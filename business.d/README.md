# 业务扩展

本目录存放可与主编排合并的业务 Compose 片段。生命周期脚本先加载根目录 `docker-compose.yml`，再按选择合并本目录片段。

## 片段清单

| 片段 | 服务 |
| --- | --- |
| `g2rain-agent.yml` | Chat Shell、Agent App、Agent Runtime、Agent Studio、MCP Registry、Model Nexus |
| `g2rain-knowledge.yml` | Knowledge App、Knowledge Service、Docling、Milvus |
| `g2rain-department.yml` | `g2rain-department`、`g2rain-department-app`（`/department`） |
| `g2rain-member.yml` | `g2rain-member`、`g2rain-member-app`（`/member`） |
| `g2rain-cms.yml` | `g2rain-cms`、`g2rain-cms-app`（`/cms`） |

`g2rain-admin-shell` 属于平台基础栈，定义在根目录 `docker-compose.yml` 中，不是业务扩展。

扩展文件依赖基础编排提供的 MySQL、Redis、Nacos、Gateway 和 `g2rain-network`。Docling 会拉取官方 GHCR 基础镜像，并在本地应用 OpenCV headless 兼容修复。

启用 CMS 前请确认 `ghcr.io/g2rain/g2rain-cms:1.0.0`（及 cms-app）可拉取；该标签曾出现 `manifest unknown`。

## 选择加载

读取 `.env` 中的 `BUSINESS_EXTENSIONS`；未配置且无 `--business` 时只启动基础栈。`.env.example` 预填了智能客服常用组合 `g2rain-agent,g2rain-knowledge`，可按需增删。可重复传入 `--business <名>` 追加片段：

```bash
# 持久化：写入 .env
BUSINESS_EXTENSIONS=g2rain-agent,g2rain-knowledge,g2rain-department,g2rain-member

# 或单次追加
./start.sh --business g2rain-department --business g2rain-member
./start.sh --business g2rain-cms
./update.sh --business g2rain-department
./stop.sh --business g2rain-department --business g2rain-member
```

片段名可写 `g2rain-department` 或 `g2rain-department.yml`。`start` / `stop` / `update` 应使用同一组扩展，否则可选服务可能残留或被 `--remove-orphans` 清掉。
