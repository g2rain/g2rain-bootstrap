#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./compose-business.inc
# shellcheck disable=SC1091
source ./image-bundle.inc

usage() {
  cat <<'EOF'
用法: ./save.sh [--output-dir <目录>] [--business <名>]... [服务名]...

将当前部署方案需要的镜像导出为 .tar.gz，供上传到镜像包站点：
- 按 Compose 合并结果提取镜像（构建型输出跳过；Docling BASE_IMAGE 会导出）；
- 本地缺失时先 docker pull，再 docker save | gzip；
- 归档名：把镜像引用中的 / 与 : 换成 _，后缀 .tar.gz。

参数：
  --output-dir <目录>  输出目录，默认 IMAGE_BUNDLE_DIR 或 ./images
  --business <名>      追加业务扩展，可重复指定
  [服务名]...          仅导出这些 Compose 服务的镜像；省略则导出整栈
EOF
}

output_dir=""
forward_args=()
while (($# > 0)); do
  case "$1" in
    --output-dir)
      if (($# < 2)) || [[ -z "${2:-}" ]]; then
        echo "--output-dir 需要指定目录" >&2
        usage >&2
        exit 1
      fi
      output_dir="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      forward_args+=("$1")
      shift
      ;;
  esac
done

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

output_dir="${output_dir:-${IMAGE_BUNDLE_DIR:-./images}}"

if ! image_list="$(g2rain_list_images "${services[@]+"${services[@]}"}")"; then
  echo "解析 Compose 镜像列表失败" >&2
  exit 1
fi
images=()
while IFS= read -r image; do
  [[ -n "$image" ]] && images+=("$image")
done <<< "$image_list"

if ((${#services[@]} > 0)) && ((${#images[@]} == 0)); then
  echo "未找到可导出镜像的服务: ${services[*]}" >&2
  echo "请确认服务名属于当前 Compose 合并结果，且非仅本地 build 输出。" >&2
  exit 1
fi

if ((${#images[@]} == 0)); then
  echo "当前方案没有可导出的镜像。" >&2
  exit 1
fi

if ((${#services[@]} > 0)); then
  echo "仅导出指定服务镜像: ${services[*]}"
fi

mkdir -p "$output_dir"

ensure_image() {
  local image="$1"
  if docker image inspect "$image" >/dev/null 2>&1; then
    return 0
  fi
  echo "本地缺失，拉取: $image"
  docker pull "$image"
}

for image in "${images[@]}"; do
  archive="$(g2rain_image_archive_name "$image")"
  dest="${output_dir%/}/$archive"
  ensure_image "$image"
  echo "导出: $image -> $dest"
  docker save "$image" | gzip -c >"$dest"
done

echo "镜像已导出到: $output_dir"
echo "上传示例: scp ${output_dir%/}/*.tar.gz user@demo.g2rain.com:/var/www/images/"
