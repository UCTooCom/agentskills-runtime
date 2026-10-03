# AgentSkills Runtime v0.0.29 发布说明

**发布日期**: 2026-10-03
**版本**: 0.0.29
**代号**: Sub-Agent Orchestration（子 Agent 编排 · 启动与登录稳态）
**平台**: Windows x64, Linux x64, macOS x64/ARM64

---

## 重大变更

### 1. sdd：规范驱动开发插件（六步流程 + 人在回路闸口，L3 进程隔离轨）

v0.0.28 之后最大的一块交付。SDD 以 **L3 进程隔离轨**插件形态落地，把"规范驱动开发
（research → spec → design → task → code → test 六步 + 逐步闸口）"从一套口头约定
变成可指挥、可追溯、可验收的工程链路。宿主负责编排，插件负责六步契约与子 agent 定义。

#### 为什么编排必须落在宿主侧

一条实测结论决定了整个架构：`CordisHostManager` 向 L3 进程插件只暴露
`host.db` / `host.mcp` / `host.event` / `host.db_schema_lookup` / `host.cache` / `host.log`，
**没有 `host.agent.invoke` 这类 RPC**。也就是说**进程插件内跑不了子 agent 派生**。
因此六步的真派生（`SddOrchestrationService`）落在宿主侧，插件只提供子 agent 声明、
六步提示词、模板与 `COMPOSITION.yaml` 编排定义（文件态 DSL，由 `LrtCompositionRunner` 消费）。

#### 插件资产

| 资产 | 内容 |
|------|------|
| `skills/sdd/SKILL.md` | 技能定义；v1.2.0 新增「大工程拆分为多子系统 SDD 工程」SOP 与铁律 15 |
| `skills/sdd/plugin.yaml` | `mode: process`；路由含 `POST /projects/:feature_name`（按 ADR-001 对齐 design） |
| `skills/sdd/COMPOSITION.yaml` | 六步编排（唯一事实来源，design §2.2.2 改为引用它，避免文档与实现漂移） |
| `skills/sdd/DATA_CONTRACT.yaml` | 数据契约，7 张表白名单 |
| `skills/sdd/agents/` | **5 份**子 agent 声明（researcher / spec-writer / design-writer / task-planner / tester） |
| `skills/sdd/prompts/` | 6 份（research / spec / design / task / **code** / test） |
| `skills/sdd/templates/` | 9 份模板（含本版新增 `specs-index-template.md`、`subsystem-contract-template.md`） |
| `skills/sdd/OPS.md` / `README.md` | 运维手册（排障表 + 13 条防回退逐条对照）/ 专属说明 |

> **关于"5 个子 agent"**：六步是方法论（恒为 6），但 `HOST_DIRECT_STAGES=["code"]` ——
> code 步由主 agent 直接调用 `coder` 技能执行、**不派生子 agent**，故声明文件是 5 个。
> 早期文档写"六个子 agent"属文档漂移，本版已全量订正。判别准则：**需要换脑子的才派生，
> 只需要换说明书的用技能**。

#### 宿主页真实接口（已 grep 核实）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/uctoo/sdd/start` | 按 `feature_name` 幂等取/建工程 |
| POST | `/api/v1/uctoo/sdd/run` | 触发某工程执行 |
| POST | `/api/v1/uctoo/sdd/run-stage` | 真派生子 agent 执行单步并推进阶段 |
| POST | `/api/v1/uctoo/sdd/review` | 闸口决策回执：`confirm` / `revise` / `abandon` |
| GET | `/api/v1/uctoo/sdd/status/:featureName` | 只读查询工程进度 |

（`sdd_projects` 的通用 CRUD 按 ADR-001 保持**未启用**：写路由在 `AutoRouteConfig.cj`
整段注释、权限节点不授予任何角色、前端写入口已摘除，见下文 §2.5）

#### 关键机制

| 机制 | 实现 |
|------|------|
| 人在回路闸口 | `applyGateDecision(confirm/revise/abandon)` + `gateForStage`；`auto=false` 时每步停在 `awaiting_review`；confirm 恢复调度需三步（库置 1 → `reloadCrontab` → `executeTask`）；revise 回退靠「`current_stage` 置为上一步」让 `nextStage` 重算本步 + bump round + 新 task_id，产物归档 `.prev` 不覆盖；abandon 写 `agent_approvals` 留痕 |
| 子 agent 契约校验 | `src/tool/sub_agent_contract_verifier.cj`（纯字符串/JSON，无网络无模型）：按 `output_contract` 的 `required_sections` 做**子串**校验；不通过 → 携结构化错误**重派 1 次** → 仍不过转闸口，结论落 `sub_agent_invocations` |
| 成本账本 | `sub_agent_invocations.recordCost`；`AgentAsTool.invoke` 的 `ToolResponse` **不暴露 `ChatUsage`** ⇒ 记 0 并在 `error_message` 追加 `token_missing`，禁折算 |
| 进度事件 | `src/app/services/bridge/sdd_event_bridge.cj`（8 类 `sdd_*`），复用 WS 广播 + SSE；SSE 单行转义 + 无 session 早退不打日志 |
| 插件自完备 | 模板以**实体复制**进 `skills/sdd/templates/`，禁止依赖插件目录外路径（如 `.codeartsdoer/skills/managing-*`）；验收口径是"仅部署 `skills/sdd/` 一个目录仍合规" |
| 阶段文档落盘 | runtime 自有 `specs/{feature_name}/`（与 `.codeartsdoer/specs/` 并存）；SDD 运行时产物走前者，ADR 等开发期决策记录仍随 spec/code 层留在 `.codeartsdoer` |

#### 踩到并沉淀的三个真坑

1. **契约与模板标题必须逐字对齐**。五份声明文件的 `output_contract.required_sections`
   与模板真实标题不一致（`"决策风险"` vs `"关键设计决策与风险"`、`"4. DFX 约束"` vs `"4. DFX约束"`），
   校验是子串包含 ⇒ 每次派单都判失败 → 重派 → 仍失败 → 闸口卡死。已逐字校正 5 处。
   **以后新增契约规则必须先 grep 模板标题核对。**
2. **`output_contract` 落库形态差异**：JSON 对象优先，否则按子串 + 一级花括号配平提取，
   兼容 YAML 原样落库 —— 因为 `agents.capabilities` 是 `Option<String>`，两种形态都得吃得下。
3. **`plugingen --mode process` 会覆盖 `SKILL.md` / `plugin.yaml`**，即使**不带 `--table`**
   走空白骨架分支也一样（实测 `tableWhitelist: []` + `routes = add/edit/del/list` 全被冲掉）。
   而 `skills/sdd/` 未纳入 git 跟踪，`git checkout` 救不回，只能按原始设计重写。
   ⇒ 新红线：**生成器执行顺序一律「先跑生成器出骨架 → 再覆盖定制内容」**；**禁止对
   `skills/sdd` 再跑任何 plugingen**。

