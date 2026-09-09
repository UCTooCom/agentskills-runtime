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

 Date: 09/09/2026 17:04:32
*/


-- ----------------------------
-- Table structure for due_diligence_task
-- ----------------------------
DROP TABLE IF EXISTS "public"."due_diligence_task";
CREATE TABLE "public"."due_diligence_task" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "task_name" varchar(200) COLLATE "pg_catalog"."default" NOT NULL,
  "enterprise_list" jsonb,
  "scene_type" varchar(50) COLLATE "pg_catalog"."default",
  "task_status" varchar(20) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'pending'::character varying,
  "total_count" int4 NOT NULL DEFAULT 0,
  "success_count" int4 NOT NULL DEFAULT 0,
  "fail_count" int4 NOT NULL DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."due_diligence_task"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."due_diligence_task"."task_name" IS '任务名称';
COMMENT ON COLUMN "public"."due_diligence_task"."enterprise_list" IS '企业名单JSON数组';
COMMENT ON COLUMN "public"."due_diligence_task"."scene_type" IS '场景类型：supplier-供应商尽调/customer-客户授信/investment-投资尽调/competitor-竞对分析/compliance-合规排查';
COMMENT ON COLUMN "public"."due_diligence_task"."task_status" IS '任务状态：pending-待处理/running-进行中/completed-完成/failed-失败';
COMMENT ON COLUMN "public"."due_diligence_task"."total_count" IS '企业总数';
COMMENT ON COLUMN "public"."due_diligence_task"."success_count" IS '成功数';
COMMENT ON COLUMN "public"."due_diligence_task"."fail_count" IS '失败数';
COMMENT ON COLUMN "public"."due_diligence_task"."creator" IS '创建者UUID，关联uctoo_user.id，行级权限';
COMMENT ON COLUMN "public"."due_diligence_task"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."due_diligence_task"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."due_diligence_task"."deleted_at" IS '软删除时间，NULL=未删除';
COMMENT ON TABLE "public"."due_diligence_task" IS '尽调任务表，存储单/批量尽调任务发起记录与进度';

-- ----------------------------
-- Records of due_diligence_task
-- ----------------------------
INSERT INTO "public"."due_diligence_task" VALUES ('a1b2c3d4-0001-0001-0001-000000000001', '单企业尽调-腾讯科技（深圳）有限公司', '["腾讯科技（深圳）有限公司"]', 'supplier', 'completed', 1, 1, 0, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:14+08', '2026-09-09 15:11:23+08', NULL);

-- ----------------------------
-- Indexes structure for table due_diligence_task
-- ----------------------------
CREATE INDEX "idx_due_diligence_task_creator" ON "public"."due_diligence_task" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_task_status" ON "public"."due_diligence_task" USING btree (
  "task_status" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table due_diligence_task
-- ----------------------------
ALTER TABLE "public"."due_diligence_task" ADD CONSTRAINT "pk_due_diligence_task" PRIMARY KEY ("id");
