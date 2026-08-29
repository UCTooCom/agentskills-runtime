---
name: beichen-finance-matching
description: 金融匹配智能体（北辰金融匹配智能体）—— 实现北辰命题"金融服务体系化"课题的产业金融服务 SOP 全流程线上化，解决企业"融资难、对接繁、流程慢"痛点。采集企业融资需求并初步审核，基于金融工具数据库（90+ 金融伙伴与产品）智能匹配优势金融机构，生成定制融资方案与对接材料包，按北辰金融 SOP 六阶段时效（1d/1d/2d/3-5d/约定时限/长期）跟踪进度与超期提醒，结果写入 company 表与 tasks 表并通过 aibuilder 呈现。触发词："融资匹配"、"金融服务"、"融资需求"、"贷款对接"、"金融方案"、"机构匹配"、"融资智能体"。
license: MIT
version: "1.0.0"
compatibility: 需要 runtime 内置工具支持（cli_execute/file_read/file_write/http_request/web_fetch/web_search），脚本执行需 Python 3.8+ + requests 库（落库模式需 psycopg2-binary）
metadata:
  author: UCToo Team (beichen-hackathon)
  version: "1.0.0"
  category: fintech
  tags: ["beichen", "fintech", "financing", "matching", "SOP", "融资", "金融"]
allowed-tools: network, filesystem, cli
---

# 金融匹配智能体（北辰金融匹配智能体）

## 概述

本技能实现北辰产业云社区命题"金融服务体系化"课题的最佳实践 SOP：
**需求建档 → 机构匹配 → 方案生成 → 材料包 → SOP 跟踪 → 结果落库**，
并配套 **金融工具数据库初始化** 能力。

- 数据来源：金融伙伴目录（90+ 家：银行/证券/基金/投资公司）+ 公开金融产品资料
- 输出形态：融资需求档案、匹配矩阵、定制金融方案、对接材料包、SOP 六阶段进度流水
- 落库方式：企业写入 `company` 表，融资方案与服务任务写入 `tasks` 表（复用 aibuilder 呈现）
- 算力底座：昇腾 AI（AtomGit 昇腾 API）——通过 runtime `.env` 配置大模型提供商即可

## 核心设计：北辰金融 SOP 时效承诺内建

北辰产业金融 SOP 六阶段时效承诺作为流程元数据内建，每个服务任务自动计算阶段截止时间，超期自动标记：

| 阶段 | 名称 | 时效承诺 |
|------|------|---------|
| 1 | 资料提交与审核 | 1 个工作日 |
| 2 | 方案制定与洽谈 | 1 个工作日 |
| 3 | 金融机构对接 | 2 个工作日 |
| 4 | 落地执行 | 3-5 个工作日 |
| 5 | 服务闭环 | 约定时限 |
| 6 | 长期维护 | 定期回访 |

## 全流程 SOP

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│ 0.初始化  │ → │ 1.建档   │ → │ 2.匹配   │ → │ 3.方案   │ → │ 4.材料包 │ → │ 5.跟踪   │
│ init     │   │ intake  │   │ match   │   │ plan    │   │ dossier │   │ track   │
└─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘
                                                            （第 6 步 落库 persist）
```

### Step 0：金融工具数据库初始化（Init）

以金融伙伴目录种子（64 银行/12 证券/9 基金/6 投资骨架，演示环境可用真实示例机构）生成金融工具数据库。

**脚本**：`scripts/init_finance_kb.py`
```bash
cli_execute({"command": "python", "args": ["scripts/init_finance_kb.py", "--seed", "knowledge/finance-seed.json"]})
# 输出：knowledge/finance-partners/*.json + knowledge/finance-index.json
```

### Step 1：融资需求采集与初步审核（Intake，SOP 阶段一）

结构化采集企业融资需求，完整性校验 + 可行性初判，生成 case_id。

**脚本**：`scripts/collect_financing_need.py`
```bash
cli_execute({"command": "python", "args": ["scripts/collect_financing_need.py", "--company", "北京北辰实业有限公司", "--amount", "500万", "--purpose", "研发投入", "--guarantee", "信用"]})
# 输出：output/needs/{case_id}.json（状态 intaked，阶段一截止 = 1 个工作日）
```

### Step 2：需求匹配优势金融机构（Match）

硬性初筛（额度/期限/担保对标产品要素）+ 优势匹配打分，输出 Top N 匹配矩阵。

**脚本**：`scripts/match_finance.py`
```bash
cli_execute({"command": "python", "args": ["scripts/match_finance.py", "--need", "output/needs/{case_id}.json", "--topn", "3"]})
# 输出：output/matches/{case_id}.json（机构/产品/评分构成/依据）
```

### Step 3：定制金融方案（Plan，SOP 阶段二)

调用昇腾 API 生成备选机构方案对比表，无 LLM 时模板降级。

**脚本**：`scripts/generate_finance_plan.py`
```bash
cli_execute({"command": "python", "args": ["scripts/generate_finance_plan.py", "--need", "output/needs/{case_id}.json", "--matches", "output/matches/{case_id}.json"]})
# 输出：output/plans/{case_id}.md（对比表 + 适配理由 + 风险提示 + 合规声明）
```

### Step 4：对接材料包（Dossier，SOP 阶段三）

按机构类型生成标准材料清单 + 预填信息 + 缺失项标注。

**脚本**：`scripts/build_dossier.py`
```bash
cli_execute({"command": "python", "args": ["scripts/build_dossier.py", "--need", "output/needs/{case_id}.json", "--partner", "光大银行"]})
# 输出：output/dossiers/{case_id}-光大银行.md
```

### Step 5：SOP 六阶段跟踪（Track）

阶段推进、超期扫描、回访提醒。

**脚本**：`scripts/track_service.py`
```bash
# 阶段推进
cli_execute({"command": "python", "args": ["scripts/track_service.py", "--case", "{case_id}", "--advance", "--owner", "张工"]})
# 超期扫描
cli_execute({"command": "python", "args": ["scripts/track_service.py", "--check"]})
# 回访任务
cli_execute({"command": "python", "args": ["scripts/track_service.py", "--case", "{case_id}", "--review"]})
```

### Step 6：结果落库（Persist）

企业 upsert 到 `company` 表，融资方案与服务任务写入 `tasks` 表。

**脚本**：`scripts/save_to_db.py`
```bash
cli_execute({"command": "python", "args": ["scripts/save_to_db.py", "--need", "output/needs/{case_id}.json", "--plan", "output/plans/{case_id}.md", "--tracking", "output/tracking/{case_id}.json", "--sql-only"]})
# 输出：output/sql/finance_*.sql（company upsert + tasks 写入 finance-plan / finance-service）
```

## 脚本执行显式命令示例

> 工作目录：`apps/agentskills-runtime/skills/beichen-finance-matching`；Windows 用 `python`，Linux/Mac 用 `python3`。

```bash
# 0. 初始化金融工具数据库
python scripts/init_finance_kb.py --seed knowledge/finance-seed.json

