/*
 Navicat Premium Dump SQL

 Source Server         : pglocal
 Source Server Type    : PostgreSQL
 Source Server Version : 160008 (160008)
 Source Host           : localhost:5432
 Source Catalog        : uctoo
 Source Schema         : public

 Target Server Type    : PostgreSQL
 Target Server Version : 160008 (160008)
 File Encoding         : 65001

 Date: 01/04/2026 16:00:31
*/


-- ----------------------------
-- Table structure for admin_applet
-- ----------------------------
DROP TABLE IF EXISTS "public"."admin_applet";
CREATE TABLE "public"."admin_applet" (
  "appid" text COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 1,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "creator" uuid,
  "id" uuid NOT NULL DEFAULT gen_random_uuid()
)
;
COMMENT ON COLUMN "public"."admin_applet"."appid" IS 'appid。应用唯一id，关联WechatopenApplet表appid';
COMMENT ON COLUMN "public"."admin_applet"."status" IS '状态。1=当前操作的应用。0=非当前操作的应用。';
COMMENT ON COLUMN "public"."admin_applet"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."admin_applet"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."admin_applet"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."admin_applet"."creator" IS '创建人';
COMMENT ON TABLE "public"."admin_applet" IS '当前管理的应用。支持统一平台管理多个应用，app、小程序、H5等，记录当前正在操作的应用。管理后台右上角切换当前管理的应用时，编辑此表数据。';

-- ----------------------------
-- Table structure for agent_runtime_status
-- ----------------------------
DROP TABLE IF EXISTS "public"."agent_runtime_status";
CREATE TABLE "public"."agent_runtime_status" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "runtime_version" varchar COLLATE "pg_catalog"."default",
  "status" varchar COLLATE "pg_catalog"."default",
  "port" int4 NOT NULL DEFAULT 8080,
  "host" varchar COLLATE "pg_catalog"."default",
  "pid" int4,
  "started_at" timestamptz(6),
  "stopped_at" timestamptz(6),
  "last_check_at" timestamptz(6),
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."agent_runtime_status"."id" IS '状态记录唯一标识';
COMMENT ON COLUMN "public"."agent_runtime_status"."runtime_version" IS '运行时版本号';
COMMENT ON COLUMN "public"."agent_runtime_status"."status" IS '运行状态';
COMMENT ON COLUMN "public"."agent_runtime_status"."port" IS '监听端口';
COMMENT ON COLUMN "public"."agent_runtime_status"."host" IS '主机地址';
COMMENT ON COLUMN "public"."agent_runtime_status"."pid" IS '进程ID';
COMMENT ON COLUMN "public"."agent_runtime_status"."started_at" IS '启动时间';
COMMENT ON COLUMN "public"."agent_runtime_status"."stopped_at" IS '停止时间';
COMMENT ON COLUMN "public"."agent_runtime_status"."last_check_at" IS '最后检查时间';
COMMENT ON COLUMN "public"."agent_runtime_status"."creator" IS '创建人';
COMMENT ON COLUMN "public"."agent_runtime_status"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."agent_runtime_status"."updated_at" IS '更新时间';
COMMENT ON TABLE "public"."agent_runtime_status" IS 'Agent运行时状态。监控Agent Skills运行时的运行状态、版本、端口等信息。';

-- ----------------------------
-- Table structure for agent_skill_configs
-- ----------------------------
DROP TABLE IF EXISTS "public"."agent_skill_configs";
CREATE TABLE "public"."agent_skill_configs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "skill_id" uuid,
  "config_key" varchar COLLATE "pg_catalog"."default",
  "config_value" varchar COLLATE "pg_catalog"."default",
  "description" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."agent_skill_configs"."id" IS '配置项唯一标识';
COMMENT ON COLUMN "public"."agent_skill_configs"."skill_id" IS '关联的技能ID';
COMMENT ON COLUMN "public"."agent_skill_configs"."config_key" IS '配置键名';
COMMENT ON COLUMN "public"."agent_skill_configs"."config_value" IS '配置值';
COMMENT ON COLUMN "public"."agent_skill_configs"."description" IS '配置说明';
COMMENT ON COLUMN "public"."agent_skill_configs"."creator" IS '创建人';
COMMENT ON COLUMN "public"."agent_skill_configs"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."agent_skill_configs"."updated_at" IS '更新时间';
COMMENT ON TABLE "public"."agent_skill_configs" IS 'Agent技能配置。存储技能的运行时配置项，支持动态配置管理。';

-- ----------------------------
-- Table structure for agent_skill_executions
-- ----------------------------
DROP TABLE IF EXISTS "public"."agent_skill_executions";
CREATE TABLE "public"."agent_skill_executions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "skill_id" uuid,
  "tool_name" varchar COLLATE "pg_catalog"."default",
  "parameters" varchar COLLATE "pg_catalog"."default",
  "result" varchar COLLATE "pg_catalog"."default",
  "success" int4 NOT NULL DEFAULT 0,
  "error_message" varchar COLLATE "pg_catalog"."default",
  "execution_time" int4 NOT NULL DEFAULT 0,
  "started_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finished_at" timestamptz(6),
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."agent_skill_executions"."id" IS '执行记录唯一标识';
COMMENT ON COLUMN "public"."agent_skill_executions"."skill_id" IS '关联的技能ID';
COMMENT ON COLUMN "public"."agent_skill_executions"."tool_name" IS '执行的工具名称';
COMMENT ON COLUMN "public"."agent_skill_executions"."parameters" IS '执行参数（JSON格式）';
COMMENT ON COLUMN "public"."agent_skill_executions"."result" IS '执行结果';
COMMENT ON COLUMN "public"."agent_skill_executions"."success" IS '是否成功。0=失败，1=成功';
COMMENT ON COLUMN "public"."agent_skill_executions"."error_message" IS '错误信息';
COMMENT ON COLUMN "public"."agent_skill_executions"."execution_time" IS '执行时间（毫秒）';
COMMENT ON COLUMN "public"."agent_skill_executions"."started_at" IS '开始时间';
COMMENT ON COLUMN "public"."agent_skill_executions"."finished_at" IS '结束时间';
COMMENT ON COLUMN "public"."agent_skill_executions"."creator" IS '创建人';
COMMENT ON COLUMN "public"."agent_skill_executions"."created_at" IS '创建时间';
COMMENT ON TABLE "public"."agent_skill_executions" IS 'Agent技能执行历史。记录技能的每次执行情况，包括参数、结果、执行时间等。';

-- ----------------------------
-- Table structure for agent_skills
-- ----------------------------
DROP TABLE IF EXISTS "public"."agent_skills";
CREATE TABLE "public"."agent_skills" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default",
  "source" varchar COLLATE "pg_catalog"."default",
  "source_url" varchar COLLATE "pg_catalog"."default",
  "source_type" varchar COLLATE "pg_catalog"."default",
  "branch" varchar COLLATE "pg_catalog"."default",
  "tag" varchar COLLATE "pg_catalog"."default",
  "commit" varchar COLLATE "pg_catalog"."default",
  "version" varchar COLLATE "pg_catalog"."default",
  "author" varchar COLLATE "pg_catalog"."default",
  "homepage" varchar COLLATE "pg_catalog"."default",
  "license" varchar COLLATE "pg_catalog"."default",
  "keywords" varchar COLLATE "pg_catalog"."default",
  "install_path" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "runtime_status" varchar COLLATE "pg_catalog"."default",
  "last_run_at" timestamptz(6),
  "run_count" int4 NOT NULL DEFAULT 0,
  "config" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "allowed_tools" varchar COLLATE "pg_catalog"."default",
  "assets_dir_exists" int4 NOT NULL DEFAULT 0,
  "avg_execution_time" int4 NOT NULL DEFAULT 0,
  "categories" varchar COLLATE "pg_catalog"."default",
  "compatibility" varchar COLLATE "pg_catalog"."default",
  "dependencies" varchar COLLATE "pg_catalog"."default",
  "env_vars" varchar COLLATE "pg_catalog"."default",
  "error_count" int4 NOT NULL DEFAULT 0,
  "extra_metadata" varchar COLLATE "pg_catalog"."default",
  "generation_model" varchar COLLATE "pg_catalog"."default",
  "generation_prompt" varchar COLLATE "pg_catalog"."default",
  "generation_status" varchar COLLATE "pg_catalog"."default",
  "instructions" varchar COLLATE "pg_catalog"."default",
  "last_error" varchar COLLATE "pg_catalog"."default",
  "last_validated_at" timestamptz(6),
  "parameters" varchar COLLATE "pg_catalog"."default",
  "parent_skill_id" uuid,
  "permissions" varchar COLLATE "pg_catalog"."default",
  "references_dir_exists" int4 NOT NULL DEFAULT 0,
  "retry_count" int4 NOT NULL DEFAULT 0,
  "scripts_dir_exists" int4 NOT NULL DEFAULT 0,
  "success_count" int4 NOT NULL DEFAULT 0,
  "tags" varchar COLLATE "pg_catalog"."default",
  "timeout" int4 NOT NULL DEFAULT 30000,
  "validation_errors" varchar COLLATE "pg_catalog"."default",
  "validation_status" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."agent_skills"."id" IS '技能唯一标识';
COMMENT ON COLUMN "public"."agent_skills"."name" IS '技能名称（1-64字符）';
COMMENT ON COLUMN "public"."agent_skills"."description" IS '技能描述（1-1024字符）';
COMMENT ON COLUMN "public"."agent_skills"."source" IS '来源平台（github/gitee/atomgit/local）';
COMMENT ON COLUMN "public"."agent_skills"."source_url" IS '源码仓库URL';
COMMENT ON COLUMN "public"."agent_skills"."source_type" IS '源类型（repository/archive/local）';
COMMENT ON COLUMN "public"."agent_skills"."branch" IS 'Git分支名称';
COMMENT ON COLUMN "public"."agent_skills"."tag" IS 'Git标签名称';
COMMENT ON COLUMN "public"."agent_skills"."commit" IS 'Git提交哈希';
COMMENT ON COLUMN "public"."agent_skills"."version" IS '技能版本号';
COMMENT ON COLUMN "public"."agent_skills"."author" IS '作者';
COMMENT ON COLUMN "public"."agent_skills"."homepage" IS '主页地址';
COMMENT ON COLUMN "public"."agent_skills"."license" IS '许可证';
COMMENT ON COLUMN "public"."agent_skills"."keywords" IS '关键词（逗号分隔）';
COMMENT ON COLUMN "public"."agent_skills"."install_path" IS '安装路径';
COMMENT ON COLUMN "public"."agent_skills"."status" IS '安装状态。0=未安装，1=已安装，2=安装失败，3=已卸载';
COMMENT ON COLUMN "public"."agent_skills"."runtime_status" IS '运行状态';
COMMENT ON COLUMN "public"."agent_skills"."last_run_at" IS '最后运行时间';
COMMENT ON COLUMN "public"."agent_skills"."run_count" IS '总运行次数';
COMMENT ON COLUMN "public"."agent_skills"."config" IS '运行时配置（JSON格式）';
COMMENT ON COLUMN "public"."agent_skills"."creator" IS '创建人';
COMMENT ON COLUMN "public"."agent_skills"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."agent_skills"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."agent_skills"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."agent_skills"."allowed_tools" IS '预批准工具列表（JSON数组）';
COMMENT ON COLUMN "public"."agent_skills"."assets_dir_exists" IS 'assets目录是否存在。0=否，1=是';
COMMENT ON COLUMN "public"."agent_skills"."avg_execution_time" IS '平均执行时间（毫秒）';
COMMENT ON COLUMN "public"."agent_skills"."categories" IS '分类（JSON数组）';
COMMENT ON COLUMN "public"."agent_skills"."compatibility" IS '兼容性要求（最大500字符）';
COMMENT ON COLUMN "public"."agent_skills"."dependencies" IS '依赖列表（JSON数组）';
COMMENT ON COLUMN "public"."agent_skills"."env_vars" IS '环境变量配置（JSON格式）';
COMMENT ON COLUMN "public"."agent_skills"."error_count" IS '错误运行次数';
COMMENT ON COLUMN "public"."agent_skills"."extra_metadata" IS '扩展元数据（JSON格式）';
COMMENT ON COLUMN "public"."agent_skills"."generation_model" IS '生成使用的模型（如gpt-4, claude-3）';
COMMENT ON COLUMN "public"."agent_skills"."generation_prompt" IS 'AI生成提示词';
COMMENT ON COLUMN "public"."agent_skills"."generation_status" IS '生成状态';
COMMENT ON COLUMN "public"."agent_skills"."instructions" IS '技能指令和指南';
COMMENT ON COLUMN "public"."agent_skills"."last_error" IS '最后错误信息';
COMMENT ON COLUMN "public"."agent_skills"."last_validated_at" IS '最后验证时间';
COMMENT ON COLUMN "public"."agent_skills"."parameters" IS '参数定义（JSON数组）';
COMMENT ON COLUMN "public"."agent_skills"."parent_skill_id" IS '父技能ID（用于技能迭代生成）';
COMMENT ON COLUMN "public"."agent_skills"."permissions" IS '权限要求（JSON数组）';
COMMENT ON COLUMN "public"."agent_skills"."references_dir_exists" IS 'references目录是否存在。0=否，1=是';
COMMENT ON COLUMN "public"."agent_skills"."retry_count" IS '重试次数';
COMMENT ON COLUMN "public"."agent_skills"."scripts_dir_exists" IS 'scripts目录是否存在。0=否，1=是';
COMMENT ON COLUMN "public"."agent_skills"."success_count" IS '成功运行次数';
COMMENT ON COLUMN "public"."agent_skills"."tags" IS '标签（JSON数组）';
COMMENT ON COLUMN "public"."agent_skills"."timeout" IS '执行超时时间（毫秒）';
COMMENT ON COLUMN "public"."agent_skills"."validation_errors" IS '验证错误信息（JSON）';
COMMENT ON COLUMN "public"."agent_skills"."validation_status" IS '验证状态';
COMMENT ON TABLE "public"."agent_skills" IS 'Agent技能管理。用于管理Agent Skills运行时的技能包，支持从GitHub、Gitee、AtomGit等平台搜索和安装技能，支持AI大模型生成技能。';

-- ----------------------------
-- Table structure for ai_client
-- ----------------------------
DROP TABLE IF EXISTS "public"."ai_client";
CREATE TABLE "public"."ai_client" (
  "id" int4 NOT NULL DEFAULT 1,
  "domain" varchar COLLATE "pg_catalog"."default",
  "username" varchar COLLATE "pg_catalog"."default",
  "password" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "token_overtime" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "creator" uuid
)
;
COMMENT ON COLUMN "public"."ai_client"."id" IS 'id';
COMMENT ON COLUMN "public"."ai_client"."domain" IS '域名';
COMMENT ON COLUMN "public"."ai_client"."username" IS '用户名';
COMMENT ON COLUMN "public"."ai_client"."password" IS '用户密码';
COMMENT ON COLUMN "public"."ai_client"."token" IS 'token';
COMMENT ON COLUMN "public"."ai_client"."token_overtime" IS 'token过期时间';
COMMENT ON COLUMN "public"."ai_client"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."ai_client"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."ai_client"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."ai_client"."creator" IS '创建人';
COMMENT ON TABLE "public"."ai_client" IS 'AI客户端信息';

-- ----------------------------
-- Table structure for app_access_token
-- ----------------------------
DROP TABLE IF EXISTS "public"."app_access_token";
CREATE TABLE "public"."app_access_token" (
  "id" text COLLATE "pg_catalog"."default" NOT NULL,
  "access_token" varchar COLLATE "pg_catalog"."default",
  "token_overtime" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."app_access_token"."id" IS '关联各应用表的appid';
COMMENT ON COLUMN "public"."app_access_token"."access_token" IS 'access_token';
COMMENT ON COLUMN "public"."app_access_token"."token_overtime" IS '过期时间';
COMMENT ON COLUMN "public"."app_access_token"."creator" IS '创建人';
COMMENT ON COLUMN "public"."app_access_token"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."app_access_token"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."app_access_token"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."app_access_token" IS '应用access_token，常用于数据库作为sdk缓存使用';

-- ----------------------------
-- Table structure for application
-- ----------------------------
DROP TABLE IF EXISTS "public"."application";
CREATE TABLE "public"."application" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "icon" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "tag" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "classify" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."application"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."application"."name" IS '应用名称';
COMMENT ON COLUMN "public"."application"."description" IS '应用描述';
COMMENT ON COLUMN "public"."application"."icon" IS '图标';
COMMENT ON COLUMN "public"."application"."tag" IS '标签';
COMMENT ON COLUMN "public"."application"."classify" IS '分类';
COMMENT ON COLUMN "public"."application"."creator" IS '创建人ID';
COMMENT ON COLUMN "public"."application"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."application"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."application"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."application" IS '应用管理';

-- ----------------------------
-- Table structure for attachments
-- ----------------------------
DROP TABLE IF EXISTS "public"."attachments";
CREATE TABLE "public"."attachments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "path" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "url" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "mime_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "file_ext" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "filesize" int4 NOT NULL DEFAULT 0,
  "filename" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "driver" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "scene" varchar COLLATE "pg_catalog"."default",
  "type" varchar COLLATE "pg_catalog"."default",
  "sc_id" int4,
  "ai_task_id" int4,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "creator" uuid
)
;
COMMENT ON COLUMN "public"."attachments"."path" IS '附件存储路径';
COMMENT ON COLUMN "public"."attachments"."url" IS '资源URL地址';
COMMENT ON COLUMN "public"."attachments"."mime_type" IS '资源mimeType';
COMMENT ON COLUMN "public"."attachments"."file_ext" IS '资源后缀';
COMMENT ON COLUMN "public"."attachments"."filesize" IS '资源大小';
COMMENT ON COLUMN "public"."attachments"."filename" IS '资源名称';
COMMENT ON COLUMN "public"."attachments"."driver" IS 'local,oss,qcloud,qiniu,huaweicloud';
COMMENT ON COLUMN "public"."attachments"."scene" IS '场景值';
COMMENT ON COLUMN "public"."attachments"."type" IS '类型';
COMMENT ON COLUMN "public"."attachments"."sc_id" IS '内容安全id';
COMMENT ON COLUMN "public"."attachments"."ai_task_id" IS 'AI任务id';
COMMENT ON COLUMN "public"."attachments"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."attachments"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."attachments"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."attachments"."creator" IS '创建人';
COMMENT ON TABLE "public"."attachments" IS '上传资源表';

-- ----------------------------
-- Table structure for chat_conversations
-- ----------------------------
DROP TABLE IF EXISTS "public"."chat_conversations";
CREATE TABLE "public"."chat_conversations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default",
  "model_provider" varchar COLLATE "pg_catalog"."default",
  "model_name" varchar COLLATE "pg_catalog"."default",
  "system_prompt" text COLLATE "pg_catalog"."default",
  "temperature" float8 NOT NULL DEFAULT 0.7,
  "max_tokens" int4 NOT NULL DEFAULT 4096,
  "status" int4 NOT NULL DEFAULT 1,
  "skill_ids" varchar COLLATE "pg_catalog"."default",
  "metadata" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."chat_conversations"."id" IS '会话唯一标识';
COMMENT ON COLUMN "public"."chat_conversations"."title" IS '会话标题';
COMMENT ON COLUMN "public"."chat_conversations"."model_provider" IS '模型提供商';
COMMENT ON COLUMN "public"."chat_conversations"."model_name" IS '模型名称';
COMMENT ON COLUMN "public"."chat_conversations"."system_prompt" IS '系统提示';
COMMENT ON COLUMN "public"."chat_conversations"."temperature" IS '温度参数';
COMMENT ON COLUMN "public"."chat_conversations"."max_tokens" IS '最大令牌数';
COMMENT ON COLUMN "public"."chat_conversations"."status" IS '会话状态';
COMMENT ON COLUMN "public"."chat_conversations"."skill_ids" IS '技能ID列表';
COMMENT ON COLUMN "public"."chat_conversations"."metadata" IS '元数据';
COMMENT ON COLUMN "public"."chat_conversations"."creator" IS '创建人';
COMMENT ON COLUMN "public"."chat_conversations"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."chat_conversations"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."chat_conversations"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."chat_conversations" IS '聊天会话表。存储智能体聊天会话的基本信息，包括模型配置、系统提示、状态等。';

-- ----------------------------
-- Table structure for chat_messages
-- ----------------------------
DROP TABLE IF EXISTS "public"."chat_messages";
CREATE TABLE "public"."chat_messages" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "conversation_id" uuid NOT NULL,
  "role" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" text COLLATE "pg_catalog"."default" NOT NULL,
  "tokens_used" int4 NOT NULL DEFAULT 0,
  "skill_executed" uuid,
  "skill_result" text COLLATE "pg_catalog"."default",
  "metadata" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."chat_messages"."id" IS '消息唯一标识';
COMMENT ON COLUMN "public"."chat_messages"."conversation_id" IS '关联的会话ID';
COMMENT ON COLUMN "public"."chat_messages"."role" IS '消息角色';
COMMENT ON COLUMN "public"."chat_messages"."content" IS '消息内容';
COMMENT ON COLUMN "public"."chat_messages"."tokens_used" IS '使用的令牌数';
COMMENT ON COLUMN "public"."chat_messages"."skill_executed" IS '执行的技能ID';
COMMENT ON COLUMN "public"."chat_messages"."skill_result" IS '技能执行结果';
COMMENT ON COLUMN "public"."chat_messages"."metadata" IS '元数据';
COMMENT ON COLUMN "public"."chat_messages"."creator" IS '创建人';
COMMENT ON COLUMN "public"."chat_messages"."created_at" IS '创建时间';
COMMENT ON TABLE "public"."chat_messages" IS '聊天消息表。存储聊天会话中的具体消息，包括角色、内容、令牌使用情况、技能执行信息等。';

-- ----------------------------
-- Table structure for cms_article_relate_tags
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_article_relate_tags";
CREATE TABLE "public"."cms_article_relate_tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "article_id" uuid NOT NULL,
  "tag_id" uuid NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "creator" uuid
)
;
COMMENT ON COLUMN "public"."cms_article_relate_tags"."id" IS 'id';
COMMENT ON COLUMN "public"."cms_article_relate_tags"."article_id" IS '文章id。关联CMSArticles表id';
COMMENT ON COLUMN "public"."cms_article_relate_tags"."tag_id" IS 'tag id。关联CmsTags表id';
COMMENT ON COLUMN "public"."cms_article_relate_tags"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_article_relate_tags"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_article_relate_tags"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."cms_article_relate_tags"."creator" IS '创建人';
COMMENT ON TABLE "public"."cms_article_relate_tags" IS '内容管理模块文章关联tag';

-- ----------------------------
-- Table structure for cms_articles
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_articles";
CREATE TABLE "public"."cms_articles" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default",
  "cover" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "images" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "url" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "keywords" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "pv" int4 NOT NULL DEFAULT 0,
  "likes" int4 NOT NULL DEFAULT 0,
  "comment_num" int4 NOT NULL DEFAULT 0,
  "is_top" int4 NOT NULL DEFAULT 0,
  "is_recommend" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 0,
  "weight" int4 NOT NULL DEFAULT 0,
  "is_can_comment" int4 NOT NULL DEFAULT 0,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "creator" uuid,
  "category_id" uuid
)
;
COMMENT ON COLUMN "public"."cms_articles"."id" IS 'id';
COMMENT ON COLUMN "public"."cms_articles"."title" IS '标题';
COMMENT ON COLUMN "public"."cms_articles"."cover" IS '封面';
COMMENT ON COLUMN "public"."cms_articles"."images" IS '内容banner多图';
COMMENT ON COLUMN "public"."cms_articles"."url" IS '自定义文章url地址';
COMMENT ON COLUMN "public"."cms_articles"."content" IS '文章详情。支持html，支持富文本编辑器';
COMMENT ON COLUMN "public"."cms_articles"."keywords" IS '关键词';
COMMENT ON COLUMN "public"."cms_articles"."description" IS '简介。用于分享时的副标题等';
COMMENT ON COLUMN "public"."cms_articles"."pv" IS '浏览量';
COMMENT ON COLUMN "public"."cms_articles"."likes" IS '点赞量';
COMMENT ON COLUMN "public"."cms_articles"."comment_num" IS '评论数';
COMMENT ON COLUMN "public"."cms_articles"."is_top" IS '是否置顶。0否。1是。';
COMMENT ON COLUMN "public"."cms_articles"."is_recommend" IS '是否首页推荐。0否。1是。';
COMMENT ON COLUMN "public"."cms_articles"."status" IS '状态。0 隐藏。1 展示 ';
COMMENT ON COLUMN "public"."cms_articles"."weight" IS '文章权重。排序';
COMMENT ON COLUMN "public"."cms_articles"."is_can_comment" IS '是否可以评论。0 不允许。1 允许 ';
COMMENT ON COLUMN "public"."cms_articles"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_articles"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_articles"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."cms_articles"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_articles"."category_id" IS '分类ID。关联CmsCategory表id';
COMMENT ON TABLE "public"."cms_articles" IS 'CMS文章表';

-- ----------------------------
-- Table structure for cms_banners
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_banners";
CREATE TABLE "public"."cms_banners" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "banner_img" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "category_id" uuid,
  "link_to" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."cms_banners"."id" IS 'id';
COMMENT ON COLUMN "public"."cms_banners"."title" IS 'banner 标题';
COMMENT ON COLUMN "public"."cms_banners"."banner_img" IS 'banner 图片';
COMMENT ON COLUMN "public"."cms_banners"."category_id" IS '关联CmsCategory表id。默认 0 代表首页展示。也可自定义首页组id';
COMMENT ON COLUMN "public"."cms_banners"."link_to" IS '链接地址';
COMMENT ON COLUMN "public"."cms_banners"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_banners"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_banners"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_banners"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_banners" IS '内容管理banner。';

-- ----------------------------
-- Table structure for cms_category
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_category";
CREATE TABLE "public"."cms_category" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default",
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "keywords" varchar COLLATE "pg_catalog"."default",
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "url" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "is_can_contribute" int4 NOT NULL DEFAULT 0,
  "is_can_comment" int4 NOT NULL DEFAULT 0,
  "type" int4 NOT NULL DEFAULT 0,
  "weight" int4 NOT NULL DEFAULT 0,
  "link_to" varchar COLLATE "pg_catalog"."default",
  "limit" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "parent_id" uuid
)
;
COMMENT ON COLUMN "public"."cms_category"."id" IS 'id';
COMMENT ON COLUMN "public"."cms_category"."name" IS '栏目名称';
COMMENT ON COLUMN "public"."cms_category"."title" IS '标题';
COMMENT ON COLUMN "public"."cms_category"."keywords" IS '关键词';
COMMENT ON COLUMN "public"."cms_category"."description" IS '描述';
COMMENT ON COLUMN "public"."cms_category"."url" IS '自定义 URL';
COMMENT ON COLUMN "public"."cms_category"."status" IS '状态。0隐藏。1显示';
COMMENT ON COLUMN "public"."cms_category"."is_can_contribute" IS '是否可以投稿。0否。1是。';
COMMENT ON COLUMN "public"."cms_category"."is_can_comment" IS '是否可以评论。0否。1是。';
COMMENT ON COLUMN "public"."cms_category"."type" IS '页面模式';
COMMENT ON COLUMN "public"."cms_category"."weight" IS '权重';
COMMENT ON COLUMN "public"."cms_category"."link_to" IS '链接外部地址';
COMMENT ON COLUMN "public"."cms_category"."limit" IS '每页数量';
COMMENT ON COLUMN "public"."cms_category"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_category"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_category"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_category"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_category" IS '内容类目';

-- ----------------------------
-- Table structure for cms_comments
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_comments";
CREATE TABLE "public"."cms_comments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "article_id" uuid NOT NULL,
  "content" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "user_id" uuid NOT NULL,
  "ip" uuid NOT NULL,
  "user_agent" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "parent_id" uuid
)
;
COMMENT ON COLUMN "public"."cms_comments"."id" IS 'id';
COMMENT ON COLUMN "public"."cms_comments"."article_id" IS '文章id';
COMMENT ON COLUMN "public"."cms_comments"."content" IS '内容';
COMMENT ON COLUMN "public"."cms_comments"."user_id" IS '评论者ID';
COMMENT ON COLUMN "public"."cms_comments"."ip" IS 'ip 地址';
COMMENT ON COLUMN "public"."cms_comments"."user_agent" IS 'agent';
COMMENT ON COLUMN "public"."cms_comments"."status" IS '状态。1 展示 0 隐藏';
COMMENT ON COLUMN "public"."cms_comments"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_comments"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_comments"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_comments"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_comments" IS '内容评论';

