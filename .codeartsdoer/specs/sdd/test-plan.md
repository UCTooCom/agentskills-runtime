# SDD 融合插件 测试与验收方案（test-plan.md）

> **文档定位**：SDD 六步第 6 步（测试验收）的**前置计划**。本文定义「测什么、怎么测、什么算通过」；执行结果回填到 `test-report.md`（模板：`test-report-template.md`）。
> **依据**：`spec.md`（v4，含 REQ-SDD-001~012 与 EARS 验收条件）、`design.md`（v4，含 §2.6 十三条防回退）、`tasks.md`（v5，含「验收检查清单」与「T-23 联调验证清单」）、`adr-001-storage-layer.md`、`sdd-methodology-baseline.md`。
> **本轮基线**：宿主 runtime 与 `skills/sdd` 插件均已通过 `cjpm build`（2026-09-29），编译不再是阻塞项，本方案从运行期验证开始。
> **红线**：AI 不执行 `cjpm build`、不直连生产库写入；构建与 DDL 由人工执行并回传日志，AI 只做日志分析与文案修订。

---

## 文档信息

| 项 | 内容 |
|---|---|
| 被测对象 | agentskills-runtime SDD 融合插件（宿主侧编排 + `skills/sdd` L3 进程插件） |
| 版本 | runtime v0.0.24 / cjc 1.1.3 + cordis-cj（ystyle） |
| 测试轮次 | 第 1 轮（编译通过后首轮） |
| 计划日期 | 2026-09-29 |
| 编制 | AI 辅助编制，人工执行与判定 |
| 状态 | 待评审 → 执行中 → 回填 `test-report.md` |

---

## 一、测试目标与范围

### 1.1 测试目标
验证 SDD 六步（研究/需求/设计/任务/编码/测试）能在 runtime 上**真实跑通**，且满足四条主线硬约束：

1. **约定即注册**：`skills/*/agents/*.md` 双向同步进 `agents` 表，无手工 SQL（`REQ-SDD-011`）。
2. **真派生**：子 agent 派单走真实执行通道，非桩实现；上下文按 `task_id` 隔离（`REQ-SDD-010`）。
3. **可校验可计量**：派单结果契约校验生效（自动重派恰好 1 次）、成本账本可聚合（`REQ-SDD-012`）。
4. **人在回路**：步步闸口不可跳过，confirm/revise/abandon 语义正确并留痕（`REQ-SDD-008/009`）。

### 1.2 范围内 / 范围外

| | 内容 |
|---|---|
| **范围内** | 宿主侧：SDD 编排服务、同步链路（`ChangeDetector`/`AgentSyncHandler`）、HTTP 路由、RBAC、SSE 事件；插件侧：L3 进程编译与生命周期、5 个子 agent 声明、`COMPOSITION.yaml`、`templates/`、`plugin.yaml`；数据层：`agents`/`sub_agent_invocations`/`sdd_projects` 及聚合视图 |
| **范围外** | web-admin 前端视觉与交互走查；cordis-cj 底座自身功能（视为可信依赖）；第三方模型服务的稳定性与配额；`.codeartsdoer/skills/managing-*` 原产品模板（插件内 `templates/` 自完备即达标） |

### 1.3 测试层级与策略

| 层级 | 名称 | 手段 | 说明 |
|---|---|---|---|
| L1 | 构建验证 | 人工 `cjpm build` | 宿主 + `cd skills/sdd && cjpm build` 双侧均须零 error |
| L2 | 静态与红线核查 | grep / ls / 目录核验 | 防回退 13 条、`agents/` 目录形态、表列限量 |
| L3 | 数据层断言 | psql 只读查询 | `agents` 同步结果、新增表/列计数、聚合视图 |
| L4 | 接口层 | HTTP 调用 | `/sdd/start`、`/run`、`/run-stage`、`/status/:featureName`、`/review` |
| L5 | 端到端 | 走完六步 + 闸口 | 复用 `tasks.md` T-23 十二步清单 |
| L6 | 文档一致性 | 人工比对 | spec/design/tasks 与实现是否漂移（含本文 §七 已知漂移） |

---

## 二、测试依据（结论锚点）

