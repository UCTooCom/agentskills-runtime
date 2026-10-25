# 政策侦探（Policy Detective）任务规划文档

> 产出：SDD 流程第 4 步（task），子 agent `sdd-task-planner`
> 模板：`skills/sdd/templates/tasks-template.md`
> 上游输入：`.codeartsdoer/specs/1024/spec.md`（35 需求 / 59 验收条件）、`design.md`（v1.0.0，复用 12 / 扩展 5 / 新建 6）、`research.md`（v2+）
> 输出目录：`.codeartsdoer/specs/1024/`（与前三份文档同目录，延续「用户显式指定输出目录时以用户为准」）
>
> **时间盒硬约束**：提交截止 **10/25 16:00**（15:00 封板）。本文所有任务按「轨一保底 → 轨二加分 → 赛事交付」三档排布，
> 轨一（T-01~T-20）为**不可裁剪**，轨二（T-21~T-25）编译受阻即按 T-25 裁剪，赛事交付（T-26~T-30）为**评奖必要条件**。

## 文档信息

| 项 | 值 |
|---|---|
| 关联需求 | `.codeartsdoer/specs/1024/spec.md` |
| 关联设计 | `.codeartsdoer/specs/1024/design.md`（v1.0.0） |
| 关联研究 | `.codeartsdoer/specs/1024/research.md`（v2+，26 次真实调用实测） |
| 生成日期 | 2026-10-25 |
| 版本 | 1.0.0 |
| 状态 | 草稿（待 code 步执行） |
| 任务总数 | 30（轨一 20 + 轨二 5 + 赛事 5） |
| 是否拆分态子系统 | **否**。本目录无 `specs/{主}/SPECS_INDEX.md`，`feature_name = 1024` 为独立单系统工程，铁律 15 的 SPECS_INDEX 前置不适用；跨技能边界（beichen / multi-search-engine / http-client）仍按「调用或按 E1–E5 清单扩展」处理，禁止顺手改动清单外内容 |

---

## 开发规范（全任务强制遵守）

### 1. 骨架来源（一次性说清，禁止另起炉灶）

| 能力 | 必须复用的既有资产 | 证据行号 |
|---|---|---|
| 云 API 密钥对 | `.env` 的 `QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY`（实测 26 次可用于 `wsa`/`SearchPro`） | `.env:265-266` |
| 出网 | `skills/http-client/scripts/http_client.ts` 的 `makeRequest()` + CLI `<method> <url> [json_body] [headers_json]` | `http_client.ts:26-32,48,83-84,136-186` |
| 双版本约定 | TypeScript 主实现 + Python 降级，同 CLI 签名 | `http-client/SKILL.md:18-23` |
| 技能 frontmatter | `name` / `description` / `license` / `metadata.{author,version,category}` | `http-client/SKILL.md:1-9` |
| L3 工程模板 | `skills/github/cjpm.toml`、`plugin.yaml`、`src/main.cj` | `cjpm.toml` 全文、`plugin.yaml` 全文、`main.cj:12-27` |
| L3 协议 | JSON-RPC over stdio（NewlineFraming），stdout 是协议通道 | `src/plugin/plugin_config.cj:18,103`；`PluginGenerator.cj:414,554` |
| 事实底座 | `knowledge/policy-index.json`（74 条，`count: 74`） | `policy-index.json` 全文 |
| 存量脚本链 | 画像 / 匹配 / 报告 / 落库 / 巡检+门禁 五个脚本，均 TS+PY 双版本 | `beichen-policy-assistant/scripts/` |
| 落库表 | 既有 `public.company`（`sql/uctooDB.sql:1824`）与 `public.tasks`（`:7488`） | `save_to_db.ts:68-69,78-87` |
| 编排策略 | 限速 / 重试 / 聚合（cookie 被拒时动态获取、403/429 换 cookie、失败延迟 2 秒重试一次） | `multi-search-engine/SKILL.md:29,37,46` |

### 2. 语言与工具绑定

- 脚本轨主实现 **TypeScript**（Node ≥22.6 原生 `fetch`，运行方式 `node --experimental-strip-types <script>.ts`，零 npm 依赖）→ 标签 `web`。
- 脚本轨降级 **Python 3.8+**（同 CLI 签名，逐字节对齐输出）→ 标签 `web`。
- L3 轨 **仓颉 cjc 1.1.3** → 标签 `cangjie`，**编写前必须加载 `cangjie-coder` 技能**。
- **AI 严禁运行 `cjpm build` / `vue-tsc` / 出包**；编译与回传由人工在独立 cmd 执行（任务内标注【人工】）。

### 3. 复用原则（违反即判回退）

1. **不重写** HTTP 客户端：只生成签名头，通过 `headers_json` 传给 `http_client.ts`。
2. **不新建数据库表**：落库只走 `save_to_db` 已实现的 `company` upsert 与 `tasks` 插入（G9）。
3. **不修改宿主 `src/`**：本组件全部能力落在 `skills/` 下。
4. **能调既有脚本就不重写**：画像/匹配/报告/落库/巡检一律"扩展"而非"重做"（design §1.3 E1–E5）。
5. 改 `beichen-policy-assistant` 时，**只允许动 E1–E5 + T-17 明确列出的行**，不得顺手重构其它段落。

### 4. 命名 / 注释 / 输出约定

- 脚本头注释照 beichen 既有格式：`#!/usr/bin/env node` + 功能说明 + `运行方式: node --experimental-strip-types <script>.ts …`（见 `build_enterprise_profile.ts:1-6`）。
- CLI 参数一律 `--kebab-case`；新增可选参数不得改变既有参数行为（spec §4.5 第 5 条）。
- 脚本 stdout **必须是单行 JSON**（供模型与上游解析）；诊断/进度/心跳**必须走 stderr**。
- 产物统一落 `skills/beichen-policy-assistant/output/{profiles,matches,reports,pending,sql}/`。
- 提交信息、日志、产物中**禁止出现密钥值片段**（G7）。

### 5. 红线清单（design §七 G1–G15 逐条落到任务验收）

G1 禁用固定 `score` 阈值 → T-05；G2 禁止假定 `authority_level` 存在 → T-06；G3 禁止把 `Version` 当能力开关 → T-03/T-06；
G4 默认不携带 `Mode=1` → T-03；G5 待核实禁止入正式报告 → T-14；G6 `Pages` 必须二次 parse → T-04；
G7 密钥零泄露 → T-02/T-08；G8 L3 诊断必须 `eprintln` → T-22；G9 禁止 `CREATE TABLE` → T-15；
G10 研判必须 `--reviewer` → T-16；G11 检索失败必须降级不中断 → T-08；G12 TS/PY 双版本齐全 → T-10、T-12~T-16；
G13 巡检单源失败禁止整批回滚 → T-16；G14 知识库不可用一律待核实 → T-07；G15 报告必须明示适用范围 → T-14。

### 6. 进度与留痕

- 批处理每 100 条向 stderr 输出一行心跳（沿用 installer `importer.cj` 节流做法）。
- 每次检索记录 `RequestId` / `Version` / 条数 / 耗时（ms）；`Version=standard` 或 `authority_level` 整批缺失时写一条降级事件。
- 多轮修订在本文件「修订记录」段留痕，含触发来源与验证结果。

---

## 任务总览

