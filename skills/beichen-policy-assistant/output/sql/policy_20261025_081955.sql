-- 产业政策智能体落库 SQL
-- 生成时间: 2026-10-25T08:19:55

UPDATE public.company SET org_description = '北京北辰实业有限公司，注册于北京市朝阳区。', region = '北京市朝阳区', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '北京北辰实业有限公司' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_introduction, business_licence, org_description, org_type) SELECT '北京北辰实业有限公司', '北京市朝阳区', '', '', '', '', '', '', '', '', '', '', '', '', '', '北京北辰实业有限公司，注册于北京市朝阳区。', '', '北京北辰实业有限公司，注册于北京市朝阳区。', 'beichen-enterprise' WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '北京北辰实业有限公司' AND deleted_at IS NULL);
-- 以下必填列未采集到，已写空串（未编造）：social_credit_code、established_time、registered_capital、registered_address、mailing_address、legal_representative、legal_representativemobile、legal_representative_email、contact_name、contact_mobile、contact_email、contact_title、website、business_licence

INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '47c44659-2f95-4af3-b57f-ddb2d58fdc35', '政策适配报告 - 北京北辰实业有限公司', '# 政策适配研判报告 - 北京北辰实业有限公司

- 生成日期：2026-08-29
- 注册区域：北京市朝阳区
- 所属行业：待核实
- 企业资质：暂无

## 匹配政策清单（按匹配度排序）

| 序号 | 政策编号 | 政策名称 | 层级/领域 | 匹配度 | 匹配依据 |
|------|---------|---------|----------|--------|---------|
| 1 | 1 | 北京市引进人才管理办法 | 市级/人才支持 | 50 | 层级市级·领域人才支持 |
| 2 | 3 | 北京市知识产权质押融资专项政策 | 市级/知识产权 | 50 | 层级市级·领域知识产权 |
| 3 | 12 | 北京市高新技术企业培育支持政策 | 市级/高新技术产业 | 50 | 层级市级·领域高新技术产业 |
| 4 | 17 | 北京市专精特新中小企业培育支持政策 | 市级/中小企业 | 50 | 层级市级·领域中小企业 |
| 5 | 2 | 北京市青年科技人才支持计划 | 市级/青年科技人才 | 30 | 层级市级·领域青年科技人才 |
| 6 | 4 | 朝阳区中小企业融资担保费补贴政策 | 区级/融资服务 | 30 | 层级区级·领域融资服务 |
| 7 | 5 | 北京市促进人工智能产业发展若干政策 | 市级/人工智能 | 30 | 层级市级·领域人工智能 |
| 8 | 8 | 北京市数据要素市场建设支持政策 | 市级/数据要素 | 30 | 层级市级·领域数据要素 |
| 9 | 10 | 北京市数字医疗产业创新发展政策 | 市级/数字医疗 | 30 | 层级市级·领域数字医疗 |
| 10 | 13 | 朝阳区支持高新技术企业创新发展若干政策 | 区级/高新技术产业 | 30 | 层级区级·领域高新技术产业 |

## 申报条件对标分析

### 政策 1 - 北京市引进人才管理办法
- 注册区域（条件 北京市）：满足
- 资质要求（条件 高层次人才）：待核实
- 缺口项：无（以申报通知为准）

### 政策 3 - 北京市知识产权质押融资专项政策
- 注册区域（条件 北京市）：满足
- 资质要求（条件 拥有自主知识产权）：待核实
- 缺口项：无（以申报通知为准）

### 政策 12 - 北京市高新技术企业培育支持政策
- 注册区域（条件 北京市）：满足
- 资质要求（条件 高新技术企业）：待核实
- 缺口项：无（以申报通知为准）

### 政策 17 - 北京市专精特新中小企业培育支持政策
- 注册区域（条件 北京市）：满足
- 资质要求（条件 专精特新中小企业）：待核实
- 缺口项：无（以申报通知为准）

### 政策 2 - 北京市青年科技人才支持计划
- 注册区域（条件 北京市）：满足
- 资质要求（条件 青年科技人才）：待核实
- 行业要求（条件 人工智能、生物医药）：部分满足
- 缺口项：无（以申报通知为准）

