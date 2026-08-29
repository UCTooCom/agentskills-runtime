---
name: beichen-policy-assistant
description: 产业政策智能体（北辰产业政策智能体）—— 实现北辰命题"政策赋能精准化"课题的政策库—匹配库—申报库全流程 SOP。输入企业名称自动生成全景企业画像（工商/经营/舆情），基于三层知识库（政策原文库/官方解读库/实操洞察库）与全网实时资源双源检索，语义级匹配市、区两级政策，生成可溯源的适配研判报告，创建申报任务，结果写入 company 表与 tasks 表并通过 aibuilder 呈现。触发词："政策匹配"、"政策申报"、"企业画像"、"政策智能体"、"能申报什么政策"、"产业政策"、"专项政策"、"政策查询"、"申报条件"。
license: MIT
version: "1.0.0"
compatibility: 需要 runtime 内置工具支持（cli_execute/file_read/file_write/http_request/web_fetch/web_search），脚本执行需 Python 3.8+ + requests 库（落库模式需 psycopg2-binary）
metadata:
  author: UCToo Team (beichen-hackathon)
  version: "1.0.0"
  category: policy
  tags: ["beichen", "policy", "enterprise-profile", "policy-matching", "政策", "申报"]
allowed-tools: network, filesystem, cli
---

# 产业政策智能体（北辰产业政策智能体）

## 概述

本技能实现北辰产业云社区命题"政策赋能精准化"课题的最佳实践 SOP：
**企业画像 → 政策检索 → 政策匹配 → 报告生成 → 申报任务 → 结果落库**，
并配套 **知识库初始化** 与 **政策库自动更新** 两个能力。

- 数据来源：公开工商/经营/舆情信息 + 三层政策知识库 + 政府公开网站（合规抓取）
- 输出形态：结构化企业画像、政策匹配矩阵、适配研判报告、申报任务
- 落库方式：企业画像写入 `company` 表，匹配报告与申报任务写入关联的 `tasks` 表（复用 aibuilder 呈现）
- 算力底座：昇腾 AI（AtomGit 昇腾 API）——通过 runtime `.env` 配置大模型提供商即可

## 核心设计：三层知识库根除幻觉

通用大模型在政策场景存在信息滞后 / 理解肤浅 / 逻辑失真三大困境，本技能通过三层知识库彻底解决：

| 层 | 目录 | 作用 |
|----|------|------|
| 政策原文库 | `knowledge/policy-original/` | 市、区两级政策全文，信息源头真实完整 |
| 官方解读库 | `knowledge/policy-interpretation/` | 权威问答与解读，锚定官方口径 |
| 实操洞察库 | `knowledge/policy-insight/` | 申报流程要点、常见退回原因、隐性规则 |

**硬性要求**：所有匹配结论必须引用政策原文库条目编号（`policy_no`），无出处的匹配结果一律标记为"待核实"，不进入正式报告。

## 全流程 SOP

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│ 0.初始化  │ → │ 1.画像   │ → │ 2.匹配   │ → │ 3.报告   │ → │ 4.申报   │ → │ 5.落库   │
│ init     │   │ profile │   │ match   │   │ report  │   │ apply   │   │ persist │
└─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘
        （另含 6.政策库自动更新 update_policy_kb，供每日 cron 触发）
```

### Step 0：知识库初始化（Init）

以命题附件 74 条政策目录为种子，生成三层知识库结构。

**脚本**：`scripts/init_policy_kb.py`
```bash
cli_execute({"command": "python", "args": ["scripts/init_policy_kb.py", "--seed", "knowledge/policy-seed.json"]})
# 输出：knowledge/policy-original/{序号}-{政策名称}.md（74 条）+ knowledge/policy-index.json
```

### Step 1：全景企业画像（Profile）

输入企业名称，聚合工商、经营、舆情多渠道公开信息，经信息甄别、冗余过滤、要点萃取，输出结构化企业画像。

**脚本**：`scripts/build_enterprise_profile.py`
```bash
cli_execute({"command": "python", "args": ["scripts/build_enterprise_profile.py", "--company", "北京北辰实业有限公司"]})
# 输出：output/profiles/{企业slug}.json + .md
```
- 未配置 LLM 时用规则降级完成要点萃取，保证可运行

### Step 2：多元政策匹配（Match）

基于企业画像语义匹配三层知识库与全网实时资源，输出匹配矩阵。

**脚本**：`scripts/match_policy.py`
```bash
cli_execute({"command": "python", "args": ["scripts/match_policy.py", "--profile", "output/profiles/{企业slug}.json", "--topn", "10"]})
# 输出：output/matches/{企业slug}-{date}.json（匹配矩阵：政策编号/评分/依据/缺口项）
```
- 硬性条件初筛（注册区域/资质/行业）→ 双源检索 → 语义评分 → policy_no 绑定

### Step 3：适配研判报告（Report）

调用昇腾 API 生成结构化适配研判报告，无 LLM 时模板降级。

**脚本**：`scripts/generate_policy_report.py`
```bash
cli_execute({"command": "python", "args": ["scripts/generate_policy_report.py", "--profile", "output/profiles/{企业slug}.json", "--matches", "output/matches/{企业slug}-{date}.json"]})
# 输出：output/reports/{企业slug}-{date}.md（含条件对标表、缺口分析、合规声明）
```

### Step 4：申报任务（Apply）

为 Top N 匹配政策生成申报任务（含材料清单与截止时间），写入匹配矩阵 meta 供落库使用。

### Step 5：结果落库（Persist）

企业画像 upsert 到 `company` 表，匹配报告与申报任务写入 `tasks` 表。

**脚本**：`scripts/save_to_db.py`
```bash
cli_execute({"command": "python", "args": ["scripts/save_to_db.py", "--profile", "output/profiles/{企业slug}.json", "--report", "output/reports/{企业slug}-{date}.md", "--matches", "output/matches/{企业slug}-{date}.json", "--sql-only"]})
# 输出：output/sql/policy_*.sql（company upsert + tasks 写入 policy-match / policy-apply）
```

### Step 6：政策库自动更新（Auto-Update）

每日定时从政府网站抓取最新政策进入储备库，人工研判确认后转入正式库。

**脚本**：`scripts/update_policy_kb.py`
```bash
# 抓取模式（每日 cron 触发）
cli_execute({"command": "python", "args": ["scripts/update_policy_kb.py", "--sources", "default"]})
# 输出：output/pending/{date}.json（状态 pending，待人工研判）