| 编号 | 任务 | 关联 spec | 关联 design | 语言 | 时间盒 | 状态 | 预计产出 |
|---|---|---|---|---|---|---|---|
| T-01 | 建 `skills/yuanbao-search/` 技能骨架与 SKILL.md | §5.4、§4.4 | §1.1.3、§2.4.1 | web | 15 min | [x] | 目录 + SKILL.md |
| T-02 | M1 TC3-HMAC-SHA256 签名模块（TS） | REQ-PD-001 | §2.5.1 | web | 30 min | [x] | `scripts/sign.ts` |
| T-03 | M2 检索编排（默认 gov/cnt 收敛/不携带 Mode） | REQ-PD-002/003/004/006 | §2.5.2 | web | 30 min | [x] | 请求构造与参数校验 |
| T-04 | M3 响应解析（`Pages` 二次 parse + 存在性防御） | REQ-PD-005 | §2.5.3 | web | 30 min | [x] | 解析器 |
| T-05 | M4 `score` 批次内归一化 + `vr` 不参与排序 | REQ-PD-016/017 | §2.5.4 | web | 20 min | [x] | 归一化函数 |
| T-06 | M5 可信度四因子合成器（档位降级链） | REQ-PD-010~013/018 | §2.5.5 | web | 40 min | [x] | 合成器 + reason |
| T-07 | M6 政策交叉验证器（2-gram Jaccard + `policy_no`） | REQ-PD-014/015 | §2.5.6 | web | 40 min | [x] | 验证器 + 索引 |
| T-08 | 错误分类处置与降级链（退避/脱敏/空集） | REQ-PD-030、§5.1.3 | §2.7.1、§3.3 | web | 30 min | [x] | 降级链路 |
| T-09 | CLI 契约：单行 JSON（含 `excluded[]`）+ 可观测 + 心跳 | §4.4、§6.2 | §2.7.2、§2.5.8 | web | 30 min | [x] | `scripts/yuanbao_search.ts` |
| T-10 | Python 降级版 `yuanbao_search.py`（同签名） | REQ-PD-033 | §2.7.2 | web | 40 min | [x] | 降级脚本 |
| T-11 | `--selftest` 自检入口 +【人工】连通性冒烟 | §4.4 第 5 条 | §2.5.7 Step 0 | web | 20 min | [x] | 自检输出 |
| T-12 | E1 扩展画像脚本：缺失字段经检索采集并标来源 | REQ-PD-020/021 | §1.3 E1 | web | 40 min | [x] | `build_enterprise_profile.ts/.py` |
| T-13 | E2 扩展匹配脚本：结论强制绑定 `policy_no` | REQ-PD-022 | §1.3 E2 | web | 30 min | [x] | `match_policy.ts/.py` |
| T-14 | 报告扩展：待核实单列 + 合规声明 + 适用范围 | REQ-PD-023/028、§6.4 | §2.8、§3.5 | web | 40 min | [x] | `generate_policy_report.ts/.py` |
| T-15 | E4 扩展落库：申报任务 `task_type`/`extra_data`/`deadline` | REQ-PD-025/029、§6.7 | §2.6.1 | web | 40 min | [x] | `save_to_db.ts/.py` |
| T-16 | E3 扩展巡检：元宝取数 + `--freshness`，保留 reviewer 门禁 | REQ-PD-026/027 | §1.3 E3 | web | 40 min | [x] | `update_policy_kb.ts/.py` |
| T-17 | 修复 beichen SKILL.md 失效降级链（`:6` `:162` `:166`） | REQ-PD-031 | §1.1.6 | web | 15 min | [x] | SKILL.md 三行 |
| T-18 | 编排层 SKILL.md：Step0–Step8 串联 + 策略复用 | REQ-PD-032、§5.3 | §2.5.7 | web | 30 min | [x] | `yuanbao-search/SKILL.md` 流程段 |
| T-19 | 产物落盘规范与落库失败保留 | §4.2 第 4 条 | §2.6.2 | web | 20 min | [x] | `output/` 四类产物 |
| T-20 | 端到端联调：3 次真实查询 + 来源可点开留证 | §4.6 第 3/4/5 条 | §2.5.7 | web | 40 min | [x] | 联调记录 + 截图 |
| T-21 | 复制 `github` 模板建 `yuanbao-policy` L3 工程骨架 | REQ-PD-040/043 | §1.1.4、§2.7.3 | cangjie | 20 min | [x] | `cjpm.toml`/`plugin.yaml`/`SKILL.md` |
| T-22 | 仓颉实现 M1–M6，诊断走 `eprintln` | REQ-PD-041 | §2.4.2、§2.7.3 | cangjie | 90 min | [x] | `src/main.cj` |
| T-23 | 【人工】`cjpm build` 出 exe + 宿主加载验证 | REQ-PD-040/041 | §4.2 | cangjie | 30 min | [x]（编译通过；宿主加载待【人工】） | `skill_yuanbao_policy.exe` |
| T-24 | 闭源分发验证：删 `src/` 仍可加载运行 | REQ-PD-042 | §4.3 | cangjie | 20 min | [ ] | 闭源分发包 |
| T-25 | 裁剪判定与回退：编译受阻时保轨一 | REQ-PD-044 | §5 R5/R6/R8 | — | 10 min | [x]（判定：不裁剪） | 裁剪结论 |
| T-26 | 演示材料：3 次真实查询录屏/截图 + `excluded[]` | §4.6 第 5 条 | §2.7.2 | — | 40 min | [~]（脚本已写，截图待【人工】） | 演示素材 |
| T-27 | 开源复用声明与 README（来源 + 本次新增点） | §4.6 第 9 条 | §1.2/§1.3 | — | 20 min | [x] | README 段落 |
| T-28 | 3 分钟路演稿（做了什么/为什么做/下一步） | §4.6 第 7 条 | §2.1 | — | 20 min | [~]（稿已写，演练计时待【人工】） | 路演稿 |
| T-29 | 【人工】社媒发布 + 提交页补链接（指定话题） | §4.6 第 6 条 | §2.1 | — | 20 min | [ ] | 发布链接 |
| T-30 | 【人工】16:00 前封板提交检查 | §4.6 第 1 条 | §5 R8 | — | 15 min | [ ] | 提交完成 |

---

## 任务依赖关系图

```
阶段 A 轨一内核（不可裁剪）
  T-01 ──▶ T-02 ──▶ T-03 ──▶ T-04 ──┐
                                    ├─▶ T-05 ─▶ T-06 ─▶ T-07 ─▶ T-08 ─▶ T-09 ─▶ T-11
  T-01 ─────────────────────────────┘                                    │
                                                        T-10（T-09 后并行）┘

阶段 B 闭环改造（依赖 T-11 自检通过）
  T-11 ──▶ T-12 ──▶ T-13 ──▶ T-14 ──▶ T-15 ──▶ T-19 ──▶ T-20
  T-11 ──▶ T-16 ─────────────────────────────────────────┘
  T-11 ──▶ T-17（独立，可与 T-12/T-13 并行）
  T-12..T-17 ──▶ T-18 ──▶ T-20

阶段 C 轨二 L3（可裁剪，与阶段 B 并行）
  T-21 ──▶ T-22 ──▶ T-23【人工】──▶ T-24 ──▶ T-20（可选并入演示）
                          └── 编译受阻 ──▶ T-25（裁剪，轨一不受影响）

阶段 D 赛事交付
  T-20 ──▶ T-26 ──▶ T-29【人工】──▶ T-30【人工】
  T-27 / T-28 可与 T-26 并行
```

- **关键前置链**：T-01 → T-02 → T-03 → T-04 → T-06 → T-07 → T-09 → T-11 → T-20（任何一环失败，轨一不成立）。
- **可并行**：T-10 与 T-12/T-13；T-17 与阶段 B 其余；阶段 C 整条与阶段 B 并行；T-27/T-28 与 T-26 并行。
- **阻塞点**：T-23（`cjpm build` 只能人工执行，AI 不得代跑）；T-29/T-30（社媒与提交只能人工）。
- **时间兜底**：15:00 封板时若阶段 C 未完成，走 T-25 裁剪，轨一仍完整交付。

---

## 任务详细说明（按编号展开）

### T-01 [建 `skills/yuanbao-search/` 技能骨架与 SKILL.md]

- **目标**：承载轨一脚本技能，形态对齐 `http-client` 既有约定（spec §5.4、§4.4）。
- **输入**：`skills/http-client/SKILL.md:1-9,18-23`；`skills/beichen-policy-assistant/scripts/` 目录布局。
- **步骤**：
  1. 建 `skills/yuanbao-search/{SKILL.md,scripts/}`。
  2. 写 frontmatter（`name: yuanbao-search`、`description` 说明"元宝搜索检索 + 可信度标注"、`license`、`metadata.{author,version,category}`）。
  3. SKILL.md 正文预留：CLI 用法、参数表、输出结构、错误处理与降级策略、自检入口（T-18 补流程段）。
  4. 声明 compatibility：`cli_execute` / `http_request` / `web_fetch`，Node ≥22.6，Python 3.8+。
- **产出物**：`skills/yuanbao-search/SKILL.md`、`skills/yuanbao-search/scripts/`。
- **验收**：frontmatter 字段与 `http-client/SKILL.md:1-9` 一致；目录可被宿主技能扫描识别。
- **风险**：SKILL.md 中不得出现 `web_search`（宿主 22 个内置工具无此项，`src/tool/tool_permission.cj:78-143`）。

### T-02 [M1 TC3-HMAC-SHA256 签名模块（TS）]

- **目标**：产出可复用签名头，密钥仅从 `.env` 读取（spec §4.3 第 1/2 条）。
- **输入**：`.env:265-266`（既有密钥对，实测可用）；design §2.5.1 精确参数表。
- **步骤**：
  1. `readEnv()` 逐行正则解析 `.env`（`^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$`）。
  2. 五步派生：`secretDate = HMAC("TC3"+SecretKey, date)` → `secretService = HMAC(secretDate,"wsa")` → `secretSigning = HMAC(secretService,"tc3_request")` → `signature = HMAC(secretSigning, stringToSign)` → 拼 `Authorization`。
  3. `canonicalRequest`：`POST` + `/` + query 空 + `content-type:application/json\nhost:{host}\n` + `SignedHeaders=content-type;host` + `SHA256(payload)`。
  4. 头集合：`Authorization` / `Content-Type` / `Host` / `X-TC-Action=SearchPro` / `X-TC-Version=2025-05-08` / `X-TC-Timestamp`。
  5. 密钥与中间派生值不写入任何产物、日志、异常。
- **产出物**：`skills/yuanbao-search/scripts/sign.ts`（导出 `buildHeaders(payload, secretId, secretKey)`）。
- **验收**：用该头调用 `SearchPro` 返回 HTTP 200 且 `Response.RequestId` 非空；产物目录 grep 不到密钥值片段（G7）。
- **风险**：`.env` 缺失密钥时以非零状态退出并提示"未配置云 API 密钥"，不得回退到硬编码。

### T-03 [M2 检索编排]

- **目标**：参数编排与硬约束落地（REQ-PD-002/003/004/006）。
- **输入**：T-02 签名头；spec §6.1 数据约束。
- **步骤**：
  1. 政策场景未指定领域时默认 `Industry=gov`、`Cnt=50`、透传时效窗（REQ-PD-002 a/b）。
  2. `Cnt` 非 {10,20,30,40,50} 时收敛到最接近的合法档位（REQ-PD-004）。
  3. `Site` 与 `Exclude` 互斥校验；`Exclude` 最多 5 个域名、`|` 分隔（REQ-PD-003）。
  4. **默认不携带 `Mode`**（G4）；`Deeplinks` 为可选开关（REQ-PD-005）。
  5. 查询词非空校验，长度上限 200 字符（spec §6.1 第 1 条）。
  6. 超时 5 秒（`AbortController`），指数退避重试至多 2 次。
