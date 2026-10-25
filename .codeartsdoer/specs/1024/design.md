# 政策侦探（Policy Detective）技术设计文档

> 产出：SDD 流程第 3 步（design），子 agent `sdd-design-writer`
> 模板：`skills/sdd/templates/design_template.md`（10 节通用设计模板）
> 设计原则：`skills/sdd/templates/design-principles.md`
> 上游输入：`.codeartsdoer/specs/1024/spec.md`（35 需求 / 59 验收条件）、`research.md`（v2+）
> 输出目录：`.codeartsdoer/specs/1024/`（用户显式指定「在 1024 目录创建」，以用户为准）
>
> **本设计的证据基线**：所有引用均标注 `文件:行号`，来自实际代码或真实调用实测。
> 元宝搜索实测累计 26 次真实调用（旗舰版），关键结论见 §2.5 与 §5。

- **项目名称**：政策侦探（Policy Detective）—— 1024 超能 Coding 周末 · 侦探赛道
- **版本**：1.1.0（2026-10-25 编码阶段实测回写：结论状态改为「可核验出处」门禁，交叉验证增补三级证据）
- **创建日期**：2026-10-25
- **作者**：UCToo Team
- **状态**：已按 v1.1 实现轨一（skills/yuanbao-search/，TS+PY 双版自检通过）

---

# 一、需求与存量功能关系分析

> 铁律：**先盘存量再设计**。任何"新建"决策前先回答"能不能复用"。

## 1.1 存量详细分析

### 1.1.1 凭据与配置

`.env:265-266` 已存在 `QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY`。本研究阶段已用该对密钥完成 26 次 `wsa` / `SearchPro` 真实调用（HTTP 200），**确认同一个密钥对可直接用于元宝搜索**——无需申请新凭据，无需新增配置项。

凭据读取沿用既有约定：脚本自行解析 `.env`（probe 中 `readEnv()` 用行正则 `^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$` 逐行匹配，见 `C:/Users/patrick/AppData/Local/Temp/ybcheck/probe_standard.mjs:6-13`）。

### 1.1.2 出网能力

`skills/http-client/scripts/http_client.ts:48` 提供 `makeRequest()`：Node 原生 `fetch` + `AbortController` 超时（:83-84），统一返回 `{success, status, headers, body, error}`（:26-32），CLI 形态 `node http_client.ts <method> <url> [json_body] [headers_json]`（:136-186）。Python 降级版 `scripts/http_client.py` 同签名。

**判断**：本组件**不需要**自己实现 HTTP 客户端，只需实现**签名头生成**并以 `headers_json` 传入即可复用。

### 1.1.3 技能形态与双版本约定

`skills/http-client/SKILL.md:18-23` 明确项目既有约定：**TypeScript 优先**（Node ≥22.6 原生 fetch，零 npm 依赖）、**Python 为降级备选**。SKILL.md frontmatter 格式见 `http-client/SKILL.md:1-9`（`name` / `description` / `license` / `metadata.{author,version,category}`）。

### 1.1.4 L3 进程隔离轨（本轮重点存量）

已是仓库主流形态而非设想：11 个带 `plugin.yaml` 的技能中 **7 个为 `mode: process`**。范本 `skills/github`：

- `skills/github/plugin.yaml`：`mode: process`、`command: ./skills/github/target/release/bin/skill_github.exe`、`enabled: true`、`autoRestart: true`、`order: 10`，含 `#region AutoCreateCode` 保护区与"二次开发区"。
- `skills/github/cjpm.toml`：`cjc-version = "1.1.3"`、`output-type = "executable"`、`compile-option = "-O2 --dy-std -Woff all"`，依赖 `ystyle::cordis_plugin` / `ystyle::cordis_core` / `jsonvalue` / `ystyle::jsonrpc`，并配 `bin-dependencies` 指向 `libs/cangjie-stdx-windows-x64-1.1.3.1/.../stdx`。
- `skills/github/src/main.cj:12-27`：`PluginRuntime.run("github", inject, provide, { ctx => ... })`，**诊断信息必须走 `eprintln`**（:13 注释）。

协议与自愈：L3 固定 **JSON-RPC over stdio**（`src/plugin/plugin_config.cj:18`），`NewlineFraming` 逐行解析（`src/plugin/tools/plugingen/PluginGenerator.cj:414`），**stdout 是协议通道，诊断只能写 stderr**（同文件 :554）。崩溃自愈默认开启（`src/plugin/plugin_config.cj:103`：`autoRestart` 缺省 true，reconcile 检测 stdout EOF 自动重拉）。

仓颉侧能力已确认可用：`stdx.crypto.digest`（宿主已有用法 `src/scripts/package_release/main.cj:18`）；出网与 TLS 的 `stdx.net.http` / `stdx.net.tls` 动态库随包就绪（`libs/cangjie-stdx-windows-x64-1.1.3.1/.../stdx/libstdx.net.http.dll`、`libstdx.net.tls.dll`）。

### 1.1.5 beichen 三层知识库与脚本链

`skills/beichen-policy-assistant/knowledge/policy-index.json`：`version 1.0.0`、`count: 74`、`policies[]` 每项含 `policy_no` / `domain` / `level` / `department` / `title` / `status` / `conditions` / `support` / `file`。政策原文 74 条、官方解读 3 条、实操洞察 3 条。

