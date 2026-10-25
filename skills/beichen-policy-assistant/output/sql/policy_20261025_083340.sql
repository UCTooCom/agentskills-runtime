-- 产业政策智能体落库 SQL
-- 生成时间: 2026-10-25T08:33:40

UPDATE public.company SET org_description = '北京朝阳智算科技有限公司，注册于朝阳区，属于人工智能、数据要素行业。', region = '朝阳区', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '北京朝阳智算科技有限公司' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_introduction, business_licence, org_description, org_type) SELECT '北京朝阳智算科技有限公司', '朝阳区', '', '', '', '', '', '', '', '', '', '', '', '', '', '北京朝阳智算科技有限公司，注册于朝阳区，属于人工智能、数据要素行业。', '', '北京朝阳智算科技有限公司，注册于朝阳区，属于人工智能、数据要素行业。', 'beichen-enterprise' WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '北京朝阳智算科技有限公司' AND deleted_at IS NULL);
-- 以下必填列未采集到，已写空串（未编造）：social_credit_code、established_time、registered_capital、registered_address、mailing_address、legal_representative、legal_representativemobile、legal_representative_email、contact_name、contact_mobile、contact_email、contact_title、website、business_licence

INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '56f1d9ee-4d5e-4d0f-8ee4-aa083aefbde1', '政策适配报告 - 北京朝阳智算科技有限公司', '# 政策适配研判报告 - 北京朝阳智算科技有限公司

- 生成日期：2026-10-25
- 注册区域：朝阳区
- 所属行业：人工智能、数据要素
- 企业资质：暂无

## 适用范围（务必阅读）

> 本报告的政策依据来自**本地政策原文库（北京地区政策，当前 74 条）**与公开渠道检索结果，
> **不代表全国通用**，也不覆盖各区自行发布的全部细则；跨地区或区级申报请以当地主管部门发布的原文为准。
> 未能在原文库中备案的结论，均在报告中标注「未备案」并保留可点开来源，供人工复核。

## 匹配政策清单（按匹配度排序）

| 序号 | 政策编号 | 政策名称 | 层级/领域 | 匹配度 | 匹配依据 | 来源 |
|------|---------|---------|----------|--------|---------|------|
| 1 | 19 | 北京市促进人工智能产业发展若干政策 | 市级/人工智能 | 45 | 层级市级·领域人工智能；领域命中：人工智能 | — |
| 2 | 20 | 北京市朝阳区促进人工智能产业发展措施 | 区级/人工智能 | 45 | 层级区级·领域人工智能；领域命中：人工智能 | — |
| 3 | 23 | 北京市数据资产入表试点工作方案 | 市级/数据要素 | 45 | 层级市级·领域数据要素；领域命中：数据要素 | — |
| 4 | 24 | 北京市数据跨境流动便利化试点政策 | 市级/数据要素 | 45 | 层级市级·领域数据要素；领域命中：数据要素 | — |
| 5 | 25 | 北京市朝阳区数据要素产业发展若干政策 | 区级/数据要素 | 45 | 层级区级·领域数据要素；领域命中：数据要素 | — |

## 申报条件对标分析

### 政策 19 - 北京市促进人工智能产业发展若干政策
- 缺口项：无（以申报通知为准）

### 政策 20 - 北京市朝阳区促进人工智能产业发展措施
- 缺口项：无（以申报通知为准）

### 政策 23 - 北京市数据资产入表试点工作方案
- 缺口项：无（以申报通知为准）

### 政策 24 - 北京市数据跨境流动便利化试点政策
- 缺口项：无（以申报通知为准）

### 政策 25 - 北京市朝阳区数据要素产业发展若干政策
- 缺口项：无（以申报通知为准）

## 申报建议与优先级

1. 【高优先级】可申报（匹配度 45 分）
   - 政策：北京市促进人工智能产业发展若干政策（编号 19）
   - 支持方式：待补充
   - 建议关注 北京市经济和信息化局 官网申报通知
2. 【高优先级】可申报（匹配度 45 分）
   - 政策：北京市朝阳区促进人工智能产业发展措施（编号 20）
   - 支持方式：待补充
   - 建议关注 朝阳区科信局 官网申报通知
3. 【高优先级】可申报（匹配度 45 分）
   - 政策：北京市数据资产入表试点工作方案（编号 23）
   - 支持方式：待补充
   - 建议关注 北京市财政局、市经信局 官网申报通知
4. 【高优先级】可申报（匹配度 45 分）
   - 政策：北京市数据跨境流动便利化试点政策（编号 24）
   - 支持方式：待补充
   - 建议关注 北京市网信办、市经信局 官网申报通知
5. 【高优先级】可申报（匹配度 45 分）
   - 政策：北京市朝阳区数据要素产业发展若干政策（编号 25）
   - 支持方式：待补充
   - 建议关注 朝阳区科信局、区大数据中心 官网申报通知

## 未查到可靠依据（已排除出正式结论）

本次未产生被排除的条目。

## 合规声明

> 本报告由产业政策智能体自动生成，数据来源于公开渠道与政策知识库，每条匹配结论均已溯源至政策原文库编号；仅供申报参考，不构成法律意见。
', 'policy-match', 'completed', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-match"]'::jsonb, '{"profile_date": "2026-08-29", "matched_count": 74, "policy_nos": ["19", "20", "23"], "follow_status": "已完成", "report_file": "北京朝阳智算科技有限公司-2026-10-25.md"}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京朝阳智算科技有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策适配报告 - 北京朝阳智算科技有限公司' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 19 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '6ff8fcd3-b23b-4c3c-8992-e2a2e74e06fa', '政策申报 - 北京市促进人工智能产业发展若干政策', '政策编号：19
支持方式：待补充
匹配依据：层级市级·领域人工智能；领域命中：人工智能
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "19", "domain": "人工智能", "level": "市级", "department": "北京市经济和信息化局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\19-北京市促进人工智能产业发展若干政策.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京朝阳智算科技有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市促进人工智能产业发展若干政策' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 20 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT 'f57e33ef-04a3-41f9-963b-3eef8f8c2c7d', '政策申报 - 北京市朝阳区促进人工智能产业发展措施', '政策编号：20
支持方式：待补充
匹配依据：层级区级·领域人工智能；领域命中：人工智能
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "20", "domain": "人工智能", "level": "区级", "department": "朝阳区科信局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\20-北京市朝阳区促进人工智能产业发展措施.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京朝阳智算科技有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市朝阳区促进人工智能产业发展措施' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 23 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT 'ce11a0b6-f6ec-4ec2-b082-d45ea81a6621', '政策申报 - 北京市数据资产入表试点工作方案', '政策编号：23
支持方式：待补充
匹配依据：层级市级·领域数据要素；领域命中：数据要素
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "23", "domain": "数据要素", "level": "市级", "department": "北京市财政局、市经信局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\23-北京市数据资产入表试点工作方案.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京朝阳智算科技有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市数据资产入表试点工作方案' AND t.deleted_at IS NULL);
