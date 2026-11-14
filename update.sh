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
可选传入 Compose 服务名（如 g2rain-basis），仅拉取/重建这些服务；省略则更新整栈。

始终使用 --force-recreate，确保配置变更也会重建容器（不删除本地镜像）。

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