- **产出物**：请求构造与参数校验函数，供 T-09 CLI 使用。
- **验收**：`--cnt 999` 被收敛为 50；默认 payload 中不含 `Mode`；不出现按 `Version` 分支启停能力的逻辑（G3）。
- **风险**：R3（`Mode=1` 旗舰版仅召回 1 条，design §5）。

### T-04 [M3 响应解析]

- **目标**：`Pages` 二次 parse + 字段存在性防御（REQ-PD-005、G6）。
- **输入**：`SearchPro` 响应；design §2.5.3。
- **步骤**：
  1. 取 `Response.Pages`，**每个元素先 `JSON.parse` 再取字段**（G6）。
  2. 按存在性提取：`title` / `url` / `site` / `date` / `passage` / `content` / `pics` / `favicon` / `score` / `authority_level` / `vr` / `deeplinks`。
  3. `url` 必填且必须为合法绝对 URL，缺失则该条丢弃并计入告警（spec §6.2 第 2 条）。
  4. `pics` / `deeplinks` 单条最多 10 项；`site` 为空保留空串（供 T-06 判最低档）。
  5. 取 `Response.Version`、`Response.RequestId`；错误取 `Response.Error.{Code,Message}`。
- **产出物**：解析器函数，输出结构对齐 spec §6.2 的 12 项。
- **验收**：任一字段整批缺失时解析不抛异常，缺失字段为 `undefined` 而非默认值 0（G2 前置）。
- **风险**：R2（`authority_level` 整批缺失）。

### T-05 [M4 `score` 归一化与排序]

- **目标**：消除量纲漂移影响（REQ-PD-016/017、G1）。
- **输入**：T-04 解析结果。
- **步骤**：
  1. 批次内 min-max：`(s-min)/(max-min)`；`max == min` 时返回 0.5。
  2. 跨批次合并时**各批先自行归一化再合并**（REQ-PD-016 b）。
  3. `vr=true` 且无 `score` 的条目置于排序序列之外并单独标注（REQ-PD-017）。
  4. 对外只输出 `scoreNorm` 与相对顺序，**不展示原始 `score` 绝对值**（spec §5.2.3 第 4 条）。
- **产出物**：归一化与排序函数。
- **验收**：代码中无 `score` 与字面常量比较，无跨批次直接比较（G1）；`vr` 条目单独成组。
- **风险**：R1（实测 0.75~5.46）。

### T-06 [M5 可信度四因子合成器]

- **目标**：把"信得过"机制化（REQ-PD-010~013/018）。
- **输入**：T-04/T-05 结果；design §2.5.5。
- **步骤**：
  1. 权威度档位：`authority_level ≥ 4` 高、`= 3` 中、`≤ 2` 低、字段缺失为**不可用**（实测值域 2~4）。
  2. 信源分级：`.gov.cn` 或政府序列 → 最高；已知门户/机构 → 中间；`site` 空或未知 → 最低（REQ-PD-012）。
  3. 时效档位：落在时效窗内 → 现行有效；早于 → 已过期；`date` 缺失 → 未知（REQ-PD-013）。
  4. 档位降级链：`base` 由信源分级决定；时效过期/未知 → `downgrade`；权威度低或不可用 → `downgrade`（高→中→低）。
  5. `reason` 必填，逐项列出四因子实际取值与判定依据（REQ-PD-018）。
  6. 权威度整批缺失时记录一条降级事件并继续（REQ-PD-011 b）。
- **产出物**：合成器函数，输出 `credibility.{authority,sourceTier,freshness,kbHit,status,level,reason}`。
- **验收**：无 `authority_level` 的批次仍产出完整标签且 `authority=不可用`、`reason` 中明示"本次服务档位未提供"（G2）。
- **风险**：R2；阈值以实测 2~4 为准，不得照抄官方 0~5 定义设阈值。

### T-07 [M6 政策交叉验证器]

- **目标**：`policy_no` 强绑定，"敢说不知道"落地（REQ-PD-014/015、G14）。
- **输入**：`skills/beichen-policy-assistant/knowledge/policy-index.json`（74 条）；design §2.5.6。
- **步骤**：
  1. 启动时一次性构建 2-gram 索引并复用（74 条规模可忽略构建耗时）。
  2. 归一化：全角转半角、去空白、去标点 `()（）【】[]《》·,.，。、/\:：;；'""`。
  3. Jaccard `J = |A∩B|/|A∪B|`；命中条件 `J ≥ 0.6` **或** 一方包含另一方且被包含长度 ≥ 80%。
  4. 命中 → 绑定 `policy_no` 并记录 `file` 路径（支撑"来源点得开"）；未命中 → 标注"未备案"。
  5. 索引不可解析 → `kbHit=库不可用`，**非最高档信源的结论一律待核实**（G14 v1.1）。
  6. 待核实项进 `excluded[]`，禁止进入正式报告（G5，报告侧由 T-14 收口）。
  7. 三级证据（2026-10-25 编码阶段实测增补）：标题 Jaccard ≥0.6 / 核心名重叠 ≥0.75（gram≥8）/ 正文出现政策全名（≥8 字）。
     依据：实测标题级最高仅 0.18，需靠重叠系数与正文引用兜住真实命中。
- **产出物**：验证器函数 + 索引缓存。
- **验收**：索引文件损坏模拟测试中，非政府信源条目全部 `status=待核实` 且无异常抛出（G14 v1.1）；
  正常索引下命中项 `policy_no` 绑定正确（实测样例：48=北京市高精尖产业发展项目资金管理办法、
  67=北京市支持专精特新中小企业高质量发展若干措施）。
- **风险**：R4（74 条均为北京政策，命中率有限）→ 由 T-14 的适用范围声明兜底。

### T-08 [错误分类处置与降级链]

- **目标**：单通道失败不中断整体（REQ-PD-030、spec §5.1.3、G11）。
- **输入**：T-03 请求、T-04 解析。
- **步骤**：
  1. `RequestLimitExceeded` → 指数退避重试至多 2 次 → 仍失败降级。
  2. `AuthFailure` / `UnauthorizedOperation` → **不重试**，输出"凭据无效"提示，**不回显服务端原始消息**（G7）。
  3. 资源未开通类 → 不重试，给出凭据与开通状态排查指引。
  4. 响应结构异常 / 空集 → 按空结果处理并记告警，**禁止抛异常中断调用方**。
  5. 降级目标：宿主内置 `http_request`（`src/tool/tool_permission.cj:143`）+ `multi-search-engine` 抓取通道；结果强制标注来源通道（`degraded: true`）。
  6. 双通道均失败 → 返回空集 + 双通道失败告警。
- **产出物**：错误分类与降级函数。
- **验收**：断网模拟下 CLI 仍返回单行 JSON（`ok:false` + `degraded:true`），退出码可控且不抛栈（G11）。
- **风险**：R7（配额阈值未知）→ 演示前预热。

### T-09 [CLI 契约：单行 JSON + 可观测 + 心跳]

- **目标**：对外接口稳定，上游调用不中断（spec §4.5 第 6 条、§4.4）。
- **输入**：T-02~T-08 全部模块。
- **步骤**：
  1. CLI：`--query`（必填）`--industry` `--freshness` `--site` `--exclude` `--cnt` `--deeplinks` `--selftest` `--json`。
  2. stdout **单行 JSON**：`ok` / `requestId` / `version` / `elapsedMs` / `degraded` / `items[]` / `excluded[]`；`items[]` 每项含可信度标签。
  3. `excluded[]` 显式列出未命中项及原因（"敢说不知道"的对外可见证据）。
  4. 每次检索记录 `RequestId` / `Version` / 条数 / 耗时；`Version=standard` 或权威度整批缺失时写降级事件（stderr）。
  5. 批量处理每 100 条向 stderr 输出一行心跳。
- **产出物**：`skills/yuanbao-search/scripts/yuanbao_search.ts`。
- **验收**：`node --experimental-strip-types yuanbao_search.ts --query "…" --json` 输出可被 `JSON.parse` 单行解析；`excluded[]` 非空时可见。
- **风险**：stdout 混入诊断会破坏解析 → 诊断一律 stderr。

### T-10 [Python 降级版]

- **目标**：双版本供给（REQ-PD-033、G12）。
- **输入**：T-09 TS 版（逐行为蓝本）。
- **步骤**：
  1. 新建 `scripts/yuanbao_search.py`，**CLI 签名与 TS 版逐字一致**。
  2. 用 `hmac` / `hashlib` 实现同五步派生；`urllib` 或 `requests` 出网。
  3. 输出结构与 TS 版逐字段对齐（`json.dumps(..., ensure_ascii=False)`）。
- **产出物**：`skills/yuanbao-search/scripts/yuanbao_search.py`。
- **验收**：同参数下两版 `items` 条数与 `policyNo` 绑定结果一致（允许 `elapsedMs` 不同）。
- **风险**：G12（缺任一版本即判回退）。

### T-11 [`--selftest` 自检与【人工】冒烟]

- **目标**：不触发完整闭环即可验证连通性与档位（spec §4.4 第 5 条）。
- **输入**：T-09。
- **步骤**：
  1. 实现 `--selftest`：发一次最小查询，输出连通性、`Version`、`authority_level` 可用性、`Pages` 条数、耗时。
  2. 【人工】执行：`node --experimental-strip-types scripts/yuanbao_search.ts --selftest`，回传输出。
  3. 【人工】执行 Python 版同命令，确认双版一致。
