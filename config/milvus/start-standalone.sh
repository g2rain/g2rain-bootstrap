#!/bin/sh
# 降权启动 Milvus，健康后再幂等建表与业务账号。标记文件存在后健康检查才通过。
set -eu

startup_timeout="${MILVUS_STARTUP_TIMEOUT:-600}"
case "$startup_timeout" in
  ''|*[!0-9]*|0) echo "MILVUS_STARTUP_TIMEOUT must be a positive integer" >&2; exit 1 ;;
esac
# 在启动数据库前检查账号，避免等数据库启动后才发现配置错误。
/bin/sh /milvus/configs/init-knowledge-user.sh --validate-only

uid="$(id -u milvus)"
gid="$(id -g milvus)"
ready="/var/lib/milvus/.knowledge-collection-ready"

mkdir -p /var/lib/milvus
chown -R "${uid}:${gid}" /var/lib/milvus
rm -f "$ready"

if command -v runuser >/dev/null 2>&1; then
  runuser -u milvus -- milvus run standalone &
elif command -v setpriv >/dev/null 2>&1; then
  setpriv --reuid=milvus --regid=milvus --clear-groups milvus run standalone &
else
  echo "milvus image has neither runuser nor setpriv" >&2
  exit 1
fi
child="$!"

terminate() {
  kill -TERM "$child" 2>/dev/null || true
  wait "$child" 2>/dev/null || true
}
trap 'terminate; exit 0' TERM INT

deadline=$(( $(date +%s) + startup_timeout ))
until curl --connect-timeout 2 --max-time 5 -fsS http://127.0.0.1:9091/healthz >/dev/null 2>&1; do
  if ! kill -0 "$child" 2>/dev/null; then
    echo "milvus exited before healthz" >&2
    exit 1
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "milvus healthz timeout after ${startup_timeout}s" >&2
    terminate
    exit 1
  fi
  sleep 2
done

if ! /bin/sh /milvus/configs/init-collection.sh; then
  echo "milvus collection initialization failed; check preceding error" >&2
  terminate
  exit 1
fi
if ! /bin/sh /milvus/configs/init-knowledge-user.sh; then
  echo "milvus knowledge user initialization failed; check preceding error" >&2
  terminate
  exit 1
fi
touch "$ready"

wait "$child"
