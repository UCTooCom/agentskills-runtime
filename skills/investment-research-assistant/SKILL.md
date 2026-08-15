---
name: investment-research-assistant
description: 智能投研助理（Investment Research Assistant）—— 实现金融行业"自动抓取、清洗、提取，输出每日投资简报"全流程最佳实践 SOP。自动抓取行情/公告/新闻等多源数据，清洗去重，提取关键投资要素（估值、财务、事件、情绪），生成结构化每日投资简报并按公司写入 company 表、研报内容写入关联 tasks 表，通过 aibuilder 模块呈现。触发词："投研"、"投资简报"、"研报"、"每日投资简报"、"股票分析"、"Investment Research"、"热点公司"、"行情"、"A股"、"复盘"、"盘后分析"、"市场资讯"、"估值分析"、"公司基本面"、"财报"、"盘前盘后"。
license: MIT
version: "1.1.0"
compatibility: 需要 runtime 内置工具支持（cli_execute/file_read/file_write/http_request/web_fetch），脚本执行需 Python 3.8+ + requests 库（落库模式需 psycopg2-binary）
metadata:
  author: UCToo Team
  version: "1.1.0"
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

| 数据源 | 内容 | 优先工具 |
|--------|------|---------|
| 行情接口 | 收盘价、涨跌幅、成交量、市盈率等 | `scripts/fetch_market_data.py`（已含东财接口、名称解析、合规留痕） |
| 公司公告 | 定期报告、重大事项 | `scripts/fetch_market_data.py`（含公告字段）或降级 `web_fetch` / `http_request` |
| 财经新闻 | 行业动态、公司新闻 | `scripts/fetch_market_data.py`（含新闻字段）或降级 `web_fetch` / `http_request` |
| 宏观数据 | 利率、PMI、CPI 等 | 降级 `web_fetch` / `http_request`（脚不含宏观数据源） |

**工具优先级**（必须遵守）：
1. **优先用 `cli_execute` 运行 `scripts/fetch_market_data.py`**——人工已验证脚本可正确生成预期产出物（`output/raw/{date}.json`）
2. 仅在检测到系统环境不具备运行脚本时（如 python 未安装、requests 缺失、cli_execute 不可用）才降级用 `web_fetch` / `http_request` 收集数据
3. 降级时仍需按脚本的字段结构产出 `output/raw/{date}.json`，保证下游 Step2 可衔接

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
- **优先用 `cli_execute` 运行此脚本**——人工已验证可正确生成预期产出物（`output/clean/{date}.json`）
- 仅在检测到系统环境不具备运行脚本时才降级用 `file_read` + 大模型手动清洗（产出需保持同字段结构以衔接下游 Step3）

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
- **优先用 `cli_execute` 运行此脚本**——人工已验证可正确生成预期产出物（`output/factors/{date}.json`）
- 仅在检测到系统环境不具备运行脚本时才降级用大模型从清洗 JSON 中提取要素（产出需保持同字段结构以衔接下游 Step4）

### Step 4：研报生成（Report）

调用大模型（昇腾 API / AtomGit）基于提取要素生成结构化投资简报：

```
每日投资简报 - {公司名称}（{代码})
├── 一句话结论（目标价区间/评级倾向）
├── 行情概览（涨跌幅、成交、估值）
├── 核心看点（2-3 条）
├── 风险提示（2-3 条）
└── 数据来源与免责声明
```

**脚本**：`scripts/generate_report.py`（输入要素 JSON，输出投资简报 Markdown）
- **优先用 `cli_execute` 运行此脚本**——人工已验证可正确生成预期产出物（`output/brief/{date}.md`）
- 已配置 `LLM_API_KEY` 时脚本内部调用昇腾 API / AtomGit OpenAI 兼容接口生成
- 未配置 LLM 时脚本内部降级为基于要素的模板化简报（不中断流程）
- 仅在检测到系统环境不具备运行脚本时才降级用 runtime 大模型直接生成（需保持同产出结构以衔接下游 Step5）

**注意**：简报仅作技术交流，不构成投资建议（合规要求）。

### Step 5：结果落库（Persist）

将研报写入数据库（复用现有 `company` + `tasks` 表，供 aibuilder 呈现）：

- 公司信息 upsert 到 `company` 表（company_name、region、website、org_description 等）
- 研报内容写入关联 `tasks` 表（title、description、task_type='research'、company_id、creator_id、tags、extra_data）

