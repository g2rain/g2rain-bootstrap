# 命令参考

## 启动

```shell
./start.sh
./start.sh --business g2rain-department --business g2rain-member
./start.sh --business g2rain-cms
```

- 若不存在 `.env`：复制 `.env.example` 后退出，提示修改后再运行。
- 若缺少 `ssl/server.crt` 或 `ssl/server.key`：调用 `./config/generate-ssl.sh "${PLATFORM_HOST:-localhost}"`。
- 按 `BUSINESS_EXTENSIONS` 与 `--business` 合并片段，拉取可拉取镜像，构建 Docling 派生镜像，启动并等待健康。

## 停止

```shell
./stop.sh
./stop.sh --business g2rain-department --business g2rain-member
```

对当前扩展集合执行 `docker compose down`，保留数据。扩展选择须与启动时一致。

## 更新

```shell
./update.sh
./update.sh --business g2rain-department
```

再次拉取可拉取镜像，执行 `up -d --build --remove-orphans --wait`。未列入当前集合的可选服务会作为孤儿容器被移除。

## 辅助命令

```shell
docker compose --env-file .env -f docker-compose.yml \
  -f business.d/g2rain-agent.yml -f business.d/g2rain-knowledge.yml ps

./config/generate-ssl.sh <host-or-ip>
./config/generate_key.sh config/<compose-service>/keys
```

- `generate-ssl.sh`：平台 HTTPS 自签证书，输出到 `ssl/`。
- `generate_key.sh`：为 OpenResty Lua 挂载目录生成 ES256 公私钥；同目录还需 `iam-public-key.pem`、`iam-key-id.txt`。

## 危险操作

```shell
docker compose ... down -v
```

会删除命名卷。只有明确要清空持久化数据时才可使用。