-- ----------------------------
-- Table structure for cms_form_data
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_form_data";
CREATE TABLE "public"."cms_form_data" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "form_id" uuid NOT NULL,
  "form_data" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "user_id" uuid NOT NULL,
  "ip" uuid NOT NULL,
  "user_agent" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."cms_form_data"."form_id" IS '表单ID。关联CmsForms表id';
COMMENT ON COLUMN "public"."cms_form_data"."form_data" IS '数据内容。json字段';
COMMENT ON COLUMN "public"."cms_form_data"."user_id" IS '用户ID';
COMMENT ON COLUMN "public"."cms_form_data"."ip" IS 'ip 地址';
COMMENT ON COLUMN "public"."cms_form_data"."user_agent" IS '客户端agent';
COMMENT ON COLUMN "public"."cms_form_data"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_form_data"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_form_data"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_form_data"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_form_data" IS '动态表单数据';

-- ----------------------------
-- Table structure for cms_form_fields
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_form_fields";
CREATE TABLE "public"."cms_form_fields" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "form_id" uuid NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "default_value" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "failed_message" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "label" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "length" int4 NOT NULL DEFAULT 0,
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "rule" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL
)
;
COMMENT ON COLUMN "public"."cms_form_fields"."form_id" IS 'form id';
COMMENT ON COLUMN "public"."cms_form_fields"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_form_fields"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_form_fields"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_form_fields"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."cms_form_fields"."default_value" IS '默认值';
COMMENT ON COLUMN "public"."cms_form_fields"."failed_message" IS '验证失败信息';
COMMENT ON COLUMN "public"."cms_form_fields"."label" IS '字段 label';
COMMENT ON COLUMN "public"."cms_form_fields"."length" IS '字段长度';
COMMENT ON COLUMN "public"."cms_form_fields"."name" IS '表单字段name';
COMMENT ON COLUMN "public"."cms_form_fields"."rule" IS '验证规则';
COMMENT ON COLUMN "public"."cms_form_fields"."status" IS '状态。1 展示 0 隐藏';
COMMENT ON COLUMN "public"."cms_form_fields"."type" IS '类型';
COMMENT ON TABLE "public"."cms_form_fields" IS '动态表单字段';

-- ----------------------------
-- Table structure for cms_forms
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_forms";
CREATE TABLE "public"."cms_forms" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "alias" varchar COLLATE "pg_catalog"."default",
  "submit_url" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "keywords" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "success_message" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "failed_message" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "success_link_to" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "is_login_to_submit" int4 NOT NULL DEFAULT 1,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."cms_forms"."name" IS '表单名称';
COMMENT ON COLUMN "public"."cms_forms"."alias" IS '表单别名';
COMMENT ON COLUMN "public"."cms_forms"."submit_url" IS '表单提交的 URL';
COMMENT ON COLUMN "public"."cms_forms"."title" IS '表单标题';
COMMENT ON COLUMN "public"."cms_forms"."keywords" IS '关键词';
COMMENT ON COLUMN "public"."cms_forms"."description" IS '描述';
COMMENT ON COLUMN "public"."cms_forms"."success_message" IS '成功提示信息';
COMMENT ON COLUMN "public"."cms_forms"."failed_message" IS '失败提示信息';
COMMENT ON COLUMN "public"."cms_forms"."success_link_to" IS '成功后跳转url';
COMMENT ON COLUMN "public"."cms_forms"."is_login_to_submit" IS '是否需登录。1 需要 0 不需要';
COMMENT ON COLUMN "public"."cms_forms"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_forms"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_forms"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_forms"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_forms" IS '动态表单';

-- ----------------------------
-- Table structure for cms_model_auxiliary_table
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_model_auxiliary_table";
CREATE TABLE "public"."cms_model_auxiliary_table" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "model_id" uuid NOT NULL,
  "alias" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "table_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "used" int4 NOT NULL DEFAULT 1
)
;
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."model_id" IS '模型ID';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."alias" IS '模型别名';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."table_name" IS '副表表明';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."description" IS '模型关联的表名,数据来源';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."cms_model_auxiliary_table"."used" IS '默认使用。 0 不使用 1 使用';
COMMENT ON TABLE "public"."cms_model_auxiliary_table" IS '动态模型表';

-- ----------------------------
-- Table structure for cms_model_fields
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_model_fields";
CREATE TABLE "public"."cms_model_fields" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "length" varchar COLLATE "pg_catalog"."default",
  "default_value" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "options" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "is_index" int4 NOT NULL DEFAULT 0,
  "is_unique" int4 NOT NULL DEFAULT 0,
  "rules" varchar COLLATE "pg_catalog"."default",
  "pattern" varchar COLLATE "pg_catalog"."default",
  "model_id" uuid NOT NULL,
  "weight" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "used_at_detail" int4 NOT NULL DEFAULT 1,
  "used_at_search" int4 NOT NULL DEFAULT 1,
  "used_at_list" int4 NOT NULL DEFAULT 1
)
;
COMMENT ON COLUMN "public"."cms_model_fields"."title" IS '字段中文名称';
COMMENT ON COLUMN "public"."cms_model_fields"."name" IS '表单字段名称';
COMMENT ON COLUMN "public"."cms_model_fields"."type" IS '类型';
COMMENT ON COLUMN "public"."cms_model_fields"."length" IS '字段长度';
COMMENT ON COLUMN "public"."cms_model_fields"."default_value" IS '默认值';
COMMENT ON COLUMN "public"."cms_model_fields"."options" IS '选项';
COMMENT ON COLUMN "public"."cms_model_fields"."is_index" IS '是否是索引。 1 是 0 否';
COMMENT ON COLUMN "public"."cms_model_fields"."is_unique" IS '是否唯一。 1 是 0 否';
COMMENT ON COLUMN "public"."cms_model_fields"."rules" IS '验证规则';
COMMENT ON COLUMN "public"."cms_model_fields"."pattern" IS '正则';
COMMENT ON COLUMN "public"."cms_model_fields"."model_id" IS '模型ID';
COMMENT ON COLUMN "public"."cms_model_fields"."weight" IS '排序';
COMMENT ON COLUMN "public"."cms_model_fields"."status" IS '状态 1显示 0隐藏';
COMMENT ON COLUMN "public"."cms_model_fields"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_model_fields"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_model_fields"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_model_fields"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."cms_model_fields"."used_at_detail" IS '展示在详情 1 是 0 否';
COMMENT ON COLUMN "public"."cms_model_fields"."used_at_search" IS '用作是否搜索 1 是 0 否';
COMMENT ON COLUMN "public"."cms_model_fields"."used_at_list" IS '展示在列表 1 是 0 否';
COMMENT ON TABLE "public"."cms_model_fields" IS '动态模型字段';

-- ----------------------------
-- Table structure for cms_models
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_models";
CREATE TABLE "public"."cms_models" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "alias" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "table_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "used_at_detail" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "used_at_search" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "used_at_list" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."cms_models"."name" IS '模型名称';
COMMENT ON COLUMN "public"."cms_models"."alias" IS '模型别名';
COMMENT ON COLUMN "public"."cms_models"."table_name" IS '模型关联的表名,数据来源';
COMMENT ON COLUMN "public"."cms_models"."description" IS '模型描述';
COMMENT ON COLUMN "public"."cms_models"."used_at_detail" IS '用在详情的字段';
COMMENT ON COLUMN "public"."cms_models"."used_at_search" IS '用在搜索的字段';
COMMENT ON COLUMN "public"."cms_models"."used_at_list" IS '用在列表的字段';
COMMENT ON COLUMN "public"."cms_models"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_models"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_models"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_models"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_models" IS '动态模型';

-- ----------------------------
-- Table structure for cms_site_links
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_site_links";
CREATE TABLE "public"."cms_site_links" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "link_to" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "weight" int4 NOT NULL DEFAULT 0,
  "is_show" int4 NOT NULL DEFAULT 1,
  "icon" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."cms_site_links"."title" IS '友情链接标题';
COMMENT ON COLUMN "public"."cms_site_links"."link_to" IS '跳转地址';
COMMENT ON COLUMN "public"."cms_site_links"."weight" IS '权重';
COMMENT ON COLUMN "public"."cms_site_links"."is_show" IS '是否显示。1 展示 0 隐藏';
COMMENT ON COLUMN "public"."cms_site_links"."icon" IS '网站图标';
COMMENT ON COLUMN "public"."cms_site_links"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_site_links"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_site_links"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_site_links"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_site_links" IS '内容管理网站链接';

-- ----------------------------
-- Table structure for cms_tags
-- ----------------------------
DROP TABLE IF EXISTS "public"."cms_tags";
CREATE TABLE "public"."cms_tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "keywords" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."cms_tags"."name" IS '标签名称';
COMMENT ON COLUMN "public"."cms_tags"."title" IS 'seo 标题';
COMMENT ON COLUMN "public"."cms_tags"."keywords" IS '关键字';
COMMENT ON COLUMN "public"."cms_tags"."description" IS '描述';
COMMENT ON COLUMN "public"."cms_tags"."creator" IS '创建人';
COMMENT ON COLUMN "public"."cms_tags"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."cms_tags"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."cms_tags"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."cms_tags" IS '内容管理标签。不推荐使用。推荐统一使用tag表';

-- ----------------------------
-- Table structure for codelabs
-- ----------------------------
DROP TABLE IF EXISTS "public"."codelabs";
CREATE TABLE "public"."codelabs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "command" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "arguments" varchar COLLATE "pg_catalog"."default",
  "data_structure" varchar COLLATE "pg_catalog"."default",
  "template_code" varchar COLLATE "pg_catalog"."default",
  "config_data" varchar COLLATE "pg_catalog"."default",
  "algorithm" varchar COLLATE "pg_catalog"."default",
  "result" varchar COLLATE "pg_catalog"."default",
  "input" varchar COLLATE "pg_catalog"."default",
  "output" varchar COLLATE "pg_catalog"."default",
  "remark" varchar COLLATE "pg_catalog"."default",
  "template_file" varchar COLLATE "pg_catalog"."default",
  "data_source" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."codelabs"."command" IS '命令名称';
COMMENT ON COLUMN "public"."codelabs"."arguments" IS '命令参数。json格式';
COMMENT ON COLUMN "public"."codelabs"."data_structure" IS '数据结构';
COMMENT ON COLUMN "public"."codelabs"."template_code" IS '模板代码';
COMMENT ON COLUMN "public"."codelabs"."config_data" IS '用户配置';
COMMENT ON COLUMN "public"."codelabs"."algorithm" IS '算法';
COMMENT ON COLUMN "public"."codelabs"."result" IS '结果';
COMMENT ON COLUMN "public"."codelabs"."input" IS '输入配置';
COMMENT ON COLUMN "public"."codelabs"."output" IS '输出配置';
COMMENT ON COLUMN "public"."codelabs"."remark" IS '备注';
COMMENT ON COLUMN "public"."codelabs"."template_file" IS '模板文件';
COMMENT ON COLUMN "public"."codelabs"."data_source" IS '数据源';
COMMENT ON COLUMN "public"."codelabs"."creator" IS '创建人';
COMMENT ON COLUMN "public"."codelabs"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."codelabs"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."codelabs"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."codelabs" IS '代码生成记录表';

-- ----------------------------
-- Table structure for codelabs_algorithm
-- ----------------------------
DROP TABLE IF EXISTS "public"."codelabs_algorithm";
CREATE TABLE "public"."codelabs_algorithm" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "command_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "algorithm_code" varchar COLLATE "pg_catalog"."default",
  "filename" varchar COLLATE "pg_catalog"."default",
  "filepath" varchar COLLATE "pg_catalog"."default",
  "template_url" varchar COLLATE "pg_catalog"."default",
  "opensource" int4 DEFAULT 0,
  "author" varchar COLLATE "pg_catalog"."default",
  "author_url" varchar COLLATE "pg_catalog"."default",
  "user_id" uuid,
  "tags" varchar COLLATE "pg_catalog"."default",
  "docs" varchar COLLATE "pg_catalog"."default",
  "images" varchar COLLATE "pg_catalog"."default",
  "description" varchar COLLATE "pg_catalog"."default",
  "price" float8 DEFAULT 0,
  "status" int4 DEFAULT 0,
  "arguments" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."codelabs_algorithm"."command_name" IS '命令名称';
COMMENT ON COLUMN "public"."codelabs_algorithm"."algorithm_code" IS '算法代码';
COMMENT ON COLUMN "public"."codelabs_algorithm"."filename" IS '算法文件名';
COMMENT ON COLUMN "public"."codelabs_algorithm"."filepath" IS '算法文件路径';
COMMENT ON COLUMN "public"."codelabs_algorithm"."template_url" IS '算法url地址';
COMMENT ON COLUMN "public"."codelabs_algorithm"."opensource" IS '是否开源';
COMMENT ON COLUMN "public"."codelabs_algorithm"."author" IS '作者';
COMMENT ON COLUMN "public"."codelabs_algorithm"."author_url" IS '作者url';
COMMENT ON COLUMN "public"."codelabs_algorithm"."user_id" IS '用户id。关联user表id';
COMMENT ON COLUMN "public"."codelabs_algorithm"."tags" IS '算法标签';
COMMENT ON COLUMN "public"."codelabs_algorithm"."docs" IS '算法文档';
COMMENT ON COLUMN "public"."codelabs_algorithm"."images" IS '算法图片';
COMMENT ON COLUMN "public"."codelabs_algorithm"."description" IS '算法描述';
COMMENT ON COLUMN "public"."codelabs_algorithm"."price" IS '算法标价';
COMMENT ON COLUMN "public"."codelabs_algorithm"."status" IS '算法状态';
COMMENT ON COLUMN "public"."codelabs_algorithm"."arguments" IS '命令参数。json格式';
COMMENT ON COLUMN "public"."codelabs_algorithm"."creator" IS '创建人';
COMMENT ON COLUMN "public"."codelabs_algorithm"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."codelabs_algorithm"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."codelabs_algorithm"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."codelabs_algorithm" IS '代码生成算法';

-- ----------------------------
-- Table structure for codelabs_templates
-- ----------------------------
DROP TABLE IF EXISTS "public"."codelabs_templates";
CREATE TABLE "public"."codelabs_templates" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "template_code" varchar COLLATE "pg_catalog"."default",
  "filename" varchar COLLATE "pg_catalog"."default",
  "filepath" varchar COLLATE "pg_catalog"."default",
  "config_header" varchar COLLATE "pg_catalog"."default",
  "config_json" varchar COLLATE "pg_catalog"."default",
  "template_url" varchar COLLATE "pg_catalog"."default",
  "opensource" int4 DEFAULT 0,
  "author" varchar COLLATE "pg_catalog"."default",
  "author_url" varchar COLLATE "pg_catalog"."default",
  "user_id" uuid,
  "tags" varchar COLLATE "pg_catalog"."default",
  "docs" varchar COLLATE "pg_catalog"."default",
  "images" varchar COLLATE "pg_catalog"."default",
  "description" varchar COLLATE "pg_catalog"."default",
  "price" float8 DEFAULT 0,
  "status" int4 DEFAULT 0,
  "arguments" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."codelabs_templates"."name" IS '模板名称';
COMMENT ON COLUMN "public"."codelabs_templates"."template_code" IS '模板代码';
COMMENT ON COLUMN "public"."codelabs_templates"."filename" IS '模板文件名';
COMMENT ON COLUMN "public"."codelabs_templates"."filepath" IS '模板路径';
COMMENT ON COLUMN "public"."codelabs_templates"."config_header" IS '模板配置表头';
COMMENT ON COLUMN "public"."codelabs_templates"."config_json" IS '模板配置项';
COMMENT ON COLUMN "public"."codelabs_templates"."template_url" IS '模板url地址';
COMMENT ON COLUMN "public"."codelabs_templates"."opensource" IS '是否开源';
COMMENT ON COLUMN "public"."codelabs_templates"."author" IS '作者';
COMMENT ON COLUMN "public"."codelabs_templates"."author_url" IS '作者url';
COMMENT ON COLUMN "public"."codelabs_templates"."user_id" IS '用户id。关联user表id';
COMMENT ON COLUMN "public"."codelabs_templates"."tags" IS '模板标签';
COMMENT ON COLUMN "public"."codelabs_templates"."docs" IS '模板文档';
COMMENT ON COLUMN "public"."codelabs_templates"."images" IS '模板图片';
COMMENT ON COLUMN "public"."codelabs_templates"."description" IS '模板描述';
COMMENT ON COLUMN "public"."codelabs_templates"."price" IS '模板标价';
COMMENT ON COLUMN "public"."codelabs_templates"."status" IS '模板状态';
COMMENT ON COLUMN "public"."codelabs_templates"."arguments" IS '模板参数';
COMMENT ON COLUMN "public"."codelabs_templates"."creator" IS '创建人';
COMMENT ON COLUMN "public"."codelabs_templates"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."codelabs_templates"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."codelabs_templates"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."codelabs_templates" IS '代码生成模板';

-- ----------------------------
-- Table structure for company
-- ----------------------------
DROP TABLE IF EXISTS "public"."company";
CREATE TABLE "public"."company" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "company_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "region" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "social_credit_code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "established_time" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "registered_capital" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "registered_address" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "mailing_address" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "legal_representative" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "legal_representativeMobile" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "legal_representative_email" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "contact_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "contact_mobile" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "contact_email" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "contact_title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "website" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "company_logo" varchar COLLATE "pg_catalog"."default",
  "associated_project_manager" varchar COLLATE "pg_catalog"."default",
  "verified" int4 NOT NULL DEFAULT 0,
  "company_introduction" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "business_licence" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."company"."company_name" IS '公司名称';
COMMENT ON COLUMN "public"."company"."region" IS '公司所在地';
COMMENT ON COLUMN "public"."company"."social_credit_code" IS '统一社会信用代码';
COMMENT ON COLUMN "public"."company"."established_time" IS '注册时间';
COMMENT ON COLUMN "public"."company"."registered_capital" IS '注册资本';
COMMENT ON COLUMN "public"."company"."registered_address" IS '注册地址';
COMMENT ON COLUMN "public"."company"."mailing_address" IS '通信地址';
COMMENT ON COLUMN "public"."company"."legal_representative" IS '法人姓名';
COMMENT ON COLUMN "public"."company"."legal_representativeMobile" IS '法人手机号';
COMMENT ON COLUMN "public"."company"."legal_representative_email" IS '法人邮箱';
COMMENT ON COLUMN "public"."company"."contact_name" IS '联系人姓名';
COMMENT ON COLUMN "public"."company"."contact_mobile" IS '联系人手机号';
COMMENT ON COLUMN "public"."company"."contact_email" IS '联系人邮箱';
COMMENT ON COLUMN "public"."company"."contact_title" IS '联系人职务';
COMMENT ON COLUMN "public"."company"."website" IS '官方网址';
COMMENT ON COLUMN "public"."company"."company_logo" IS '公司logo';
COMMENT ON COLUMN "public"."company"."associated_project_manager" IS '关联客户代表';
COMMENT ON COLUMN "public"."company"."verified" IS '企业实名认证';
COMMENT ON COLUMN "public"."company"."company_introduction" IS '公司介绍';
COMMENT ON COLUMN "public"."company"."business_licence" IS '公司营业执照';
COMMENT ON COLUMN "public"."company"."creator" IS '创建人';
COMMENT ON COLUMN "public"."company"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."company"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."company"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."company" IS '公司信息';

-- ----------------------------
-- Table structure for component_setting
-- ----------------------------
DROP TABLE IF EXISTS "public"."component_setting";
CREATE TABLE "public"."component_setting" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "table_catalog" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "table_schema" varchar COLLATE "pg_catalog"."default",
  "table_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "page_name" varchar COLLATE "pg_catalog"."default",
  "component_name" varchar COLLATE "pg_catalog"."default",
  "route" varchar COLLATE "pg_catalog"."default",
  "selected_table_column" varchar COLLATE "pg_catalog"."default",
  "selected_form_column" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."component_setting"."id" IS 'id';
COMMENT ON COLUMN "public"."component_setting"."table_catalog" IS '表分组。即数据库名';
COMMENT ON COLUMN "public"."component_setting"."table_schema" IS 'table_schema';
COMMENT ON COLUMN "public"."component_setting"."table_name" IS '表名';
COMMENT ON COLUMN "public"."component_setting"."page_name" IS '页面名';
COMMENT ON COLUMN "public"."component_setting"."component_name" IS '组件名';
COMMENT ON COLUMN "public"."component_setting"."route" IS '路由';
COMMENT ON COLUMN "public"."component_setting"."selected_table_column" IS '已选的表列';
COMMENT ON COLUMN "public"."component_setting"."selected_form_column" IS '已选的表单列';
COMMENT ON COLUMN "public"."component_setting"."creator" IS '创建人';
COMMENT ON COLUMN "public"."component_setting"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."component_setting"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."component_setting"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."component_setting" IS '组件配置';

-- ----------------------------
-- Table structure for config
-- ----------------------------
DROP TABLE IF EXISTS "public"."config";
CREATE TABLE "public"."config" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "parent_id" uuid,
  "component" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "key" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 1,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."config"."name" IS '配置名称';
COMMENT ON COLUMN "public"."config"."parent_id" IS '父级配置';
COMMENT ON COLUMN "public"."config"."component" IS 'tab 引入的组件名称';
COMMENT ON COLUMN "public"."config"."key" IS '配置键名';
COMMENT ON COLUMN "public"."config"."value" IS '配置键值';
COMMENT ON COLUMN "public"."config"."status" IS '状态。1 启用 0 禁用';
COMMENT ON COLUMN "public"."config"."creator" IS '创建人';
COMMENT ON COLUMN "public"."config"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."config"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."config"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."config" IS '配置信息';

-- ----------------------------
-- Table structure for crm_business_card
-- ----------------------------
DROP TABLE IF EXISTS "public"."crm_business_card";
CREATE TABLE "public"."crm_business_card" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "uid" uuid NOT NULL,
  "umodel" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "realname" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "gender" varchar COLLATE "pg_catalog"."default",
  "cover" varchar COLLATE "pg_catalog"."default",
  "job_title" varchar COLLATE "pg_catalog"."default",
  "sub_title" varchar COLLATE "pg_catalog"."default",
  "organization" varchar COLLATE "pg_catalog"."default",
  "org_logo" varchar COLLATE "pg_catalog"."default",
  "mobile" varchar COLLATE "pg_catalog"."default",
  "wechat" varchar COLLATE "pg_catalog"."default",
  "address" varchar COLLATE "pg_catalog"."default",
  "email" varchar COLLATE "pg_catalog"."default",
  "attrs" varchar COLLATE "pg_catalog"."default",
  "nanoid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "phone" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."crm_business_card"."uid" IS '关联各用户表的id';
COMMENT ON COLUMN "public"."crm_business_card"."umodel" IS '关联模型名';
COMMENT ON COLUMN "public"."crm_business_card"."realname" IS '真实名字';
COMMENT ON COLUMN "public"."crm_business_card"."gender" IS '性别';
COMMENT ON COLUMN "public"."crm_business_card"."cover" IS '封面图片';
COMMENT ON COLUMN "public"."crm_business_card"."job_title" IS '职位';
COMMENT ON COLUMN "public"."crm_business_card"."sub_title" IS '副职位';
COMMENT ON COLUMN "public"."crm_business_card"."organization" IS '企业组织名称';
COMMENT ON COLUMN "public"."crm_business_card"."org_logo" IS '企业组织logo';
COMMENT ON COLUMN "public"."crm_business_card"."mobile" IS '移动电话号码';
COMMENT ON COLUMN "public"."crm_business_card"."wechat" IS '微信号';
COMMENT ON COLUMN "public"."crm_business_card"."address" IS '地址';
COMMENT ON COLUMN "public"."crm_business_card"."email" IS '邮箱';
COMMENT ON COLUMN "public"."crm_business_card"."attrs" IS '更多字段';
COMMENT ON COLUMN "public"."crm_business_card"."nanoid" IS '页面nanoid';
COMMENT ON COLUMN "public"."crm_business_card"."phone" IS '固定电话号码';
COMMENT ON COLUMN "public"."crm_business_card"."creator" IS '创建人';
COMMENT ON COLUMN "public"."crm_business_card"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."crm_business_card"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."crm_business_card"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."crm_business_card" IS '名片信息';

-- ----------------------------
-- Table structure for crm_card_holder
-- ----------------------------
DROP TABLE IF EXISTS "public"."crm_card_holder";
CREATE TABLE "public"."crm_card_holder" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "holder_uid" uuid NOT NULL,
  "holder_umodel" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "card_uid" uuid NOT NULL,
  "card_umodel" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "nanoid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "weight" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."crm_card_holder"."holder_uid" IS '名片夹所有者uid';
COMMENT ON COLUMN "public"."crm_card_holder"."holder_umodel" IS '名片夹所有者umodel';
COMMENT ON COLUMN "public"."crm_card_holder"."card_uid" IS '名片uid';
COMMENT ON COLUMN "public"."crm_card_holder"."card_umodel" IS '名片umodel';
COMMENT ON COLUMN "public"."crm_card_holder"."nanoid" IS '名片nanoid';
COMMENT ON COLUMN "public"."crm_card_holder"."weight" IS '排序';
COMMENT ON COLUMN "public"."crm_card_holder"."status" IS '状态:1=展示;0=隐藏';
COMMENT ON COLUMN "public"."crm_card_holder"."creator" IS '创建人';
COMMENT ON COLUMN "public"."crm_card_holder"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."crm_card_holder"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."crm_card_holder"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."crm_card_holder" IS '名片夹信息';

-- ----------------------------
-- Table structure for crm_visit_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."crm_visit_log";
CREATE TABLE "public"."crm_visit_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "from_uid" uuid NOT NULL,
  "from_umodel" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "to_uid" uuid NOT NULL,
  "to_umodel" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."crm_visit_log"."from_uid" IS '来访者uid';
COMMENT ON COLUMN "public"."crm_visit_log"."from_umodel" IS '来访者模型';
COMMENT ON COLUMN "public"."crm_visit_log"."to_uid" IS '受访者uid';
COMMENT ON COLUMN "public"."crm_visit_log"."to_umodel" IS '受访者模型';
COMMENT ON COLUMN "public"."crm_visit_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."crm_visit_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."crm_visit_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."crm_visit_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."crm_visit_log" IS '访客记录';

-- ----------------------------
-- Table structure for crontab
-- ----------------------------
DROP TABLE IF EXISTS "public"."crontab";
CREATE TABLE "public"."crontab" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "group" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 1,
  "task" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "cron" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "tactics" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "remark" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "status" int4 NOT NULL DEFAULT 1
)
;
COMMENT ON COLUMN "public"."crontab"."name" IS '任务名称';
COMMENT ON COLUMN "public"."crontab"."group" IS '分组。1 默认 2 系统';
COMMENT ON COLUMN "public"."crontab"."task" IS '任务名称';
COMMENT ON COLUMN "public"."crontab"."cron" IS 'cron 表达式';
COMMENT ON COLUMN "public"."crontab"."tactics" IS '策略。1 立即执行 2 执行一次 3 放弃执行';
COMMENT ON COLUMN "public"."crontab"."remark" IS '备注';
COMMENT ON COLUMN "public"."crontab"."creator" IS '创建人';
COMMENT ON COLUMN "public"."crontab"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."crontab"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."crontab"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."crontab"."status" IS '状态。1 正常 2 禁用';
COMMENT ON TABLE "public"."crontab" IS '计划任务';

-- ----------------------------
-- Table structure for crontab_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."crontab_log";
CREATE TABLE "public"."crontab_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "crontab_id" uuid NOT NULL,
  "used_time" int4 NOT NULL DEFAULT 0,
  "error_message" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 1,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."crontab_log"."crontab_id" IS 'crontab 任务ID';
COMMENT ON COLUMN "public"."crontab_log"."used_time" IS '任务消耗时间';
COMMENT ON COLUMN "public"."crontab_log"."error_message" IS '错误信息';
COMMENT ON COLUMN "public"."crontab_log"."status" IS '状态。1 成功 0 失败';
COMMENT ON COLUMN "public"."crontab_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."crontab_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."crontab_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."crontab_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."crontab_log" IS '计划任务记录';

-- ----------------------------
-- Table structure for customer_level
-- ----------------------------
DROP TABLE IF EXISTS "public"."customer_level";
CREATE TABLE "public"."customer_level" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."customer_level"."name" IS '等级唯一英文名';
COMMENT ON COLUMN "public"."customer_level"."title" IS '等级中文标题';
COMMENT ON COLUMN "public"."customer_level"."creator" IS '创建人';
COMMENT ON COLUMN "public"."customer_level"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."customer_level"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."customer_level"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."customer_level" IS '客户等级';