| 来源 | 章节 | 约束摘要 |
|---|---|---|
| `spec.md` | §4 DFX | 四步编排 ≤10s、SSE 事件 ≤2s、契约校验 ≤1s 且禁网络/模型；状态可恢复、审核留痕不丢；闸口鉴权 + 操作可审计；模板随插件打包、L3 日志只走 stderr；新增 ≤2 表 ≤2 列 |
| `spec.md` | §5.1~5.11 | REQ-SDD-001~012 的 EARS 验收条件（逐条见 §四 追溯矩阵） |
| `spec.md` | §6.7 | 库表使用约束：仅允许新增 `sdd_projects`/`sub_agent_invocations` 两表，`agents.skill_name`/`agent_contexts.task_id` 两列 |
| `design.md` | §2.6 | 十三条防回退（禁跳闸口、禁新建表、condition 红线、code 步不派生等） |
| `design.md` | §2.9 | 三层（同步层/加载层/派生层）路径集合须一致，不一致以 DB 为准并告警 |
| `tasks.md` | 验收检查清单 / T-23 | 终验 16 条 + 端到端 12 步 |

---

## 三、测试环境与前置条件

### 3.1 环境

| 项 | 要求 |
|---|---|
| 工具链 | cjc 1.1.3（cjnative）、`cordis-cj`（ystyle）、stdx `libs/cangjie-stdx-windows-x64-1.1.3.1` |
| 数据库 | PostgreSQL（host.db），SDD 增量 SQL 已人工执行完毕 |
| 运行形态 | 宿主 HTTPS `127.0.0.1:443`；`skills/sdd` 为 L3 独立进程（stdio RPC） |
| 实施主体 | AI 不跑构建/不写生产库；构建与 DDL 人工执行、日志回传 AI 分析 |

### 3.2 数据准备与前置操作
1. 宿主 `cjpm build` 通过 → 重启 runtime。
2. `cd skills/sdd && cjpm build` 通过。
3. 若尚未执行，`psql` 执行 `sql/incremental/` 下三条 SDD 增量脚本。
   > Windows psql 在 Git Bash 下会忽略 `-c`/`-f`，**须走 stdin 管道**；验证用「BEGIN 全执行 → ROLLBACK」干跑。
4. 确认 RBAC：`/api/v1/uctoo/sdd/*` 相关权限已登记并授予超管（否则一律 403）。

### 3.3 准入条件（Entry Criteria）
- [ ] 宿主与插件双侧编译零 error（已满足）
- [ ] 增量 SQL 已执行且可回滚验证
- [ ] runtime 可正常启动并完成一轮 `SyncManager.syncAll`
- [ ] 超管账号可用，SSE/WS 通道连通

---

## 四、需求追溯矩阵

| 需求 | 标题 | 主验证用例组 | 关键判据 |
|---|---|---|---|
| REQ-SDD-001 | 任务识别与工程初始化 | E1、E2 | 目录落在 runtime 自有 `specs/{feature_name}/`，不写 `.codeartsdoer/specs/` |
| REQ-SDD-002 | 可选研究步 | E3、E8 | `condition` 只依赖 `enable_research`，不读文件是否存在 |
| REQ-SDD-003~005 | 需求/设计/任务步 | E4、E5 | 分别产出 6 节 spec、10+2 节 design、tasks-template 骨架 |
| REQ-SDD-006 | 编码步 | E6、G4 | **不派生子 agent**，按语言标签加载 coder 技能 |
| REQ-SDD-007 | 测试验收步 | E7 | 末步产出 `test-report.md`，含一致性核查与 P0~P2 缺陷分级 |
| REQ-SDD-008 | 步步闸口 | E9、E10 | 五步闸口三选一（confirm/revise/abandon），`recommended=confirm` |
| REQ-SDD-009 | 决策闭环 | E10、E11 | 每次决策落 `agent_approvals`，revise/abandon 语义正确 |
| REQ-SDD-010 | 子 agent 派生与上下文交接 | C1~C6 | 真执行通道、上下文按 `task_id` 隔离、缺失即失败 |
| REQ-SDD-011 | `agents/` 自动探测与加载 | B1~B6 | 双向同步、`skill_name` 回填、删文件即下线、coder 类零命中 |
| REQ-SDD-012 | 契约校验与成本账本 | D1~D6 | 重派恰好 1 次、token 缺失记 0 + `token_missing`、视图可聚合 |
| DFX 全量 | §4.1~4.5 | F1~F6 | 见 §五 F 组 |

