-- 智能投研助理落库 SQL
-- 生成时间: 2026-08-15T11:31:05.930069

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '贵州茅台' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '贵州茅台', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '贵州茅台' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT 'd9a86dca-a309-42fd-b62e-e9101359f11a', '每日投资简报 - 贵州茅台', '# 每日投资简报 - 贵州茅台

## 行情概览
- 收盘价: 1341.99  涨跌幅: -0.98%
- PE: None  PB: None  总市值: None
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-08-15", "code": "600519"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '贵州茅台' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 贵州茅台' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '宁德时代' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '宁德时代', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '宁德时代' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '44ebcc01-0f1a-4595-8a65-82616a9060f0', '每日投资简报 - 宁德时代', '# 每日投资简报 - 宁德时代

## 行情概览
- 收盘价: 393.93  涨跌幅: -0.6%
- PE: None  PB: None  总市值: None
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-08-15", "code": "300750"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '宁德时代' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 宁德时代' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '比亚迪' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '比亚迪', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '比亚迪' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '720c6265-2c17-4185-9ab3-284d181b87e2', '每日投资简报 - 比亚迪', '# 每日投资简报 - 比亚迪

## 行情概览
- 收盘价: 88.9  涨跌幅: -0.9%
- PE: None  PB: None  总市值: None
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-08-15", "code": "002594"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '比亚迪' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 比亚迪' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '五 粮 液' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '五 粮 液', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '五 粮 液' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '3550245d-508b-4e10-b7f4-207176bbeab4', '每日投资简报 - 五 粮 液', '# 每日投资简报 - 五 粮 液

## 行情概览
- 收盘价: 73.75  涨跌幅: -1.82%
- PE: None  PB: None  总市值: None
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-08-15", "code": "000858"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '五 粮 液' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 五 粮 液' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '中芯国际' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '中芯国际', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '中芯国际' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT 'bb2691c2-160a-4cfa-b4ec-9f163ff9a7f3', '每日投资简报 - 中芯国际', '# 每日投资简报 - 中芯国际

## 行情概览
- 收盘价: 132.87  涨跌幅: 2.65%
- PE: None  PB: None  总市值: None
- 情绪: positive

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

> 生成时间: 2026-08-15
', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-08-15", "code": "688981"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '中芯国际' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 中芯国际' AND t.deleted_at IS NULL);
