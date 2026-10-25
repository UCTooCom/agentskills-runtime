-- 产业政策智能体落库 SQL
-- 生成时间: 2026-10-25T08:33:37

UPDATE public.company SET org_description = '北京北辰实业有限公司，注册于北京市朝阳区。', region = '北京市朝阳区', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '北京北辰实业有限公司' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_introduction, business_licence, org_description, org_type) SELECT '北京北辰实业有限公司', '北京市朝阳区', '', '', '', '', '', '', '', '', '', '', '', '', '', '北京北辰实业有限公司，注册于北京市朝阳区。', '', '北京北辰实业有限公司，注册于北京市朝阳区。', 'beichen-enterprise' WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '北京北辰实业有限公司' AND deleted_at IS NULL);
-- 以下必填列未采集到，已写空串（未编造）：social_credit_code、established_time、registered_capital、registered_address、mailing_address、legal_representative、legal_representativemobile、legal_representative_email、contact_name、contact_mobile、contact_email、contact_title、website、business_licence

INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '0554b0c8-2047-4507-8e01-1f13293e6c2c', '政策适配报告 - 北京北辰实业有限公司', '# 政策适配研判报告 - 北京北辰实业有限公司

- 生成日期：2026-10-25
- 注册区域：北京市朝阳区
- 所属行业：待核实
- 企业资质：暂无

## 适用范围（务必阅读）

> 本报告的政策依据来自**本地政策原文库（北京地区政策，当前 74 条）**与公开渠道检索结果，
> **不代表全国通用**，也不覆盖各区自行发布的全部细则；跨地区或区级申报请以当地主管部门发布的原文为准。
> 未能在原文库中备案的结论，均在报告中标注「未备案」并保留可点开来源，供人工复核。

## 匹配政策清单（按匹配度排序）

| 序号 | 政策编号 | 政策名称 | 层级/领域 | 匹配度 | 匹配依据 | 来源 |
|------|---------|---------|----------|--------|---------|------|
| 1 | 1 | 北京市高层次创新创业人才支持计划科技新星计划管理办法 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 2 | 2 | 北京市博士后科研工作站管理办法 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 3 | 3 | 北京市技能大师工作室建设管理办法 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 4 | 4 | 北京市支持留学回国人才创新创业若干措施 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 5 | 5 | 北京市朝阳区高层次人才引进支持政策 | 区级/人才支持 | 30 | 层级区级·领域人才支持 | — |

## 申报条件对标分析

### 政策 1 - 北京市高层次创新创业人才支持计划科技新星计划管理办法
- 缺口项：无（以申报通知为准）

### 政策 2 - 北京市博士后科研工作站管理办法
- 缺口项：无（以申报通知为准）

### 政策 3 - 北京市技能大师工作室建设管理办法
- 缺口项：无（以申报通知为准）

### 政策 4 - 北京市支持留学回国人才创新创业若干措施
- 缺口项：无（以申报通知为准）

### 政策 5 - 北京市朝阳区高层次人才引进支持政策
- 缺口项：无（以申报通知为准）

## 申报建议与优先级

1. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市高层次创新创业人才支持计划科技新星计划管理办法（编号 1）
   - 支持方式：待补充
   - 建议关注 北京市科委 官网申报通知
2. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市博士后科研工作站管理办法（编号 2）
   - 支持方式：待补充
   - 建议关注 北京市人社局 官网申报通知
3. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市技能大师工作室建设管理办法（编号 3）
   - 支持方式：待补充
   - 建议关注 北京市人社局 官网申报通知
4. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市支持留学回国人才创新创业若干措施（编号 4）
   - 支持方式：待补充
   - 建议关注 北京市人社局 官网申报通知
5. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市朝阳区高层次人才引进支持政策（编号 5）
   - 支持方式：待补充
   - 建议关注 朝阳区人才工作局 官网申报通知

## 未查到可靠依据（已排除出正式结论）

本次未产生被排除的条目。

## 合规声明

> 本报告由产业政策智能体自动生成，数据来源于公开渠道与政策知识库，每条匹配结论均已溯源至政策原文库编号；仅供申报参考，不构成法律意见。
', 'policy-match', 'completed', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-match"]'::jsonb, '{"profile_date": "2026-09-25", "matched_count": 74, "policy_nos": ["1", "2", "3"], "follow_status": "已完成", "report_file": "北京北辰实业有限公司-2026-10-25.md"}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策适配报告 - 北京北辰实业有限公司' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 1 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT 'c3999893-f5f7-4004-86dd-4530231699c9', '政策申报 - 北京市高层次创新创业人才支持计划科技新星计划管理办法', '政策编号：1
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "1", "domain": "人才支持", "level": "市级", "department": "北京市科委", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\1-北京市高层次创新创业人才支持计划科技新星计划管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市高层次创新创业人才支持计划科技新星计划管理办法' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 2 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '8ffaa876-edda-4feb-a06a-4fc1fae6b355', '政策申报 - 北京市博士后科研工作站管理办法', '政策编号：2
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "2", "domain": "人才支持", "level": "市级", "department": "北京市人社局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\2-北京市博士后科研工作站管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市博士后科研工作站管理办法' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 3 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT 'dbd84c71-cbcb-49ac-b563-4c0b63707e60', '政策申报 - 北京市技能大师工作室建设管理办法', '政策编号：3
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "3", "domain": "人才支持", "level": "市级", "department": "北京市人社局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\3-北京市技能大师工作室建设管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市技能大师工作室建设管理办法' AND t.deleted_at IS NULL);