- **产出物**：自检输出记录（贴入本文「修订记录」）。
- **验收**：`--selftest` 返回 HTTP 200 且打印 `version` 与字段可用性矩阵；两版均通过后方可进入阶段 B。
- **风险**：R7 配额超限 → 预热重试；如持续 `AuthFailure` 需人工核对 `.env` 密钥有效性。

### T-12 [E1 扩展画像脚本]

- **目标**：缺失字段经检索采集并标来源，禁止编造（REQ-PD-020/021）。
- **输入**：`build_enterprise_profile.ts:1-6`（CLI `--company "名称"`）；T-09 检索能力。
- **步骤**：
  1. 保留原有 CLI 与输出结构，仅扩展：外部信息不可用时调用 `yuanbao_search` 采集（`--industry news`）。
  2. 每条属性新增 `source` 字段记录采集通道（检索 / 原接口 / 空）。
  3. 未获取字段留空并标记，`禁止`填充推测值（spec §6.5 第 2 条）。
  4. `--company` 为空时以非零状态退出并提示"企业名称为必填项"（spec §5.3.3 第 1 条）。
  5. TS / PY 双版同改（G12）。
- **产出物**：`build_enterprise_profile.ts` / `.py`。
- **验收**：断网模拟下画像仍产出，字段标记"未获取"，流程不中断；`source` 字段齐全。
- **风险**：不得改写脚本其它段落（开发规范 §3.5）。

### T-13 [E2 扩展匹配脚本]

- **目标**：匹配结论强制绑定 `policy_no`（REQ-PD-022）。
- **输入**：`match_policy.ts:1-7`（CLI `--profile {画像json} [--topn 10]`）；T-07 验证器。
- **步骤**：
  1. 匹配输出每项新增 `policy_no`；无法绑定者**不作为匹配结论输出**，转入待核实集合。
  2. 保留 `--topn` 与规则打分（无 LLM 时仍可用，REQ-PD-024）。
  3. TS / PY 双版同改。
- **产出物**：`match_policy.ts` / `.py`。
- **验收**：输出 `matches[]` 中 `policy_no` 非空率 100%；无编号项出现在独立的 `pending` 集合中。
- **风险**：R4 命中率低 → 不得为凑数放宽阈值（J ≥ 0.6 是硬阈值）。

### T-14 [报告扩展：待核实单列 + 声明]

- **目标**：报告合规且"敢说不知道"可见（REQ-PD-023/028、§4.6 第 3 条、G5/G15）。
- **输入**：`generate_policy_report.ts:1-6`（CLI `--profile --matches`）；T-07。
- **步骤**：
  1. 报告渲染前**过滤** `status == 待核实` 的条目（G5）。
  2. 单列「未查到可靠依据」章节，逐条列出 `excluded[]` 的标题与原因。
  3. 报告固定附"仅供申报参考，不构成法律意见"（REQ-PD-028）。
  4. 报告开头明示适用范围：本知识库为北京地区政策（74 条），禁止让用户误认为全国通用（G15）。
  5. 每条结论附可点击来源链接（`url` + 政策原文 `file` 路径）（§4.6 第 4 条）。
  6. TS / PY 双版同改。
- **产出物**：`generate_policy_report.ts` / `.py`；`output/reports/{slug}.md`。
- **验收**：报告中无待核实结论；含合规声明、适用范围声明；每条结论链接可点开。
- **风险**：内容边界——只做客观检索与条件比对，不做政策解读或倾向性评价（§4.6 第 8 条）。

### T-15 [E4 扩展落库脚本]

- **目标**：申报任务与报告落既有表（REQ-PD-025/029、G9）。
- **输入**：`save_to_db.ts:68-69,78-87`；`sql/uctooDB.sql:1824,7488`。
- **步骤**：
  1. 保留 `company` 的 UPDATE + INSERT ... WHERE NOT EXISTS upsert（`org_type='beichen-enterprise'`）。
  2. `tasks` 新增 `task_type='policy-apply'`：`extra_data`（jsonb）存材料清单，`deadline` 存截止时间，`task_status` 存跟进状态（待启动/进行中/已完成/已终止）。
  3. `deadline` 为空时写入 Null 并在产物中明示"截止时间未知"（spec §6.7 第 4 条）。
  4. **禁止出现 `CREATE TABLE`**（G9）；如需新列，走 `sql/incremental/` 增量脚本并论证复用不成立。
  5. 保留 `--sql-only`；连接失败时生成 SQL 文件并保留产物（spec §5.3.3 第 4 条）。
  6. TS / PY 双版同改。
- **产出物**：`save_to_db.ts` / `.py`；`output/sql/*.sql`。
- **验收**：`task_type` 仅出现 `policy-match` / `policy-apply` 两类；落库 SQL 中无建表语句。
- **风险**：G9；psycopg2 缺失时 PY 版走 `--sql-only`。

### T-16 [E3 扩展巡检脚本]

- **目标**：元宝取数 + 时效窗 + 保留人工门禁（REQ-PD-026/027、G10/G13）。
- **输入**：`update_policy_kb.ts:1-10`（`--sources default` / `--demo` / `--commit --date --reviewer`）；T-09。
- **步骤**：
  1. 新增 `--sources yuanbao --freshness <窗>`：调用 `yuanbao_search --industry gov --freshness …`，结果写 `output/pending/{date}.json`，状态 `待研判`。
  2. 待研判条目必带 `url` / `发现时间` / `来源请求标识`（spec §6.8）。
  3. 单源失败**记录失败条目并继续**，禁止 `break` 或回滚（G13）。
  4. 保留 `--commit --date --reviewer` 门禁：`reviewer` 为空直接拒绝并保持待研判（G10）。
  5. 采纳时记录 `reviewer` 与时间（spec §4.3 第 3/4 条）。
  6. TS / PY 双版同改。
- **产出物**：`update_policy_kb.ts` / `.py`；`output/pending/{date}.json`。
- **验收**：缺 `--reviewer` 时拒绝入库且条目仍为待研判；多源巡检中人为让一源失败，其余源结果仍写入。
- **风险**：G13；巡检单次 ≤ 5 分钟（spec §4.1 第 3 条）。

### T-17 [修复 beichen SKILL.md 失效降级链]

- **目标**：把指向不存在工具的降级链改指真实能力（REQ-PD-031）。
- **输入**：`skills/beichen-policy-assistant/SKILL.md:6,:162,:166`（三处引用 `web_search`）；`src/tool/tool_permission.cj:78-143`（22 个内置工具无 `web_search`）。
- **步骤**：
  1. `:6` compatibility 声明去掉 `web_search`，改为 `http_request` / `web_fetch` + `yuanbao-search`。
  2. `:162` "画像降级为 web_search 采集" 改为"经 `yuanbao-search` 检索采集，未获取字段留空并标注来源"。
  3. `:166` "换 web_search / web_fetch 采集" 改为"换 `yuanbao-search` / `web_fetch` 采集"。
  4. 复核全库 `skills/` 其它文档是否还有同类死链（同批登记，不改代码）。
- **产出物**：`skills/beichen-policy-assistant/SKILL.md` 三行改动。
- **验收**：`beichen-policy-assistant` 文档内 grep `web_search` 零命中；降级链指向的脚本真实存在。
- **风险**：只改文档不改脚本逻辑，避免牵动既有流程。

### T-18 [编排层 SKILL.md：Step0–Step8]

- **目标**：流程串联与策略复用（REQ-PD-032、§5.3）。
- **输入**：design §2.5.7 Step 0–8；`multi-search-engine/SKILL.md:29,37,46`。
- **步骤**：
  1. 在 `yuanbao-search/SKILL.md` 写 Step0 自检 → Step1 画像 → Step2 检索 → Step3 可信度 → Step4 匹配 → Step5 报告 → Step6 落库 → Step7 巡检 → Step8 研判。
  2. 明确每步调用的具体脚本与 CLI 参数（可直接复制执行）。
  3. 保留聚合、限速与重试策略并注明来源（REQ-PD-032 a）。
  4. 写明"元宝不可用时回退抓取通道，结果标注 `degraded`"。
- **产出物**：`skills/yuanbao-search/SKILL.md` 流程段。
- **验收**：照 SKILL.md 从头执行可跑通全链路；每一步的命令可直接粘贴运行。
- **风险**：完整闭环 ≤ 3 分钟，超出先返回阶段性结果（spec §4.1 第 4 条）。

### T-19 [产物落盘与落库失败保留]

- **目标**：产物可复核、落库失败不丢数据（spec §4.2 第 4 条、§4.4 第 4 条）。
- **输入**：T-12~T-16 产物。
- **步骤**：
  1. 规范 `output/` 四类产物：`profiles/{slug}.json`、`matches/{slug}.json`、`reports/{slug}.md`、`pending/{date}.json`（`sql/` 为既有过路目录，保留）。
  2. 落库失败时产物**必须保留**，输出提示"落库失败，已生成产物文件"（spec §5.3.3 第 4 条）。
  3. 产物中不得包含密钥（G7）。
- **产出物**：`output/` 目录规范 + 失败保留分支。
- **验收**：断开数据库后跑全流程，四类产物齐全且流程不中断。
- **风险**：产物路径与 beichen 既有脚本一致，避免两套目录。

### T-20 [端到端联调与留证]

- **目标**：3 次真实查询打通全链路并留证（§4.6 第 3/4/5 条）。
- **输入**：T-11~T-19 全部产出。
- **步骤**：
  1. 【人工】执行 3 次不同企业的真实查询（画像 → 检索 → 可信度 → 匹配 → 报告 → 落库）。
  2. 每次记录：`RequestId`、`Version`、条数、耗时、`items` 与 `excluded[]` 条数。
  3. 验证每条结论的来源链接可点开、每条匹配结论带 `policy_no`。
  4. 覆盖 1 条异常：知识库索引临时改名 → 全部结论置待核实且流程不中断（G14）。
  5. 截图/录屏留证（演示素材，交 T-26）。
