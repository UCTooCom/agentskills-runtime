# 智能投研助理参赛作品技术设计文档

> **文档定位**：本文档为 2026 昇腾 x AtomGit「金融行业应用 Agent 黑客松」参赛作品《智能投研助理》的技术设计文档（design.md），定义"怎么做"。
>
> **比赛**：金融行业应用 Agent 黑客松 | **版本**：v1.0 | **日期**：2026-08-07

---

# 一、总体架构设计

## 1.1 架构图

```
┌────────────────────────────────────────────────────────────────────┐
│                    用户（投研用户 / 评审专家）                        │
│         输入目标公司列表 → 获取每日投资简报                          │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
┌──────────────────────────────▼─────────────────────────────────────┐
│              AgentSkills Runtime（仓颉 Runtime）                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │      智能投研助理 Skill（investment-research-assistant）       │  │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  │  │
│  │  │ 1.抓取  │→│ 2.清洗  │→│ 3.提取  │→│ 4.生成  │→│ 5.落库  │  │  │
│  │  │ fetch  │ │ clean  │ │ extract│ │ report │ │persist │  │  │
│  │  └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘  │  │
│  │      │           │          │          │          │        │  │
│  │  ┌───▼───────┐   │          │          │     ┌────▼────┐   │  │
│  │  │scripts/*.py│  │          │          │     │company/ │   │  │
│  │  └───────────┘   │          │          │     │tasks 表 │   │  │
│  └──────────────────┼──────────┼──────────┼─────┼─────────┼───┘  │
│                     │          │          │     │         │      │
│  内置工具: web_fetch/http_request/firecrawl/cli_execute          │
│  大模型: 昇腾 API（AtomGit，OpenAI 兼容）                         │
└─────────────────────┼──────────┼──────────┼─────┼─────────┼──────┘
                      │          │          │     │         │
              ┌───────▼──┐  ┌────▼───┐ ┌────▼──┐ │   ┌──────▼─────┐
              │ 公开数据源 │  │raw/    │ │clean/ │ │   │ aibuilder   │
              │ 行情/公告/ │  │factors/│ │brief/ │ │   │ (web-admin) │
              │ 新闻      │  │ 输出    │ │ 输出   │ │   │ 研报呈现     │
              └──────────┘  └────────┘ └───────┘ │   └────────────┘
                                                  │
                                          ┌───────▼──────┐
                                          │ PostgreSQL    │
                                          │ company/tasks │
                                          └──────────────┘
```

## 1.2 技术选型

| 层级 | 选型 | 说明 |
|------|------|------|
| 技能运行时 | AgentSkills Runtime（仓颉） | 技能执行环境、内置工具、权限体系 |
| 技能格式 | SKILL.md + scripts | 符合 AgentSkills 开放标准 |
| 脚本语言 | Python 3 | 抓取/清洗/提取/落库轻量脚本 |
| 大模型 | 昇腾 API（AtomGit） | OpenAI 兼容接口，`.env` 配置 |
| 数据库 | PostgreSQL | company / tasks 表（复用现有） |
| 呈现 | aibuilder（web-admin） | company 列表 + tasks 研报详情 |

---

# 二、Skill 目录结构设计

```
skills/investment-research-assistant/
├── SKILL.md                    # 技能定义（SOP 主文档）
├── COMPOSITION.yaml            # 组合步骤编排（抓取→清洗→提取→生成→落库→简报）
└── scripts/
    ├── fetch_market_data.py    # Step1 自动抓取（行情接口多源）
    ├── clean_market_data.py    # Step2 数据清洗（去重/格式统一/剔除无效）
    ├── extract_factors.py      # Step3 要素提取（行情/事件/情绪/风险）
    ├── generate_report.py      # Step4 研报生成（昇腾 API / 模板降级）
    └── save_report_to_db.py    # Step5 结果落库（company upsert + tasks 插入）
```

## 2.1 输出目录约定

```
output/
├── raw/       # 抓取原始 JSON（{date}.json）
├── clean/     # 清洗后 JSON
├── factors/   # 要素 JSON
├── brief/     # 每日投资简报 Markdown（{date}.md）
└── sql/       # 落库 SQL（可选直连）
```

---

# 三、模块设计

## 3.1 fetch_market_data.py（抓取）

**输入**：`--companies "600519,000858"`、`--date`、`--outdir`
**逻辑**：
1. 解析公司列表（代码/名称）
2. 调用公开行情接口（东方财富 push2 公开接口，合规）
3. 输出 `output/raw/{date}.json`（含 quotes/news/来源/抓取时间）

**关键实现**：`resolve_codes()` 代码归一化、`fetch_quote()` 行情抓取、限流休眠。

## 3.2 clean_market_data.py（清洗）

