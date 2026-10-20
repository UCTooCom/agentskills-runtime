# 研究文档：插件系统增强迭代（plugin-system-enhancement）

> 模板：`skills/sdd/templates/research-template.md`
> 落盘位置：`specs/plugin-system-enhancement/research.md`（runtime 自有 `specs/`，未落 `.codeartsdoer/specs/`）
> 研究日期：2026-10-19
> 关联：`SPECS_INDEX.md`（子系统目录与集成契约，唯一权威账本）

---

# 用户原始需求

用户原话（2026-10-19）：

> "之前对4个智能体开源项目的插件机制进行了一个横向对比分析，请参考 `docs/ref/plugin-mechanism-comparison-wx.html`，对 ASR 的插件系统迭代演进提供了一些建议和启发，`\.codeartsdoer/specs/plugin-system` 这个是已开发完成的插件机制的关联前置 sdd 工程目录，可以参考，请在 `specs` 目录创建插件系统增强迭代的 sdd 工程目录，使用 `skills/sdd` 技能创建全部 sdd 文档。"

- **目标**：以横向对比报告第 9 章「对 ASR 的启示」为需求源，把 ASR 插件系统的迭代增强固化成一套可回放的 SDD 工程文档。
- **范围（In Scope）**：
  1. 报告 §9 建议表中 P0 / P1 / P2 共 7 条增强项（第 8 条 RSI 常驻自进化循环移交既有 `specs/RSI`，第 9 条"保持项"不改动）；
  2. 基线侦察中顺带暴露、且与上述增强项同源的安全缺陷（环境变量泄漏、`host.secret` 越权取值）；
  3. 主工程目录 + 6 个独立子系统 SDD 工程的完整文档。
- **非范围（Out of Scope）**：
  1. **不复活 `dylib` 轨**（见 §五 决策 D-1）；
  2. **不重写**既有插件系统（`.codeartsdoer/specs/plugin-system` 已开发完成，本次只做增量增强）；
  3. **不做** RSI 每 N 轮后台自评触发器与 LRT 五环节编排（移交 `specs/RSI`）；
  4. **不做** `plugin + SKILL.md` 三维一体、三轨 `mode` 声明、确定性代码腿工具链本身的改造——这三项是报告 §9 明确标注的"保持项"。
- **关键约束**：仓颉语言（Cangjie）；AI **不运行 `cjpm build`**（编译由人工在独立 cmd 完成）；铁律 9 复用优先（默认不新建表）；铁律 14 二次开发底座优先；铁律 15 大工程拆分为多子系统。

---

# 研究结果

## 一、现状与定位

### 1.1 与既有相关工程的关系

| 既有产物 | 路径 | 关系 | 本次是否要动 |
|---|---|---|---|
| 插件系统前置 SDD 工程（**已开发完成**） | `.codeartsdoer/specs/plugin-system/{spec,design,tasks,research,review-report,lightweight-plan}.md` | **前置基线**，本次的需求与验收以它为存量事实来源 | 只读参考，**不重写** |
| 插件系统实现 | `src/plugin/**`（13 个核心文件）+ `libs/plugin-spi/**` + `libs/cordis-cj/**` | 增强落点 | 增量改造 |
| 横向对比报告 | `docs/ref/plugin-mechanism-comparison-wx.html`（1389 行，§9 建议表） | **需求源** | 只读 |
| RSI 工程 | `specs/RSI/` | 邻接，承接自进化循环 | 移交，不纳入 |
| SDD 技能 | `skills/sdd/`（SKILL.md + 5 子 agent + 6 prompt + 9 模板） | 流程依据 | 只读 |

关键判断：本次是**增量增强**，不是重做。既有三轨框架、注册表、事件总线、L3 宿主服务均保持，只在"加载前校验 / 能力治理 / 依赖编排 / 崩溃自愈 / 创作工具链"五处补缺口。

### 1.2 本质区别（决定不能简单复用）

本次增强与既有 `plugin-system` 工程形似但神异：

