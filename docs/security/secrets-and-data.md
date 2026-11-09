# 安全、密钥与数据

## 环境凭据

`.env.example` 中的固定密码和认证材料仅能作为本地示例。生产环境必须使用独立强凭据和受控 Secret 注入，限制文件权限，避免通过命令行、日志、备份或工单泄露。

当前发布快照的 Nacos 配置包含本地开发凭据。轮换时必须同时更新：

- 宿主机 `.env` 中的 MySQL、Redis、Nacos 相关变量
- Nacos 内各服务的数据源与 Redis 配置
- Milvus 的 `MILVUS_TOKEN` / `MILVUS_BOOTSTRAP_TOKEN`

只改 `.env` 会导致服务启动后仍连到旧凭据。

## 应用密钥

仓库当前跟踪多个 `config/g2rain-*/keys/` 目录，其中包含命名为私钥的 PEM/DER 文件。它们必须视为不可信的演示材料：禁止生产复用，并应决定是否从当前版本及 Git 历史移除。若曾在任何环境使用，必须立即轮换对应密钥。

生成脚本输出的新私钥只应写入部署主机的受限 Secret 路径，不应再次提交。公钥与 IAM key id 的分发也需要版本和信任链管理。

## 数据与网络

- `.env`、`data/`、`logs/`、`ssl/` 已被 Git 忽略。
- MySQL、Redis、Nacos、Kafka、Docling、Milvus 等运维端口不应直接暴露到不可信网络。
- Milvus 必须保持鉴权开启。`MILVUS_BOOTSTRAP_TOKEN` 是管理员凭据，改密后必须同步，否则健康检查不会通过。
- Milvus 持久化目录为 `data/milvus/`，须整体纳入备份；知识文件在 `data/g2rain-knowledge/`。
- 生产应使用受信任的 TLS 证书，替换默认自签材料。
- Nginx/Gateway 转发的身份头必须只在可信网络内建立与传播。
- 日志和备份可能含 Token、用户数据及连接信息，应限制访问和保留周期。

## 执行边界

生命周期脚本会拉取 GHCR 与上游镜像，并在本机构建 Docling 派生镜像。只允许受评审的镜像标签、Dockerfile 与配置参与部署。不要对不受信任的覆盖变量或外部挂载内容执行 `start.sh` / `update.sh`。