-- ----------------------------
-- Table structure for customer_status
-- ----------------------------
DROP TABLE IF EXISTS "public"."customer_status";
CREATE TABLE "public"."customer_status" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."customer_status"."name" IS '状态唯一英文名';
COMMENT ON COLUMN "public"."customer_status"."title" IS '状态中文标题';
COMMENT ON COLUMN "public"."customer_status"."creator" IS '创建人';
COMMENT ON COLUMN "public"."customer_status"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."customer_status"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."customer_status"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."customer_status" IS '客户状态';

-- ----------------------------
-- Table structure for customer_type
-- ----------------------------
DROP TABLE IF EXISTS "public"."customer_type";
CREATE TABLE "public"."customer_type" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."customer_type"."name" IS '客户类型名(英文唯一)';
COMMENT ON COLUMN "public"."customer_type"."title" IS '类型中文标题';
COMMENT ON COLUMN "public"."customer_type"."creator" IS '创建人';
COMMENT ON COLUMN "public"."customer_type"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."customer_type"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."customer_type"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."customer_type" IS '客户类型';

-- ----------------------------
-- Table structure for data_access_authorization
-- ----------------------------
DROP TABLE IF EXISTS "public"."data_access_authorization";
CREATE TABLE "public"."data_access_authorization" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "entity_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "entity_type" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "user_id" uuid NOT NULL,
  "permission" int4 NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."data_access_authorization"."id" IS 'id';
COMMENT ON COLUMN "public"."data_access_authorization"."entity_id" IS '实体id';
COMMENT ON COLUMN "public"."data_access_authorization"."entity_type" IS '实体类型';
COMMENT ON COLUMN "public"."data_access_authorization"."user_id" IS '用户id，关联uctoo_user.id';
COMMENT ON COLUMN "public"."data_access_authorization"."permission" IS '权限，1=可读，2=可写，3=可授权';
COMMENT ON COLUMN "public"."data_access_authorization"."creator" IS '创建人';
COMMENT ON COLUMN "public"."data_access_authorization"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."data_access_authorization"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."data_access_authorization"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."data_access_authorization" IS '数据访问授权';

-- ----------------------------
-- Table structure for db_connection
-- ----------------------------
DROP TABLE IF EXISTS "public"."db_connection";
CREATE TABLE "public"."db_connection" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "password" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "host" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "port" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "database_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "ssl" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "provider" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying
)
;
COMMENT ON COLUMN "public"."db_connection"."id" IS 'id';
COMMENT ON COLUMN "public"."db_connection"."user" IS '用户名';
COMMENT ON COLUMN "public"."db_connection"."password" IS '密码';
COMMENT ON COLUMN "public"."db_connection"."host" IS '主机地址';
COMMENT ON COLUMN "public"."db_connection"."port" IS '端口';
COMMENT ON COLUMN "public"."db_connection"."database_name" IS '数据库名';
COMMENT ON COLUMN "public"."db_connection"."ssl" IS '是否ssl，0=否，1=是';
COMMENT ON COLUMN "public"."db_connection"."creator" IS '创建人';
COMMENT ON COLUMN "public"."db_connection"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."db_connection"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."db_connection"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."db_connection"."provider" IS '数据库驱动，postgresql、mysql等';
COMMENT ON COLUMN "public"."db_connection"."type" IS '类型，uctoo等';
COMMENT ON TABLE "public"."db_connection" IS '数据库连接';

-- ----------------------------
-- Table structure for db_info
-- ----------------------------
DROP TABLE IF EXISTS "public"."db_info";
CREATE TABLE "public"."db_info" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "table_catalog" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "table_schema" varchar COLLATE "pg_catalog"."default",
  "table_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "column_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "column_default" varchar COLLATE "pg_catalog"."default",
  "is_nullable" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'YES'::character varying,
  "data_type" varchar COLLATE "pg_catalog"."default",
  "vue_component_type" varchar COLLATE "pg_catalog"."default" DEFAULT 'textarea'::character varying,
  "react_component_type" varchar COLLATE "pg_catalog"."default" DEFAULT 'textarea'::character varying,
  "arkui_component_type" varchar COLLATE "pg_catalog"."default" DEFAULT 'TextArea'::character varying,
  "uniapp_component_type" varchar COLLATE "pg_catalog"."default" DEFAULT 'textarea'::character varying,
  "rules" varchar COLLATE "pg_catalog"."default",
  "pattern" varchar COLLATE "pg_catalog"."default",
  "weight" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "placeholder" varchar COLLATE "pg_catalog"."default",
  "is_column_hidden" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'NO'::character varying,
  "is_table_hidden" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'NO'::character varying,
  "column_comment" varchar COLLATE "pg_catalog"."default",
  "ordinal_position" int4 NOT NULL DEFAULT 0,
  "migration_id" varchar COLLATE "pg_catalog"."default" DEFAULT 'dev'::character varying,
  "character_maximum_length" int8 DEFAULT 11
)
;
COMMENT ON COLUMN "public"."db_info"."id" IS 'id';
COMMENT ON COLUMN "public"."db_info"."table_catalog" IS '表分组。即数据库名';
COMMENT ON COLUMN "public"."db_info"."table_schema" IS 'table_schema';
COMMENT ON COLUMN "public"."db_info"."table_name" IS '表名';
COMMENT ON COLUMN "public"."db_info"."column_name" IS '列名';
COMMENT ON COLUMN "public"."db_info"."column_default" IS '默认值';
COMMENT ON COLUMN "public"."db_info"."is_nullable" IS '是否可空。YES可空，NO不可空。';
COMMENT ON COLUMN "public"."db_info"."data_type" IS '数据类型';
COMMENT ON COLUMN "public"."db_info"."vue_component_type" IS 'vue控件类型。一般用于生成PC端管理后台代码。';
COMMENT ON COLUMN "public"."db_info"."react_component_type" IS 'vue控件类型。一般用于生成PC端管理后台代码。';
COMMENT ON COLUMN "public"."db_info"."arkui_component_type" IS 'arkui控件类型。一般用于生成鸿蒙原生应用代码。';
COMMENT ON COLUMN "public"."db_info"."uniapp_component_type" IS 'uniapp控件类型。一般用于生成小程序应用代码。';
COMMENT ON COLUMN "public"."db_info"."rules" IS '校验规则';
COMMENT ON COLUMN "public"."db_info"."pattern" IS '正则表达式';
COMMENT ON COLUMN "public"."db_info"."weight" IS '排序';
COMMENT ON COLUMN "public"."db_info"."creator" IS '创建人';
COMMENT ON COLUMN "public"."db_info"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."db_info"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."db_info"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."db_info"."placeholder" IS '占位符或tips';
COMMENT ON COLUMN "public"."db_info"."is_column_hidden" IS '字段是否隐藏。YES=隐藏，NO=显示。';
COMMENT ON COLUMN "public"."db_info"."is_table_hidden" IS '表是否隐藏。YES=隐藏，NO=显示。由于是字段表，因此这个字段存在冗余，应保持同一个表在多条字段记录中此值一致。';
COMMENT ON COLUMN "public"."db_info"."column_comment" IS '列备注';
COMMENT ON COLUMN "public"."db_info"."ordinal_position" IS '列的顺序位置';
COMMENT ON COLUMN "public"."db_info"."migration_id" IS '关联_prisma_migrations表id。可作为数据库版本管理标识。';
COMMENT ON TABLE "public"."db_info" IS '数据库信息。屏蔽不同数据库差异，保存一致的数据库结构信息，便于可视化代码生成。可用于codelabs表的数据源data_source';

-- ----------------------------
-- Table structure for departments
-- ----------------------------
DROP TABLE IF EXISTS "public"."departments";
CREATE TABLE "public"."departments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "department_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "parent_id" uuid,
  "principal" varchar COLLATE "pg_catalog"."default",
  "mobile" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "email" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "weight" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 1,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."departments"."department_name" IS '部门名称';
COMMENT ON COLUMN "public"."departments"."parent_id" IS '父级ID';
COMMENT ON COLUMN "public"."departments"."principal" IS '负责人';
COMMENT ON COLUMN "public"."departments"."mobile" IS '联系电话';
COMMENT ON COLUMN "public"."departments"."email" IS '联系邮箱';
COMMENT ON COLUMN "public"."departments"."weight" IS '排序';
COMMENT ON COLUMN "public"."departments"."status" IS '状态。1 正常 0 停用';
COMMENT ON COLUMN "public"."departments"."creator" IS '创建人';
COMMENT ON COLUMN "public"."departments"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."departments"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."departments"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."departments" IS '部门信息';

-- ----------------------------
-- Table structure for developer
-- ----------------------------
DROP TABLE IF EXISTS "public"."developer";
CREATE TABLE "public"."developer" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "mobile" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "id_card" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "alipay_account" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."developer"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."developer"."mobile" IS '手机号';
COMMENT ON COLUMN "public"."developer"."id_card" IS '身份证';
COMMENT ON COLUMN "public"."developer"."alipay_account" IS '支付宝账户';
COMMENT ON COLUMN "public"."developer"."status" IS '状态。0 待认证 1 已认证';
COMMENT ON COLUMN "public"."developer"."creator" IS '创建人';
COMMENT ON COLUMN "public"."developer"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."developer"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."developer"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."developer" IS '开发者信息';

-- ----------------------------
-- Table structure for developer_account
-- ----------------------------
DROP TABLE IF EXISTS "public"."developer_account";
CREATE TABLE "public"."developer_account" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "type" int4 NOT NULL DEFAULT 0,
  "user_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "wechat_miniapp_user_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "realname" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "mobile" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "idcard1" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "idcard2" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "business_license" varchar COLLATE "pg_catalog"."default",
  "wechat_openid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "mchid" varchar COLLATE "pg_catalog"."default",
  "alipay_user_Id" varchar COLLATE "pg_catalog"."default",
  "alipay_login_name" varchar COLLATE "pg_catalog"."default",
  "company_name" varchar COLLATE "pg_catalog"."default",
  "company_address" varchar COLLATE "pg_catalog"."default",
  "company_contact" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."developer_account"."type" IS '帐号类型:1=企业,2=个人';
COMMENT ON COLUMN "public"."developer_account"."user_id" IS '关联user表id';
COMMENT ON COLUMN "public"."developer_account"."wechat_miniapp_user_id" IS '关联wechat_mMiniappUser_id表id';
COMMENT ON COLUMN "public"."developer_account"."realname" IS '真实姓名';
COMMENT ON COLUMN "public"."developer_account"."mobile" IS '手机号';
COMMENT ON COLUMN "public"."developer_account"."idcard1" IS '身份证正面';
COMMENT ON COLUMN "public"."developer_account"."idcard2" IS '身份证反面';
COMMENT ON COLUMN "public"."developer_account"."business_license" IS '营业执照';
COMMENT ON COLUMN "public"."developer_account"."wechat_openid" IS '微信openid（个人结算）';
COMMENT ON COLUMN "public"."developer_account"."mchid" IS '微信支付商户号（企业结算）';
COMMENT ON COLUMN "public"."developer_account"."alipay_user_Id" IS '支付宝个人帐号（个人结算）';
COMMENT ON COLUMN "public"."developer_account"."alipay_login_name" IS '支付宝登录号';
COMMENT ON COLUMN "public"."developer_account"."company_name" IS '公司名称';
COMMENT ON COLUMN "public"."developer_account"."company_address" IS '公司地址';
COMMENT ON COLUMN "public"."developer_account"."company_contact" IS '公司联系方式';
COMMENT ON COLUMN "public"."developer_account"."status" IS '认证状态。1=待认证,2=已认证';
COMMENT ON COLUMN "public"."developer_account"."creator" IS '创建人';
COMMENT ON COLUMN "public"."developer_account"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."developer_account"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."developer_account"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."developer_account" IS '开发者实名信息';

-- ----------------------------
-- Table structure for element_components
-- ----------------------------
DROP TABLE IF EXISTS "public"."element_components";
CREATE TABLE "public"."element_components" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "tag" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "docs_url" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "specification" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "version" varchar COLLATE "pg_catalog"."default",
  "remarks" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."element_components"."name" IS '组件名。与https://github.com/ElemeFE/element/blob/master/components.json一致';
COMMENT ON COLUMN "public"."element_components"."tag" IS '组件标签';
COMMENT ON COLUMN "public"."element_components"."docs_url" IS '组件文档url地址';
COMMENT ON COLUMN "public"."element_components"."specification" IS '组件规范json。包含组件Attributes的全量信息';
COMMENT ON COLUMN "public"."element_components"."version" IS '版本';
COMMENT ON COLUMN "public"."element_components"."remarks" IS '备注';
COMMENT ON COLUMN "public"."element_components"."status" IS '状态';
COMMENT ON COLUMN "public"."element_components"."creator" IS '创建人';
COMMENT ON COLUMN "public"."element_components"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."element_components"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."element_components"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."element_components" IS 'element UI组件信息';

-- ----------------------------
-- Table structure for entity
-- ----------------------------
DROP TABLE IF EXISTS "public"."entity";
CREATE TABLE "public"."entity" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "link" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "privacy_level" int4 NOT NULL DEFAULT 0,
  "stars" float8 NOT NULL DEFAULT 0,
  "description" varchar COLLATE "pg_catalog"."default",
  "group_id" uuid,
  "picture" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "images" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "content" text COLLATE "pg_catalog"."default",
  "json" text COLLATE "pg_catalog"."default",
  "city" varchar COLLATE "pg_catalog"."default",
  "price" float8 DEFAULT 0,
  "birthday" date,
  "owner" varchar COLLATE "pg_catalog"."default",
  "creator" uuid NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "end_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "start_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "status" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."entity"."link" IS '链接url';
COMMENT ON COLUMN "public"."entity"."privacy_level" IS '隐私等级';
COMMENT ON COLUMN "public"."entity"."stars" IS '星级';
COMMENT ON COLUMN "public"."entity"."description" IS '描述';
COMMENT ON COLUMN "public"."entity"."group_id" IS '分组id';
COMMENT ON COLUMN "public"."entity"."picture" IS '单图';
COMMENT ON COLUMN "public"."entity"."images" IS '多图';
COMMENT ON COLUMN "public"."entity"."content" IS '内容';
COMMENT ON COLUMN "public"."entity"."json" IS 'json内容';
COMMENT ON COLUMN "public"."entity"."city" IS '城市';
COMMENT ON COLUMN "public"."entity"."price" IS '价格';
COMMENT ON COLUMN "public"."entity"."birthday" IS '生日';
COMMENT ON COLUMN "public"."entity"."owner" IS '所属用户。关联user表username';
COMMENT ON COLUMN "public"."entity"."creator" IS '创建人';
COMMENT ON COLUMN "public"."entity"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."entity"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."entity"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."entity" IS '实体信息';

-- ----------------------------
-- Table structure for faq
-- ----------------------------
DROP TABLE IF EXISTS "public"."faq";
CREATE TABLE "public"."faq" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."faq"."title" IS '标题';
COMMENT ON COLUMN "public"."faq"."content" IS '内容';
COMMENT ON COLUMN "public"."faq"."creator" IS '创建人';
COMMENT ON COLUMN "public"."faq"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."faq"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."faq"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."faq" IS '常见问题';

-- ----------------------------
-- Table structure for feedback
-- ----------------------------
DROP TABLE IF EXISTS "public"."feedback";
CREATE TABLE "public"."feedback" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default",
  "content" varchar COLLATE "pg_catalog"."default",
  "images" varchar COLLATE "pg_catalog"."default",
  "phone" varchar COLLATE "pg_catalog"."default",
  "remark" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."feedback"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."feedback"."type" IS '反馈类型';
COMMENT ON COLUMN "public"."feedback"."content" IS '反馈内容';
COMMENT ON COLUMN "public"."feedback"."images" IS '图片';
COMMENT ON COLUMN "public"."feedback"."phone" IS '联系电话';
COMMENT ON COLUMN "public"."feedback"."remark" IS '处理备注';
COMMENT ON COLUMN "public"."feedback"."status" IS '是否处理。0=未处理,1=已处理';
COMMENT ON COLUMN "public"."feedback"."creator" IS '创建人';
COMMENT ON COLUMN "public"."feedback"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."feedback"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."feedback"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."feedback" IS '反馈信息';

-- ----------------------------
-- Table structure for group_has_permission
-- ----------------------------
DROP TABLE IF EXISTS "public"."group_has_permission";
CREATE TABLE "public"."group_has_permission" (
  "group_id" uuid NOT NULL,
  "permission_name" text COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."group_has_permission"."group_id" IS '关联user_group.id';
COMMENT ON COLUMN "public"."group_has_permission"."permission_name" IS '关联permissions.id';
COMMENT ON COLUMN "public"."group_has_permission"."status" IS '状态';
COMMENT ON COLUMN "public"."group_has_permission"."creator" IS '创建人';
COMMENT ON COLUMN "public"."group_has_permission"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."group_has_permission"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."group_has_permission"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."group_has_permission" IS '用户组权限';

-- ----------------------------
-- Table structure for group_tag
-- ----------------------------
DROP TABLE IF EXISTS "public"."group_tag";
CREATE TABLE "public"."group_tag" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "group_id" uuid NOT NULL,
  "tagId" uuid NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."group_tag"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."group_tag"."creator" IS '创建人';
COMMENT ON COLUMN "public"."group_tag"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."group_tag"."updated_at" IS '更新时间';

-- ----------------------------
-- Table structure for guest_users
-- ----------------------------
DROP TABLE IF EXISTS "public"."guest_users";
CREATE TABLE "public"."guest_users" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "nickname" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default",
  "domain" varchar COLLATE "pg_catalog"."default",
  "ipAddress" varchar COLLATE "pg_catalog"."default",
  "userAgent" varchar COLLATE "pg_catalog"."default",
  "referer" varchar COLLATE "pg_catalog"."default",
  "lastAccessTime" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "mobile" varchar COLLATE "pg_catalog"."default",
  "channel" varchar COLLATE "pg_catalog"."default",
  "comments" varchar COLLATE "pg_catalog"."default",
  "user_id" uuid,
  "user_model" varchar COLLATE "pg_catalog"."default",
  "appid" varchar COLLATE "pg_catalog"."default",
  "status" int4 DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."guest_users"."nickname" IS '昵称';
COMMENT ON COLUMN "public"."guest_users"."token" IS 'token';
COMMENT ON COLUMN "public"."guest_users"."domain" IS '来源域名';
COMMENT ON COLUMN "public"."guest_users"."ipAddress" IS 'ip地址';
COMMENT ON COLUMN "public"."guest_users"."userAgent" IS '用户端类型';
COMMENT ON COLUMN "public"."guest_users"."referer" IS '来源网址';
COMMENT ON COLUMN "public"."guest_users"."lastAccessTime" IS '最近访问时间';
COMMENT ON COLUMN "public"."guest_users"."mobile" IS '手机号码';
COMMENT ON COLUMN "public"."guest_users"."channel" IS '来源渠道';
COMMENT ON COLUMN "public"."guest_users"."comments" IS '备注';
COMMENT ON COLUMN "public"."guest_users"."user_id" IS '关联用户id';
COMMENT ON COLUMN "public"."guest_users"."user_model" IS '关联用户模型';
COMMENT ON COLUMN "public"."guest_users"."appid" IS 'appid';
COMMENT ON COLUMN "public"."guest_users"."status" IS '状态';
COMMENT ON COLUMN "public"."guest_users"."creator" IS '创建人';
COMMENT ON COLUMN "public"."guest_users"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."guest_users"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."guest_users"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."guest_users" IS '匿名用户，访客信息';

-- ----------------------------
-- Table structure for i18
-- ----------------------------
DROP TABLE IF EXISTS "public"."i18";
CREATE TABLE "public"."i18" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "key" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" text COLLATE "pg_catalog"."default" NOT NULL,
  "lang_id" uuid,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."i18"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."i18"."key" IS '国际化key';
COMMENT ON COLUMN "public"."i18"."content" IS '内容';
COMMENT ON COLUMN "public"."i18"."lang_id" IS '语言ID';
COMMENT ON TABLE "public"."i18" IS '国际化内容';

-- ----------------------------
-- Table structure for jobs
-- ----------------------------
DROP TABLE IF EXISTS "public"."jobs";
CREATE TABLE "public"."jobs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "job_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "coding" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "weight" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 1,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."jobs"."job_name" IS '岗位名称';
COMMENT ON COLUMN "public"."jobs"."coding" IS '编码';
COMMENT ON COLUMN "public"."jobs"."description" IS '描述';
COMMENT ON COLUMN "public"."jobs"."weight" IS '排序';
COMMENT ON COLUMN "public"."jobs"."status" IS '1 正常 0 停用';
COMMENT ON COLUMN "public"."jobs"."creator" IS '创建人';
COMMENT ON COLUMN "public"."jobs"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."jobs"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."jobs"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."jobs" IS '岗位信息';

-- ----------------------------
-- Table structure for lang
-- ----------------------------
DROP TABLE IF EXISTS "public"."lang";
CREATE TABLE "public"."lang" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 1,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."lang"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."lang"."name" IS '语言名称';
COMMENT ON COLUMN "public"."lang"."code" IS '语言代码';
COMMENT ON COLUMN "public"."lang"."status" IS '状态';
COMMENT ON TABLE "public"."lang" IS '语言管理';

-- ----------------------------
-- Table structure for link
-- ----------------------------
DROP TABLE IF EXISTS "public"."link";
CREATE TABLE "public"."link" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "link" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "privacy_cevel" int4 NOT NULL DEFAULT 0,
  "owner" uuid,
  "stars" float8 NOT NULL DEFAULT 0,
  "description" varchar COLLATE "pg_catalog"."default",
  "group_id" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid
)
;
COMMENT ON COLUMN "public"."link"."link" IS '链接url';
COMMENT ON COLUMN "public"."link"."privacy_cevel" IS '隐私等级';
COMMENT ON COLUMN "public"."link"."owner" IS '所有者。关联user表username';
COMMENT ON COLUMN "public"."link"."stars" IS '星级';
COMMENT ON COLUMN "public"."link"."description" IS '描述';
COMMENT ON COLUMN "public"."link"."group_id" IS '分组id';
COMMENT ON COLUMN "public"."link"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."link"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."link"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."link"."creator" IS '创建人';
COMMENT ON TABLE "public"."link" IS '链接信息';

-- ----------------------------
-- Table structure for link_group
-- ----------------------------
DROP TABLE IF EXISTS "public"."link_group";
CREATE TABLE "public"."link_group" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "owner" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "groupname" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "picture" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "stars" float8 NOT NULL DEFAULT 0,
  "watcher_count" int4 NOT NULL DEFAULT 0,
  "linked_count" int4 NOT NULL DEFAULT 0,
  "links_count" int4 NOT NULL DEFAULT 0,
  "privacy_level" int4 NOT NULL DEFAULT 0,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."link_group"."owner" IS '归属用户。关联user表username';
COMMENT ON COLUMN "public"."link_group"."groupname" IS '分组名';
COMMENT ON COLUMN "public"."link_group"."name" IS '组名。英文唯一描述';
COMMENT ON COLUMN "public"."link_group"."description" IS '描述';
COMMENT ON COLUMN "public"."link_group"."picture" IS '图片';
COMMENT ON COLUMN "public"."link_group"."stars" IS '星级';
COMMENT ON COLUMN "public"."link_group"."watcher_count" IS '浏览数';
COMMENT ON COLUMN "public"."link_group"."linked_count" IS '被链接数';
COMMENT ON COLUMN "public"."link_group"."links_count" IS '链接数量';
COMMENT ON COLUMN "public"."link_group"."privacy_level" IS '隐私等级';
COMMENT ON COLUMN "public"."link_group"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."link_group"."creator" IS '创建人';
COMMENT ON COLUMN "public"."link_group"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."link_group"."updated_at" IS '更新时间';
COMMENT ON TABLE "public"."link_group" IS '链接分组';

-- ----------------------------
-- Table structure for link_tag
-- ----------------------------
DROP TABLE IF EXISTS "public"."link_tag";
CREATE TABLE "public"."link_tag" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "link_id" uuid NOT NULL,
  "tag_id" uuid NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."link_tag"."link_id" IS '链接id';
COMMENT ON COLUMN "public"."link_tag"."tag_id" IS '标签id';
COMMENT ON COLUMN "public"."link_tag"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."link_tag"."creator" IS '创建人';
COMMENT ON COLUMN "public"."link_tag"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."link_tag"."updated_at" IS '更新时间';
COMMENT ON TABLE "public"."link_tag" IS '链接标签关联';

-- ----------------------------
-- Table structure for login_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."login_log";
CREATE TABLE "public"."login_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "login_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "login_ip" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "browser" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "os" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "login_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."login_log"."login_name" IS '用户名';
COMMENT ON COLUMN "public"."login_log"."login_ip" IS '登录地点ip';
COMMENT ON COLUMN "public"."login_log"."browser" IS '浏览器';
COMMENT ON COLUMN "public"."login_log"."os" IS '操作系统';
COMMENT ON COLUMN "public"."login_log"."login_at" IS '登录时间';
COMMENT ON COLUMN "public"."login_log"."status" IS '状态。1 成功 0 失败';
COMMENT ON COLUMN "public"."login_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."login_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."login_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."login_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."login_log" IS '登录记录';

-- ----------------------------
-- Table structure for minishop_activity
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_activity";
CREATE TABLE "public"."minishop_activity" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "goods_ids" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default",
  "richtext_title" varchar COLLATE "pg_catalog"."default",
  "sharde_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "end_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "rules" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "richtext_id" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."minishop_activity"."title" IS '活动名称';
COMMENT ON COLUMN "public"."minishop_activity"."goods_ids" IS '商品id';
COMMENT ON COLUMN "public"."minishop_activity"."type" IS '类型';
COMMENT ON COLUMN "public"."minishop_activity"."richtext_title" IS '说明标题';
COMMENT ON COLUMN "public"."minishop_activity"."sharde_time" IS '开始时间';
COMMENT ON COLUMN "public"."minishop_activity"."end_time" IS '结束时间';
COMMENT ON COLUMN "public"."minishop_activity"."rules" IS '活动规则';
COMMENT ON COLUMN "public"."minishop_activity"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_activity"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_activity"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_activity"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_activity" IS '商城活动';

-- ----------------------------
-- Table structure for minishop_activity_goods_sku_price
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_activity_goods_sku_price";
CREATE TABLE "public"."minishop_activity_goods_sku_price" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "activity_id" uuid NOT NULL,
  "sku_price_id" uuid NOT NULL,
  "goods_id" uuid NOT NULL,
  "stock" int4 NOT NULL DEFAULT 0,
  "sales" int4 NOT NULL DEFAULT 0,
  "price" float8 DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."activity_id" IS '活动id';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."sku_price_id" IS '规格id';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."goods_id" IS '所属产品';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."stock" IS '库存';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."sales" IS '已售';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."price" IS '活动价格';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."status" IS '状态';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_activity_goods_sku_price"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_activity_goods_sku_price" IS '商品活动价格';

-- ----------------------------
-- Table structure for minishop_activity_groupon
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_activity_groupon";
CREATE TABLE "public"."minishop_activity_groupon" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "goods_id" uuid NOT NULL,
  "activity_id" uuid NOT NULL,
  "num" int4 NOT NULL DEFAULT 0,
  "current_num" int4 NOT NULL DEFAULT 0,
  "expire_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finish_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "status" varchar COLLATE "pg_catalog"."default" NOT NULL
)
;
COMMENT ON COLUMN "public"."minishop_activity_groupon"."user_id" IS '用户id。团长';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."goods_id" IS '商品';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."activity_id" IS '活动id';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."num" IS '成团人数';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."current_num" IS '当前人数';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."expire_time" IS '过期时间';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."finish_time" IS '成团时间';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."minishop_activity_groupon"."status" IS '状态。invalid=已过期,ing=进行中,finish=已成团,finish-fictitious=虚拟成团';
COMMENT ON TABLE "public"."minishop_activity_groupon" IS '活动成团信息';

-- ----------------------------
-- Table structure for minishop_activity_groupon_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_activity_groupon_log";
CREATE TABLE "public"."minishop_activity_groupon_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "user_nickname" varchar COLLATE "pg_catalog"."default",
  "user_avatar" varchar COLLATE "pg_catalog"."default",
  "groupon_id" uuid NOT NULL,
  "goods_id" uuid NOT NULL,
  "goods_sku_price_id" uuid NOT NULL,
  "activity_id" uuid NOT NULL,
  "is_leader" int4 NOT NULL DEFAULT 0,
  "is_fictitious" int4 NOT NULL DEFAULT 0,
  "order_id" uuid NOT NULL,
  "is_refund" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."user_nickname" IS '用户昵称';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."user_avatar" IS '头像';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."groupon_id" IS '拼团活动id';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."goods_id" IS '商品id';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."goods_sku_price_id" IS '商品规格';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."activity_id" IS '活动id';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."is_leader" IS '是否团长';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."is_fictitious" IS '是否虚拟用户';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."order_id" IS '订单id';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."is_refund" IS '是否退款';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_activity_groupon_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_activity_groupon_log" IS '拼团记录';