**脚本**：`scripts/save_report_to_db.py`（支持 psycopg2 直连或生成 SQL 文件）
- **优先用 `cli_execute` 运行此脚本**——人工已验证可正确生成预期产出物（`output/sql/report_*.sql` 或直连 DB 写入）
- `--sql-only` 模式仅生成 SQL 文件（无需 psycopg2），人工导入数据库即可
- 直连模式需 `DATABASE_URL` 环境变量 + psycopg2（未安装时脚本自动降级为 `--sql-only`）
- 仅在检测到系统环境不具备运行脚本时才降级用 runtime 数据库 CRUD API 直接写入 company/tasks 表

### Step 6：每日简报输出（Brief）

- 汇总全部目标公司的简报为《每日投资简报》（Markdown）
- 保存到 `output/` 目录
- 通过 aibuilder 模块呈现（company 列表 + tasks 研报详情）

## 脚本执行显式命令示例（v10 新增，即使不读完整 SOP 也可直接执行）

> **重要**：agent 即使因 file_read 编码问题未读到完整 SOP，也可直接按本段命令执行六步全流程。命令中的日期 `2026-08-12` 需替换为用户要求的日期。

```bash
# Step 1：抓取行情（必填 --companies，支持代码或名称；--force 覆盖旧产出避免误判已完成）
cli_execute({"command": "python", "args": ["scripts/fetch_market_data.py", "--companies", "600519,000858,300750", "--date", "2026-08-12", "--force"]})
# 输出: output/raw/2026-08-12.json

# Step 2：清洗数据
cli_execute({"command": "python", "args": ["scripts/clean_market_data.py", "--input", "output/raw/2026-08-12.json"]})
# 输出: output/clean/2026-08-12.json

# Step 3：提取要素
cli_execute({"command": "python", "args": ["scripts/extract_factors.py", "--input", "output/clean/2026-08-12.json"]})
# 输出: output/factors/2026-08-12.json

# Step 4：生成研报
cli_execute({"command": "python", "args": ["scripts/generate_report.py", "--factors", "output/factors/2026-08-12.json"]})
# 输出: output/brief/2026-08-12.md

# Step 5：落库（仅生成 SQL 文件，无需数据库驱动）
cli_execute({"command": "python", "args": ["scripts/save_report_to_db.py", "--report", "output/brief/2026-08-12.md", "--factors", "output/factors/2026-08-12.json", "--sql-only"]})
# 输出: output/sql/report_20260812_HHMMSS.sql
```

**工作目录**：`apps/agentskills-runtime/skills/investment-research-assistant`（脚本相对路径基于此目录）
**Windows 用 `python`，Linux/Mac 用 `python3`**

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `companies` | string | 是 | 目标公司列表，如 "600519,000858" 或 "贵州茅台,五粮液"（名称自动调东财搜索 API 解析为代码） |
| `date` | string | 否 | 简报日期（默认当天，格式 YYYY-MM-DD） |
| `data_sources` | string | 否 | 数据源配置（默认行情+公告+新闻） |
| `output_dir` | string | 否 | 简报输出目录（默认 `output/`） |

**输入验证**：
- `companies` 必填，空值或纯分隔符时脚本报错退出（`sys.exit(1)`）
- 6 位数字代码自动补齐（如 "519" → "000519"），非数字名称调东财搜索 API 解析
- 代码格式非法（含字母/长度异常）时东财接口返回空数据，clean 步骤会剔除无效行情并记录
- `date` 非今日时抓取历史快照（东财接口支持），非交易日返回上一交易日数据

## 错误处理与降级策略

- **数据源失败**：单个数据源抓取失败时记录 error 字段，不中断其他公司抓取；agent 按"遇挫不停"原则尝试替代数据源
- **LLM 不可用**：`generate_report.py` 检测 `LLM_API_KEY` 未配置时自动降级为模板化简报，不中断流程
- **数据库连接失败**：`save_report_to_db.py` 支持 `--sql-only` 模式仅生成 SQL 文件，无 psycopg2 时打印警告并降级
- **编码错误**：`cli_execute` 的 stdout 编码失败时返回替换后的字符串（非空），agent 按"stdout 解码失败替代方案清单"尝试其他路径
- **部分公司失败**：研报按公司独立生成，单家公司失败不影响其他公司输出

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

