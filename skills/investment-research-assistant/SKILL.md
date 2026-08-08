---
name: investment-research-assistant
description: 智能投研助理（Investment Research Assistant）—— 实现金融行业"自动抓取、清洗、提取，输出每日投资简报"全流程最佳实践 SOP。自动抓取行情/公告/新闻等多源数据，清洗去重，提取关键投资要素（估值、财务、事件、情绪），生成结构化每日投资简报并按公司写入 company 表、研报内容写入关联 tasks 表，通过 aibuilder 模块呈现。触发词："投研"、"投资简报"、"研报"、"每日投资简报"、"股票分析"、"Investment Research"。
license: MIT
metadata:
  author: UCToo Team
  version: "1.0.0"
  category: fintech
  tags: ["fintech", "investment", "research", "daily-briefing", "投研", "投资简报"]
allowed-tools: network, filesystem, cli
---

# 智能投研助理（Investment Research Assistant）

## 概述

本技能实现金融行业 Agent 核心场景"**智能投研助理**"的最佳实践 SOP：
**自动抓取 → 数据清洗 → 要素提取 → 研报生成 → 结果落库 → 每日投资简报**。

- 数据来源：公开行情接口、公告、财经新闻等（合规抓取）
- 输出形态：结构化每日投资简报（Markdown/JSON）
- 落库方式：按公司写入 `company` 表，研报内容写入关联的 `tasks` 表（复用 aibuilder 呈现）
- 算力底座：昇腾 AI（AtomGit 昇腾 API）——通过 runtime `.env` 配置大模型提供商即可

## 全流程 SOP

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│ 1. 抓取  │ → │ 2. 清洗  │ → │ 3. 提取  │ → │ 4. 生成  │ → │ 5. 落库  │ → │ 6. 简报  │
│ fetch   │   │ clean   │   │ extract │   │ report  │   │ persist │   │ brief   │
└─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

### Step 1：自动抓取（Fetch）

抓取当日目标公司（行业/指数成分股/自选池）的多源数据：

| 数据源 | 内容 | 推荐工具 |
|--------|------|---------|
| 行情接口 | 收盘价、涨跌幅、成交量、市盈率等 | `web_fetch` / `http_request` / `scripts/fetch_market_data.py` |
| 公司公告 | 定期报告、重大事项 | `web_fetch` / `firecrawl` |
| 财经新闻 | 行业动态、公司新闻 | `web_fetch` / `firecrawl` |
| 宏观数据 | 利率、PMI、CPI 等 | `web_fetch` / `http_request` |

**最佳实践**：
- 优先使用官方/公开合规数据源（交易所、公司官网、权威财经门户）
- 数据源数量 ≥ 3，避免单一来源偏差
- 记录数据来源与抓取时间（合规留痕）

### Step 2：数据清洗（Clean）

对抓取到的原始数据进行清洗：

- 去重（按标题/代码/发布时间去重）
- 去除广告、噪声、无关内容
- 统一格式（日期、单位、数字精度）
- 剔除停牌、退市、异常行情等无效数据
- 空值/异常值处理并标记

**脚本**：`scripts/clean_market_data.py`（输入原始 JSON，输出清洗后 JSON）

### Step 3：要素提取（Extract）

从清洗后数据中提取结构化投资要素：

| 要素 | 说明 |
|------|------|
| 行情指标 | 收盘价、涨跌幅、PE/PB、成交量、市值 |
| 财务指标 | 营收、净利润、毛利率、ROE（如有财报） |
| 事件要素 | 业绩预告、分红、回购、并购、监管 |
| 情绪要素 | 新闻情感倾向（正面/中性/负面） |
| 风险提示 | 高波动、负面事件、合规风险 |

**脚本**：`scripts/extract_factors.py`（输出要素 JSON）

### Step 4：研报生成（Report）

调用大模型（昇腾 API / AtomGit）基于提取要素生成结构化投资简报：

