-- =============================================
-- g2rain_knowledge 数据库表结构
-- MySQL 8.0.13+
-- 仅用于首次初始化；脚本会删除并重建知识库表，禁止在已有业务数据的环境重复执行
-- 约定：ID 由服务生成；organ_id 为机构/租户隔离键；不使用物理外键。
-- 含逻辑删除条件的索引统一使用函数键 (IF(delete_flag = 0, 0, NULL))，仅有效记录参与索引语义。
-- =============================================

-- 创建数据库
CREATE DATABASE IF NOT EXISTS `g2rain_knowledge` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `g2rain_knowledge`;

-- =============================================
-- 清理（依赖表优先）
-- =============================================
DROP TABLE IF EXISTS `knowledge_feedback`;
DROP TABLE IF EXISTS `knowledge_answer_template`;
DROP TABLE IF EXISTS `knowledge_release`;
DROP TABLE IF EXISTS `knowledge_task`;
DROP TABLE IF EXISTS `knowledge_chunk`;
DROP TABLE IF EXISTS `knowledge_revision`;
DROP TABLE IF EXISTS `knowledge_item`;
DROP TABLE IF EXISTS `knowledge_tag`;
DROP TABLE IF EXISTS `knowledge_category`;

-- =============================================
-- 1. 知识分类表 (knowledge_category)
-- 组织级扁平运营分类；不使用父子树。分类不承担权限、隔离或检索过滤。
-- =============================================
CREATE TABLE `knowledge_category` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `category_code` VARCHAR(64) NOT NULL COMMENT '分类编码',
    `category_name` VARCHAR(128) NOT NULL COMMENT '分类名称',
    `status` VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态[ACTIVE:有效, INACTIVE:停用]',
    `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
    `remark` VARCHAR(512) NULL COMMENT '备注',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_category_code_del` (`organ_id`, `category_code`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_status_del_sort` (`organ_id`, `status`, (IF(delete_flag = 0, 0, NULL)), `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识分类表';

-- =============================================
-- 2. 知识标签字典表 (knowledge_tag)
-- 组织级扁平标签字典；`tag_code` 为稳定身份，`tag_name` 仅展示。
-- 标签仅用于业务分类与检索筛选，不承担机构隔离或权限控制。
-- =============================================
CREATE TABLE `knowledge_tag` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `tag_code` VARCHAR(64) NOT NULL COMMENT '稳定业务编码，如 after_sales、x100；创建后冻结',
    `tag_name` VARCHAR(128) NOT NULL COMMENT '展示名称，如 售后、X100',
    `status` VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态[ACTIVE:有效, INACTIVE:停用]',
    `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
    `remark` VARCHAR(512) NULL COMMENT '备注',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_tag_code_del` (`organ_id`, `tag_code`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_status_del_sort` (`organ_id`, `status`, (IF(delete_flag = 0, 0, NULL)), `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识标签字典表';

-- =============================================
-- 3. 知识主题表 (knowledge_item)
-- =============================================
CREATE TABLE `knowledge_item` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `category_id` BIGINT NULL COMMENT '知识分类标识',
    `knowledge_key` VARCHAR(128) NOT NULL COMMENT '稳定业务键，如 refund_policy',
    `knowledge_name` VARCHAR(256) NOT NULL COMMENT '知识名称',
    `knowledge_type` VARCHAR(32) NOT NULL COMMENT '知识类型[DOCUMENT:文档, FAQ:问答]',
    `status` VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态[ACTIVE:有效, INACTIVE:停用]',
    `description` VARCHAR(1024) NULL COMMENT '知识说明',
    `priority` INT NOT NULL DEFAULT 0 COMMENT '运营与同主题并列排序优先级，数值越大越靠前；不写入Milvus过滤',
    `tags_json` JSON NULL COMMENT '主题已选标签编码数组，PROCESS/INDEX任务同步到Milvus Entity tags字段',
    `visibility` VARCHAR(16) NOT NULL DEFAULT 'PRIVATE' COMMENT '共享范围[PRIVATE:仅本机构, PUBLIC:公共知识]',
    `create_user_id` BIGINT NULL COMMENT '创建用户标识',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_knowledge_key_del` (`organ_id`, `knowledge_key`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_category_type_status_del` (`organ_id`, `category_id`, `knowledge_type`, `status`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_visibility_del` (`visibility`, (IF(delete_flag = 0, 0, NULL)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识主题表';

-- =============================================
-- 4. 知识版本表 (knowledge_revision)
-- =============================================
CREATE TABLE `knowledge_revision` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `knowledge_id` BIGINT NOT NULL COMMENT '知识主题标识',
    `revision_no` VARCHAR(64) NOT NULL COMMENT '版本号，如 v3 或 2026.10.03',
    `source_type` VARCHAR(32) NOT NULL COMMENT '来源类型[FILE:文件, FAQ:结构化问答]',
    `revision_status` VARCHAR(32) NOT NULL DEFAULT 'DRAFT' COMMENT '版本状态[DRAFT,PARSING,PARSE_FAILED,REVIEWING,INDEXING,INDEX_FAILED,READY_TO_PUBLISH,PUBLISHED,DEPRECATED,REJECTED]',
    `source_file_name` VARCHAR(512) NULL COMMENT '净化后的原始文件名',
    `source_content_type` VARCHAR(128) NULL COMMENT '原始文件MIME类型',
    `source_storage_path` VARCHAR(1024) NULL COMMENT '受控本地存储相对路径',
    `source_sha256` CHAR(64) NULL COMMENT '原始文件SHA-256',
    `source_file_size` BIGINT NULL COMMENT '原始文件大小，单位字节',
    `faq_question` TEXT NULL COMMENT 'FAQ标准问题，仅FAQ来源使用',
    `faq_answer` MEDIUMTEXT NULL COMMENT 'FAQ标准答案，仅FAQ来源使用',
    `parser_name` VARCHAR(64) NULL COMMENT '解析器名称，如 Docling',
    `parser_version` VARCHAR(64) NULL COMMENT '解析器版本',
    `parser_task_id` VARCHAR(128) NULL COMMENT '解析服务任务标识',
    `parsed_storage_path` VARCHAR(1024) NULL COMMENT '结构化解析产物相对路径',
    `chunk_count` INT NOT NULL DEFAULT 0 COMMENT '切片数量',
    `index_status` VARCHAR(32) NOT NULL DEFAULT 'PENDING' COMMENT '索引状态[PENDING,INDEXING,INDEXED,FAILED,DELETING,DELETED]',
    `embedding_profile` VARCHAR(64) NULL COMMENT '向量配置键，如 qwen-4096-v1；与 collection/维度对应，审核通过后写入',
    `embedding_model` VARCHAR(128) NULL COMMENT '外部向量模型标识',
    `index_completed_time` TIMESTAMP NULL COMMENT '索引完成时间',
    `reviewer_user_id` BIGINT NULL COMMENT '审核用户标识',
    `review_time` TIMESTAMP NULL COMMENT '审核时间',
    `review_comment` VARCHAR(1024) NULL COMMENT '审核意见',
    `create_user_id` BIGINT NULL COMMENT '创建用户标识',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_knowledge_revision_del` (`organ_id`, `knowledge_id`, `revision_no`, (IF(delete_flag = 0, 0, NULL))),
    UNIQUE KEY `uk_organ_knowledge_single_draft_del` (`organ_id`, `knowledge_id`, (IF(delete_flag = 0 AND revision_status = 'DRAFT', 0, NULL))),
    INDEX `idx_organ_knowledge_status_index_del` (`organ_id`, `knowledge_id`, `revision_status`, `index_status`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_source_hash_del` (`organ_id`, `source_sha256`, (IF(delete_flag = 0, 0, NULL)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识版本表';

-- =============================================
-- 5. 知识切片清单表 (knowledge_chunk)
-- =============================================
CREATE TABLE `knowledge_chunk` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `revision_id` BIGINT NOT NULL COMMENT '知识版本标识',
    `chunk_no` INT NOT NULL COMMENT '版本内切片序号，从1开始',
    `parent_chunk_no` INT NULL COMMENT '父级切片序号',
    `source_locator` VARCHAR(1024) NOT NULL COMMENT '解析产物内的受控定位符',
    `title_path` JSON NULL COMMENT '标题层级路径，不保存完整正文',
    `page_start` INT NULL COMMENT '起始页码',
    `page_end` INT NULL COMMENT '结束页码',
    `token_count` INT NULL COMMENT '切片token数量',
    `content_sha256` CHAR(64) NOT NULL COMMENT '切片正文SHA-256',
    `chunk_status` VARCHAR(32) NOT NULL DEFAULT 'PENDING' COMMENT '切片状态[PENDING,INDEXED,FAILED,DELETED]',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_revision_chunk_del` (`organ_id`, `revision_id`, `chunk_no`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_revision_status_del` (`organ_id`, `revision_id`, `chunk_status`, (IF(delete_flag = 0, 0, NULL)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识切片清单表';

-- =============================================
-- 6. 知识处理任务表 (knowledge_task)
-- 含任务输入快照、协作取消与租约 fencing 代次；只供领域 Worker 使用。
-- =============================================
CREATE TABLE `knowledge_task` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `revision_id` BIGINT NOT NULL COMMENT '知识版本标识',
    `task_type` VARCHAR(32) NOT NULL COMMENT '知识处理任务类型[PARSE,INDEX,DELETE_INDEX]；不承载发布、回滚或下线',
    `task_status` VARCHAR(32) NOT NULL DEFAULT 'PENDING' COMMENT '任务状态[PENDING,RUNNING,SUCCESS,FAILED,CANCELED]',
    `idempotency_key` VARCHAR(128) NOT NULL COMMENT '幂等键',
    `input_snapshot` JSON NULL COMMENT '不可变处理输入快照，不含正文或凭据',
    `attempt_no` INT NOT NULL DEFAULT 0 COMMENT '尝试次数',
    `available_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '任务可被领取时间，用于处理任务延迟重试',
    `lease_owner` VARCHAR(128) NULL COMMENT '当前任务工作者标识',
    `lease_expire_time` TIMESTAMP NULL COMMENT '任务领取租约到期时间',
    `lease_generation` BIGINT NOT NULL DEFAULT 0 COMMENT '任务租约 fencing 代次',
    `cancel_requested` TINYINT NOT NULL DEFAULT 0 COMMENT '运行中任务协作取消标识',
    `provider_name` VARCHAR(64) NULL COMMENT '外部提供方名称',
    `model_name` VARCHAR(128) NULL COMMENT '模型标识',
    `trace_id` VARCHAR(64) NULL COMMENT '调用链标识',
    `started_time` TIMESTAMP NULL COMMENT '开始时间',
    `finished_time` TIMESTAMP NULL COMMENT '完成时间',
    `error_code` VARCHAR(64) NULL COMMENT '安全错误码',
    `error_summary` VARCHAR(1024) NULL COMMENT '净化后的错误摘要，不得含原文或Secret',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_task_idempotency_del` (`organ_id`, `idempotency_key`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_revision_type_status_del` (`organ_id`, `revision_id`, `task_type`, `task_status`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_status_available_del` (`organ_id`, `task_status`, `available_time`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_task_dispatch_lease_del` (`task_status`, `available_time`, `lease_expire_time`, (IF(delete_flag = 0, 0, NULL)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识解析与索引处理任务表';

-- =============================================
-- 7. 知识发布选择表 (knowledge_release)
-- =============================================
CREATE TABLE `knowledge_release` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `knowledge_id` BIGINT NOT NULL COMMENT '知识主题标识',
    `active_revision_id` BIGINT NULL COMMENT '当前生产生效版本标识',
    `release_status` VARCHAR(32) NOT NULL DEFAULT 'UNPUBLISHED' COMMENT '发布状态[UNPUBLISHED,PUBLISHED,SUSPENDED]',
    `published_user_id` BIGINT NULL COMMENT '最近发布用户标识',
    `published_time` TIMESTAMP NULL COMMENT '最近发布时间',
    `release_reason` VARCHAR(512) NULL COMMENT '发布或变更原因',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_knowledge_release_del` (`organ_id`, `knowledge_id`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_active_revision_status_del` (`organ_id`, `active_revision_id`, `release_status`, (IF(delete_flag = 0, 0, NULL)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识发布选择表';

-- =============================================
-- 8. 知识回复模板表 (knowledge_answer_template)
-- 按机构维护问答回复模板，模型仍由服务端配置。
-- =============================================
CREATE TABLE `knowledge_answer_template` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `template_code` VARCHAR(64) NOT NULL COMMENT '稳定模板编码，机构内唯一',
    `template_name` VARCHAR(128) NOT NULL COMMENT '模板展示名称',
    `system_prompt` MEDIUMTEXT NOT NULL COMMENT '服务端回复模板内容',
    `status` VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态[ACTIVE,INACTIVE]',
    `remark` VARCHAR(512) NULL COMMENT '管理备注',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_organ_answer_template_code_del` (`organ_id`, `template_code`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_answer_template_status_del` (`organ_id`, `status`, (IF(delete_flag = 0, 0, NULL)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识回复模板表';

-- =============================================
-- 9. 知识反馈表 (knowledge_feedback)
-- =============================================
CREATE TABLE `knowledge_feedback` (
    `id` BIGINT NOT NULL COMMENT '主键标识',
    `organ_id` BIGINT NOT NULL COMMENT '机构标识',
    `revision_id` BIGINT NULL COMMENT '关联知识版本标识',
    `chunk_id` BIGINT NULL COMMENT '关联知识切片标识',
    `trace_id` VARCHAR(64) NULL COMMENT 'Agent调用链标识',
    `feedback_type` VARCHAR(32) NOT NULL COMMENT '反馈类型[LOW_SCORE,WRONG_ANSWER,MANUAL_TAKEOVER,CORRECTED]',
    `feedback_status` VARCHAR(32) NOT NULL DEFAULT 'OPEN' COMMENT '处理状态[OPEN,PROCESSING,RESOLVED,IGNORED]',
    `feedback_summary` VARCHAR(1024) NULL COMMENT '净化后的反馈摘要',
    `corrected_answer` MEDIUMTEXT NULL COMMENT '人工修正答案，受知识运营权限保护',
    `operator_user_id` BIGINT NULL COMMENT '提交或处理用户标识',
    `resolved_user_id` BIGINT NULL COMMENT '解决用户标识',
    `resolved_time` TIMESTAMP NULL COMMENT '解决时间',
    `create_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version` INT NOT NULL DEFAULT 0 COMMENT '记录版本',
    `delete_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标识[0:未删除, 1:已删除]',
    PRIMARY KEY (`id`),
    INDEX `idx_organ_status_type_create_del` (`organ_id`, `feedback_status`, `feedback_type`, `create_time`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_organ_revision_chunk_del` (`organ_id`, `revision_id`, `chunk_id`, (IF(delete_flag = 0, 0, NULL))),
    INDEX `idx_trace_id` (`trace_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='知识反馈表';
