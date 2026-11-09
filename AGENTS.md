# G2rain Bootstrap 协作约定

## 项目定位

本仓库负责用 Docker Compose 快速拉起 谷雨G2rain智能体平台部署栈：拉取已发布的 GHCR 镜像，按默认或所选业务扩展合并编排，管理启动、停止与更新。它不克隆源码、不执行业务构建，也不替代生产级密钥、TLS、容量规划、备份与高可用设计。

## 工作入口

- 先阅读 `docs/index.md`、`docs/project.yaml` 和任务涉及的运维、安全文档。
- 以 `start.sh`、`stop.sh`、`update.sh`、`compose-business.inc`、根目录 `docker-compose.yml`、`business.d/*.yml`、`.env.example` 与 `config/` 为当前行为事实来源。
- 修改镜像标签、资源上限、端口、卷、业务扩展选择、证书生成或凭据约定时，同步更新 `docs/` 与 `README.md`。
- 不执行 `start.sh`、`stop.sh`、`update.sh`、`docker compose down -v`、`config/generate-ssl.sh` 或 `config/generate_key.sh`，除非用户明确授权对应环境和影响范围。

## 安全验证

```shell
bash -n start.sh stop.sh update.sh compose-business.inc
bash -n config/generate-ssl.sh config/generate_key.sh
docker compose --env-file .env.example -f docker-compose.yml config
docker compose --env-file .env.example -f docker-compose.yml -f business.d/g2rain-agent.yml -f business.d/g2rain-knowledge.yml config
docker compose --env-file .env.example -f docker-compose.yml \
  -f business.d/g2rain-agent.yml -f business.d/g2rain-knowledge.yml \
  -f business.d/g2rain-department.yml -f business.d/g2rain-member.yml \
  -f business.d/g2rain-cms.yml config
```

中央目录已登记本项目为平台部署入口，尚无部署编排类正式 Profile；工程约束见 `docs/architecture/local-baseline.md`。

以上仅做静态解析；运行部署命令前还必须检查 `.env`、目标 Docker Context、数据备份和服务清单。

## 完成标准

- 基础编排与所选业务片段可解析，生命周期脚本语法通过。
- 镜像标签固定版本，不引入不可追溯的 `latest`。
- 不提交真实凭据、生产私钥、运行时 `.env`、`data/`、`logs/` 或 `ssl/`。
- 明确说明是否真正启动过容器、验证过健康状态或执行过回滚。