| 维度 | 既有 plugin-system 工程 | 本次 plugin-system-enhancement |
|---|---|---|
| 要解决的问题 | 从 0 到 1：**让插件能加载、能跑** | 从 1 到 N：**敢让第三方二进制进来** |
| 信任模型 | 默认信任（插件与宿主同源） | 默认不信任（声明 vs 实际，机器验证） |
| 失败代价 | 加载失败 = 功能缺失 | ABI 不兼容 = **段错误**（原生二进制，非异常） |
| 治理对象 | 插件生命周期 | 插件的**版本契约 + 能力边界 + 崩溃行为** |

工程结论：**复用底座（三轨、注册表、事件总线、宿主服务、工具链），不复用其"默认信任"的前提**——本次的全部增量本质上是给既有底座加装"校验与门禁"。

## 二、已有可复用基础设施盘点

> 仅列强相关项，标注"路径 + 能复用什么 + 复用方式"。

### 2.1 插件系统底座（直接复用）
- `src/plugin/plugin_config.cj:72-112`（`PluginManifestEntry`）—— 清单模型，复用方式：**扩展字段**（新增版本/能力/依赖字段），不新建结构。
- `src/plugin/plugin_registry.cj:39-56,143-180`（register 幂等 / snapshot / restore）—— 复用方式：**原样调用**，版本校验失败时的"回滚注册表"即复用 `restore`。
- `libs/plugin-spi/src/plugin_event_bus.cj:121-152`（emit / waterfall，异常只记日志继续）—— 复用方式：**原样调用**，崩溃/重启事件走既有总线。
- `src/plugin/plugin_sync_bridge.cj:38-59,64-90`（内存 → `agent_skills` 库回写）—— 复用方式：**原样调用**，观测状态沿用既有通道，不新建表。
- `src/plugin/plugin_host_manager.cj:114-160`（`loadAll` 三轨分发）、`cordis_host_manager.cj:196-204`（期望态 reconcile）—— 复用方式：**在其上插入校验点**。

### 2.2 死代码资产（改造后复用，本次最大复用机会）
- `src/security/permission_service.cj` —— 已有 fs/net/cmd/memory/cpu/timeout **六类策略模型** + `PermissionCheckResult.allow()` `:56` / `.deny(reason)` `:65` + `checkCapability` `:292-309` + DENY 审计 `:171/184/203/224/239/257/271/285`。
- `src/security/sandbox_executor.cj:72` —— `SandboxExecutor` / `createSandbox` `:162-169`。
- **现状**：`grep "import magic.security" src/` → **0 命中**，完全未接线。
- 复用方式：**改造后复用**（注意 `permission_service.cj:295-322` 对未知 capability type 走 **fail-open**，这是复用前必须先修的 P0）。

### 2.3 既有算法与范式（参考复用）
- `libs/cordis-cj/cordis_host/src/plugin_host.cj:984-1010` —— `topoSort`（按 provide/inject 分层）。现状对宿主恒 no-op（因 `toCordisEntry` 不填 provide/inject），复用方式：**补齐输入使其生效**，不另写一套。
- `libs/cordis-cj/cordis_host/src/plugin_host.cj:920-980` —— `healCrashed()` 崩溃自愈已存在，复用方式：**在其上加装退避/计数/熔断**。
- `src/interaction/error_recovery_manager.cj:72-103`、`src/app/services/crontab/retry/*` —— 既有退避范式，复用方式：**参考其策略形状**。
- `src/skill/lrt_composition_runner.cj:11-12` —— 复用 `CompositionExecutor` 的拓扑排序/环检测，复用方式：**范式参考**。

### 2.4 确定性工具链（原样调用）
- `loaddbinfo` → `plugingen` / `crudgen` → `crudweb`；下线 `pluginuninstall`（`src/plugin/tools/pluginuninstall/pluginuninstall.cj`）。
- `plugingen` 默认 L3 process 轨（`src/plugin/tools/plugingen/plugingen.cj:48` `var mode = "process"`）—— 与本次"默认即最安全那轨"的定位一致。

## 三、能力缺口分析（已有 vs 待建）

> 全部经源码实证（grep / read），非文档转述。