-- ----------------------------
-- Table structure for minishop_address_info
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_address_info";
CREATE TABLE "public"."minishop_address_info" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "receiver_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "detailed_address" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "mobile" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "country" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "province" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "city" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "town" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "default" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_address_info"."receiver_name" IS '收件人姓名';
COMMENT ON COLUMN "public"."minishop_address_info"."detailed_address" IS '详细收货地址信息';
COMMENT ON COLUMN "public"."minishop_address_info"."mobile" IS '收件人手机号码';
COMMENT ON COLUMN "public"."minishop_address_info"."country" IS '国家';
COMMENT ON COLUMN "public"."minishop_address_info"."province" IS '省份';
COMMENT ON COLUMN "public"."minishop_address_info"."city" IS '城市';
COMMENT ON COLUMN "public"."minishop_address_info"."town" IS '乡镇';
COMMENT ON COLUMN "public"."minishop_address_info"."default" IS '是否默认收件地址。0否，1是';
COMMENT ON COLUMN "public"."minishop_address_info"."status" IS '状态';
COMMENT ON COLUMN "public"."minishop_address_info"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_address_info"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_address_info"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_address_info"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_address_info" IS '收件人地址信息';

-- ----------------------------
-- Table structure for minishop_area
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_area";
CREATE TABLE "public"."minishop_area" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "parent_id" uuid,
  "level" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_area"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_area"."parent_id" IS '上级id';
COMMENT ON COLUMN "public"."minishop_area"."level" IS '层级';
COMMENT ON COLUMN "public"."minishop_area"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_area"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_area"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_area"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_area" IS '省市区信息';

-- ----------------------------
-- Table structure for minishop_cart
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_cart";
CREATE TABLE "public"."minishop_cart" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "minishop_spu_id" uuid NOT NULL,
  "minishop_sku_id" uuid NOT NULL,
  "product_id" uuid NOT NULL,
  "out_product_id" uuid NOT NULL,
  "sku_id" uuid NOT NULL,
  "out_sku_id" uuid NOT NULL,
  "product_cnt" int4 NOT NULL DEFAULT 1,
  "openid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_cart"."user_id" IS '关联user表id';
COMMENT ON COLUMN "public"."minishop_cart"."minishop_spu_id" IS '关联minishop_spu表id';
COMMENT ON COLUMN "public"."minishop_cart"."minishop_sku_id" IS '关联minishop_sku表id';
COMMENT ON COLUMN "public"."minishop_cart"."product_id" IS '小商店内部商品ID';
COMMENT ON COLUMN "public"."minishop_cart"."out_product_id" IS '商家自定义商品ID';
COMMENT ON COLUMN "public"."minishop_cart"."sku_id" IS '小商店内部sku_iD';
COMMENT ON COLUMN "public"."minishop_cart"."out_sku_id" IS '商家自定义sku_id';
COMMENT ON COLUMN "public"."minishop_cart"."product_cnt" IS '商品数量';
COMMENT ON COLUMN "public"."minishop_cart"."openid" IS '微信用户openid';
COMMENT ON COLUMN "public"."minishop_cart"."appid" IS '应用appid';
COMMENT ON COLUMN "public"."minishop_cart"."status" IS '状态';
COMMENT ON COLUMN "public"."minishop_cart"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_cart"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_cart"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_cart"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_cart" IS '购物车信息';

-- ----------------------------
-- Table structure for minishop_config
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_config";
CREATE TABLE "public"."minishop_config" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "group" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "tip" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" varchar COLLATE "pg_catalog"."default",
  "rule" varchar COLLATE "pg_catalog"."default",
  "extend" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_config"."name" IS '变量名';
COMMENT ON COLUMN "public"."minishop_config"."group" IS '分组';
COMMENT ON COLUMN "public"."minishop_config"."title" IS '变量标题';
COMMENT ON COLUMN "public"."minishop_config"."tip" IS '变量描述';
COMMENT ON COLUMN "public"."minishop_config"."type" IS '类型。string,text,int,bool,array,datetime,date,file';
COMMENT ON COLUMN "public"."minishop_config"."value" IS '变量值';
COMMENT ON COLUMN "public"."minishop_config"."content" IS '变量字典数据';
COMMENT ON COLUMN "public"."minishop_config"."rule" IS '验证规则';
COMMENT ON COLUMN "public"."minishop_config"."extend" IS '扩展属性';
COMMENT ON COLUMN "public"."minishop_config"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_config"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_config"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_config"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_config" IS '商城配置';

-- ----------------------------
-- Table structure for minishop_coupons
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_coupons";
CREATE TABLE "public"."minishop_coupons" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "goods_ids" varchar COLLATE "pg_catalog"."default",
  "amount" float8 DEFAULT 0,
  "enough" float8 DEFAULT 0,
  "stock" int4 NOT NULL DEFAULT 0,
  "limit" int4 NOT NULL DEFAULT 0,
  "get_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "use_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "description" varchar COLLATE "pg_catalog"."default",
  "use_time_start" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "use_time_end" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "get_time_start" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "get_time_end" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_coupons"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_coupons"."type" IS '类型。cash=代金券,discount=折扣券';
COMMENT ON COLUMN "public"."minishop_coupons"."goods_ids" IS '适用商品';
COMMENT ON COLUMN "public"."minishop_coupons"."amount" IS '券面额';
COMMENT ON COLUMN "public"."minishop_coupons"."enough" IS '消费门槛';
COMMENT ON COLUMN "public"."minishop_coupons"."stock" IS '库存';
COMMENT ON COLUMN "public"."minishop_coupons"."limit" IS '每人限制';
COMMENT ON COLUMN "public"."minishop_coupons"."get_time" IS '领取周期';
COMMENT ON COLUMN "public"."minishop_coupons"."use_time" IS '有效期';
COMMENT ON COLUMN "public"."minishop_coupons"."description" IS '描述';
COMMENT ON COLUMN "public"."minishop_coupons"."use_time_start" IS '开始使用时间';
COMMENT ON COLUMN "public"."minishop_coupons"."use_time_end" IS '结束使用时间';
COMMENT ON COLUMN "public"."minishop_coupons"."get_time_start" IS '开始领取时间';
COMMENT ON COLUMN "public"."minishop_coupons"."get_time_end" IS '结束领取时间';
COMMENT ON COLUMN "public"."minishop_coupons"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_coupons"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_coupons"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_coupons"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_coupons" IS '商城优惠券';

-- ----------------------------
-- Table structure for minishop_decorate
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_decorate";
CREATE TABLE "public"."minishop_decorate" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "image" varchar COLLATE "pg_catalog"."default",
  "memo" varchar COLLATE "pg_catalog"."default",
  "platform" varchar COLLATE "pg_catalog"."default",
  "status" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_decorate"."name" IS '模板名称';
COMMENT ON COLUMN "public"."minishop_decorate"."type" IS '页面分类。shop=商城,custom=自定义,preview=临时预览';
COMMENT ON COLUMN "public"."minishop_decorate"."image" IS '图片';
COMMENT ON COLUMN "public"."minishop_decorate"."memo" IS '备注';
COMMENT ON COLUMN "public"."minishop_decorate"."platform" IS '适用平台。H5=H5,wxOfficialAccount=微信公众号网页,wxMiniProgram=微信小程序,App=App,preview=预览';
COMMENT ON COLUMN "public"."minishop_decorate"."status" IS '状态。normal,hidden';
COMMENT ON COLUMN "public"."minishop_decorate"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_decorate"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_decorate"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_decorate"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_decorate" IS '商城模板信息';

-- ----------------------------
-- Table structure for minishop_decorate_content
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_decorate_content";
CREATE TABLE "public"."minishop_decorate_content" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "category" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" varchar COLLATE "pg_catalog"."default",
  "decorate_id" uuid NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "status" int4 NOT NULL DEFAULT 1,
  "weight" int4 NOT NULL DEFAULT 0
)
;
COMMENT ON COLUMN "public"."minishop_decorate_content"."type" IS '类型';
COMMENT ON COLUMN "public"."minishop_decorate_content"."category" IS '页面类型。home=首页,user=个人中心,tabbar=底部导航,popup=弹出提醒,float-button=悬浮按钮,custom=自定义';
COMMENT ON COLUMN "public"."minishop_decorate_content"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_decorate_content"."content" IS '内容。json数据';
COMMENT ON COLUMN "public"."minishop_decorate_content"."decorate_id" IS '归属模板ID';
COMMENT ON COLUMN "public"."minishop_decorate_content"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_decorate_content"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_decorate_content"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_decorate_content"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."minishop_decorate_content"."status" IS '状态。0隐藏，1显示';
COMMENT ON COLUMN "public"."minishop_decorate_content"."weight" IS '排序';
COMMENT ON TABLE "public"."minishop_decorate_content" IS '页面模板装修数据';

-- ----------------------------
-- Table structure for minishop_dispatch
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_dispatch";
CREATE TABLE "public"."minishop_dispatch" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type_ids" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_dispatch"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_dispatch"."type" IS '发货方式。express=物流快递,selfetch=用户自提,store=商户配送,autosend=自动发货';
COMMENT ON COLUMN "public"."minishop_dispatch"."type_ids" IS '包含模板';
COMMENT ON COLUMN "public"."minishop_dispatch"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_dispatch"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_dispatch"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_dispatch"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_dispatch" IS '配送方式';

-- ----------------------------
-- Table structure for minishop_dispatch_autosend
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_dispatch_autosend";
CREATE TABLE "public"."minishop_dispatch_autosend" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_dispatch_autosend"."type" IS '自动发货类型。card=卡密,text=固定内容,params=自定义内容';
COMMENT ON COLUMN "public"."minishop_dispatch_autosend"."content" IS '发货内容';
COMMENT ON COLUMN "public"."minishop_dispatch_autosend"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_dispatch_autosend"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_dispatch_autosend"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_dispatch_autosend"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_dispatch_autosend" IS '自动发货';

-- ----------------------------
-- Table structure for minishop_dispatch_express
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_dispatch_express";
CREATE TABLE "public"."minishop_dispatch_express" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "weigh" int4 DEFAULT 0,
  "first_num" int4 NOT NULL DEFAULT 0,
  "first_price" float8 DEFAULT 0,
  "additional_num" int4 NOT NULL DEFAULT 0,
  "additional_price" float8 NOT NULL DEFAULT 0,
  "province_ids" uuid,
  "city_ids" uuid,
  "area_ids" uuid,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_dispatch_express"."type" IS '计费方式。number=件数,weight=重量';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."weigh" IS '权重';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."first_num" IS '首(重/件)数';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."first_price" IS '首(重/件)';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."additional_num" IS '续(重/件)数';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."additional_price" IS '续(重/件)';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."province_ids" IS '省份';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."city_ids" IS '市级';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."area_ids" IS '区域';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_dispatch_express"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_dispatch_express" IS '发货信息';

-- ----------------------------
-- Table structure for minishop_dispatch_selfetch
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_dispatch_selfetch";
CREATE TABLE "public"."minishop_dispatch_selfetch" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "store_ids" uuid NOT NULL,
  "expire_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "expire_day" int4 NOT NULL DEFAULT 0,
  "expire_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."store_ids" IS '包含门店';
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."expire_type" IS '过期类型。day=天数,time=截至日期';
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."expire_day" IS 'X天过期';
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."expire_time" IS '截至日期';
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_dispatch_selfetch"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_dispatch_selfetch" IS '自提数据';

-- ----------------------------
-- Table structure for minishop_dispatch_store
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_dispatch_store";
CREATE TABLE "public"."minishop_dispatch_store" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "store_ids" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_dispatch_store"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_dispatch_store"."store_ids" IS '包含门店';
COMMENT ON COLUMN "public"."minishop_dispatch_store"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_dispatch_store"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_dispatch_store"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_dispatch_store"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_dispatch_store" IS '自提店铺';

-- ----------------------------
-- Table structure for minishop_express
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_express";
CREATE TABLE "public"."minishop_express" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "weigh" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_express"."name" IS '快递公司名';
COMMENT ON COLUMN "public"."minishop_express"."code" IS '编码';
COMMENT ON COLUMN "public"."minishop_express"."weigh" IS '权重';
COMMENT ON COLUMN "public"."minishop_express"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_express"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_express"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_express"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_express" IS '快递公司';

-- ----------------------------
-- Table structure for minishop_failed_job
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_failed_job";
CREATE TABLE "public"."minishop_failed_job" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "data" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_failed_job"."data" IS '数据';
COMMENT ON COLUMN "public"."minishop_failed_job"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_failed_job"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_failed_job"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_failed_job"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_failed_job" IS '事务失败数据';

-- ----------------------------
-- Table structure for minishop_goods_comment
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_goods_comment";
CREATE TABLE "public"."minishop_goods_comment" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "goods_id" uuid NOT NULL,
  "order_id" uuid NOT NULL,
  "order_item_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "level" int4 NOT NULL DEFAULT 0,
  "content" varchar COLLATE "pg_catalog"."default",
  "images" varchar COLLATE "pg_catalog"."default",
  "reply_content" varchar COLLATE "pg_catalog"."default",
  "reply_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_goods_comment"."goods_id" IS '商品id';
COMMENT ON COLUMN "public"."minishop_goods_comment"."order_id" IS '订单id';
COMMENT ON COLUMN "public"."minishop_goods_comment"."order_item_id" IS '订单商品';
COMMENT ON COLUMN "public"."minishop_goods_comment"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_goods_comment"."level" IS '评价星级';
COMMENT ON COLUMN "public"."minishop_goods_comment"."content" IS '评价内容';
COMMENT ON COLUMN "public"."minishop_goods_comment"."images" IS '评价图片';
COMMENT ON COLUMN "public"."minishop_goods_comment"."reply_content" IS '显示状态';
COMMENT ON COLUMN "public"."minishop_goods_comment"."reply_time" IS '回复时间';
COMMENT ON COLUMN "public"."minishop_goods_comment"."status" IS '显示状态';
COMMENT ON COLUMN "public"."minishop_goods_comment"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_goods_comment"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_goods_comment"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_goods_comment"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_goods_comment" IS '商品评论';

-- ----------------------------
-- Table structure for minishop_goods_service
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_goods_service";
CREATE TABLE "public"."minishop_goods_service" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "image" varchar COLLATE "pg_catalog"."default",
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_goods_service"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_goods_service"."image" IS '服务标志';
COMMENT ON COLUMN "public"."minishop_goods_service"."description" IS '描述';
COMMENT ON COLUMN "public"."minishop_goods_service"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_goods_service"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_goods_service"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_goods_service"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_goods_service" IS '商品服务标识';

-- ----------------------------
-- Table structure for minishop_link
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_link";
CREATE TABLE "public"."minishop_link" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default",
  "path" varchar COLLATE "pg_catalog"."default",
  "group" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_link"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_link"."path" IS '路径';
COMMENT ON COLUMN "public"."minishop_link"."group" IS '所属分组';
COMMENT ON COLUMN "public"."minishop_link"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_link"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_link"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_link"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_link" IS '商城链接';

-- ----------------------------
-- Table structure for minishop_order
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order";
CREATE TABLE "public"."minishop_order" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "order_id" varchar COLLATE "pg_catalog"."default",
  "out_order_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "out_trade_no" varchar COLLATE "pg_catalog"."default",
  "openid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "user_id" varchar COLLATE "pg_catalog"."default",
  "type" int4 NOT NULL DEFAULT 0,
  "path" varchar COLLATE "pg_catalog"."default",
  "scene" int4 DEFAULT 0,
  "order_detail_id" varchar COLLATE "pg_catalog"."default",
  "address_info_id" varchar COLLATE "pg_catalog"."default",
  "out_aftersale_id" varchar COLLATE "pg_catalog"."default",
  "ticket" varchar COLLATE "pg_catalog"."default",
  "ticket_expire_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "final_price" int4 DEFAULT 0,
  "ext_json" varchar COLLATE "pg_catalog"."default",
  "platform" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "transaction_id" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "status" int4 NOT NULL DEFAULT 0,
  "appid" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."minishop_order"."order_id" IS '微信侧订单id';
COMMENT ON COLUMN "public"."minishop_order"."out_order_id" IS '商家自定义订单ID';
COMMENT ON COLUMN "public"."minishop_order"."out_trade_no" IS '商户支付订单号';
COMMENT ON COLUMN "public"."minishop_order"."openid" IS '微信用户openid';
COMMENT ON COLUMN "public"."minishop_order"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_order"."type" IS '非必填，默认为0。0:普通场景, 1:合单支付';
COMMENT ON COLUMN "public"."minishop_order"."path" IS '商家小程序该订单的页面path，用于微信侧订单中心跳转';
COMMENT ON COLUMN "public"."minishop_order"."scene" IS '下单时小程序的场景值';
COMMENT ON COLUMN "public"."minishop_order"."order_detail_id" IS '关联order_detail表id';
COMMENT ON COLUMN "public"."minishop_order"."address_info_id" IS '关联minishop_user_address表id';
COMMENT ON COLUMN "public"."minishop_order"."out_aftersale_id" IS '售后ID';
COMMENT ON COLUMN "public"."minishop_order"."ticket" IS '拉起收银台的ticket';
COMMENT ON COLUMN "public"."minishop_order"."ticket_expire_time" IS 'ticket有效截止时间';
COMMENT ON COLUMN "public"."minishop_order"."final_price" IS '订单最终价格（单位：分）';
COMMENT ON COLUMN "public"."minishop_order"."ext_json" IS '附加信息';
COMMENT ON COLUMN "public"."minishop_order"."platform" IS '平台。H5=H5,wxOfficialAccount=微信公众号,wxMiniProgram=微信小程序,App=App';
COMMENT ON COLUMN "public"."minishop_order"."transaction_id" IS '支付流水号';
COMMENT ON COLUMN "public"."minishop_order"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."minishop_order"."status" IS '订单状态。10=待付款,11=收银台支付完成（自动流转，对商家来说和10同等对待即可）,20=待发货,30=待收货,100=完成,200=全部商品售后之后，订单取消,250=用户主动取消/待付款超时取消/商家取消';
COMMENT ON TABLE "public"."minishop_order" IS '商城订单';

-- ----------------------------
-- Table structure for minishop_order_action
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_action";
CREATE TABLE "public"."minishop_order_action" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "order_id" uuid NOT NULL,
  "out_order_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "order_item_id" uuid,
  "oper_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "oper_id" uuid,
  "order_status" int4 NOT NULL DEFAULT 0,
  "dispatch_status" int4 NOT NULL DEFAULT 0,
  "comment_status" int4 NOT NULL DEFAULT 0,
  "aftersale_status" int4 NOT NULL DEFAULT 0,
  "refund_status" int4 NOT NULL DEFAULT 0,
  "remark" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_action"."order_id" IS '微信侧订单id';
COMMENT ON COLUMN "public"."minishop_order_action"."out_order_id" IS '商家自定义订单ID';
COMMENT ON COLUMN "public"."minishop_order_action"."order_item_id" IS '订单商品id';
COMMENT ON COLUMN "public"."minishop_order_action"."oper_type" IS '操作人类型:user,store,admin,system';
COMMENT ON COLUMN "public"."minishop_order_action"."oper_id" IS '操作人id。关联user表id';
COMMENT ON COLUMN "public"."minishop_order_action"."order_status" IS '订单状态';
COMMENT ON COLUMN "public"."minishop_order_action"."dispatch_status" IS '发货状态';
COMMENT ON COLUMN "public"."minishop_order_action"."comment_status" IS '评论状态';
COMMENT ON COLUMN "public"."minishop_order_action"."aftersale_status" IS '售后状态';
COMMENT ON COLUMN "public"."minishop_order_action"."refund_status" IS '退款状态';
COMMENT ON COLUMN "public"."minishop_order_action"."remark" IS '操作备注';
COMMENT ON COLUMN "public"."minishop_order_action"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_action"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_action"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_action"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_action" IS '订单操作数据';

-- ----------------------------
-- Table structure for minishop_order_aftersale
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_aftersale";
CREATE TABLE "public"."minishop_order_aftersale" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "aftersale_sn" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "type" int4 NOT NULL DEFAULT 0,
  "phone" varchar COLLATE "pg_catalog"."default",
  "activity_id" varchar COLLATE "pg_catalog"."default",
  "activity_type" varchar COLLATE "pg_catalog"."default",
  "order_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "out_order_id" varchar COLLATE "pg_catalog"."default",
  "order_item_id" uuid NOT NULL,
  "goods_id" uuid NOT NULL,
  "goods_sku_price_id" uuid NOT NULL,
  "goods_sku_text" varchar COLLATE "pg_catalog"."default",
  "goods_title" varchar COLLATE "pg_catalog"."default",
  "goods_image" varchar COLLATE "pg_catalog"."default",
  "goods_original_price" float8 NOT NULL DEFAULT 0,
  "discount_fee" float8 DEFAULT 0,
  "goods_price" float8 NOT NULL DEFAULT 0,
  "goods_num" int4 NOT NULL DEFAULT 0,
  "dispatch_status" int4 NOT NULL DEFAULT 0,
  "dispatch_fee" float8 DEFAULT 0,
  "aftersale_status" int4 NOT NULL DEFAULT 0,
  "refund_status" int4 NOT NULL DEFAULT 0,
  "refund_fee" float8 DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_aftersale"."aftersale_sn" IS '售后单号';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."type" IS '类型。1=退款,2=退货,3=其他';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."phone" IS '联系方式';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."activity_id" IS '活动';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."activity_type" IS '活动类型';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."order_id" IS '微信侧订单id';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."out_order_id" IS '商家自定义订单ID';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."order_item_id" IS '订单商品';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_id" IS '商品id';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_sku_price_id" IS '规格id';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_sku_text" IS '规格名';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_title" IS '商品名称';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_image" IS '商品图片';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_original_price" IS '商品原价';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."discount_fee" IS '优惠费用';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_price" IS '商品价格';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."goods_num" IS '购买数量';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."dispatch_status" IS '发货状态。0=未发货,1=已发货,2=已收货';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."dispatch_fee" IS '发货费用';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."aftersale_status" IS '售后状态。-1=拒绝,0=未处理,1=处理中,2=售后完成';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."refund_status" IS '退款状态。-1=拒绝退款,0=未退款,1=同意';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."refund_fee" IS '退款金额';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_aftersale"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_aftersale" IS '订单售后记录';

-- ----------------------------
-- Table structure for minishop_order_aftersale_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_aftersale_log";
CREATE TABLE "public"."minishop_order_aftersale_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "order_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "out_order_id" varchar COLLATE "pg_catalog"."default",
  "order_aftersale_id" uuid NOT NULL,
  "oper_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "oper_id" uuid NOT NULL,
  "dispatch_status" int4 NOT NULL DEFAULT 0,
  "aftersale_status" int4 NOT NULL DEFAULT 0,
  "refund_status" int4 NOT NULL DEFAULT 0,
  "reason" varchar COLLATE "pg_catalog"."default",
  "content" varchar COLLATE "pg_catalog"."default",
  "images" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."order_id" IS '微信侧订单id';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."out_order_id" IS '商家自定义订单ID';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."order_aftersale_id" IS '售后单';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."oper_type" IS '操作人类型。user,store,admin,system';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."oper_id" IS '操作人id';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."dispatch_status" IS '发货状态';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."aftersale_status" IS '售后状态';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."refund_status" IS '退款状态';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."reason" IS '售后原因';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."content" IS '内容';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."images" IS '图片';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_aftersale_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_aftersale_log" IS '订单售后记录';

-- ----------------------------
-- Table structure for minishop_order_detail
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_detail";
CREATE TABLE "public"."minishop_order_detail" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "product_infos" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "pay_info" varchar COLLATE "pg_catalog"."default",
  "multi_pay_info" varchar COLLATE "pg_catalog"."default",
  "price_info" varchar COLLATE "pg_catalog"."default",
  "delivery_detail" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_detail"."product_infos" IS '订单商品信息';
COMMENT ON COLUMN "public"."minishop_order_detail"."pay_info" IS '订单支付信息。payorder时action_type!=6时存在';
COMMENT ON COLUMN "public"."minishop_order_detail"."multi_pay_info" IS '订单支付信息。payorder时action_type=6时存在';
COMMENT ON COLUMN "public"."minishop_order_detail"."price_info" IS '订单价格信息';
COMMENT ON COLUMN "public"."minishop_order_detail"."delivery_detail" IS '订单物流信息。必须调过发货接口才会存在这个字段';
COMMENT ON COLUMN "public"."minishop_order_detail"."status" IS '订单详情状态';
COMMENT ON COLUMN "public"."minishop_order_detail"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_detail"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_detail"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_detail"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_detail" IS '订单详情。数据结构与此文档一致 https://developers.weixin.qq.com/miniprogram/dev/platform-capabilities/business-capabilities/ministore/minishopopencomponent/API/order/get_order_detail.html';

-- ----------------------------
-- Table structure for minishop_order_express
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_express";
CREATE TABLE "public"."minishop_order_express" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "order_id" uuid NOT NULL,
  "express_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "express_code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "express_no" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_express"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_order_express"."order_id" IS '订单id';
COMMENT ON COLUMN "public"."minishop_order_express"."express_name" IS '快递公司';
COMMENT ON COLUMN "public"."minishop_order_express"."express_code" IS '公司编号';
COMMENT ON COLUMN "public"."minishop_order_express"."express_no" IS '快递单号';
COMMENT ON COLUMN "public"."minishop_order_express"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_express"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_express"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_express"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_express" IS '订单快递信息';

-- ----------------------------
-- Table structure for minishop_order_express_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_express_log";
CREATE TABLE "public"."minishop_order_express_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "order_id" uuid NOT NULL,
  "order_express_id" uuid NOT NULL,
  "location" varchar COLLATE "pg_catalog"."default",
  "content" varchar COLLATE "pg_catalog"."default",
  "changedate" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_express_log"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_order_express_log"."order_id" IS '订单id';
COMMENT ON COLUMN "public"."minishop_order_express_log"."order_express_id" IS '包裹快递单号';
COMMENT ON COLUMN "public"."minishop_order_express_log"."location" IS '地址信息';
COMMENT ON COLUMN "public"."minishop_order_express_log"."content" IS '物流信息';
COMMENT ON COLUMN "public"."minishop_order_express_log"."changedate" IS '变动时间';
COMMENT ON COLUMN "public"."minishop_order_express_log"."status" IS '物流状态';
COMMENT ON COLUMN "public"."minishop_order_express_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_express_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_express_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_express_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_express_log" IS '订单快递记录';

-- ----------------------------
-- Table structure for minishop_order_item
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_item";
CREATE TABLE "public"."minishop_order_item" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "order_id" varchar COLLATE "pg_catalog"."default",
  "out_order_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "goods_id" uuid NOT NULL,
  "goods_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "goods_sku_price_id" uuid NOT NULL,
  "activity_id" uuid,
  "activity_type" varchar COLLATE "pg_catalog"."default",
  "item_goods_sku_price_id" uuid,
  "goods_sku_text" varchar COLLATE "pg_catalog"."default",
  "goods_title" varchar COLLATE "pg_catalog"."default",
  "goods_image" varchar COLLATE "pg_catalog"."default",
  "goods_original_price" float8 DEFAULT 0,
  "discount_fee" float8 DEFAULT 0,
  "goods_price" float8 DEFAULT 0,
  "goods_num" int4 NOT NULL DEFAULT 0,
  "pay_price" float8 NOT NULL DEFAULT 0,
  "dispatch_status" int4 NOT NULL DEFAULT 0,
  "dispatch_fee" float8 DEFAULT 0,
  "dispatch_type" varchar COLLATE "pg_catalog"."default",
  "dispatch_id" uuid,
  "store_id" uuid,
  "aftersale_status" int4 NOT NULL DEFAULT 0,
  "comment_status" int4 NOT NULL DEFAULT 0,
  "refund_status" int4 DEFAULT 0,
  "refund_fee" float8 DEFAULT 0,
  "refund_msg" varchar COLLATE "pg_catalog"."default",
  "express_name" varchar COLLATE "pg_catalog"."default",
  "express_code" varchar COLLATE "pg_catalog"."default",
  "express_no" varchar COLLATE "pg_catalog"."default",
  "ext" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_item"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_order_item"."order_id" IS '微信侧订单id';