脚本链（`skills/beichen-policy-assistant/scripts/`，9 组 TS/Python 双版本）CLI 契约：

| 脚本 | CLI | 行号 |
|---|---|---|
| `build_enterprise_profile.ts` | `--company "名称"` | :1-6 |
| `match_policy.ts` | `--profile {画像json} [--topn 10]` | :1-7 |
| `save_to_db.ts` | `--profile {} --report {} --matches {} [--sql-only]` | :1-7 |
| `update_policy_kb.ts` | `--sources default` \| `--demo` \| `--commit --date --reviewer` | :6-9 |

落库已实现且**不新建表**：`save_to_db.ts:68-69` 对 `public.company` 做 UPDATE + INSERT ... WHERE NOT EXISTS 的 upsert（`org_type = 'beichen-enterprise'`）；`save_to_db.ts:78-87` 向 `public.tasks` 插入，`task_type` 取值 `policy-match` / `policy-apply`，结构化数据进 `extra_data`（jsonb）。表结构见 `sql/uctooDB.sql:1824`（company）、`sql/uctooDB.sql:7488`（tasks，含 `deadline` / `task_status` / `tags` / `extra_data`）。

研判门禁**已存在**：`update_policy_kb.ts:9` 的 `--commit --date --reviewer` 模式，要求显式传 reviewer 才入库。

### 1.1.6 需修复的存量缺陷

`skills/beichen-policy-assistant/SKILL.md:162` 与 `:166` 两条降级路径指向 `web_search`。经核对宿主内置工具清单 `src/tool/tool_permission.cj`（共 22 个：`browser_open` `cli_execute` `code_snippet_generator` `directory_create` `directory_list` `file_copy` `file_delete` `file_edit` `file_move` `file_read` `file_search` `file_write` `firecrawl` `http_request` `python_execute` `skill_initializer` `skill_install` `skill_packager` `skill_search` `skill_validate` `template_engine` `web_fetch`）**不存在 `web_search`**；`src/` 全量 grep `web_search` 零命中。即：**这两条降级链自建成起就是死的**。本组件需将其改指到真实可用的检索能力。

### 1.1.7 限速 / 重试 / 聚合策略

`skills/multi-search-engine/SKILL.md:29`（cookie 仅在被拒时动态获取、不落盘）、`:37`（403/429 时抓取引擎首页换新 cookie）、`:46`（失败后延迟 2 秒重试一次）。这些**编排策略**与取数通道无关，应保留复用。

## 1.2 已实现（可直接复用，复用度 100%）

| # | 存量资产 | 位置 | 复用方式 |
|---|---|---|---|
| S1 | 云 API 密钥对 | `.env:265-266` | 直接读取，实测可用于 wsa SearchPro |
| S2 | HTTP 请求能力 | `skills/http-client/scripts/http_client.ts:48` | 调用其 CLI，签名头由本组件生成后传入 |
| S3 | 双版本脚本约定 | `skills/http-client/SKILL.md:18-23` | 新技能照此形态建 TS 主 + Python 降级 |
| S4 | L3 工程模板 | `skills/github/cjpm.toml`、`plugin.yaml`、`src/main.cj` | 复制改名，仅改 name / command / 依赖 |
| S5 | L3 stdio 协议与自愈 | `src/plugin/plugin_config.cj:18,103` | 遵循 JSON-RPC over stdio，诊断走 stderr |
| S6 | 密钥派生所需摘要能力 | `stdx.crypto.digest`（`src/scripts/package_release/main.cj:18`） | L3 轨实现 HMAC-SHA256 |
| S7 | 政策索引与原文库 | `knowledge/policy-index.json`（74 条） | 交叉验证的事实底座 |
| S8 | 企业画像生成 | `build_enterprise_profile.ts:1-6` | 直接调用 |
| S9 | 政策匹配 | `match_policy.ts:1-7` | 直接调用 |
| S10 | 落库（不新建表） | `save_to_db.ts:68-87` | 直接调用 |
| S11 | 研判门禁 | `update_policy_kb.ts:9` | 直接调用，`--reviewer` 强制署名 |
| S12 | 限速/重试/聚合策略 | `multi-search-engine/SKILL.md:29,37,46` | 编排层复用 |

## 1.3 需扩展（部分复用，复用度 ~50%）

| # | 存量资产 | 扩展点 | 对应需求 |
|---|---|---|---|
| E1 | `build_enterprise_profile.ts` | 字段缺失时的降级从"标记留空"改为**经元宝检索采集并标注采集来源** | REQ-PD-021 |
| E2 | `match_policy.ts` | 匹配结论**必须**绑定 `policy_no`，未绑定者不得作为结论输出 | REQ-PD-022 |
| E3 | `update_policy_kb.ts` | 取数源由固定 4 站点抓取改为元宝检索 + `Freshness` 时效窗；保留 `--commit --reviewer` 门禁 | REQ-PD-026、REQ-PD-027 |
| E4 | `save_to_db.ts` | 申报任务的 `task_type` 与 `extra_data` 结构扩展（材料清单、截止时间、跟进状态） | REQ-PD-025、REQ-PD-029 |
| E5 | `beichen/SKILL.md:162,166` | 两条指向不存在工具的降级链改指本组件 | REQ-PD-031 |