#### ADR-001：两张新表的存储层形态

`sub_agent_invocations`（追加入口审计）与 `sdd_projects`（工程投影）**不是后台可编辑的
业务实体**，落的是「三问判据」之后的取舍：写入方在宿主进程、语义是追加/投影、
读写不在插件进程 ⇒ 不该切给插件 CRUD。但人工执行时最终选了 **crudgen 生成宿主五层模块**
（ADR v2），把"防人工增删改"改为**事后收敛**：

- 后端四条写路由（`add`/`edit`/`del`）在 `AutoRouteConfig.cj` 整段注释；
- `permissions` 确实生成了 `database.uctoo.{sdd_projects,sub_agent_invocations}` 节点，
  **菜单项不会因前端改动而消失** —— 必须不授予非超管角色；
- 前端 `index.vue` 摘除 `add-*` 挂载 + 表格写按钮的 `v-permission` 改指向不存在的权限码。

实际验收口径是**三层全做**，含 `curl POST .../add` 必须 404。

#### 配套文档

`research.md` / `spec.md` / `design.md` / `tasks.md` / `test-plan.md` /
`adr-001-storage-layer.md`（决策记录）/ `logs/crud.md`（人工执行链记录）。

---

### 2. 子 Agent（Sub-Agent）体系真正打通

v0.0.28 时 `agents/` 子目录机制**只落地了"声明"的一半**：`skills/*/agents/*.md` 有文件、
`agents` 表有行，但二者之间**没有任何自动链路**（`sub_agent_tool.cj:141-190` 还是返回
`"Sub-agent task completed: ..."` 的桩）。本版补齐「声明 → 解析 → 同步 → 派生 → 校验 → 记账 → 下线」全链。

#### 自动同步（REQ-SDD-011）

| 环节 | 改动 |
|------|------|
| 扫描扩围 | `ChangeDetector.collectMdFiles` 原本只收 `<base>/AGENTS.md` 与 `<base>/agents/`；新增 `collectBundledAgentMdFiles` 逐层 `walk` 技能根，收 `skills/<skill>/agents/**/*.md`（口径与 `deriveSkillName` 一致） |
| 落库 | `AgentsPO.cj` 补 `@ORMField['skill_name']`；`AgentSyncHandler.syncFromFileSystem` 前调 `deriveSkillName(sourcePath)` —— 仅路径含 `/agents/` 段才取前段为 `skill_name`，主 agent 留空 |
| 扫描入口 | `detectAgentChanges` 加命名参数 `bundledSkillRoots!`；`AgentSyncHandler(basePath, skillBasePath!)`；`SyncManager` 逐级下传 |
| 下线闭环 | `AgentSyncHandler.offlineBySourcePath`：按 `source_path` 定位 + 软删 `deleted_at`（不物理删）；`SyncManager` Deleted 分支用 `as AgentSyncHandler` 向下转型调用，不给接口加方法 |

> ⚠️ 这里踩了个隐蔽的坑：`collectMdFiles` 里注释写 `skills/<skill>/agents/*.md`
> 时，`/` 紧跟 `*` 在**块注释内又开了一层** `/*`，编译报 `unterminated block comment`
> 且错误跨度画到文件末尾的 `}`。**凡写目录通配一律改文字描述，不要写 `/` + `*` 连写。**

#### 真派生

唯一执行器仍是 `src/tool/agent_as_tool.cj` 的 `AgentAsTool`
（`SubAgentMode.Isolated` = 上下文全塞进唯一 `question`；`WithContext` = 继承主 agent 全量上下文）。
缺的"由 `agents` 表造 Agent 实例"前半段由 `src/sdd_subagent_dispatch.cj` 补上，
`sub_agent_tool.cj` 从桩接入；`capabilities` 由 `resolveAgent` 三元组带回
（BaseAgent 上无该成员，与"id 只能从解析路径带出"同款铁律）。

#### 文档订正

`docs/agents/agent-declaration-spec.md`：§3.1 的 `type:` → **`agent_type:`**
（实现读 `agent_type`，老文档是错的）；§3.2 补 7 个扩展键；§7.1 重写（原写的
built-in/user/project/policy 四级目录代码里根本不存在）；新增 §9「技能内 agents 目录约定」。
同时删掉 `skills/cangjie-coder/agents/`（该技能改为纯技能形态，不派生编码子 agent），
`SKILL.md` 去 `agents:` 键、正文改「四步工作流」（v4.0.0）。

---

### 3. agent 操作 Web：从"调接口"回归"像人一样点界面"

上一版的 agent 操作数据库走的是页面 `registerPageTool` 注册的**业务句柄**——
那些句柄内部直接 `useAxiosRepo(...).api().addCrontab(...)`，**绕过界面直连后端**，
这不是人类操作。本版把示范做对：`crontab` 在后端 `skills/` 里**没有** L2 插件，
唯一正确通道就是前端，语义干净。

#### 前端（L2 PageTool）

`crontab-operator/SKILL.md` 用 `page-agent-tool` 原语给出七类人类式操作配方：
`browserState` 读无障碍树 → `click` / `fill` / `select` / `scroll` 真操作渲染后的界面。

| 技能 | 位置 | 内容 |
|------|------|------|
| `crontab-operator` | `apps/web-admin/web/src/skills/crontab-operator/` | SKILL.md（人类式操作哲学 + 页面真实布局 + 7 类配方）+ `reference/crontab-guide.md`（字段详解） |
| `uctoo-operator` | 同上目录 | 模块总览加 Crontab 行，并显式反对调用 `registerPageTool` 业务句柄 |
| `entity-operator` | 同上目录 | 导航护栏（与 `browser_open` 同列禁止 `webmcp-cli` 打开本应用内地址） |

导航护栏三层：

1. `App.vue` 的 `navigate_url` 把任意 URL（相对路径 / localhost / 生产域名）**归一为
   当前标签页 origin + 应用内 path** 后 `router.push`，绝不新开窗口；
2. 技能文档明确「**前端就是用户当前标签页**，不要读 `.env` 的 `VITE_*` 去推断前端地址」——
   之前 agent 就是这么把后端 API 域名 `javatoarktsapi.uctoo.com` 当前端地址，
   又用 CDP 新开浏览器（丢登录态）才失败的；
3. `src/tool/cli_tool.cj` 新增 `isWebmcpCliAppUrlOpen` 护栏：命中
   `webmcp-cli tabs|pages open <同源应用地址>` 直接拒绝并回「改用 `navigate_url`」。

#### 写动作权限（按路由精准放行，不是全局放开）

实测修正了此前的错误假设：`executePageAgentTool` 里 `fill`/`select`/`click`/`scroll`/`hover`
**没有任何动作级开关，handler 无条件执行**，只有 `executeJavascript` 受
`tool-config.ts` 控制（且默认就是 `true`）。所以 `pagetool-init.ts` 头注释里
"不开放 fill/select" 是与当前版本不符的旧假设。本版在 `pagetool-init.ts` 新增
`isCrudwebDbPage()` + `beforeGetBrowserState()` 钩子，对 `/database/uctoo/` 页
`setPageAgentToolConfig({enableExecuteJavascript: true}, {mode: 'merge'})`；
AI 对话界面黑名单不变。