COMMENT ON COLUMN "public"."minishop_order_item"."out_order_id" IS '商家自定义订单ID';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_id" IS '商品id';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_type" IS '商品类型。normal=实体商品,virtual=虚拟商品';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_sku_price_id" IS '规格id';
COMMENT ON COLUMN "public"."minishop_order_item"."activity_id" IS '活动id';
COMMENT ON COLUMN "public"."minishop_order_item"."activity_type" IS '活动类型';
COMMENT ON COLUMN "public"."minishop_order_item"."item_goods_sku_price_id" IS '活动规格|积分商城规格id';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_sku_text" IS '规格名';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_title" IS '商品名称';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_image" IS '商品图片';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_original_price" IS '商品原价';
COMMENT ON COLUMN "public"."minishop_order_item"."discount_fee" IS '优惠费用';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_price" IS '商品价格';
COMMENT ON COLUMN "public"."minishop_order_item"."goods_num" IS '购买数量';
COMMENT ON COLUMN "public"."minishop_order_item"."pay_price" IS '支付金额(不含运费)';
COMMENT ON COLUMN "public"."minishop_order_item"."dispatch_status" IS '发货状态。0=未发货,1=已发货,2=已收货';
COMMENT ON COLUMN "public"."minishop_order_item"."dispatch_fee" IS '发货费用';
COMMENT ON COLUMN "public"."minishop_order_item"."dispatch_type" IS '发货方式';
COMMENT ON COLUMN "public"."minishop_order_item"."dispatch_id" IS '发货模板';
COMMENT ON COLUMN "public"."minishop_order_item"."store_id" IS '门店';
COMMENT ON COLUMN "public"."minishop_order_item"."aftersale_status" IS '售后状态。-1=拒绝,0=未申请,1=申请售后,2=售后完成';
COMMENT ON COLUMN "public"."minishop_order_item"."comment_status" IS '评价状态。0=未评价,1=已评价';
COMMENT ON COLUMN "public"."minishop_order_item"."refund_status" IS '退款状态。-1=拒绝退款,0=无,1=申请中,2=同意';
COMMENT ON COLUMN "public"."minishop_order_item"."refund_fee" IS '退款金额';
COMMENT ON COLUMN "public"."minishop_order_item"."refund_msg" IS '退款原因';
COMMENT ON COLUMN "public"."minishop_order_item"."express_name" IS '快递公司';
COMMENT ON COLUMN "public"."minishop_order_item"."express_code" IS '快递公司编号';
COMMENT ON COLUMN "public"."minishop_order_item"."express_no" IS '快递单号';
COMMENT ON COLUMN "public"."minishop_order_item"."ext" IS '附加字段';
COMMENT ON COLUMN "public"."minishop_order_item"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_item"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_item"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_item"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_item" IS '订单详情';

-- ----------------------------
-- Table structure for minishop_order_status
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_order_status";
CREATE TABLE "public"."minishop_order_status" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_order_status"."title" IS '描述';
COMMENT ON COLUMN "public"."minishop_order_status"."value" IS '枚举值';
COMMENT ON COLUMN "public"."minishop_order_status"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_order_status"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_order_status"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_order_status"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_order_status" IS '订单状态枚举';

-- ----------------------------
-- Table structure for minishop_product_category
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_product_category";
CREATE TABLE "public"."minishop_product_category" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "parent_id" uuid,
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "category_title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "weight" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "category_image" varchar COLLATE "pg_catalog"."default",
  "category_type" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."minishop_product_category"."parent_id" IS '类目父ID';
COMMENT ON COLUMN "public"."minishop_product_category"."name" IS '类目名称';
COMMENT ON COLUMN "public"."minishop_product_category"."category_title" IS '类目标题';
COMMENT ON COLUMN "public"."minishop_product_category"."weight" IS '类目排序';
COMMENT ON COLUMN "public"."minishop_product_category"."status" IS '类目状态';
COMMENT ON COLUMN "public"."minishop_product_category"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_product_category"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_product_category"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_product_category"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."minishop_product_category"."category_image" IS '类目图片';
COMMENT ON COLUMN "public"."minishop_product_category"."category_type" IS '类目类型';
COMMENT ON TABLE "public"."minishop_product_category" IS '商品类目';

-- ----------------------------
-- Table structure for minishop_refund_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_refund_log";
CREATE TABLE "public"."minishop_refund_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "order_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "out_order_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "refund_sn" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "order_item_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "pay_fee" float8 NOT NULL DEFAULT 0,
  "refund_fee" float8 NOT NULL DEFAULT 0,
  "pay_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "payment_json" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_refund_log"."order_id" IS '微信侧订单id';
COMMENT ON COLUMN "public"."minishop_refund_log"."out_order_id" IS '商家自定义订单ID';
COMMENT ON COLUMN "public"."minishop_refund_log"."refund_sn" IS '商户退款单号';
COMMENT ON COLUMN "public"."minishop_refund_log"."order_item_id" IS '订单商品';
COMMENT ON COLUMN "public"."minishop_refund_log"."pay_fee" IS '支付金额';
COMMENT ON COLUMN "public"."minishop_refund_log"."refund_fee" IS '退款金额';
COMMENT ON COLUMN "public"."minishop_refund_log"."pay_type" IS '付款方式';
COMMENT ON COLUMN "public"."minishop_refund_log"."payment_json" IS '退款原始数据';
COMMENT ON COLUMN "public"."minishop_refund_log"."status" IS '退款状态。0=退款中,1=退款完成,-1=退款失败''';
COMMENT ON COLUMN "public"."minishop_refund_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_refund_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_refund_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_refund_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_refund_log" IS '退款记录';

-- ----------------------------
-- Table structure for minishop_share
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_share";
CREATE TABLE "public"."minishop_share" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "share_id" uuid NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default",
  "type_id" varchar COLLATE "pg_catalog"."default",
  "platform" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_share"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_share"."share_id" IS '分享人';
COMMENT ON COLUMN "public"."minishop_share"."type" IS '识别类型';
COMMENT ON COLUMN "public"."minishop_share"."type_id" IS '识别标识';
COMMENT ON COLUMN "public"."minishop_share"."platform" IS '平台';
COMMENT ON COLUMN "public"."minishop_share"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_share"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_share"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_share"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_share" IS '分享记录';

-- ----------------------------
-- Table structure for minishop_shipping_method
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_shipping_method";
CREATE TABLE "public"."minishop_shipping_method" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_shipping_method"."title" IS '描述';
COMMENT ON COLUMN "public"."minishop_shipping_method"."value" IS '枚举值';
COMMENT ON COLUMN "public"."minishop_shipping_method"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_shipping_method"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_shipping_method"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_shipping_method"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_shipping_method" IS '发货方式枚举';

-- ----------------------------
-- Table structure for minishop_sku
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_sku";
CREATE TABLE "public"."minishop_sku" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "product_id" uuid NOT NULL,
  "out_product_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "sku_id" uuid NOT NULL,
  "sku_name" varchar COLLATE "pg_catalog"."default",
  "out_sku_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "thumb_img" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "sale_price" int4 NOT NULL DEFAULT 0,
  "market_price" int4 NOT NULL DEFAULT 0,
  "stock_num" int4 NOT NULL DEFAULT 0,
  "barcode" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "sku_code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "sku_attrs" uuid NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_sku"."product_id" IS '小商店内部商品ID';
COMMENT ON COLUMN "public"."minishop_sku"."out_product_id" IS '商家自定义商品ID';
COMMENT ON COLUMN "public"."minishop_sku"."sku_id" IS '小商店内部sku_iD';
COMMENT ON COLUMN "public"."minishop_sku"."sku_name" IS 'sku名称';
COMMENT ON COLUMN "public"."minishop_sku"."out_sku_id" IS '商家自定义sku_id';
COMMENT ON COLUMN "public"."minishop_sku"."thumb_img" IS 'sku小图';
COMMENT ON COLUMN "public"."minishop_sku"."sale_price" IS '售卖价格,以分为单位';
COMMENT ON COLUMN "public"."minishop_sku"."market_price" IS '市场价格,以分为单位';
COMMENT ON COLUMN "public"."minishop_sku"."stock_num" IS '库存';
COMMENT ON COLUMN "public"."minishop_sku"."barcode" IS '条形码';
COMMENT ON COLUMN "public"."minishop_sku"."sku_code" IS '商品编码';
COMMENT ON COLUMN "public"."minishop_sku"."sku_attrs" IS '属性自定义用';
COMMENT ON COLUMN "public"."minishop_sku"."status" IS 'sku状态。5=上架中,21=假删除';
COMMENT ON COLUMN "public"."minishop_sku"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_sku"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_sku"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_sku"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_sku" IS 'sku数据。与此文档数据结构一致https://developers.weixin.qq.com/miniprogram/dev/platform-capabilities/business-capabilities/ministore/minishopopencomponent/API/sku/get_sku.html';

-- ----------------------------
-- Table structure for minishop_sku_attrs
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_sku_attrs";
CREATE TABLE "public"."minishop_sku_attrs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "key" varchar COLLATE "pg_catalog"."default",
  "value" varchar COLLATE "pg_catalog"."default",
  "parent_id" uuid,
  "spu_id" uuid NOT NULL,
  "weigh" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_sku_attrs"."name" IS '名称';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."key" IS '属性键';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."value" IS '属性值';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."parent_id" IS '父属性组';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."spu_id" IS '所属商品id。关联spu表out_product_d';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."weigh" IS '排序';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_sku_attrs"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_sku_attrs" IS 'sku属性';

-- ----------------------------
-- Table structure for minishop_sku_status
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_sku_status";
CREATE TABLE "public"."minishop_sku_status" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_sku_status"."title" IS '描述';
COMMENT ON COLUMN "public"."minishop_sku_status"."value" IS '枚举值';
COMMENT ON COLUMN "public"."minishop_sku_status"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_sku_status"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_sku_status"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_sku_status"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_sku_status" IS 'sku状态';

-- ----------------------------
-- Table structure for minishop_spu
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_spu";
CREATE TABLE "public"."minishop_spu" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "out_product_id" varchar COLLATE "pg_catalog"."default",
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "subtitle" varchar COLLATE "pg_catalog"."default",
  "headimg" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "edit_status" int4 NOT NULL DEFAULT 0,
  "min_price" int4 NOT NULL DEFAULT 0,
  "cats" varchar COLLATE "pg_catalog"."default",
  "attrs" varchar COLLATE "pg_catalog"."default",
  "model" uuid,
  "dispatch_type" varchar COLLATE "pg_catalog"."default",
  "express_info" varchar COLLATE "pg_catalog"."default",
  "shopcat" varchar COLLATE "pg_catalog"."default",
  "skus" varchar COLLATE "pg_catalog"."default",
  "sales_count" int4 NOT NULL DEFAULT 0,
  "weigh" int4 NOT NULL DEFAULT 0,
  "template_id" varchar COLLATE "pg_catalog"."default",
  "ext_json" varchar COLLATE "pg_catalog"."default",
  "memo" varchar COLLATE "pg_catalog"."default",
  "ext_attrs" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "start_at" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "end_at" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "meet_at" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "address" varchar COLLATE "pg_catalog"."default",
  "latitude" float8 DEFAULT 0,
  "longitude" float8 DEFAULT 0,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "desc_info" varchar COLLATE "pg_catalog"."default",
  "brand_id" int4 DEFAULT 0
)
;
COMMENT ON COLUMN "public"."minishop_spu"."out_product_id" IS '商家自定义商品ID';
COMMENT ON COLUMN "public"."minishop_spu"."title" IS '标题';
COMMENT ON COLUMN "public"."minishop_spu"."subtitle" IS '副标题';
COMMENT ON COLUMN "public"."minishop_spu"."headimg" IS '主图,多张,列表';
COMMENT ON COLUMN "public"."minishop_spu"."status" IS '商品线上状态';
COMMENT ON COLUMN "public"."minishop_spu"."edit_status" IS '商品草稿状态';
COMMENT ON COLUMN "public"."minishop_spu"."min_price" IS '商品SKU最小价格（单位：分）';
COMMENT ON COLUMN "public"."minishop_spu"."cats" IS '商家需要先申请可使用类目';
COMMENT ON COLUMN "public"."minishop_spu"."attrs" IS '商品属性';
COMMENT ON COLUMN "public"."minishop_spu"."model" IS '商品型号';
COMMENT ON COLUMN "public"."minishop_spu"."dispatch_type" IS '发货方式。express=物流快递,selfetch=用户自提,store=商家配送,autosend=自动发货';
COMMENT ON COLUMN "public"."minishop_spu"."express_info" IS '运费模板ID';
COMMENT ON COLUMN "public"."minishop_spu"."shopcat" IS '分类ID';
COMMENT ON COLUMN "public"."minishop_spu"."skus" IS '商品skus';
COMMENT ON COLUMN "public"."minishop_spu"."sales_count" IS '销量';
COMMENT ON COLUMN "public"."minishop_spu"."weigh" IS '排序';
COMMENT ON COLUMN "public"."minishop_spu"."template_id" IS '模板id';
COMMENT ON COLUMN "public"."minishop_spu"."ext_json" IS 'ext_json';
COMMENT ON COLUMN "public"."minishop_spu"."memo" IS '备注';
COMMENT ON COLUMN "public"."minishop_spu"."ext_attrs" IS '更多属性';
COMMENT ON COLUMN "public"."minishop_spu"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_spu"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_spu"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_spu"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."minishop_spu"."desc_info" IS '商品详情，图文';
COMMENT ON TABLE "public"."minishop_spu" IS 'spu数据。与此文档一致https://developers.weixin.qq.com/miniprogram/dev/platform-capabilities/business-capabilities/ministore/minishopopencomponent/API/spu/get_spu.html';

-- ----------------------------
-- Table structure for minishop_spu_edit_status
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_spu_edit_status";
CREATE TABLE "public"."minishop_spu_edit_status" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_spu_edit_status"."title" IS '描述';
COMMENT ON COLUMN "public"."minishop_spu_edit_status"."value" IS '枚举值';
COMMENT ON COLUMN "public"."minishop_spu_edit_status"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_spu_edit_status"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_spu_edit_status"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_spu_edit_status"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_spu_edit_status" IS 'spu编辑状态枚举';

-- ----------------------------
-- Table structure for minishop_spu_status
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_spu_status";
CREATE TABLE "public"."minishop_spu_status" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_spu_status"."title" IS '描述';
COMMENT ON COLUMN "public"."minishop_spu_status"."value" IS '枚举值';
COMMENT ON COLUMN "public"."minishop_spu_status"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_spu_status"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_spu_status"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_spu_status"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_spu_status" IS 'spu状态枚举';

-- ----------------------------
-- Table structure for minishop_store
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_store";
CREATE TABLE "public"."minishop_store" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "headimg" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "realname" varchar COLLATE "pg_catalog"."default",
  "phone" varchar COLLATE "pg_catalog"."default",
  "province_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "city_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "area_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "province_id" varchar COLLATE "pg_catalog"."default",
  "city_id" varchar COLLATE "pg_catalog"."default",
  "area_id" varchar COLLATE "pg_catalog"."default",
  "address" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "latitude" float8 DEFAULT 0,
  "longitude" float8 DEFAULT 0,
  "store" int4 NOT NULL DEFAULT 0,
  "selfetch" int4 NOT NULL DEFAULT 0,
  "service_type" varchar COLLATE "pg_catalog"."default",
  "service_radius" int4 NOT NULL DEFAULT 0,
  "service_province_ids" varchar COLLATE "pg_catalog"."default",
  "service_city_ids" uuid,
  "service_area_ids" varchar COLLATE "pg_catalog"."default",
  "openhours" varchar COLLATE "pg_catalog"."default",
  "openweeks" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "desc_info" varchar COLLATE "pg_catalog"."default",
  "parent_id" uuid,
  "principal" varchar COLLATE "pg_catalog"."default",
  "cover" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."minishop_store"."name" IS '门店名称';
COMMENT ON COLUMN "public"."minishop_store"."headimg" IS '门店图片';
COMMENT ON COLUMN "public"."minishop_store"."realname" IS '联系人';
COMMENT ON COLUMN "public"."minishop_store"."phone" IS '联系电话';
COMMENT ON COLUMN "public"."minishop_store"."province_name" IS '省';
COMMENT ON COLUMN "public"."minishop_store"."city_name" IS '市';
COMMENT ON COLUMN "public"."minishop_store"."area_name" IS '区';
COMMENT ON COLUMN "public"."minishop_store"."province_id" IS '省id';
COMMENT ON COLUMN "public"."minishop_store"."city_id" IS '市id';
COMMENT ON COLUMN "public"."minishop_store"."area_id" IS '区id';
COMMENT ON COLUMN "public"."minishop_store"."address" IS '详细地址';
COMMENT ON COLUMN "public"."minishop_store"."latitude" IS '纬度';
COMMENT ON COLUMN "public"."minishop_store"."longitude" IS '经度';
COMMENT ON COLUMN "public"."minishop_store"."store" IS '支持配送。0=否,1=是';
COMMENT ON COLUMN "public"."minishop_store"."selfetch" IS '支持自提。0=否,1=是';
COMMENT ON COLUMN "public"."minishop_store"."service_type" IS '服务范围';
COMMENT ON COLUMN "public"."minishop_store"."service_radius" IS '服务半径';
COMMENT ON COLUMN "public"."minishop_store"."service_province_ids" IS '服务行政省';
COMMENT ON COLUMN "public"."minishop_store"."service_city_ids" IS '服务行政市';
COMMENT ON COLUMN "public"."minishop_store"."service_area_ids" IS '服务行政区';
COMMENT ON COLUMN "public"."minishop_store"."openhours" IS '营业时间';
COMMENT ON COLUMN "public"."minishop_store"."openweeks" IS '营业天数';
COMMENT ON COLUMN "public"."minishop_store"."status" IS '门店状态。0=禁用,1=启用';
COMMENT ON COLUMN "public"."minishop_store"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_store"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_store"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_store"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_store" IS '门店信息';

-- ----------------------------
-- Table structure for minishop_store_apply
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_store_apply";
CREATE TABLE "public"."minishop_store_apply" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid,
  "apply_num" int4 DEFAULT 0,
  "status_msg" varchar COLLATE "pg_catalog"."default",
  "status" int4 DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "gender" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "idcard_image" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "idcard_no" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "mobile" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "realname" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "skill" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "user_model" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "address" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "age" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "badly_off" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "birthday" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "buddhist_name" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "career" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "conversion_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "corporation" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "education" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "emergency_contact" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "emergency_mobile" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "emergency_relationship" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "health" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "idcard_type" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "job_title" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "nationality" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "reason" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "school" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "signin_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "signout_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."minishop_store_apply"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_store_apply"."apply_num" IS '申请次数';
COMMENT ON COLUMN "public"."minishop_store_apply"."status_msg" IS '审核信息';
COMMENT ON COLUMN "public"."minishop_store_apply"."status" IS '审核状态。-1驳回,0=未审核,1=已通过';
COMMENT ON COLUMN "public"."minishop_store_apply"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_store_apply"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_store_apply"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_store_apply"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_store_apply" IS '门店申请';

-- ----------------------------
-- Table structure for minishop_user_address
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_user_address";
CREATE TABLE "public"."minishop_user_address" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "is_default" int4 NOT NULL DEFAULT 0,
  "user_id" uuid NOT NULL,
  "consignee" varchar COLLATE "pg_catalog"."default",
  "phone" varchar COLLATE "pg_catalog"."default",
  "province_name" varchar COLLATE "pg_catalog"."default",
  "city_name" varchar COLLATE "pg_catalog"."default",
  "area_name" varchar COLLATE "pg_catalog"."default",
  "province_id" uuid,
  "city_id" uuid,
  "area_id" uuid,
  "latitude" float8 DEFAULT 0,
  "longitude" float8 DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "address" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."minishop_user_address"."is_default" IS '是否默认。0否，1是';
COMMENT ON COLUMN "public"."minishop_user_address"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_user_address"."consignee" IS '收货人';
COMMENT ON COLUMN "public"."minishop_user_address"."phone" IS '联系电话';
COMMENT ON COLUMN "public"."minishop_user_address"."province_name" IS '省';
COMMENT ON COLUMN "public"."minishop_user_address"."city_name" IS '市';
COMMENT ON COLUMN "public"."minishop_user_address"."area_name" IS '区';
COMMENT ON COLUMN "public"."minishop_user_address"."province_id" IS '省id';
COMMENT ON COLUMN "public"."minishop_user_address"."city_id" IS '市id';
COMMENT ON COLUMN "public"."minishop_user_address"."area_id" IS '区id';
COMMENT ON COLUMN "public"."minishop_user_address"."latitude" IS '纬度';
COMMENT ON COLUMN "public"."minishop_user_address"."longitude" IS '经度';
COMMENT ON COLUMN "public"."minishop_user_address"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_user_address"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_user_address"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_user_address"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."minishop_user_address"."address" IS '详细地址';
COMMENT ON TABLE "public"."minishop_user_address" IS '用户收获地址';

-- ----------------------------
-- Table structure for minishop_user_bank
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_user_bank";
CREATE TABLE "public"."minishop_user_bank" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "realname" varchar COLLATE "pg_catalog"."default",
  "bank_name" varchar COLLATE "pg_catalog"."default",
  "card_no" varchar COLLATE "pg_catalog"."default",
  "is_default" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_user_bank"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_user_bank"."realname" IS '真实姓名';
COMMENT ON COLUMN "public"."minishop_user_bank"."bank_name" IS '银行名';
COMMENT ON COLUMN "public"."minishop_user_bank"."card_no" IS '卡号';
COMMENT ON COLUMN "public"."minishop_user_bank"."is_default" IS '是否默认。0否。1是';
COMMENT ON COLUMN "public"."minishop_user_bank"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_user_bank"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_user_bank"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_user_bank"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_user_bank" IS '用户银行账户';

-- ----------------------------
-- Table structure for minishop_user_coupons
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_user_coupons";
CREATE TABLE "public"."minishop_user_coupons" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "coupons_id" uuid NOT NULL,
  "use_order_id" uuid NOT NULL,
  "use_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "create_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_user_coupons"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_user_coupons"."coupons_id" IS '优惠券id';
COMMENT ON COLUMN "public"."minishop_user_coupons"."use_order_id" IS '订单id';
COMMENT ON COLUMN "public"."minishop_user_coupons"."use_time" IS '使用时间';
COMMENT ON COLUMN "public"."minishop_user_coupons"."create_time" IS '领取时间';
COMMENT ON COLUMN "public"."minishop_user_coupons"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_user_coupons"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_user_coupons"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_user_coupons"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_user_coupons" IS '用户优惠券';

-- ----------------------------
-- Table structure for minishop_user_favorite
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_user_favorite";
CREATE TABLE "public"."minishop_user_favorite" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "goods_id" uuid NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_user_favorite"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_user_favorite"."goods_id" IS '商品id';
COMMENT ON COLUMN "public"."minishop_user_favorite"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_user_favorite"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_user_favorite"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_user_favorite"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_user_favorite" IS '用户收藏';

-- ----------------------------
-- Table structure for minishop_user_store
-- ----------------------------
DROP TABLE IF EXISTS "public"."minishop_user_store";
CREATE TABLE "public"."minishop_user_store" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "store_id" uuid NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."minishop_user_store"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."minishop_user_store"."store_id" IS '门店id';
COMMENT ON COLUMN "public"."minishop_user_store"."creator" IS '创建人';
COMMENT ON COLUMN "public"."minishop_user_store"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."minishop_user_store"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."minishop_user_store"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."minishop_user_store" IS '用户所属门店';

-- ----------------------------
-- Table structure for module_config
-- ----------------------------
DROP TABLE IF EXISTS "public"."module_config";
CREATE TABLE "public"."module_config" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "module_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "component" varchar COLLATE "pg_catalog"."default",
  "key" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "parent_id" uuid
)
;
COMMENT ON COLUMN "public"."module_config"."module_name" IS '模块唯一名。与模块module.json中uni_name一致';
COMMENT ON COLUMN "public"."module_config"."name" IS '配置名称';
COMMENT ON COLUMN "public"."module_config"."component" IS 'tab 引入的组件名称';
COMMENT ON COLUMN "public"."module_config"."key" IS '配置键名';
COMMENT ON COLUMN "public"."module_config"."value" IS '配置键值';
COMMENT ON COLUMN "public"."module_config"."status" IS '状态。1=启用,2=禁用';
COMMENT ON COLUMN "public"."module_config"."creator" IS '创建人';
COMMENT ON COLUMN "public"."module_config"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."module_config"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."module_config"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."module_config" IS '模块配置信息';

-- ----------------------------
-- Table structure for operate_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."operate_log";
CREATE TABLE "public"."operate_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "module" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "operate" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "route" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "params" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "ip" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "method" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."operate_log"."module" IS '模块名称';
COMMENT ON COLUMN "public"."operate_log"."operate" IS '操作模块';
COMMENT ON COLUMN "public"."operate_log"."route" IS '路由';
COMMENT ON COLUMN "public"."operate_log"."params" IS '参数';
COMMENT ON COLUMN "public"."operate_log"."ip" IS 'ip';
COMMENT ON COLUMN "public"."operate_log"."method" IS '请求方法';
COMMENT ON COLUMN "public"."operate_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."operate_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."operate_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."operate_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."operate_log" IS '操作记录';

-- ----------------------------
-- Table structure for os_platform
-- ----------------------------
DROP TABLE IF EXISTS "public"."os_platform";
CREATE TABLE "public"."os_platform" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."os_platform"."title" IS '描述';
COMMENT ON COLUMN "public"."os_platform"."value" IS '枚举值';
COMMENT ON COLUMN "public"."os_platform"."creator" IS '创建人';
COMMENT ON COLUMN "public"."os_platform"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."os_platform"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."os_platform"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."os_platform" IS '操作系统';

-- ----------------------------
-- Table structure for permissions
-- ----------------------------
DROP TABLE IF EXISTS "public"."permissions";
CREATE TABLE "public"."permissions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "permission_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "level" varchar COLLATE "pg_catalog"."default",
  "icon" varchar COLLATE "pg_catalog"."default",
  "module" varchar COLLATE "pg_catalog"."default",
  "component" varchar COLLATE "pg_catalog"."default",
  "redirect" varchar COLLATE "pg_catalog"."default",
  "type" int4 NOT NULL DEFAULT 1,
  "hidden" int4 NOT NULL DEFAULT 1,
  "weight" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "keepalive" int4 NOT NULL DEFAULT 1,
  "path" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "title" varchar COLLATE "pg_catalog"."default",
  "parent_id" uuid,
  "meta" jsonb,
  "method" varchar COLLATE "pg_catalog"."default",
  "menu_type" varchar COLLATE "pg_catalog"."default" DEFAULT 'normal'::character varying,
  "locale" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying
)
;
COMMENT ON COLUMN "public"."permissions"."permission_name" IS '菜单名称';
COMMENT ON COLUMN "public"."permissions"."level" IS '层级。顶层为0';
COMMENT ON COLUMN "public"."permissions"."icon" IS '菜单图标';
COMMENT ON COLUMN "public"."permissions"."module" IS '模块';
COMMENT ON COLUMN "public"."permissions"."component" IS '组件名称';
COMMENT ON COLUMN "public"."permissions"."redirect" IS '跳转地址';
COMMENT ON COLUMN "public"."permissions"."type" IS '类型。1 菜单 2 按钮';
COMMENT ON COLUMN "public"."permissions"."hidden" IS '是否隐藏。0隐藏，1显示';
COMMENT ON COLUMN "public"."permissions"."weight" IS '排序';
COMMENT ON COLUMN "public"."permissions"."creator" IS '创建人';
COMMENT ON COLUMN "public"."permissions"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."permissions"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."permissions"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."permissions"."keepalive" IS '1 缓存 2 不存在';
COMMENT ON COLUMN "public"."permissions"."menu_type" IS '菜单类型';
COMMENT ON COLUMN "public"."permissions"."locale" IS '国际化key';
COMMENT ON TABLE "public"."permissions" IS '权限';

-- ----------------------------
-- Table structure for review
-- ----------------------------
DROP TABLE IF EXISTS "public"."review";
CREATE TABLE "public"."review" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "score" int4 NOT NULL,
  "description" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "group_id" uuid,
  "link" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."review"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."review"."creator" IS '创建人';
COMMENT ON COLUMN "public"."review"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."review"."updated_at" IS '更新时间';

