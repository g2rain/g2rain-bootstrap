#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./compose-business.inc

usage() {
  cat <<'EOF'
用法: ./update.sh [--business <名>]...

合并片段选择须与启动时一致。
读取 BUSINESS_EXTENSIONS；可用 --business 追加扩展。
EOF
}

g2rain_parse_business_args "$@"
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

"${compose[@]}" pull --ignore-buildable
"${compose[@]}" up -d --build --remove-orphans --wait