| # | 缺口 | 现状（证据） | 待建（本工程范围） | 复用/新建 | 归属子系统 |
|---|---|---|---|---|---|
| G-01 | **无版本协商** | `pluginApi`/`apiVersion`/`hostVersion`/`handshake` 全仓 **0 命中**；`@PluginAnnotation.version`（`plugin_annotation.cj:37`）存在但 `plugin_loader.cj:64/69` 从不读；生成器写 `version:1.0.0`（`CrudPluginGenerator.cj:156`）但 `plugin_config.cj:122-208` 从不解析 | 宿主 API 版本常量 + 清单版本字段 + 加载前校验 + L3 协议版本 | 新建（复用 `PluginRegistry.restore` 做回滚） | version-guard |
| G-02 | **无能力宣告握手** | `InitializeParams`（`message.cj:10-53`）无 capabilities；initialize handler（`plugin_host.cj:104-135`）只 `checkMissing` `:115` | L3 启动后上报将注册 Service/Route，与声明比对，不符拒绝挂载 | 新建（复用 IF-07 禁列表） | capability-handshake |
| G-03 | **能力门禁只覆盖 DB 表名** | `tableWhitelist`（`plugin_config.cj:106-108`）；强制点仅 `cordis_host_services.cj:451-468` 与 `:286-302`；`:476-482` 三种操作一律放行 | 扩为通用能力清单（网络/文件/子进程/环境变量/secret/DB），**缺省全拒** | **改造复用 `src/security/`** | capability-governance |
| G-04 | **网络出口无控制** | `executeMcpOperation` `:1155-1186` 只校验非空，无 alias/tool 白名单，只有审计无拦截 | MCP alias + tool 白名单 | 改造复用 | capability-governance |
| G-05 | **宿主环境全量泄漏** | `plugin_config.cj:100-101` 声明"不自动注入宿主环境"但字段从未使用；`plugin_manager.cj:98-100` 实际 `getVariables()` 全量继承后 launch `:162` | env 白名单（缺省不继承） | 改造 | capability-governance |
| G-06 | **`host.secret` 越权取值** | `cordis_host_services.cj:116-128` 对任意 `env:NAME` 直接返明文 `:125`，无 per-plugin 授权 | per-plugin secret 授权清单 + 审计 | 改造 | capability-governance |
| G-07 | **依赖只做事后断言** | `checkDependencies` `plugin_loader.cj:122-130` 仅存在性检查，无拓扑无环检测；design.md:889 承诺的拓扑排序未兑现 | 依赖推导替代/兜底 `order` 数字排序 + 环检测 + 逆序停机 | 复用 cordis `topoSort` | dependency-graph |
| G-08 | **崩溃自愈无退避/计数/熔断** | `healCrashed` `:963-978` 直接 `launchPlugin` `:972`；`PluginInstance`（`plugin_instance.cj:18-31`）无 restartCount；`autoRestart`（`plugin_config.cj:103-104`）**解析但零消费点** | 退避 + 计数 + 风暴熔断 + crash-reason 结构化 + `autoRestart` 真正消费 | 在既有 `healCrashed` 上加装 | lifecycle-observability |
| G-09 | **生成器不产出测试** | 产出清单（§2.4）无 `test/`、无 `*_test.cj` | `plugingen` 模板自带"跑得起的最小测试" | 新增 | authoring-toolchain |
| G-10 | **无独立 validate** | 唯一 `plugin_loader.cj:111-117` 只检查 `getName().isEmpty()`；`plugingen` 选项全集 `:345-354` 无 `--validate` | 独立 `plugin validate` 命令 | 新增 | authoring-toolchain |
| G-11 | **`inspectProcessPlugin` 文档与实现不符** | `cordis_host_manager.cj:391` docstring 承诺 pid/restartCount，实现 `:395-414` 没有 | 实现对齐 docstring | 修正 | lifecycle-observability |
| G-12 | **`dylib` 轨运行时不存在** | `PluginDylibLoader` 全仓零调用；`loadAll` 对 Dylib 走与 Sync 相同的 `loadSingle`（`plugin_host_manager.cj:135`）；`unloadDylib` 空实现 `:146-151` | **本次不做**（见 §五 D-1），仅预留接口 | — | （单独立项） |

## 四、推荐工程方案

### 4.1 总体形态

一个**主工程 + 6 个独立子系统 SDD 工程**的组合：主工程 `plugin-system-enhancement` 只做目录账本（`SPECS_INDEX.md`）、总体需求/设计/集成任务与端到端验收；6 个子系统各自独立六步、独立闸口、独立验收。