-- ----------------------------
-- Table structure for role_has_permission
-- ----------------------------
DROP TABLE IF EXISTS "public"."role_has_permission";
CREATE TABLE "public"."role_has_permission" (
  "role_id" uuid NOT NULL,
  "permission_name" text COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;

-- ----------------------------
-- Table structure for sensitive_word
-- ----------------------------
DROP TABLE IF EXISTS "public"."sensitive_word";
CREATE TABLE "public"."sensitive_word" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "word" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."sensitive_word"."word" IS '词汇';
COMMENT ON COLUMN "public"."sensitive_word"."creator" IS '创建人';
COMMENT ON COLUMN "public"."sensitive_word"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."sensitive_word"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."sensitive_word"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."sensitive_word" IS '敏感词';

-- ----------------------------
-- Table structure for sms_config
-- ----------------------------
DROP TABLE IF EXISTS "public"."sms_config";
CREATE TABLE "public"."sms_config" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default",
  "parent_id" uuid,
  "key" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."sms_config"."name" IS '运营商名称';
COMMENT ON COLUMN "public"."sms_config"."parent_id" IS '父级id';
COMMENT ON COLUMN "public"."sms_config"."key" IS 'key';
COMMENT ON COLUMN "public"."sms_config"."value" IS 'value';
COMMENT ON COLUMN "public"."sms_config"."creator" IS '创建人';
COMMENT ON COLUMN "public"."sms_config"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."sms_config"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."sms_config"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."sms_config" IS '短信配置';

-- ----------------------------
-- Table structure for sms_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."sms_log";
CREATE TABLE "public"."sms_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "event" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "mobile" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "times" int4 NOT NULL DEFAULT 0,
  "ip" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."sms_log"."event" IS '事件';
COMMENT ON COLUMN "public"."sms_log"."mobile" IS '手机号';
COMMENT ON COLUMN "public"."sms_log"."code" IS '验证码';
COMMENT ON COLUMN "public"."sms_log"."times" IS '验证次数';
COMMENT ON COLUMN "public"."sms_log"."ip" IS 'ip';
COMMENT ON COLUMN "public"."sms_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."sms_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."sms_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."sms_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."sms_log" IS '短信记录';

-- ----------------------------
-- Table structure for sms_template
-- ----------------------------
DROP TABLE IF EXISTS "public"."sms_template";
CREATE TABLE "public"."sms_template" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "operator" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "identify" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."sms_template"."name" IS '模版名称';
COMMENT ON COLUMN "public"."sms_template"."operator" IS '运营商';
COMMENT ON COLUMN "public"."sms_template"."identify" IS '模版标识';
COMMENT ON COLUMN "public"."sms_template"."code" IS '模版CODE';
COMMENT ON COLUMN "public"."sms_template"."creator" IS '创建人';
COMMENT ON COLUMN "public"."sms_template"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."sms_template"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."sms_template"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."sms_template" IS '短信模板';

-- ----------------------------
-- Table structure for tag
-- ----------------------------
DROP TABLE IF EXISTS "public"."tag";
CREATE TABLE "public"."tag" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."tag"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."tag"."creator" IS '创建人';
COMMENT ON COLUMN "public"."tag"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."tag"."updated_at" IS '更新时间';

-- ----------------------------
-- Table structure for uctoo_role
-- ----------------------------
DROP TABLE IF EXISTS "public"."uctoo_role";
CREATE TABLE "public"."uctoo_role" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."uctoo_role"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."uctoo_role"."creator" IS '创建人';
COMMENT ON COLUMN "public"."uctoo_role"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."uctoo_role"."updated_at" IS '更新时间';

-- ----------------------------
-- Table structure for uctoo_session
-- ----------------------------
DROP TABLE IF EXISTS "public"."uctoo_session";
CREATE TABLE "public"."uctoo_session" (
  "user_id" uuid NOT NULL,
  "valid" bool NOT NULL DEFAULT true,
  "created_at" date NOT NULL DEFAULT CURRENT_DATE,
  "updated_at" date NOT NULL DEFAULT CURRENT_DATE,
  "user_agent" varchar COLLATE "pg_catalog"."default",
  "ip" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "auth_provider" int4 NOT NULL DEFAULT 0,
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "deleted_at" timestamptz(6),
  "creator" uuid
)
;
COMMENT ON COLUMN "public"."uctoo_session"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."uctoo_session"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."uctoo_session"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."uctoo_session"."creator" IS '创建人';

-- ----------------------------
-- Table structure for uctoo_user
-- ----------------------------
DROP TABLE IF EXISTS "public"."uctoo_user";
CREATE TABLE "public"."uctoo_user" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "username" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "email" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "password" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "avatar" varchar COLLATE "pg_catalog"."default",
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "last_login" date NOT NULL DEFAULT CURRENT_DATE,
  "auth_provider" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "last_login_ip" varchar COLLATE "pg_catalog"."default",
  "last_login_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "remember_token" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "access_token" varchar COLLATE "pg_catalog"."default",
  "refresh_token" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."uctoo_user"."name" IS '姓名';
COMMENT ON COLUMN "public"."uctoo_user"."username" IS '登录帐号';
COMMENT ON COLUMN "public"."uctoo_user"."email" IS '登录email';
COMMENT ON COLUMN "public"."uctoo_user"."password" IS '密码';
COMMENT ON COLUMN "public"."uctoo_user"."avatar" IS '头像';
COMMENT ON COLUMN "public"."uctoo_user"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."uctoo_user"."last_login" IS '最近一次登录时间';
COMMENT ON COLUMN "public"."uctoo_user"."auth_provider" IS '认证提供商';
COMMENT ON COLUMN "public"."uctoo_user"."creator" IS '创建人';
COMMENT ON COLUMN "public"."uctoo_user"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."uctoo_user"."last_login_ip" IS '最近一次登录ip';
COMMENT ON COLUMN "public"."uctoo_user"."last_login_time" IS '最近一次登录时间';
COMMENT ON COLUMN "public"."uctoo_user"."remember_token" IS '是否记录token。用于再次自动登录';
COMMENT ON COLUMN "public"."uctoo_user"."updated_at" IS '更新时间';
COMMENT ON TABLE "public"."uctoo_user" IS '用户表。相当于account。RBAC中的用户';

-- ----------------------------
-- Table structure for unipay_applets
-- ----------------------------
DROP TABLE IF EXISTS "public"."unipay_applets";
CREATE TABLE "public"."unipay_applets" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "operator" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."unipay_applets"."name" IS '应用名称';
COMMENT ON COLUMN "public"."unipay_applets"."operator" IS '运营商';
COMMENT ON COLUMN "public"."unipay_applets"."appid" IS 'appid';
COMMENT ON COLUMN "public"."unipay_applets"."code" IS '应用CODE';
COMMENT ON COLUMN "public"."unipay_applets"."creator" IS '创建人';
COMMENT ON COLUMN "public"."unipay_applets"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."unipay_applets"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."unipay_applets"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."unipay_applets" IS '统一支付应用';

-- ----------------------------
-- Table structure for unipay_config
-- ----------------------------
DROP TABLE IF EXISTS "public"."unipay_config";
CREATE TABLE "public"."unipay_config" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default",
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "operator" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "key" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."unipay_config"."name" IS '运营商名称';
COMMENT ON COLUMN "public"."unipay_config"."key" IS 'key';
COMMENT ON COLUMN "public"."unipay_config"."value" IS 'value';
COMMENT ON COLUMN "public"."unipay_config"."creator" IS '创建人';
COMMENT ON COLUMN "public"."unipay_config"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."unipay_config"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."unipay_config"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."unipay_config" IS '统一支付配置';

-- ----------------------------
-- Table structure for user_group
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_group";
CREATE TABLE "public"."user_group" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "group_name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "parent_id" varchar COLLATE "pg_catalog"."default",
  "code" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "intro" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_group"."group_name" IS '组名';
COMMENT ON COLUMN "public"."user_group"."parent_id" IS '父级id';
COMMENT ON COLUMN "public"."user_group"."code" IS '组标识';
COMMENT ON COLUMN "public"."user_group"."intro" IS '组介绍';
COMMENT ON COLUMN "public"."user_group"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_group"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_group"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_group"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_group" IS '用户组';

-- ----------------------------
-- Table structure for user_has_account
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_has_account";
CREATE TABLE "public"."user_has_account" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "account_type" varchar COLLATE "pg_catalog"."default",
  "account_id" uuid NOT NULL,
  "status" int4 NOT NULL DEFAULT 1,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_has_account"."id" IS 'id';
COMMENT ON COLUMN "public"."user_has_account"."user_id" IS '关联uctoo_user.id';
COMMENT ON COLUMN "public"."user_has_account"."account_type" IS '帐号类型';
COMMENT ON COLUMN "public"."user_has_account"."account_id" IS '帐号id';
COMMENT ON COLUMN "public"."user_has_account"."status" IS '状态';
COMMENT ON COLUMN "public"."user_has_account"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_has_account"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_has_account"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_has_account"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_has_account" IS '用户关联账号';

-- ----------------------------
-- Table structure for user_has_group
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_has_group";
CREATE TABLE "public"."user_has_group" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "groupable_type" varchar COLLATE "pg_catalog"."default",
  "group_id" uuid NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "groupable_id" uuid NOT NULL
)
;
COMMENT ON COLUMN "public"."user_has_group"."groupable_type" IS '可分组数据类型。与表名一致';
COMMENT ON COLUMN "public"."user_has_group"."group_id" IS '组id';
COMMENT ON COLUMN "public"."user_has_group"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_has_group"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_has_group"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_has_group"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."user_has_group"."groupable_id" IS '可分组数据id。';
COMMENT ON TABLE "public"."user_has_group" IS '用户与组关联';

-- ----------------------------
-- Table structure for user_has_jobs
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_has_jobs";
CREATE TABLE "public"."user_has_jobs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "job_id" uuid NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_has_jobs"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_has_jobs"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_has_jobs"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_has_jobs"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_has_jobs" IS '用户与职位关联';

-- ----------------------------
-- Table structure for user_has_roles
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_has_roles";
CREATE TABLE "public"."user_has_roles" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "role_id" uuid NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_has_roles"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_has_roles"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_has_roles"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_has_roles"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_has_roles" IS '用户与角色关联';

-- ----------------------------
-- Table structure for user_messages
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_messages";
CREATE TABLE "public"."user_messages" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "ai_task_id" uuid NOT NULL,
  "from_uid" uuid NOT NULL,
  "from_model" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "from_ai_user_id" uuid,
  "to_user_id" uuid NOT NULL,
  "to_model" uuid NOT NULL,
  "to_ai_user_id" uuid,
  "msg_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "msg_content" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "ext" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_messages"."ai_task_id" IS 'AI系统任务id';
COMMENT ON COLUMN "public"."user_messages"."from_uid" IS '发消息用户id';
COMMENT ON COLUMN "public"."user_messages"."from_model" IS '发消息用户表名';
COMMENT ON COLUMN "public"."user_messages"."from_ai_user_id" IS '发消息AI系统用户id';
COMMENT ON COLUMN "public"."user_messages"."to_user_id" IS '收消息用户id';
COMMENT ON COLUMN "public"."user_messages"."to_model" IS '收消息用户表名';
COMMENT ON COLUMN "public"."user_messages"."msg_type" IS '消息类型';
COMMENT ON COLUMN "public"."user_messages"."msg_content" IS '消息内容';
COMMENT ON COLUMN "public"."user_messages"."ext" IS '扩展信息';
COMMENT ON COLUMN "public"."user_messages"."status" IS '消息状态';
COMMENT ON COLUMN "public"."user_messages"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_messages"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_messages"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_messages"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_messages" IS '用户消息';

-- ----------------------------
-- Table structure for user_role
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_role";
CREATE TABLE "public"."user_role" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "role_id" uuid NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "deleted_at" timestamptz(6),
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;
COMMENT ON COLUMN "public"."user_role"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_role"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_role"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."user_role"."updated_at" IS '更新时间';
COMMENT ON TABLE "public"."user_role" IS '用户与角色关联';

-- ----------------------------
-- Table structure for user_score
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_score";
CREATE TABLE "public"."user_score" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "appid" varchar COLLATE "pg_catalog"."default",
  "from_umodel" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "total_score" int4 NOT NULL DEFAULT 0,
  "team_score" int4 NOT NULL DEFAULT 0,
  "volunteer_score" int4 NOT NULL DEFAULT 0,
  "event_score" int4 NOT NULL DEFAULT 0,
  "ext_score" varchar COLLATE "pg_catalog"."default",
  "medals" varchar COLLATE "pg_catalog"."default",
  "total_times" int4 DEFAULT 0,
  "total_medals" int4 DEFAULT 0,
  "annual_times" int4 DEFAULT 0,
  "annual_medals" int4 DEFAULT 0,
  "monthly_times" int4 DEFAULT 0,
  "monthly_medals" int4 DEFAULT 0,
  "ext_info" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_score"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."user_score"."appid" IS 'appid';
COMMENT ON COLUMN "public"."user_score"."from_umodel" IS '用户表';
COMMENT ON COLUMN "public"."user_score"."total_score" IS '总分';
COMMENT ON COLUMN "public"."user_score"."team_score" IS '团队积分';
COMMENT ON COLUMN "public"."user_score"."volunteer_score" IS '志愿者积分';
COMMENT ON COLUMN "public"."user_score"."event_score" IS '活动积分';
COMMENT ON COLUMN "public"."user_score"."ext_score" IS '更多积分';
COMMENT ON COLUMN "public"."user_score"."medals" IS '奖牌';
COMMENT ON COLUMN "public"."user_score"."total_times" IS '总次数';
COMMENT ON COLUMN "public"."user_score"."total_medals" IS '总徽章数';
COMMENT ON COLUMN "public"."user_score"."annual_times" IS '年次数';
COMMENT ON COLUMN "public"."user_score"."annual_medals" IS '年徽章数';
COMMENT ON COLUMN "public"."user_score"."monthly_times" IS '月次数';
COMMENT ON COLUMN "public"."user_score"."monthly_medals" IS '月徽章数';
COMMENT ON COLUMN "public"."user_score"."ext_info" IS '更多信息';
COMMENT ON COLUMN "public"."user_score"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_score"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_score"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_score"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_score" IS '用户积分';

-- ----------------------------
-- Table structure for user_sign
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_sign";
CREATE TABLE "public"."user_sign" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "appid" varchar COLLATE "pg_catalog"."default",
  "from_umodel" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "to_id" varchar COLLATE "pg_catalog"."default",
  "to_model" varchar COLLATE "pg_catalog"."default",
  "sign_at" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "score" int4 NOT NULL DEFAULT 0,
  "is_replenish" int4 DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_sign"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."user_sign"."appid" IS 'appid';
COMMENT ON COLUMN "public"."user_sign"."from_umodel" IS '签到用户表';
COMMENT ON COLUMN "public"."user_sign"."to_id" IS '打卡数据id';
COMMENT ON COLUMN "public"."user_sign"."to_model" IS '打卡数据表';
COMMENT ON COLUMN "public"."user_sign"."sign_at" IS '签到日期';
COMMENT ON COLUMN "public"."user_sign"."score" IS '所得积分';
COMMENT ON COLUMN "public"."user_sign"."is_replenish" IS '是否补签。0=正常,1=补签';
COMMENT ON COLUMN "public"."user_sign"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_sign"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_sign"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_sign"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_sign" IS '打卡';

-- ----------------------------
-- Table structure for user_view
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_view";
CREATE TABLE "public"."user_view" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "model_id" uuid NOT NULL,
  "from_model" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_view"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."user_view"."model_id" IS '被访问数据id';
COMMENT ON COLUMN "public"."user_view"."from_model" IS '被访问数据表';
COMMENT ON COLUMN "public"."user_view"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_view"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_view"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_view"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_view" IS '用户浏览商品记录';

-- ----------------------------
-- Table structure for user_wallet_apply
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_wallet_apply";
CREATE TABLE "public"."user_wallet_apply" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "money" float8 DEFAULT 0,
  "charge_money" float8 DEFAULT 0,
  "service_fee" float8 DEFAULT 0,
  "get_type" varchar COLLATE "pg_catalog"."default",
  "bank_info" varchar COLLATE "pg_catalog"."default",
  "card_no" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "realname" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "status_msg" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_wallet_apply"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."user_wallet_apply"."money" IS '提现金额';
COMMENT ON COLUMN "public"."user_wallet_apply"."charge_money" IS '手续费';
COMMENT ON COLUMN "public"."user_wallet_apply"."service_fee" IS '手续费率';
COMMENT ON COLUMN "public"."user_wallet_apply"."get_type" IS '收款类型:bank=银行卡';
COMMENT ON COLUMN "public"."user_wallet_apply"."bank_info" IS '打款信息';
COMMENT ON COLUMN "public"."user_wallet_apply"."card_no" IS '银行卡';
COMMENT ON COLUMN "public"."user_wallet_apply"."realname" IS '真实姓名';
COMMENT ON COLUMN "public"."user_wallet_apply"."status" IS '提现状态。0=申请中,1=已打款,-1=已拒绝';
COMMENT ON COLUMN "public"."user_wallet_apply"."status_msg" IS '提现信息';
COMMENT ON COLUMN "public"."user_wallet_apply"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_wallet_apply"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_wallet_apply"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_wallet_apply"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_wallet_apply" IS '用户提现';

-- ----------------------------
-- Table structure for user_wallet_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."user_wallet_log";
CREATE TABLE "public"."user_wallet_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "wallet" float8 DEFAULT 0,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "wallet_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "item_id" uuid,
  "ext_info" varchar COLLATE "pg_catalog"."default",
  "oper_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "oper_id" uuid,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."user_wallet_log"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."user_wallet_log"."wallet" IS '变动金额';
COMMENT ON COLUMN "public"."user_wallet_log"."type" IS '变动类型';
COMMENT ON COLUMN "public"."user_wallet_log"."wallet_type" IS '日志类型。money=余额,score=积分';
COMMENT ON COLUMN "public"."user_wallet_log"."item_id" IS '项目id';
COMMENT ON COLUMN "public"."user_wallet_log"."ext_info" IS '附加字段';
COMMENT ON COLUMN "public"."user_wallet_log"."oper_type" IS '操作人类型。user,store,admin,system';
COMMENT ON COLUMN "public"."user_wallet_log"."oper_id" IS '操作人';
COMMENT ON COLUMN "public"."user_wallet_log"."creator" IS '创建人';
COMMENT ON COLUMN "public"."user_wallet_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."user_wallet_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."user_wallet_log"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."user_wallet_log" IS '用户提现记录';

-- ----------------------------
-- Table structure for vmc
-- ----------------------------
DROP TABLE IF EXISTS "public"."vmc";
CREATE TABLE "public"."vmc" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "vmc_no" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "replenishment_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "client_status" int4 NOT NULL DEFAULT 0,
  "coins_status" int4 DEFAULT 0,
  "note_status" int4 DEFAULT 0,
  "print_status" int4 DEFAULT 0,
  "pos_status" int4 DEFAULT 0,
  "client_desc" varchar COLLATE "pg_catalog"."default",
  "client_version" varchar COLLATE "pg_catalog"."default",
  "cab_list" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "last_poll_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "update_version" varchar COLLATE "pg_catalog"."default",
  "cover_image" varchar COLLATE "pg_catalog"."default",
  "image" varchar COLLATE "pg_catalog"."default",
  "address" varchar COLLATE "pg_catalog"."default",
  "temple_id" varchar COLLATE "pg_catalog"."default",
  "name" varchar COLLATE "pg_catalog"."default",
  "type" varchar COLLATE "pg_catalog"."default",
  "capacity" varchar COLLATE "pg_catalog"."default",
  "firmware" varchar COLLATE "pg_catalog"."default",
  "scene_str" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."vmc"."vmc_no" IS '设备编号、不能为空';
COMMENT ON COLUMN "public"."vmc"."replenishment_time" IS '客户端上次补货时间';
COMMENT ON COLUMN "public"."vmc"."client_status" IS '整机状态。 (0-正常 1-禁用 2-异常/暂停服务)';
COMMENT ON COLUMN "public"."vmc"."coins_status" IS '硬币器状态。 (0-正常 1-禁用 2-故障)';
COMMENT ON COLUMN "public"."vmc"."note_status" IS '纸币器状态。 (0-正常 1-禁用 2-故障)';
COMMENT ON COLUMN "public"."vmc"."print_status" IS '打印机状态。(0-正常 1-纸已用完、2-纸快用完、4-切纸出错、8-打印机头过热、16-打印机盖开启)';
COMMENT ON COLUMN "public"."vmc"."pos_status" IS 'POS机状态。 0-正常、1-禁用、2-故障';
COMMENT ON COLUMN "public"."vmc"."client_desc" IS '客户端版本描述';
COMMENT ON COLUMN "public"."vmc"."client_version" IS '客户端版本号';
COMMENT ON COLUMN "public"."vmc"."cab_list" IS '货柜状态。如果不支持则不上传该字段';
COMMENT ON COLUMN "public"."vmc"."creator" IS '创建人';
COMMENT ON COLUMN "public"."vmc"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."vmc"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."vmc"."deleted_at" IS '删除时间';
COMMENT ON COLUMN "public"."vmc"."last_poll_time" IS '最后心跳时间';
COMMENT ON COLUMN "public"."vmc"."update_version" IS '升级版本号';
COMMENT ON COLUMN "public"."vmc"."cover_image" IS '屏幕显示的素材url地址';
COMMENT ON COLUMN "public"."vmc"."firmware" IS '下载升级的固件url地址';
COMMENT ON TABLE "public"."vmc" IS '自助售货机。无状态变化时 3-20分钟间隔上报，有状态变化时 立即上报。
';

-- ----------------------------
-- Table structure for vue_editor_items_config
-- ----------------------------
DROP TABLE IF EXISTS "public"."vue_editor_items_config";
CREATE TABLE "public"."vue_editor_items_config" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "type" varchar COLLATE "pg_catalog"."default",
  "category" varchar COLLATE "pg_catalog"."default",
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "value" varchar COLLATE "pg_catalog"."default",
  "page_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "schema" varchar COLLATE "pg_catalog"."default",
  "ui_schema" varchar COLLATE "pg_catalog"."default",
  "form_data" varchar COLLATE "pg_catalog"."default",
  "error_schema" varchar COLLATE "pg_catalog"."default",
  "form_footer" varchar COLLATE "pg_catalog"."default",
  "form_props" uuid,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."vue_editor_items_config"."type" IS '类型';
COMMENT ON COLUMN "public"."vue_editor_items_config"."category" IS '分类';
COMMENT ON COLUMN "public"."vue_editor_items_config"."name" IS '组件名称';
COMMENT ON COLUMN "public"."vue_editor_items_config"."value" IS '组件配置json';
COMMENT ON COLUMN "public"."vue_editor_items_config"."page_id" IS '归属页面ID';
COMMENT ON COLUMN "public"."vue_editor_items_config"."schema" IS 'schema';
COMMENT ON COLUMN "public"."vue_editor_items_config"."ui_schema" IS 'uiSchema';
COMMENT ON COLUMN "public"."vue_editor_items_config"."form_data" IS 'formData';
COMMENT ON COLUMN "public"."vue_editor_items_config"."error_schema" IS 'errorSchema';
COMMENT ON COLUMN "public"."vue_editor_items_config"."form_footer" IS 'formFooter';
COMMENT ON COLUMN "public"."vue_editor_items_config"."form_props" IS 'formProps';
COMMENT ON COLUMN "public"."vue_editor_items_config"."creator" IS '创建人';
COMMENT ON COLUMN "public"."vue_editor_items_config"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."vue_editor_items_config"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."vue_editor_items_config"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."vue_editor_items_config" IS 'vue编辑器控件配置';

-- ----------------------------
-- Table structure for vue_editor_pages
-- ----------------------------
DROP TABLE IF EXISTS "public"."vue_editor_pages";
CREATE TABLE "public"."vue_editor_pages" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "image" varchar COLLATE "pg_catalog"."default",
  "memo" varchar COLLATE "pg_catalog"."default",
  "platform" varchar COLLATE "pg_catalog"."default",
  "page_title" varchar COLLATE "pg_catalog"."default",
  "page_path" varchar COLLATE "pg_catalog"."default",
  "user_id" uuid,
  "edit_status" int4 NOT NULL DEFAULT 0,
  "tags" varchar COLLATE "pg_catalog"."default",
  "description" varchar COLLATE "pg_catalog"."default",
  "page_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."vue_editor_pages"."name" IS '页面名称';
COMMENT ON COLUMN "public"."vue_editor_pages"."type" IS '页面类型';
COMMENT ON COLUMN "public"."vue_editor_pages"."image" IS '页面预览图';
COMMENT ON COLUMN "public"."vue_editor_pages"."memo" IS '备注';
COMMENT ON COLUMN "public"."vue_editor_pages"."platform" IS '适用平台';
COMMENT ON COLUMN "public"."vue_editor_pages"."page_title" IS '页面标题';
COMMENT ON COLUMN "public"."vue_editor_pages"."page_path" IS '页面路径';
COMMENT ON COLUMN "public"."vue_editor_pages"."user_id" IS '用户id';
COMMENT ON COLUMN "public"."vue_editor_pages"."edit_status" IS '编辑状态';
COMMENT ON COLUMN "public"."vue_editor_pages"."tags" IS '分类标签';
COMMENT ON COLUMN "public"."vue_editor_pages"."description" IS '页面说明';
COMMENT ON COLUMN "public"."vue_editor_pages"."page_id" IS '页面id。使用nanoid';
COMMENT ON COLUMN "public"."vue_editor_pages"."status" IS '状态';
COMMENT ON COLUMN "public"."vue_editor_pages"."creator" IS '创建人';
COMMENT ON COLUMN "public"."vue_editor_pages"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."vue_editor_pages"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."vue_editor_pages"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."vue_editor_pages" IS 'vue编辑器页面';

-- ----------------------------
-- Table structure for wechat_cloud
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_cloud";
CREATE TABLE "public"."wechat_cloud" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "env" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "codesecret" varchar COLLATE "pg_catalog"."default",
  "info_list" varchar COLLATE "pg_catalog"."default",
  "config" varchar COLLATE "pg_catalog"."default",
  "functions" varchar COLLATE "pg_catalog"."default",
  "collections" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechat_cloud"."appid" IS 'appid';
COMMENT ON COLUMN "public"."wechat_cloud"."env" IS '云环境id';
COMMENT ON COLUMN "public"."wechat_cloud"."codesecret" IS '代码秘钥';
COMMENT ON COLUMN "public"."wechat_cloud"."info_list" IS '环境信息';
COMMENT ON COLUMN "public"."wechat_cloud"."config" IS '小程序配置json';
COMMENT ON COLUMN "public"."wechat_cloud"."functions" IS '云函数列表';
COMMENT ON COLUMN "public"."wechat_cloud"."collections" IS '集合信息';
COMMENT ON COLUMN "public"."wechat_cloud"."status" IS '状态。-1=HALTED,0=UNAVAILABLE,1=NORMAL';
COMMENT ON COLUMN "public"."wechat_cloud"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_cloud"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_cloud"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_cloud"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_cloud" IS '微信云';

-- ----------------------------
-- Table structure for wechat_graphic
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_graphic";
CREATE TABLE "public"."wechat_graphic" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "author" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "cover" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "content" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "parent_id" uuid
)
;
COMMENT ON COLUMN "public"."wechat_graphic"."title" IS '标题';
COMMENT ON COLUMN "public"."wechat_graphic"."author" IS '作者';
COMMENT ON COLUMN "public"."wechat_graphic"."cover" IS '封面';
COMMENT ON COLUMN "public"."wechat_graphic"."content" IS '内容';
COMMENT ON COLUMN "public"."wechat_graphic"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_graphic"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_graphic"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_graphic"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_graphic" IS '微信图片';

-- ----------------------------
-- Table structure for wechat_material
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_material";
CREATE TABLE "public"."wechat_material" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "tag_id" varchar COLLATE "pg_catalog"."default",
  "fans_amount" int4 DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechat_material"."name" IS '标签名称';
COMMENT ON COLUMN "public"."wechat_material"."tag_id" IS '微信 tag id';
COMMENT ON COLUMN "public"."wechat_material"."fans_amount" IS '粉丝数量';
COMMENT ON COLUMN "public"."wechat_material"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_material"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_material"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_material"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_material" IS '微信素材';

-- ----------------------------
-- Table structure for wechat_menus
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_menus";
CREATE TABLE "public"."wechat_menus" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "key" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "url" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "pagepath" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "media_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "parent_id" uuid
)
;
COMMENT ON COLUMN "public"."wechat_menus"."name" IS '菜单名称';
COMMENT ON COLUMN "public"."wechat_menus"."type" IS '类型';
COMMENT ON COLUMN "public"."wechat_menus"."key" IS 'key';
COMMENT ON COLUMN "public"."wechat_menus"."url" IS 'view 类型  url 链接';
COMMENT ON COLUMN "public"."wechat_menus"."appid" IS '小程序appid';
COMMENT ON COLUMN "public"."wechat_menus"."pagepath" IS '小程序页面';
COMMENT ON COLUMN "public"."wechat_menus"."media_id" IS '调用新增永久素材接口返回的合法media_id';
COMMENT ON COLUMN "public"."wechat_menus"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_menus"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_menus"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_menus"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_menus" IS '微信公众号菜单';

