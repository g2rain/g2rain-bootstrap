# 命令参考

## 拉取镜像

```shell
./pull.sh
./pull.sh --business g2rain-agent --business g2rain-knowledge
./pull.sh g2rain-basis
./pull.sh --background
```

脚本从当前 Compose 方案提取镜像；末尾可跟 Compose 服务名，仅拉取这些服务的镜像。`ghcr.io` 镜像通过 `ghcr.1ms.run` 拉取后重新标记为原标签，其他 Registry 镜像直接拉取。默认并行数为 4，可通过 `IMAGE_PULL_PARALLEL` 调整。

优先读取 `.env`，不存在时读取 `.env.example`。`BUSINESS_EXTENSIONS` 决定默认扩展，`--business` 在此基础上追加；拉取与后续启动应使用同一组扩展。

在 `.env` 中配置：

```shell
GHCR_MIRROR=ghcr.1ms.run
IMAGE_PULL_PARALLEL=4
```

Compose 和 Dockerfile 保留官方镜像引用。启用 Knowledge 时，脚本从合并配置的 `build.args.BASE_IMAGE` 获取 Docling 基础镜像，默认执行等价操作：

```shell
docker pull ghcr.1ms.run/docling-project/docling-serve-cpu:v1.29.0
docker tag ghcr.1ms.run/docling-project/docling-serve-cpu:v1.29.0 \
  ghcr.io/docling-project/docling-serve-cpu:v1.29.0
```

所有声明 `build` 的服务，其输出镜像均跳过拉取，包括自定义标签的 Docling 修复镜像。`pull.sh` 只准备镜像，不构建镜像、不启动容器；Docling 修复版由后续启动或更新流程构建。

后台拉取可组合扩展参数：

```shell
./pull.sh --background --business g2rain-knowledge
tail -f logs/image-pull.log
cat logs/image-pull.pid
```

后台命令返回表示任务已提交，不代表下载完成；通过日志中的完成或失败信息确认结果。每次后台调用会覆盖上述日志和 PID 文件，应等待当前任务结束后再启动下一次。

前台模式下，业务片段或 Compose 解析失败会终止执行；任一镜像拉取或标签转换失败会返回非零退出码。修正配置或网络问题后可重新运行。`start.sh` 与 `update.sh` 已自动调用本脚本，独立运行适用于提前准备镜像。

## 首次准备

```shell
./init-once.sh
./init-once.sh --host your.server.host --port 10443
./init-once.sh --force
```

- 若不存在 `.env`：从 `.env.example` 复制；未传 `--host`/`--port` 时退出，提示修改后再运行。
- 用 `.env` 中的 `PLATFORM_HOST` / `PLATFORM_PORT` 替换 `config/mysql/g2rain-basis.sql` 占位符。
- 若缺少 `ssl/server.crt` 或 `ssl/server.key`：调用 `./config/generate-ssl.sh`。
- 成功后写入 `.g2rain-bootstrap-init.done`。不拉取镜像、不启动容器。

## 启动

```shell
./start.sh
./start.sh --business g2rain-department --business g2rain-member
./start.sh --business g2rain-cms
```

- 缺少完成标记、仍有 SQL 占位符或缺少证书时，自动调用 `./init-once.sh`。
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
./update.sh g2rain-basis
./update.sh --business g2rain-agent --business g2rain-knowledge g2rain-basis
```

执行拉取后 `up -d --build --force-recreate --wait`，配置变更也会重建容器，不删除本地镜像。指定服务名时仅拉取/重建这些服务（不带 `--remove-orphans`）；省略则整栈更新（带 `--remove-orphans`）。`--business` 选择须与启动时一致。

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