## 1.4 需新增（复用度 0%）

| # | 新增物 | 说明 | 对应需求 |
|---|---|---|---|
| N1 | `skills/yuanbao-search/` 脚本技能 | SKILL.md + `scripts/yuanbao_search.ts` / `.py` | REQ-PD-001~006、033 |
| N2 | TC3-HMAC-SHA256 签名模块 | 五步密钥派生 + 规范请求串，见 §2.5.2 | REQ-PD-001 |
| N3 | 响应解析器（含 `Pages` 二次 parse） | 实测 `Pages` 元素为 JSON 字符串 | REQ-PD-005 |
| N4 | 可信度四因子合成器 | 档位降级链，见 §2.5.5 | REQ-PD-010~019 |
| N5 | 政策交叉验证器 | `policy-index.json` 比对 + 绑定 `policy_no` | REQ-PD-014、015 |
| N6 | `skills/yuanbao-policy/` L3 独立工程 | cjpm.toml + plugin.yaml + src/main.cj，闭源分发载体 | REQ-PD-040~044 |

**复用度概览**：直接复用 12 项、部分复用 5 项、新建 6 项 → **复用度 ≈ (12 + 5×0.5) / 23 ≈ 63%**。

---

# 二、增量设计方案

## 2.1 设计目标

1. **内核替换**：把政策线索的取数通道从"抓取搜索引擎结果页"换成"结构化检索 API"，且上游调用方式不中断。
2. **可信度可解释**：把"信得过"从口号变成**四因子合成 + 可解释理由**的机制。
3. **敢说不知道**：未绑定 `policy_no` 的结论强制标"待核实"并排除出正式报告——这是赛事明文评分点，也是本组件最强差异化。
4. **双轨交付**：脚本轨保底（今天必须可用），L3 轨并行（创意加分与闭源绝活）。
5. **零侵入**：不修改宿主 `src/`，不新建数据库表。

## 2.2 设计原则

- **复用优先**：能调既有脚本就不重写（§1.2 十二项）。
- **存在性防御**：所有可选字段按"存在即用、缺失即降级"处理，绝不假定。
- **可解释优于黑箱**：不输出单一分数，输出分档 + 分项取值 + 理由。
- **降级不中断**：任何单点失败都不得让整体流程中止。
- **凭据零泄露**：密钥不进产物、日志、异常、进程参数。

## 2.3 技术选型

| 组件 | 选型 | 依据 |
|---|---|---|
| 脚本轨主实现 | TypeScript（Node ≥22.6 原生 fetch） | `http-client/SKILL.md:18-23` 既有约定，零 npm 依赖 |
| 脚本轨降级 | Python 3.8+ | 同上，既有约定 |
| 检索服务 | 元宝搜索 `wsa` / `SearchPro` / `2025-05-08` | 官方 SDK `tencentcloud/wsa/v20250508/wsa_client.py` |
| 鉴权 | TC3-HMAC-SHA256 | 实测 26 次通过 |
| L3 轨语言 | 仓颉 cjc 1.1.3 | `skills/github/cjpm.toml` 既有模板 |
| L3 轨协议 | JSON-RPC over stdio（NewlineFraming） | `src/plugin/plugin_config.cj:18` |
| 事实底座 | beichen 三层知识库（74 条） | `knowledge/policy-index.json` |
| 落库 | 既有 `company` / `tasks` 表 | `sql/uctooDB.sql:1824`、`:7488`；禁止新建 |

## 2.4 系统架构

### 2.4.1 架构图

```
                        ┌──────────────────────────────────────┐
   创业者 ─────────────▶│         政策侦探编排层（SKILL.md）      │
                        └───────────────┬──────────────────────┘
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        ▼                               ▼                               ▼
┌────────────────┐          ┌────────────────────┐          ┌────────────────────┐
│ 轨一：脚本技能  │          │  检索内核（共用）     │          │ 轨二：L3 进程插件   │
│ yuanbao-search │─────────▶│  ① 签名 ② 请求       │◀─────────│ skill_yuanbao_     │
│ TS 主 / Py 降级 │          │  ③ 解析 ④ 归一化     │          │ policy.exe（闭源）  │
└────────────────┘          └─────────┬──────────┘          └────────────────────┘
                                      │                          stdio JSON-RPC
                                      ▼                          （stdout 为协议通道）
                            ┌────────────────────┐
                            │ 可信度四因子合成器   │
                            │ 权威度/信源/时效/命中 │
                            └─────────┬──────────┘
                                      │ policy_no 绑定（未命中→待核实，拒绝入册）
                                      ▼
                    ┌─────────────────────────────────┐
                    │ beichen 存量脚本链（复用，扩展）   │
                    │ 画像 → 匹配 → 报告 → 落库 → 巡检   │
                    └──────────────┬──────────────────┘
                                   ▼
                        company / tasks（既有表，不新建）
```

### 2.4.2 模块划分