### 政策 4 - 朝阳区中小企业融资担保费补贴政策
- 注册区域（条件 朝阳区注册）：不满足
- 资质要求（条件 中小企业）：待核实
- 缺口项：无（以申报通知为准）

### 政策 5 - 北京市促进人工智能产业发展若干政策
- 注册区域（条件 北京市）：满足
- 资质要求（条件 人工智能企业）：待核实
- 行业要求（条件 人工智能）：部分满足
- 缺口项：无（以申报通知为准）

### 政策 8 - 北京市数据要素市场建设支持政策
- 注册区域（条件 北京市）：满足
- 资质要求（条件 数据要素企业）：待核实
- 行业要求（条件 数据要素）：部分满足
- 缺口项：无（以申报通知为准）

### 政策 10 - 北京市数字医疗产业创新发展政策
- 注册区域（条件 北京市）：满足
- 资质要求（条件 数字医疗企业）：待核实
- 行业要求（条件 数字医疗）：部分满足
- 缺口项：无（以申报通知为准）

### 政策 13 - 朝阳区支持高新技术企业创新发展若干政策
- 注册区域（条件 朝阳区注册）：不满足
- 资质要求（条件 高新技术企业认定）：待核实
- 缺口项：无（以申报通知为准）

## 申报建议与优先级

1. 【高优先级】可申报（匹配度 50 分）
   - 政策：北京市引进人才管理办法（编号 1）
   - 支持方式：落户支持/资金奖励
   - 建议关注 北京市人才工作局 官网申报通知
2. 【高优先级】可申报（匹配度 50 分）
   - 政策：北京市知识产权质押融资专项政策（编号 3）
   - 支持方式：质押融资/贴息补贴
   - 建议关注 北京市知识产权局 官网申报通知
3. 【高优先级】可申报（匹配度 50 分）
   - 政策：北京市高新技术企业培育支持政策（编号 12）
   - 支持方式：研发费用加计扣除/奖励
   - 建议关注 北京市科委 官网申报通知
4. 【高优先级】可申报（匹配度 50 分）
   - 政策：北京市专精特新中小企业培育支持政策（编号 17）
   - 支持方式：认定奖励/融资支持
   - 建议关注 北京市经信局 官网申报通知
5. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市青年科技人才支持计划（编号 2）
   - 支持方式：科研经费资助
   - 建议关注 北京市科委 官网申报通知

## 合规声明

> 本报告由产业政策智能体自动生成，数据来源于公开渠道与政策知识库，每条匹配结论均已溯源至政策原文库编号；仅供申报参考，不构成法律意见。
', 'policy-match', 'completed', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-match"]'::jsonb, '{"profile_date": "2026-09-25", "matched_count": 77, "policy_nos": ["1", "2", "3"], "follow_status": "已完成", "report_file": "北京北辰实业有限公司-2026-08-29.md"}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策适配报告 - 北京北辰实业有限公司' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 1 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT 'dfec6250-7ddb-4ba3-8527-e08db39e491b', '政策申报 - 北京市高层次创新创业人才支持计划科技新星计划管理办法', '政策编号：1
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "1", "domain": "人才支持", "level": "市级", "department": "北京市科委", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\1-北京市高层次创新创业人才支持计划科技新星计划管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市高层次创新创业人才支持计划科技新星计划管理办法' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 2 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '824311be-85ab-4f4d-a7ef-cb49881a9cd4', '政策申报 - 北京市博士后科研工作站管理办法', '政策编号：2
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "2", "domain": "人才支持", "level": "市级", "department": "北京市人社局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\2-北京市博士后科研工作站管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市博士后科研工作站管理办法' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 3 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '71c7bd69-4b30-4d59-bd76-37cba828e904', '政策申报 - 北京市技能大师工作室建设管理办法', '政策编号：3
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "3", "domain": "人才支持", "level": "市级", "department": "北京市人社局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\3-北京市技能大师工作室建设管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市技能大师工作室建设管理办法' AND t.deleted_at IS NULL);
