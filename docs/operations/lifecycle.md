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

## 停止

普通维护使用与启动相同的扩展选择，例如 `./stop.sh` 或带相同 `--business`。持久化卷与 `data/` 绑定目录默认保留。只有明确要删除数据时才使用 `down -v`，且必须先有备份与恢复方案。

## 更新

`./update.sh` 对当前扩展集合拉取、构建并重建。更新前备份 `data/`、当前镜像 digest 与 `.env`；更新后验证健康状态和业务冒烟流程。可用 `.env` 中的 `*_IMAGE` 覆盖单个组件版本，但仍应固定可追溯标签，避免 `latest`。若缩小扩展集合，`--remove-orphans` 会移除不再编排的可选服务。