# commit 模式（人工研判确认后）
cli_execute({"command": "python", "args": ["scripts/update_policy_kb.py", "--commit", "--date", "2026-08-29", "--reviewer", "张工"]})
# 效果：储备库中被确认条目转入政策原文库，索引状态更新
```

## 脚本执行显式命令示例（即使不读完整 SOP 也可直接执行）

> 工作目录：`apps/agentskills-runtime/skills/beichen-policy-assistant`；Windows 用 `python`，Linux/Mac 用 `python3`。

```bash
# 0. 初始化知识库
python scripts/init_policy_kb.py --seed knowledge/policy-seed.json

# 1. 企业画像
python scripts/build_enterprise_profile.py --company "北京北辰实业有限公司"

# 2. 政策匹配
python scripts/match_policy.py --profile output/profiles/beijing_beichen_shiyeyouxiangongsi.json --topn 10

# 3. 适配报告
python scripts/generate_policy_report.py --profile output/profiles/beijing_beichen_shiyeyouxiangongsi.json --matches output/matches/beijing_beichen_shiyeyouxiangongsi-2026-08-29.json

# 4. 结果落库（仅生成 SQL 文件，无需数据库驱动）
python scripts/save_to_db.py --profile output/profiles/beijing_beichen_shiyeyouxiangongsi.json --report output/reports/beijing_beichen_shiyeyouxiangongsi-2026-08-29.md --matches output/matches/beijing_beichen_shiyeyouxiangongsi-2026-08-29.json --sql-only
```

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `company` | string | 画像/匹配/报告时必填 | 目标企业名称（支持批量，逗号分隔） |
| `topn` | int | 否 | 匹配/申报 Top N（默认 10） |
| `policy_no` | string | 否 | 指定政策编号（单政策查询） |
| `reviewer` | string | commit 时必填 | 研判人（政策更新 commit 留痕） |
| `mode` | string | 否 | update 模式：默认抓取 / `commit` 研判入库 |
| `sql_only` | bool | 否 | 落库仅生成 SQL 文件（默认 true） |

**输入验证**：`company` 为空时脚本报错退出（`sys.exit(1)`）；`topn` 非正数时回退默认值；commit 缺 `reviewer` 时拒绝执行。

## 错误处理与降级策略

- **工商接口不可用**：画像降级为 web_search 采集 + 字段留空标记"待补充"
- **LLM 不可用**：匹配用规则打分、报告用模板生成，均不中断流程
- **数据库连接失败**：save_to_db.py 支持 `--sql-only` 生成 SQL 文件
- **政府网站反爬**：update_policy_kb.py 多源重试 + 指数退避，失败记录 error 字段不中断
- **编码错误**：cli_execute stdout 编码失败时按"遇挫不停"原则换 web_search / web_fetch 采集

## 输出

| 输出 | 路径/位置 | 说明 |
|------|----------|------|
| 三层知识库 | `knowledge/` | 政策原文库/官方解读库/实操洞察库 + 索引 |
| 企业画像 | `output/profiles/` | 结构化画像 JSON + Markdown |
| 匹配矩阵 | `output/matches/` | 企业 × 政策匹配矩阵 JSON |
| 适配报告 | `output/reports/` | 适配研判报告 Markdown |
| 储备流水 | `output/pending/` | 政策自动更新待研判流水 |
| 落库 | company / tasks 表 | aibuilder 可呈现（企业/报告/申报任务） |

## 安全与合规

- **数据合规**：仅抓取政府公开网站与公开工商/舆情信息，记录来源与抓取时间
- **人工研判门禁**：储备库 → 正式库必须人工 commit（`--reviewer` 留痕）
- **内容合规**：报告固定附加"仅供申报参考，不构成法律意见"声明
- **权限安全**：脚本仅访问白名单数据源与本地数据库
- **信创合规**：仓颉 Runtime + 昇腾算力 + 国产数据库
- **审计留痕**：画像、匹配、更新、落库全流程产物持久化于 output/

## 严禁事项

- 严禁抓取未授权数据（付费接口、反爬站点、企业隐私数据）
- 严禁输出无溯源的政策匹配结论（幻觉治理硬性要求）
- 严禁伪造政策来源与匹配依据
- 严禁绕过人工研判门禁直接提交正式库

## 参考文档

- 内置工具：`apps/agentskills-runtime/docs/builtin-tools.md`
- 数据库结构：`apps/agentskills-runtime/sql/uctooDB.sql`（company / tasks 表）
- 技能开发：`apps/agentskills-runtime/docs/uctoo-v4/uctoo-v4-module-development.md`