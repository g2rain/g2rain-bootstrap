#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker() {
  if [[ "$1" == compose ]]; then
    if [[ "${MOCK_FAIL:-0}" == 1 ]]; then return 19; fi
    printf '%s\n' 'services:' '  docling-serve:' '    build:' '      args:' '        BASE_IMAGE: ghcr.io/docling-project/docling-serve-cpu:v1.29.0' '    image: local/custom-docling:test' '  app:' '    image: ghcr.io/g2rain/example:1' '  redis:' '    image: redis:7-alpine' 'networks:' '  default: {}'
  else
    printf 'MOCK %s\n' "$*"
  fi
}
export -f docker
output="$(bash ./pull.sh)"
[[ "$output" == *'MOCK pull ghcr.1ms.run/docling-project/docling-serve-cpu:v1.29.0'* ]]
[[ "$output" == *'MOCK tag ghcr.1ms.run/docling-project/docling-serve-cpu:v1.29.0 ghcr.io/docling-project/docling-serve-cpu:v1.29.0'* ]]
[[ "$output" == *'MOCK pull redis:7-alpine'* ]]
[[ "$output" != *'MOCK pull local/custom-docling:test'* ]]
if MOCK_FAIL=1 bash ./pull.sh; then exit 1; fi
if bash ./pull.sh --business nonexistent-review-test; then exit 1; fi
# 使用相同后台启动命令，从父目录经相对路径调用帮助；无需创建后台日志。
cd ..
bash g2rain-bootstrap/pull.sh --help >/dev/null
echo 'Mock checks passed (no downloads).'