---

## 五、测试用例设计

> 用例 ID 规则：`组号-序号`；**级别** P0=阻断交付 / P1=严重影响 / P2=一般。
> 表中「预期」均取自 spec/design 原文口径，未新增自创标准。

### A 组：构建与静态红线（L1/L2）

| ID | 前置 | 步骤 | 预期 | 级别 |
|---|---|---|---|---|
| A-1 | 干净工作区 | 宿主根目录 `cjpm build` | 零 error（warning 不阻断） | P0 |
| A-2 | A-1 通过 | `cd skills/sdd && cjpm build` | 零 error；`cordis-cj` examples 的 `unused function:'main'` 仅为 warning | P0 |
| A-3 | A-2 通过 | `ls skills/{cangjie,web,app}-coder/agents` | 三处均**不存在** `agents/` 目录 | P0 |
| A-4 | A-2 通过 | 对照 `design.md` §2.6 十三条逐条 grep/审查 | 十三条全部满足，无违反 | P0 |
| A-5 | 增量 SQL 已跑 | 统计 SDD 新增库表与列 | 恰好 ≤2 表（`sdd_projects`/`sub_agent_invocations`）+ ≤2 列（`agents.skill_name`/`agent_contexts.task_id`），符合 §6.7 | P0 |

### B 组：约定即注册与双向同步（REQ-SDD-011）— **本轮修复重点**

> 背景：`ChangeDetector.collectBundledAgentMdFiles` 原用单条非递归 `Directory.walk` 扫整个 `./skills`，收不到第三层 `skills/<skill>/agents/*.md`（2026-09-28 已改为两层 walk）。本组直接验证该修复。

| ID | 前置 | 步骤 | 预期 | 级别 |
|---|---|---|---|---|
| B-1 | runtime 启动并完成 syncAll | `SELECT name, agent_type, skill_name, source_path FROM agents WHERE deleted_at IS NULL ORDER BY skill_name, name;` | **`skill_name='sdd'` 5 行**（researcher/spec-writer/design-writer/task-planner/tester）；另有 skill-creator 3、test-generator 3；`source_path` 均指向 `skills/*/agents/*.md` | P0 |
| B-2 | B-1 通过 | 同查询按 `skill_name` 分组计数 | bundled 子 agent 合计 **11 行**；`skill_name='cangjie-coder'` 为 **0 行** | P0 |
| B-3 | B-1 通过 | 新建 `skills/sdd/agents/probe.md`（含 `agent_type: sub`）→ 重启或调同步 → 重查 B-1 | 多出 `probe`，`skill_name='sdd'`，**全程无手工 SQL** | P0 |
| B-4 | B-3 通过 | 删除 `probe.md` → 重启/同步 → 重查 B-1 | `probe` 行 `deleted_at` 非空（软删下线），非孤儿残留 | P0 |
| B-5 | — | 放入缺 `agent_type` 的声明文件 → 同步 | 同步报错并指出文件与缺失键，**该文件不入库**，其余文件照常处理 | P1 |
| B-6 | — | 检查各技能 `agents/` 目录：含空 `agents/` 目录的技能（如 `opentiny-next-app-integration`）与含 `.md` 的技能分别核对 | 空目录 **0 行**入库；含 md 的按实际文件数入库，无错扫 | P1 |
| B-7 | 加载技能 sdd | 对比日志中 `BundledAgentScanner` 探测到的内存条数与 DB 行数 | 相等；不等时以 DB 为准并出现 WARN（design §2.9.5） | P1 |

### C 组：子 agent 派生与上下文隔离（REQ-SDD-010）

