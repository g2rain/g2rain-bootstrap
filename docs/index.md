# g2rain-bootstrap 工程文档

本仓库是 谷雨G2rain智能体平台的快速启动入口：用 Shell 与 Docker Compose 拉取已发布镜像，组装基础设施、平台服务与 Admin Shell；Agent、Knowledge、部门、会员、CMS 等业务片段按 `BUSINESS_EXTENSIONS` / `--business` 选择加载。

与 [g2rain-deploy](https://github.com/g2rain/g2rain-deploy) 的分工：本仓库承接已发布镜像的快速启动与生产部署，默认配置用于最低资源验证，生产前需调整资源、安全与数据保障；源码联调、镜像构建与更灵活的业务片段选择在 deploy。

## 导航

- [项目元数据](project.yaml)
- [本地工程基线](architecture/local-baseline.md)
- [架构与职责](architecture/overview.md)
- [部署拓扑](architecture/topology.md)
- [配置与合并模型](architecture/configuration-model.md)
- [运行流程](architecture/runtime-flows.md)
- [差异与风险](architecture/deviations.md)
- [命令参考](operations/commands.md)
- [镜像拉取与后台准备](operations/commands.md#拉取镜像)
- [首次安装](operations/installation.md)
- [启动、停止与更新](operations/lifecycle.md)
- [备份与回滚](operations/backup-and-rollback.md)
- [安全、密钥与数据](security/secrets-and-data.md)
- [本地开发](development/local-development.md)
- [Shell 与 Compose 约定](development/conventions.md)
- [验证策略](development/testing.md)
- [完成标准](development/definition-of-done.md)
- [Git 工作流](development/git-workflow.md)
- [需求记录](requirements/README.md)
- [架构决策](decisions/README.md)

## 当前验证

2026-11-09 本次静态复核：

- `init-once.sh`、`start.sh`、`stop.sh`、`update.sh`、`compose-business.inc`、`config/generate-ssl.sh` 的 Bash 语法检查通过。
- Docker Compose 成功解析基础编排（13 个服务）、默认 Agent+Knowledge（23 个服务），以及追加 department/member/cms 后的组合。

未启动容器，未验证运行时健康状态，也未执行安装、更新、停止或清理操作。静态检查不等同于部署验收；已知限制见[差异与风险](architecture/deviations.md)。