---

## 新增功能

### 长程任务报告直推对话（`artifact_ready`）

产物在 runtime 本地磁盘，前端没有静态服务可访问，只给 `artifactPath` 等于给不了内容。
所以本版采用**推正文不推路径**：

| 层 | 改动 |
|------|------|
| `lrt_event_bridge.cj` | `LrtEventType` 增 `artifact_ready`；新增 `pushArtifactReady(taskId, sessionId, agentId, title, html, artifactPath, traceId)` |
| `lrt_event_relay.cj` | `host.event` 增 `case "artifact_ready"`（供插件侧 emit） |
| `lrt_host_executor.cj` | `runRound` 调 `pushHtmlArtifactsToChat`；`MAX_HTML_ARTIFACT_BYTES` = 1MB、`pushedHtmlArtifacts` 跨回合去重 |
| `TinyRobotChat.vue` | `handleLrtEvent` 增分支 → push `{type:'html_artifact', title, html}` |
| `HtmlArtifact.vue` | iframe 沙箱渲染（既有前端资产） |

边界：session_id 空（纯 cron）直接 return；只处理 `.html`/`.htm`；>1MB 跳过；全程只记日志不上抛。

> **SSE 是行协议，`data:` 必须单行**（本轮最大的坑）：HTML 报告必然含大量换行，
> 一帧被切多段后**后续行被丢弃** ⇒ 残缺 JSON 连 `JSON.parse` 都过不了 ⇒ 事件静默丢失。
> 对策是在 `dispatch` 协议边界做**幂等加固**：`if (wire.contains("\n") \|\| wire.contains("\r"))`
> 就地 `\r`→`\\r`、\n→`\\n`；已转义时空操作、漏转义时救回。实测 28,582 字节 / 309 行的真报告
> 走「事件 JSON → SSE 帧 → parseSSEBlock → JSON.parse → handleLrtEvent」**19/19 通过**。

### evomap 大模型通道（2026-09-23）

`src/model/model_manager.cj` 新增 `evomap` provider（`EVOMAP_BASE_URL` /
`https://api.evomap.ai/v1` / `EVOMAP_API_KEY`），chat 模型分支走 `OpenAIChatModel`
（embedding/image 未加，Gateway 不提供）。
同时给 `normalizeModelName` 加**前缀守卫**：模型名以「非 deepseek 的已知 provider + `-`」
开头时整名原样返回，避免 `evomap-deepseek-v4-flash` 被错改成 `deepseek-flash`。

### ArcBench 通道与 LRT 同通道（2026-10-03）

宿主 `MODEL_PROVIDER=arcbench` + `MODEL_NAME=deepseek-v4-flash-vision-exp`；
L3 插件不继承宿主的 `MODEL_*`，故 `LRT_MODEL_*` 三项（base_url / api_key / name）
**必须同步改成同值**，`.env.example` 同步。

> ⚠️ ArcBench 网关**硬校验：prompt 必须含 `json` 字样才放行 `json_object`，否则 400**
> （`Prompt must contain the word 'json' ...`）。LRT 四个脚本的 prompt 都写了
> 「只输出 JSON，不要解释」所以满足，**以后改这些 prompt 千万别删掉 json 字样**。

### 登录可观测性

| 项 | 内容 |
|------|------|
| 后端分阶段埋点 | `UctooUserAuthController.signin` 对 query / bcrypt / loginLog / authorize 四段计时，打 `[SigninTiming]` INFO；总耗时 >3s 追加 WARN（文案点名最慢阶段，不再硬编码前端超时值） |
| 失败可诊断 | `JWTUtil` 两处 catch 的日志加 `FAILED-TO-SIGN` 标签并指向 openssl，加密库失败不再伪装成「认证失败」 |
| 健康体检 SQL | `sql/incremental/login_health_check_20261003.sql`：登录真实 `status` 分布 + 会话堆积诊断 + 软删清理（保留 90 天，可重复执行） |
| 前端错误分类 | `login-mail.vue` 的 catch 区分超时 / 无响应 / 500 / 业务失败，优先展示服务端 `errmsg`；`login-mail.vue` 不再把任何错误一律映射成「请输入正确的用户名密码」 |

### SDD 技能 v1.2.0：大工程拆分为多子系统工程

工程量巨大时拆成多个独立子系统 SDD 工程，每个颗粒度合适、可独立验收、可与其他子系统组合集成，
**主工程维护各子系统 SDD 工程目录**（`specs/{主}/SPECS_INDEX.md`，八节账本：总览 / 子系统登记表 /
集成契约汇总 / 依赖 DAG / 组合集成验收基线 / 变更影响面 / 风险 / 修订记录）。

- **触发判据**（命中任一进评估）：任务 >40 条 / ≥3 语言标签 / ≥3 可独立上线边界 /
  code 步两轮跑不完 / ≥2 个把关人。加字段、加一个接口、单表 CRUD 不拆。
- **拆分维度优先级**：交付面 → 数据/领域边界 → 技术栈 → 人/回路边界。
  **禁止按文件目录切、按实体个数平均分。**
- **颗粒度红线**：可独立验收任务 ≥3 条（下限）、tasks ≤40 条（上限）、一级子系统 ≤6 个、
  两子系统间 ≥5 个双向接口即判拆错合并。
- **可验收三档**：L1 自测 → **L2 跨子系统集成（硬档位）** → L3 主工程端到端。
  子系统只跑 L1 就报 done，主工程闸口不予确认。
- **集成契约先定后动**（`spec`/`design` 步产出）：接口清单 / 数据契约 / 单向无环依赖 /
  明确不提供什么；破坏性变更双侧同轮，单边先改 = P0。

> 两个从宿主源码实测来的硬判据：`feature_name` 是 `sdd_projects` 的唯一键，
> 子系统必须各自 `feature_name = {主}--{子系统ID}`（双连字符）才能各自一行、各自闸口；
> **不要给子系统传 `output_dir`** —— 不传时落 `specs/{feature_name}` 自然派生，
> 而 `relativeArtifactPath` 恒记 `specs/{feature_name}/{file}`，传了会让库里相对路径与盘上实际路径对不上。

配套新增两份模板 `subsystem-contract-template.md`、`specs-index-template.md`，
并同步进 `prompts/task.md`、`prompts/code.md`、`templates/tasks-template.md` 三处落地。

### plugingen 多表生成与累积能力（sync 内嵌轨）

plugingen 原本只支持单表 CRUD 生成。本版对齐 `crudgen` 的「保护区 / 多表 / 幂等追加」
行为，新增三项能力（**仅 sync 内嵌轨**，`--mode process` 仍单表）：

