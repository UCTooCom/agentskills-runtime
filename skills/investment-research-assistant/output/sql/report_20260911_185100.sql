-- 智能投研助理落库 SQL
-- 生成时间: 2026-09-11T18:51:00.369572

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '贵州茅台' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '贵州茅台', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '贵州茅台' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT 'f211fbc2-28f1-4837-bc02-26f37387b066', '每日投资简报 - 贵州茅台', '# 每日投资简报 - 贵州茅台

## 行情概览
- 收盘价: 1275.16  涨跌幅: -0.78%
- PE: 17.9  PB: 6.34  总市值: 15940.5405
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-11", "code": "600519"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '贵州茅台' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 贵州茅台' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '五 粮 液' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '五 粮 液', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '五 粮 液' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '220d6276-b2bb-41c8-aa87-da9e3d3eaed9', '每日投资简报 - 五 粮 液', '# 每日投资简报 - 五 粮 液

## 行情概览
- 收盘价: 69.75  涨跌幅: -1.04%
- PE: 15.47  PB: 2.29  总市值: 2707.4216
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-11", "code": "000858"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '五 粮 液' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 五 粮 液' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '宁德时代' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '宁德时代', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '宁德时代' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT 'f0461fc1-c9cb-48f9-8660-48c4a90f981f', '每日投资简报 - 宁德时代', '# 每日投资简报 - 宁德时代

## 行情概览
- 收盘价: 330.51  涨跌幅: -2.23%
- PE: None  PB: None  总市值: None
- 情绪: negative

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日市场情绪偏负面
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-11", "code": "300750"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '宁德时代' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 宁德时代' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '比亚迪' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '比亚迪', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '比亚迪' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '845e00a6-f43a-43ad-b755-217ba3530041', '每日投资简报 - 比亚迪', '# 每日投资简报 - 比亚迪

## 行情概览
- 收盘价: 84.0  涨跌幅: 0.57%
- PE: None  PB: None  总市值: None
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-11", "code": "002594"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '比亚迪' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 比亚迪' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '中国平安' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '中国平安', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '中国平安' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '091850ee-81a4-46d9-a41d-d12b1afa9dcf', '每日投资简报 - 中国平安', '# 每日投资简报 - 中国平安

## 行情概览
- 收盘价: 54.83  涨跌幅: -1.24%
- PE: None  PB: None  总市值: None
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

> 生成时间: 2026-09-11
', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-11", "code": "601318"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '中国平安' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 中国平安' AND t.deleted_at IS NULL);
