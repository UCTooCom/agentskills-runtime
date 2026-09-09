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

 Date: 09/09/2026 17:03:36
*/


-- ----------------------------
-- Table structure for due_diligence_enterprise
-- ----------------------------
DROP TABLE IF EXISTS "public"."due_diligence_enterprise";
CREATE TABLE "public"."due_diligence_enterprise" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "enterprise_name" varchar(200) COLLATE "pg_catalog"."default" NOT NULL,
  "credit_code" varchar(18) COLLATE "pg_catalog"."default",
  "legal_representative" varchar(100) COLLATE "pg_catalog"."default",
  "registered_capital" varchar(100) COLLATE "pg_catalog"."default",
  "established_date" date,
  "registration_status" varchar(50) COLLATE "pg_catalog"."default",
  "business_scope" text COLLATE "pg_catalog"."default",
  "data_source" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "fetched_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "scene_type" varchar(50) COLLATE "pg_catalog"."default",
  "task_id" uuid,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."due_diligence_enterprise"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."enterprise_name" IS '企业名称';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."credit_code" IS '统一社会信用代码（18位，唯一性辅助判重）';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."legal_representative" IS '法定代表人';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."registered_capital" IS '注册资本';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."established_date" IS '成立日期';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."registration_status" IS '经营状态：存续/注销/吊销等';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."business_scope" IS '经营范围';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."data_source" IS '数据来源：tianyancha等';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."fetched_at" IS '数据采集时间';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."scene_type" IS '场景类型';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."task_id" IS '关联任务ID，关联due_diligence_task.id';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."creator" IS '创建者UUID，行级权限';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."due_diligence_enterprise"."deleted_at" IS '软删除时间';
COMMENT ON TABLE "public"."due_diligence_enterprise" IS '企业基础信息表，存储天眼查工商信息采集结果';

-- ----------------------------
-- Records of due_diligence_enterprise
-- ----------------------------
INSERT INTO "public"."due_diligence_enterprise" VALUES ('a1b2c3d4-0002-0002-0002-000000000002', '腾讯科技（深圳）有限公司', '9144030071526726XG', '马化腾', '200万美元', '2000-02-24', '存续', '一般经营项目：从事计算机软硬件的技术开发、销售自行开发的软件；计算机技术服务及信息服务；计算机硬件的研发、批发；玩具设计开发；玩具的批发与零售（许可审批类商品除外）；商品的批发与零售（许可审批类商品除外）；动漫及衍生产品设计服务；电子产品设计服务；游戏游艺设备销售；国内贸易；从事货物及技术进出口(不含分销及国家专营、专...', 'tianyancha', '2026-09-09 15:11:17+08', 'supplier', 'a1b2c3d4-0001-0001-0001-000000000001', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:17+08', '2026-09-09 15:11:17+08', NULL);

-- ----------------------------
-- Indexes structure for table due_diligence_enterprise
-- ----------------------------
CREATE INDEX "idx_due_diligence_enterprise_creator" ON "public"."due_diligence_enterprise" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_enterprise_credit" ON "public"."due_diligence_enterprise" USING btree (
  "credit_code" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_enterprise_name" ON "public"."due_diligence_enterprise" USING btree (
  "enterprise_name" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_enterprise_task" ON "public"."due_diligence_enterprise" USING btree (
  "task_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table due_diligence_enterprise
-- ----------------------------
ALTER TABLE "public"."due_diligence_enterprise" ADD CONSTRAINT "pk_due_diligence_enterprise" PRIMARY KEY ("id");
