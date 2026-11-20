# shellcheck shell=bash
# 镜像归档命名与 Compose 镜像列表解析：由 pull.sh / save.sh source。
# 依赖调用方已 cd 到仓库根；可选已 source compose-business.inc 与 .env。

G2RAIN_ENV_FILE=
G2RAIN_COMPOSE_CMD=()

g2rain_source_env() {
  if [[ -f .env ]]; then
    G2RAIN_ENV_FILE=.env
  else
    G2RAIN_ENV_FILE=.env.example
  fi
  set -a
  # shellcheck disable=SC1090
  source "$G2RAIN_ENV_FILE"
  set +a
}

# ghcr.io/g2rain/foo:1.0.0 -> ghcr.io_g2rain_foo_1.0.0.tar.gz
g2rain_image_archive_name() {
  local image="$1"
  local name="${image//\//_}"
  name="${name//:/_}"
  printf '%s.tar.gz\n' "$name"
}

g2rain_compose_cmd_init() {
  G2RAIN_COMPOSE_CMD=(docker compose --env-file "$G2RAIN_ENV_FILE" -f docker-compose.yml)
  local file paths
  if ! paths="$(g2rain_business_yml_paths)"; then
    return 1
  fi
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    G2RAIN_COMPOSE_CMD+=(-f "$file")
  done <<< "$paths"
}

# 从合并后的 Compose 配置提取可准备镜像；构建型输出跳过，Docling BASE_IMAGE 保留。
# 参数：可选服务名列表；无参数则取整栈。
g2rain_list_images() {
  local services=("$@")
  if ! g2rain_compose_cmd_init; then
    return 1
  fi

  local resolved_config
  if ! resolved_config="$("${G2RAIN_COMPOSE_CMD[@]}" config)"; then
    echo "docker compose config 失败" >&2
    return 1
  fi

  export G2RAIN_PULL_SERVICES="${services[*]-}"
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