| 模块 | 职责 | 形态 |
|---|---|---|
| M1 签名模块 | TC3-HMAC-SHA256 五步派生，产出请求头 | TS / Py / 仓颉 三处同算法 |
| M2 检索模块 | 参数编排、条数收敛、超时重试、降级 | TS / Py / 仓颉 |
| M3 解析模块 | `Pages` 二次 parse、字段存在性防御 | TS / Py / 仓颉 |
| M4 归一化模块 | `score` 批次内 min-max 归一化 | TS / Py / 仓颉 |
| M5 可信度合成 | 四因子档位降级链 + 理由生成 | TS / Py / 仓颉 |
| M6 交叉验证 | `policy-index.json` 比对、绑定 `policy_no` | TS / Py / 仓颉 |
| M7 编排层 | 串联存量脚本链，人在回路门禁 | SKILL.md 流程 |
| M8 可观测 | 请求标识 / 版本号 / 条数 / 耗时 / 降级事件 | 日志 + 产物 |

### 2.4.3 组件交互

轨一（脚本轨，保底路径）：SKILL.md 描述流程 → 模型经 `cli_execute` 调用 `yuanbao_search.ts` → 产物 JSON 落盘 → 交 beichen 存量脚本链。

轨二（L3 轨，加分路径）：宿主按 `plugin.yaml` 的 `command` 拉起 `skill_yuanbao_policy.exe` → stdio JSON-RPC → 插件内完成 M1–M6 → 宿主获得结构化结果与可信度标签。

两条轨**共用同一套判定规则**（§2.5.5），保证行为一致；L3 轨缺失时脚本轨完整可用（REQ-PD-044）。

## 2.5 详细设计

### 2.5.1 M1 签名模块

实测通过的精确参数（`probe_standard.mjs:21-47`）：

| 项 | 值 |
|---|---|
| 方法 / 路径 | `POST /` |
| Host | `wsa.tencentcloudapi.com` |
| 服务标识 | `wsa` |
| 动作 | `SearchPro`（头 `X-TC-Action`） |
| 版本 | `2025-05-08`（头 `X-TC-Version`） |
| 算法 | `TC3-HMAC-SHA256` |
| 规范头 | `content-type:application/json\n host:{host}\n`，`SignedHeaders=content-type;host` |

派生链（五步）：`secretDate = HMAC("TC3"+SecretKey, date)` → `secretService = HMAC(secretDate, "wsa")` → `secretSigning = HMAC(secretService, "tc3_request")` → `signature = HMAC(secretSigning, stringToSign)` → `Authorization`。`stringToSign` = 算法 + 时间戳 + `credentialScope({date}/wsa/tc3_request)` + `SHA256(canonicalRequest)`。

**约束**：密钥仅从 `.env` 读取；签名中间值禁止写入任何产物或日志（REQ-PD：§4.3 spec 安全性第 1、2 条）。

### 2.5.2 M2 检索模块（参数编排）

默认编排（REQ-PD-002）：政策场景未显式指定领域时，默认 `Industry=gov` + `Cnt=50` + 透传时效窗。

**强制约束（实测依据）**：

- `Mode` **默认不携带**。`Mode=1` 旗舰版下仅召回 1 条且该条无 `score`（spec §2 术语），禁止作为主通道（REQ-PD-006）。
- `Cnt` 收敛至枚举 {10,20,30,40,50}（REQ-PD-004）。
- `Site` 与 `Exclude` 互斥；`Exclude` 最多 5 个域名、`|` 分隔（spec §6.1）。
- `Deeplinks` 为可选开关，响应缺失不视为错误（REQ-PD-005）。
- 超时 5 秒（spec §4.1），指数退避重试至多 2 次（spec §4.2）。

降级链：元宝失败 → 宿主内置 `http_request`（`src/tool/tool_permission.cj:143`）+ `multi-search-engine` 抓取通道 → 仍失败返回空集并告警；**任一环节不得整体中断**。

### 2.5.3 M3 解析模块

**必须处理的两个实测坑**：

1. `Pages` 数组每个元素是 **JSON 字符串**，需二次 `JSON.parse`（`probe_standard.mjs:66-70` 已验证）。
2. 字段按存在性提取：`score` / `authority_level` / `content` / `pics` / `deeplinks` / `vr` / `date` / `favicon` **均可能整批缺失**。

解析输出统一结构（对齐 spec §6.2）：`title` / `url` / `site` / `date` / `passage` / `content?` / `pics?` / `favicon?` / `score?` / `authority_level?` / `vr?` / `deeplinks?`。其中 `url` 为必填且必须为合法绝对 URL（溯源唯一依据）。

### 2.5.4 M4 归一化模块（头号风险的工程解）

实测 `score` 跨度 **0.75 ~ 5.46**，量纲由 `Industry` 与 `Version` 共同决定（spec §2）。因此：

```
norm(s, batch):
  max = 本批次内 score 最大值;  min = 本批次内 score 最小值
  if (max == min) return 0.5
  return (s - min) / (max - min)
```

**硬约束**：`norm` 结果**仅在本批次内有效**；跨批次合并必须各批先自行归一化再合并（REQ-PD-016 b）。对外**不展示** `score` 原始绝对值，只展示批次内相对顺序（spec §5.2.3 第 4 条）。带 `vr=true` 且无 `score` 的条目**不参与**排序，单独标注（REQ-PD-017）。

### 2.5.5 M5 可信度四因子合成器（本设计核心）

设计为**档位降级链**而非加权求和——因为因子可能整批缺失，加权求和在缺失时需编造权重。

