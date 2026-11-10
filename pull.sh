#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./compose-business.inc

usage() {
  cat <<'EOF'
用法: ./pull.sh [--background] [--business <名>]...

拉取当前部署方案需要的镜像：
- ghcr.io 镜像改从 ghcr.1ms.run 拉取，再打回原 ghcr.io 标签；
- 其他 Registry 的镜像直接拉取；
- 默认最多并行拉取 4 个镜像。

参数：
  --background       后台拉取，日志写入 logs/image-pull.log
  --business <名>    追加业务扩展，可重复指定
EOF
}

background=0
forward_args=()
while (($# > 0)); do
  case "$1" in
    --background)
      background=1
      shift
      ;;
    *)
      forward_args+=("$1")
      shift
      ;;
  esac
done

if ((background)); then
  mkdir -p logs
  nohup bash ./pull.sh "${forward_args[@]}" >logs/image-pull.log 2>&1 &
  pid=$!
  printf '%s\n' "$pid" >logs/image-pull.pid
  echo "镜像正在后台拉取，PID: $pid"
  echo "查看日志: tail -f logs/image-pull.log"
  exit 0
fi

if [[ -f .env ]]; then
  env_file=.env
else
  env_file=.env.example
fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

g2rain_parse_business_args "${forward_args[@]}"
if ((${#G2RAIN_REMAINING_ARGS[@]} > 0)); then
  for arg in "${G2RAIN_REMAINING_ARGS[@]}"; do
    case "$arg" in
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "未知参数: $arg" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
fi

compose=(docker compose --env-file "$env_file" -f docker-compose.yml)
business_paths="$(g2rain_business_yml_paths)"
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  compose+=(-f "$file")
done <<< "$business_paths"

# 先检查 Compose 的退出状态，避免进程替换吞掉解析错误。
resolved_config="$("${compose[@]}" config)"
# 只解析 Compose 规范化输出的 services 层级，不按镜像名称猜测 build。
# 构建型服务跳过输出镜像；Docling 的 BASE_IMAGE 仍需预拉取。
image_list="$(awk '
  function emit() {
    if (service != "" && !build && image != "") print image
    if (service == "docling-serve" && build && base != "") print base
  }
  /^services:$/ { inside=1; next }
  inside && /^[^ ]/ { emit(); service=""; inside=0 }
  inside && /^  [^ ]/ {
    emit(); service=$1; sub(/:$/, "", service)
    build=0; image=""; base=""; next
  }
  inside && /^    build:/ { build=1 }
  inside && /^    image:/ { image=$2 }
  inside && /^        BASE_IMAGE:/ { base=$2 }
  END { emit() }
' <<< "$resolved_config" | sort -u)"
images=()
while IFS= read -r image; do
  [[ -n "$image" ]] && images+=("$image")
done <<< "$image_list"

mirror="${GHCR_MIRROR:-ghcr.1ms.run}"
parallel="${IMAGE_PULL_PARALLEL:-4}"
if ! [[ "$parallel" =~ ^[1-9][0-9]*$ ]]; then
  echo "IMAGE_PULL_PARALLEL 必须是正整数" >&2
  exit 1
fi

pull_one() {
  local image="$1" accelerated
  if [[ "$image" == ghcr.io/* ]]; then
    accelerated="${mirror}/${image#ghcr.io/}"
    echo "拉取 GHCR 加速镜像: $accelerated"
    docker pull "$accelerated"
    docker tag "$accelerated" "$image"
    echo "已标记为: $image"
  else
    echo "直接拉取镜像: $image"
    docker pull "$image"
  fi
}

failed=0
pids=()
for image in "${images[@]}"; do
  pull_one "$image" &
  pids+=("$!")
  if ((${#pids[@]} >= parallel)); then
    if ! wait "${pids[0]}"; then
      failed=1
    fi
    pids=("${pids[@]:1}")
  fi
done

for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    failed=1
  fi
done

if ((failed)); then
  echo "部分镜像拉取失败，请检查上方日志。" >&2
  exit 1
fi

echo "镜像拉取和标签转换完成。"
