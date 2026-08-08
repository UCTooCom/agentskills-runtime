# 智能投研助理参赛作品需求规格文档

> **文档定位**：本文档为 2026 昇腾 x AtomGit「金融行业应用 Agent 黑客松」参赛作品《智能投研助理》的正式需求规格文档（spec.md），定义"做什么"。
>
> **比赛**：金融行业应用 Agent 黑客松（昇腾 x AtomGit AI 社区）
> **赛题**：智能投研助理 —— 自动抓取、清洗、提取，输出每日投资简报
> **版本**：v1.0 | **日期**：2026-08-07
> **提交截止**：2026-08-08 晚 24 点（线上初审投稿截止）

---

# **1. 组件定位**

## **1.1 核心职责**

本参赛作品《智能投研助理》是运行在 AgentSkills Runtime 上的一个金融行业 Agent 技能（Skill），实现赛题要求的"**自动抓取、清洗、提取，输出每日投资简报**"全流程最佳实践 SOP：

1. **自动抓取**：通过 runtime 内置网络工具（web_fetch / http_request / firecrawl）和 scripts 脚本，从公开合规数据源抓取目标公司（行情、公告、新闻、宏观）多源数据
2. **数据清洗**：去重、格式统一、无效数据剔除，产出结构化清洗数据
3. **要素提取**：从清洗数据中提取投资要素（行情指标、事件、情绪、风险提示）
4. **研报生成**：调用大模型（昇腾 API / AtomGit）生成结构化每日投资简报
5. **结果落库**：按公司写入 `company` 表，研报内容写入关联 `tasks` 表，复用 aibuilder 模块呈现
6. **简报输出**：汇总生成《每日投资简报》并持久化

## **1.2 核心输入**

1. **目标公司列表**：用户指定的公司代码/名称（如 `600519,000858`）
2. **简报日期**：生成简报的日期（默认当天）
3. **多源数据**：公开行情接口、公告、财经新闻等（合规抓取）
4. **大模型服务**：昇腾 AI 算力底座（AtomGit 昇腾 API，OpenAI 兼容接口）
5. **数据库**：runtime 连接的 PostgreSQL 数据库（company / tasks 表）

## **1.3 核心输出**

1. **原始数据**：抓取的多源原始 JSON（`output/raw/`）
2. **清洗数据**：结构化清洗数据（`output/clean/`）
3. **要素数据**：投资要素 JSON（`output/factors/`）
4. **投资简报**：每日投资简报 Markdown（`output/brief/`）
5. **落库 SQL / 数据库记录**：company 表 upsert + tasks 表研报记录（aibuilder 可呈现）
6. **演示能力**：录屏视频（放在 README 中）+ 可运行代码

## **1.4 职责边界**

本作品**不负责**以下事项：

- **不开发仓颉程序**：本次参赛只开发 Skill，不做 runtime 仓颉代码修改
- **不做数据库结构变更**：复用现有 company / tasks 表结构
- **不提供投资建议**：简报仅作技术交流，不构成投资建议（合规要求）
- **不抓取未授权数据**：仅使用公开、合规数据源

---

# **2. 顶层设计原则**

## **2.1 原则 1：最大化复用产品体系已有能力**

| 产品能力 | 复用方式 |
|---------|---------|
| AgentSkills Runtime | 技能运行环境、内置工具（web_fetch/http_request/firecrawl/cli_execute） |
| 大模型服务 | 昇腾 API（AtomGit），通过 `.env` 配置切换 |
| company / tasks 表 + aibuilder | 研报呈现模块 |
| RBAC 权限体系 + 审计日志 | 安全合规 |
| PC 客户端 / web-admin | 产品化呈现 |

## **2.2 原则 2：金融合规与安全第一**

- 数据来源合规（仅公开数据）、内容合规（免责声明）、权限安全（白名单）、审计留痕

## **2.3 原则 3：全链路国产自主可控**

- 仓颉 Runtime + 昇腾算力（NPU/API）+ 国产数据库，满足金融行业信创要求

---

# **3. 领域术语**

**智能投研助理（Investment Research Assistant）**
: 实现"自动抓取、清洗、提取，输出每日投资简报"全流程的 Agent 技能（Skill），本次参赛作品核心交付物。

**AgentSkills**
: 开放标准技能格式（SKILL.md），runtime 加载执行的技能单元。

**SOP**
: 标准作业流程（Standard Operating Procedure），本技能定义了抓取→清洗→提取→生成→落库→简报的六步流程。

**aibuilder**
: runtime 中的 AI Builder 模块（web-admin 前端），呈现 company 列表与 tasks 研报详情。

