# 技术设计文档：插件系统增强迭代（plugin-system-enhancement）

> 模板：`skills/sdd/templates/design_template.md`
> 版本 v1.0 ｜ 日期 2026-10-19 ｜ 状态：草稿（待 gate-design 确认）
> 配套：`SPECS_INDEX.md`（唯一权威账本）、`research.md`（基线）、`spec.md`（跨子系统需求）
> **范围声明**：本文件只设计**组合架构与集成口径**；各子系统内部模块设计见各自 `design.md`（铁律 15）。

---

## 文档信息

- **项目名称**：plugin-system-enhancement（插件系统增强迭代）
- **版本**：v1.0
- **创建日期**：2026-10-19
- **作者**：SDD 主工程（文档步由子 agent 执行）
- **状态**：草稿

---

## 1. 设计概述

### 1.1 设计目标

1. **可增量落地**：6 个增强点各自独立开关、独立回滚，任一失败不影响其它。
2. **默认安全**：能力缺省全拒、版本缺省放行（向后兼容）——两个"缺省"方向相反但都不失控。
3. **复用优先**：0 新建表；能力模型改造复用 `src/security/`；拓扑复用 cordis `topoSort`；自愈复用 `healCrashed`。
4. **存量零回归**：既有 4 个 sync 插件 + 51 个 skill 插件加载行为不变。

### 1.2 设计原则

| 原则 | 口径 |
|---|---|
| 契约先行 | 先冻结 IF-01~IF-12，再动实现；改契约先于改实现（铁律 15） |
| 复用优先 | 能改造复用就不新建；确需新建须写明复用不成立理由（铁律 9） |
| 底座优先 | 规范源 `uctoo-dev-manual` + `docs/uctoo-v4/*.md`；脚手架走 `loaddbinfo` → `plugingen`/`crudgen` → `crudweb`（铁律 14） |
| 边界不越 | 子系统只改自己边界内的文件；跨界一律走契约接口 |
| 证据驱动 | 所有结论带 `文件:行号`；查不到标"待核实"，禁止编造 API |
| 不编译 | AI 不运行 `cjpm build`；编译由人工在独立 cmd 完成并回传 |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 编程语言 | Cangjie（仓颉） | 与宿主一致；代码编写须用 `cangjie-coder` 技能 |
| 插件隔离 | 既有三轨 `sync / dylib / process` | 本次不改三轨模型；`dylib` 轨本次不复活（R-01） |
| L3 宿主 | cordis-cj（`libs/cordis-cj/`） | 复用其期望态 reconcile、`topoSort`、`healCrashed` |
| 权限模型 | `src/security/permission_service.cj` + `sandbox_executor.cj` | **改造复用**（现状零引用死代码，R-02） |
| 持久化 | PostgreSQL，复用 `agent_skills` 既有列 | 0 新表 0 新列（默认） |
| 脚手架 | `loaddbinfo` → `plugingen` / `crudgen` → `crudweb` | 生成物当骨架做最小适配 |

---

## 2. 系统架构

### 2.1 架构图

```
                         ┌─────────────────────────────────────┐
                         │        宿主 PluginHostManager        │
                         │  loadAll / reconcile（既有，不改模型）│
                         └───────────────┬─────────────────────┘
                                         │ 在既有链路上插入校验点
     ┌───────────────────────────────────┼───────────────────────────────────┐
     │                                   │                                   │
┌────▼──────────┐              ┌─────────▼─────────┐            ┌───────────▼──────────┐
│ version-guard │  IF-01~04    │ capability-        │  IF-05~07  │ dependency-graph      │ IF-10
│ 版本协商准入  │─────────────►│ governance         │◄───────────│ 依赖拓扑 / 逆序停机   │
│ (最上游)      │              │ 能力清单 + 门禁    │            │ (独立，可并行)        │
└───────────────┘              └─────────┬─────────┘            └───────────────────────┘
                                         │ IF-05/07
                       ┌─────────────────┼──────────────────┐
              ┌────────▼────────┐   ┌────▼────────────────▼──────┐
              │ capability-     │   │ authoring-toolchain          │
              │ handshake       │   │ plugingen 测试 + validate    │
              │ IF-08/09 (P0)   │   │ IF-12                        │
              └────────┬────────┘   └──────────────────────────────┘
                       │
              ┌────────▼─────────────────────────┐
              │ lifecycle-observability  IF-11   │
              │ 退避 / 计数 / 熔断 / crash-reason │
              │ (独立，可并行)                    │
              └──────────────────────────────────┘
```

