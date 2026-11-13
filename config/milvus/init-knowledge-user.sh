#!/bin/sh
# 幂等创建 Knowledge 业务账号：角色 → collection 授权 → 用户 → 绑角色。
# 凭据来自 MILVUS_TOKEN（username:password）；管理员操作用 MILVUS_BOOTSTRAP_TOKEN。
# 用户已存在时不改密（改密须运维显式调用 update_password）；仍确保角色与授权到位。
set -eu

collection="${KNOWLEDGE_MILVUS_COLLECTION:-g2rain_knowledge_chunks_qwen_4096_v1}"
bootstrap="${MILVUS_BOOTSTRAP_TOKEN:-root:Milvus}"
app_token="${MILVUS_TOKEN:-}"
role_name="${MILVUS_KNOWLEDGE_ROLE:-knowledge_rw}"
base="http://127.0.0.1:19530"

case "$collection" in
  *[!A-Za-z0-9_]*)
    echo "invalid milvus collection name" >&2
    exit 1
    ;;
esac

if [ -z "$app_token" ]; then
  echo "MILVUS_TOKEN is empty; set username:password for knowledge service" >&2
  exit 1
fi

case "$app_token" in
  *:*)
    ;;
  *)
    echo "MILVUS_TOKEN must be username:password" >&2
    exit 1
    ;;
esac

user_name="${app_token%%:*}"
user_pass="${app_token#*:}"

if [ -z "$user_name" ] || [ -z "$user_pass" ]; then
  echo "MILVUS_TOKEN must be username:password" >&2
  exit 1
fi

case "$user_name" in
  *[!A-Za-z0-9_]*)
    echo "invalid milvus user name" >&2
    exit 1
    ;;
esac

case "$role_name" in
  *[!A-Za-z0-9_]*)
    echo "invalid milvus role name" >&2
    exit 1
    ;;
esac

# 业务 token 若就是 bootstrap（例如临时 root:Milvus），无需再建业务用户。
if [ "$app_token" = "$bootstrap" ]; then
  echo "MILVUS_TOKEN equals bootstrap token; skip knowledge user init"
  exit 0
fi

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

post() {
  curl -sS \
    -H "Authorization: Bearer ${bootstrap}" \
    -H "Content-Type: application/json" \
    --data "$2" \
    "${base}$1"
}

code_of() {
  printf '%s' "$1" | sed -n 's/.*"code"[[:space:]]*:[[:space:]]*\([-0-9][0-9]*\).*/\1/p' | head -n 1
}

# 0 成功；部分「已存在」类错误视为可继续（幂等）。
accept_ok_or_exists() {
  body="$1"
  label="$2"
  code="$(code_of "$body")"
  if [ "$code" = "0" ]; then
    return 0
  fi
  case "$body" in
    *[Aa]lready*[Ee]xist*|*[Dd]uplicate*|*"user already"*|*"role already"*|*"privilege already"*)
      echo "${label}: already exists, continue"
      return 0
      ;;
  esac
  echo "${label} failed: ${body}" >&2
  return 1
}

user_exists=0
list_users="$(post /v2/vectordb/users/list "{}")"
list_users_code="$(code_of "$list_users")"
if [ "$list_users_code" != "0" ]; then
  echo "milvus users list failed: ${list_users}" >&2
  exit 1
fi
case "$list_users" in
  *"\"${user_name}\""*|*"\"userName\":\"${user_name}\""*)
    user_exists=1
    ;;
esac

role_body="$(post /v2/vectordb/roles/create "{\"roleName\":\"${role_name}\"}")"
accept_ok_or_exists "$role_body" "create role ${role_name}"

priv_rw="$(post /v2/vectordb/roles/grant_privilege_v2 \
  "{\"roleName\":\"${role_name}\",\"privilege\":\"CollectionReadWrite\",\"dbName\":\"default\",\"collectionName\":\"${collection}\"}")"
accept_ok_or_exists "$priv_rw" "grant CollectionReadWrite on ${collection}"

priv_admin="$(post /v2/vectordb/roles/grant_privilege_v2 \
  "{\"roleName\":\"${role_name}\",\"privilege\":\"CollectionAdmin\",\"dbName\":\"default\",\"collectionName\":\"${collection}\"}")"
accept_ok_or_exists "$priv_admin" "grant CollectionAdmin on ${collection}"

if [ "$user_exists" -eq 0 ]; then
  pass_json="$(json_escape "$user_pass")"
  create_user="$(post /v2/vectordb/users/create \
    "{\"userName\":\"${user_name}\",\"password\":\"${pass_json}\"}")"
  accept_ok_or_exists "$create_user" "create user ${user_name}"
else
  echo "user ${user_name} already exists; password not changed"
fi

grant_role="$(post /v2/vectordb/users/grant_role \
  "{\"userName\":\"${user_name}\",\"roleName\":\"${role_name}\"}")"
accept_ok_or_exists "$grant_role" "grant role ${role_name} to ${user_name}"

echo "knowledge milvus user ready: ${user_name} role=${role_name} collection=${collection}"
