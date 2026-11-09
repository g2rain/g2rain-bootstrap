# 配置与合并模型

## 环境变量

`.env.example` 是 `.env` 模板，包含平台地址、端口、数据库、Redis、Nacos、时区、业务扩展、Docling 与 Milvus 等配置。模板中的固定值仅用于本地示例，生产环境必须全部审查并替换敏感项。

当前发布快照的 Nacos 初始化数据带有一组本地开发凭据。若更换 MySQL / Redis / Nacos 口令，必须同时更新 Nacos 内各服务的数据源与 Redis 配置，不能只改 `.env`。

Chat Shell 匿名接入码使用 `CHAT_ANONYMOUS_ENTRY_KEY`；为空表示不开放匿名访问。

`BUSINESS_EXTENSIONS` 控制合并的业务片段，逗号或空格分隔。未配置时不合并任何业务片段。`.env.example` 预填智能客服常用组合 `g2rain-agent,g2rain-knowledge`；可按需追加 `g2rain-department`、`g2rain-member`、`g2rain-cms`。

可用与 Compose 中同名的 `*_IMAGE` 变量覆盖单个镜像，例如 `GATEWAY_IMAGE`、`KNOWLEDGE_IMAGE`、`DOCLING_IMAGE`、`CMS_IMAGE`。

## 单请求 Demo 资源上限

`docker-compose.yml` 通过文件级 YAML 锚点为各服务声明 `deploy.resources` 上限，面向最低资源的功能跑通，不适用于并发或生产。

| 角色 | 锚点 / 声明位置 | 典型 limit |
| --- | --- | --- |
| 前端 App / Shell | `x-deploy-frontend` | 0.25 CPU / 192M |
| Java 后端 | `x-deploy-java` + `JAVA_TOOL_OPTIONS`（`-Xms32m` / `-Xmx256m`、`MaxMetaspaceSize=160m`、`ReservedCodeCacheSize=32m`） | 0.50 CPU / 512M |
| MySQL | `x-deploy-mysql` | 0.50 CPU / 512M |
| Redis | `x-deploy-redis` | 0.20 CPU / 160M |
| Nacos | `x-deploy-nacos` | 0.50 CPU / 640M |
| Kafka | `x-deploy-kafka` | 0.50 CPU / 384M |
| Nginx | `x-deploy-nginx` | 0.10 CPU / 96M |
| Docling | `business.d/g2rain-knowledge.yml` 内联 | 1.00 CPU / 1536M |
| Milvus | `business.d/g2rain-knowledge.yml` 内联 | 1.00 CPU / 1280M |

业务片段文件不能引用主文件 YAML 锚点，因此各扩展服务在各自文件内重复声明资源上限。reservation 是软预留，不代表进程空闲常驻。

## Compose 合并

生命周期脚本通过 `compose-business.inc` 构造：

```text
docker compose --env-file .env \
  -f docker-compose.yml \
  -f business.d/<所选片段>.yml ...
```

选择规则：

1. 读取 `BUSINESS_EXTENSIONS`（可为空）
2. 追加可重复的 `--business <名>`
3. 去重后按解析顺序依次 `-f`；若结果为空则只加载主 Compose

主 Compose 始终位于参数链第一位。没有 `services.conf` 源码构建映射。`start` / `stop` / `update` 应使用同一组扩展；`update.sh` 带 `--remove-orphans`，未列入当前集合的可选服务会被移除。

## Docling 本机构建

`docling-serve` 声明 `build`：

- `DOCLING_BASE_IMAGE`：官方基础镜像，默认 `ghcr.io/docling-project/docling-serve-cpu:v1.29.0`
- `DOCLING_IMAGE`：本机派生标签，默认 `g2rain-bootstrap/docling-serve-cpu:v1.29.0`
- `docling-serve/fix-opencv.py`：构建阶段替换 OpenCV

`start.sh` / `update.sh` 使用 `pull --ignore-buildable`，再 `up -d --build --wait`，因此可拉取的发布镜像会更新，Docling 派生镜像在本机构建。

## 证书与应用密钥

- `config/generate-ssl.sh`：为平台 HTTPS 生成自签证书，写入 `ssl/`（Git 忽略）。
- `config/generate_key.sh`：为 OpenResty Lua 挂载目录生成 ES256 密钥材料；与 SSL 脚本职责不同。