# 或直接运行脚本（需 python + requests；Windows 用 python，Linux/Mac 用 python3）
# Windows: pip install requests psycopg2-binary
# Linux/Mac: pip3 install requests psycopg2-binary
python scripts/fetch_market_data.py --companies "600519,000858"
python scripts/clean_market_data.py --input output/raw/2026-08-07.json
python scripts/extract_factors.py --input output/clean/2026-08-07.json
python scripts/generate_report.py --factors output/factors/2026-08-07.json
python scripts/save_report_to_db.py --report output/brief/2026-08-07.md --factors output/factors/2026-08-07.json --sql-only
```

## 复用产品体系能力

本技能最大化复用 AgentSkills Runtime 产品体系已有能力：

| 能力 | 复用方式 |
|------|---------|
| 内置工具 `web_fetch`/`http_request` | 数据抓取（Step 1） |
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

- 内置工具：`apps/agentskills-runtime/docs/builtin-tools.md`（runtime 根目录的 docs）
- 技能开发：`apps/agentskills-runtime/docs/uctoo-v4/uctoo-v4-module-development.md`
- 数据库结构：`apps/agentskills-runtime/sql/uctooDB.sql`（company / tasks 表）
- AgentSkills 规范：`apps/agentskills-runtime/docs/uctoo-v4/`

## 任务完成判定（必须遵守，v9 新增）

> **核心原则**：不能因目录有旧研报文件就误判任务已完成——这是 v9 实测中 agent 的典型错误行为。

### 必查项

1. **日期匹配**：必须检查产出文件的日期是否匹配用户要求。用户要 `2026-08-10` 投研时，`output/brief/2026-08-11.md`（旧研报）**不算完成**——只有 `output/brief/2026-08-10.md` 存在且内容为本次生成才算完成。
2. **实际执行 SOP**：必须实际执行六步 SOP 并确认每步的产出文件存在且内容为本次生成，不能只看目录有文件就误判。
3. **内容校验**：打开 `output/brief/{用户要求日期}.md` 检查内容是否包含本次抓取的数据（如收盘价、涨跌幅等具体数值），非空文件且非旧内容才算完成。
4. **旧文件忽略**：如发现目录有旧日期的研报文件，应忽略（非本次产出），继续执行 SOP 直至生成用户要求日期的研报。

### 错误行为示例（v9 实测根因，严禁复现）

```
用户：请生成昨日（2026.08.10）3家热点公司投研
agent：[执行 dir /s /b 发现 output/brief/2026-08-11.md]
agent：[误判] "已使用 investment-research-assistant 技能生成昨日（2026-08-10）3家热点公司投研简报"
agent：[直接返回 answer 停止]  ← 错误！实际 SOP 全步并未真正执行
```

### 正确行为示例

```
用户：请生成昨日（2026.08.10）3家热点公司投研
agent：[执行 dir /s /b 发现 output/brief/2026-08-11.md（旧研报，日期不匹配）]
agent：[忽略旧文件] "目录有 2026-08-11 旧研报，但用户要 2026-08-10，需重新执行 SOP"
agent：[执行 fetch → clean → extract → generate → archive 六步 SOP，用 date=2026-08-10]
agent：[校验 output/brief/2026-08-10.md 存在且内容含本次抓取的数据]
agent：[返回 answer 报告 3 家公司的具体投研分析]  ← 正确！
```

## 旧产出清理（建议，v9 新增）

- 运行 SOP 前可清理 `output/` 目录下的旧文件，避免误判
- 或用 `fetch_market_data.py --force` 覆盖旧产出文件（`--force` 参数会覆盖同日期的旧 JSON）
- 清理命令示例：`file_write` 删除 `output/brief/{旧日期}.md`，或 `cli_execute` 运行 `rm output/brief/*.md` 后重新生成

## 遇挫不停重试指令（v17 新增，P0）

> **背景**：v17 实测中，agent 在第 3 步 `extract_factors.py` 因 `output/factors` 目录不存在（cwd 不一致）失败后，直接总结"未最终交付"返回 answer 停止——未自动重试或换方案。本轮已将脚本 `--outdir` 改为绝对路径根治，但 SOP 中仍需显式重试指令防止 agent 遇挫即停。

### 必须遵守的重试规则

1. **任何 SOP 步骤失败时，必须先重试一次**（同一命令再跑一次，确认是否偶发），重试仍失败才换方案
2. **重试仍失败时，必须尝试替代方案**（如脚本失败 → 降级 `web_fetch` 抓数据 → 手工整理），不可直接返回 answer 停止
3. **替代方案也失败时，必须在 answer 中明确报告"尝试了 X 次重试和 Y 种替代方案均失败"**，并给出下一步建议（而非只说"失败"就停）
4. **严禁遇挫即停**：未实际尝试重试和替代方案就返回 answer 停止，是 v17 实测根因，本轮起列为错误行为示例

### 错误行为示例（v17 实测根因，严禁复现）

```
agent：[执行 extract_factors.py 报 FileNotFoundError: output/factors/2026-08-13.json]
agent：[误判] "第 3 步失败，未最终交付，需要修复 factors 输出路径后重跑"
agent：[直接返回 answer 停止]  ← 错误！未重试、未换方案、未尝试绝对路径 --outdir 参数
```

### 正确行为示例

```
agent：[执行 extract_factors.py 报 FileNotFoundError]
agent：[重试 1] 同一命令再跑一次，确认是否偶发——仍失败
agent：[换方案] 用 --outdir 显式传绝对路径再跑：cli_execute({"command":"python","args":["scripts/extract_factors.py","--input","output/clean/2026-08-13.json","--outdir","<绝对路径>/output/factors"]})
agent：[校验 output/factors/2026-08-13.json 存在]  ← 成功！继续第 4 步
agent：[执行 generate_report.py → save_report_to_db.py 直至交付]
agent：[返回 answer 报告 3 家公司的具体投研分析]  ← 正确！
```

## --outdir 参数说明（v17 新增）

- 本轮起 `extract_factors.py`、`generate_report.py`、`save_report_to_db.py` 的 `--outdir` 默认值已改为基于脚本所在目录的绝对路径，不再依赖 cwd
- agent 调用 `cli_execute` 时**无需显式传 --outdir**，默认值已正确指向 `{技能目录}/output/{子目录}`
- 如遇默认值仍失败，可显式传 `--outdir` 绝对路径兜底（参考上文正确行为示例）

## SOP 全步完成强制约束（v17 新增，P0）

> **背景**：v17 实测中，agent 在完成 Step 1-3（fetch/clean/extract）后，直接进入 answer 总结阶段，跳过 Step 4（generate_report.py）和 Step 5（save_report_to_db.py），导致 `output/brief/` 和 `output/sql/` 缺失当日产出物。agent 在 reasoning 中自认"数据已足够"而提前终止——这是错误行为。

### 必须遵守的规则

1. **禁止提前终止**：必须依次执行 Step 1 → Step 2 → Step 3 → Step 4 → Step 5 全部脚本，不得在任何中间步骤后直接跳到 answer 总结
2. **产出文件校验**：每步执行后必须用 `file_read` 或 `cli_execute` 校验产出文件存在且非空：
   - Step 1 后：`output/raw/{date}.json` 存在
   - Step 2 后：`output/clean/{date}.json` 存在
   - Step 3 后：`output/factors/{date}.json` 存在
   - Step 4 后：`output/brief/{date}.md` 存在且非空
   - Step 5 后：`output/sql/report_{date}_*.sql` 存在且非空
3. **缺则补执行**：如校验发现某步产出缺失，必须立即补执行该步脚本，不得跳过
4. **answer 前终检**：生成最终 answer 前，必须确认 `output/brief/{date}.md` 和 `output/sql/report_{date}_*.sql` 均已存在，否则继续执行缺失步骤

### 错误行为示例（v17 实测根因，严禁复现）

```
agent：[执行 Step 1 fetch → Step 2 clean → Step 3 extract，全部成功]
agent：[误判] "数据已足够，直接总结研报"
agent：[跳过 Step 4/5，直接返回 answer]  ← 错误！output/brief/ 和 output/sql/ 缺失
```

### 正确行为示例

```
agent：[执行 Step 1 → Step 2 → Step 3，全部成功]
agent：[继续执行 Step 4] cli_execute({"command":"python","args":["scripts/generate_report.py","--factors","output/factors/{date}.json"]})
agent：[校验 output/brief/{date}.md 存在且非空]  ← 成功
agent：[继续执行 Step 5] cli_execute({"command":"python","args":["scripts/save_report_to_db.py","--report","output/brief/{date}.md","--factors","output/factors/{date}.json","--sql-only"]})
agent：[校验 output/sql/report_{date}_*.sql 存在且非空]  ← 成功
agent：[返回 answer 报告 3 家公司的具体投研分析]  ← 正确！全部产出物已生成
```