- **产出物**：联调记录（贴入「修订记录」）+ 截图。
- **验收**：3 次查询全部HTTP 200；`excluded[]` 非空（证明敢说不知道）；异常用例行为符合 G14。
- **风险**：R7 配额 → 三次查询间隔预热。

### T-21 [L3 工程骨架]

- **目标**：建立可独立编译的 L3 工程（REQ-PD-040/043）。
- **输入**：`skills/github/cjpm.toml`、`plugin.yaml`、`src/main.cj:12-27`。
- **步骤**：
  1. 复制 `github` 模板为 `skills/yuanbao-policy/`，改 `name=yuanbao-policy`、`command=./skills/yuanbao-policy/target/release/bin/skill_yuanbao_policy.exe`。
  2. `cjpm.toml`：`cjc-version="1.1.3"`、`output-type="executable"`、`compile-option="-O2 --dy-std -Woff all"`，依赖照抄并加 `bin-dependencies` 指向 `libs/cangjie-stdx-windows-x64-1.1.3.1/.../stdx`。
  3. `plugin.yaml`：`mode: process`、`enabled: true`、`autoRestart: true`、`order` 顺延；保留 `#region AutoCreateCode` 保护区。
  4. 补 `SKILL.md`（模型行为契约，REQ-PD-043）。
- **产出物**：`skills/yuanbao-policy/{cjpm.toml,plugin.yaml,SKILL.md,src/}`。
- **验收**：三文件内容与 `github` 范本同构，仅 name/command/依赖不同。
- **风险**：R6（cjc 1.1.3 TLS breaking change）→ 出网按 1.1.3 新包名/字段名写。

### T-22 [仓颉实现 M1–M6]

- **目标**：L3 轨与脚本轨共用同一套判定规则（REQ-PD-041、design §2.4.3）。
- **输入**：T-02~T-07 的规则定义；`stdx.crypto.digest`（先例 `src/scripts/package_release/main.cj:18`）。
- **步骤**：
  1. **先加载 `cangjie-coder` 技能**再写 `.cj` 代码。
  2. 实现签名（`stdx.crypto.digest` 的 HMAC-SHA256）、请求（`stdx.net.http` / `stdx.net.tls`）、解析、归一化、可信度合成、交叉验证。
  3. `PluginRuntime.run("yuanbao-policy", inject, provide, { ctx => 注册 handler })`，照 `github/src/main.cj:17-26`。
  4. **诊断一律 `eprintln`**，stdout 只允许 JSON-RPC 帧（G8）。
  5. 规则与 TS 版逐条对齐，保证双轨行为一致。
- **产出物**：`skills/yuanbao-policy/src/main.cj`。
- **验收**：`main.cj` 中 grep 无 `println`（G8）；规则分支与 T-06/T-07 一致。
- **风险**：R5（仓颉侧 `stdx.net.http` 零先例）→ 编译受阻走 T-25 裁剪。

### T-23 [【人工】编译与加载验证]

- **目标**：产出可执行文件并被宿主加载（REQ-PD-040/041）。
- **输入**：T-21/T-22。
- **步骤**：
  1. 【人工】`cd skills/yuanbao-policy && cjpm build`，回传日志（AI 只分析修复）。
  2. 确认 `target/release/bin/skill_yuanbao_policy.exe` 存在。
  3. 【人工】启动宿主，确认插件被扫 `plugin.yaml` 注册并完成能力宣告。
  4. 缺 DLL 时按既有做法补齐（exe 同目录 + 四路 DLL）。
- **产出物**：`skill_yuanbao_policy.exe` + 加载日志。
- **验收**：宿主日志出现该插件注册；一次检索经插件返回结构化结果与可信度标签。
- **风险**：R5/R6；AI 不代跑 `cjpm build`。

### T-24 [闭源分发验证]

- **目标**：证明不含源码仍可安装运行（REQ-PD-042，绝活演示）。
- **输入**：T-23 产物。
- **步骤**：
  1. 复制分发目录，**删除 `src/`**，仅留 exe + `plugin.yaml` + `SKILL.md`。
  2. 【人工】宿主加载该目录，执行一次检索。
  3. 截图：目录树（无 `src/`）+ 检索成功输出。
- **产出物**：闭源分发包 + 验证截图。
- **验收**：无 `src/` 目录时插件照常加载并返回值；对照说明脚本型技能（JS/Python 必须明文）做不到。
- **风险**：exe 依赖 DLL 必须一并分发，否则启动即失败回退脚本轨（§5.5.3 第 3 条）。

### T-25 [裁剪判定与回退]

- **目标**：L3 轨缺失不影响轨一完整交付（REQ-PD-044）。
- **输入**：T-23 编译结果。
- **步骤**：
  1. 若 T-23 失败且 15:00 临近 → 判定裁剪，`plugin.yaml` 置 `enabled: false`（或整体不纳入提交）。
  2. 确认脚本轨（T-01~T-20）在 L3 关闭状态下功能完整。
  3. 未完成的 L3 工程文件本身保留为工程证据（spec §5.5 说明）。
- **产出物**：裁剪结论 + 轨一完整性确认记录。
- **验收**：L3 关闭时，`yuanbao_search.ts --selftest` 与完整闭环均正常。
- **风险**：R8 时间紧，裁剪决策不得晚于 15:00。

### T-26 [演示材料]

- **目标**：≥ 3 次真实查询的录屏或截图，含可点开来源（§4.6 第 5 条）。
- **输入**：T-20 联调留证；T-24 闭源截图（若有）。
- **步骤**：
  1. 整理 3 次查询的完整过程（命令 → 结果 → `excluded[]` → 可点开链接）。
  2. 单独一屏展示"未查到可靠依据"（`excluded[]`）——这是"敢说不知道"的直接证据。
  3. 若有 L3 轨，加一屏"删掉 `src/` 照样跑"的闭源对比。
- **产出物**：录屏 / 截图集（≥ 3 次查询）。
- **验收**：每次查询均含结果与可点开来源；至少一屏明确展示"未查到可靠依据"。
- **风险**：内容禁区——不涉时政评论与特定个人（§4.6 第 8 条）。

### T-27 [开源复用声明与 README]

- **目标**：注明复用来源与本次新增点（§4.6 第 9 条）。
- **输入**：design §1.2/§1.3（复用 12 / 扩展 5 / 新建 6）。
- **步骤**：
  1. 写明复用 `beichen-policy-assistant` 的三层知识库与其脚本链，标注来源。
  2. 写明本次新增：元宝检索内核、可信度四因子、`policy_no` 强制溯源、L3 闭源轨。
  3. 补 `yuanbao-search/README.md` 与 `yuanbao-policy/README.md`（若有）。
- **产出物**：README 段落 / 新增 README。
- **验收**：复用项与新增项逐条可对照 design §1.2/§1.3，无遗漏。
- **风险**：不得含密钥或内部路径敏感信息。

### T-28 [3 分钟路演稿]

- **目标**：3 分钟讲清"做了什么、为什么做、下一步"（§4.6 第 7 条）。
- **输入**：design §2.1 五个设计目标；T-26 素材。
- **步骤**：
  1. 结构：痛点（政策查得到但不敢信）→ 做什么（检索内核替换 + 四因子可信度 + 强制溯源）→ 为什么（查不到敢说不知道）→ 绝活（L3 闭源分发）→ 下一步。
  2. 每屏对应一张截图，控制在 6~8 屏。
  3. 计时演练一次，超 3 分钟则压缩。
- **产出物**：路演稿（含计时）。
- **验收**：演练 ≤ 3 分钟；评审四维度（完成度 30% / 创意 25% / 场景 25% / 展示 20%）均有对应内容。
- **风险**：不得弱化"敢说不知道"这一核心竞争力。

### T-29 [【人工】社媒发布与链接回填]

- **目标**：完成公开发布（评奖必要条件，§4.6 第 6 条）。
- **输入**：T-26 素材、T-27 声明。
- **步骤**：
  1. 【人工】发布到小红书或视频号，附话题标签：`#元宝搜索` `#WaytoAGI` `#AI切磋大会` `#1024超能Coding周末`。
  2. 【人工】把链接回填到作品提交页（侦探赛道链接可补填至 10/25 23:59，作品本体不延后）。
  3. 内容不涉时政与特定个人。
- **产出物**：发布链接 + 提交页回填记录。
- **验收**：公开可访问；四个话题标签齐全；提交页已填链接。
- **风险**：未完成分享则不具备赛道评优资格——此项为硬门槛。

### T-30 [【人工】封板提交检查]

- **目标**：16:00 前完成提交（§4.6 第 1 条）。
- **输入**：T-01~T-29 全部产出。
- **步骤**：
  1. 15:00 封板：冻结代码与文档，执行本文件「验收检查清单」终检。
  2. 15:00—16:00 提交：确认作品本体、演示材料、开源声明齐备。
  3. 若社媒链接未就绪，利用 23:59 前补填通道（仅链接，不延后本体）。
- **产出物**：提交完成确认。
- **验收**：提交记录时间戳 ≤ 16:00；清单全部勾选或已标注豁免。
- **风险**：R8；超时即失去评奖资格。

---

## 需求覆盖追踪矩阵

### 功能需求（spec 附录 A，35 条）

