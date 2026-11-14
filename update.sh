#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./compose-business.inc

usage() {
  cat <<'EOF'
用法: ./update.sh [--business <名>]... [服务名]...

合并片段选择须与启动时一致。
读取 BUSINESS_EXTENSIONS；可用 --business 追加扩展。
可选传入 Compose 服务名（如 g2rain-basis），仅更新这些服务；省略则更新整栈。

指定服务时会：停止并删除对应容器 → 删除本地镜像 → 重新拉取 → 强制重建。
整栈更新使用 --force-recreate，确保容器重新创建。

示例:
  ./update.sh
  ./update.sh g2rain-basis
  ./update.sh --business g2rain-agent --business g2rain-knowledge g2rain-basis
EOF
}

g2rain_parse_business_args "$@"
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

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

env_file=.env
if [[ ! -f "$env_file" ]]; then
  env_file=.env.example
fi

compose=(docker compose --env-file "$env_file" -f docker-compose.yml)
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  compose+=(-f "$file")
done < <(g2rain_business_yml_paths)

resolve_service_images() {
  local resolved_config
  resolved_config="$("${compose[@]}" config)"
  export G2RAIN_PULL_SERVICES="${services[*]}"
  awk '
    BEGIN {
      n = split(ENVIRON["G2RAIN_PULL_SERVICES"], arr, " ")
      for (i = 1; i <= n; i++) if (arr[i] != "") want[arr[i]] = 1
      filter_on = (length(want) > 0)
    }
    function wanted() {
      return !filter_on || (service in want)
    }
    function emit() {
      if (service != "" && wanted() && !build && image != "") print image
      if (service == "docling-serve" && wanted() && build && base != "") print base
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
  ' <<< "$resolved_config" | sort -u
}

if ((${#services[@]} > 0)); then
  echo "停止并移除容器: ${services[*]}"
  "${compose[@]}" rm -sf "${services[@]}"

  mirror="${GHCR_MIRROR:-ghcr.1ms.run}"
  mapfile -t target_images < <(resolve_service_images)
  if ((${#target_images[@]} == 0)); then
    echo "未解析到服务镜像: ${services[*]}" >&2
    exit 1
  fi
  for image in "${target_images[@]}"; do
    [[ -n "$image" ]] || continue
    echo "删除本地镜像: $image"
    docker rmi -f "$image" >/dev/null 2>&1 || true
    if [[ "$image" == ghcr.io/* ]]; then
      docker rmi -f "${mirror}/${image#ghcr.io/}" >/dev/null 2>&1 || true
    fi
  done
fi

pull_args=()
for name in "${G2RAIN_BUSINESS_EXTRA[@]+"${G2RAIN_BUSINESS_EXTRA[@]}"}"; do
  pull_args+=(--business "$name")
done
if ((${#services[@]} > 0)); then
  pull_args+=("${services[@]}")
fi
./pull.sh "${pull_args[@]+"${pull_args[@]}"}"

up_args=(up -d --build --force-recreate --wait)
if ((${#services[@]} > 0)); then
  # 局部更新不带 --remove-orphans，避免误删未点名的运行中服务。
  up_args+=("${services[@]}")
else
  up_args+=(--remove-orphans)
fi
"${compose[@]}" "${up_args[@]}"