因子取值（对齐 spec §6.3）：

| 因子 | 取值 | 判定规则 |
|---|---|---|
| 权威度档位 | 高 / 中 / 低 / 不可用 | `authority_level ≥ 4` 高；`= 3` 中；`≤ 2` 低；字段缺失为不可用。**实测值域 2~4**（官方定义 0~5，以实测为准设阈值） |
| 信源分级 | 最高 / 中间 / 最低 | 域名含 `.gov.cn` 或政府序列 → 最高；已知门户/机构 → 中间；`site` 为空或未知 → 最低 |
| 时效档位 | 现行有效 / 已过期 / 未知 | `date` 在时效窗内 → 现行有效；早于时效窗 → 已过期；`date` 缺失 → 未知 |
| 原文库命中 | 已命中 / 未命中 / 库不可用 | 见 §2.5.6 |

合成规则：

```
base = 由信源分级决定：最高→高，中间→中，最低→低
if (时效 == 已过期 || 时效 == 未知)        base = downgrade(base)
if (权威度档位 == 低 || 权威度 == 不可用)  base = downgrade(base)   // 缺失时同时写入理由
downgrade: 高→中, 中→低, 低→低

// 可核验出处门禁（2026-10-25 修订，独立于 base，优先判定）
if (信源分级 == 最低)                       结论状态 = 待核实   // 无法核验发布主体
if (时效 == 已过期)                         结论状态 = 待核实   // 过期政策不作申报依据
if (原文库命中 == 库不可用 && 信源 != 最高)  结论状态 = 待核实   // 无事实底座且非官方一手
else                                        结论状态 = 可采信
```

**v1.1 修订说明（编码阶段实测回写）**：原规则为"原文库未命中 → 待核实"。
实测 50 条真实结果全部被判待核实，其中 28 条是政府官网原文发布页（.gov.cn、authority_level=4、时效现行），
误判根因是**比对对象错配**：检索结果是"申报通知"（*关于组织开展 2026 年第二批专精特新中小企业资质申报工作的通知*），
库存的是"政策名"（*北京市支持专精特新中小企业高质量发展若干措施*），标题级 2-gram Jaccard 最高仅 **0.18**，
远低于 0.6 阈值；正文中也不出现政策全名（全文包含命中 0/50）。
而官方发布页的 URL 点得开、发布日期看得见，**本身就是可核验出处**，判成"不知道"在语义上说不通。
修订后：敢说不知道 = **拿不出可核验出处时说不知道**；原文库命中降级为加分项（绑定 `policy_no` 与原文路径），
未命中标注"未在本地政策原文库备案，需人工复核"。实测同查询下 20 可采信 / 10 待核实，排除项全部是未知站点与过期内容。

**关键**：`结论状态 == 待核实` 的条目**禁止进入正式适配报告**（REQ-PD-015）。这是"查不到敢说不知道"的机制化实现，也是赛事明文评分点。

理由字段（REQ-PD-018）必填，逐项列出四因子实际取值与判定依据，例如：

> 权威度=不可用（本次服务档位未提供）；信源=最高（bjchy.gov.cn）；时效=现行有效（2026-09-12 落在 1 年内）；原文库=未命中 → 结论状态：待核实，**已排除出正式报告**。

### 2.5.6 M6 政策交叉验证器

输入：检索条目 `title`；底座：`knowledge/policy-index.json` 的 `policies[].title` / `department`。

算法（确定性、无 LLM 依赖）：

1. 归一化：全角转半角、去空白、去标点符号 `()（）【】[]《》·,.，。、/\:：;；'""`。
2. 建立 2-gram 字符集。
3. **三级证据**（2026-10-25 修订，实测回写）：
   - ① 标题级：Jaccard `J = |A∩B| / |A∪B| ≥ 0.6`，**或**一方包含另一方且被包含长度 ≥ 80%；
   - ② 核心名重叠：`|A∩B| / min(|A|,|B|) ≥ 0.75` 且较小方 gram 数 ≥ 8 —— 长通知标题里嵌着短政策名时
     Jaccard 被分母摊薄（实测 0.18~0.35），重叠系数不摊薄；
   - ③ 正文引用：政策全名（≥8 字）出现在「标题 + 摘要」归一化文本中。
4. 命中 → 绑定该条 `policy_no`，记录 `file` 路径（用于"来源点得开"），并在理由中标注证据类型。
5. 索引不可解析 → 因子置"库不可用"，**非最高档信源的结论一律待核实**（spec §5.2.3 第 2 条 v1.1）。

实测命中样例（正确）：`48 → 北京市高精尖产业发展项目资金管理办法`、`67 → 北京市支持专精特新中小企业高质量发展若干措施`。
未命中仍属多数——这是库覆盖面（74 条北京政策）的真实反映，由报告的适用范围声明兜底，不是算法缺陷。

### 2.5.7 M7 编排层与存量脚本链