| 能力 | 行为 |
|------|------|
| 一次生成多表 | `--tables a,b,c` 一次生成多张表的五层 CRUD 产物（PO/DAO/Service/Controller/Route），公共产物正确生成并衔接 |
| 同名 + 不同表追加 | 再次生成同名插件、不同表名，新表 CRUD 正常生成；公共产物基于「历史表清单 + 本次请求表」去重保序合并后整体重渲，旧表信息与二次开发保留、新表加入、表名不重复 |
| 同名 + 相同表只覆盖保护区 | 再次生成同名插件、相同表名，只覆盖该表各层 `//#region AutoCreateCode ... //#endregion AutoCreateCode` 区间内的自动生成内容，区间外二次开发保留；公共产物表清单不变（不含重复项） |

实现要点：

- `PluginGenerator.readExistingTables` 解析聚合路由文件 `src/{PascalName}Route.cj` 中的
  `// table:` 标记行还原历史表清单；`mergeTableList` 去重保序合并。
- `writeRendered` → `TemplateEngine.updateFile` 仅替换 `AutoCreateCode` 区间内容
  （header/footer 保留），所有 per-table 与聚合模板均带该保护区。
- 宿主 `PluginHostManager` 每插件条目仅注册单一 `entry` / `routeClass`，故同名多表插件
  **必须**产出「聚合入口 Plugin + 聚合路由 Route」（name-based，循环装配/注册所有表的
  Service/Controller/Route）；`plugins.yaml` 条目重名时整体替换为聚合类（保留原 order），
  不新增重复条目。

用法：

```bash
# 一次生成多表（同一插件聚合多张表）
cjpm run --skip-build --name magic.plugin.tools.plugingen \
  --run-args "--name github --db uctoo --tables repository,branch,commit,repository_file"

# 同名插件累积追加新表（公共产物自动合并，旧表保留）
cjpm run --skip-build --name magic.plugin.tools.plugingen \
  --run-args "--name github --db uctoo --tables issue,pull_request"

# 同名同表重生成（仅刷新 AutoCreateCode 保护区，二开与公共产物表清单不变）
cjpm run --skip-build --name magic.plugin.tools.plugingen \
  --run-args "--name github --db uctoo --table repository"
```

> ⚠️ 范围：`--mode process`（经 `CrudPluginGenerator`）仍按单表生成，不支持 `--tables`
> 多表累积；多表需求请走 sync 轨。

顺带修复一处预存 bug：`generateBlankPlugin` 曾引用不存在的 `PluginManifestEntry.cj.tpl`
模板（实际为 `PluginEntry.cj.tpl`），导致空白插件从不渲染入口；本版改为正确模板名，
空白插件骨架实际可用。

### 其他

- `skills/web-coder/`、`skills/app-coder/` 新建（纯技能形态，无 `agents/`）。
- `src/utils/startup_trace.cj`：启动阶段落盘 trace（诊断用，走绝对路径）。
- `sql/insert_subagents.sql`：4 条 sub-agent 灌库脚本（显式列名 + 美元引号包长正文）。

---

## 改进

### 启动链路稳定性治理（15+ 轮诊断闭环）

这是本版耗时最长的一条线。症状是 `pluginManager.loadAll` 偶尔不返回、进程挂住，
**且每次卡的点都不一样**（sdd → due_diligence_agent → codelabs 的第一条路由 → 再回 sdd），
说明它**与具体插件无关的并发竞态**，不是"某个插件慢"。

| 轮次 | 结论 | 处置 |
|------|------|------|
| 1 | `awaitActive` **丢失唤醒**：`inst.status` 在 `settleLock` 外读，而 `transitionStatus` 在锁内「置 status + notifyAll」 | 读 status 与 `wait()` 移进同一临界区 |
| 2 | 临界区内调 `transitionStatus` ⇒ 风险（仓颉 `Mutex` 可重入，靠分析易误判） | 临界区只留纯状态读取 |
| 3~4 | 轮询 / `tryLock` 版仍挂 | 定位手段升级 |
| 5 | **`ConfigSyncHandler.startupSync()` 是另一个真卡点**：80 个 key 串行查库 | 整体包进 `spawn {}` 移出启动关键路径 |
| 6 | 把 awaitActive 超时 10s → 30s；加 `[HS-INIT]` / `[HS-PROVIDE]` / `[AWAIT-DIAG]` 探针 | — |
| 7~11 | 卡点反复横跳 | 官方 `cordis-cj` 更新（见下） |
| 12 | 卡点精确定位到 `router.post(...)` 调用点 | — |
| 13 | 控制组实验（注册一个**零捕获**的平凡闭包）同样卡 ⇒ **推翻"闭包捕获 `this`/cordisHost"假说** | — |
| 14 | **主线程阻塞在 `LogUtils.info` 内部**：同一条日志在框架 `.log` 缺席、同时刻后台线程写日志成功 | `log_utils_impl.cj` 新增 `WRITE_LOCK`（后改为 `withWriteLock` 有界 tryLock 500ms，超时丢弃并打 `[LOG-DROP]`） |
| 15 | **`std.core.sleep` 在主线程上会永久挂起**（工程内 18 处 sleep 全在 spawn 出的后台线程） | 新增 `spinWait(d: Duration)` 有界忙等，替换 5 处；`MonoTime.now()` 轮询 + 循环顶部 deadline 兜底 |
| 16~17 | `healCrashed()` 持 `state.lock` 调外部 `isExited` ⇒ AB-BA 风险；`isClosed()` 会被主线程高频调用 | 两处改 **tryLock**；快照在锁内取、判活锁外做 |
| 18 | 官方 `cordis-cj` 更新的「消除静默失败」补丁合并进来 | `plugin_runtime.cj` / `event_registry.cj` 共 9 处 `catch` 改 `eprintln`；`awaitActive` 换回官方验证过的条件变量版；`plugin_manager.cj` env 追加 `CORDIS_PLUGIN_ID/PROVIDE/INJECT` |
| 19 | **真凶：awaitActive 轮询循环体内有 11 处每轮 `eprintln`**。`cjpm run` 把子进程 stdio 接成**管道**，stdio 写同步阻塞 ⇒ 主线程卡在写里 ⇒ while 停滞 ⇒ 循环顶部的 deadline 兜底永远走不到 | 循环内 11 处改 `traceAwaitP(...)` **直写文件**；`traceAwait*` 全部改绝对路径（相对路径在 `target/release/bin` cwd 下写失败且被 `try` 吞，掩盖过真相） |
| 20+ | 卡死消除 | 4 个进程插件首次全部返回 Ok，`plugins loaded=8, failed=0`；整轮启动约 14 秒（此前约 7 分钟才被 Ctrl-C） |

同时落地的三条红线：

- **启动关键路径（reconcile / awaitActive / 日志写出口）禁止 `synchronized` 无限期等锁**，
  一律 tryLock + 有界重试；拿不到就降级（插件 failed / 丢一条日志），不要拖死整机。