```
每日投资简报 - {公司名称}（{代码}）
├── 一句话结论（目标价区间/评级倾向）
├── 行情概览（涨跌幅、成交、估值）
├── 核心看点（2-3 条）
├── 风险提示（2-3 条）
└── 数据来源与免责声明
```

**注意**：简报仅作技术交流，不构成投资建议（合规要求）。

### Step 5：结果落库（Persist）

将研报写入数据库（复用现有 `company` + `tasks` 表，供 aibuilder 呈现）：

- 公司信息 upsert 到 `company` 表（company_name、region、website、org_description 等）
- 研报内容写入关联 `tasks` 表（title、description、task_type='research'、company_id、creator_id、tags、extra_data）

**脚本**：`scripts/save_report_to_db.py`（支持 psycopg2 直连或生成 SQL 文件）

### Step 6：每日简报输出（Brief）

- 汇总全部目标公司的简报为《每日投资简报》（Markdown）
- 保存到 `output/` 目录
- 通过 aibuilder 模块呈现（company 列表 + tasks 研报详情）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `companies` | string | 是 | 目标公司列表，如 "600519,000858" 或 "贵州茅台,五粮液" |
| `date` | string | 否 | 简报日期（默认当天，格式 YYYY-MM-DD） |
| `data_sources` | string | 否 | 数据源配置（默认行情+公告+新闻） |
| `output_dir` | string | 否 | 简报输出目录（默认 `output/`） |

## 输出

| 输出 | 路径/位置 | 说明 |
|------|----------|------|
| 原始数据 | `output/raw/` | 抓取原始 JSON |
| 清洗数据 | `output/clean/` | 清洗后 JSON |
| 要素数据 | `output/factors/` | 提取要素 JSON |
| 投资简报 | `output/brief/` | 每日投资简报 Markdown |
| 数据库落库 | company / tasks 表 | aibuilder 可呈现 |

## 使用示例

```bash
# 通过 skill 执行（runtime 内置工具调用）
skill run investment-research-assistant:generate-daily-brief companies="600519,000858"

# 或直接运行脚本（需要 python3 + requests）
python3 scripts/fetch_market_data.py --companies "600519,000858"
python3 scripts/clean_market_data.py --input output/raw/2026-08-07.json
python3 scripts/extract_factors.py --input output/clean/2026-08-07.json
python3 scripts/save_report_to_db.py --report output/brief/2026-08-07.md
```

## 复用产品体系能力

本技能最大化复用 AgentSkills Runtime 产品体系已有能力：

| 能力 | 复用方式 |
|------|---------|
| 内置工具 `web_fetch`/`http_request`/`firecrawl` | 数据抓取（Step 1） |
| 内置工具 `cli_execute` | 运行 scripts 脚本 |
| 大模型服务（昇腾 API / AtomGit） | 研报生成（Step 4） |
| `company`/`tasks` 表 + aibuilder 模块 | 研报呈现（Step 5/6） |
| RBAC 权限体系 / 审计日志 | 安全合规 |
| 信创 / 国产自主可控技术栈 | 金融合规要求 |

## 安全与合规

- **数据合规**：仅使用公开、已授权数据源；记录来源与抓取时间
- **内容合规**：简报标注"仅供技术交流，不构成投资建议"
- **权限安全**：脚本仅访问白名单数据源与本地数据库
- **信创合规**：全链路国产技术栈（仓颉 Runtime + 昇腾算力 + 国产数据库）
- **审计留痕**：抓取、生成、落库全流程记录审计日志

## 严禁事项

- 严禁抓取未授权数据（付费接口、反爬站点、个人隐私数据）
- 严禁输出误导性投资建议
- 严禁伪造数据来源
- 严禁绕过权限体系直接执行高敏感操作

## 参考文档

- 内置工具：`docs/builtin-tools.md`
- 技能开发：`docs/skill-development.md`
- 数据库结构：`sql/public20260730.sql`（company / tasks 表）
- AgentSkills 规范：`docs/standard/`