```
Step 0  自检：yuanbao_search.ts --selftest          → 输出连通性 + Version + 字段可用性
Step 1  画像：build_enterprise_profile.ts --company "X"   （E1：缺失字段经检索采集并标来源）
Step 2  检索：yuanbao_search.ts --query "<画像关键词>" --industry gov --cnt 50 --freshness 1y
Step 3  可信度：四因子合成 + 交叉验证 → 绑定 policy_no / 待核实分流
Step 4  匹配：match_policy.ts --profile {画像} [--topn 10]（E2：结论绑定 policy_no）
Step 5  报告：generate_policy_report.ts（含合规声明；待核实项单列"未查到可靠依据"）
Step 6  落库：save_to_db.ts（E4：申报任务 extra_data 扩展）
Step 7  巡检：update_policy_kb.ts --sources yuanbao --freshness 7d（E3）
Step 8  研判：update_policy_kb.ts --commit --date <日期> --reviewer <人>（S11 门禁，缺 reviewer 拒绝）
```

### 2.5.8 M8 进度与可观测

每次检索必须记录（spec §4.4）：`RequestId`、`Version`、返回条数、耗时（ms）。

`Version` 为 `standard` 或观测到 `authority_level` 整批缺失 → 写一条**降级事件**日志。

心跳：批量处理每 100 条向 stderr 输出一行进度（沿用 installer `importer.cj` 的节流心跳做法），确保长任务可见、卡点可定位。

## 2.6 数据设计

### 2.6.1 数据模型

不新建表。三类数据落点：

| 数据 | 落点 | 依据 |
|---|---|---|
| 企业画像 | `company.org_description` / `region` / `org_type='beichen-enterprise'` | `save_to_db.ts:68-69` |
| 匹配报告 | `tasks`（`task_type='policy-match'`，正文入 `description`，结构入 `extra_data`） | `save_to_db.ts:78-87` |
| 申报任务 | `tasks`（`task_type='policy-apply'`，`deadline` 存截止时间，`task_status` 存跟进状态） | `sql/uctooDB.sql:7488` |

### 2.6.2 产物文件

`skills/beichen-policy-assistant/output/` 下：`profiles/{slug}.json`（画像）、`matches/{slug}.json`（匹配矩阵 + 可信度标签）、`reports/{slug}.md`（适配报告）、`pending/{date}.json`（待研判流水）。落库失败时产物保留供人工重试（spec §5.3.3 第 4 条）。

## 2.7 接口设计

### 2.7.1 外部接口（元宝搜索）

唯一外部依赖。请求头：`Authorization` / `Content-Type` / `Host` / `X-TC-Action` / `X-TC-Version` / `X-TC-Timestamp`。响应取 `Response.Pages`（元素需二次 parse）、`Response.Version`、`Response.RequestId`；错误取 `Response.Error.{Code,Message}`。

错误分类处置（spec §5.1.3）：`RequestLimitExceeded` → 退避重试 2 次后降级；`AuthFailure` / `UnauthorizedOperation` → 不重试，提示凭据（**错误信息不得含密钥片段**）；结构异常 → 按空集处理并告警，禁止抛异常中断调用方。

### 2.7.2 内部接口（脚本 CLI，与项目既有约定一致）

```
node --experimental-strip-types scripts/yuanbao_search.ts \
  --query "<查询词>" \
  [--industry gov|news|acad|finance] \
  [--freshness 1d|1w|1m|1y|YYYY-MM-DD|YYYY-MM-DD..YYYY-MM-DD] \
  [--site <单个域名>] [--exclude <d1|d2|...最多5个>] \
  [--cnt 10|20|30|40|50] [--deeplinks] [--selftest] [--json]

python scripts/yuanbao_search.py ...      # 同签名，降级备选
```

输出（stdout，单行 JSON）：

```json
{
  "ok": true,
  "requestId": "…",
  "version": "flagship",
  "elapsedMs": 668,
  "degraded": false,
  "items": [
    {
      "title": "…", "url": "https://…", "site": "…", "date": "2026-09-12",
      "passage": "…", "scoreNorm": 0.82, "authorityLevel": 4,
      "credibility": {
        "authority": "高", "sourceTier": "最高", "freshness": "现行有效",
        "kbHit": "已命中", "policyNo": "12",
        "status": "可采信", "level": "高",
        "reason": "权威度=4(高)；信源=最高(…gov.cn)；时效=现行有效；原文库=已命中(policy_no=12)"
      }
    }
  ],
  "excluded": [ { "title": "…", "status": "待核实", "reason": "原文库未命中" } ]
}
```

`excluded` 数组是"敢说不知道"的**对外可见证据**——未命中项不是被丢弃，而是被明确列出并说明原因。演示时直接展示这个数组。

### 2.7.3 L3 插件接口（轨二）

`skills/yuanbao-policy/plugin.yaml`：`mode: process`、`command: ./skills/yuanbao-policy/target/release/bin/skill_yuanbao_policy.exe`、`enabled: true`、`autoRestart: true`。

协议约束（**必须遵守，否则协议被破坏**）：stdout 是 JSON-RPC 帧通道（`PluginGenerator.cj:414`），诊断信息只能 `eprintln`（`PluginGenerator.cj:554`）。注册方式照 `skills/github/src/main.cj:17-26`：`PluginRuntime.run("yuanbao-policy", inject, provide, { ctx => 注册 handler })`。

## 2.8 人在回路设计