- **启动关键路径的循环体内禁止 `eprintln`**；诊断走 `File` 直写，`eprintln` 只留入口/出口一次性调用。
- **仓颉 `std.core.sleep` 不要在主线程上调用**（实测永久挂起）。

附带两个诊断手段：**应急开关** `CORDIS_SKIP_PROCESS_PLUGINS=<name>`（命中即在拉起前跳过该
process 插件，不改 plugin.yaml、不删代码，用于隔离"某个插件拖死启动"）；
以及 Windows 上抓 hang 的手法：`cjdb --batch -p <PID> -o "thread backtrace all" -o "quit" > D:\bt.txt`
，**必须配 CPU 增量测量交叉验证**（`cjdb` 的 lldb 会漏掉 OS 主线程，0ms = 阻塞、满核 = 自旋）。

### 登录性能与可用性

v0.0.28 的登录偶发"帐号密码错误"，本版查清并修掉：

| 环节 | 结论 |
|------|------|
| 是否认证失败 | **不是**。`login_log` 里 6/6 全是 `status=1`（成功），零失败记录 |
| 真因 | bcrypt 单次校验慢，落在 **7.8s ~ 40s**（近两日 16 个样本：min 5.35s / 中位 16.16s / max 40.01s），而前端 axios 超时 **15s** ⇒ 浏览器提前取消（`ECONNABORTED`），前端 catch 又把任何错误统一显示成「请输入正确的用户名密码」 |
| 时间分布 | 用 `login_log.login_at` 劈开：查询 + bcrypt ≈ 16~22s，写库 + 建会话 ≈ 1s ⇒ **95% 时间在 bcrypt** |
| 已推翻的误判 | 「启动同步风暴」（同步中 16.2s vs 同步后 7.8s 的相关性）不成立：同一次会话里 T+411s（同步早已结束 5 分钟）登录仍要 23.11s。「重启后就好了」只是这次恰好落在分布快端，**没有任何资源被释放** |
| **真根因** | `cjpm.toml` 的 `[profile.build]` 原来**只有 `incremental` + `lto`，没有优化级别** ⇒ 全程 `-O0`；且 `--int-overflow` 默认 `throwing`（每个整数运算插溢出检查分支）。bcrypt 热路径约 6800 万次整数运算，本该 ~0.5s 被放大到 7~22s。另外 `lto` **仅 Linux 生效**，Windows 上是空转 |

修复（零业务语义改动）：

| 位置 | 改动 |
|------|------|
| `[package] compile-option` / 两个 `[target.*]` | 追加 `-O2` |
| `blowfish` 依赖 | `compile-option = "-O2 --int-overflow=wrapping"` |
| `jwt4cj` / `f_orm` 依赖 | `compile-option = "-Woff unused -O2"` / `"-O2"` |
| `blowfish-cj/src/bcrypt.cj` | `encipher` 改**标量入参 + 元组返回**（`-> (Int64, Int64)`，第 0 项是 `r ^ P[17]`、第 1 项是 `l`，别写反）；`add32` 提升为模块级函数；`crypt` 里 P/S 由 `ArrayList` 改 `Array<Int64>` |
| 前端 | `uctoo_user.ts` login 显式 `timeout: 30000`（原沿用上层默认 15s） |

> **path-dependency 不继承父级 `compile-option`**，热路径依赖必须逐个显式声明；
> **`--int-overflow=wrapping` 只给 blowfish 加，不能全局加**（会改变业务代码溢出语义）。
> 安全性已核：blowfish 内 `add32` 用 `& 0xffffffff` 掩码、其余全是 XOR，中间值恒 < 2^32，
> 语义完全等价，只是省掉检查分支。
>
> **⚠️ 新增红线：`cjpm` 增量构建不因「依赖 compile-option 变更」重编依赖，
> 改了 compile-option 必须 `cjpm clean && cjpm build`**（或删 `target/release/{blowfish,jwt4cj,f_orm}`）。
> 判据只看产物 mtime 是否晚于 `cjpm.toml`；`.dep-cache` / `.cjpm-history` 只记依赖边、查不出。

### 长程任务（LRT）链路修复

把"长程任务跑不完/只跑一步"的五个独立根因一次性定位并修掉：

| # | 根因 | 修复 |
|---|------|------|
| 1 | **任务静默死亡**（P0）：`ReactExecutor.asyncRun` 的 spawn 块**无 catch**，异常冒到 `AsyncAgentResponse.next()` 的 catch → `finishFn(false)` → `AgentEndEvent(None)` → `onAgentEnd` 把 `case None => 2` 硬编码 completed，且 result 不设 ⇒ `status=2 result=NULL`，前端永远 loading | spawn 加 catch 记 ERROR + `setTerminationReason(Error)` + 返回可读 failMsg；`onAgentEnd` 改写 `(status=3, resultContent=失败原因)` |
| 2 | `PythonExecutorTool.readStreamToEnd` 用 `String.fromUtf8` 硬解，Windows 子进程 GBK 输出 ⇒ 抛 Invalid utf8 ⇒ stdout 全丢 | 内层 try + `unsafe { fromUtf8Unchecked }` 兜底；`parseEnvObject` 默认注入 `PYTHONIOENCODING=utf-8` + `PYTHONUTF8=1` |
| 3 | `WebFetchTool` 网络层失败后仍盲目 verify=true 重试，同 URL 同指纹必败却各等 ~2min | 加 `isNetworkLayerFailure` + for 跳过无意义重试 |
| 4 | `CheckpointManager` 的 filter 是非 JSON 的 `agent_id='${id}'`，每次 parse 失败 ⇒ 退化为「无过滤取最新一条」（跨 agent 串档隐患） | 两处改合法 JSON `{"agent_id":{"equals":"..."}}` |
| 5 | **`agent_id` NOT NULL 插不进**：双身份工程落地不完整（插件 insert 漏写 `agent_id`；`handleLrtPlan` 每次 plan 都建孤儿根任务与宿主争用同一 `taskId`；`host.db` 行级权限不 owner 感知致真人查不到自己的任务） | 静态槽 `identityAgentId` + `setIdentityFromRequest`；`handleLrtPlan` 宿主透传 `task_id` 时直接规划进既有根任务；`buildRowLevelCondition` 对 `agent_tasks`/`crontab` 改成 `(creator IS NULL OR creator='x' OR owner_user_id='x')`，与 `PermissionUtils` 同口径 |
| 6 | 插件找不到 `COMPOSITION.yaml` / `scripts/`：`plugin.yaml` 的 `env:` 段**从未被宿主转发到进程**（`cordis_host_manager.cj:toCordisEntry` 只透传 `command`/`args`）⇒ 资源全部解析到宿主 cwd | 见下「资源定位」 |
| 7 | **自动续跑失控**：`submitTask` 建常驻 crontab 后全工程无代码在终态停表 ⇒ 6 条 `lrt-*` 永久空转（`exec_count` 386）；且 `react_executor` 对普通 chat 异常也套用 LRT「任务执行异常中断」文案 | 采用方案 A：A1 不再建常驻调度（改事件驱动）+ A2 执行器终态一律停表（经 `LrtScheduleBridge` 摘引擎 + `crontab.status=2`）+ A3 显式续跑收敛到 `lrt-intervene resume`（单回合）+ C 失败文案按场景分流（聊天用「本次回复失败」）；治理脚本 `lrt_zombie_task_mark_only_20260923.sql` |