-- ----------------------------
-- Table structure for wechat_miniapp_version
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_miniapp_version";
CREATE TABLE "public"."wechat_miniapp_version" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "product_id" uuid,
  "template_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "ext_json" varchar COLLATE "pg_catalog"."default",
  "user_version" varchar COLLATE "pg_catalog"."default",
  "user_desc" varchar COLLATE "pg_catalog"."default",
  "audit_status" int4 NOT NULL DEFAULT 0,
  "category_list" varchar COLLATE "pg_catalog"."default",
  "page_list" varchar COLLATE "pg_catalog"."default",
  "item_list" varchar COLLATE "pg_catalog"."default",
  "audit_id" varchar COLLATE "pg_catalog"."default",
  "reason" varchar COLLATE "pg_catalog"."default",
  "succ_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "fail_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechat_miniapp_version"."product_id" IS '商品id。即小程序模板对应第三方appstore的商品id';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."template_id" IS '第三方平台代码库中的代码模版ID';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."ext_json" IS '第三方模板自定义的配置';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."user_version" IS '代码版本号。开发者可自定义';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."user_desc" IS '代码描述。开发者可自定义';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."audit_status" IS '审核状态。-1=未提交审核,0=审核成功,1=审核失败,2=审核中';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."category_list" IS '可填选的类目列表';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."page_list" IS '页面配置列表';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."item_list" IS '提交审核项的一个列表（至少填写1项，至多填写5项）';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."audit_id" IS '提交审核时获得的审核id';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."reason" IS '审核不通过原因';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."succ_time" IS '审核成功时间';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."fail_time" IS '审核失败时间';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."appid" IS 'appid';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."status" IS '代码状态:-1=已下线,0=未上传,1=已上传,2=已发布';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_miniapp_version"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_miniapp_version" IS '小程序版本';

-- ----------------------------
-- Table structure for wechat_reply
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_reply";
CREATE TABLE "public"."wechat_reply" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "keyword" varchar COLLATE "pg_catalog"."default",
  "media_id" varchar COLLATE "pg_catalog"."default",
  "media_url" varchar COLLATE "pg_catalog"."default",
  "image_url" varchar COLLATE "pg_catalog"."default",
  "title" varchar COLLATE "pg_catalog"."default",
  "content" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" int4 NOT NULL DEFAULT 0,
  "rule_type" int4 NOT NULL DEFAULT 0,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "appid" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."wechat_reply"."keyword" IS '关键字';
COMMENT ON COLUMN "public"."wechat_reply"."media_id" IS '微信资源ID';
COMMENT ON COLUMN "public"."wechat_reply"."media_url" IS '本地资源 URL';
COMMENT ON COLUMN "public"."wechat_reply"."image_url" IS '本地图片 URL';
COMMENT ON COLUMN "public"."wechat_reply"."title" IS '标题';
COMMENT ON COLUMN "public"."wechat_reply"."content" IS '内容';
COMMENT ON COLUMN "public"."wechat_reply"."type" IS '类型。1文字 2图文 3图片 4音乐 5视频 6语音 7转客服';
COMMENT ON COLUMN "public"."wechat_reply"."rule_type" IS '类型。1 关键字 2 关注 3 默认';
COMMENT ON COLUMN "public"."wechat_reply"."status" IS '1 正常 2 禁用';
COMMENT ON COLUMN "public"."wechat_reply"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_reply"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_reply"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_reply"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_reply" IS '微信公众号消息';

-- ----------------------------
-- Table structure for wechat_tags
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_tags";
CREATE TABLE "public"."wechat_tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "tag_id" int4 NOT NULL DEFAULT 0,
  "name" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "fans_amount" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechat_tags"."tag_id" IS '微信 tag_Id';
COMMENT ON COLUMN "public"."wechat_tags"."name" IS '标签名称';
COMMENT ON COLUMN "public"."wechat_tags"."fans_amount" IS '粉丝数量';
COMMENT ON COLUMN "public"."wechat_tags"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_tags"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_tags"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_tags"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_tags" IS '微信标签';

-- ----------------------------
-- Table structure for wechat_user_has_tags
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechat_user_has_tags";
CREATE TABLE "public"."wechat_user_has_tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "tag_id" int4 NOT NULL DEFAULT 0,
  "user_id" uuid NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechat_user_has_tags"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechat_user_has_tags"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechat_user_has_tags"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechat_user_has_tags"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechat_user_has_tags" IS '微信用户标签';

-- ----------------------------
-- Table structure for wechatopen
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatopen";
CREATE TABLE "public"."wechatopen" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "appsecret" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "encoding_aes_key" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "component_verify_ticket" varchar COLLATE "pg_catalog"."default",
  "component_access_token" varchar COLLATE "pg_catalog"."default",
  "token_overtime" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "pre_auth_code" varchar COLLATE "pg_catalog"."default",
  "pre_code_overtime" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "token" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechatopen"."appid" IS 'appid';
COMMENT ON COLUMN "public"."wechatopen"."appsecret" IS 'appsecret';
COMMENT ON COLUMN "public"."wechatopen"."encoding_aes_key" IS 'encodingAesKey';
COMMENT ON COLUMN "public"."wechatopen"."component_verify_ticket" IS 'componentVerifyTicket';
COMMENT ON COLUMN "public"."wechatopen"."component_access_token" IS 'componentAccessToken';
COMMENT ON COLUMN "public"."wechatopen"."token_overtime" IS 'token过期时间';
COMMENT ON COLUMN "public"."wechatopen"."pre_auth_code" IS '预授权码';
COMMENT ON COLUMN "public"."wechatopen"."pre_code_overtime" IS '预授权过期时间';
COMMENT ON COLUMN "public"."wechatopen"."token" IS 'token';
COMMENT ON COLUMN "public"."wechatopen"."status" IS '状态';
COMMENT ON COLUMN "public"."wechatopen"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatopen"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatopen"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatopen"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatopen" IS '微信第三方平台信息。详情参考 https://open.weixin.qq.com/';

-- ----------------------------
-- Table structure for wechatopen_applet
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatopen_applet";
CREATE TABLE "public"."wechatopen_applet" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar COLLATE "pg_catalog"."default",
  "typedata" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default",
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "appsecret" varchar COLLATE "pg_catalog"."default",
  "aeskey" varchar COLLATE "pg_catalog"."default",
  "mchid" varchar COLLATE "pg_catalog"."default",
  "mchkey" varchar COLLATE "pg_catalog"."default",
  "mch_api_cert" varchar COLLATE "pg_catalog"."default",
  "mch_api_key" varchar COLLATE "pg_catalog"."default",
  "notify_url" varchar COLLATE "pg_catalog"."default",
  "principal" varchar COLLATE "pg_catalog"."default",
  "original" varchar COLLATE "pg_catalog"."default",
  "wechat" varchar COLLATE "pg_catalog"."default",
  "headface_image" varchar COLLATE "pg_catalog"."default",
  "qrcode_image" varchar COLLATE "pg_catalog"."default",
  "signature" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "weigh" int4 NOT NULL DEFAULT 0,
  "service_type_info" varchar COLLATE "pg_catalog"."default",
  "verify_type_info" varchar COLLATE "pg_catalog"."default",
  "business_info" varchar COLLATE "pg_catalog"."default",
  "authorizer_access_token" varchar COLLATE "pg_catalog"."default",
  "access_token_overtime" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "authorizer_refresh_token" varchar COLLATE "pg_catalog"."default",
  "miniprograminfo" varchar COLLATE "pg_catalog"."default",
  "ticket" varchar COLLATE "pg_catalog"."default",
  "ticket_overtime" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "func_info" varchar COLLATE "pg_catalog"."default",
  "basic_config" varchar COLLATE "pg_catalog"."default",
  "channels_info" int4 DEFAULT 0,
  "register_type" int4 DEFAULT 0,
  "redirect_url" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."wechatopen_applet"."name" IS '应用名称';
COMMENT ON COLUMN "public"."wechatopen_applet"."typedata" IS '应用类型';
COMMENT ON COLUMN "public"."wechatopen_applet"."token" IS 'token';
COMMENT ON COLUMN "public"."wechatopen_applet"."appid" IS 'appid';
COMMENT ON COLUMN "public"."wechatopen_applet"."appsecret" IS 'appsecret';
COMMENT ON COLUMN "public"."wechatopen_applet"."aeskey" IS 'EncodingAESKey';
COMMENT ON COLUMN "public"."wechatopen_applet"."mchid" IS '微信支付商户号';
COMMENT ON COLUMN "public"."wechatopen_applet"."mchkey" IS '商户支付密钥';
COMMENT ON COLUMN "public"."wechatopen_applet"."mch_api_cert" IS '商户API证书cert';
COMMENT ON COLUMN "public"."wechatopen_applet"."mch_api_key" IS '商户API证书key';
COMMENT ON COLUMN "public"."wechatopen_applet"."notify_url" IS '微信支付异步通知url';
COMMENT ON COLUMN "public"."wechatopen_applet"."principal" IS '主体名称';
COMMENT ON COLUMN "public"."wechatopen_applet"."original" IS '原始ID';
COMMENT ON COLUMN "public"."wechatopen_applet"."wechat" IS '微信号';
COMMENT ON COLUMN "public"."wechatopen_applet"."headface_image" IS '头像';
COMMENT ON COLUMN "public"."wechatopen_applet"."qrcode_image" IS '二维码图片';
COMMENT ON COLUMN "public"."wechatopen_applet"."signature" IS '账号介绍';
COMMENT ON COLUMN "public"."wechatopen_applet"."status" IS '状态';
COMMENT ON COLUMN "public"."wechatopen_applet"."weigh" IS '权重';
COMMENT ON COLUMN "public"."wechatopen_applet"."service_type_info" IS '授权方公众号类型';
COMMENT ON COLUMN "public"."wechatopen_applet"."verify_type_info" IS '授权方认证类型';
COMMENT ON COLUMN "public"."wechatopen_applet"."business_info" IS '用以了解公众号功能的开通状况';
COMMENT ON COLUMN "public"."wechatopen_applet"."authorizer_access_token" IS '第三方平台授权token';
COMMENT ON COLUMN "public"."wechatopen_applet"."access_token_overtime" IS '授权token过期时间';
COMMENT ON COLUMN "public"."wechatopen_applet"."authorizer_refresh_token" IS '授权刷新token';
COMMENT ON COLUMN "public"."wechatopen_applet"."miniprograminfo" IS '小程序信息';
COMMENT ON COLUMN "public"."wechatopen_applet"."ticket" IS 'jsapi ticket';
COMMENT ON COLUMN "public"."wechatopen_applet"."ticket_overtime" IS 'jsapi ticket 过期时间';
COMMENT ON COLUMN "public"."wechatopen_applet"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatopen_applet"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatopen_applet"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatopen_applet"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatopen_applet" IS '微信第三方平台绑定的应用';

-- ----------------------------
-- Table structure for wechatopen_miniapp_domains
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatopen_miniapp_domains";
CREATE TABLE "public"."wechatopen_miniapp_domains" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "requestdomain" varchar COLLATE "pg_catalog"."default",
  "wsrequestdomain" varchar COLLATE "pg_catalog"."default",
  "uploaddomain" varchar COLLATE "pg_catalog"."default",
  "downloaddomain" varchar COLLATE "pg_catalog"."default",
  "udpdomain" varchar COLLATE "pg_catalog"."default",
  "tcpdomain" varchar COLLATE "pg_catalog"."default",
  "effective_domain" varchar COLLATE "pg_catalog"."default",
  "ext_domain" varchar COLLATE "pg_catalog"."default",
  "effective_webviewdomain" varchar COLLATE "pg_catalog"."default",
  "ext_webviewdomain" varchar COLLATE "pg_catalog"."default",
  "file_name" varchar COLLATE "pg_catalog"."default",
  "file_content" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."appid" IS 'appid';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."requestdomain" IS 'requestdomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."wsrequestdomain" IS 'wsrequestdomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."uploaddomain" IS 'uploaddomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."downloaddomain" IS 'downloaddomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."udpdomain" IS 'udpdomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."tcpdomain" IS 'tcpdomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."effective_domain" IS 'effectiveDomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."ext_domain" IS 'extDomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."effective_webviewdomain" IS 'effectiveWebviewdomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."ext_webviewdomain" IS 'extWebviewdomain';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."file_name" IS 'file_name';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."file_content" IS 'file_content';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatopen_miniapp_domains"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatopen_miniapp_domains" IS '小程序域名配置';

-- ----------------------------
-- Table structure for wechatopen_miniapp_users
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatopen_miniapp_users";
CREATE TABLE "public"."wechatopen_miniapp_users" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid,
  "ai_user_id" uuid,
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "openid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "unionid" varchar COLLATE "pg_catalog"."default",
  "nickname" varchar COLLATE "pg_catalog"."default",
  "phone_number" varchar COLLATE "pg_catalog"."default",
  "pure_phone_number" varchar COLLATE "pg_catalog"."default",
  "country_code" varchar COLLATE "pg_catalog"."default",
  "password" varchar COLLATE "pg_catalog"."default",
  "gender" int4 DEFAULT 0,
  "city" varchar COLLATE "pg_catalog"."default",
  "province" varchar COLLATE "pg_catalog"."default",
  "country" varchar COLLATE "pg_catalog"."default",
  "avatar_url" varchar COLLATE "pg_catalog"."default",
  "language" varchar COLLATE "pg_catalog"."default",
  "subscribe" int4 NOT NULL DEFAULT 0,
  "subscribe_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "remark" varchar COLLATE "pg_catalog"."default",
  "tagid_list" varchar COLLATE "pg_catalog"."default",
  "subscribe_scene" varchar COLLATE "pg_catalog"."default",
  "qr_scene" varchar COLLATE "pg_catalog"."default",
  "qr_scene_str" varchar COLLATE "pg_catalog"."default",
  "privilege" varchar COLLATE "pg_catalog"."default",
  "loginip" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default",
  "access_token" varchar COLLATE "pg_catalog"."default",
  "access_token_overtime" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "session_key" varchar COLLATE "pg_catalog"."default",
  "verification" varchar COLLATE "pg_catalog"."default",
  "ai_user_info" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "refresh_token" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."user_id" IS '关联管理后台users表ID';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."ai_user_id" IS 'AI子系统用户ID';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."appid" IS '关联applet表appid';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."openid" IS 'openid';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."unionid" IS '微信第三方平台用户统一标识';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."nickname" IS '用户昵称';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."phone_number" IS '用户绑定的手机号（国外手机号会有区号）';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."pure_phone_number" IS '没有区号的手机号';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."country_code" IS '区号';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."password" IS '登录密码';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."gender" IS '性别。1=男,2=女,0=未知';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."city" IS '城市';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."province" IS '省份';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."country" IS '国家';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."avatar_url" IS '头像';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."language" IS '语言';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."subscribe" IS '是否使用该小程序标识。0=未关注，1=关注';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."subscribe_time" IS '关注时间';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."remark" IS '运营者对粉丝的备注';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."tagid_list" IS '用户被打上的标签ID列表';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."subscribe_scene" IS '用户使用的渠道来源';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."qr_scene" IS '二维码扫码场景（开发者自定义）';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."qr_scene_str" IS '二维码扫码场景描述（开发者自定义）';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."privilege" IS '用户特权信息。json数组';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."loginip" IS 'ip地址';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."token" IS 'token,自定义登录态请求api的标识，前端需缓存''';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."access_token" IS 'access_token';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."access_token_overtime" IS 'access_token过期时间';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."session_key" IS '会话密钥';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."verification" IS '验证';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."ai_user_info" IS 'AI子系统用户信息';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."status" IS '状态';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatopen_miniapp_users"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatopen_miniapp_users" IS '小程序用户';

-- ----------------------------
-- Table structure for wechatopen_template
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatopen_template";
CREATE TABLE "public"."wechatopen_template" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "draft_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "template_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "user_version" varchar COLLATE "pg_catalog"."default",
  "user_desc" varchar COLLATE "pg_catalog"."default",
  "create_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "source_miniprogram_appid" varchar COLLATE "pg_catalog"."default",
  "source_miniprogram" varchar COLLATE "pg_catalog"."default",
  "template_type" int4 NOT NULL DEFAULT 0,
  "category_list" varchar COLLATE "pg_catalog"."default",
  "audit_scene" int4 NOT NULL DEFAULT 0,
  "audit_status" int4 NOT NULL DEFAULT 0,
  "reason" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechatopen_template"."draft_id" IS '草稿id';
COMMENT ON COLUMN "public"."wechatopen_template"."template_id" IS '模板id';
COMMENT ON COLUMN "public"."wechatopen_template"."user_version" IS '版本号';
COMMENT ON COLUMN "public"."wechatopen_template"."user_desc" IS '版本描述开发者自定义字段';
COMMENT ON COLUMN "public"."wechatopen_template"."create_time" IS '开发者上传草稿时间戳';
COMMENT ON COLUMN "public"."wechatopen_template"."source_miniprogram_appid" IS '开发小程序的appid';
COMMENT ON COLUMN "public"."wechatopen_template"."source_miniprogram" IS '开发小程序的名称';
COMMENT ON COLUMN "public"."wechatopen_template"."template_type" IS '0对应普通模板，1对应标准模板';
COMMENT ON COLUMN "public"."wechatopen_template"."category_list" IS '标准模板的类目信息；如果是普通模板则值为空的数组''';
COMMENT ON COLUMN "public"."wechatopen_template"."audit_scene" IS '标准模板的场景标签；普通模板不返回该值''';
COMMENT ON COLUMN "public"."wechatopen_template"."audit_status" IS '标准模板的审核状态；普通模板不返回该值''';
COMMENT ON COLUMN "public"."wechatopen_template"."reason" IS '标准模板的审核驳回的原因，；普通模板不返回该值';
COMMENT ON COLUMN "public"."wechatopen_template"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatopen_template"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatopen_template"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatopen_template"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatopen_template" IS '微信第三方平台小程序模板';

-- ----------------------------
-- Table structure for wechatopen_template_draft
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatopen_template_draft";
CREATE TABLE "public"."wechatopen_template_draft" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "draft_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "user_version" varchar COLLATE "pg_catalog"."default",
  "user_desc" varchar COLLATE "pg_catalog"."default",
  "create_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechatopen_template_draft"."draft_id" IS '草稿id';
COMMENT ON COLUMN "public"."wechatopen_template_draft"."user_version" IS '版本号';
COMMENT ON COLUMN "public"."wechatopen_template_draft"."user_desc" IS '版本描述开发者自定义字段';
COMMENT ON COLUMN "public"."wechatopen_template_draft"."create_time" IS '开发者上传草稿时间戳';
COMMENT ON COLUMN "public"."wechatopen_template_draft"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatopen_template_draft"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatopen_template_draft"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatopen_template_draft"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatopen_template_draft" IS '微信第三方平台小程序草稿箱';

-- ----------------------------
-- Table structure for wechatopen_users
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatopen_users";
CREATE TABLE "public"."wechatopen_users" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid,
  "ai_user_id" uuid,
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "openid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "unionid" varchar COLLATE "pg_catalog"."default",
  "nickname" varchar COLLATE "pg_catalog"."default",
  "phone_number" varchar COLLATE "pg_catalog"."default",
  "pure_phone_number" varchar COLLATE "pg_catalog"."default",
  "country_code" varchar COLLATE "pg_catalog"."default",
  "password" varchar COLLATE "pg_catalog"."default",
  "gender" int4 DEFAULT 0,
  "city" varchar COLLATE "pg_catalog"."default",
  "province" varchar COLLATE "pg_catalog"."default",
  "country" varchar COLLATE "pg_catalog"."default",
  "avatar_url" varchar COLLATE "pg_catalog"."default",
  "language" varchar COLLATE "pg_catalog"."default",
  "subscribe" int4 DEFAULT 0,
  "subscribe_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "remark" varchar COLLATE "pg_catalog"."default",
  "tagid_list" varchar COLLATE "pg_catalog"."default",
  "subscribe_scene" varchar COLLATE "pg_catalog"."default",
  "qr_scene" varchar COLLATE "pg_catalog"."default",
  "qr_scene_str" varchar COLLATE "pg_catalog"."default",
  "privilege" varchar COLLATE "pg_catalog"."default",
  "loginip" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default",
  "access_token" varchar COLLATE "pg_catalog"."default",
  "access_token_overtime" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "session_key" varchar COLLATE "pg_catalog"."default",
  "verification" varchar COLLATE "pg_catalog"."default",
  "ai_user_info" varchar COLLATE "pg_catalog"."default",
  "status" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  "refresh_token" varchar COLLATE "pg_catalog"."default",
  "scope" varchar COLLATE "pg_catalog"."default"
)
;
COMMENT ON COLUMN "public"."wechatopen_users"."user_id" IS '用户ID';
COMMENT ON COLUMN "public"."wechatopen_users"."appid" IS 'appid';
COMMENT ON COLUMN "public"."wechatopen_users"."openid" IS 'openid';
COMMENT ON COLUMN "public"."wechatopen_users"."unionid" IS '用户统一标识';
COMMENT ON COLUMN "public"."wechatopen_users"."nickname" IS '用户昵称';
COMMENT ON COLUMN "public"."wechatopen_users"."phone_number" IS '手机号码';
COMMENT ON COLUMN "public"."wechatopen_users"."country_code" IS '国家';
COMMENT ON COLUMN "public"."wechatopen_users"."password" IS '登录密码';
COMMENT ON COLUMN "public"."wechatopen_users"."gender" IS '性别。1=男性，2=女性';
COMMENT ON COLUMN "public"."wechatopen_users"."city" IS '城市';
COMMENT ON COLUMN "public"."wechatopen_users"."province" IS '省份';
COMMENT ON COLUMN "public"."wechatopen_users"."country" IS '国家';
COMMENT ON COLUMN "public"."wechatopen_users"."avatar_url" IS '用户头像';
COMMENT ON COLUMN "public"."wechatopen_users"."language" IS '用户的语言';
COMMENT ON COLUMN "public"."wechatopen_users"."subscribe" IS '是否订阅该公众号标识。0=未关注，1=关注';
COMMENT ON COLUMN "public"."wechatopen_users"."subscribe_time" IS '用户关注时间。为时间戳';
COMMENT ON COLUMN "public"."wechatopen_users"."remark" IS '公众号运营者对粉丝的备注';
COMMENT ON COLUMN "public"."wechatopen_users"."tagid_list" IS '用户被打上的标签ID列表';
COMMENT ON COLUMN "public"."wechatopen_users"."subscribe_scene" IS '返回用户关注的渠道来源';
COMMENT ON COLUMN "public"."wechatopen_users"."qr_scene" IS '二维码扫码场景（开发者自定义）';
COMMENT ON COLUMN "public"."wechatopen_users"."qr_scene_str" IS '二维码扫码场景描述（开发者自定义）';
COMMENT ON COLUMN "public"."wechatopen_users"."privilege" IS '用户特权信息，json数组';
COMMENT ON COLUMN "public"."wechatopen_users"."loginip" IS 'IP地址';
COMMENT ON COLUMN "public"."wechatopen_users"."token" IS 'token';
COMMENT ON COLUMN "public"."wechatopen_users"."access_token" IS 'access_token';
COMMENT ON COLUMN "public"."wechatopen_users"."access_token_overtime" IS 'access_token_overtime';
COMMENT ON COLUMN "public"."wechatopen_users"."verification" IS '验证';
COMMENT ON COLUMN "public"."wechatopen_users"."status" IS '状态';
COMMENT ON COLUMN "public"."wechatopen_users"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatopen_users"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatopen_users"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatopen_users"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatopen_users" IS '公众号用户';

-- ----------------------------
-- Table structure for wechatpay_transaction
-- ----------------------------
DROP TABLE IF EXISTS "public"."wechatpay_transaction";
CREATE TABLE "public"."wechatpay_transaction" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "notify_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "transaction_id" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "mchid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "appid" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "out_trade_no" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "trade_state" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "trade_state_desc" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "bank_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "trade_type" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "success_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "attach" varchar COLLATE "pg_catalog"."default",
  "payer" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "amount" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "scene_info" varchar COLLATE "pg_catalog"."default",
  "promotion_detail" varchar COLLATE "pg_catalog"."default",
  "is_subscribe" varchar COLLATE "pg_catalog"."default",
  "create_time" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resource_type" varchar COLLATE "pg_catalog"."default",
  "event_type" varchar COLLATE "pg_catalog"."default",
  "resource_algorithm" varchar COLLATE "pg_catalog"."default",
  "resource_ciphertext" varchar COLLATE "pg_catalog"."default",
  "resource_nonce" varchar COLLATE "pg_catalog"."default",
  "resource_original_type" varchar COLLATE "pg_catalog"."default",
  "resource_associated_data" varchar COLLATE "pg_catalog"."default",
  "summary" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wechatpay_transaction"."notify_id" IS '通知ID';
COMMENT ON COLUMN "public"."wechatpay_transaction"."transaction_id" IS '微信支付订单号';
COMMENT ON COLUMN "public"."wechatpay_transaction"."mchid" IS '商户号';
COMMENT ON COLUMN "public"."wechatpay_transaction"."appid" IS 'appid';
COMMENT ON COLUMN "public"."wechatpay_transaction"."out_trade_no" IS '商户支付订单号';
COMMENT ON COLUMN "public"."wechatpay_transaction"."trade_state" IS '交易状态。SUCCESS=支付成功,REFUND=转入退款,NOTPAY=未支付,CLOSED=已关闭,REVOKED=已撤销（付款码支付）,USERPAYING=用户支付中（付款码支付）,PAYERROR=支付失败(其他原因，如银行返回失败) ';
COMMENT ON COLUMN "public"."wechatpay_transaction"."trade_state_desc" IS '交易状态描述';
COMMENT ON COLUMN "public"."wechatpay_transaction"."bank_type" IS '付款银行';
COMMENT ON COLUMN "public"."wechatpay_transaction"."trade_type" IS '交易类型。JSAPI=公众号支付,NATIVE=扫码支付,APP=APP支付,MICROPAY=付款码支付,MWEB=H5支付,FACEPAY=刷脸支付''';
COMMENT ON COLUMN "public"."wechatpay_transaction"."success_time" IS '支付完成时间';
COMMENT ON COLUMN "public"."wechatpay_transaction"."attach" IS '附加数据';
COMMENT ON COLUMN "public"."wechatpay_transaction"."payer" IS '支付者。json包含用户标识	openid';
COMMENT ON COLUMN "public"."wechatpay_transaction"."amount" IS '订单金额信息json';
COMMENT ON COLUMN "public"."wechatpay_transaction"."scene_info" IS '支付场景信息描述json';
COMMENT ON COLUMN "public"."wechatpay_transaction"."promotion_detail" IS '优惠功能';
COMMENT ON COLUMN "public"."wechatpay_transaction"."is_subscribe" IS '是否关注公众号';
COMMENT ON COLUMN "public"."wechatpay_transaction"."create_time" IS '通知创建时间';
COMMENT ON COLUMN "public"."wechatpay_transaction"."resource_type" IS '通知数据类型';
COMMENT ON COLUMN "public"."wechatpay_transaction"."event_type" IS '通知类型';
COMMENT ON COLUMN "public"."wechatpay_transaction"."resource_algorithm" IS '加密算法类型';
COMMENT ON COLUMN "public"."wechatpay_transaction"."resource_ciphertext" IS '数据密文';
COMMENT ON COLUMN "public"."wechatpay_transaction"."resource_nonce" IS '随机串';
COMMENT ON COLUMN "public"."wechatpay_transaction"."resource_original_type" IS '原始类型';
COMMENT ON COLUMN "public"."wechatpay_transaction"."resource_associated_data" IS '附加数据';
COMMENT ON COLUMN "public"."wechatpay_transaction"."summary" IS '回调摘要';
COMMENT ON COLUMN "public"."wechatpay_transaction"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wechatpay_transaction"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wechatpay_transaction"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wechatpay_transaction"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wechatpay_transaction" IS '微信支付流水';

-- ----------------------------
-- Table structure for wxa_updatable_message
-- ----------------------------
DROP TABLE IF EXISTS "public"."wxa_updatable_message";
CREATE TABLE "public"."wxa_updatable_message" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid,
  "openid" varchar COLLATE "pg_catalog"."default",
  "unionid" varchar COLLATE "pg_catalog"."default",
  "activity_id" varchar COLLATE "pg_catalog"."default",
  "expiration_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "valid" int4 DEFAULT 0,
  "iv" varchar COLLATE "pg_catalog"."default",
  "encrypted_data" varchar COLLATE "pg_catalog"."default",
  "share_ticket" varchar COLLATE "pg_catalog"."default",
  "member_count" varchar COLLATE "pg_catalog"."default",
  "room_limit" varchar COLLATE "pg_catalog"."default",
  "path" varchar COLLATE "pg_catalog"."default",
  "version_type" varchar COLLATE "pg_catalog"."default",
  "target_state" int4 DEFAULT 0,
  "template_info" varchar COLLATE "pg_catalog"."default",
  "to_openid" varchar COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."wxa_updatable_message"."user_id" IS '小程序用户表id';