### 4.2 核心编排草图（依赖与闸口）

```
                 ┌──────────────────┐
                 │  version-guard   │  P0（最上游：协议版本字段先冻结）
                 └────────┬─────────┘
                          │ IF-04 (InitializeParams.protocolVersion)
                 ┌────────▼─────────────────┐
                 │  capability-governance   │  能力枚举 + 门禁 + env/secret 修复
                 └────────┬─────────────────┘
              ┌───────────┼───────────────┐
     ┌────────▼──────┐  ┌─▼──────────────▼─────────┐
     │ capability-   │  │  authoring-toolchain      │
     │ handshake(P0) │  │  （模板测试 + validate）  │
     └───────────────┘  └───────────────────────────┘

  并行、无上游依赖：dependency-graph（P2） / lifecycle-observability（P2→按 P1 排期）
```

- 每个子系统后挂 `gate-{stage}` 人在回路闸口（confirm / revise / abandon）。
- 上游进 `code` 前必须已达 `test`；`version-guard` 与 `capability-handshake` 改同一 `InitializeParams`，**强制串行**（R-05）。

### 4.3 复用决策（严守"优先复用"）

| 决策 | 结论 | 理由 |
|---|---|---|
| 数据库表/列 | **0 新建表、0 新建列** | 状态类沿用 `agent_skills.runtime_status` / `last_error`；清单一律走 `plugin.yaml`；观测增量优先塞进既有 JSON 承载字段。`lifecycle-observability` 若确需新列，须先论证复用不成立（R-06） |
| 能力模型 | **改造复用 `src/security/`**，不新建 | 六类策略 + 沙箱已实现（R-02）。唯一阻塞是 `permission_service.cj:295-322` 未知 capability 走 fail-open，须先修 |
| 拓扑排序 | **复用 cordis `topoSort`**，不另写 | `plugin_host.cj:984-1010` 已存在，只是输入为空；补齐 `toCordisEntry` 的 provide/inject 即可生效 |
| 崩溃自愈 | **在既有 `healCrashed` 上加装** | `plugin_host.cj:920-980` 已工作，缺的是退避/计数/熔断 |
| 版本回滚 | **复用 `PluginRegistry.restore`** | `plugin_registry.cj:160-180` 已有快照/恢复，正是 REQ-PS-010 要求的能力 |
| 事件通道 | **复用 `plugin_event_bus` + `PluginSyncBridge`** | 崩溃/重启事件与状态回写均有既有通道 |

### 4.4 需新建的最小集合

- `PluginError` 新增版本类错误码（`plugin_types.cj:56-63`）：`VersionMismatch` / `IncompatibleApi` / `UnsupportedHost`。
- `InitializeParams` 新增两个字段：`protocolVersion`（version-guard）、`declaredCapabilities`（capability-handshake）。
- `PluginManifestEntry` 新增：版本字段、能力声明字段、依赖声明字段（`plugin_config.cj:72-112`）。
- `plugingen` 新增：`--validate` 子命令 + 模板测试文件。
- 一个跨子系统共享的上游规则收口文件（authoring-toolchain 设计为 `rules_upstream.cj`）。

## 五、关键设计决策与风险