### 插件资源定位与打包

L3 进程由宿主 stdio 拉起、**cwd = 宿主工作目录**，而真实资源在 `skills/long-running-task/`。
`LrtScriptRunner` / `LrtCompositionRunner` 的 `resolveSkillDir` / `resolveScriptsDir` 只查
`LRT_SKILL_ROOT` / `LRT_SCRIPTS_DIR` 两个 env，而 plugin.yaml 的 `env:` 又被丢弃 ⇒ 技能目录解析成 `.`。
本版把 `env:` 转发接上（cordis 侧 `plugin_manager.cj` 的 envMap 补 `CORDIS_PLUGIN_ID/PROVIDE/INJECT`
的同时，宿主侧正式把 `plugin.yaml` 的 `env:` 透传给进程）。

插件侧随之修掉 `plugingen` 生成骨架的三处 API 用法错误（`PluginContext` 不是 `HostContext`；
`ctx.on(...)` 应为 `registerHandler(key, fn)`；`ctx.effect` 是两参），并修掉骨架里
`console.log` —— **L3 进程 stdout 是 stdio RPC 独占通道，打印会污染协议帧**，改为 `eprintln`。

### 网络与 TLS 后端切换

native HTTP 后端 `http=cj` 用的自研 TLS 库 **jinguissl 存在握手 transcript bug**
（`Server Finished verify_data mismatch`），**与服务器/连接相关、非必然复现**：
同一 runtime 对 `api.deepseek.com` 的非流式调用能完成握手并返回真实 402（欠费），
但 sophnet 的流式 chat 必失败。对比旧 git 库确认 `http_cj.cj` / `jinguissl` / `http_lib`
逐字节一致，**没有可移植的 TLS 修复补丁可抄**。

修复：`cjpm.toml` 第 3 行 `compile-option` 的 `--cfg` 由 `http=cj` 改为 **`http=curl`**
（调系统 `curl.exe`，用系统 TLS 绕开 jinguissl）。`http=curl` 后 `http_curl.cj` 首次参与编译，
顺带修掉 `Option<String>` 上裸 `|>` 解析 `contains` 被当成 `Iterable` 容器方法的报错
（照 `http_cj.cj:140-144` 既有写法先 `match` 解包成 `String` 再 `.contains`）。

### 前端质量修复（生产构建暴露的预存 bug）

升级 OpenTiny 3.32.0 后跑 `npm run build` 才发现的一批问题（dev 模式不校验 named export
与相对路径，故此前一直没暴露）：

| 问题 | 修复 |
|------|------|
| `Header.vue` logo 路径 | 子目录里写 `./assets/img/logo.png`，应为 `../assets/...` |
| `ant-design-vue` 图标导入 | 4 个文件从主包导入图标（主包从不 re-export）；改从已 hoisted 的 `@ant-design/icons-vue` 导入，package.json 补依赖 |
| `registerPageTool` 导入源 | 8 个文件从 `@opentiny/next-sdk` 导入（SDK 已移除该 API）；改回本地 shim `@/mcp-servers/registerPageTool`，与全仓 ~100 个文件一致 |
| `App.vue` 两处 `/mcp` 配成 `type:'sse'` | `WebMcpClient.connect` 的 `type:'sse'` 走 EventSource GET，而 runtime `/mcp` 是 POST-only；改 `type:'streamablehttp'`，控制台 `SseError` 消失 |
| `eventStream.ts` 终态帧未 cancel | `while(!signal.aborted)` 包 try/finally，退出时 `reader.cancel()` + abort，让浏览器走干净 FIN 而非 abruptly RST，消除 `TLS read failed: 10053` 噪声 |
| `login-mail.vue` 链接渲染空 `<a>` | `linkifyTextNodes` 用 `m[1]`，正则无捕获组 ⇒ 改 `m[0]` |
| SSE 单行不幂等 | 见「长程任务报告直推」一节 |

### OpenTiny 版本同步（3.32.0）

| 包 | 版本 |
|------|------|
| `@opentiny/vue` / `-theme` / `-icon` / `-locale` / `-huicharts` | **3.32.0**（原 3.31.0） |
| `next-sdk` / `next-remoter` | 0.4.9 → 0.4.11（**选择性源码合并**，严禁整文件替换） |
| `webmcp-cli` | 0.0.8 → 0.0.9（0.0.9 不在 v0.4.11 tag 内，来自单个未打 tag 提交 `47a2b03` WXT 扩展桥接） |
| `tiny-robot` 三件套 | **保持 0.5.1**（官方 catalog 反钉 0.3.1-alpha.6，跟主版本反而是降级） |

> **两个必须记住的陷阱**：① 官方 `package.json` 全用 `catalog:` 引用，本地 web-admin
> 无 pnpm-workspace catalog ⇒ **照搬会直接 `pnpm install` 失败**，必须翻译成本地显式版本；
> ② 本地 lib 是**定制 fork**，`AgentModelProvider.ts`（流式思维链增量拆分器 + 关闭后
> enqueue 静默丢弃的安全包装）与 `TinyRobotChat.vue` 等 7 处本地定制**严禁被官方覆盖**
> （判定依据：对 v0.4.9 / v0.4.11 两版差异行数相同 ⇒ 是本地增量而非版本落后）。

genui-sdk 集成结论：`node_modules/@opentiny/genui-sdk-vue` 是**断裂符号链接**，本地
`TinyRobotChat.vue` 只有 GenUI 开关、**没有渲染器**。frameworks/vue 声明 tiny-robot 0.3.3
（与 D1 冲突）且 `workspace:*` 依赖不收敛 ⇒ 本版暂缓（P2）。

### 控制台降噪

| 噪声 | 根因 | 处置 |
|------|------|------|
| 散落无前缀的裸 `true` | `libs/jwt4cj/src/base_verification.cj:336` 残留调试 `print(isValid)`（JWT `nbf` 校验时每请求打印） | 删除（vendored 库，已加注释以免下次库更新被覆盖） |
| 每 ~10 分钟一条 `TLS server handshake failed: Client Finished verify_data mismatch` | `HTTPServer.cj` 的 `config.errorLog` 把客户端侧/握手期/keep-alive/idle 回收的**良性**事件也按 `logger.error` 上报 | 6 类良性关键字降 `logger.debug`，其余真实错误仍 ERROR |
| `conn state: NEW` 刷屏 | `config.connState` 每新连接 INFO 一次 | 仅 `name != "NEW"` 才 `logger.info` |