| 需求编号 | 需求 | 覆盖任务 | 状态 | 备注 |
|---|---|---|---|---|
| REQ-PD-001 | 检索通道唯一化 | T-02, T-03, T-09 | 全覆盖 | 不走结果页抓取为主通道 |
| REQ-PD-002 | 政策场景默认编排 | T-03 | 全覆盖 | 默认 gov + cnt50 + 时效窗透传 |
| REQ-PD-003 | 信源限定与排除 | T-03 | 全覆盖 | Site/Exclude 互斥，Exclude ≤5 |
| REQ-PD-004 | 结果条数上限收敛 | T-03 | 全覆盖 | 收敛到 {10,20,30,40,50} |
| REQ-PD-005 | 子链可选获取 | T-03, T-04 | 全覆盖 | 缺失不视为错误 |
| REQ-PD-006 | 禁止依赖低召回模式 | T-03 | 全覆盖 | 默认不携带 Mode |
| REQ-PD-010 | 权威度分档 | T-06 | 全覆盖 | 阈值按实测 2~4 |
| REQ-PD-011 | 权威度缺失降级 | T-06, T-09 | 全覆盖 | 记降级事件并继续 |
| REQ-PD-012 | 信源分级 | T-06 | 全覆盖 | .gov.cn → 最高 |
| REQ-PD-013 | 时效判定（含缺失） | T-06 | 全覆盖 | date 缺失 → 未知并下调 |
| REQ-PD-014 | 事实交叉验证 | T-07 | 全覆盖 | 2-gram Jaccard ≥ 0.6 |
| REQ-PD-015 | 无出处禁止入册 | T-07, T-14 | 全覆盖 | v1.1 可核验出处门禁；待核实进 excluded[] |
| REQ-PD-016 | 相关性仅同批排序 | T-05 | 全覆盖 | 批次内 min-max |
| REQ-PD-017 | vr 条目不参与排序 | T-05 | 全覆盖 | 单独标注 |
| REQ-PD-018 | 可解释性 | T-06 | 全覆盖 | reason 必填 |
| REQ-PD-019 | 溯源信息保留 | T-04, T-09 | 全覆盖 | url/site/date/requestId |
| REQ-PD-020 | 企业画像（禁编造） | T-12 | 全覆盖 | 空字段留空标记 |
| REQ-PD-021 | 画像字段缺失降级 | T-12 | 全覆盖 | 改用检索采集并标来源 |
| REQ-PD-022 | 政策匹配（绑定编号） | T-13 | 全覆盖 | 无编号不输出 |
| REQ-PD-023 | 适配报告（含声明） | T-14 | 全覆盖 | 条件对标 + 缺口 + 声明 |
| REQ-PD-024 | 无 LLM 时降级 | T-13, T-14 | 全覆盖 | 规则打分 + 模板 |
| REQ-PD-025 | 申报任务生成 | T-15 | 全覆盖 | 材料清单 + 截止时间 |
| REQ-PD-026 | 政策库巡检 | T-16 | 全覆盖 | 元宝取数进储备库 |
| REQ-PD-027 | 研判门禁 | T-16 | 全覆盖 | 缺 reviewer 拒绝 |
| REQ-PD-028 | 合规声明 | T-14 | 全覆盖 | 报告固定附声明 |
| REQ-PD-029 | 结果落库 | T-15, T-19 | 全覆盖 | 复用既有表 |
| REQ-PD-030 | 检索内核切换 | T-08, T-18 | 全覆盖 | 失败回退抓取通道 |
| REQ-PD-031 | 无效降级点修复 | T-17 | 全覆盖 | SKILL.md:6/162/166 |
| REQ-PD-032 | 聚合与限速保留 | T-18 | 全覆盖 | 复用 multi-search-engine 策略 |
| REQ-PD-033 | 双版本脚本供给 | T-10, T-12~T-16 | 全覆盖 | TS + PY 同签名 |
| REQ-PD-040 | 独立工程形态 | T-21, T-23 | 全覆盖 | L3 可执行产物 |
| REQ-PD-041 | 进程隔离运行 | T-21, T-22, T-23 | 全覆盖 | stdio JSON-RPC |
| REQ-PD-042 | 闭源分发支持 | T-24 | 全覆盖 | 删 src/ 仍运行 |
| REQ-PD-043 | 模型行为契约 | T-21 | 全覆盖 | SKILL.md 行为说明 |
| REQ-PD-044 | 裁剪不影响主链路 | T-25 | 全覆盖 | 轨一独立可用 |

### DFX 约束（spec §4）

| 约束 | 覆盖任务 | 状态 | 备注 |
|---|---|---|---|
| §4.1-1 单次检索 ≤5s | T-03, T-11 | 全覆盖 | AbortController 5s + 自检记录耗时 |
| §4.1-2 单条标注 ≤50ms | T-06, T-11 | 全覆盖 | 50 条批处理 ≤2.5s |
| §4.1-3 巡检 ≤5min | T-16, T-20 | 全覆盖 | 联调计时 |
| §4.1-4 闭环 ≤3min | T-18, T-20 | 全覆盖 | 超时返回阶段性结果 |
| §4.2-1 检索失败降级 | T-08 | 全覆盖 | 不整体中断 |
| §4.2-2 权威度缺失降级 | T-06 | 全覆盖 | 三因子继续 |
| §4.2-3 巡检失败不回滚 | T-16 | 全覆盖 | 记失败继续 |
| §4.2-4 落库失败保留产物 | T-15, T-19 | 全覆盖 | 供人工重试 |
| §4.2-5 重试 ≤2 次退避 | T-03, T-08 | 全覆盖 | 指数退避 |
| §4.3-1 凭据仅从环境读取 | T-02 | 全覆盖 | 禁止硬编码 |
| §4.3-2 签名密钥不落盘 | T-02, T-09 | 全覆盖 | 产物不含密钥 |
| §4.3-3 知识库写入留痕 | T-16 | 全覆盖 | 操作人 + 时间 |
| §4.3-4 研判必须署名 | T-16 | 全覆盖 | 缺省拒绝 |
| §4.3-5 不采集无关隐私 | T-12 | 全覆盖 | 画像字段范围收敛 |
| §4.4-1 记录请求标识与版本 | T-09 | 全覆盖 | RequestId/Version/条数/耗时 |
| §4.4-2 标签附理由 | T-06 | 全覆盖 | reason 必填 |
| §4.4-3 降级事件日志 | T-06, T-09 | 全覆盖 | standard 或字段缺失时记 |
| §4.4-4 产物持久化 | T-19 | 全覆盖 | 四类产物 |
| §4.4-5 独立自检入口 | T-11 | 全覆盖 | `--selftest` |
| §4.5-1 兼容版本波动 | T-06, T-09 | 全覆盖 | 不作能力开关 |
| §4.5-2 兼容字段缺失 | T-04, T-06 | 全覆盖 | 存在性校验 |
| §4.5-3 兼容标准版能力 | T-06 | 全覆盖 | 无权威度仍交付 |
| §4.5-4 不依赖 Mode=1 | T-03 | 全覆盖 | 默认不携带 |
| §4.5-5 参数向后兼容 | T-09, T-18 | 全覆盖 | 新增可选参数不改旧行为 |
| §4.5-6 上游接口稳定 | T-09, T-17, T-18 | 全覆盖 | 内核切换不中断调用 |
| §4.6-1 16:00 前提交 | T-30 | 全覆盖 | 15:00 封板 |
| §4.6-2 搜索必须为核心 | T-01~T-09, T-26 | 全覆盖 | 去掉即转不起来 |
| §4.6-3 必须敢说不知道 | T-07, T-14, T-26 | 全覆盖 | `excluded[]` 可见 |
| §4.6-4 来源可点开 | T-04, T-14, T-20 | 全覆盖 | 每条结论带 URL |
| §4.6-5 演示 ≥3 次真实查询 | T-20, T-26 | 全覆盖 | 录屏/截图 |
| §4.6-6 社媒分享（获奖必要） | T-29 | 全覆盖 | 【人工】四话题标签 |
| §4.6-7 路演 ≤3 分钟 | T-28 | 全覆盖 | 计时演练 |
| §4.6-8 内容禁区 | T-14, T-26, T-29 | 全覆盖 | 不做政策解读评价 |
| §4.6-9 开源复用声明 | T-27 | 全覆盖 | 来源 + 新增点 |

---

## 验收检查清单（终验）

### A. 功能与需求

- [ ] spec 35 条功能需求全部有对应实现并通过其 59 条验收条件
- [ ] DFX 约束（性能 / 可靠 / 安全 / 可维护 / 兼容）已验证或标注豁免
- [ ] spec / design / tasks 三份文档与最终实现一致（无漂移）

### B. 红线自检（G1–G15 逐条 grep / 运行验证）

- [ ] G1 代码中无 `score` 字面阈值与跨批次比较
- [ ] G2 `authority_level` 全部取用处有存在性校验与降级分支
- [ ] G3 无按 `Version == "flagship"` 启停能力的逻辑
- [ ] G4 默认 payload 无 `Mode = 1`
- [ ] G5 报告渲染处过滤 `status == 待核实`（门禁口径为 v1.1 可核验出处，非"未绑编号"）
- [ ] G6 `Pages` 元素已二次 `JSON.parse`
- [x] G7 产物目录与日志 grep 不到密钥值片段（实测 `output/` 扫描 0 命中）
- [x] G8 L3 `src/main.cj` 无 `println`（诊断走 `eprintln`）
- [x] G9 全部 SQL 无 `CREATE TABLE`（实测 `grep -c "CREATE TABLE"` = 0）
- [x] G10 `--commit` 路径有 `reviewer` 非空校验（实测缺参拒绝且条目保持待研判）
- [x] G11 检索失败处有降级分支、不直接抛出（画像补采、巡检、检索三处均记录后继续）
- [x] G12 每个改动脚本 TS / PY 双版本齐全且签名一致
- [x] G13 巡检循环无失败即 `break` / 回滚（实测失败源登记后继续）
- [x] G14 索引解析失败时「非最高档信源」结论置"待核实"（实测 7 条被排除、退出码 0）
- [x] G15 报告含适用范围说明（北京地区 74 条，非全国通用）