| ID | 前置 | 步骤 | 预期 | 级别 |
|---|---|---|---|---|
| C-1 | 已注册 5 个子 agent | 派单一个子 agent，要求其写一个探针文件 | 探针文件**真实落盘**（非返回字符串冒充）；`sub_agent_invocations` 有对应记录 | P0 |
| C-2 | — | spec 步连续执行/重做多次后查 `agent_contexts` | 上下文按 `task_id` 隔离，前一次的 messages **不出现**在后一次 | P0 |
| C-3 | — | 临时删除某子 agent 声明文件并同步下线 → 再跑该步 | **立即失败并提示**（给出缺失的 `source_path`），**禁止**静默由主 agent 自写 | P0 |
| C-4 | — | 检查执行通道实现 | 走 `AgentDefinition → Agent 实例 → AgentAsTool → chat`；`SubAgentTool.executeSubAgent` 桩行为已移除 | P0 |
| C-5 | — | 查 `SubAgentTool` 解析 `agent_name` 的顺序 | 优先在本技能 `bundledAgents` 内查找，再回退全局 `agents` 表 | P1 |
| C-6 | — | `SELECT capabilities, default_input_types, default_output_types FROM agents WHERE skill_name='sdd';` | 5 行三列均非 NULL（ACS 结构填充） | P1 |

### D 组：契约校验与成本账本（REQ-SDD-012）

| ID | 前置 | 步骤 | 预期 | 级别 |
|---|---|---|---|---|
| D-1 | — | 故意让子 agent 回传缺章节文档 | `verify_passed=false`、**恰好两次派单**（`attempt` 1→2，无第三次）后转人工闸口 | P0 |
| D-2 | D-1 | 查 `sub_agent_invocations` 的 `errors` 字段 | 含结构化错误（缺哪个章节），可解释「为什么被打回」 | P0 |
| D-3 | — | 修改 `capabilities.output_contract.required_sections` 后重跑 | 新规则下次即生效，**无需改代码**、未新建表/列 | P1 |
| D-4 | — | `default_output_types` 置空后派单 | 降级为非空校验，记录标注 `contract_absent`，**不跳过校验** | P1 |
| D-5 | — | 一次成功派单后查成本四字段 | `duration_ms`/`prompt_tokens`/`completion_tokens`/`total_tokens` 均非 NULL | P0 |
| D-6 | — | 模型返回无 usage 时 | token 记 **0** 并标注 `token_missing`，**禁止估算**，不阻断主流程 | P0 |
| D-7 | — | `SELECT * FROM v_sub_agent_stage_cost;` | 按 `stage` 给出 派单次数/平均 tokens/重派率/平均耗时 四项指标 | P1 |

### E 组：六步编排、闸口与产物（REQ-SDD-001~009）

> 执行顺序直接复用 `tasks.md` **T-23 联调验证清单**（12 步），此处只补 beforehand 与判据。

| ID | 步骤摘要 | 预期 | 级别 |
|---|---|---|---|
| E-1 | `POST /api/v1/uctoo/sdd/start` | 返回 `crontab_id`；工程目录建在 runtime 自有 `specs/{feature_name}/`，**不**在 `.codeartsdoer/specs/` | P0 |
| E-2 | `feature_name` 非法（含大写/超 10 字符）或已存在 | 按 §5.1.3：自动追加序号或提示换名，不崩溃 | P2 |
| E-3 | `enable_research=false` 走六步 | 跳过研究步且不报错；`condition` 只依赖该开关（不读 `research.md` 是否存在） | P0 |
| E-4 | `POST /api/v1/uctoo/sdd/run`（带 `agent_id`、`auto:false`）与 `/run-stage` 分步执行 | 逐步推进，每步产物落 `specs/{feature_name}/` 并写 `long_running_task_artifact` | P0 |
| E-5 | 检查六份产物 | spec 6 节 / design 10 节+两段式 / tasks 骨架 / research 八节，符合 `skills/sdd/templates/` | P1 |
| E-6 | 编码步 | **不派生编码子 agent**（`sub_agent_invocations` 无 code 步记录）；按语言标签加载 cangjie/web/app-coder 技能并按 SOP 执行 | P0 |
| E-7 | 测试步（末步） | 产出 `test-report.md`，含「与 spec/design 的一致性核查」+ P0~P2 缺陷分级 | P0 |
| E-8 | `GET /api/v1/uctoo/sdd/status/:featureName` | 编码未完成前测试步拒绝启动；`auto:false` 时每一步 `status=awaiting_review` | P0 |
| E-9 | 任一步完成后闸口 | 弹出 confirm/revise/abandon 三选项卡片，`recommended=confirm`；RBAC 未登记则 403 | P0 |
| E-10 | `POST /api/v1/uctoo/sdd/review` `{decision:"confirm", crontab_id}` | 恢复调度并推进下一步（库置 1 + reloadCrontab + executeTask 三步缺一不可） | P0 |
| E-11 | `decision:"revise"` | `round+1`、`current_stage` 退回上一步、上一版产物归档 `*.prev` 不覆盖；连续 revise 不越级 | P0 |
| E-12 | `decision:"abandon"` | `sdd_projects.status=4`（abandoned）；`agent_approvals` 有 `sdd-gate-abandon` 留痕；**复盘 abort 语义在 memory 中记为 status=4，与 tasks.md 曾写的 'abandoned' 字面值以实际枚举为准** | P0 |
| E-13 | 闸口超时未响应 | 按 `default=confirm` 自动推进并记「超时默认通过」；决策点失效时降级为普通审批，**不伪造选项卡片** | P1 |
| E-14 | 尝试跳过闸口直达末步 | 被决策点框架拦截并报错 | P0 |