### 安全与开源准备：SQL 脱敏

`sql/uctooDB.sql` 是随 runtime 开源的库结构与初始数据。复核后修掉 6 类遗漏：
`opengauss_orm_connectionUrl` 真实 DB 密码、`footer.contact` 真实 QQ 号、
`QCLOUD_COS_BUCKET` 腾讯云 APPID、`agent_skills` 的 GitHub 仓库账号、
本地绝对路径（`UCTOO_API_SKILL_DIR` / `SKILL_INSTALL_PATH` / `SSL_CERT_FILE` 等）、
图片 URL 中的云账号 APPID 与环境 ID。最终残留扫描 6 项全为 0。

判定为**安全保留**的「产品级演示种子数据」（`application` / `company` /
`messages` / `tasks` / `crontab` / `db_info` 元数据、`entity` 的 `testest111` 等）未动。

### stdx OpenSSL DLL 文档化

社区用户反馈「新机器搭环境 → 登录 401」，根因链已实测闭环并写成文档
（`skills/uctoo-dev-manual/specs/runtime-openssl-dll-guide.md` + 仓颉官方 issue 草稿）：

1. `JWTUtil.generateAccessToken` → `HMAC(privateKey, HashType.SHA256)` 走 stdx crypto
2. stdx 的 `libcangjie-dynamicLoader-opensslFFI.dll` 把 **`libcrypto-3-x64.dll` /
   `libssl-3-x64.dll` 写死在二进制里**（已向官方确认 PE 导入表，三版本 stdx 均不带这两个 DLL）
3. 用户机器装了 OpenSSL 4.x（只有 `libcrypto-4-x64.dll`）⇒ `SHA256_Init` 找不到
4. jwt4cj 的 catch 吞掉异常返回空 token ⇒ 下游 `DeserializeUserMiddleware` /
   `RequirePermissionMiddleware` 一律 401

一键修复：`package_release` 出包时把 `bin/libcrypto-3.dll` / `libssl-3.dll`
复制一份成 `*-3-x64.dll`（治本，本版已接入打包脚本）；临时绕过是复制系统 DLL 重命名。

---

## 数据库变更

| 脚本 | 内容 |
|------|------|
| `20260920_agent_tasks_owner_user_id.sql` | `agent_tasks` 增 `owner_user_id`（双身份） |
| `20260921_dual_identity_owner_user_id.sql` | 双身份口径落地 |
| `sql/insert_subagents.sql` | 4 条 sub-agent 灌库 |
| `20260927_sdd_orchestration_permissions.sql` | SDD 三个语义入口（`sdd/start`、`sdd/run-stage`、`sdd/status`）注册 + 授权 |
| **`sdd_subagent_20260927.sql`** | `sub_agent_invocations`（追加入口审计账本）+ `sdd_projects`（工程投影，唯一键 `feature_name`）+ 视图 `v_sub_agent_stage_cost`；幂等，BEGIN/COMMIT，含回填与自检 |
| `20260928_sdd_gate_review_permission.sql` | `POST /api/v1/uctoo/sdd/review` 注册 + 授权（漏登记则闸口按钮全 403） |
| `lrt_zombie_task_mark_only_20260923.sql` | 僵尸任务治理（保留现场、只标记；可回退） |
| `login_health_check_20261003.sql` | 登录真实 status 诊断 + 会话堆积软删清理（保留 90 天，可重复执行） |

> `v_sub_agent_stage_cost` 是**视图**，不在插件 `tableWhitelist` 内（host 按表名拦截）——
> 前端看账本只能走宿主侧只读 API 直连 ORM，或把视图名显式加进白名单。

---

## 迁移指南

### 从 v0.0.28 升级

1. **升级 Runtime 服务**
   ```bash
   npm install @opencangjie/skills@latest
   npx skills install-runtime --runtime-version 0.0.29
   npx skills restart
   ```

2. **执行增量 SQL（幂等，按序执行）**
   ```bash
   psql -U postgres -d uctoo -f sql/incremental/20260920_agent_tasks_owner_user_id.sql
   psql -U postgres -d uctoo -f sql/incremental/20260927_sdd_orchestration_permissions.sql
   psql -U postgres -d uctoo -f sql/incremental/sdd_subagent_20260927.sql
   psql -U postgres -d uctoo -f sql/incremental/20260928_sdd_gate_review_permission.sql
   ```

3. **全量重编（本版是硬性要求）**
   ```bash
   cd apps/agentskills-runtime
   cjpm clean && cjpm build     # ⚠️ 改过 compile-option 必须 clean，增量不会重编依赖
   ```

4. **编译并部署 sdd 插件**
   ```bash
   cd skills/sdd && cjpm build
   ```
   > 该插件是独立包，**不在** runtime 的 `[dependencies]` 中，主包 `cjpm build` 不会编译它。

5. **模型通道检查**：若使用 ArcBench，`.env` 的 `MODEL_PROVIDER/NAME/CONFIG`
   与 `LRT_MODEL_BASE_URL/API_KEY/NAME` 三项**必须同值**（插件不继承 `MODEL_*`）。

6. **前端依赖重装**
   ```bash
   cd apps/web-admin/web && pnpm install && npm run build
   ```

> 对外 REST API 路径、WebSocket 消息协议、既有 SSE 事件格式均保持不变。
> 新增 `/api/v1/uctoo/sdd/*` 一组端点；`sdd_projects` / `sub_agent_invocations` 的
> 通用 CRUD 路由按 ADR-001 **保持注释未启用**，无新增写入口。

---

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~440MB（解压 ~1.4GB）
- 包含: 所有依赖 DLL，内嵌 http_lib 依赖链 + cordis-cj 依赖链；出包脚本已补 `libcrypto-3-x64.dll` / `libssl-3-x64.dll`

### Linux x64
- 待构建发布

### macOS
- x64 / ARM64：待构建发布

---

## 安装使用

### 使用 JavaScript SDK

```bash
npm install @opencangjie/skills@latest
npx skills install-runtime --runtime-version 0.0.29
npx skills start
```

### 构建说明

```bash
# 主包（自动编译全部 path 依赖；改过 compile-option 请用 clean 版）
cjpm clean && cjpm build

# sdd 插件（独立包，须单独构建）
cd skills/sdd && cjpm build

# 前端
cd apps/web-admin/web && npm install && npm run build
```

### 启动排障开关

```bash
# 怀疑某个 process 插件拖死启动：在拉起前跳过它（不改 plugin.yaml、不删代码）
set CORDIS_SKIP_PROCESS_PLUGINS=sdd
```

### 生成 L3 进程轨插件

> ⚠️ 顺序红线：**先跑生成器出骨架 → 再覆盖定制内容**。
> `plugingen --mode process` 会覆盖 `SKILL.md` 与 `plugin.yaml`（即使不带 `--table`），
> 若目标目录未纳入 git 跟踪将无法回滚。

