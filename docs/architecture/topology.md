# 部署拓扑

## 基础主编排

根目录 `docker-compose.yml` 静态解析后包含 13 个服务：

- 基础设施：MySQL、Redis、Nacos、Kafka、Nginx
- 平台入口：`g2rain-gateway`（镜像 `g2rain-gateway-webflux`）
- 平台后端：`g2rain-basis`、`g2rain-infra`、`g2rain-iam`
- 前端与 Shell：`g2rain-main-shell`、`g2rain-admin-shell`、`g2rain-infra-app`、`g2rain-manager-app`

`g2rain-admin-shell`（Context Path `/admin`）属于基础栈，不在 `business.d` 中。

## 业务扩展

业务片段全部由 `BUSINESS_EXTENSIONS` 与 `--business` 选择。`.env.example` 预填 `g2rain-agent,g2rain-knowledge` 时完整栈共 23 个服务。

| 片段 | 服务 |
| --- | --- |
| `business.d/g2rain-agent.yml` | `g2rain-chat-shell`（`/chat`）、`g2rain-agent-app`（`/agent`）、`g2rain-agent-runtime`、`g2rain-agent-studio`、`g2rain-mcp-registry`、`g2rain-model-nexus` |
| `business.d/g2rain-knowledge.yml` | `g2rain-knowledge-app`（`/knowledge`）、`docling-serve`、`milvus`、`g2rain-knowledge` |
| `business.d/g2rain-department.yml` | `g2rain-department`、`g2rain-department-app`（`/department`） |
| `business.d/g2rain-member.yml` | `g2rain-member`、`g2rain-member-app`（`/member`） |
| `business.d/g2rain-cms.yml` | `g2rain-cms`、`g2rain-cms-app`（`/cms`） |

启用 CMS 前请确认 `ghcr.io/g2rain/g2rain-cms:1.0.0` 与 `g2rain-cms-app:1.0.0` 可拉取；该标签曾出现 `manifest unknown`。

## 知识库业务片段

`docling-serve` 与 `milvus` 均接入 `g2rain-network`，并默认映射宿主机端口：Docling `5001`（`DOCLING_PORT`）、Milvus SDK `19530`（`MILVUS_PORT`）；Milvus 健康检查 `9091` 仅容器内使用。

`docling-serve` 默认镜像为本地标签 `g2rain-bootstrap/docling-serve-cpu:v1.29.0`（可由 `DOCLING_IMAGE` 覆盖），由 `docling-serve/Dockerfile` 基于官方 `ghcr.io/docling-project/docling-serve-cpu:v1.29.0` 构建。构建阶段把 GUI OpenCV 换成同版本 headless，避免旧内核加载 Qt 失败。HybridChunker 依赖 `sentence-transformers/all-MiniLM-L6-v2`：宿主机 HF cache（`DOCLING_HF_CACHE`）挂到 `HF_HOME`；入口 `start-docling-serve.sh` 以 root `chown` 后，缺模型时幂等预拉（`DOCLING_HF_PREFETCH`，默认 1），再降权到 UID 1001。业务进程默认 `HF_HUB_OFFLINE=1`。无出网环境须预置 cache 并设 `DOCLING_HF_PREFETCH=0`。

`g2rain-knowledge` 通过 `http://docling-serve:5001` 调用文档解析，通过 `http://milvus:19530` 访问向量检索。`g2rain-knowledge-app` 经 Nginx `/knowledge/` 对外；业务 API 仍经 `/api/` → Gateway。Milvus 以 Standalone 单容器运行，使用嵌入式 etcd、Woodpecker 本地 WAL 和本地存储，数据持久化在 `data/milvus/`。知识原文件及解析产物持久化在 `data/g2rain-knowledge/`（容器内默认 `/data/knowledge`）。

Milvus v3 镜像默认非 root：入口以 root `chown` `data/milvus/` 后降权启动。进程健康后按 `config/milvus/knowledge-collection.json` 幂等创建 collection，并写入 `data/milvus/.knowledge-collection-ready`；健康检查同时要求该标记。已存在的同名 collection 不会因更新模板自动补列。

## 对外入口

默认 HTTPS 入口为 `https://<PLATFORM_HOST>:10443/`。智能客服访客入口为 `/chat/`；管理端为 `/admin/`。可选扩展对应 `/department/`、`/member/`、`/cms/`。

## 依赖顺序

各服务的 `depends_on` 与健康检查以当前 Compose 文件为准。启动脚本对合并后的所选栈执行 `up -d --build --wait`，由 Compose 健康检查驱动等待。