**昇腾 AI 算力底座**
: 比赛硬性要求 —— 使用昇腾 NPU 或昇腾 API。本作品通过 AtomGit 昇腾 API（OpenAI 兼容接口）接入。

**company 表**
: 公司信息表（company_name、region、website、org_description 等），研报按公司输出至此。

**tasks 表**
: 任务/研报内容表（title、description、task_type、company_id 等），研报正文写入 description。

---

# **4. 角色与边界**

## **4.1 核心角色**

- **金融投研用户**：输入目标公司列表，获取每日投资简报
- **Agent 智能体**：自动执行抓取→清洗→提取→生成→落库全流程
- **评审专家**：检验作品可运行性、业务闭环、技术创新性

## **4.2 外部系统**

- **AgentSkills Runtime**：技能运行环境，提供内置工具与大模型调用
- **昇腾 API（AtomGit）**：大模型算力底座
- **PostgreSQL**：company / tasks 表存储
- **公开数据源**：行情接口、公告、新闻（合规抓取）

---

# **5. 核心能力**

## **5.1 自动抓取（Fetch）**

- 支持输入公司代码/名称列表
- 通过内置工具或 `scripts/fetch_market_data.py` 抓取行情、公告、新闻
- 记录数据来源与抓取时间（合规留痕）

## **5.2 数据清洗（Clean）**

- 去重（标题/代码/时间）、格式统一、无效数据剔除
- 通过 `scripts/clean_market_data.py` 实现

## **5.3 要素提取（Extract）**

- 提取行情指标（收盘价、涨跌幅、PE/PB、市值）、事件、情绪、风险提示
- 通过 `scripts/extract_factors.py` 实现

## **5.4 研报生成（Report）**

- 调用大模型（昇腾 API / AtomGit）生成结构化简报
- 未配置 LLM 时降级为模板生成
- 通过 `scripts/generate_report.py` 实现

## **5.5 结果落库（Persist）**

- company 表 upsert（按 company_name 去重）
- tasks 表插入研报（task_type='research'，关联 company_id）
- 通过 `scripts/save_report_to_db.py` 实现（支持直连或生成 SQL）

## **5.6 简报输出与呈现（Brief）**

- 汇总生成《每日投资简报》Markdown
- 通过 aibuilder 模块呈现（company 列表 + tasks 研报）

---

# **6. 数据约束**

## **6.1 company 表（复用现有结构）**

| 字段 | 说明 |
|------|------|
| company_name | 公司名称（upsert 去重键） |
| region | 公司所在地 |
| org_description | 投资简报摘要 |
| org_type | 'investment-research' |
| is_verified | false |

## **6.2 tasks 表（复用现有结构）**

| 字段 | 说明 |
|------|------|
| title | 每日投资简报 - {公司名称} |
| description | 研报正文（Markdown） |
| task_type | 'research' |
| task_status | 'completed' |
| company_id | 关联 company 表 id |
| tags | ['investment-research','daily-brief'] |
| extra_data | report_date、code |

---

# **7. 参赛要求对照**

| 比赛要求 | 本作品满足方式 |
|---------|--------------|
| 金融场景 | 智能投研助理（投研场景） |
| 必须能跑 | Skill + scripts 可运行，无需 PPT/mockup |
| 解决真问题 | 自动抓取、清洗、提取、简报全流程闭环 |
| 昇腾 AI 算力底座 | `.env` 配置 AtomGit 昇腾 API（OpenAI 兼容） |
| 原创性 | 全部自研 Skill + 脚本，参考开源但严禁抄袭 |
| 技术文档 | 本文档 + design.md + tasks.md + README |

---

# **8. 验收标准**

| 编号 | 场景 | 预期结果 |
|------|------|---------|
| AC-01 | 安装 skill 到 runtime | runtime 可加载 investment-research-assistant 技能 |
| AC-02 | 输入公司列表执行 | 自动完成抓取→清洗→提取→生成→落库全流程 |
| AC-03 | 检查原始数据 | output/raw 生成原始 JSON |
| AC-04 | 检查清洗数据 | output/clean 生成清洗后 JSON，无效数据剔除 |
| AC-05 | 检查要素数据 | output/factors 生成投资要素 JSON |
| AC-06 | 检查简报 | output/brief 生成每日投资简报 Markdown |
| AC-07 | 检查落库 | company 表 upsert、tasks 表插入研报记录 |
| AC-08 | aibuilder 呈现 | web-admin aibuilder 可见公司列表与研报详情 |
| AC-09 | 昇腾算力 | .env 配置 AtomGit 昇腾 API 后大模型调用正常 |
| AC-10 | 合规 | 简报含"不构成投资建议"免责声明 |