### C. 复用与边界

- [x] 未重写 HTTP 客户端（复用 `http_client.ts`，仅传签名头）
- [x] 未新建数据库表（仅 `company` / `tasks`）
- [x] 未修改宿主 `src/`
- [x] `beichen-policy-assistant` 改动限于 E1–E5 + T-17 三行文档
- [x] `web_search` 在本次交付文档中零命中

### D. 编译与执行（【人工】）

- [x] 【人工】`node --experimental-strip-types yuanbao_search.ts --selftest` 通过（TS 版）
- [x] 【人工】`python yuanbao_search.py --selftest` 通过（PY 版）
- [x] 【人工】`cjpm build` 通过（T-23）—— 2026-10-25 09:54 四轮修复后 0 errors，`target/release/bin/skill_yuanbao_policy.exe` 已产出（1.8 MB）
- [x] 【人工】端到端 3 次真实查询留证完成（见「T-12~T-20 实测记录」）

### E. 跨边界冒烟（≥3 主干 + 1 异常）

- [x] 主干 1：`yuanbao-search` → `build_enterprise_profile` 画像产出且字段带 `source`
- [x] 主干 2：`yuanbao-search` → `match_policy` 结论 `policy_no` 非空率 100%
- [x] 主干 3：`generate_policy_report` → `save_to_db` 报告入库且 `task_type` 正确
- [x] 异常 1：知识库索引不可读 → 全部结论置"待核实"、流程不中断、退出码可控
- [x] 异常 2（附加）：无 `--reviewer` 的 `--commit` → 拒绝入库且条目保持待研判

### F. 赛事交付

- [ ] 16:00 前完成提交（15:00 封板）
- [ ] 演示材料含 ≥3 次真实查询与可点开来源
- [ ] 至少一屏展示"未查到可靠依据"
- [ ] 社媒已发布并附四个指定话题标签，提交页已回填链接
- [ ] 路演演练 ≤3 分钟
- [ ] 开源复用声明齐备

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动内容 | 验证结果 |
|---|---|---|---|---|
| 2026-10-25 | R1 | SDD 流程第 4 步（task） | 初版 tasks.md：30 任务 / 依赖图 / 覆盖矩阵（35 REQ + 34 条 DFX）/ 终验清单 | 六节齐全；无占位符；与 spec 35 需求、design 15 条防回退逐条对齐 |
| 2026-10-25 | R2 | 编码阶段实测（T-01~T-11 已实现） | 结论状态门禁改为**可核验出处**（用户拍板）；交叉验证增补三级证据；同步修订 spec v1.1 / design v1.1 / SKILL.md / 本文件 T-07、G5、G14、矩阵 REQ-PD-015 | 实测：50 条真实结果由 0 可采信变为 20 可采信 / 10 待核实（cnt=30）；TS 与 PY 双版输出逐字段一致 |
| 2026-10-25 | R3 | 【人工】L3 编译四轮回传（T-23） | `cjpm build` **0 errors** 通过，`skill_yuanbao_policy.exe`（1.8 MB）已产出；T-21/T-22/T-23（编译段）与 T-25（判定**不裁剪**）回写为完成；T-24（宿主加载 + 闭源分发）与 T-26~T-30 仍待推进 | 四轮根因：① `init` 是关键字（`PolicyKb.init(` 7 处）；② `match` 是关键字（改名 `matchPolicy` 2 处）；③ `HashMap[key]` 返回 `V` 非 `Option`（10 处改 `.get()`）；④ `Array<Rune>(n,{i=>…})` 的 lambda 不能捕获 `var`（`transport.cj:78` 固化 `atFixed`） |
| 2026-10-25 | R4 | AI 文档侧产出（T-21 补漏 / T-26 / T-27 / T-28） | 补 `skills/yuanbao-policy/SKILL.md`（REQ-PD-043 漏项）；新建 `presentation/{demo-script,pitch-3min,open-source-declaration}.md`；新建 `skills/yuanbao-search/README.md` 与 `skills/yuanbao-policy/README.md`（开源复用声明 12 复用 / 5 扩展 / 6 新建） | **仍待【人工】**：T-23 宿主加载、T-24 闭源验证、T-26 八屏截图、T-28 计时演练、T-29 社媒四标签、T-30 提交。SKILL.md 契约与 `handlers.cj` 实际实现逐字对齐（含能力边界：不支持 site/exclude/deeplinks、时效按年份近似） |
| 2026-10-25 | R5 | 环境修复后【AI 实跑】端到端复测（T-12~T-20） | ① 开发环境 runtime 恢复：`magic.app` 监听 443，`GET https://javatoarktsapi.uctoo.com/hello` → HTTP 200 `{"message":"Hello World"}`；② `yuanbao_search.ts --selftest` 通过：flagship 档位、10 条返回、**8 可采信 / 2 排除**、原文库 74 条可用、首条命中原文库（policy_no=61，标题相似度 0.82）；③ 闭环三段跑通：画像 → 匹配（10 条，`policy_no_coverage=1.0`，`bound_from_search=0`）→ 报告（90 行 md，含「适用范围（务必阅读）」章节） | **实测暴露的能力边界（如实记录，未粉饰）**：① 画像 LLM 萃取连续 HTTP 429（TokLens 共享 RPM 限流）→ 降级规则组装，7 个字段如实标「未获取」**未编造**；② 因画像为空，报告 10 条政策匹配度均为 30、依据为「层级·领域」粗粒度、来源列为空 ⇒ 报告可作为降级样例，但**不宜作为主演示素材**；③ 通道可用性实测：`toklens` 被 runtime 健康检测标 **degraded**（429）、`arcbench` 返回 `invalid_api_key`(401)、`deepseek` 虽 enabled 但 `.env` 无 `DEEPSEEK_API_KEY` ⇒ **当前无可用 LLM 通道**，画像增强不可用 |
| 2026-10-25 | R6 | 开发环境 runtime 启动故障修复（阻塞项，优先于功能） | **根因三层**：① PC 客户端开机自启（`HKCU\...\Run` 的 `agentskills-runtime-pc`）→ 6 个 `AgentSkills Runtime` 进程 + 内嵌 PG 残留；② **8 个 L3 进程插件各占满 1 核**（8 核吃满）→ 宿主主线程被饿死；③ `awaitActive` 逻辑本身正确（全 tryLock + 墙钟 deadline 兜底），但主线程拿不到时间片 ⇒ `iter=1` 几行代码跑 4 min ~ 1h6m，Ctrl+C 杀插件释放 CPU 后立刻返回 Ok。**处置**：删自启注册表项；`auto-launch.ts` 的 `enable()` 降级为 no-op（开机自启能力下线）；清残留进程；**按用户确认卸载** `github` / `sheets`（为其他比赛生成、无用），另临时禁用 6 个高耗插件，只保留 `yuanbao-policy` | 修复后重启操作系统 + 启动 runtime **恢复正常**（探活 200）。**未动**系统 PostgreSQL 16（`D:/Program Files/PostgreSQL/16/data`，5432，即 `DATABASE_URL` 指向的库）；被清的是 PC 内嵌 PG（5433）。**病根未根治**：`plugin_runtime.cj:651` 的 `while(!isClosed()){sleep(100ms)}` 疑似满核自旋，修复需重编译 8 个插件 ⇒ 赛后处理（`yuanbao-policy` 实测同样自旋 CPU≈166s/6min） |

### T-26 / T-27 / T-28 已完成的文档产出（AI 侧）

| 产出 | 路径 | 说明 |
|---|---|---|
| T-21 补漏 `SKILL.md` | `skills/yuanbao-policy/SKILL.md` | L3 模型行为契约：handler key、`search`/`selftest` 入参与出参、四因子规则、闭源分发、已知差异。与 `handlers.cj` 逐字对齐，含能力边界标注 |
| T-26 演示脚本 | `.codeartsdoer/specs/1024/presentation/demo-script.md` | 8 屏分镜（命令 + 期望输出 + 解说词 + 截图文件名），其中屏 5「敢说不知道」为单屏核心，屏 7 闭源对比依赖 T-23/T-24 |
| T-27 开源声明（短版） | `.codeartsdoer/specs/1024/presentation/open-source-declaration.md` | 提交页 / 社媒可直接粘贴版 |
| T-27 README | `skills/yuanbao-search/README.md`、`skills/yuanbao-policy/README.md` | 复用 12 / 扩展 5 / 新建 6 逐条对照 design §1.2~§1.4；含实测数据与能力边界 |
| T-28 路演稿 | `.codeartsdoer/specs/1024/presentation/pitch-3min.md` | 5 屏 2'50"，含计时表与「超时怎么砍」备注；屏 3（敢说不知道）标注**不许压缩** |

**待【人工】**：T-26 八屏截图（`presentation/shots/`）、T-28 计时演练一次。

### T-12~T-20 已完成的实测记录（轨一闭环改造 + 联调）