```bash
cjpm run --skip-build --name magic.plugin.tools.plugingen -- \
  --name {table} --db {db} --table {table} --mode process --contract

cd skills/{table} && cjpm build
```

卸载同一进程插件（自动识别轨 → 先列计划 → 确认后加 `--force`）：

```bash
cjpm run --skip-build --name magic.plugin.tools.pluginuninstall -- --name {table} --purge
cjpm run --skip-build --name magic.plugin.tools.pluginuninstall -- --name {table} --purge --force
```

---

## 相关文档

| 文档 | 说明 |
|------|------|
| [SDD 技能说明](./skills/sdd/SKILL.md) | 六步流程、人在回路、子 agent、大工程拆分 SOP（v1.2.0） |
| [SDD 运维手册](./skills/sdd/OPS.md) | 排障表 + 13 条防回退逐条对照 |
| [SDD 测试与验收方案](./.codeartsdoer/specs/sdd/test-plan.md) | 七组用例 A~G，逐条追溯 REQ 编号 |
| [ADR-001 存储层形态](./.codeartsdoer/specs/sdd/adr-001-storage-layer.md) | 两张新表为何不是后台 CRUD 实体 |
| [agent 声明规范](./docs/agents/agent-declaration-spec.md) | `agent_type` / 扩展键 / 技能内 `agents/` 约定 |
| [crontab 人类式操作配方](./../../web-admin/web/src/skills/crontab-operator/SKILL.md) | page-agent-tool 七类操作 |
| [子 agent 声明机制研究](./.codeartsdoer/specs/sdd/research.md) | 声明/解析/同步/派生四层现状核验 |
| [启动卡死诊断记录](./logs/startup-hang-awaitactive-final-fix.md) | awaitActive 终版修复与判读表 |
| [落盘 trace 说明](./src/utils/startup_trace.cj) | 启动阶段诊断（绝对路径） |
| [OpenSSL DLL 指引](./skills/uctoo-dev-manual/specs/runtime-openssl-dll-guide.md) | 401 根因、三档修复、排查顺序 |
| [plugingen 使用手册](./skills/uctoo-dev-manual/tools/plugingen.md) | 插件生成器多表/累积/保护区用法（v0.0.29 新增） |
| [长程任务增量 SQL](./sql/incremental/20260911_long_running_task.sql) | 产物表与自进化记录表 DDL |
| [SDD 子 agent 增量 SQL](./sql/incremental/sdd_subagent_20260927.sql) | 两张表 + 成本视图 |

---

## 已知问题

- **sdd 插件尚未走完第 0→4 轮联调**：`skills/sdd/` 的编译、闸口回执、契约校验、成本账本
  在宿主侧编译通过，但端到端验收清单（12 步）转人工执行，结果需回填
  `specs/{feature_name}/test-report.md`
- `skills/sdd/` 早期**未纳入 git 跟踪**，plugingen 覆盖事故时无法 `git checkout` 回滚；
  生成器执行顺序红线已写进 `tasks.md`，但目录跟踪状态待补
- `sdd_projects` / `sub_agent_invocations` 的 `permissions` 节点仍存在于权限表
  （菜单项不会因前端摘除而消失），**必须不授予任何非超管角色**，否则等于开了一个隐藏后台入口
- awaitActive 的诊断探针（`[HS-INIT]` / `[AWAIT-DIAG]` / `[STARTUP-DIAG]` / `traceAwaitP`）
  仍保留在 `cordis_host` 与 `main.cj`，确认稳定后建议清理
- **会话永不过期**：`uctoo_session` 无 `expires_at`，`createSession` 建行后无任何定时失效，
  累计约 2500 行（demo 用户独占多数）；相关清理 SQL 在 `login_health_check_20261003.sql`，
  默认 `BEGIN...ROLLBACK` 干跑，需人工改 COMMIT 才生效
- **日志无滚动**：`apps/agentskills-runtime/logs` 已 82MB / 65 个文件，每次启动生成新文件从不回收
- `DatabaseConnection.cj` 的 `maxConnections` / `connectionTimeout` 是**死配置**：
  `ORMInitializer.init` 调 `ORM.register("postgres", url, [])` 传空 options，这两个值从未生效；
  真实池参数是 f_orm 的（`getPoolMaxSize` = 10、`getConnectTimeout` = **50ms**）
- **cjpm 增量构建不因「依赖 compile-option 变更」重编依赖**：改了 `cjpm.toml` 里
  `[dependencies].compile-option` 就必须 `cjpm clean && cjpm build`，否则 `-O2` 一次都不会生效
- **stdx 的 OpenSSL DLL 硬编码问题**尚未在 stdx 侧修复（issue 草稿已备），Windows 上
  用 stdx crypto 的用户若装了 OpenSSL 4.x 仍会 401，本版靠出包复制 `*-3-x64.dll` 规避
- **ArcBench 网关硬校验 prompt 必须含 `json` 字样**，改 LRT 脚本 prompt 时删掉会导致
  整条 json_object 降级链全 400
- `plugingen --mode process` 生成的 V4 CRUD handler 为框架桩，需按具体业务实现；
  该模式也不写 `plugins.yaml`，登记条目需手工追加
- OpenTiny `genui-sdk-vue` 依赖断裂、frameworks/vue 与 tiny-robot 0.5.1 版本冲突，
  GenUI 渲染器集成暂缓（P2）
- cordis-cj 的 UDS 传输在 Windows 上不可用，L3 轨固定使用 stdio
- L3 进程轨插件的 `stdx` DLL 路径注入依赖 `CANGJIE_STDX_PATH` 环境变量，
  某些 cjpm 配置下可能需手动设置
- `pluginuninstall` 是**配置态** CLI：不负责终止进程实例，`.exe` 被运行中进程占用时删除会失败

---

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- OpenTiny 开源社区（TinyRobot / next-remoter / next-sdk）
- zcwl / multi-search-engine 技能原作者（MIT 许可）
- cordis-cj 开源项目（ystyle）
- 反馈 OpenTiny 3.32.0 升级与登录 401 问题的社区开发者

---

## 支持

如有问题，请通过以下方式获取帮助：
- AtomGit Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

---

## 下一版本计划

- sdd 插件联调收口：按 `test-plan.md` 第 0→4 轮执行并回填 `test-report.md`
- 长程任务与 SDD 的更深整合（LRT 的规划/执行链与 SDD 六步的对齐）
- Agent 直接操作 Web 应用端到端打通（genui-sdk-vue 依赖修复后重开）
- 插件市场 Web UI（技能市场可视化展示与一键安装）
- L3 进程轨插件热更新（不重启宿主替换插件版本）
- 会话过期与日志滚动（把 `login_health_check_20261003.sql` 的软删与保留策略产品化）
- 性能监控面板（插件加载耗时、路由响应时间、进程资源占用）
- OpenTiny 依赖跟随官方发行线；`tiny-robot` 维持 0.5.1 直至官方 catalog 放开

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
