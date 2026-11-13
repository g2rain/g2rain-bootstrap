# 启动、停止与更新

## 首次准备

首次部署或更换平台访问地址（且 MySQL 数据卷仍为空）时，先执行：

```shell
./init-once.sh --host your.server.host --port 10443
```

也可只改好 `.env` 后执行 `./init-once.sh`。该步骤会替换 `g2rain-basis.sql` 占位符并按需生成证书。`start.sh` 在缺少完成标记时会自动调用。

## 启动

启动前先解析 Compose：

```shell
docker compose --env-file .env \
  -f docker-compose.yml \
  -f business.d/g2rain-agent.yml \
  -f business.d/g2rain-knowledge.yml \
  config
```

再执行 `./start.sh`。需要部门或会员时：

```shell
./start.sh --business g2rain-department --business g2rain-member
```

完成后应检查 Compose 状态、关键容器日志、HTTPS 入口、`/chat/` 访问、登录与核心服务调用。首次使用自签证书时，浏览器会显示安全提示。

## Milvus 重启排查

先在部署主机检查退出状态与日志，不要删除 `data/milvus/`：

```shell
docker inspect milvus-standalone --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Restarts={{.RestartCount}} Memory={{.HostConfig.Memory}}'
docker logs --tail 200 milvus-standalone
```

- `invalid milvus user name`：旧 `.env` 的 `knowledge-service` 含连字符，初始化脚本拒绝。将 `MILVUS_TOKEN` 的用户名改为 `knowledge_service`，保留自己的密码，同步 Knowledge 实际配置（含 Nacos 中的覆盖值）。启动会创建新用户，不删除旧用户，也不会修改已有用户的密码。
- `OOMKilled=true`：检查主机可用内存与容器限制。默认上限已由 `1280M` 改为 `2G`，可用 `MILVUS_MEMORY_LIMIT` 调整；2G 不是已验证的容量保证。
- `milvus healthz timeout`：默认启动等待为 600 秒，可通过 `MILVUS_STARTUP_TIMEOUT` 调整；同时检查前面的 Milvus 日志、磁盘与 CPU 情况。
- 集合或账号初始化失败：查看前面的 REST 错误，检查管理员凭据 `MILVUS_BOOTSTRAP_TOKEN` 和授权。启动脚本会退出触发重启；单纯健康检查失败不会自动重启容器。

已有安装更新仓库后，还需调整服务器 `.env`；新增变量不填时使用上述默认值。配置变更须重建容器才能生效，单纯 `docker restart` 不会更新环境变量或资源限制。在部署目录执行以下命令（其他业务片段按实际部署补充）：

```shell
docker compose --env-file .env -f docker-compose.yml \
  -f business.d/g2rain-agent.yml -f business.d/g2rain-knowledge.yml \
  up -d --no-deps milvus g2rain-knowledge
```

此操作会重建配置变化的服务并造成短暂中断，保留绑定目录中的数据。完成后检查日志与健康状态。

## 停止

普通维护使用与启动相同的扩展选择，例如 `./stop.sh` 或带相同 `--business`。持久化卷与 `data/` 绑定目录默认保留。只有明确要删除数据时才使用 `down -v`，且必须先有备份与恢复方案。

## 更新

`./update.sh` 对当前扩展集合拉取、构建并重建。更新前备份 `data/`、当前镜像 digest 与 `.env`；更新后验证健康状态和业务冒烟流程。可用 `.env` 中的 `*_IMAGE` 覆盖单个组件版本，但仍应固定可追溯标签，避免 `latest`。若缩小扩展集合，`--remove-orphans` 会移除不再编排的可选服务。