1. **D-1（`dylib` 轨）**：决策为**本次不复活**。原因：`PluginDylibLoader` 是孤儿代码（全仓零调用），`loadAll` 对 Dylib 实际走 Sync 路径——报告 §9 P0 第 1 条"给 Dylib/Process 两轨补版本协商"中，**Dylib 那一半当前无处可挂**。缓解：`version-guard` 只预留 dylib 版本校验接口并显式标注未接线；dylib 复活建议单独立项（如 `specs/plugin-dylib-track`），需产品决策是否值得投入。已登记为 `SPECS_INDEX` §7 **R-01**。
2. **D-2（`src/security/` 复用）**：决策为**改造复用而非新建**。原因：六类策略 + 沙箱已完整实现，新建即重复实现，违反铁律 9。风险：`permission_service.cj:295-322` 对未知 capability type **fail-open**，且该模块零引用意味着从未被测试过。缓解：复用前先修 fail-open 为 fail-closed 并补单测。已登记为 **R-02**。
3. **D-3（环境变量泄漏）**：决策为**纳入本次修复**。原因：`plugin_manager.cj:98-100` 全量继承宿主环境，插件可直接读取 `orm_connectionUrl`、LLM key 明文，且与 `plugin_config.cj:100` 的注释、`cordis_host_services.cj:91` 的安全边界声明**直接冲突**。这是架构红线，不另立子系统，并入 `capability-governance`。已登记为 **R-03**。
4. **D-4（RSI 自进化循环）**：决策为**移交 `specs/RSI`**。原因：报告 §9 第 8 条的"每 N 轮后台自评触发器 + LRT 五环节编排"属 RSI 主线，与插件系统增强的交付面不同；本工程只交付其"确定性代码腿工具链"侧（`authoring-toolchain`）。
5. **D-5（共享文件串行）**：`InitializeParams` 被 `version-guard` 与 `capability-handshake` 同改。决策为**串行 + 契约冻结**（先 IF-04 后 IF-08）。已登记为 **R-05**。
6. **约束（工程红线）**：AI **不运行 `cjpm build`**；编译、类型检查由人工在独立 cmd 完成并回传结果。所有文档结论必须带 `文件:行号` 证据，查不到标注"待核实"，禁止编造 API。
7. **风险（防回退）**：既有 4 个 sync 插件（`src/plugins/generated_anchors.cj:10-17` 锚定 EntityPlugin/EntityRoute/FeedbackPlugin/FeedbackRoute）与 51 个 skill 插件必须**零回归**。缓解：新增校验一律**缺省放行/向后兼容**（存量清单无版本与能力声明时不拒绝加载），并在 §5.1 用例 5 设为硬锚点。已登记为 **R-04**。

## 六、后续步骤指引（交接给 spec / design / tasks）

- **下一步（需求规格）**：固化 7 条增强项为跨子系统 REQ（版本协商 / 能力清单 / 能力握手 / 依赖编排 / 崩溃自愈 / 创作工具链 / 存量零回归），并定义跨子系统 DFX 红线。
- **再下一步（设计）**：确定 6 个子系统的集成契约（IF-01~IF-12）、依赖 DAG、共享文件串行约定、端到端验收基线。
- **任务规划**：主工程只出**集成与编排类**任务（契约冻结、串行协调、L2/L3 验收、防回退锚点）；各子系统内部细节任务留在各自 `tasks.md`。

---

# 附录 A：本研究直接复用的关键文件索引

| 用途 | 文件 | 备注 |
|---|---|---|
| 需求源（P0/P1/P2 建议表） | `docs/ref/plugin-mechanism-comparison-wx.html` §9 | 只读引用 |
| 存量需求基线 | `.codeartsdoer/specs/plugin-system/spec.md`（含 REQ-PS-010 `:179`） | 原样参考 |
| 存量设计基线 | `.codeartsdoer/specs/plugin-system/design.md`（§2.4 `:889` 拓扑排序承诺） | 原样参考 |
| 清单模型 | `src/plugin/plugin_config.cj:72-112` | 扩展字段 |
| 注册表快照/回滚 | `src/plugin/plugin_registry.cj:143-180` | 原样调用 |
| 事件总线 | `libs/plugin-spi/src/plugin_event_bus.cj:121-152` | 原样调用 |
| 状态回写 | `src/plugin/plugin_sync_bridge.cj:38-90` | 原样调用 |
| 三轨分发 | `src/plugin/plugin_host_manager.cj:114-160` | 插入校验点 |
| 能力模型（死代码） | `src/security/permission_service.cj`、`src/security/sandbox_executor.cj` | **改造复用** |
| 拓扑排序 | `libs/cordis-cj/cordis_host/src/plugin_host.cj:984-1010` | 补齐输入复用 |
| 崩溃自愈 | `libs/cordis-cj/cordis_host/src/plugin_host.cj:920-980` | 加装退避/计数/熔断 |
| 退避范式 | `src/interaction/error_recovery_manager.cj:72-103` | 范式参考 |
| 脚手架 | `src/plugin/tools/plugingen/plugingen.cj:48` | 原样调用 + 增 `--validate` |
| 流程依据 | `skills/sdd/SKILL.md`（铁律 9/12/14/15） | 原样遵循 |