# 1. 需求建档（SOP 阶段一）
python scripts/collect_financing_need.py --company "北京北辰实业有限公司" --amount "500万" --term "2年" --purpose "研发投入" --guarantee "信用"

# 2. 机构匹配
python scripts/match_finance.py --need output/needs/{case_id}.json --topn 3

# 3. 方案生成
python scripts/generate_finance_plan.py --need output/needs/{case_id}.json --matches output/matches/{case_id}.json

# 4. 对接材料包
python scripts/build_dossier.py --need output/needs/{case_id}.json --partner "光大银行"

# 5. SOP 跟踪
python scripts/track_service.py --case {case_id} --advance --owner "张工"

# 6. 落库
python scripts/save_to_db.py --need output/needs/{case_id}.json --plan output/plans/{case_id}.md --tracking output/tracking/{case_id}.json --sql-only
```

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `company` | string | 是 | 企业名称 |
| `amount` | string | 是 | 融资金额（如"500万"） |
| `purpose` | string | 是 | 融资用途（流动资金/研发投入/设备采购/股权融资） |
| `term` | string | 否 | 融资期限（如"2年"） |
| `guarantee` | string | 否 | 可接受担保方式（信用/抵押/质押/保证） |
| `revenue` | string | 否 | 营收概况（粗粒度） |
| `topn` | int | 否 | 匹配 Top N（默认 3） |
| `case_id` | string | 跟踪时必填 | 服务单号 |
| `owner` | string | 阶段推进时填 | 责任人 |
| `partner` | string | 材料包必填 | 目标机构名 |

**输入验证**：`company`/`amount`/`purpose` 缺失时脚本报错退出（`sys.exit(1)`）；金额/期限自动归一化为数字+单位。

## 错误处理与降级策略

- **LLM 不可用**：匹配用规则打分、方案用模板生成，均不中断流程
- **数据库连接失败**：save_to_db.py 支持 `--sql-only` 生成 SQL 文件
- **伙伴库产品要素不全**：匹配以优势领域 + 服务经验先验降级打分
- **编码错误**：cli_execute stdout 编码失败时按"遇挫不停"原则继续

## 输出

| 输出 | 路径/位置 | 说明 |
|------|----------|------|
| 金融工具数据库 | `knowledge/` | 金融伙伴库/产品要素库/服务经验库 + 索引 |
| 融资需求档案 | `output/needs/` | 结构化需求 JSON |
| 匹配矩阵 | `output/matches/` | 需求 × 机构/产品匹配矩阵 |
| 融资方案 | `output/plans/` | 定制融资方案 Markdown |
| 对接材料包 | `output/dossiers/` | 材料清单 + 预填信息 |
| 服务跟踪流水 | `output/tracking/` | SOP 六阶段进度 + 超期标记 |
| 落库 | company / tasks 表 | aibuilder 可呈现（企业/方案/进度） |

## 安全与合规

- **数据合规**：仅使用命题目录与公开产品资料；服务经验案例脱敏后入库
- **内容合规**：方案固定附加"仅供融资决策参考，不构成投资建议，最终以金融机构审批为准"声明
- **权限安全**：财务信息属敏感数据，脚本仅本地处理与白名单数据库；RBAC 控制呈现权限
- **审计留痕**：需求、匹配、方案、材料包、跟踪全流程产物持久化于 output/
- **信创合规**：仓颉 Runtime + 昇腾算力 + 国产数据库

## 严禁事项

- 严禁使用非公开金融数据与未授权接口
- 严禁输出确定性投资建议（融资可行性以金融机构审批为准）
- 严禁伪造机构匹配依据与产品要素
- 严禁绕过权限体系访问企业财务敏感信息

## 参考文档

- 内置工具：`apps/agentskills-runtime/docs/builtin-tools.md`
- 数据库结构：`apps/agentskills-runtime/sql/uctooDB.sql`（company / tasks 表）
- 技能开发：`apps/agentskills-runtime/docs/uctoo-v4/uctoo-v4-module-development.md`