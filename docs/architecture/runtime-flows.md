# 运行流程

## 启动

1. 切换到仓库根目录；若不存在 `.env`，从 `.env.example` 复制后退出，要求先修改再重跑。
2. 加载 `.env`。
3. 若缺少 `ssl/server.crt` 或 `ssl/server.key`，调用 `config/generate-ssl.sh`，主机名取自 `PLATFORM_HOST`（默认 `localhost`）。
4. 按 `BUSINESS_EXTENSIONS` 与 `--business` 解析业务片段，合并主 Compose。
5. 执行 `docker compose pull --ignore-buildable`。
6. 执行 `docker compose up -d --build --wait`。
7. 打印访客入口：`${PLATFORM_BASE_URL}/chat/`。

## 更新

1. 使用与启动相同的 Compose 合并参数。
2. 再次 `pull --ignore-buildable`。
3. 执行 `up -d --build --remove-orphans --wait`。

更新前应备份 `data/`、当前 `.env` 与镜像 digest；升级后检查健康状态与 `/chat/` 冒烟流程。未列入当前扩展集合的可选服务会被 `--remove-orphans` 移除。

## 停止

`stop.sh` 对同一合并栈执行 `docker compose down`，保留命名卷与绑定挂载的数据目录。扩展选择须与启动时一致。不要执行 `docker compose down -v`，除非明确要删除持久化数据。

## 与 deploy 的差异

本仓库没有 `init-once.sh`、没有源码 `codes/` 同步、没有按服务名选择性启停，也没有 `--cleanup` 一类扩展清理参数。`--business` 为追加语义，不是 deploy 的“仅加载列出片段”。首次准备只是复制 `.env` 与按需生成自签证书。
