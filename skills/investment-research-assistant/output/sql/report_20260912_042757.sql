-- 智能投研助理落库 SQL
-- 生成时间: 2026-09-12T04:27:57.745476

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '贵州茅台' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '贵州茅台', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '贵州茅台' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT 'eabbc465-9587-456a-a9c4-61822b34fd38', '每日投资简报 - 贵州茅台', '# 每日投资简报 - 贵州茅台

## 行情概览
- 收盘价: 1275.16  涨跌幅: -0.78%
- PE: None  PB: None  总市值: None
- 情绪: neutral

## 核心看点
- 当日事件/新闻数量: 0 条

## 风险提示
- 当日未获取到有效公告/新闻数据，信息覆盖有限

## 数据来源与免责声明
> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。

---

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-12", "code": "600519"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '贵州茅台' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 贵州茅台' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '宁德时代' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '宁德时代', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '宁德时代' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '4454ac50-a15b-4bce-99da-02e57bee2c93', '每日投资简报 - 宁德时代', '# 每日投资简报 - 宁德时代

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

', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-12", "code": "300750"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '宁德时代' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 宁德时代' AND t.deleted_at IS NULL);

UPDATE public.company SET org_description = '', updated_at = CURRENT_TIMESTAMP WHERE company_name = '比亚迪' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '比亚迪', '中国', '', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '比亚迪' AND deleted_at IS NULL);
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '0ca2d724-467f-4b8f-bf6c-cc8eaa4d764a', '每日投资简报 - 比亚迪', '# 每日投资简报 - 比亚迪

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

> 生成时间: 2026-09-12
', 'research', 'completed', 'normal', c.id, '["investment-research", "daily-brief"]'::jsonb, '{"report_date": "2026-09-12", "code": "002594"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '比亚迪' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '每日投资简报 - 比亚迪' AND t.deleted_at IS NULL);
