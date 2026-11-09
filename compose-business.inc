# shellcheck shell=bash
# 业务 Compose 片段合并：由 start.sh / stop.sh / update.sh source。
# 依赖调用方已 cd 到仓库根；可选已 source .env。

G2RAIN_BUSINESS_EXTRA=()
G2RAIN_REMAINING_ARGS=()

g2rain_normalize_business_name() {
  local name="${1:-}"
  name="${name#business.d/}"
  name="${name%.yml}"
  name="${name%.yaml}"
  printf '%s\n' "$name"
}

g2rain_default_business_names() {
  # 只读 BUSINESS_EXTENSIONS；不在脚本里写死默认扩展。
  # 推荐组合由 .env.example 提供，未配置且无 --business 时仅启动基础栈。
  local raw="${BUSINESS_EXTENSIONS:-}"
  raw="${raw//,/ }"
  # shellcheck disable=SC2206
  local names=($raw)
  local name
  for name in "${names[@]}"; do
    [[ -n "$name" ]] || continue
    g2rain_normalize_business_name "$name"
  done
}

g2rain_name_in_list() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

g2rain_resolved_business_names() {
  local names=()
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    if ! g2rain_name_in_list "$name" "${names[@]+"${names[@]}"}"; then
      names+=("$name")
    fi
  done < <(g2rain_default_business_names)
  for name in "${G2RAIN_BUSINESS_EXTRA[@]+"${G2RAIN_BUSINESS_EXTRA[@]}"}"; do
    name="$(g2rain_normalize_business_name "$name")"
    [[ -n "$name" ]] || continue
    if ! g2rain_name_in_list "$name" "${names[@]+"${names[@]}"}"; then
      names+=("$name")
    fi
  done
  if ((${#names[@]} > 0)); then
    printf '%s\n' "${names[@]}"
  fi
}

g2rain_business_yml_paths() {
  local name path
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    path="business.d/${name}.yml"
    if [[ ! -f "$path" ]]; then
      echo "业务片段不存在: $path" >&2
      return 1
    fi
    printf '%s\n' "$path"
  done < <(g2rain_resolved_business_names)
}

g2rain_parse_business_args() {
  G2RAIN_BUSINESS_EXTRA=()
  G2RAIN_REMAINING_ARGS=()
  while (($# > 0)); do
    case "$1" in
      --business)
        if (($# < 2)) || [[ -z "${2:-}" ]]; then
          echo "--business 需要指定片段名（见 business.d/README.md）" >&2
          return 1
        fi
        G2RAIN_BUSINESS_EXTRA+=("$(g2rain_normalize_business_name "$2")")
        shift 2
        ;;
      --help|-h)
        G2RAIN_REMAINING_ARGS+=("$1")
        shift
        ;;
      *)
        G2RAIN_REMAINING_ARGS+=("$1")
        shift
        ;;
    esac
  done
}