1. **研判门禁**（REQ-PD-027）：储备库 → 正式库必须 `--commit --reviewer <人>`；缺 `reviewer` 直接拒绝并保持"待研判"。
2. **留痕**：研判动作同时记录 `reviewer` 与时间；政策原文库写入记录操作人与时间（spec §4.3）。
3. **合规声明**：所有报告附"仅供申报参考，不构成法律意见"（REQ-PD-028）。
4. **内容边界**：仅做**客观政策的检索与条件比对**，不做政策解读或倾向性评价（spec §4.6 第 8 条，赛事内容禁区）。

## 2.9 防回退约束

见 §七（必写章节，逐条列"禁止复现的问题 + 判据"）。

---

# 三、非功能设计

## 3.1 安全性

1. 密钥仅从 `.env` 读取；**禁止**硬编码、禁止进入产物/日志/异常堆栈/进程参数（spec §4.3）。判据：全局 grep 产物目录与日志不含 `SecretId`/`SecretKey` 值片段。
2. 错误信息脱敏：`AuthFailure` 类错误提示只说"凭据无效"，不回显任何服务端原始消息中的敏感片段。
3. 不采集与政策申报无关的企业隐私数据。

## 3.2 性能

| 指标 | 目标 | 依据 |
|---|---|---|
| 单次检索端到端 | ≤ 5 s | 实测基线 210 ms ~ 1488 ms |
| 单条标注 | ≤ 50 ms | 50 条批处理标注总耗时 ≤ 2.5 s |
| 完整闭环 | ≤ 3 min | 超时先返回阶段性结果 |
| 巡检单次 | ≤ 5 min | spec §4.1 |

优化：交叉验证的 2-gram 索引**启动时构建一次**并复用（74 条规模，构建可忽略）；检索结果按 `cnt` 上限一次取满，避免分页多次往返。

## 3.3 可靠性

1. 检索失败 → 降级到 `http_request` + 抓取通道，不中断（REQ-PD-030 b）。
2. `authority_level` 全批缺失 → 三因子继续判定 + 记降级事件，不报错（REQ-PD-011）。
3. 巡检单源失败 → 记录失败条目继续，**禁止整批回滚**（REQ-PD-026 b）。
4. 落库失败 → 保留产物文件供人工重试（REQ-PD-029 b）。
5. L3 插件启动失败 / 崩溃 → `autoRestart` 重拉，失败则回退脚本轨（`plugin_config.cj:103`）。

## 3.4 可维护性

1. 每次检索记录 `RequestId` / `Version` / 条数 / 耗时。
2. 可信度标签必带可解释理由。
3. 提供 `--selftest` 独立自检入口，不触发完整闭环即可验证连通性与档位。
4. 产物全部落盘，支持事后复核。

## 3.5 兼容性

1. 兼容 `Version` 在 `standard` ↔ `flagship` 间波动（实测 8 次中 7 flagship / 1 standard）。
2. 兼容 `authority_level` / `content` / `pics` / `deeplinks` / `vr` / `score` 部分缺失。
3. 向后兼容：新增可选参数不改变既有参数行为；上游调用方式不中断（REQ-PD-030）。
4. 地域适用：74 条均为北京政策，报告**必须**明示适用范围，禁止让用户误认为全国通用（spec §6.4 第 9 条）。

---

# 四、部署与运维

## 4.1 部署形态

| 轨 | 产物 | 部署方式 |
|---|---|---|
| 轨一（保底） | `skills/yuanbao-search/`（SKILL.md + TS/Py 脚本） | 目录拷贝即用，**无需编译** |
| 轨二（加分） | `skills/yuanbao-policy/`（exe + plugin.yaml + SKILL.md） | 宿主扫 `skills/*/plugin.yaml` 注册 |

## 4.2 构建命令（用户执行）

```bash
# 轨一：零编译，拷贝即可用

# 轨二：L3 独立工程（用户执行，AI 不跑 cjpm）
cd D:/UCT/projects/uctoo/apps/agentskills-runtime/skills/yuanbao-policy
cjpm build                 # 产物 target/release/bin/skill_yuanbao_policy.exe
```

## 4.3 闭源分发（绝活演示）

分发目录**删除 `src/`**，仅保留：`skill_yuanbao_policy.exe` + `plugin.yaml` + `SKILL.md`。插件照常加载运行——这是脚本型技能（JS/Python 必须明文）做不到的。

## 4.4 运维观测

- 日志：stderr 心跳 + 降级事件。
- 排障入口：`--selftest` 先判连通性与档位，再判业务。

---

# 五、风险与对策

| # | 风险 | 证据 | 对策 | 等级 |
|---|---|---|---|---|
| R1 | `score` 量纲漂移（0.75~5.46） | 26 次实测 | 批次内 min-max 归一化；禁止跨批比较、禁止写死阈值 | 高 |
| R2 | `authority_level` 整批缺失（`Version` 波动） | 8 次中 1 次 standard | 主指标但强制降级路径；三因子继续判定 | 高 |
| R3 | `Mode=1` 召回极少（1 条） | 旗舰版实测 | 默认不携带 `Mode` | 中 |
| R4 | 知识库仅 74 条北京政策 → 命中率低 | `policy-index.json` | 报告明示适用范围；未命中走"待核实"而非放行 | 中 |
| R5 | 仓颉侧无 `stdx.net.http` 存量先例 | `grep src` 零命中 | 库已随包（`libstdx.net.http.dll`）；若编译受阻，L3 轨裁剪，不影响轨一交付 | 中 |
| R6 | cjc 1.1.3 TLS breaking change | 既有迁移记录 | L3 出网按 1.1.3 新包名/字段名写 | 中 |
| R7 | 配额超限（`RequestLimitExceeded`）阈值未知 | 官方文档未给出 | 演示前预热；退避重试 + 降级 | 低 |
| R8 | 赛程时间紧（16:00 截止） | 选手手册 | 轨一必须完成；轨二可裁剪，未完成亦为工程证据 | 高 |