### 2.2 模块划分（子系统级）

| 子系统 | 落点文件（主要） | 改动性质 |
|---|---|---|
| version-guard | `libs/plugin-spi/src/plugin_types.cj:56-63`（错误码）、`plugin_config.cj:72-112`（字段）、`plugin_host_manager.cj:114-160`（插入校验）、`message.cj:10-53`（IF-04） | 新增 + 插入 |
| capability-governance | `src/security/*`（改造复用）、`cordis_host_services.cj:70-81`（门禁接线）、`plugin_manager.cj:98-100`（env 白名单） | **改造为主** |
| capability-handshake | `message.cj`（IF-08）、`plugin_host.cj:104-135`（握手校验）、`cordis_host_manager.cj:143-155`（失败插件不注册路由） | 新增 + 插入 |
| dependency-graph | `plugin_config.cj:338-350`（排序）、`plugin_loader.cj:122-130`（拓扑）、`cordis_host_manager.cj:263-274`（provide/inject）、`:418-438`（逆序停机） | 改造 |
| lifecycle-observability | `plugin_host.cj:920-980`（退避/计数/熔断）、`plugin_instance.cj:18-31`（字段）、`cordis_host_manager.cj:395-414`（检视） | 新增 + 改造 |
| authoring-toolchain | `src/plugin/tools/plugingen/*`（模板 + `--validate`） | 新增 |

### 2.3 组件交互

**加载主干（增强后）**：

```
discover(既有) → sortByOrder/拓扑(dependency-graph)
   → 版本校验(version-guard) ──失败──► 拒绝 + registry.restore 回滚
   → 能力预检(capability-governance/capability-handshake 静态部分)
   → 分轨加载
        ├─ sync/dylib：反射实例化（既有）
        └─ process：toCordisEntry(补 provide/inject) → addDesired
                       → 协议版本校验(IF-04) → 能力宣告握手(IF-08/09)
                       ──失败──► 不 addDesired / 安全终止 + 不注册 HTTP 路由
   → Active → 能力门禁常驻(CapabilityGate)
   → 运行期：崩溃 → healCrashed + 退避/计数/熔断(lifecycle-observability) → 事件 → 状态回写
```

---

## 3. 详细设计（组合层）

### 3.1 契约冻结与串行约定

- IF-01~IF-12 已在 `SPECS_INDEX.md` §3 冻结为草案；任何变更走 §6 变更影响面登记。
- **共享文件串行表**（避免合并冲突）：

| 文件 | 改动方 | 顺序 |
|---|---|---|
| `libs/cordis-cj/cordis_core/src/message.cj`（`InitializeParams`） | version-guard（IF-04）→ capability-handshake（IF-08） | **严格串行** |
| `src/plugin/plugin_config.cj`（`PluginManifestEntry`） | version-guard → capability-governance → dependency-graph | 按拓扑序 |
| `src/plugin/cordis_host_manager.cj` | dependency-graph（`toCordisEntry`/`shutdownAll`）与 capability-handshake（路由注册 `:143-155`）字段不同 | 可并行，但需 CR 复核 |

### 3.2 加载准入的组合语义

| 检查 | 缺省行为 | 失败后果 | 归属 |
|---|---|---|---|
| 版本协商 | **放行**（存量无声明） | 拒绝加载 + 回滚注册表 | version-guard |
| 能力预检 | **放行**（存量无声明） | 拒绝挂载（L3 未拉起） | capability-handshake（预检） |
| 能力宣告比对 | 上报 ⊆ 声明 | 拒绝挂载 + 安全终止 | capability-handshake |
| 运行期能力门禁 | **拒绝**（缺省全拒） | 单次调用 DENY + 审计 | capability-governance |
| 依赖环检测 | — | 明确错误，拒绝该批次 | dependency-graph |
| 重启熔断 | N=5（可配） | 停止重拉，置 Error | lifecycle-observability |

