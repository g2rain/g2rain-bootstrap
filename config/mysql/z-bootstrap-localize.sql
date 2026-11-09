-- 将 g2rain-deploy 发布快照中的测试机地址改为 Compose 内部服务名。
-- 本文件在 init-nacos.sql 之后运行，仅影响空 MySQL 数据目录的首次初始化。
USE nacos;

UPDATE config_info
SET content = REPLACE(content, '10.0.0.2', 'mysql');

UPDATE config_info
SET content = REPLACE(content, '43.138.13.145', 'mysql');

UPDATE config_info
SET content = REPLACE(content, '120.245.114.207', 'mysql');

UPDATE config_info
SET content = REPLACE(content, '1.203.173.224', 'mysql');

-- 同一份配置中 Redis 与 Milvus 也曾使用数据库宿主机 IP，按端口精确修正。
UPDATE config_info
SET content = REPLACE(content, 'host: mysql\n      # 端口\n      port: 6379', 'host: redis\n      # 端口\n      port: 6379');

UPDATE config_info
SET content = REPLACE(content, 'http://mysql:19530', 'http://milvus:19530');
