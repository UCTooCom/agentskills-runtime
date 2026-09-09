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

 Date: 09/09/2026 17:03:48
*/


-- ----------------------------
-- Table structure for due_diligence_equity
-- ----------------------------
DROP TABLE IF EXISTS "public"."due_diligence_equity";
CREATE TABLE "public"."due_diligence_equity" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "enterprise_id" uuid NOT NULL,
  "shareholder_name" varchar(200) COLLATE "pg_catalog"."default" NOT NULL,
  "shareholding_ratio" numeric(5,2) NOT NULL DEFAULT 0.00,
  "penetration_level" int4 NOT NULL DEFAULT 0,
  "shareholding_path" text COLLATE "pg_catalog"."default" NOT NULL,
  "is_beneficial_owner" varchar(10) COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."due_diligence_equity"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."due_diligence_equity"."enterprise_id" IS '企业ID，关联due_diligence_enterprise.id';
COMMENT ON COLUMN "public"."due_diligence_equity"."shareholder_name" IS '股东名称';
COMMENT ON COLUMN "public"."due_diligence_equity"."shareholding_ratio" IS '持股比例（0~100.00）';
COMMENT ON COLUMN "public"."due_diligence_equity"."penetration_level" IS '穿透层级，0=直接股东，1=间接第一层，以此类推';
COMMENT ON COLUMN "public"."due_diligence_equity"."shareholding_path" IS '持股路径，如 A→B→C';
COMMENT ON COLUMN "public"."due_diligence_equity"."is_beneficial_owner" IS '是否最终受益人：是/否';
COMMENT ON COLUMN "public"."due_diligence_equity"."creator" IS '创建者UUID，行级权限';
COMMENT ON COLUMN "public"."due_diligence_equity"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."due_diligence_equity"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."due_diligence_equity"."deleted_at" IS '软删除时间';
COMMENT ON TABLE "public"."due_diligence_equity" IS '股权结构条目表，存储穿透计算后的股东与持股关系';

-- ----------------------------
-- Records of due_diligence_equity
-- ----------------------------

-- ----------------------------
-- Indexes structure for table due_diligence_equity
-- ----------------------------
CREATE INDEX "idx_due_diligence_equity_creator" ON "public"."due_diligence_equity" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_equity_enterprise" ON "public"."due_diligence_equity" USING btree (
  "enterprise_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table due_diligence_equity
-- ----------------------------
ALTER TABLE "public"."due_diligence_equity" ADD CONSTRAINT "pk_due_diligence_equity" PRIMARY KEY ("id");
