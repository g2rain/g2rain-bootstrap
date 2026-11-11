#!/usr/bin/env bash
# g2rain-bootstrap 一次性准备：.env → 替换 MySQL 初始化 SQL 占位符 → 按需生成 SSL → 写完成标记。
# 不克隆源码、不构建业务镜像、不执行 docker compose up。
#
# 从 .env 读取 PLATFORM_HOST / PLATFORM_PORT，将 config/mysql/g2rain-basis.sql 中的
# __PLATFORM_HOST__、__PLATFORM_PORT__ 替换后再由 MySQL 首次初始化导入（须在空数据卷前完成）。
#
# 注意: MySQL 仅在空数据卷首次初始化时执行 docker-entrypoint-initdb.d 下的 SQL；若 data/mysql
# 已有数据，修改 g2rain-basis.sql 不会自动更新库内记录，需自行迁移或清空数据卷后重装。
#
# 用法:
#   ./init-once.sh [--host HOST] [--port PORT] [--force]
#   ./init-once.sh --help
#
# 环境变量:
#   G2RAIN_BOOTSTRAP_INIT_FORCE=1  等同于 --force
#
# 完成后请执行: ./start.sh（start.sh 在缺少完成标记时也会自动调用本脚本）

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

MARKER="${ROOT}/.g2rain-bootstrap-init.done"
ENV_EXAMPLE="${ROOT}/.env.example"
ENV_FILE="${ROOT}/.env"
SQL_BASIS="${ROOT}/config/mysql/g2rain-basis.sql"