**T-12（画像采集留来源）**：`build_enterprise_profile.ts/.py` 新增 `--no-search`（默认开启检索补采）、
`field_sources`（每个属性标记「预填 / 原接口 / 检索采集(url) / 未获取」）、`search_evidence[]`、`search_meta`
（`used/request_id/channel/note`）。实测：`--company ""` 双版均以**退出码 2** + "企业名称为必填项"拒绝；
对「北京中关村软件园发展有限责任公司」真实补采，检索通道返回 `requestId=62e854ad-…` 但**可采信条目为 0**
（news 轨道信源多为自媒体，被门禁排除）→ 字段保持「未获取」、流程不中断、Markdown 新增「采集来源」章节。
**结论**：工商信息检索命中率低是客观事实，脚本行为（留空 + 记录）符合「禁止编造」（spec §6.5 第 2 条）。

**T-13（结论强绑定 policy_no）**：`match_policy.ts/.py` 新增 `normalizeNo / normalizeDeadline`、
经 `yuanbao-search/scripts/policy_kb` 交叉验证绑定（加载失败则全部转待核实，绝不放宽阈值）。
输出新增 `pending`（规范键）+ `excluded`（与报告脚本的契约别名，同一数组）+ `policy_no_coverage` + `kb_count`。
实测（3 家企业）：`policy_no_coverage` 均为 **1.0**；检索侧未绑定项全部进入 `pending`（13 / 16 / 17 条），
无一进入 `matches`。双版产物逐字段一致（仅 `policy_no_coverage` 的 `1` vs `1.0` JSON 数字写法差异）。

**T-14（报告扩展）**：已完成（上一轮），本轮联调验证「未查到可靠依据」章节实际渲染出 13 条排除项及原因。

**T-15（申报任务落库）**：`save_to_db.ts/.py` 新增 `--deadline / --creator / --follow-status / --credit-code`；
`tasks` 写入 `extra_data`（材料清单 + `follow_status` + `deadline_known` + `materials_source`）、
`deadline`（未知时写 NULL 并在 SQL 注释与 `result.notes` 明示"截止时间未知"）、`task_status`
（中文跟进状态映射为库内枚举 `open/in_progress/completed/closed`，中文值保留在 `extra_data.follow_status`）。
**实测发现并修复两个会导致落库必失败的既有缺陷**（线上库实测，非基线 schema 可见）：
1. `tasks.creator_id` NOT NULL 且无默认 → 原 SQL 必报 not-null；改为 `--creator` 显式指定或
   `COALESCE((SELECT u.id FROM uctoo_user …), 占位 uuid)`（该列无外键，线上 23 个用户可解析）。
2. `company` 有 **17 列 NOT NULL 且无默认**（含 `social_credit_code`、法人手机号等）→ 原 SQL 必报 not-null；
   改为按画像填值、未采集列写**空串**并在 `company_unfilled_cols` 与 SQL 注释中列明，**不编造**任何值。
**验证**：`BEGIN; … ROLLBACK;` 干跑通过 —— `UPDATE 0 / INSERT 1（company）/ INSERT 4（1 policy-match + 3 policy-apply）/ ROLLBACK`，无 `CREATE TABLE`；双版 SQL 逐字节一致（UUID 与时间归一后）。

**T-16（巡检接元宝）**：`update_policy_kb.ts/.py` 新增 `--sources yuanbao`（可与 `default` / URL 组合）、
`--freshness`（默认 `m3`）、`--query`；储备条目状态统一为 **`待研判`**，必带 `url` / `discovered_at`（发现时间）/
`request_id`（来源请求标识）；`--commit` 仍只接受 `confirmed`，缺 `--reviewer` 直接拒绝并保持待研判。
实测：`--sources "yuanbao,http://127.0.0.1:9/dead"` → 元宝 32 条 + 失败源 1 条登记，**流程继续**（G13）；
待研判条目缺 url/发现时间/请求标识的条目数 **0**；`--commit` 带 reviewer 写入临时库成功（`next_policy_no=75`，留痕 `reviewer=张工`）。

**T-19（产物规范）**：`output/` 四类产物齐全（`profiles/` `matches/` `reports/` `pending/`，新增 `search/` 存检索中间产物）；
落库失败时 `result.products` 保留文件并打印"落库失败，已生成产物文件"；
**密钥扫描**：`grep -rIl -E "SecretId|SecretKey|sk-[A-Za-z0-9]{16,}|password" output/` → **0 命中**（G7）。

**T-20（端到端联调 3 次 + 1 异常）**：

| # | 企业 | RequestId | Version | items / excluded | 匹配结论 | 检索绑定 |
|---|---|---|---|---|---|---|
| 1 | 北京北辰实业有限公司 | `11a6c990-f69b-4ef5-9291-e87c4cf73375` | flagship | 13 / 7 | 5（覆盖率 1.0） | 0（13 条转待核实） |
| 2 | 北京朝阳智算科技有限公司 | `12f13cff-7202-4f79-903c-e0a56846cb6d` | flagship | 16 / 4 | 5（覆盖率 1.0） | 0（16 条转待核实） |
| 3 | 北京中关村软件园发展有限责任公司 | `cf613793-077d-492d-9cac-b1254dea6f8e` | flagship | 17 / 3 | 5（覆盖率 1.0） | 0（17 条转待核实） |

三次均为 HTTP 200；`excluded[]` 非空（13/16/17），"敢说不知道"可见；报告「未查到可靠依据」章节逐条列出。
**异常用例（G14）**：把 `knowledge/policy-index.json` 临时改名后跑检索 → 退出码 0、`ok=true`、
warning 明确「政策原文库不可用…非政府信源的结论将置待核实」，20 条中 **7 条被排除**、剩余 13 条
`authority=高`（政府信源）仍可采信 —— 符合 G14 v1.1（非最高档信源一律待核实），流程不中断，索引已还原。

**检索侧绑定率的诚实说明**：三次联调 `bound_from_search` 均为 0，原因是本轮检索词命中的多为
「申报通知 / 新闻通稿」，与原文库「政策名」的标题 Jaccard 普遍 < 0.6、正文全名命中率极低（此前 50 条实测 0 命中）。
先前一次查询绑定成功 3 条，是因为检索通道自身已标注 `policyNo`（48 / 74）。**此为能力边界，不为凑数放宽阈值**（R4）。

### T-01~T-11 已完成的实测记录（轨一内核）

- **自检**（`--selftest`，TS + PY 双版）：HTTP 200 / `Version=flagship` / 10 条 / authority_level 10/10 可用 /
  score 10/10 可用 / deeplinks 0/10（未请求 Deeplinks）/ 政策原文库可用（74 条）/ 耗时 2.3s（TS，经 http_client 子进程）、1.3s（PY，urllib）。
- **真实查询** `--query "北京 专精特新 中小企业 扶持 政策 申报" --cnt 30 --freshness 1y`：
  返回 30 → 可采信 20 / 待核实 10；命中原文库 2 条（`policy_no=48`，北京市高精尖产业发展项目资金管理办法）。
- **排除原因分布**（50 条批次实测）：未知站点/自媒体 21 条、过期 1 条，均为真实不可核验项。
- **传输通道**：TS 走 `http_client.ts`（子进程 CLI 复用，实测成功）；不可用时自动回退内置 fetch；PY 走标准库 urllib。
- **已修 bug**：Python 版 `overlap()` 误写为 `len(small & (a|b))`（恒等于 small）→ 相似度恒为 1、全部误命中；已改为 `len(a & b) / len(small)`。

### 待回填（执行阶段补）

- ~~`T-11` 自检输出~~ → 已回填（见上「T-01~T-11 实测记录」：flagship / 10 条 / authority 10-10 / 2.3s）
- ~~`T-20` 三次真实查询记录~~ → 已回填（见上联调表），**仍缺截图路径**（T-26 补）
- `T-26` 八屏截图路径（`presentation/shots/01…08`，屏 7 依赖 T-23/T-24）
  - 已可用的替代素材（R5 实测产出，可直接截图）：`yuanbao_search.ts --selftest` 输出（10 条 / 8 可采信 / 2 排除 / 原文库 74 条 / 首条命中 policy_no=61）——**覆盖屏 2「检索结果」与屏 3「敢说不知道」**，建议优先截这两屏
  - 报告样例 `output/reports/北京北辰实业股份有限公司-2026-10-25.md`（90 行）为**降级样例**（匹配度全 30 / 来源列空），**不建议作为主演示屏**
- `T-28` 计时演练结论（实测是否 ≤3 分钟，超时砍哪一屏）
- ~~`T-23` 【人工】`cjpm build` 日志与结论~~ → 已回填：四轮编译（init 关键字 7 处 / `match` 关键字 2 处 / HashMap 下标返回 V 10 处 / lambda 捕获 var 1 处）后 0 errors 通过
- ~~`T-23` 宿主加载验证~~ → 已回填（R5/R6）：修复后 runtime 监听 443、探活 200、`[cordis][yuanbao-policy] -> Active` 且注册 7 个 host 服务
- ~~`T-25` 裁剪判定结果~~ → 已回填：**不裁剪**，轨二全量保留
- `T-24` 闭源分发验证（删 `src/` 后仍可加载）——**需重启 runtime**，建议在截图全部完成后最后做，避免中途重启打断
- 【阻塞项】LLM 通道可用性：当前 `toklens`=degraded(429) / `arcbench`=401 / `deepseek` 无 key ⇒ 画像 LLM 增强不可用；若演示需要「有内容的画像」，须先恢复任一可用通道
- `T-29` / `T-30` 社媒链接与提交时间戳

---

> 配套：同目录 `research.md`（v2+）、`spec.md`、`design.md`（v1.0.0）；测试阶段使用 `skills/sdd/templates/test-report-template.md`。
