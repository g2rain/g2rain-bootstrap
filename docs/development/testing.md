# 验证策略

## 当前基线

2026-11-09 静态复核：

- `init-once.sh`、`start.sh`、`stop.sh`、`update.sh`、`compose-business.inc`、`config/generate-ssl.sh` 通过 `bash -n`。
- Docker Compose 成功解析基础编排（13 服务）、默认 Agent+Knowledge（23 服务），以及追加 department/member/cms 的组合。
- 未执行容器运行测试。

本次 Compose 使用 `.env.example` 执行 `config --services`，只解析配置，不拉取镜像或启动容器。

## 变更验证

- Shell 语法：所有生命周期 `.sh`、`compose-business.inc` 与将实际调用的辅助脚本。
- Compose：基础编排、每个业务片段及常用合并组合（含可选扩展）。
- 扩展选择：`BUSINESS_EXTENSIONS`、`--business` 追加与去重。
- 镜像：确认默认标签可追溯，覆盖变量不会悄悄引入 `latest`。
- 资源与端口：核对锚点、片段内联声明与 `.env.example` 端口映射。
- 生命周期：在隔离 Docker Context 中验证启动等待、更新、普通停止；破坏性清理需单独授权。
- 数据：验证已有/空数据卷、数据库初始化、Milvus 建表标记、备份与回滚。
- 安全：扫描固定凭据、私钥、危险权限和不可信命令执行入口。

仅静态解析通过不能证明部署成功；运行时验证必须说明使用的环境、服务范围和数据影响。
