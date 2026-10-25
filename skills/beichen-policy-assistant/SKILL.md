---
name: beichen-policy-assistant
description: 产业政策智能体（北辰产业政策智能体）—— 实现北辰命题"政策赋能精准化"课题的政策库—匹配库—申报库全流程 SOP。支持两类入口：① 主题/产业方向检索（不给企业名，直接检索近期可申报的产业政策，带可信度四因子与原文库交叉验证）；② 给定企业名称做全景画像→政策匹配→研判报告→申报任务→落库。触发词："政策匹配"、"政策申报"、"企业画像"、"政策智能体"、"能申报什么政策"、"产业政策"、"专项政策"、"政策查询"、"申报条件"、"检索产业政策"、"近期可申报"。关联检索内核 yuanbao-search（skills/yuanbao-search/）。
license: MIT
version: "1.0.0"
compatibility: 需要 runtime 内置工具 cli_execute（在 runtime 根目录执行子进程）。脚本优先使用 TypeScript 版本（需 Node.js v23.10.0+，原生支持 TypeScript：`node --experimental-strip-types`）；TS 版本运行有错误时降级使用 Python 版本（需 Python 3.8+ + requests 库）。
metadata:
  author: UCToo Team (beichen-hackathon)
  version: "1.0.0"
  category: policy
  tags: ["beichen", "policy", "enterprise-profile", "policy-matching", "政策", "申报"]
allowed-tools: network, filesystem, cli
---

# 产业政策智能体（北辰产业政策智能体）

## ⚠️ 执行方式红线（务必先看，否则一定"卡住"）

1. **用 `cli_execute` 直接跑脚本文件**，不要调用 `yuanbao-search` / `yuanbao-policy` 这两个"技能工具"。
   - 它们作为技能工具被调用时只返回一句占位状态字符串（"`Skill xxx executed with arguments...`"），**不返回任何检索/匹配结果**，这会导致你误以为"调了元宝但没进展"。
   - 真正干活的是 `skills/yuanbao-search/scripts/yuanbao_search.ts` 这个脚本文件，必须通过 `cli_execute` 执行。
2. **`cli_execute` 的子进程永远在 runtime 根目录运行**，所有脚本路径必须是**相对于 runtime 根目录**的绝对层级路径，**必须以 `skills/...` 开头**：
   - 本技能脚本：`skills/beichen-policy-assistant/scripts/<脚本>.ts`
   - 检索内核脚本：`skills/yuanbao-search/scripts/yuanbao_search.ts`
   - ❌ 错误写法（会报 can't open file）：`scripts/xxx.ts`、`init_policy_kb.ts`、`yuanbao_search.ts`
3. `cli_execute` 的 `args` 传 **JSON 数组字符串**，例如：
   `"args": "[\"--experimental-strip-types\",\"skills/yuanbao-search/scripts/yuanbao_search.ts\",\"--query\",\"...\"]"`

---

## 入口判断（先定走哪条路）

- **场景 A · 主题/产业方向检索（用户没给具体企业名）** → 直接走下方【场景 A】，**不要索取企业名**，立即检索并出清单。
  例："检索我近期可以申报的产业政策"、"专精特新 有哪些申报政策"、"高精尖产业资金 申报条件"。
- **场景 B · 给定企业名称做全流程** → 走下方【场景 B】：画像 → 匹配 → 报告 → 落库。

> 用户原话含"检索/查询/有哪些/什么政策/可申报"且**未出现企业全称**时，一律按场景 A 处理，禁止反问企业名。

---

## 场景 A · 主题/产业方向检索（当前主用路径）

**目标**：按用户给的产业方向/政策主题，检索近期可申报的产业政策，输出带可信度四因子的线索清单。

**第 1 步：直接调用 `cli_execute` 运行检索内核**（不要先问企业名）：

```json
{
  "command": "node",
  "args": "[\"--experimental-strip-types\", \"skills/yuanbao-search/scripts/yuanbao_search.ts\", \"--query\", \"<把用户主题组织成检索词，如：专精特新 中小企业 申报 条件>\", \"--industry\", \"gov\", \"--cnt\", \"20\", \"--freshness\", \"1y\", \"--json\"]"
}
```

- `--freshness 1y` 表示近一年；用户说"近期/今年"可用 `"2026-01-01,2026-12-31"`。
- `--cnt` 收敛到 {10,20,30,40,50}，默认 50；演示取 20 即可。
- `--json` 让脚本输出单行 JSON（stdout），诊断信息走 stderr，互不污染。

**第 2 步：解析 stdout 里的单行 JSON**，关键字段：
- `items[]`：`title` / `url` / `date` / `passage` / `credibility.status`（可采信｜待核实）/ `policyNo`（命中原文库的政策编号）/ `scoreNorm`。
- `stats`：`returned`（返回数）/ `credible`（可采信数）/ `excluded`（待核实数）。
- `excluded[]`：未过门禁的条目，必须**如实列出并说明原因**（这是"敢说不知道"的对外证据，不得隐瞒）。

