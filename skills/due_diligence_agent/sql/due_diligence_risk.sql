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

 Date: 09/09/2026 17:04:20
*/


-- ----------------------------
-- Table structure for due_diligence_risk
-- ----------------------------
DROP TABLE IF EXISTS "public"."due_diligence_risk";
CREATE TABLE "public"."due_diligence_risk" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "enterprise_id" uuid NOT NULL,
  "risk_type" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "risk_level" varchar(10) COLLATE "pg_catalog"."default" NOT NULL,
  "level_basis" text COLLATE "pg_catalog"."default" NOT NULL,
  "risk_description" text COLLATE "pg_catalog"."default" NOT NULL,
  "risk_date" date,
  "source_tool" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."due_diligence_risk"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."due_diligence_risk"."enterprise_id" IS '企业ID，关联due_diligence_enterprise.id';
COMMENT ON COLUMN "public"."due_diligence_risk"."risk_type" IS '风险类型：judicial-case-司法案件/administrative-penalty-行政处罚/operation-abnormal-经营异常等';
COMMENT ON COLUMN "public"."due_diligence_risk"."risk_level" IS '风险等级：高/中/低';
COMMENT ON COLUMN "public"."due_diligence_risk"."level_basis" IS '分级依据说明（可解释、可追溯）';
COMMENT ON COLUMN "public"."due_diligence_risk"."risk_description" IS '风险描述';
COMMENT ON COLUMN "public"."due_diligence_risk"."risk_date" IS '风险发生日期';
COMMENT ON COLUMN "public"."due_diligence_risk"."source_tool" IS '数据来源工具（天眼查MCP工具名）';
COMMENT ON COLUMN "public"."due_diligence_risk"."creator" IS '创建者UUID，行级权限';
COMMENT ON COLUMN "public"."due_diligence_risk"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."due_diligence_risk"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."due_diligence_risk"."deleted_at" IS '软删除时间';
COMMENT ON TABLE "public"."due_diligence_risk" IS '风险条目表，存储司法/行政处罚/经营异常等多源风险分级结果';

-- ----------------------------
-- Records of due_diligence_risk
-- ----------------------------
INSERT INTO "public"."due_diligence_risk" VALUES ('032bfb1c-e70b-442e-9652-cc4a17f1cbd0', 'a1b2c3d4-0002-0002-0002-000000000002', 'judgment_debtor', '高', '天眼查风险概览标注为高风险，被执行人2条', '被执行人记录2条（当前存续状态）', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('9f8bf0f6-c90f-4968-a6c2-7c4f058a248e', 'a1b2c3d4-0002-0002-0002-000000000002', 'historical_judgment_debtor', '高', '天眼查风险概览标注为高风险，历史被执行人1条', '历史被执行人记录1条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('6927e89e-89df-48fe-b44f-f67a6faf6739', 'a1b2c3d4-0002-0002-0002-000000000002', 'hearing_notice', '中', '天眼查风险概览标注为警示，开庭公告659条，按分级规则警示归为中风险', '开庭公告659条（当前存续状态）', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('df7432cc-93d3-4de2-b86c-a34aec4059ee', 'a1b2c3d4-0002-0002-0002-000000000002', 'judicial_documents', '中', '天眼查风险概览标注为警示，裁判文书201条，按分级规则警示归为中风险', '裁判文书201条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('6dfa2b16-495e-4d0d-a0cc-49aa9a28990d', 'a1b2c3d4-0002-0002-0002-000000000002', 'court_notice', '中', '天眼查风险概览标注为警示，法院公告70条，按分级规则警示归为中风险', '法院公告70条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('fe6841ca-3d84-4aa0-939b-1d00e160a719', 'a1b2c3d4-0002-0002-0002-000000000002', 'service_notice', '中', '天眼查风险概览标注为警示，送达公告139条，按分级规则警示归为中风险', '送达公告139条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('ddc1276b-07cd-4bb3-a950-2eaaf1bd4328', 'a1b2c3d4-0002-0002-0002-000000000002', 'case_filing_info', '中', '天眼查风险概览标注为警示，立案信息188条，按分级规则警示归为中风险', '立案信息188条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('da92f3a5-f212-445a-b150-d339d565a2b5', 'a1b2c3d4-0002-0002-0002-000000000002', 'historical_hearing_notice', '低', '天眼查风险概览标注为警示，历史开庭公告2460条，历史数据按分级规则归为低风险', '历史开庭公告2460条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('8556efa1-507b-4b5c-ba34-59e325aa97cc', 'a1b2c3d4-0002-0002-0002-000000000002', 'historical_judicial_docs', '低', '天眼查风险概览标注为警示，历史裁判文书2110条，历史数据按分级规则归为低风险', '历史裁判文书2110条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('499583b2-6fd8-4e91-ac1c-b533b8be4201', 'a1b2c3d4-0002-0002-0002-000000000002', 'historical_admin_penalty', '低', '天眼查风险概览标注为警示，历史行政处罚1条，历史数据按分级规则归为低风险', '历史行政处罚1条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('95838fa1-f766-4e4a-82a8-c63b751c20cd', 'a1b2c3d4-0002-0002-0002-000000000002', 'historical_equity_pledge', '低', '天眼查风险概览标注为警示，历史股权出质14条，历史数据按分级规则归为低风险', '历史股权出质14条', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('2317ce39-dedc-41b1-8c42-2a511524fd1b', 'a1b2c3d4-0002-0002-0002-000000000002', 'peripheral_simple_cancellation', '高', '天眼查周边风险标注为高风险，关联企业简易注销', '该公司投资的深圳市人保腾讯麦盛能源投资基金企业（有限合伙）进行了简易注销；关联主体：深圳市人保腾讯麦盛能源投资基金企业（有限合伙）', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);
INSERT INTO "public"."due_diligence_risk" VALUES ('0de756ce-800e-4056-b4cf-d98a4e5107be', 'a1b2c3d4-0002-0002-0002-000000000002', 'peripheral_liquidation', '高', '天眼查周边风险标注为高风险，关联企业有清算信息', '该公司投资的武汉市世纪冲鸣科技有限公司有清算信息；关联主体：武汉市世纪冲鸣科技有限公司', NULL, 'get_risk_overview', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:19+08', '2026-09-09 15:11:19+08', NULL);

-- ----------------------------
-- Indexes structure for table due_diligence_risk
-- ----------------------------
CREATE INDEX "idx_due_diligence_risk_creator" ON "public"."due_diligence_risk" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_risk_enterprise" ON "public"."due_diligence_risk" USING btree (
  "enterprise_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_risk_level" ON "public"."due_diligence_risk" USING btree (
  "risk_level" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table due_diligence_risk
-- ----------------------------
ALTER TABLE "public"."due_diligence_risk" ADD CONSTRAINT "pk_due_diligence_risk" PRIMARY KEY ("id");
