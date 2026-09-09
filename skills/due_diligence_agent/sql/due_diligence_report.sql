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

 Date: 09/09/2026 17:04:10
*/


-- ----------------------------
-- Table structure for due_diligence_report
-- ----------------------------
DROP TABLE IF EXISTS "public"."due_diligence_report";
CREATE TABLE "public"."due_diligence_report" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "enterprise_id" uuid NOT NULL,
  "title" varchar(200) COLLATE "pg_catalog"."default" NOT NULL,
  "report_content" text COLLATE "pg_catalog"."default" NOT NULL,
  "report_format" varchar(10) COLLATE "pg_catalog"."default" NOT NULL,
  "generated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "disclaimer" text COLLATE "pg_catalog"."default" NOT NULL,
  "scene_type" varchar(50) COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;
COMMENT ON COLUMN "public"."due_diligence_report"."id" IS '主键UUID';
COMMENT ON COLUMN "public"."due_diligence_report"."enterprise_id" IS '企业ID，关联due_diligence_enterprise.id';
COMMENT ON COLUMN "public"."due_diligence_report"."title" IS '报告标题';
COMMENT ON COLUMN "public"."due_diligence_report"."report_content" IS '报告内容（四部分：基本信息/股权穿透/风险分级/结论建议）';
COMMENT ON COLUMN "public"."due_diligence_report"."report_format" IS '报告格式：md/docx/html';
COMMENT ON COLUMN "public"."due_diligence_report"."generated_at" IS '报告生成时间';
COMMENT ON COLUMN "public"."due_diligence_report"."disclaimer" IS '免责声明';
COMMENT ON COLUMN "public"."due_diligence_report"."scene_type" IS '场景类型';
COMMENT ON COLUMN "public"."due_diligence_report"."creator" IS '创建者UUID，行级权限';
COMMENT ON COLUMN "public"."due_diligence_report"."created_at" IS '创建时间';
COMMENT ON COLUMN "public"."due_diligence_report"."updated_at" IS '更新时间';
COMMENT ON COLUMN "public"."due_diligence_report"."deleted_at" IS '软删除时间';
COMMENT ON TABLE "public"."due_diligence_report" IS '尽调报告表，存储四部分结构化尽调报告';

-- ----------------------------
-- Records of due_diligence_report
-- ----------------------------
INSERT INTO "public"."due_diligence_report" VALUES ('fa7dd9de-501b-46a6-9c5c-1f190071113b', 'a1b2c3d4-0002-0002-0002-000000000002', '企业信用与风控尽调报告-腾讯科技（深圳）有限公司-2026-09-09', '# 企业信用与风控尽调报告

**企业名称：** 腾讯科技（深圳）有限公司

## 一、企业基本信息

- **data_source**：tianyancha
- **credit_code**：9144030071526726XG
- **legal_representative**：马化腾
- **registered_capital**：200万美元
- **registration_status**：存续
- **business_scope**：一般经营项目：从事计算机软硬件的技术开发、销售自行开发的软件；计算机技术服务及信息服务；计算机硬件的研发、批发；玩具设计开发；玩具的批发与零售（许可审批类商品除外）；商品的批发与零售（许可审批类商品除外）；动漫及衍生产品设计服务；电子产品设计服务；游戏游艺设备销售；国内贸易；从事货物及技术进出口(不含分销及国家专营、专...

## 二、股权结构（含穿透）

（直接股东数据缺失）

## 三、风险清单（分级标注）

（未识别到风险事项）

## 四、结论与建议

### 综合风险评级：暂无风险

**风险概况：** 高风险0项、中风险0项、低风险0项。

**股权穿透：** 未识别到最终受益人数据。

**建议：** 未识别到明显风险事项，建议定期复核。

---

*免责声明：本报告由企业信用与风控尽调智能体自动生成，仅供参考、不构成投资/授信/准入决策依据。*
*报告生成时间：2026-09-09 15:11:22*', 'md', '2026-09-09 15:11:22+08', '免责声明：本报告由企业信用与风控尽调智能体自动生成，仅供参考、不构成投资/授信/准入决策依据。', 'supplier', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:22+08', '2026-09-09 15:11:22+08', NULL);
INSERT INTO "public"."due_diligence_report" VALUES ('285a117d-4158-43de-bf6e-496409e25baa', 'a1b2c3d4-0002-0002-0002-000000000002', '企业信用与风控尽调报告-腾讯科技（深圳）有限公司-2026-09-09', '<!DOCTYPE html><html><head><meta charset="UTF-8"><style>body{font-family:sans-serif;max-width:900px;margin:0 auto;padding:20px;}h1{color:#1a5276;}</style></head><body><h1>企业信用与风控尽调报告</h1><p>企业名称：腾讯科技（深圳）有限公司</p><h2>一、企业基本信息</h2><ul><li>统一社会信用代码：9144030071526726XG</li><li>法定代表人：马化腾</li><li>注册资本：200万美元</li><li>登记状态：存续</li></ul><h2>二、股权结构（含穿透）</h2><p>（直接股东数据缺失）</p><h2>三、风险清单（分级标注）</h2><p>（未识别到风险事项）</p><h2>四、结论与建议</h2><p>综合风险评级：暂无风险</p><p>免责声明：本报告仅供参考、不构成投资/授信/准入决策依据。</p></body></html>', 'html', '2026-09-09 15:11:22+08', '免责声明：本报告由企业信用与风控尽调智能体自动生成，仅供参考、不构成投资/授信/准入决策依据。', 'supplier', '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-09-09 15:11:22+08', '2026-09-09 15:11:22+08', NULL);

-- ----------------------------
-- Indexes structure for table due_diligence_report
-- ----------------------------
CREATE INDEX "idx_due_diligence_report_creator" ON "public"."due_diligence_report" USING btree (
  "creator" "pg_catalog"."uuid_ops" ASC NULLS LAST
);
CREATE INDEX "idx_due_diligence_report_enterprise" ON "public"."due_diligence_report" USING btree (
  "enterprise_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table due_diligence_report
-- ----------------------------
ALTER TABLE "public"."due_diligence_report" ADD CONSTRAINT "pk_due_diligence_report" PRIMARY KEY ("id");
