#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./compose-business.inc

usage() {
  cat <<'EOF'
用法: ./start.sh [--business <名>]...

合并 .env 中的 BUSINESS_EXTENSIONS；未配置时仅启动基础栈。
可重复传入 --business 追加片段，例如:
  ./start.sh --business g2rain-agent --business g2rain-knowledge
  ./start.sh --business g2rain-department --business g2rain-member

推荐组合见 .env.example 与 business.d/README.md。
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

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "已生成 .env，请先修改其中的密码与访问地址，然后重新运行 ./start.sh。"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [[ ! -f ssl/server.crt || ! -f ssl/server.key ]]; then
  ./config/generate-ssl.sh "${PLATFORM_HOST:-localhost}"
fi

compose=(docker compose --env-file .env -f docker-compose.yml)
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  compose+=(-f "$file")
done < <(g2rain_business_yml_paths)

./pull.sh "$@"
"${compose[@]}" up -d --build --wait
echo "G2Rain 已启动：${PLATFORM_BASE_URL:-https://${PLATFORM_HOST:-localhost}:${PLATFORM_PORT:-10443}}/chat/"
