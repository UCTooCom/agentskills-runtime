/*

 Source Server         : pglocal
 Source Server Type    : PostgreSQL
 Source Server Version : 160008 (160008)
 Source Host           : localhost:5432
 Source Catalog        : uctoo
 Source Schema         : public

 Target Server Type    : PostgreSQL
 Target Server Version : 160008 (160008)
 File Encoding         : 65001

 Date: 09/09/2026 17:03:59
*/


-- ----------------------------
-- Table structure for due_diligence_mcp_call_log
-- ----------------------------
DROP TABLE IF EXISTS "public"."due_diligence_mcp_call_log";
CREATE TABLE "public"."due_diligence_mcp_call_log" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "task_id" uuid,
  "tool_name" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "tool_arg" text COLLATE "pg_catalog"."default",
  "duration_ms" int4,
  "result_status" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "error_message" text COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."task_id" IS '关联任务ID，关联due_diligence_task.id';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."tool_name" IS 'MCP工具名称（如registration-info/equity-tree/judicial-case）';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."tool_arg" IS '工具入参JSON（脱敏）';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."duration_ms" IS '调用耗时毫秒';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."result_status" IS '结果状态：success/failed/timeout';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."error_message" IS '错误信息（脱敏）';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."creator" IS '创建者UUID，行级权限';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."due_diligence_mcp_call_log"."deleted_at" IS '软删除时间';
COMMENT ON TABLE "public"."due_diligence_mcp_call_log" IS 'MCP调用清单/日志表，赛事评分凭证与审计依据';

-- ----------------------------
-- Records of due_diligence_mcp_call_log
-- ----------------------------
INSERT INTO "public"."due_diligence_mcp_call_log" VALUES ('cda07bd8-2972-4a88-9e81-d243a4bf3b11', 'a1b2c3d4-0001-0001-0001-000000000001', 'mcp_initialize', '{"endpoint":"https://mcp.tianyancha.com/mcp"}', 1377, 'success', NULL, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:14+08', '2026-09-09 15:11:15+08', NULL);
INSERT INTO "public"."due_diligence_mcp_call_log" VALUES ('2f1a2742-96f8-4e90-bcc1-48713cfeda71', 'a1b2c3d4-0001-0001-0001-000000000001', 'get_company_registration_info', '{"company_name":"腾讯科技（深圳）有限公司","tool_name":"get_company_registration_info"}', 1922, 'success', NULL, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:15+08', '2026-09-09 15:11:17+08', NULL);
INSERT INTO "public"."due_diligence_mcp_call_log" VALUES ('f654a954-9d37-4deb-852f-7c669d69c8dd', 'a1b2c3d4-0001-0001-0001-000000000001', 'get_risk_overview', '{"company_name":"腾讯科技（深圳）有限公司","tool_name":"get_risk_overview"}', 2053, 'success', NULL, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:17+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_mcp_call_log" VALUES ('412bb411-153b-43a5-9d72-ef7a2aa90319', 'a1b2c3d4-0001-0001-0001-000000000001', 'mcp_close', '{}', 27, 'success', NULL, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:23+08', '2026-09-09 15:11:23+08', NULL);

-- ----------------------------
-- Indexes structure for table due_diligence_mcp_call_log
-- ----------------------------
CREATE INDEX "idx_due_diligence_mcp_call_log_creator" ON "public"."due_diligence_mcp_call_log" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_mcp_call_log_task" ON "public"."due_diligence_mcp_call_log" USING btree (
  "task_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_mcp_call_log_tool" ON "public"."due_diligence_mcp_call_log" USING btree (
  "tool_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table due_diligence_mcp_call_log
-- ----------------------------
ALTER TABLE "public"."due_diligence_mcp_call_log" ADD CONSTRAINT "pk_due_diligence_mcp_call_log" PRIMARY KEY ("id");
