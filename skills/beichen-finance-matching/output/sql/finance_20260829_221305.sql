-- 金融匹配智能体落库 SQL
-- 生成时间: 2026-08-29T22:13:05.159804

UPDATE public.company SET org_description = '融资需求 500万（研发投入）| 企业画像摘要：北京北辰实业有限公司，注册于北京市朝阳区。', region = '北京市朝阳区', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '北京北辰实业有限公司' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '北京北辰实业有限公司', '北京市朝阳区', '融资需求 500万（研发投入）| 企业画像摘要：北京北辰实业有限公司，注册于北京市朝阳区。', 'beichen-enterprise', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '北京北辰实业有限公司' AND deleted_at IS NULL);

INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '33128c8e-b5ea-4e3b-8532-d631c7c11016', '融资方案 - 北京北辰实业有限公司', '# 定制融资方案 - 北京北辰实业有限公司

## 需求概览

- 融资金额：500万
- 融资期限：2年
- 融资用途：研发投入
- 担保方式：信用
- 服务单号：FC-20260829-5033BE

## 备选机构方案对比

| 机构 | 推荐产品 | 产品类型 | 额度 | 期限 | 担保 | 匹配度 |
|------|---------|---------|------|------|------|--------|
| 光大银行 | 科技研发贷 | 债权 | 视企业情况 | 流贷最长5年/项目贷最长10年 | 灵活 | 55.8 |
| 光大银行 | 知识产权质押贷 | 债权 | 额度无上限 | 最长3年 | 质押 | 55.8 |
| 浦发银行 | 浦研贷 | 债权 | 视企业情况 | 流贷最长5年/固定贷最长10年 | 灵活 | 42.8 |
| 北京银行 | 科创贷 | 债权 | 最高10亿元 | 视情况 | 知识产权质押 | 38.2 |
| 北京银行 | 科创e贷 | 债权 | 最高500万元 | 视情况 | 信用 | 38.2 |

## 各方案适配理由

### 光大银行（匹配度 55.8）
- 匹配依据：优势领域命中 1 项（1 项与需求领域相关）；服务经验 31 家次；平均放款周期约 5 个工作日
- 优势领域：数据要素、科技金融、知识产权质押、专精特新

### 浦发银行（匹配度 42.8）
- 匹配依据：优势领域命中 1 项（1 项与需求领域相关）；服务经验 17 家次；平均放款周期约 5 个工作日
- 优势领域：科技金融、投贷联动、离岸跨境、园区服务

### 北京银行（匹配度 38.2）
- 匹配依据：优势领域命中 1 项（1 项与需求领域相关）；服务经验 11 家次；平均放款周期约 4 个工作日
- 优势领域：数据资产、专精特新、科技金融、普惠金融

## 组合融资建议

- 可考虑"信贷 + 贴息"组合，具体以机构审批与政策兑现为准。

## 风险提示

- 融资可行性、利率与放款以金融机构独立审批为准。
- 产品额度/利率为公开资料区间，实际以合同条款为准。

## 对接路径

1. 企业与匹配机构联系人对接，提交对接材料包；
2. 机构审核资料并出具初步方案；
3. 双方洽谈细节并签约落地。

## 合规声明

> 本方案由金融匹配智能体自动生成，仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。
', 'finance-plan', 'completed', 'normal', c.id, '["beichen", "finance-plan"]'::jsonb, '{"case_id": "FC-20260829-5033BE", "amount": "500万", "purpose": "研发投入", "partners": ["光大银行", "浦发银行", "北京银行"]}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '融资方案 - 北京北辰实业有限公司' AND t.deleted_at IS NULL);

INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT 'c28eb84b-d63b-4303-87fe-c55f922093c6', '资料提交与审核 - 北京北辰实业有限公司', 'SOP 阶段 1：资料提交与审核。责任人：待分配。截止：2026-08-31', 'finance-service', 'completed', 'normal', c.id, '["beichen", "finance-service"]'::jsonb, '{"case_id": "FC-20260829-5033BE", "sop_stage": 1, "due_date": "2026-08-31", "owner": ""}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '资料提交与审核 - 北京北辰实业有限公司' AND t.deleted_at IS NULL);

INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '9b0e28bd-981d-44fa-8d68-7b6a4d0d2085', '方案制定与洽谈 - 北京北辰实业有限公司', 'SOP 阶段 2：方案制定与洽谈。责任人：张工。截止：2026-08-31', 'finance-service', 'in-progress', 'normal', c.id, '["beichen", "finance-service"]'::jsonb, '{"case_id": "FC-20260829-5033BE", "sop_stage": 2, "due_date": "2026-08-31", "owner": "张工"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京北辰实业有限公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '方案制定与洽谈 - 北京北辰实业有限公司' AND t.deleted_at IS NULL);
