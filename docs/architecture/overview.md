# 架构与职责

仓库把快速启动职责划分为三部分：生命周期脚本负责操作顺序；Compose 文件定义运行拓扑；配置目录提供中间件、代理、数据库初始化及应用密钥材料。G2rain 业务组件只使用已发布的 GHCR 镜像，不在本仓库克隆源码或执行业务构建。

```text
运维人员
  -> init-once.sh：.env、g2rain-basis.sql 平台地址占位符、自签证书（可独立或由 start.sh 调用）
  -> start.sh：检查首次准备、拉取镜像、合并业务片段、启动并等待健康
  -> update.sh：再次拉取可拉取镜像、重建服务并清理孤儿容器
  -> stop.sh：docker compose down，保留命名卷与绑定数据目录

配置输入
  -> .env.example / .env
  -> .env 中的 BUSINESS_EXTENSIONS 与可选 --business
  -> 主 Compose docker-compose.yml
  -> business.d 所选片段（由 BUSINESS_EXTENSIONS / --business 决定）
  -> compose-business.inc：片段选择与合并
  -> config/ 中间件、SQL、Nginx、SSL 脚本与应用密钥
  -> docling-serve/：基于官方 Docling 镜像的本机兼容修复构建
```

本仓库不实现平台业务逻辑，也不替代生产级密钥管理、备份、灾难恢复、集群调度和高可用设计。默认资源档仅用于单请求 Demo。