---

# 六、附录

## 6.1 引用的真实实现文件清单

| 文件 | 关键行 | 用途 |
|---|---|---|
| `apps/agentskills-runtime/.env` | 265-266 | 云 API 密钥对（实测可用于 wsa） |
| `skills/http-client/scripts/http_client.ts` | 26-32, 48, 83-84, 136-186 | 出网能力复用 |
| `skills/http-client/SKILL.md` | 1-9, 18-23 | frontmatter 与双版本约定 |
| `skills/github/plugin.yaml` | 全文 | L3 插件清单范本 |
| `skills/github/cjpm.toml` | 全文 | L3 工程配置范本 |
| `skills/github/src/main.cj` | 12-27 | L3 入口与 stderr 约束 |
| `src/plugin/plugin_config.cj` | 18, 103 | stdio 协议、崩溃自愈 |
| `src/plugin/tools/plugingen/PluginGenerator.cj` | 414, 554 | stdout 协议通道约束 |
| `src/tool/tool_permission.cj` | 78-143 | 内置工具清单（无 `web_search`） |
| `skills/beichen-policy-assistant/knowledge/policy-index.json` | 全文 | 74 条政策索引 |
| `skills/beichen-policy-assistant/scripts/build_enterprise_profile.ts` | 1-6 | 画像 CLI |
| `skills/beichen-policy-assistant/scripts/match_policy.ts` | 1-7 | 匹配 CLI |
| `skills/beichen-policy-assistant/scripts/save_to_db.ts` | 68-69, 78-87 | 落库（不新建表） |
| `skills/beichen-policy-assistant/scripts/update_policy_kb.ts` | 1-10 | 巡检与研判门禁 |
| `skills/beichen-policy-assistant/SKILL.md` | 162, 166 | 待修复的失效降级链 |
| `skills/multi-search-engine/SKILL.md` | 29, 37, 46 | 限速/重试/聚合策略 |
| `sql/uctooDB.sql` | 1824, 7488 | company / tasks 表结构 |
| `src/scripts/package_release/main.cj` | 18 | `stdx.crypto.digest` 用法先例 |
| `libs/cangjie-stdx-windows-x64-1.1.3.1/.../stdx/` | — | `net.http` / `net.tls` / `crypto.digest` 就位 |
| `D:/UCT/products/gitee/tencentcloud-sdk-python/tencentcloud/wsa/v20250508/` | `wsa_client.py`、`models.py` | 官方字段矩阵权威信源 |

## 6.2 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-25 | UCToo Team | 初始版本：两段式首章 + 10 节设计 + 防回退约束 |

---

# 七、防回退约束（必写）

> 逐条写明"禁止复现的问题 + 判据"，供 tasks 步与联调核对。

| # | 禁止复现的问题 | 判据（发现即视为回退） |
|---|---|---|
| G1 | 用固定数值作为 `score` 可信度阈值 | 代码中出现 `score` 与字面常量比较；或跨批次直接比较 `score` |
| G2 | 假定 `authority_level` 必然存在 | 直接取用该字段而无存在性校验、无降级分支 |
| G3 | 把 `Version` 当作能力开关 | 出现按 `Version == "flagship"` 分支启用/禁用能力的逻辑 |
| G4 | 把 `Mode=1` 当主召回通道 | 默认 payload 中携带 `Mode = 1` |
| G5 | 待核实结论进入正式报告 | 报告渲染环节未过滤 `status == 待核实` 的条目（判定口径见 §2.5.5 v1.1 可核验出处门禁） |
| G6 | `Pages` 未做二次 parse | 直接把 `Pages` 元素当对象取字段（元素实为 JSON 字符串） |
| G7 | 密钥进入产物 / 日志 / 异常 | 产物目录或日志中 grep 到密钥值片段 |
| G8 | L3 插件用 `println` 输出诊断 | `src/main.cj` 出现 `println`（必须 `eprintln`） |
| G9 | 新建数据库表 | SQL 中出现 `CREATE TABLE`（只允许复用 `company` / `tasks`） |
| G10 | 研判无署名放行 | `--commit` 路径缺少 `reviewer` 非空校验 |
| G11 | 检索失败导致整体中断 | 请求失败处直接抛出且无降级分支 |
| G12 | TS 实现失败不提供 Python 降级 | 技能目录下缺任一版本脚本 |
| G13 | 巡检单源失败整批回滚 | 巡检循环中出现失败即 `break` / 回滚已处理条目 |
| G14 | 知识库不可用时仍放行结论 | 索引解析失败时未将「非最高档信源」的结论置"待核实" |
| G15 | 政策库被误认为全国通用 | 报告中缺适用范围说明 |
