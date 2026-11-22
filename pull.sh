#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./compose-business.inc
# shellcheck disable=SC1091
source ./image-bundle.inc

usage() {
  cat <<'EOF'
用法: ./pull.sh [--background] [--force] [--business <名>]... [服务名]...

从官网镜像包目录下载 .tar.gz 并 docker load：
- 按 Compose 合并结果提取镜像（构建型输出跳过；Docling BASE_IMAGE 会准备）；
- 固定从 https://www.g2rain.com/g2rain-downloads/docker 下载（说明页见 /platform/image-downloads.html）；
- 本地已有同名镜像时跳过，除非指定 --force；
- 最多并行下载 4 个归档。
- Compose 中的 image 引用保持不变，本脚本只负责准备本地镜像。

参数：
  --background       后台拉取，日志写入 logs/image-pull.log
  --force            即使本地已有镜像也重新下载并 load
  --business <名>    追加业务扩展，可重复指定
  [服务名]...        仅拉取这些 Compose 服务的镜像；省略则拉取整栈
EOF
}

background=0
force=0
forward_args=()
while (($# > 0)); do
  case "$1" in
    --background)
      background=1
      shift
      ;;
    --force)
      force=1
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
  nohup bash ./pull.sh ${force:+--force} "${forward_args[@]+"${forward_args[@]}"}" >logs/image-pull.log 2>&1 &
  pid=$!
  printf '%s\n' "$pid" >logs/image-pull.pid
  echo "镜像正在后台拉取，PID: $pid"
  echo "查看日志: tail -f logs/image-pull.log"
  exit 0
fi

g2rain_source_env
g2rain_parse_business_args "${forward_args[@]+"${forward_args[@]}"}"

services=()
if ((${#G2RAIN_REMAINING_ARGS[@]} > 0)); then
  for arg in "${G2RAIN_REMAINING_ARGS[@]}"; do
    case "$arg" in
      --help|-h)
        usage
        exit 0
        ;;
      -*)
        echo "未知参数: $arg" >&2
        usage >&2
        exit 1
        ;;
      *)
        services+=("$arg")
        ;;
    esac
  done
fi

# 官网直链目录；说明页：https://www.g2rain.com/platform/image-downloads.html
base_url="https://www.g2rain.com/g2rain-downloads/docker"
parallel=4

if ! command -v curl >/dev/null 2>&1; then
  echo "需要 curl 才能从官网下载镜像包" >&2
  exit 1
fi

if ! image_list="$(g2rain_list_images "${services[@]+"${services[@]}"}")"; then
  echo "解析 Compose 镜像列表失败" >&2
  exit 1
fi
images=()
while IFS= read -r image; do
  [[ -n "$image" ]] && images+=("$image")
done <<< "$image_list"

if ((${#services[@]} > 0)) && ((${#images[@]} == 0)); then
  echo "未找到可拉取镜像的服务: ${services[*]}" >&2
  echo "请确认服务名属于当前 Compose 合并结果，且非仅本地 build 输出。" >&2
  exit 1
fi

if ((${#services[@]} > 0)); then
  echo "仅拉取指定服务镜像: ${services[*]}"
fi

pull_one() {
  local image="$1"
  local archive url
  archive="$(g2rain_image_archive_name "$image")"
  url="${base_url}/${archive}"

  if ((force == 0)) && docker image inspect "$image" >/dev/null 2>&1; then
    echo "已存在，跳过: $image"
    return 0
  fi

  echo "下载并加载: $url"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/g2rain-image.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN
  if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
    echo "下载失败: $image ($url)" >&2
    return 1
  fi
  if ! docker load -i "$tmp"; then
    echo "docker load 失败: $image" >&2
    return 1
  fi

  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "load 完成但未找到标签: $image（请确认归档由 save.sh 按同名镜像导出）" >&2
    return 1
  fi
  echo "已加载: $image"
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

for pid in "${pids[@]+"${pids[@]}"}"; do
  if ! wait "$pid"; then
    failed=1
  fi
done

if ((failed)); then
  echo "部分镜像拉取失败，请检查上方日志。" >&2
  exit 1
fi

echo "镜像下载和加载完成。"