log_info() { echo "[INFO] $*"; }
log_ok() { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err() { echo "[ERROR] $*" >&2; }

usage() {
  cat <<'EOF'
用法:
  ./init-once.sh [--host HOST] [--port PORT] [--force]
  ./init-once.sh --help

说明:
  - 若尚无 .env，从 .env.example 创建；可用 --host / --port 写入平台地址。
  - 从 .env 读取 PLATFORM_HOST / PLATFORM_PORT，替换 g2rain-basis.sql 中的
    __PLATFORM_HOST__、__PLATFORM_PORT__（须在空 MySQL 数据卷首次初始化前完成）。
  - 若缺少 ssl/server.crt 或 ssl/server.key，调用 config/generate-ssl.sh。
  - 成功结束后写入 .g2rain-bootstrap-init.done；失败不写标记，可修正后重跑。
  - 不拉取镜像、不启动容器；完成后执行 ./start.sh。

选项:
  --host / --port   创建或已有 .env 时可写入平台地址（同时同步 PLATFORM_BASE_URL）。
  --force           忽略完成标记，重新执行准备流程。

强制重跑:
  rm -f .g2rain-bootstrap-init.done
  或: G2RAIN_BOOTSTRAP_INIT_FORCE=1 ./init-once.sh --force
EOF
}

escape_sed_repl() {
  printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

ensure_env_file() {
  local platform_host="${1:-}"
  local platform_port="${2:-}"
  local created=0

  if [[ -f "$ENV_FILE" ]]; then
    log_ok "已存在 .env"
  else
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
      log_err "未找到 .env.example，无法创建 .env"
      exit 1
    fi
    log_info "从 .env.example 创建 .env"
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    created=1
  fi

  if [[ -n "$platform_host" ]]; then
    if grep -q '^PLATFORM_HOST=' "$ENV_FILE"; then
      sed -i.bak "s|^PLATFORM_HOST=.*|PLATFORM_HOST=${platform_host}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi
  fi
  if [[ -n "$platform_port" ]]; then
    if grep -q '^PLATFORM_PORT=' "$ENV_FILE"; then
      sed -i.bak "s|^PLATFORM_PORT=.*|PLATFORM_PORT=${platform_port}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi
  fi
  if [[ -n "$platform_host" || -n "$platform_port" ]]; then
    local ph pp
    ph=$(grep -E '^PLATFORM_HOST=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')
    pp=$(grep -E '^PLATFORM_PORT=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')
    if [[ -n "$ph" && -n "$pp" ]] && grep -q '^PLATFORM_BASE_URL=' "$ENV_FILE"; then
      sed -i.bak "s|^PLATFORM_BASE_URL=.*|PLATFORM_BASE_URL=https://${ph}:${pp}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi
  fi

  if ((created == 1)) && [[ -z "$platform_host" && -z "$platform_port" ]]; then
    log_warn "已生成 .env，请先修改其中的密码与访问地址，然后重新运行 ./init-once.sh 或 ./start.sh。"
    exit 1
  fi

  if ((created == 1)); then
    log_ok "已创建 .env"
  fi
}

apply_sql_placeholders() {
  if [[ ! -f "$ENV_FILE" ]]; then
    log_err "缺少 .env，无法替换 SQL 占位符"
    exit 1
  fi
  if [[ ! -f "$SQL_BASIS" ]]; then
    log_warn "未找到 $SQL_BASIS，跳过 SQL 占位符替换"
    return 0
  fi
  if ! grep -q '__PLATFORM_HOST__' "$SQL_BASIS" 2>/dev/null; then
    log_info "g2rain-basis.sql 中无 __PLATFORM_HOST__ 占位符，跳过替换（可能已替换过）"
    return 0
  fi

  local ph pp
  ph=$(grep -E '^PLATFORM_HOST=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')
  pp=$(grep -E '^PLATFORM_PORT=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')
  if [[ -z "$ph" || -z "$pp" ]]; then
    log_err ".env 中 PLATFORM_HOST 或 PLATFORM_PORT 为空，无法替换 SQL 占位符"
    exit 1
  fi

  local eph epp
  eph=$(escape_sed_repl "$ph")
  epp=$(escape_sed_repl "$pp")

  log_info "将平台地址写入 g2rain-basis.sql（供 MySQL 首次初始化）"
  sed -i.bak \
    -e "s|__PLATFORM_HOST__|${eph}|g" \
    -e "s|__PLATFORM_PORT__|${epp}|g" \
    "$SQL_BASIS"
  rm -f "${SQL_BASIS}.bak"
  log_ok "SQL 占位符已替换为 ${ph}:${pp}"
}

ensure_ssl() {
  if [[ -f "${ROOT}/ssl/server.crt" && -f "${ROOT}/ssl/server.key" ]]; then
    log_ok "已存在 SSL 证书"
    return 0
  fi
  local gen="${ROOT}/config/generate-ssl.sh"
  if [[ ! -f "$gen" ]]; then
    log_err "未找到 $gen"
    exit 1
  fi
  local ph
  ph=$(grep -E '^PLATFORM_HOST=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r')
  log_info "生成 SSL 证书（主机: ${ph:-localhost}）"
  "$gen" "${ph:-localhost}"
  log_ok "SSL 证书已生成"
}

write_marker() {
  {
    echo "initialized_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "note=g2rain-bootstrap one-time prep complete"
  } >"$MARKER"
  log_ok "已写入完成标记: .g2rain-bootstrap-init.done"
}

main() {
  local platform_host=""
  local platform_port=""
  local force=0

  if [[ "${G2RAIN_BOOTSTRAP_INIT_FORCE:-0}" == "1" ]]; then
    force=1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --host)
        platform_host="${2:-}"
        if [[ -z "$platform_host" ]]; then
          log_err "--host 需要参数"
          exit 1
        fi
        shift 2
        ;;
      --port)
        platform_port="${2:-}"
        if [[ -z "$platform_port" ]]; then
          log_err "--port 需要参数"
          exit 1
        fi
        shift 2
        ;;
      --force)
        force=1
        shift
        ;;
      *)
        log_err "未知参数: $1"
        usage >&2
        exit 1
        ;;
    esac
  done

  if [[ -f "$MARKER" && "$force" -eq 0 ]]; then
    local need=0
    if [[ -f "$SQL_BASIS" ]] && grep -q '__PLATFORM_HOST__' "$SQL_BASIS" 2>/dev/null; then
      need=1
    fi
    if [[ ! -f "${ROOT}/ssl/server.crt" || ! -f "${ROOT}/ssl/server.key" ]]; then
      need=1
    fi
    if [[ ! -f "$ENV_FILE" ]]; then
      need=1
    fi
    if [[ "$need" -eq 0 ]]; then
      log_ok "已完成首次准备（存在 .g2rain-bootstrap-init.done），跳过。需要重跑请加 --force"
      exit 0
    fi
    log_warn "完成标记存在，但检测到未完成项，继续执行准备"
  fi

  ensure_env_file "$platform_host" "$platform_port"
  apply_sql_placeholders
  ensure_ssl
  write_marker
  log_ok "首次准备完成。请执行: ./start.sh"
}

main "$@"
