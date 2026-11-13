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

# HF hub 的 snapshots/<rev>/*.json 通常是指向 blobs/ 的符号链接。
# find -type f 会漏掉 symlink，导致误判 incomplete 并重启循环。
# 用 test -e（跟随链接）+ huggingface_hub local_files_only 双校验。
shell_snapshot_present() {
  [ -d "$model_path/snapshots" ] || return 1
  # shellcheck disable=SC2086
  set -- "$model_path"/snapshots/*/config.json
  if [ -e "$1" ]; then
    return 0
  fi
  set -- "$model_path"/snapshots/*/tokenizer_config.json
  [ -e "$1" ]
}

hub_local_ok() {
  HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 HF_HUB_DISABLE_TELEMETRY=1 \
    python3 -c "from huggingface_hub import snapshot_download; print(snapshot_download('${model}', local_files_only=True))"
}

tokenizer_ready() {
  shell_snapshot_present || return 1
  hub_local_ok >/dev/null 2>&1
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

  if ! shell_snapshot_present; then
    echo "docling-serve: prefetch finished but snapshots/config.json missing under ${model_path}" >&2
    ls -la "$model_path/snapshots" >&2 || true
    find "$model_path/snapshots" \( -type f -o -type l \) 2>/dev/null | head -n 40 >&2 || true
    exit 1
  fi
  if ! hub_path="$(hub_local_ok)"; then
    echo "docling-serve: prefetch finished but huggingface_hub local_files_only=True failed for ${model}" >&2
    ls -la "$model_path/snapshots" >&2 || true
    find "$model_path/snapshots" \( -type f -o -type l \) 2>/dev/null | head -n 40 >&2 || true
    exit 1
  fi
  echo "docling-serve: tokenizer cache ready at ${hub_path}"
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