**输入**：raw JSON
**逻辑**：
1. 数值归一化（东财原始值 /100）
2. 按标题去重
3. 剔除无代码/无价格的无效记录
4. 输出 `output/clean/{date}.json`

## 3.3 extract_factors.py（要素提取）

**输入**：clean JSON
**逻辑**：
1. 行情要素：收盘价、涨跌幅、PE/PB、市值
2. 情绪要素：涨跌幅映射 positive/neutral/negative
3. 风险提示：波动率、高估值、负面情绪、数据缺失
4. 输出 `output/factors/{date}.json`

## 3.4 generate_report.py（研报生成）

**输入**：factors JSON
**逻辑**：
1. 检测 LLM 配置（`LLM_API_KEY`/`OPENAI_API_KEY`）
2. 有配置：调用昇腾 API（OpenAI 兼容 `/chat/completions`）生成简报
3. 无配置：模板降级生成（行情概览+核心看点+风险提示+免责声明）
4. 输出 `output/brief/{date}.md`

## 3.5 save_report_to_db.py（落库）

**输入**：简报 Markdown + factors JSON
**逻辑**：
1. `split_report_by_company()` 按公司拆分简报
2. `build_company_upsert_sql()`：company 表按 company_name upsert
3. `build_task_insert_sql()`：tasks 表插入研报（task_type='research'，关联 company_id）
4. 支持直连（psycopg2）或仅生成 SQL 文件
5. 输出 SQL 文件，可选写库

---

# 四、大模型接入设计（昇腾算力底座）

## 4.1 配置方式

修改 runtime `.env`：

```env
# AtomGit（昇腾 API）模型配置
MODEL_PROVIDER=atomgit
MODEL_NAME=deepseek-v4-flash
MODEL_CONFIG=atomgit:deepseek-v4-flash
ATOMGIT_API_KEY=<token>
ATOMGIT_BASE_URL=https://api-ai.gitcode.com/v1
```

参考 `.env.example` 完整配置。

## 4.2 脚本侧 LLM 调用

`generate_report.py` 环境变量：

```env
LLM_BASE_URL=https://api-ai.gitcode.com/v1
LLM_API_KEY=<token>
LLM_MODEL=deepseek-v4-flash
```

> 注：脚本侧 LLM 为可选增强；正式运行时由 runtime 大模型服务（昇腾 API）完成研报生成，符合"昇腾 API 算力底座"要求。

---

# 五、数据库落库设计

## 5.1 company 表 upsert

```sql
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified)
VALUES ('{name}', '中国', '{摘要}', 'investment-research', false)
ON CONFLICT (company_name) DO UPDATE SET org_description = EXCLUDED.org_description;
```

> 注：company 表以 company_name 为业务去重键（需确认唯一约束；若无唯一索引，脚本可先 SELECT 再 UPDATE/INSERT）。

## 5.2 tasks 表插入

```sql
INSERT INTO public.tasks
  (id, title, description, task_type, task_status, priority, company_id, tags, extra_data)
SELECT '{uuid}', '每日投资简报 - {name}', '{研报正文}', 'research', 'completed', 'normal',
       c.id, '["investment-research","daily-brief"]'::jsonb, '{"report_date":"{date}"}'::jsonb
FROM public.company c WHERE c.company_name = '{name}';
```

---

# 六、合规与安全设计

1. **数据合规**：仅抓取公开行情接口（东方财富公开数据），记录来源与时间
2. **内容合规**：简报固定附加"仅供技术交流，不构成投资建议"免责声明
3. **权限安全**：脚本仅访问白名单数据源与本地数据库；高敏感操作需确认
4. **审计留痕**：抓取、生成、落库全流程可追溯（output 目录持久化）
5. **信创合规**：仓颉 Runtime + 昇腾算力 + 国产数据库，全链路国产自主可控

---

# 七、风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 公开接口限流/变更 | 抓取失败 | 多源数据、失败重试、模板降级 |
| Python 依赖缺失 | 脚本不可运行 | scripts 仅依赖标准库+requests（可选），无依赖降级路径 |
| 无 LLM 配置 | 简报质量下降 | 模板降级生成（保证可运行） |
| company 表无唯一约束 | upsert 冲突 | 脚本提供先查后更的兼容路径 |
| 接口数据字段变化 | 解析异常 | try/except 容错，异常记录不中断 |

---

# 八、验收检查清单

- [x] SKILL.md 符合 AgentSkills 标准格式
- [x] COMPOSITION.yaml 定义六步编排
- [x] 5 个 Python 脚本齐全且语法正确
- [x] 落库逻辑复用 company / tasks 表结构
- [x] 支持昇腾 API（AtomGit）配置
- [x] 简报含合规免责声明
- [ ] runtime 加载技能成功（人工验证）
- [ ] 端到端执行成功（人工验证）
- [ ] aibuilder 呈现研报（人工验证）
