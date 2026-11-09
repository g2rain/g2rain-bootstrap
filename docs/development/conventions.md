# Shell 与 Compose 约定

- Shell 使用 Bash，并保持 `set -euo pipefail` 兼容。
- 所有路径基于脚本所在仓库根解析，避免依赖调用者当前目录。
- 仅支持 Docker Compose V2（`docker compose`）。
- 业务片段选择集中在 `compose-business.inc`；新增片段须同步 `business.d/README.md`、`.env.example` 与工程文档。
- `--business` 为追加语义，并与 `BUSINESS_EXTENSIONS` 去重合并。
- G2rain 组件镜像使用固定版本标签；禁止默认引入 `latest`。
- 资源、端口、卷、健康检查的变更必须同步 `docs/` 与 `README.md`。
- 清理、覆盖、生成密钥、删除数据卷均属于显式授权操作，必须有清晰提示。
- 示例配置只提供占位用途；演示私钥不得被当作生产材料。