COMMENT ON COLUMN "public"."wxa_updatable_message"."openid" IS 'openid';
COMMENT ON COLUMN "public"."wxa_updatable_message"."unionid" IS 'unionid';
COMMENT ON COLUMN "public"."wxa_updatable_message"."activity_id" IS '动态消息的 ID';
COMMENT ON COLUMN "public"."wxa_updatable_message"."expiration_time" IS 'activity_id 的过期时间戳。默认24小时后过期。';
COMMENT ON COLUMN "public"."wxa_updatable_message"."valid" IS '验证是否通过';
COMMENT ON COLUMN "public"."wxa_updatable_message"."iv" IS '加密算法的初始向量。详细见加密数据解密算法';
COMMENT ON COLUMN "public"."wxa_updatable_message"."encrypted_data" IS '经过加密的activity_id。解密后可得到原始的activity_id';
COMMENT ON COLUMN "public"."wxa_updatable_message"."share_ticket" IS 'shareTicket';
COMMENT ON COLUMN "public"."wxa_updatable_message"."member_count" IS '状态。 0 时有效，文字内容模板中 member_count 的值';
COMMENT ON COLUMN "public"."wxa_updatable_message"."room_limit" IS '状态。 0 时有效，文字内容模板中 room_limit 的值';
COMMENT ON COLUMN "public"."wxa_updatable_message"."path" IS '状态。 1 时有效，点击「进入」启动小程序时使用的路径';
COMMENT ON COLUMN "public"."wxa_updatable_message"."version_type" IS '状态。 1 时有效，点击「进入」启动小程序时使用的路径';
COMMENT ON COLUMN "public"."wxa_updatable_message"."target_state" IS '动态消息修改后的状态。0=未开始，1=已开始';
COMMENT ON COLUMN "public"."wxa_updatable_message"."template_info" IS '动态消息对应的模板信息';
COMMENT ON COLUMN "public"."wxa_updatable_message"."to_openid" IS '接收人openid';
COMMENT ON COLUMN "public"."wxa_updatable_message"."creator" IS '创建人';
COMMENT ON COLUMN "public"."wxa_updatable_message"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."wxa_updatable_message"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."wxa_updatable_message"."deleted_at" IS '删除时间';
COMMENT ON TABLE "public"."wxa_updatable_message" IS '微信消息通知';

-- ----------------------------
-- Primary Key structure for table admin_applet
-- ----------------------------
ALTER TABLE "public"."admin_applet" ADD CONSTRAINT "admin_applet_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table agent_runtime_status
-- ----------------------------
ALTER TABLE "public"."agent_runtime_status" ADD CONSTRAINT "agent_runtime_status_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table agent_skill_configs
-- ----------------------------
CREATE UNIQUE INDEX "agent_skill_configs_skill_id_config_key_key" ON "public"."agent_skill_configs" USING btree (
  "skill_id" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "config_key" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE INDEX "agent_skill_configs_skill_id_idx" ON "public"."agent_skill_configs" USING btree (
  "skill_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table agent_skill_configs
-- ----------------------------
ALTER TABLE "public"."agent_skill_configs" ADD CONSTRAINT "agent_skill_configs_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table agent_skill_executions
-- ----------------------------
CREATE INDEX "agent_skill_executions_creator_idx" ON "public"."agent_skill_executions" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "agent_skill_executions_skill_id_idx" ON "public"."agent_skill_executions" USING btree (
  "skill_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table agent_skill_executions
-- ----------------------------
ALTER TABLE "public"."agent_skill_executions" ADD CONSTRAINT "agent_skill_executions_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table agent_skills
-- ----------------------------
ALTER TABLE "public"."agent_skills" ADD CONSTRAINT "agent_skills_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table ai_client
-- ----------------------------
ALTER TABLE "public"."ai_client" ADD CONSTRAINT "ai_client_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table app_access_token
-- ----------------------------
ALTER TABLE "public"."app_access_token" ADD CONSTRAINT "app_access_token_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table application
-- ----------------------------
ALTER TABLE "public"."application" ADD CONSTRAINT "application_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table attachments
-- ----------------------------
ALTER TABLE "public"."attachments" ADD CONSTRAINT "attachments_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table chat_conversations
-- ----------------------------
CREATE INDEX "chat_conversations_creator_idx" ON "public"."chat_conversations" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "chat_conversations_status_idx" ON "public"."chat_conversations" USING btree (
  "status" "pg_catalog"."int4_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table chat_conversations
-- ----------------------------
ALTER TABLE "public"."chat_conversations" ADD CONSTRAINT "chat_conversations_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table chat_messages
-- ----------------------------
CREATE INDEX "chat_messages_conversation_id_idx" ON "public"."chat_messages" USING btree (
  "conversation_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "chat_messages_created_at_idx" ON "public"."chat_messages" USING btree (
  "created_at" "pg_catalog"."timestamptz_ops" ASC NULLS LAST
);
CREATE INDEX "chat_messages_creator_idx" ON "public"."chat_messages" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table chat_messages
-- ----------------------------
ALTER TABLE "public"."chat_messages" ADD CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_article_relate_tags
-- ----------------------------
ALTER TABLE "public"."cms_article_relate_tags" ADD CONSTRAINT "cms_article_relate_tags_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_articles
-- ----------------------------
ALTER TABLE "public"."cms_articles" ADD CONSTRAINT "cms_articles_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_banners
-- ----------------------------
ALTER TABLE "public"."cms_banners" ADD CONSTRAINT "cms_banners_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_category
-- ----------------------------
ALTER TABLE "public"."cms_category" ADD CONSTRAINT "cms_category_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_comments
-- ----------------------------
ALTER TABLE "public"."cms_comments" ADD CONSTRAINT "cms_comments_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_form_data
-- ----------------------------
ALTER TABLE "public"."cms_form_data" ADD CONSTRAINT "cms_form_data_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_form_fields
-- ----------------------------
ALTER TABLE "public"."cms_form_fields" ADD CONSTRAINT "cms_form_fields_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_forms
-- ----------------------------
ALTER TABLE "public"."cms_forms" ADD CONSTRAINT "cms_forms_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_model_auxiliary_table
-- ----------------------------
ALTER TABLE "public"."cms_model_auxiliary_table" ADD CONSTRAINT "cms_model_auxiliary_table_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_model_fields
-- ----------------------------
ALTER TABLE "public"."cms_model_fields" ADD CONSTRAINT "cms_model_fields_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_models
-- ----------------------------
ALTER TABLE "public"."cms_models" ADD CONSTRAINT "cms_models_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_site_links
-- ----------------------------
ALTER TABLE "public"."cms_site_links" ADD CONSTRAINT "cms_site_links_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table cms_tags
-- ----------------------------
ALTER TABLE "public"."cms_tags" ADD CONSTRAINT "cms_tags_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table codelabs
-- ----------------------------
ALTER TABLE "public"."codelabs" ADD CONSTRAINT "codelabs_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table codelabs_algorithm
-- ----------------------------
ALTER TABLE "public"."codelabs_algorithm" ADD CONSTRAINT "codelabs_algorithm_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table codelabs_templates
-- ----------------------------
ALTER TABLE "public"."codelabs_templates" ADD CONSTRAINT "codelabs_templates_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table company
-- ----------------------------
ALTER TABLE "public"."company" ADD CONSTRAINT "company_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table component_setting
-- ----------------------------
ALTER TABLE "public"."component_setting" ADD CONSTRAINT "component_setting_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table config
-- ----------------------------
ALTER TABLE "public"."config" ADD CONSTRAINT "config_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table crm_business_card
-- ----------------------------
ALTER TABLE "public"."crm_business_card" ADD CONSTRAINT "crm_business_card_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table crm_card_holder
-- ----------------------------
ALTER TABLE "public"."crm_card_holder" ADD CONSTRAINT "crm_card_holder_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table crm_visit_log
-- ----------------------------
ALTER TABLE "public"."crm_visit_log" ADD CONSTRAINT "crm_visit_Log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table crontab
-- ----------------------------
ALTER TABLE "public"."crontab" ADD CONSTRAINT "crontab_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table crontab_log
-- ----------------------------
ALTER TABLE "public"."crontab_log" ADD CONSTRAINT "crontab_log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table customer_level
-- ----------------------------
ALTER TABLE "public"."customer_level" ADD CONSTRAINT "customer_level_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table customer_status
-- ----------------------------
ALTER TABLE "public"."customer_status" ADD CONSTRAINT "customer_status_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table customer_type
-- ----------------------------
ALTER TABLE "public"."customer_type" ADD CONSTRAINT "customer_type_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table data_access_authorization
-- ----------------------------
CREATE INDEX "data_access_authorization_entity_id_entity_type_user_id_idx" ON "public"."data_access_authorization" USING btree (
  "entity_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "entity_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "user_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table data_access_authorization
-- ----------------------------
ALTER TABLE "public"."data_access_authorization" ADD CONSTRAINT "data_access_authorization_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table db_connection
-- ----------------------------
ALTER TABLE "public"."db_connection" ADD CONSTRAINT "db_connection_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table db_info
-- ----------------------------
ALTER TABLE "public"."db_info" ADD CONSTRAINT "db_info_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table departments
-- ----------------------------
ALTER TABLE "public"."departments" ADD CONSTRAINT "departments_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table developer
-- ----------------------------
ALTER TABLE "public"."developer" ADD CONSTRAINT "developer_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table developer_account
-- ----------------------------
ALTER TABLE "public"."developer_account" ADD CONSTRAINT "developer_account_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table element_components
-- ----------------------------
ALTER TABLE "public"."element_components" ADD CONSTRAINT "element_components_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table entity
-- ----------------------------
ALTER TABLE "public"."entity" ADD CONSTRAINT "entity_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table faq
-- ----------------------------
ALTER TABLE "public"."faq" ADD CONSTRAINT "faq_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table feedback
-- ----------------------------
ALTER TABLE "public"."feedback" ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table group_has_permission
-- ----------------------------
ALTER TABLE "public"."group_has_permission" ADD CONSTRAINT "group_has_permission_pkey" PRIMARY KEY ("group_id", "permission_name");

-- ----------------------------
-- Indexes structure for table group_tag
-- ----------------------------
CREATE UNIQUE INDEX "unique_tag_per_group" ON "public"."group_tag" USING btree (
  "group_id" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "tagId" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table group_tag
-- ----------------------------
ALTER TABLE "public"."group_tag" ADD CONSTRAINT "group_tag_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table guest_users
-- ----------------------------
ALTER TABLE "public"."guest_users" ADD CONSTRAINT "guest_users_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table i18
-- ----------------------------
ALTER TABLE "public"."i18" ADD CONSTRAINT "i18_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table jobs
-- ----------------------------
ALTER TABLE "public"."jobs" ADD CONSTRAINT "jobs_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table lang
-- ----------------------------
ALTER TABLE "public"."lang" ADD CONSTRAINT "lang_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table link
-- ----------------------------
CREATE INDEX "fki_links_owner_fkey" ON "public"."link" USING btree (
  "owner" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table link
-- ----------------------------
ALTER TABLE "public"."link" ADD CONSTRAINT "link_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table link_group
-- ----------------------------
CREATE INDEX "lg_owner_fkey" ON "public"."link_group" USING btree (
  "owner" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "unique_groupname_per_owner" ON "public"."link_group" USING btree (
  "owner" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "groupname" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table link_group
-- ----------------------------
ALTER TABLE "public"."link_group" ADD CONSTRAINT "link_group_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table link_tag
-- ----------------------------
CREATE UNIQUE INDEX "unique_tag_per_link" ON "public"."link_tag" USING btree (
  "link_id" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "tag_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table link_tag
-- ----------------------------
ALTER TABLE "public"."link_tag" ADD CONSTRAINT "link_tag_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table login_log
-- ----------------------------
ALTER TABLE "public"."login_log" ADD CONSTRAINT "login_jog_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_activity
-- ----------------------------
ALTER TABLE "public"."minishop_activity" ADD CONSTRAINT "minishop_activity_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_activity_goods_sku_price
-- ----------------------------
ALTER TABLE "public"."minishop_activity_goods_sku_price" ADD CONSTRAINT "minishop_activity_goods_sku_Price_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_activity_groupon
-- ----------------------------
ALTER TABLE "public"."minishop_activity_groupon" ADD CONSTRAINT "MinishopActivityGroupon_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_activity_groupon_log
-- ----------------------------
ALTER TABLE "public"."minishop_activity_groupon_log" ADD CONSTRAINT "MinishopActivityGrouponLog_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_address_info
-- ----------------------------
ALTER TABLE "public"."minishop_address_info" ADD CONSTRAINT "minishop_address_info_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_area
-- ----------------------------
ALTER TABLE "public"."minishop_area" ADD CONSTRAINT "MinishopArea_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_cart
-- ----------------------------
ALTER TABLE "public"."minishop_cart" ADD CONSTRAINT "minishop_cart_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_config
-- ----------------------------
ALTER TABLE "public"."minishop_config" ADD CONSTRAINT "minishop_config_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_coupons
-- ----------------------------
ALTER TABLE "public"."minishop_coupons" ADD CONSTRAINT "minishop_coupons_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_decorate
-- ----------------------------
ALTER TABLE "public"."minishop_decorate" ADD CONSTRAINT "minishop_decorate_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_decorate_content
-- ----------------------------
ALTER TABLE "public"."minishop_decorate_content" ADD CONSTRAINT "minishop_decorate_content_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_dispatch
-- ----------------------------
ALTER TABLE "public"."minishop_dispatch" ADD CONSTRAINT "minishop_dispatch_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_dispatch_autosend
-- ----------------------------
ALTER TABLE "public"."minishop_dispatch_autosend" ADD CONSTRAINT "minishop_dispatch_autosend_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_dispatch_express
-- ----------------------------
ALTER TABLE "public"."minishop_dispatch_express" ADD CONSTRAINT "minishop_dispatch_express_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_dispatch_selfetch
-- ----------------------------
ALTER TABLE "public"."minishop_dispatch_selfetch" ADD CONSTRAINT "minishop_dispatch_selfetch_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_dispatch_store
-- ----------------------------
ALTER TABLE "public"."minishop_dispatch_store" ADD CONSTRAINT "minishop_dispatch_store_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_express
-- ----------------------------
ALTER TABLE "public"."minishop_express" ADD CONSTRAINT "minishop_express_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_failed_job
-- ----------------------------
ALTER TABLE "public"."minishop_failed_job" ADD CONSTRAINT "minishop_failed_job_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_goods_comment
-- ----------------------------
ALTER TABLE "public"."minishop_goods_comment" ADD CONSTRAINT "minishop_goods_comment_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_goods_service
-- ----------------------------
ALTER TABLE "public"."minishop_goods_service" ADD CONSTRAINT "minishop_goods_service_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_link
-- ----------------------------
ALTER TABLE "public"."minishop_link" ADD CONSTRAINT "minishop_link_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order
-- ----------------------------
ALTER TABLE "public"."minishop_order" ADD CONSTRAINT "minishop_order_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_action
-- ----------------------------
ALTER TABLE "public"."minishop_order_action" ADD CONSTRAINT "minishop_order_action_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_aftersale
-- ----------------------------
ALTER TABLE "public"."minishop_order_aftersale" ADD CONSTRAINT "minishop_order_aftersale_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_aftersale_log
-- ----------------------------
ALTER TABLE "public"."minishop_order_aftersale_log" ADD CONSTRAINT "minishop_order_aftersale_log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_detail
-- ----------------------------
ALTER TABLE "public"."minishop_order_detail" ADD CONSTRAINT "minishop_order_detail_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_express
-- ----------------------------
ALTER TABLE "public"."minishop_order_express" ADD CONSTRAINT "minishop_order_express_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_express_log
-- ----------------------------
ALTER TABLE "public"."minishop_order_express_log" ADD CONSTRAINT "minishop_order_express_log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_item
-- ----------------------------
ALTER TABLE "public"."minishop_order_item" ADD CONSTRAINT "minishop_order_item_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_order_status
-- ----------------------------
ALTER TABLE "public"."minishop_order_status" ADD CONSTRAINT "minishop_order_status_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_product_category
-- ----------------------------
ALTER TABLE "public"."minishop_product_category" ADD CONSTRAINT "minishop_product_category_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_refund_log
-- ----------------------------
ALTER TABLE "public"."minishop_refund_log" ADD CONSTRAINT "minishop_refund_log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_share
-- ----------------------------
ALTER TABLE "public"."minishop_share" ADD CONSTRAINT "minishop_share_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_shipping_method
-- ----------------------------
ALTER TABLE "public"."minishop_shipping_method" ADD CONSTRAINT "minishop_shipping_method_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_sku
-- ----------------------------
ALTER TABLE "public"."minishop_sku" ADD CONSTRAINT "minishop_sku_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_sku_attrs
-- ----------------------------
ALTER TABLE "public"."minishop_sku_attrs" ADD CONSTRAINT "minishop_sku_attrs_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_sku_status
-- ----------------------------
ALTER TABLE "public"."minishop_sku_status" ADD CONSTRAINT "minishop_sku_status_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_spu
-- ----------------------------
ALTER TABLE "public"."minishop_spu" ADD CONSTRAINT "minishop_spu_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_spu_edit_status
-- ----------------------------
ALTER TABLE "public"."minishop_spu_edit_status" ADD CONSTRAINT "minishop_spu_edit_status_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_spu_status
-- ----------------------------
ALTER TABLE "public"."minishop_spu_status" ADD CONSTRAINT "minishop_spu_status_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_store
-- ----------------------------
ALTER TABLE "public"."minishop_store" ADD CONSTRAINT "minishop_store_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_store_apply
-- ----------------------------
ALTER TABLE "public"."minishop_store_apply" ADD CONSTRAINT "minishop_store_apply_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_user_address
-- ----------------------------
ALTER TABLE "public"."minishop_user_address" ADD CONSTRAINT "minishop_user_address_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_user_bank
-- ----------------------------
ALTER TABLE "public"."minishop_user_bank" ADD CONSTRAINT "minishop_user_bank_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_user_coupons
-- ----------------------------
ALTER TABLE "public"."minishop_user_coupons" ADD CONSTRAINT "minishop_user_coupons_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_user_favorite
-- ----------------------------
ALTER TABLE "public"."minishop_user_favorite" ADD CONSTRAINT "minishop_user_favorite_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table minishop_user_store
-- ----------------------------
ALTER TABLE "public"."minishop_user_store" ADD CONSTRAINT "minishop_user_store_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table module_config
-- ----------------------------
ALTER TABLE "public"."module_config" ADD CONSTRAINT "module_config_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table operate_log
-- ----------------------------
ALTER TABLE "public"."operate_log" ADD CONSTRAINT "operate_log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table os_platform
-- ----------------------------
ALTER TABLE "public"."os_platform" ADD CONSTRAINT "os_platform_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table permissions
-- ----------------------------
CREATE UNIQUE INDEX "permissions_permission_name_key" ON "public"."permissions" USING btree (
  "permission_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table permissions
-- ----------------------------
ALTER TABLE "public"."permissions" ADD CONSTRAINT "permissions_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table review
-- ----------------------------
CREATE UNIQUE INDEX "unique_reviewer_per_group" ON "public"."review" USING btree (
  "creator_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "group_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table review
-- ----------------------------
ALTER TABLE "public"."review" ADD CONSTRAINT "review_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table role_has_permission
-- ----------------------------
ALTER TABLE "public"."role_has_permission" ADD CONSTRAINT "role_has_permission_pkey" PRIMARY KEY ("role_id", "permission_name");

-- ----------------------------
-- Primary Key structure for table sensitive_word
-- ----------------------------
ALTER TABLE "public"."sensitive_word" ADD CONSTRAINT "sensitive_word_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table sms_config
-- ----------------------------
ALTER TABLE "public"."sms_config" ADD CONSTRAINT "sms_config_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table sms_log
-- ----------------------------
ALTER TABLE "public"."sms_log" ADD CONSTRAINT "sms_log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table sms_template
-- ----------------------------
ALTER TABLE "public"."sms_template" ADD CONSTRAINT "sms_template_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table tag
-- ----------------------------
CREATE UNIQUE INDEX "unique_tag" ON "public"."tag" USING btree (
  "name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table tag
-- ----------------------------
ALTER TABLE "public"."tag" ADD CONSTRAINT "tag_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table uctoo_role
-- ----------------------------
CREATE UNIQUE INDEX "unique_name" ON "public"."uctoo_role" USING btree (
  "name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table uctoo_role
-- ----------------------------
ALTER TABLE "public"."uctoo_role" ADD CONSTRAINT "uctoo_role_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table uctoo_session
-- ----------------------------
ALTER TABLE "public"."uctoo_session" ADD CONSTRAINT "uctoo_session_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table uctoo_user
-- ----------------------------
CREATE UNIQUE INDEX "unique_email" ON "public"."uctoo_user" USING btree (
  "email" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE UNIQUE INDEX "unique_username" ON "public"."uctoo_user" USING btree (
  "username" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table uctoo_user
-- ----------------------------
ALTER TABLE "public"."uctoo_user" ADD CONSTRAINT "uctoo_users_pk" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table unipay_applets
-- ----------------------------
ALTER TABLE "public"."unipay_applets" ADD CONSTRAINT "unipay_applets_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table unipay_config
-- ----------------------------
ALTER TABLE "public"."unipay_config" ADD CONSTRAINT "unipay_config_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_group
-- ----------------------------
ALTER TABLE "public"."user_group" ADD CONSTRAINT "user_group_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_has_account
-- ----------------------------
ALTER TABLE "public"."user_has_account" ADD CONSTRAINT "user_has_account_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_has_group
-- ----------------------------
ALTER TABLE "public"."user_has_group" ADD CONSTRAINT "user_has_group_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_has_jobs
-- ----------------------------
ALTER TABLE "public"."user_has_jobs" ADD CONSTRAINT "user_has_jobs_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_has_roles
-- ----------------------------
ALTER TABLE "public"."user_has_roles" ADD CONSTRAINT "user_has_roles_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_messages
-- ----------------------------
ALTER TABLE "public"."user_messages" ADD CONSTRAINT "user_messages_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_role
-- ----------------------------
ALTER TABLE "public"."user_role" ADD CONSTRAINT "user_role_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_score
-- ----------------------------
ALTER TABLE "public"."user_score" ADD CONSTRAINT "user_score_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_sign
-- ----------------------------
ALTER TABLE "public"."user_sign" ADD CONSTRAINT "user_sign_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_view
-- ----------------------------
ALTER TABLE "public"."user_view" ADD CONSTRAINT "user_view_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_wallet_apply
-- ----------------------------
ALTER TABLE "public"."user_wallet_apply" ADD CONSTRAINT "user_wallet_apply_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table user_wallet_log
-- ----------------------------
ALTER TABLE "public"."user_wallet_log" ADD CONSTRAINT "user_wallet_log_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table vmc
-- ----------------------------
ALTER TABLE "public"."vmc" ADD CONSTRAINT "vmc_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table vue_editor_items_config
-- ----------------------------
ALTER TABLE "public"."vue_editor_items_config" ADD CONSTRAINT "vue_editor_items_config_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table vue_editor_pages
-- ----------------------------
ALTER TABLE "public"."vue_editor_pages" ADD CONSTRAINT "vue_editor_pages_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_cloud
-- ----------------------------
ALTER TABLE "public"."wechat_cloud" ADD CONSTRAINT "wechat_cloud_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_graphic
-- ----------------------------
ALTER TABLE "public"."wechat_graphic" ADD CONSTRAINT "wechat_graphic_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_material
-- ----------------------------
ALTER TABLE "public"."wechat_material" ADD CONSTRAINT "wechat_material_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_menus
-- ----------------------------
ALTER TABLE "public"."wechat_menus" ADD CONSTRAINT "wechat_menus_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_miniapp_version
-- ----------------------------
ALTER TABLE "public"."wechat_miniapp_version" ADD CONSTRAINT "wechat_miniapp_version_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_reply
-- ----------------------------
ALTER TABLE "public"."wechat_reply" ADD CONSTRAINT "wechat_reply_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_tags
-- ----------------------------
ALTER TABLE "public"."wechat_tags" ADD CONSTRAINT "wechat_tags_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechat_user_has_tags
-- ----------------------------
ALTER TABLE "public"."wechat_user_has_tags" ADD CONSTRAINT "wechat_user_has_tags_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechatopen
-- ----------------------------
ALTER TABLE "public"."wechatopen" ADD CONSTRAINT "wechatopen_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table wechatopen_applet
-- ----------------------------
CREATE UNIQUE INDEX "wechatopen_applet_appid_key" ON "public"."wechatopen_applet" USING btree (
  "appid" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table wechatopen_applet
-- ----------------------------
ALTER TABLE "public"."wechatopen_applet" ADD CONSTRAINT "wechatopen_applet_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechatopen_miniapp_domains
-- ----------------------------
ALTER TABLE "public"."wechatopen_miniapp_domains" ADD CONSTRAINT "wechatopen_miniapp_domains_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechatopen_miniapp_users
-- ----------------------------
ALTER TABLE "public"."wechatopen_miniapp_users" ADD CONSTRAINT "wechatopen_miniapp_users_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechatopen_template
-- ----------------------------
ALTER TABLE "public"."wechatopen_template" ADD CONSTRAINT "wechatopen_template_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechatopen_template_draft
-- ----------------------------
ALTER TABLE "public"."wechatopen_template_draft" ADD CONSTRAINT "wechatopen_template_draft_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Indexes structure for table wechatopen_users
-- ----------------------------
CREATE UNIQUE INDEX "wechatopen_users_openid_key" ON "public"."wechatopen_users" USING btree (
  "openid" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table wechatopen_users
-- ----------------------------
ALTER TABLE "public"."wechatopen_users" ADD CONSTRAINT "wechatopen_users_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wechatpay_transaction
-- ----------------------------
ALTER TABLE "public"."wechatpay_transaction" ADD CONSTRAINT "wechatpay_transaction_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table wxa_updatable_message
-- ----------------------------
ALTER TABLE "public"."wxa_updatable_message" ADD CONSTRAINT "wxa_updatable_message_pkey" PRIMARY KEY ("id");

-- ----------------------------
-- Foreign Keys structure for table chat_messages
-- ----------------------------
ALTER TABLE "public"."chat_messages" ADD CONSTRAINT "chat_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."chat_conversations" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ----------------------------
-- Foreign Keys structure for table entity
-- ----------------------------
ALTER TABLE "public"."entity" ADD CONSTRAINT "Entity_creatorId_fkey" FOREIGN KEY ("creator") REFERENCES "public"."uctoo_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table group_has_permission
-- ----------------------------
ALTER TABLE "public"."group_has_permission" ADD CONSTRAINT "group_has_permission_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."user_group" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "public"."group_has_permission" ADD CONSTRAINT "group_has_permission_permission_name_fkey" FOREIGN KEY ("permission_name") REFERENCES "public"."permissions" ("permission_name") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ----------------------------
-- Foreign Keys structure for table group_tag
-- ----------------------------
ALTER TABLE "public"."group_tag" ADD CONSTRAINT "GroupTag_groupId_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."link_group" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."group_tag" ADD CONSTRAINT "GroupTag_tagId_fkey" FOREIGN KEY ("tagId") REFERENCES "public"."tag" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table i18
-- ----------------------------
ALTER TABLE "public"."i18" ADD CONSTRAINT "i18_lang_id_fkey" FOREIGN KEY ("lang_id") REFERENCES "public"."lang" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ----------------------------
-- Foreign Keys structure for table minishop_store
-- ----------------------------
ALTER TABLE "public"."minishop_store" ADD CONSTRAINT "minishop_store_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."minishop_store" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ----------------------------
-- Foreign Keys structure for table permissions
-- ----------------------------
ALTER TABLE "public"."permissions" ADD CONSTRAINT "permissions_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."permissions" ("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ----------------------------
-- Foreign Keys structure for table role_has_permission
-- ----------------------------
ALTER TABLE "public"."role_has_permission" ADD CONSTRAINT "role_has_permission_permission_name_fkey" FOREIGN KEY ("permission_name") REFERENCES "public"."permissions" ("permission_name") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "public"."role_has_permission" ADD CONSTRAINT "role_has_permission_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."uctoo_role" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ----------------------------
-- Foreign Keys structure for table user_has_account
-- ----------------------------
ALTER TABLE "public"."user_has_account" ADD CONSTRAINT "User_account_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."uctoo_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table user_has_group
-- ----------------------------
ALTER TABLE "public"."user_has_group" ADD CONSTRAINT "user_has_group_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."user_group" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "public"."user_has_group" ADD CONSTRAINT "user_has_group_groupable_id_fkey" FOREIGN KEY ("groupable_id") REFERENCES "public"."uctoo_user" ("id") ON DELETE RESTRICT ON UPDATE CASCADE;
