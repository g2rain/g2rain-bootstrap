# 首次安装

## 前置检查

- 在 Linux x86_64 主机或兼容 Bash 环境执行。
- 安装 Docker Engine 24+、Docker Compose 2.20+ 与 OpenSSL。
- 最低单请求 Demo：4 核 CPU、16 GB 内存和 40 GB 可用磁盘；容器资源上限合计约 11.7 GB。
- 复制 `.env.example` 为 `.env`，替换访问地址；生产环境还必须轮换所有密码、Token，并同步 Nacos 内配置。
- 确认当前 Docker Context、磁盘空间、开放端口和持久化目录。
- 若 GHCR 包需要认证，使用仅含 `read:packages` 的令牌登录：

```shell
echo "$GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USER --password-stdin
```

## 执行原则

本仓库没有独立初始化脚本。首次准备步骤是：

1. 复制并审查 `.env`。
2. 执行 `./start.sh`；缺失证书时脚本会生成自签证书。
3. 若 `.env` 尚不存在，脚本会从模板生成后退出，要求修改后再启动。

MySQL 初始化 SQL 仅在空数据卷首次创建时自动执行，已有数据卷不会自动重放。Docling 会在首次 `up --build` 时本机构建派生镜像；无外网或需离线 tokenizer 时，应预先准备 `DOCLING_HF_CACHE`。

不要对不受信任的 Compose 片段、镜像覆盖或密钥目录运行该流程。
