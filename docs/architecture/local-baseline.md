# 本地工程基线

中央 G2rain 架构目录已登记本项目为平台部署入口（`platform-deployment-entry`），部署职责为 `production-deployment-bootstrap`，`profile` 为 `null`。目前没有适用于部署编排仓库的正式 Profile，本仓库继续采用本地基线 `g2rain-compose-bootstrap 1.0.0-local`。

登记依据：[中央项目目录](https://github.com/g2rain/g2rain/blob/c1d33755e595845808a37ae73bb79367df6bbb1b/docs/architecture/catalog/projects.yaml)，固定基线提交 `c1d33755e595845808a37ae73bb79367df6bbb1b`，2026-11-08 复核。中央登记的 `configuration-validated` 只表示配置检查，不代表全栈运行验收。

中央目录还列有按目标生成部署方案的职责；当前仓库入口为首次准备、启动、停止和更新脚本，未见独立方案生成命令，不应据此承诺已有生成接口。

## 基线约束

- Shell 脚本使用 Bash 严格模式（`set -euo pipefail`），生命周期入口为首次准备、启动、停止和更新；`init-once.sh` 仅做 `.env` / SQL 占位符 / SSL，不克隆源码、不构建业务镜像。
- 仅维护 Docker Compose V2（`docker compose`）主编排；不提供 Compose V1 并行栈。
- 主 Compose 始终先加载；业务片段仅由 `BUSINESS_EXTENSIONS` 与可追加的 `--business` 决定，脚本不写死默认扩展。
- G2rain 组件镜像默认固定正式版本标签，地址形如 `ghcr.io/g2rain/<组件>:<版本>`，不使用 `latest`。
- Docling 以官方 GHCR 镜像为底，在本机通过 `docling-serve/Dockerfile` 做最小 OpenCV headless 修复；派生镜像不要求 G2rain 另行发布。
- 环境模板不得作为生产配置直接使用；凭据和密钥必须由部署环境安全注入，并与 Nacos 内配置同步轮换。
- 数据删除、证书生成、密钥生成与破坏性 Compose 操作均属于显式授权操作。

未来中央 Profile 建立后，应固定其版本和基线引用，评审本地差异后再登记 Profile 采用。