> 两个"缺省"方向相反是**有意为之**：加载准入缺省放行是为了存量零回归（REQ-DFX-C2）；运行期门禁缺省全拒是为了第三方二进制安全（REQ-DFX-S1）。

### 3.3 复用 `src/security/` 的改造要点（关键设计决策）

- 现状：`permission_service.cj` + `sandbox_executor.cj` 完整实现但 `grep "import magic.security" src/` → 0 命中。
- 决策：**改造复用**（R-02）。
- 复用前**必须**先修：`permission_service.cj:295-322` 对未知 capability type 走 **fail-open** → 改为 **fail-closed**（REQ-DFX-S2，P0）。
- 复用方式：能力枚举映射到既有 `Capability` 模型；DENY 审计复用既有 `_auditLog`（`:171/184/203/224/239/257/271/285`）；`SandboxExecutor`（`sandbox_executor.cj:72`）作为 process 轨的可选加固层。

### 3.4 观测与状态回写

- 全部复用既有通道：事件经 `plugin_event_bus.cj:121-152`；状态经 `PluginSyncBridge`（`plugin_sync_bridge.cj:38-90`）回写 `agent_skills.runtime_status` / `last_error`。
- 观测增量（重启次数、最后崩溃时间）默认收纳进既有列与 JSON 承载字段；**新增列须先论证复用不成立**（R-06）。

---

## 4. 数据设计

### 4.1 数据模型

- **插件清单**：`plugin.yaml`（文件态，权威声明源）→ `PluginManifestEntry`（`plugin_config.cj:72-112`，扩展字段）。
- **握手载荷**：`InitializeParams`（`message.cj:10-53`，扩展 2 字段）。
- **运行时状态**：`agent_skills`（既有表，复用列）。

### 4.2 数据表设计

**本次 0 新建表、0 新建列（默认口径）**。若 `lifecycle-observability` 论证确需新列，须：
1. 在各自 `design.md` 写明"复用不成立"理由；
2. 走 `loaddbinfo`（灌 `db_info`）→ `crudgen`（宿主）/`plugingen`（插件）→ `crudweb`（界面）；
3. 补 `sql/incremental/` 增量 DDL（幂等、禁 DROP）；
4. 新增宿主路由必补 `permissions` + `role_has_permission`（否则 403）。

### 4.3 数据关系

```
plugin.yaml (声明)  ──比对──►  InitializeParams (上报)
        │                              │
        └──► PluginManifestEntry ──► 加载准入判定 ──► PluginRegistry (注册/回滚)
                                                          │
                                                   PluginSyncBridge
                                                          ▼
                                                   agent_skills (状态)
```

---

## 5. API / 接口设计

### 5.1 跨子系统接口（契约汇总，详见 SPECS_INDEX §3）

| 编号 | 接口 | 提供方 → 消费方 |
|---|---|---|
| IF-01 | 宿主插件 API 版本常量 | version-guard → 全部 |
| IF-02 | 清单版本字段解析 | version-guard → capability-governance, authoring-toolchain |
| IF-03 | 加载前版本校验 | version-guard → PluginHostManager |
| IF-04 | L3 握手协议版本字段 | version-guard → capability-handshake |
| IF-05 | 能力枚举与缺省策略 | capability-governance → capability-handshake, authoring-toolchain |
| IF-06 | 能力门禁判定 | capability-governance → CordisHostServices |
| IF-07 | 跨进程能力禁列表 | capability-governance → capability-handshake, 静态审计 |
| IF-08 | 能力宣告载荷字段 | capability-handshake → 宿主状态监听 |
| IF-09 | 宣告比对与拒绝 | capability-handshake → CordisHostManager |
| IF-10 | 依赖声明解析与拓扑 | dependency-graph → 宿主加载器 |
| IF-11 | 重启 / 崩溃事件 | lifecycle-observability → 观测端点、PluginSyncBridge |
| IF-12 | 清单静态校验 | authoring-toolchain → CLI / CI |

### 5.2 对外 HTTP 端点

**本次不新增宿主 HTTP 路由**（默认口径）。若确需新增：路径遵循 `/api/v1/uctoo/...`，列表键名为表名 + `s`，分页/筛选/排序按 `uctoo-v4-api-specification`，并补权限登记。

---

## 6. 安全设计

### 6.1 认证机制

