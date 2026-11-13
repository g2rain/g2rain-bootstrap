#!/bin/sh
# HybridChunker 依赖 sentence-transformers/all-MiniLM-L6-v2（本地 tokenizer）。
# 官方镜像以 UID 1001 运行；以 root 纠正 HF_HOME 挂载属主，缺完整模型时幂等预拉，再降权启动。
# 与 Milvus start-standalone.sh 同套路。业务进程仍尊重 HF_HUB_OFFLINE（默认离线只读）。
set -eu

hf_home="${HF_HOME:-/opt/app-root/src/.cache/huggingface}"
uid="${DOCLING_UID:-1001}"
gid="${DOCLING_GID:-0}"
model="${DOCLING_HF_TOKENIZER_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"
prefetch="${DOCLING_HF_PREFETCH:-1}"
# HuggingFace hub 本地目录名：org/name → models--org--name
model_dir="$(printf '%s' "$model" | sed 's|/|--|g')"
model_path="${hf_home}/hub/models--${model_dir}"

export HF_HOME="${hf_home}"
export HF_HUB_CACHE="${hf_home}/hub"

mkdir -p "${hf_home}/hub"
chown -R "${uid}:${gid}" "${hf_home}"
chmod -R g+rwX "${hf_home}" || true

# 仅有空目录/锁文件/残缺快照不算就绪；须能离线读到 config.json。
tokenizer_ready() {
  [ -d "$model_path" ] || return 1
  find "$model_path/snapshots" -type f \( -name 'config.json' -o -name 'tokenizer_config.json' \) 2>/dev/null | grep -q .
}

need_model=1
if tokenizer_ready; then
  need_model=0
  echo "docling-serve: tokenizer cache ready at ${model_path}"
fi

if [ "$need_model" -eq 1 ]; then
  if [ "$prefetch" = "0" ] || [ "$prefetch" = "false" ] || [ "$prefetch" = "no" ]; then
    echo "docling-serve: missing usable tokenizer at ${model_path}; set DOCLING_HF_PREFETCH=1 or pre-seed DOCLING_HF_CACHE" >&2
    ls -la "${hf_home}/hub" >&2 || true
    exit 1
  fi
  echo "docling-serve: prefetching ${model} into ${hf_home}"
  HF_HUB_OFFLINE=0 TRANSFORMERS_OFFLINE=0 HF_HUB_DISABLE_TELEMETRY=1 \
    python3 - <<PY
from huggingface_hub import snapshot_download
path = snapshot_download("${model}", local_files_only=False)
print("docling-serve: downloaded to", path)
PY
  chown -R "${uid}:${gid}" "${hf_home}"
  chmod -R g+rwX "${hf_home}" || true
  if ! tokenizer_ready; then
    echo "docling-serve: prefetch finished but tokenizer still incomplete at ${model_path}" >&2
    find "$model_path" -maxdepth 3 -type f 2>/dev/null | head -n 40 >&2 || true
    exit 1
  fi
fi

if [ "$#" -eq 0 ]; then
  set -- docling-serve run
fi

if [ -x /usr/bin/container-entrypoint ]; then
  target="/usr/bin/container-entrypoint"
else
  target=""
fi

if command -v setpriv >/dev/null 2>&1; then
  if [ -n "$target" ]; then
    exec setpriv --reuid="${uid}" --regid="${gid}" --clear-groups -- "$target" "$@"
  fi
  exec setpriv --reuid="${uid}" --regid="${gid}" --clear-groups -- "$@"
fi

if command -v runuser >/dev/null 2>&1; then
  if [ -n "$target" ]; then
    exec runuser -u "#${uid}" -- "$target" "$@"
  fi
  exec runuser -u "#${uid}" -- "$@"
fi

echo "docling-serve entrypoint needs setpriv or runuser to drop to uid ${uid}" >&2
exit 1
