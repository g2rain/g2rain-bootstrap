# 本地开发

文档和脚本开发可在不连接 Docker Engine 的情况下完成大部分静态检查。推荐在 Linux 或兼容 Bash 环境验证脚本行为，并解析合并后的 Compose 配置。

```shell
bash -n pull.sh start.sh stop.sh update.sh compose-business.inc
bash -n config/generate-ssl.sh
docker compose --env-file .env.example -f docker-compose.yml config
docker compose --env-file .env.example \
  -f docker-compose.yml \
  -f business.d/g2rain-agent.yml \
  -f business.d/g2rain-knowledge.yml \
  config
docker compose --env-file .env.example \
  -f docker-compose.yml \
  -f business.d/g2rain-agent.yml \
  -f business.d/g2rain-knowledge.yml \
  -f business.d/g2rain-department.yml \
  -f business.d/g2rain-member.yml \
  -f business.d/g2rain-cms.yml \
  config
```

不要为了测试脚本而在开发者的默认 Docker Context 中执行真实 `up`、`down`、`prune` 或破坏性 `down -v`。源码联调与本地镜像构建请使用 [g2rain-deploy](https://github.com/g2rain/g2rain-deploy)。