沿用既有：V4 中间件链在宿主侧执行（CORS → DeserializeUser → RequirePermission → RowLevel → OperateLog）；`ExternalPluginRouteGateway`（`src/plugin/external_plugin_route_gateway.cj`）承担外挂路由。

### 6.2 权限控制（本次核心）

| 控制点 | 现状 | 本次目标 |
|---|---|---|
| DB 表 | `tableWhitelist`（仅表名，`:476-482` 三种操作一律放行） | 升级为能力子项，补列级/操作级可选约束 |
| 网络出口 | `host.mcp` 无白名单（`:1155-1186`） | MCP alias + tool 白名单 |
| 文件访问 | 无 `host.fs`，无路径约束 | 纳入能力清单 |
| 子进程 | 无门禁（`lrt_composition_runner.cj:13` 直接 newProcess） | 纳入能力清单 |
| 环境变量 | **全量继承宿主**（`plugin_manager.cj:98-100`） | 白名单注入（REQ-EN-012） |
| secret | `env:NAME` 任意取值返明文（`:116-128`） | per-plugin 授权清单（REQ-EN-013） |
| 行级权限 | 宿主侧强制附加已存在（`:470-473`） | 保持并复用 |

### 6.3 数据安全

- DENY 判定**必须**落审计（REQ-DFX-S5）。
- 跨进程能力禁列表（IF-07）**单一来源**，预检与静态审计复用同一张表（REQ-EN-014），防止"审计说安全 / 实际能加载"漂移。

---

## 7. 性能设计

### 7.1 性能目标

见 `spec.md` §4.1（REQ-DFX-P1~P3）：单插件准入校验 ≤ 10 ms；握手往返 ≤ 1 s；100 插件拓扑 ≤ 50 ms。

### 7.2 优化策略

- 准入门槛全部为**内存比对**，禁止在加载路径做阻塞 IO。
- 能力门禁结果可缓存（插件级），失效点为清单变更与 reconcile。
- 拓扑排序只在清单集合变化时重算，不在每轮 reconcile 重算。

---

## 8. 部署设计

### 8.1 部署架构

无新增部署单元。全部增强落在宿主进程内（sync/process 轨）与插件脚手架（CLI）。

### 8.2 环境配置

| 配置项 | 缺省 | 说明 |
|---|---|---|
| `PLUGIN_RECONCILE_INTERVAL_SECONDS` | 60（`main.cj:929`） | 既有，保持 |
| `CORDIS_SKIP_PROCESS_PLUGINS` | 未设（`cordis_host_manager.cj:149-167`） | 既有应急开关，保持 |
| 重启熔断阈值 | 5（新增，可配） | lifecycle-observability |
| 能力缺省策略 | 全拒（新增） | capability-governance |

---

## 9. 风险与对策（组合层）

| 风险 | 对策 |
|---|---|
| R-01 `dylib` 轨不存在，P0 建议一半无落点 | 本次只做 process/sync；预留接口；建议单独立项 |
| R-02 `src/security/` 零引用、未测过 | 复用前先修 fail-open（P0）并补单测 |
| R-03 宿主环境变量全量泄漏 | 并入 capability-governance，白名单注入 |
| R-04 存量回归 | 缺省放行 + 端到端硬锚点（§5.1 用例 5） |
| R-05 `InitializeParams` 两方同改 | 严格串行：先 IF-04 后 IF-08 |
| R-06 观测字段倾向新建列 | 默认复用 `agent_skills` 既有列与 JSON 字段 |
| R-07 `autoRestart` 未消费 | lifecycle-observability 必须真正消费 |
| R-08 `inspectProcessPlugin` 文档与实现不符 | 实现对齐 docstring |

---

## 10. 附录

### 10.1 参考文档

- `docs/ref/plugin-mechanism-comparison-wx.html` §9（需求源）
- `.codeartsdoer/specs/plugin-system/{spec,design}.md`（存量基线）
- `skills/sdd/SKILL.md`（铁律 9 / 12 / 14 / 15）
- `docs/uctoo-v4/*.md`、`skills/uctoo-dev-manual/`（规范源）
- 各子系统 `contract.md` / `spec.md` / `design.md` / `tasks.md`

### 10.2 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-19 | SDD 主工程 | 初始版本：组合架构、契约汇总、串行约定、风险对策 |