### F 组：DFX（spec §4）

| ID | 检验项 | 预期 | 级别 |
|---|---|---|---|
| F-1 | 性能 | 研究/需求/设计/任务四步的纯编排 + 落盘 ≤10s（不含子 agent 撰写） | P1 |
| F-2 | 进度实时性 | 每步状态变化后 ≤2s 推送 SSE/WS 事件；纯 cron 无 session 时推前判空早退 | P1 |
| F-3 | 契约校验开销 | 2000 行 markdown 校验 ≤1s，且不发起任何网络/模型调用 | P1 |
| F-4 | 可靠性 | 编码步中断后重拉起，从 `agent_contexts` 检查点恢复，已落盘文档不丢；`status` 不倒退为 0 | P0 |
| F-5 | 可维护性 | 仅部署 `skills/sdd/` 一个目录（不挂 `.codeartsdoer/skills/`）仍能产出合规文档；修改 `templates/` 即生效 | P1 |
| F-6 | L3 日志 | 插件 stdout **无**业务打印（stdio RPC 独占），日志经 stderr / `host.log` 落盘 | P0 |

### G 组：本轮（2026-09-28~29）修复项回归

| ID | 修复内容 | 回归方法 | 预期 | 级别 |
|---|---|---|---|---|
| G-1 | `ChangeDetector` 两层 `Directory.walk` | 执行 B-1/B-2 | 11 行 bundled 子 agent 入库（此前始终只有 MainAgent） | P0 |
| G-2 | `HTTPServer` 日志降噪（errorLog 降级 + `connState` 跳过 NEW） | 观察 cmd 控制台 | 不再刷屏 `TLS handshake failed` / `read data timeout` / `conn state: NEW`；真实错误仍以 ERROR 出现 | P2 |
| G-3 | `libs/jwt4cj` 删除残留 `print(isValid)` | 观察 cmd 控制台 | **无**无前缀裸 `true` 输出（该 print 原在 JWT `nbf` 校验时每请求打印） | P1 |
| G-4 | `WebMCPController` 补 `SddEventBridge` import | A-1 构建通过 | 编译无 `undeclared identifier` | P0 |
| G-5 | `skills/sdd/src/effects.cj` 补 lambda `=>` + `label` 改位置传参 | A-2 构建通过 | 编译无 `expected '=>' in lambda expression` / 无 `invalid named arguments prefix 'label:'` | P0 |
| G-6 | `SddEffects` 卸载行为 | 卸载插件或重启 | `ctx.effect` 注册成功（`getEffects()` 可见 `sdd/cleanup`），disposer 被逆序调用 | P2 |

---

## 六、执行顺序与轮次

