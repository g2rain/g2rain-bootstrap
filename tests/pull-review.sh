#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker() {
  if [[ "$1" == compose ]]; then
    if [[ "${MOCK_FAIL:-0}" == 1 ]]; then return 19; fi
    printf '%s\n' 'services:' '  docling-serve:' '    build:' '      args:' '        BASE_IMAGE: ghcr.io/docling-project/docling-serve-cpu:v1.29.0' '    image: local/custom-docling:test' '  app:' '    image: ghcr.io/g2rain/example:1' '  redis:' '    image: redis:7-alpine' 'networks:' '  default: {}'
  elif [[ "$1" == image && "$2" == inspect ]]; then
    if [[ "${MOCK_HAVE_IMAGE:-0}" == 1 || "${MOCK_LOADED:-0}" == 1 ]]; then return 0; fi
    return 1
  elif [[ "$1" == load ]]; then
    MOCK_LOADED=1
    printf 'MOCK %s\n' "$*"
  else
    printf 'MOCK %s\n' "$*"
  fi
}
curl() {
  printf 'MOCK curl'
  local arg
  for arg in "$@"; do
    printf ' %s' "$arg"
  done
  printf '\n'
  local out=""
  while (($# > 0)); do
    if [[ "$1" == -o ]]; then
      out="$2"
      break
    fi
    shift
  done
  if [[ -n "$out" ]]; then
    printf 'fake-tar\n' >"$out"
  fi
}
export -f docker curl
output="$(bash ./pull.sh)"
[[ "$output" == *'MOCK curl'*'https://www.g2rain.com/g2rain-downloads/docker/ghcr.io_docling-project_docling-serve-cpu_v1.29.0.tar.gz'* ]]
[[ "$output" == *'MOCK curl'*'https://www.g2rain.com/g2rain-downloads/docker/redis_7-alpine.tar.gz'* ]]
[[ "$output" == *'MOCK load -i'* ]]
[[ "$output" != *'local/custom-docling:test'* ]]
filtered="$(bash ./pull.sh app)"
[[ "$filtered" == *'仅拉取指定服务镜像: app'* ]]
[[ "$filtered" == *'MOCK curl'*'https://www.g2rain.com/g2rain-downloads/docker/ghcr.io_g2rain_example_1.tar.gz'* ]]
[[ "$filtered" != *'redis_7-alpine.tar.gz'* ]]
[[ "$filtered" != *'docling-serve-cpu'* ]]
skipped="$(MOCK_HAVE_IMAGE=1 bash ./pull.sh redis)"
[[ "$skipped" == *'已存在，跳过: redis:7-alpine'* ]]
[[ "$skipped" != *'MOCK curl'* ]]
forced="$(MOCK_HAVE_IMAGE=1 bash ./pull.sh --force redis)"
[[ "$forced" == *'MOCK curl'*'redis_7-alpine.tar.gz'* ]]
if bash ./pull.sh nonexistent-service-review-test; then exit 1; fi
if MOCK_FAIL=1 bash ./pull.sh; then exit 1; fi
if bash ./pull.sh --business nonexistent-review-test; then exit 1; fi
# 使用相同后台启动命令，从父目录经相对路径调用帮助；无需创建后台日志。
cd ..
bash g2rain-bootstrap/pull.sh --help >/dev/null
bash g2rain-bootstrap/save.sh --help >/dev/null
echo 'Mock checks passed (no downloads).'