**第 3 步：向用户呈现结果**，固定结构：
1. 一句话结论（命中多少条可采信、适用范围北京政策原文库 74 条）。
2. 可采信清单（表格）：序号｜政策/线索标题｜来源(.gov.cn 优先)｜发布日期｜可信度｜原文库编号(policyNo)｜要点 passage。
3. 待核实清单（excluded）：每条标注"未命中原文库 / 信源最低 / 已过期"等具体原因。
4. 合规声明："以上线索仅供申报参考，不构成法律意见；建议在正式申报前以主管部门最新发布为准。"
5. 若用户想进一步做"企业级匹配"，再询问企业全称，转入场景 B。

> 检索内核会自动与 `skills/beichen-policy-assistant/knowledge/policy-index.json`（北京 74 条政策原文库）做交叉验证；命中的条目会带 `policyNo`，未命中的标"未在本地政策原文库备案，需人工复核"，二者都可采信（官方发布页 URL 本身就是可核验出处）。

---

## 场景 B · 企业全流程（给定企业名称）

> 脚本路径一律带 `skills/beichen-policy-assistant/scripts/` 前缀。

### Step 0：知识库初始化（Init，首次或库变更时跑）

```json
{ "command": "node", "args": "[\"--experimental-strip-types\", \"skills/beichen-policy-assistant/scripts/init_policy_kb.ts\", \"--seed\", \"skills/beichen-policy-assistant/knowledge/policy-seed.json\"]" }
```
输出：`knowledge/policy-original/{序号}-{政策名称}.md`（74 条）+ `knowledge/policy-index.json`。

### Step 1：全景企业画像（Profile）

```json
{ "command": "node", "args": "[\"--experimental-strip-types\", \"skills/beichen-policy-assistant/scripts/build_enterprise_profile.ts\", \"--company\", \"<企业全称>\"]" }
```
输出：`output/profiles/{企业slug}.json` + `.md`。未配置 LLM 时用规则降级萃取，保证可运行。

### Step 2：多元政策匹配（Match）

```json
{ "command": "node", "args": "[\"--experimental-strip-types\", \"skills/beichen-policy-assistant/scripts/match_policy.ts\", \"--profile\", \"skills/beichen-policy-assistant/output/profiles/<企业slug>.json\", \"--topn\", \"10\"]" }
```
输出：`output/matches/<企业slug>-<date>.json`（匹配矩阵：政策编号/评分/依据/缺口项）。

### Step 3：适配研判报告（Report）

```json
{ "command": "node", "args": "[\"--experimental-strip-types\", \"skills/beichen-policy-assistant/scripts/generate_policy_report.ts\", \"--profile\", \"skills/beichen-policy-assistant/output/profiles/<企业slug>.json\", \"--matches\", \"skills/beichen-policy-assistant/output/matches/<企业slug>-<date>.json\"]" }
```
输出：`output/reports/<企业slug>-<date>.md`（含条件对标表、缺口分析、合规声明）。

### Step 4：申报任务（Apply）
为 Top N 匹配政策生成申报任务（材料清单、截止时间），写入匹配矩阵 meta。

### Step 5：结果落库（Persist，仅生成 SQL）

```json
{ "command": "node", "args": "[\"--experimental-strip-types\", \"skills/beichen-policy-assistant/scripts/save_to_db.ts\", \"--profile\", \"skills/beichen-policy-assistant/output/profiles/<企业slug>.json\", \"--report\", \"skills/beichen-policy-assistant/output/reports/<企业slug>-<date>.md\", \"--matches\", \"skills/beichen-policy-assistant/output/matches/<企业slug>-<date>.json\", \"--sql-only\"]" }
```
输出：`output/sql/policy_*.sql`（company upsert + tasks 写入 policy-match / policy-apply）。

---

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `company` | string | 场景 B 必填 | 目标企业全称（支持批量，逗号分隔） |
| `topn` | int | 否 | 匹配/申报 Top N（默认 10） |
| `query` | string | 场景 A 必填 | 主题检索词（≤200 字符） |
| `freshness` | string | 否 | 时效窗，场景 A 用：`1y`/`2026-01-01,2026-12-31` 等 |

## 错误处理与降级

- 检索内核 `http_client` 通道超时 → 自动回退内置 fetch（stderr 告警，结果仍可采信）。
- LLM 不可用 → 匹配用规则打分、报告用模板生成，均不中断流程。
- 脚本 TS 版异常 → 改用同目录 `.py` 版（参数签名一致）。
- 数据库连接失败 → save_to_db 用 `--sql-only` 仅出 SQL 文件。

## 输出与合规

- 三层知识库 / 企业画像 / 匹配矩阵 / 研判报告落 `skills/beichen-policy-assistant/output/` 与 `knowledge/`。
- 报告固定附"仅供申报参考，不构成法律意见"。
- 北京地区 74 条政策原文库，报告须明示适用范围，不得让用户误认为全国通用。

## 严禁事项

- 严禁抓取未授权数据（付费接口、反爬站点、企业隐私数据）。
- 严禁输出无溯源的政策匹配结论（幻觉治理硬性要求）。
- 严禁伪造政策来源与匹配依据；未绑定 `policy_no` 或信源不可核验者一律标"待核实"进 `excluded[]`。
- 严禁绕过人工研判门禁直接提交正式库。