| 轮次 | 用例组 | 目的 | 阻塞性 |
|---|---|---|---|
| 第 0 轮 | A 组 | 确认双侧构建与静态红线 | 全阻塞，不过则停 |
| 第 1 轮 | B 组 | **优先验证本轮同步修复是否真正生效** | B-1/B-2 不过则需回退排查 |
| 第 2 轮 | C、D 组 | 子 agent 派生链路与契约/账本 | P0 用例不过则停 |
| 第 3 轮 | E 组 | 端到端六步 + 闸口（= T-23 十二步） | 核心验收 |
| 第 4 轮 | F、G 组 | DFX 达标 + 本轮修复回归 | P2 可记遗留 |

---

## 七、已知文档漂移（执行时同步订正）

| # | 位置 | 现象 | 处置状态 |
|---|---|---|---|
| 1 | `spec.md` §5.9.1 规则 1、§5.10 多处；`design.md`；`tasks.md`；`research.md` | 表述为「**六个**子 agent」，但 `skills/sdd/agents/` 实际只有 **5 个** md；按 `HOST_DIRECT_STAGES=["code"]`（code 步不派生）策略，**5 个才是正确形态** | ✅ **已订正（2026-09-29）**：四处文档的「六个/6 条/6 行」已全部改为「五个/5 条/5 行」，并澄清 code 步由主 agent + coder 技能直执行、不派生子 agent |
| 2 | `skills/opentiny-next-app-integration/agents/` | 存在**空** `agents/` 目录（0 个 md） | B-6 已覆盖；建议 `ChangeDetector` 对该情形不产生任何行，并考虑是否清理空目录 |
| 3 | `tasks.md` T-23 清单第 1 步 | 写「sdd 5 行」，与 spec「六个」矛盾 | ✅ **已统一为 5**（随 #1 一并订正） |

---

## 八、缺陷分级与验收判定

### 8.1 缺陷分级
- **P0（阻断交付）**：核心链路不可用、数据错误/丢失、违反 §2.6 红线、编译失败。
- **P1（严重影响）**：功能可用但结果不达标（如文法/格式不符、辅助表缺失、指标不可聚合）。
- **P2（一般/体验）**：日志噪声、文案漂移、非关键路径瑕疵。

### 8.2 准出条件（Exit Criteria）— 全部满足方为「通过验收」
- [ ] A-1、A-2 双侧编译零 error
- [ ] **12 条 REQ-SDD 均有对应执行结果**，其 EARS 验收条件全部通过或有显式豁免说明
- [ ] P0 缺陷数 = 0；P1 缺陷全部有处置方案（修复或排期）
- [ ] 复用项未被重写（COMPOSITION 引擎 / 决策框架 / 复用表 / 模板）
- [ ] 表列扩张符合 `spec.md` §6.7：≤2 表 + ≤2 列
- [ ] 六步走通 + 五步闸口可用 + revise/abandon 语义正确
- [ ] `agents` 表 bundled 子 agent 双向同步生效（新增入库、删除软删）
- [ ] coder 三技能无 `agents/`，`skill_name='cangjie-coder'` 为 0 行
- [ ] 契约校验生效且**自动重派恰好 1 次**，无无限重试
- [ ] 成本账本可聚合；token 取不到记 0 + `token_missing`，无估算冒充实测
- [ ] spec/design/tasks 与实现一致，§七 漂移项已订正或明确延期

### 8.3 验收结论
三选一：**通过 / 有条件通过（附遗留项与时限）/ 不通过**。结论与缺陷清单回填 `${feature_name}/test-report.md`。

---

## 九、产出物与职责

| 产出物 | 路径 | 责任方 |
|---|---|---|
| 本方案 | `.codeartsdoer/specs/sdd/test-plan.md` | AI 编制，人工评审 |
| 执行结果报告 | `apps/agentskills-runtime/specs/{feature_name}/test-report.md` | 人工执行，AI 汇总 |
| 构建日志 | 人工 cmd 回传 | 人工 |
| 缺陷清单 | 报告 §七 + Backlog | 双方 |

> **注意**：阶段文档须落在 **runtime 自有 `specs/{feature_name}/`**，SDD 运行期不得向 `.codeartsdoer/specs/` 写入任何产出（REQ-SDD-001 规则 2）。
