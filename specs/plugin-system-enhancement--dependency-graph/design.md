# 技术设计文档：dependency-graph

## 文档信息
- **项目名称**: `plugin-system-enhancement--dependency-graph`
- **契约编号**: IF-10（IF-10.1～IF-10.4，不新增全局接口编号）
- **版本**: 1.0
- **创建日期**: 2026-10-19
- **作者**: SDD 文档步
- **状态**: 草稿
- **关联需求**: `specs/plugin-system-enhancement--dependency-graph/spec.md`
- **权威边界**: `specs/plugin-system-enhancement--dependency-graph/contract.md:9-19,23-37`

## 1. 设计概述

### 1.1 设计目标

1. 在 sync/dylib 生命周期开始前解析 `@PluginAnnotation.dependencies`，生成稳定正向/逆向拓扑计划，替代“按 `order` 先加载、再检查依赖是否已注册”的事后断言（`src/plugin/plugin_loader.cj:56-73,119-149`；`src/plugin/plugin_host_manager.cj:114-160,301-381`）。
2. 在 process 清单中补齐 `provide/inject` 严格解析与 `toCordisEntry` 映射，使 cordis 已有 `topoSort` 真正消费宿主元数据，不在宿主另写第二套 process 排序（`src/plugin/cordis_host_manager.cj:253-274`；`libs/cordis-cj/cordis_core/src/config.cj:16-37`；`libs/cordis-cj/cordis_host/src/plugin_host.cj:829-840,980-1031`）。
3. 对 sync 与 process 的自环/多节点环在启动前返回 `PluginError.DependencyCycle` 和确定性闭合路径；当前 cordis 在环上按原序追加，必须消除该静默降级（`libs/cordis-cj/cordis_host/src/plugin_host.cj:1025-1028`；`specs/plugin-system-enhancement--dependency-graph/contract.md:25-30,90-94`）。
4. 批量卸载与宿主停机复用成功激活的同一计划反序，做到依赖方先清理、被依赖方后清理；当前 sync 只有单插件停用，process `shutdownAll` 只是顺序遍历（`src/plugin/plugin_host_manager.cj:414-454`；`src/plugin/cordis_host_manager.cj:416-438`）。
5. 无依赖图逐项保持现有 `sortByOrder()` 结果，锁定 4 个 sync 锚点与 51 个 skill 插件零回归（`src/plugin/plugin_config.cj:337-350`；`src/plugins/generated_anchors.cj:1-16`；`specs/plugin-system-enhancement/SPECS_INDEX.md:127-155`）。

### 1.2 设计原则

- **契约先行**：实现只覆盖 IF-10.1～IF-10.4；语义变化先改 `contract.md` 和主工程权威账本（`specs/plugin-system-enhancement--dependency-graph/contract.md:7-19,74-84`）。
- **依赖优先、order 同层稳定**：边约束高于数值优先级；就绪集合按 `(order, declarationIndex)` 选择（`specs/plugin-system-enhancement--dependency-graph/contract.md:32-37`）。
- **复用优先**：sync 借鉴已有 Kahn/环检测范式；process 原位演进 cordis `topoSort`，禁止平行实现（`src/skill/composition_executor.cj:286-345`；`src/skill/lrt_composition_runner.cj:359-423`；`libs/cordis-cj/cordis_host/src/plugin_host.cj:980-1031`）。
- **计划一次、正反复用**：`reverseOrder` 严格由成功激活的 `forwardOrder` 反转，不重新遍历另一张可能漂移的图（`specs/plugin-system-enhancement--dependency-graph/contract.md:27-30,39-50`）。
- **非法图启动前原子拒绝**：缺失或成环时不执行本批生命周期钩子，不产生部分计划（`specs/plugin-system-enhancement--dependency-graph/contract.md:90-100`）。
- **最小改动与边界隔离**：`cordis_host_manager.cj` 只增加 `provide/inject` 映射与计划消费；capabilities、协议版本、握手拒绝逻辑由 `capability-handshake` 维护（`specs/plugin-system-enhancement--dependency-graph/contract.md:52-60,62-72`）。
- **底座优先但零持久化**：先遵循 `uctoo-dev-manual` 与 `docs/uctoo-v4`；因本子系统 0 表/0 路由，不运行代码生成链，不创建增量 SQL 或权限数据（`skills/uctoo-dev-manual/SKILL.md:14-38,219-237`；`specs/plugin-system-enhancement--dependency-graph/contract.md:39-50`）。

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 编程语言 | 仓颉（Cangjie） | 宿主技术栈为仓颉；实现阶段必须加载 `cangjie-coder`，AI 不运行 `cjpm build`（`docs/uctoo-v4/uctoo-v4-architecture.md:163-174`；`skills/sdd/templates/tasks-template.md:1-5,38-41`） |
| sync 拓扑 | 稳定 Kahn 入度算法 + 剩余子图确定性环路径提取 | 复用 `CompositionExecutor` / `LrtCompositionRunner` 的入度表、邻接表和结果计数范式（`src/skill/composition_executor.cj:286-345`；`src/skill/lrt_composition_runner.cj:359-423`） |
| process 拓扑 | cordis `PluginHost.topoSort` 原位演进 | 现有 `computeToAdd` 已调用它；只补严格错误、稳定输入序和结果复用（`libs/cordis-cj/cordis_host/src/plugin_host.cj:829-840,980-1031`） |
| 元数据来源 | sync/dylib：反射读取 `PluginAnnotation`；process：yaml4cj 解析 `plugin.yaml` | 两轨保持现有权威来源，不引入第三种依赖 DSL（`libs/plugin-spi/src/plugin_annotation.cj:25-49`；`src/plugin/plugin_config.cj:116-267`） |
| 进程依赖模型 | cordis 服务 Key `provide/inject` | `PluginEntry` 已原生定义并序列化这两个字段（`libs/cordis-cj/cordis_core/src/config.cj:16-47`） |
| 数据库 | 不适用 | IF-10 为纯进程内编排，0 新表、0 新列（`specs/plugin-system-enhancement--dependency-graph/contract.md:39-50`） |

## 2. 系统架构

### 2.1 架构图

```text
                     ┌────────────────────────────┐
 plugin.yaml ───────▶│ PluginManifestEntry parser│
 (order/provide/     │ strict provide/inject     │
  inject)             └────────────┬───────────────┘
                                   │ PluginList（保留声明序）
 @PluginAnnotation ────────────────┤
 (dependencies)                    ▼
                     ┌────────────────────────────┐
                     │ IF-10 Dependency Planning  │
                     │                            │
                     │ sync: DependencyResolver  │
                     │   - missing validation    │
                     │   - stable topo/cycle     │
                     │   - DependencyPlan        │
                     │                            │
                     │ process: cordis topoSort  │
                     │   - same existing impl    │
                     │   - cycle as error        │
                     └──────────┬─────────┬───────┘
                                │         │
                forward/reverse │         │ mapped provide/inject
                                ▼         ▼
                     ┌──────────────┐  ┌──────────────────┐
                     │PluginHostMgr │  │CordisHostManager │
                     │sync/dylib    │  │process           │
                     └──────┬───────┘  └─────────┬────────┘
                            │                    │
                     PluginRegistry       cordis PluginHost
                            │                    │
                 listAll follows plan      launch / remove
```

现有发现与集中解析都先调用 `sortByOrder()`，宿主再逐项分轨；process 最终进入 `CordisHostManager.loadProcessPlugins`（`src/plugin/plugin_discovery_service.cj:66-81`；`src/plugin/plugin_config_parser.cj:45-60`；`src/plugin/plugin_host_manager.cj:114-160`）。目标架构在生命周期前增加计划阶段，但保留原分轨执行器。

### 2.2 模块划分

| 模块 | 状态 | 职责 | 主要落点 | 边界证据 |
|---|---|---|---|---|
| 依赖元数据解析 | 演进既有 | strict 解析 process `provide/inject`；统一 sync 依赖字符串拆分 | `src/plugin/plugin_config.cj`、`src/plugin/plugin_loader.cj` | 当前字段范围和拆分规则见 `src/plugin/plugin_config.cj:72-112,122-208,279-295`、`src/plugin/plugin_loader.cj:132-149` |
| `DependencyResolver` | 新增设计类型 | IF-10.1：sync/dylib 预读取注解，校验缺失，生成稳定 `DependencyPlan` | `src/plugin/` 下具体文件名待代码步按现有命名约定确定 | 契约已冻结名称和返回形态（`specs/plugin-system-enhancement--dependency-graph/contract.md:25-30`） |
| `DependencyPlan` | 新增设计对象 | 保存成功激活的正序、反序、声明序索引 | plugin-spi 或宿主包归属在代码步根据依赖方向确定，禁止造成反向 import | 数据契约见 `specs/plugin-system-enhancement--dependency-graph/contract.md:39-50,52-60` |
| sync 消费适配 | 演进既有 | `loadAll/reconcile` 在 `loadSingle` 前消费计划；批量停机消费反序 | `src/plugin/plugin_host_manager.cj` | 当前逐项分轨和单插件停用见 `src/plugin/plugin_host_manager.cj:114-160,186-255,414-454` |
| process 映射适配 | 演进既有 | 把 `provide/inject` 映射到 cordis 条目，保存同一拓扑计划用于停机 | `src/plugin/cordis_host_manager.cj` | 当前 `toCordisEntry` 未映射、停机顺序错误（`src/plugin/cordis_host_manager.cj:253-274,416-438`） |
| cordis 拓扑内核 | 原位演进 | 复用 `topoSort`，增加稳定顺序、闭合环错误和计划返回 | `libs/cordis-cj/cordis_host/src/plugin_host.cj` | 当前算法与环回退见 `libs/cordis-cj/cordis_host/src/plugin_host.cj:980-1031` |
| 回归测试 | 扩展既有 | DG-CT-01～06、L1/L2/L3 防回退 | `src/plugin/integration/plugin_system_check.cj`、`src/plugin/integration/cordis_l3_check.cj`、cordis tests | 既有入口见 `src/plugin/integration/plugin_system_check.cj:21-86`、`src/plugin/integration/cordis_l3_check.cj:126-197` |

### 2.3 组件交互

#### 2.3.1 启动期

1. `PluginDiscoveryService` 或 `PluginConfigParser` 产生按旧 `order` 规则稳定预排序的 `PluginList`；这一步是无依赖黄金序的输入基线（`src/plugin/plugin_discovery_service.cj:79-81`；`src/plugin/plugin_config_parser.cj:58-60`）。
2. `PluginHostManager` 取已启用条目并按轨分组。sync/dylib 组交给 IF-10.1；process 组交给 IF-10.2/IF-10.3。禁用条目保持原 skip 语义（`src/plugin/plugin_host_manager.cj:126-153`）。
3. sync 解析器反射读取注解，建立插件名依赖图；process 解析器只读取清单服务 Key，不读取 `PluginAnnotation`（`libs/plugin-spi/src/plugin_annotation.cj:25-49`；`specs/plugin-system-enhancement--dependency-graph/contract.md:44-50`）。
4. 任一轨发现环时，在对应轨生命周期开始前返回错误；sync 不调用 `loadSingle`，process 不写入 cordis desired、不拉起进程（`specs/plugin-system-enhancement--dependency-graph/contract.md:90-94`）。
5. 合法计划分别由既有 sync 生命周期和 cordis process 生命周期执行，不改变插件业务钩子（`src/plugin/plugin_host_manager.cj:301-381`；`libs/cordis-cj/cordis_host/src/plugin_host.cj:787-815`）。

#### 2.3.2 增量调谐

`PluginHostManager.reconcile` 当前只把尚未加载的新条目放入 `freshList`（`src/plugin/plugin_host_manager.cj:186-255`）。目标设计要求：

- sync/dylib resolver 将 `PluginRegistry.listAll()` 中现有插件名作为“已满足集合”，但只对 `freshList` 生成输出，避免把已激活插件重复加载；注册表可稳定返回现有实例（`src/plugin/plugin_registry.cj:79-112`）。
- 新插件依赖另一个同批新插件时，二者进入同一图；新插件依赖既有插件时，该边视为已满足；依赖既不在同批也不在注册表时返回 `DependencyMissing`。
- process 继续由 cordis desired/actual 差集调谐；`computeToAdd` 已只选择 actual 中不存在的条目（`libs/cordis-cj/cordis_host/src/plugin_host.cj:829-840`）。
- 本设计不实现“配置变更热更新”或目录删除自动卸载，保持现有明确边界（`src/plugin/plugin_host_manager.cj:162-184`）。

#### 2.3.3 批量停机

- sync/dylib：只对实际成功激活且仍注册的插件按 `DependencyPlan.reverseOrder` 调用既有单插件清理；`deactivate(name)` 的钩子异常继续语义保持（`src/plugin/plugin_host_manager.cj:414-454`）。
- process：`CordisHostManager` 保存 cordis 返回的实际正向计划 ID；`shutdownAll` 反向遍历并调用既有 `removePlugin`，每项 try/catch 后继续（`src/plugin/cordis_host_manager.cj:418-438`；`libs/cordis-cj/cordis_host/src/plugin_host.cj:864-889`）。
- 单插件显式 `deactivate(name)` / `deactivateProcessPlugin(name)` 不做隐式级联，本需求只保证批量卸载/宿主停机的逆序；现有单插件入口见 `src/plugin/plugin_host_manager.cj:419-454`、`src/plugin/cordis_host_manager.cj:375-388`。

## 3. 详细设计

### 3.1 依赖元数据解析设计

#### 3.1.1 类设计

| 类型/函数 | 现状 | 目标设计 | 契约 |
|---|---|---|---|
| `PluginManifestEntry` | 有 `name/mode/enabled/order/.../httpRoutes`，无 `provide/inject` | 新增两个缺省空的 `ArrayList<String>` 字段；仅 process 编排消费 | IF-10.2（`contract.md:27-29,44-50`） |
| `PluginManifestEntry.fromJsonValue` | 返回 `Option`；通用数组解析对类型错误静默/转字符串 | 目标返回通道必须能携带 `PluginError.ConfigInvalid`；`provide/inject` 使用严格字符串数组解析 | IF-10.2（`contract.md:27-29`） |
| `PluginAnnotation.dependencies` | 逗号分隔 String | 保持不变 | IF-10.1（`libs/plugin-spi/src/plugin_annotation.cj:25-49`） |
| `splitDependencies` | `PluginLoader` 私有函数 | 提升为同包唯一实现，由 loader 和 resolver 共同调用，语义不复制 | IF-10.1 稳定解析（`src/plugin/plugin_loader.cj:132-149`） |
| `PluginError.DependencyCycle` | 不存在；现有枚举有 `DependencyMissing/ConfigInvalid` 等 | 新增携带诊断字符串的枚举分支，`message()` 输出统一前缀和闭合路径 | IF-10.1 / IF-10.3（`libs/plugin-spi/src/plugin_types.cj:53-84`；`contract.md:27-30`） |

`PluginManifestEntry.fromJsonValue` 当前返回 `Option`，无法满足 IF-10.2 的明确 `ConfigInvalid`。因此目标态把该解析入口演进为可携带 `PluginError` 的 `Result` 形态，并同步更新其既有调用者；当前调用面为 `PluginConfigParser.parse` 和 `fromPluginYaml`，后者再被 `PluginDiscoveryService` 消费（`src/plugin/plugin_config_parser.cj:45-52`；`src/plugin/plugin_config.cj:216-267`；`src/plugin/plugin_discovery_service.cj:64-75`）。这是 IF-10.2 的内部签名演进，不新增全局接口编号。

#### 3.1.2 接口设计

**IF-10.2 严格数组规则**：

1. 字段缺失：返回空数组。
2. 字段存在且为数组：逐项验证必须是 `JsonString`，保持 YAML 顺序和原值。
3. 字段存在但非数组：返回 `PluginError.ConfigInvalid("<name>.provide/inject must be string array")` 的等价信息。
4. 数组中有非字符串：返回 `ConfigInvalid`，消息含字段名与元素索引。
5. 不复用现有宽松 `parseStringArray` 处理 IF-10 字段；该函数会忽略非数组并把非字符串 `toString`，不符合契约（`src/plugin/plugin_config.cj:279-295`）。
6. `args/tableWhitelist` 的既有宽松行为不在本子系统范围内，不顺手收紧。

**sync 依赖字符串规则**：

1. 空串 → `[]`。
2. 逗号分隔后 `trimAscii()`。
3. 过滤空项；保持第一次出现顺序。
4. 重复依赖可在建图时去重，避免重复增加入度；去重不得改变首次声明顺序。
5. 自依赖不作为缺失处理，进入环检测并报告 `A -> A`。

前 3 条直接复用现有 `splitDependencies` 语义（`src/plugin/plugin_loader.cj:132-149`）；第 4～5 条是 IF-10 图构造的确定性约束（`specs/plugin-system-enhancement--dependency-graph/contract.md:25-37,90-94`）。

#### 3.1.3 数据流

```text
sync/dylib entry.className
  → ClassTypeInfo.get
  → findAnnotation<PluginAnnotation>
  → 校验 annotation.name == entry.name
  → shared splitDependencies
  → normalized dependency names

process plugin.yaml
  → yaml4cj decode
  → PluginManifestEntry.fromJsonValue（Result 目标态）
  → strict provide/inject arrays
  → toCordisEntry
  → PluginEntry.provide/inject
```

反射读取、注解缺失和名称不一致继续分别沿用 `InstantiationFailed` / `AnnotationInvalid`，不得改报 `DependencyMissing`（`src/plugin/plugin_loader.cj:46-67`；`libs/plugin-spi/src/plugin_types.cj:56-81`）。

### 3.2 sync/dylib DependencyResolver 设计

#### 3.2.1 类设计

**目标设计对象（契约已声明、当前尚未实现）**：

| 对象 | 字段/依赖 | 说明 |
|---|---|---|
| `DependencyResolver` | 只读 `PluginRegistry` 或等价已注册名快照 | 对外保持 `resolve(entries)`；增量场景通过构造依赖读取已满足集合，不改变 IF-10.1 请求形态（`specs/plugin-system-enhancement--dependency-graph/contract.md:25-30`） |
| `DependencyPlan` | `forwardOrder`、`reverseOrder`、`declarationIndex` | 对外只读；内部邻接表和入度表不泄漏（`specs/plugin-system-enhancement--dependency-graph/contract.md:39-50`） |
| 内部 Node | `entry/name/order/index/dependencies` | 一次注解读取后缓存，避免同批重复反射 |

类型具体归属遵循单向依赖：若放入 `plugin-spi` 会迫使其引用宿主 `PluginManifestEntry`，则改放宿主 `magic.plugin` 包，禁止为共享类型制造反向 import；主工程要求子系统依赖方向单向无环（`specs/plugin-system-enhancement/SPECS_INDEX.md:66-85,89-105`）。

#### 3.2.2 接口设计

IF-10.1 目标接口保持契约：

```text
DependencyResolver.resolve(entries)
  → Result<DependencyPlan, PluginError>
```

- 输入只含已启用的 sync/dylib 候选条目。
- 输出 `forwardOrder` 用于 `loadSingle`，`reverseOrder` 用于批量停机。
- `DependencyMissing`：依赖名既不在候选节点，也不在已注册名集合。
- `DependencyCycle`：输出闭合路径。
- 同一输入与同一已注册集合幂等（`specs/plugin-system-enhancement--dependency-graph/contract.md:25-37`）。

#### 3.2.3 数据流与算法

**阶段 A：节点收集**

1. 顺序遍历候选条目，记录 `declarationIndex`。
2. 每个唯一 `className` 只反射一次；读取 `PluginAnnotation` 并校验名称。
3. 用共享拆分函数得到依赖名，按首次出现去重。
4. 建立 `name → Node` 索引；同名重复沿用既有注册/配置错误边界，不在本需求新增冲突策略。

**阶段 B：缺失校验与建图**

1. 对每个 `B dependsOn A`：
   - A 在候选索引：添加边 `A → B`，B 入度加一；
   - A 在已注册名集合：视为外部已满足，不加入本批入度；
   - 否则立即返回 `DependencyMissing("B:A")` 的等价明确信息。
2. 邻接列表按候选输入序保存，保证环路径与入度释放确定性。

**阶段 C：稳定 Kahn**

1. 把所有入度 0 节点放入 ready 集合。
2. ready 每次选择 `(order ASC, declarationIndex ASC)` 最小节点；实现可用 `ArrayList` 稳定插入/扫描，不假设仓颉存在未核实的优先队列 API。
3. 输出节点，递减其邻接节点入度；新就绪节点按相同键加入。
4. 输出数等于节点数时成功；`reverseOrder` 直接由成功输出反转。

该实现上界为 `O(V² + E)` 时间、`O(V + E)` 空间，满足 spec DG-NFR-001；现有可复用范式已证明仓颉 `HashMap + ArrayList` 足以完成入度算法（`src/skill/composition_executor.cj:286-345`；`src/skill/lrt_composition_runner.cj:359-423`）。

**阶段 D：确定性闭合环路径**

当 Kahn 输出数小于节点数：

1. 只在入度仍大于 0 的剩余子图中搜索。
2. 按 `(order, declarationIndex)` 选择首个起点，邻接遍历按声明序。
3. 维护当前路径与路径内位置；首次遇到当前路径中的节点时截取闭合段并在末尾追加起点。
4. 输出如 `A -> B -> C -> A`；自环输出 `A -> A`。
5. 不返回部分 `DependencyPlan`。

`LrtCompositionRunner` 当前只能返回空列表和“possible cycle”日志（`src/skill/lrt_composition_runner.cj:417-423`）；本设计借鉴其检测范式，但按 IF-10 增加明确闭合路径。

### 3.3 sync 宿主接入设计

#### 3.3.1 类设计

`PluginHostManager` 新增以下内部状态，具体字段名在代码步按仓颉命名规范确定，不新增跨子系统接口：

- 最近一次成功的 sync/dylib 激活 ID 正序；
- 对应逆序或可由正序即时反转的只读计划；
- 仅记录实际成功激活的 ID，失败/跳过条目不进入停机集合。

现有 `PluginRegistry.orderedNames` 按注册顺序增长，因此按 plan 调用 `loadSingle` 即可自然让 `listAll()` 和 `list(state)` 反映拓扑序，无需改注册表（`src/plugin/plugin_registry.cj:20-24,39-55,79-112`）。

#### 3.3.2 接口设计

- `loadAll`：发现后先筛选 enabled sync/dylib，调用 IF-10.1；Err 时本轨不进入 `loadSingle`，process 是否继续由产品错误隔离策略决定。契约 DG-CT-04 要求同一成环轨整体拒绝，不能部分激活（`specs/plugin-system-enhancement--dependency-graph/contract.md:90-94`）。
- `reconcile`：对 `freshList` 调用 resolver，并把已注册集合视为已满足；只加载 forwardOrder 中的新条目（`src/plugin/plugin_host_manager.cj:186-255`）。
- `loadSingle`：保留 `PluginLoader.checkDependencies` 作为防御性一致性断言，不再承担排序职责；其缺失错误仍可防止运行中注册表意外漂移（`src/plugin/plugin_loader.cj:68-73,119-130`）。
- 批量停机入口：新增宿主内部批量清理能力，逐项复用现有 `deactivate(name)`，不复制钩子/cleanup/注销逻辑（`src/plugin/plugin_host_manager.cj:414-454`）。

“loadAll 遇到某轨非法图时是否允许另一轨继续”在现有 IF-10 契约未明确；本设计的最小承诺是**非法图所属候选轨不部分启动**。跨轨整体事务语义标为待核实，不在实现中自行扩大为全宿主事务。

#### 3.3.3 数据流

```text
PluginList（旧 order 黄金序）
  → enabled sync/dylib entries
  → DependencyResolver.resolve
    Err → 记录统一 PluginError，本轨 0 个生命周期调用
    Ok  → for entry in forwardOrder: loadSingle(entry)
          成功 ID 追加 activePlan
  → 批量停机：reverse(activePlan) → deactivate(id)
```

### 3.4 process 轨复用设计

#### 3.4.1 类设计

| 类型 | 现状 | 目标 |
|---|---|---|
| `PluginManifestEntry` | 无 `provide/inject` | 新增缺省空数组并严格解析（`src/plugin/plugin_config.cj:72-112`） |
| `PluginEntry` | 已有 `inject/provide` | 不新增重复字段（`libs/cordis-cj/cordis_core/src/config.cj:16-37`） |
| `CordisHostManager` | `toCordisEntry` 只映射 id/source/args；`startedIds` 按 await 顺序记录 | 映射两个数组，保存 cordis 实际拓扑正序用于停机（`src/plugin/cordis_host_manager.cj:53-54,181-238,253-274`） |
| `HostState` | `desired` 仅为 HashMap，`addDesired` 不保存声明序 | 最小补充期望 ID 稳定序，使 `computeToAdd` 不依赖未承诺的 HashMap 迭代顺序（`libs/cordis-cj/cordis_host/src/host_state.cj:10-33`） |
| `PluginHost.topoSort` | private Unit；环按原序追加 | 原位改为可返回成功顺序或闭合环诊断的实现，仍是唯一 process 拓扑内核（`libs/cordis-cj/cordis_host/src/plugin_host.cj:980-1031`） |

`HostState.desired` 保留用于 O(1) 状态查询，只增加与其同步维护的稳定 ID 序列；`addDesired/removeDesired/reconcile(configPath)` 必须成对维护，避免把 HashMap 枚举顺序当成声明顺序。当前 `reconcile(configPath)` 会重建 desired HashMap（`libs/cordis-cj/cordis_host/src/plugin_host.cj:766-782`），因此也是稳定序重建点。

#### 3.4.2 接口设计

**IF-10.3 `toCordisEntry` 映射**：

| 宿主字段 | cordis 字段 | 规则 |
|---|---|---|
| `name` | `id` | 保持现有映射 |
| `command` | `source` | 保持现有路径解析 |
| `args` | `args` | 保持现有映射 |
| `inject` | `inject` | 新增原序复制 |
| `provide` | `provide` | 新增原序复制 |

映射范围严格止于 IF-10；`config/enabled` 是否补映射不属于本需求，capabilities 更不在本接口内（`src/plugin/cordis_host_manager.cj:253-274`；`specs/plugin-system-enhancement--dependency-graph/contract.md:27-30,58-60`）。

**cordis 拓扑结果传播**：

1. `topoSort` 不再用 Unit 隐藏环；目标返回形态必须能表达“排序后列表”或“闭合环字符串”。具体仓颉 `Result` 类型/import 在代码步由 `cangjie-coder` 对 cordis 包现有依赖核实，本文不虚构未验证类型别名。
2. `computeToAdd` 与 `reconcileDesired` 把该错误向 `CordisHostManager.loadProcessPlugins` 传播。
3. 宿主边界统一映射为 `PluginError.DependencyCycle`；cordis 库不反向依赖 `plugin-spi`，避免依赖环。
4. 调用者忽略成功返回值的既有测试可保持行为，但新增环测试必须断言错误；现有调用点包括宿主和 cordis e2e/uds 测试（`src/plugin/cordis_host_manager.cj:193-204`；`libs/cordis-cj/cordis_tests/src/e2e_test.cj:165-169`；`libs/cordis-cj/cordis_tests/src/uds_e2e_test.cj:202-206`）。

#### 3.4.3 数据流与算法

**稳定优先级输入**

- process 子序列来自已经按 `order` 稳定排序的 `PluginList`，所以其输入位置本身就是 `(order, declarationIndex)` 优先级（`src/plugin/plugin_config.cj:337-350`）。
- `HostState` 的稳定 desired ID 序列保留此顺序；`computeToAdd` 按该序列取仍未 actual 的条目，再交给唯一 `topoSort`。
- `topoSort` 内部使用输入位置作为就绪优先级，不需要给 cordis `PluginEntry` 增加宿主专有 `order` 字段，保持 cordis 数据模型最小化。

**依赖建图**

1. 建立 `serviceKey → provider plugin IDs`。
2. 对 consumer 的每个 inject：
   - 当前候选存在 provider：每个 provider 都形成 provider → consumer 约束；
   - 当前候选无 provider：沿用 cordis 既有“外部/已存在服务”语义，不判 `DependencyMissing`（`libs/cordis-cj/cordis_host/src/plugin_host.cj:1003-1011`）。
3. 使用稳定就绪集合输出 provider 在 consumer 前的序列。
4. 输出数不足时从剩余插件边提取闭合插件 ID 路径并返回错误，不再按原序追加。

**复用边界**

本设计只改造 `libs/cordis-cj/cordis_host/src/plugin_host.cj:980-1031` 的既有算法及其结果通道；`CordisHostManager` 只负责映射、调用和错误转换，不实现 serviceKey 邻接表。静态审查若在宿主发现第二份 process 入度/邻接算法即不通过。

### 3.5 逆序卸载与停机设计

#### 3.5.1 类设计

- `DependencyPlan.reverseOrder`：sync/dylib 成功计划的反序。
- sync 活跃计划：只包含 `loadSingle` 成功的条目，避免对加载失败项调用 `deactivate`。
- process 活跃计划：以 cordis 实际解析的正向拓扑 ID 序为基准，与 `startedIds`/actual 状态求交后反转；当前 `startedIds` 只按 await 循环追加，不能直接代表拓扑（`src/plugin/cordis_host_manager.cj:206-238`）。

#### 3.5.2 接口设计

**IF-10.4 批量清理规则**：

1. 输入为空：安全返回。
2. 从正向计划末尾到开头遍历。
3. 处理前检查插件仍存在；不存在则跳过，不报重复清理错误。
4. 每个 ID 通过 visited 集合或计划去重保证至多一次。
5. sync 每项调用现有 `deactivate`；process 每项调用现有 `removePlugin`。
6. 捕获单项异常并继续；最终可记录汇总，但不新增 HTTP 响应或外部事件。

现有 sync `deactivate` 已保证 `onDeactivate/onUnload` 异常不阻断后续 cleanup（`src/plugin/plugin_host_manager.cj:414-454`）；现有 process `shutdownAll` 已逐项 try/catch，只需把遍历序替换为计划逆序（`src/plugin/cordis_host_manager.cj:418-438`）。

#### 3.5.3 数据流

```text
forwardPlan: [A, B, C]
actual active: {A, B, C}
reverse once: [C, B, A]
  C cleanup/terminate (失败则记录)
  B cleanup/terminate (失败则记录)
  A cleanup/terminate
```

单插件 Agent 工具仍调用 `PluginHostManager.deactivate(name)`，不自动级联；当前调用点见 `src/plugin/plugin_agent_tools.cj:323-329`。工程级 `pluginuninstall` 静态资产/数据库痕迹清理不属于 IF-10（`skills/uctoo-dev-manual/SKILL.md:175-197`）。

### 3.6 错误设计

| 场景 | 错误 | 消息最小内容 | 生命周期效果 | 证据/契约 |
|---|---|---|---|---|
| sync 依赖名缺失 | `DependencyMissing` | 依赖方 + 缺失名 | 本批 sync/dylib 不启动 | `libs/plugin-spi/src/plugin_types.cj:56-81`；IF-10.1 |
| sync/process 成环 | `DependencyCycle`（新增） | 闭合插件路径 | 成环轨本批不启动 | `contract.md:27-30,90-94` |
| `provide/inject` 类型非法 | `ConfigInvalid` | 插件名 + 字段 + 元素索引（如适用） | 对应 process 条目不进入 desired | `contract.md:27-29` |
| 反射类不存在 | `InstantiationFailed` | className + 原因 | sync 计划失败 | `src/plugin/plugin_loader.cj:46-54` |
| 缺少/不匹配注解 | `AnnotationInvalid` | className/name 差异 | sync 计划失败 | `src/plugin/plugin_loader.cj:56-67` |
| 单项清理失败 | 既有生命周期错误/日志 | 插件 ID + 原因 | 继续清理其余项 | `src/plugin/plugin_host_manager.cj:424-452`；`src/plugin/cordis_host_manager.cj:425-437` |

环路径确定性顺序与输入稳定序一致，便于黄金测试。process cordis 内部错误在宿主边界转换为 `PluginError.DependencyCycle`，cordis 不 import plugin-spi。

## 4. 数据设计

### 4.1 数据模型

#### 4.1.1 `PluginManifestEntry` 增量字段

| 字段 | 逻辑类型 | 缺省 | 约束 | 持久化 |
|---|---|---|---|---|
| `provide` | `ArrayList<String>` | 空数组 | process 服务 Key，严格字符串数组、保持声明序 | 仅来自 YAML，进程内 |
| `inject` | `ArrayList<String>` | 空数组 | process 服务 Key，严格字符串数组、保持声明序 | 仅来自 YAML，进程内 |

现有 `PluginManifestEntry` 已是进程内清单对象，无数据库映射（`src/plugin/plugin_config.cj:72-114`）。

#### 4.1.2 `DependencyPlan`

| 字段 | 逻辑类型 | 约束 |
|---|---|---|
| `forwardOrder` | 插件条目只读序列 | 每个候选至多一次，所有依赖边方向满足前置 |
| `reverseOrder` | 插件条目只读序列 | 严格等于成功激活正序的反序 |
| `declarationIndex` | 名称到整数索引 | 从输入派生，不持久化，不对外修改 |

数据契约由 IF-10.1/IF-10.4 定义（`specs/plugin-system-enhancement--dependency-graph/contract.md:25-30,39-50`）。

#### 4.1.3 cordis 稳定 desired 顺序

`HostState.desired` 继续承担 ID → Entry 查询；新增并同步维护 ID 顺序序列，仅用于 `computeToAdd` 的确定性枚举。不得用 `HashMap.keys()` 迭代顺序代替声明序，因为现有数据结构只声明为 HashMap，未给出稳定顺序契约（`libs/cordis-cj/cordis_host/src/host_state.cj:10-33`）。

### 4.2 数据表设计

不新增或修改数据库表。IF-10 登记为 0 新表，且只处理进程内清单、注解与 cordis 条目（`specs/plugin-system-enhancement/SPECS_INDEX.md:49-58`；`specs/plugin-system-enhancement--dependency-graph/contract.md:39-50`）。

因此：

- 不创建 `sql/incremental/` 文件；
- 不运行 `loaddbinfo`；
- 不运行 `plugingen` / `crudgen` / `crudweb`；
- 不新增 `permissions` / `role_has_permission`；
- 不新增 creator/软删字段。

上述工具链只在表结构/路由扩展时适用（`skills/uctoo-dev-manual/SKILL.md:14-38,219-237`；`skills/uctoo-dev-manual/tools/loaddbinfo.md:29-51`）。

### 4.3 数据关系

```text
PluginManifestEntry(sync/dylib) ─className─▶ PluginAnnotation.dependencies
             │                                  │
             └──────────────▶ DependencyResolver ─▶ DependencyPlan

PluginManifestEntry(process).provide/inject
             │
             └─toCordisEntry─▶ PluginEntry.provide/inject
                                  │
                                  └─cordis topoSort─▶ process forward/reverse plan
```

两轨只在宿主总控层并列消费，不互相转换依赖键（`specs/plugin-system-enhancement--dependency-graph/contract.md:44-50,52-60`）。

## 5. API 设计

### 5.1 API 列表

本子系统不新增 HTTP API。IF-10 全部是进程内调用，主工程登记路径为 `DependencyResolver.resolve(entries)`（`specs/plugin-system-enhancement/SPECS_INDEX.md:66-83`）。

| 方法 | 路径 | 描述 |
|------|------|------|
| 不适用 | 不适用 | 0 个 HTTP 端点；不触发 V4 路由和权限登记 |

### 5.2 API 详细设计

#### 5.2.1 不适用说明

- 无请求方法、URL、HTTP 参数或响应体。
- 无认证/鉴权中间件变更。
- 无 `permissions` / `role_has_permission` 记录。
- 若后续要暴露诊断 HTTP API，属于新契约，必须先更新 `contract.md` 与 `SPECS_INDEX.md`，不能在 IF-10 实现中顺带加入（`specs/plugin-system-enhancement--dependency-graph/contract.md:74-84`）。

## 6. 接口设计

### 6.1 内部接口

| IF 子项 | 提供方 | 消费方 | 请求 | 响应/错误 | 设计状态 |
|---|---|---|---|---|---|
| IF-10.1 | `DependencyResolver` | `PluginHostManager` | 已启用 sync/dylib entries | `DependencyPlan` / `DependencyMissing` / `DependencyCycle` | 新增实现；契约已冻结 |
| IF-10.2 | `PluginManifestEntry.fromJsonValue` | 配置/发现路径 | YAML JsonValue | 严格 `provide/inject` 或 `ConfigInvalid` | 演进既有解析结果通道 |
| IF-10.3 | `CordisHostManager.toCordisEntry` + cordis topo | process 宿主 | manifest process entry | 完整 `PluginEntry` + 拓扑结果/环错误 | 映射补齐，拓扑原位演进 |
| IF-10.4 | `DependencyPlan.reverseOrder` / 批量停机 | sync/process 停机入口 | 成功激活正序 | 逆序清理；单项失败继续 | 新增计划消费 |

接口语义逐项对应 `specs/plugin-system-enhancement--dependency-graph/contract.md:23-37`，不得拆出 IF-13 等新全局编号。

### 6.2 外部接口

- 对其他 SDD 子系统无上游依赖；主工程 DAG 将 dependency-graph 定义为孤立可并行节点（`specs/plugin-system-enhancement/SPECS_INDEX.md:89-103`）。
- 与 `capability-handshake` 仅共享 `src/plugin/cordis_host_manager.cj:263-274` 附近：本子系统写 `provide/inject`，对方写 capability/握手字段。合并时按字段分区复核，不互相 import 私有类型（`specs/plugin-system-enhancement--dependency-graph/contract.md:58-60`）。
- cordis 是存量库依赖，不是另一个 SDD 子系统；process 排序由其现有 `topoSort` 提供（`libs/cordis-cj/cordis_host/src/plugin_host.cj:980-1031`）。
- `PluginRegistry` 是宿主存量组件；只消费其注册集合和顺序，不改变公开列表语义（`src/plugin/plugin_registry.cj:20-24,79-112`）。

## 7. 安全设计

### 7.1 认证机制

不适用。本子系统无外部网络入口、用户请求或认证令牌；仅消费宿主已发现的进程内清单对象（`specs/plugin-system-enhancement--dependency-graph/contract.md:39-50,62-72`）。

### 7.2 权限控制

- 不新增权限点或 RBAC 关系。V4 权限链为 `uctoo_user → user_has_roles → uctoo_role → role_has_permission → permissions`，本组件不读写该链（`docs/uctoo-v4/user-permission-system.md:22-39`）。
- 不修改 process `tableWhitelist`、host.db 门禁或 capability gate；这些分别是既有宿主服务/`capability-governance` 范围（`src/plugin/plugin_config.cj:106-108`；`specs/plugin-system-enhancement/SPECS_INDEX.md:74-77,153-154`）。

### 7.3 数据安全

- `provide/inject` 按纯字符串服务 Key 解析，不执行、不拼接命令、不写入环境变量。
- 严格类型失败即 `ConfigInvalid`，避免宽松 `toString` 把畸形清单伪装成有效服务名（`src/plugin/plugin_config.cj:279-295`）。
- 本设计不改变 `command` 路径解析、进程环境继承或 secret 代理；相关安全缺口归 `capability-governance`（`specs/plugin-system-enhancement/SPECS_INDEX.md:153-154`）。

## 8. 性能设计

### 8.1 性能目标

| 指标 | 目标 | 验证 |
|---|---|---|
| sync 排序时间 | 不劣于 `O(V² + E)` | 构造不同 V/E 的计数型单测，确认无无界循环 |
| sync 附加空间 | `O(V + E)` | 节点索引、邻接表、入度表、ready/路径集合 |
| 注解反射次数 | 每批每个唯一 className ≤ 1 | 测试探针/计数 |
| process 排序实现数 | 1 | 静态审查仅 cordis `topoSort` 持有 serviceKey 邻接逻辑 |
| 无依赖结果 | 与旧 `sortByOrder()` 逐项一致 | 黄金序对比 |

现有目标规模的硬回归集合为 51 个 skill 插件与 4 个 sync 锚点（`specs/plugin-system-enhancement/SPECS_INDEX.md:127-155`）。本设计不声明未经实测的毫秒 SLA；若需时延红线，标记为待基准测试后在契约 minor 中补充。

### 8.2 优化策略

1. 注解元数据同批缓存，避免 resolver 和 loader 重复解析依赖字符串；loader 只保留注册存在性防御断言。
2. 无依赖快速路径可直接复用输入（输入已是旧 `sortByOrder` 黄金序），但仍需完成必要的注解合法性/缺失校验；若优化会绕过校验则不采用。
3. `reverseOrder` 由 forward 一次反转，不重建图。
4. process desired 顺序单独保存，避免每次为稳定性重新排序 HashMap。
5. 不引入数据库/cache/消息队列。

## 9. 部署设计

### 9.1 部署架构

本子系统随宿主和 vendored cordis 源码一同编译，无独立服务、端口、容器或数据库迁移：

```text
agentskills-runtime
  ├─ src/plugin/*                    sync/process 宿主适配
  ├─ libs/plugin-spi/*               统一错误（如归属依赖允许）
  └─ libs/cordis-cj/cordis_host/*    既有 process topoSort 原位演进
```

三轨中 sync 属宿主编译图，process 插件为独立可执行进程并由 `CordisHostManager` 拉起；本设计不复活 dylib（`skills/uctoo-dev-manual/specs/plugin-system-design.md:21-29`；`specs/plugin-system-enhancement/SPECS_INDEX.md:150-153`）。

### 9.2 环境配置

- 不新增环境变量或配置文件。
- 旧 `plugin.yaml` 无 `provide/inject` 时自动按空数组处理（`specs/plugin-system-enhancement--dependency-graph/contract.md:74-84`）。
- 新 process 插件可声明 `provide/inject`；模板/生成器自动产出这些字段不在本子系统范围，移交 `authoring-toolchain`（`specs/plugin-system-enhancement/SPECS_INDEX.md:79-81`）。
- 无 `sql/incremental/`、DB 前置或 RBAC 发布步骤。
- AI 不执行 `cjpm build`；人工在独立环境执行编译、类型检查、lint、L1/L2/L3，并回传结果（`skills/sdd/templates/tasks-template.md:1-5,38-41`）。

## 10. 附录

### 10.1 参考文档

1. `specs/plugin-system-enhancement--dependency-graph/contract.md:1-110` —— IF-10 权威子系统契约。
2. `specs/plugin-system-enhancement/SPECS_INDEX.md:49-105,109-159` —— 主工程边界、DAG、L3 用例 4/5、R-04。
3. `specs/plugin-system-enhancement--dependency-graph/spec.md` —— 本设计对应需求与 EARS 验收。
4. `src/plugin/plugin_config.cj:72-112,122-208,279-295,337-350` —— 清单模型、解析和旧 order 排序。
5. `src/plugin/plugin_loader.cj:46-73,119-149` —— 注解读取、事后依赖检查、拆分规则。
6. `src/plugin/plugin_host_manager.cj:114-160,186-255,301-381,414-454` —— sync 加载/增量/单插件停用。
7. `src/plugin/cordis_host_manager.cj:127-239,253-274,375-438` —— process 编排、映射、停机。
8. `libs/cordis-cj/cordis_host/src/plugin_host.cj:766-840,980-1031` —— desired 调谐与既有 topoSort。
9. `libs/cordis-cj/cordis_host/src/host_state.cj:10-33` —— desired HashMap 与顺序缺口。
10. `src/skill/composition_executor.cj:286-345`、`src/skill/lrt_composition_runner.cj:359-423` —— 仓颉拓扑/环检测复用范式。
11. `skills/uctoo-dev-manual/SKILL.md:14-70,219-237`、`skills/uctoo-dev-manual/specs/plugin-system-design.md:21-123` —— 二次开发底座与插件三轨规范。
12. `.codeartsdoer/specs/plugin-system/design.md:888-894` —— “未声明时按 dependencies 拓扑”的既有设计承诺。

### 10.2 已实现功能/存量功能对比

| 能力 | 存量现状 | 本设计动作 | 是否复用 |
|---|---|---|---|
| `order` 排序 | 稳定冒泡升序 | 降为拓扑同层优先级；无依赖完全一致 | 复用黄金语义 |
| sync 依赖解析 | 私有逗号拆分 | 提升为唯一共享规则 | 复用 |
| sync 缺失检查 | 加载时查注册表 | 前移到计划阶段，加载时保留防御断言 | 复用错误类型 |
| sync 拓扑 | 无 | 按 CompositionExecutor/LRT 范式实现稳定计划 | 借鉴存量范式 |
| process `PluginEntry.provide/inject` | 已有 | 仅补宿主字段与映射 | 直接复用 |
| process topoSort | 已有，环回退原序 | 原位增强错误和稳定序 | 直接复用，禁止重写 |
| sync 单插件清理 | 已有 | 批量逆序逐项调用 | 直接复用 |
| process removePlugin | 已有 | shutdownAll 逆序逐项调用 | 直接复用 |
| 数据库/权限 | 不涉及 | 0 变更 | 不适用 |

### 10.3 待核实项

1. cordis 包内应使用哪一个已引入的 `Result` 类型承载拓扑错误，需要实现阶段由 `cangjie-coder` 检查该包 imports 后确定；不得凭文档编造类型别名。
2. `DependencyPlan` 最终放在 `magic.plugin` 还是 `plugin-spi`，需以“不引入 plugin-spi → 宿主反向依赖”为准；接口字段语义已由 IF-10 冻结。
3. `loadAll` 中一个轨成环时另一轨是否继续，IF-10 只冻结“成环轨不部分启动”；跨轨全局事务语义待主工程裁决，未裁决前不得擅自扩大。
4. 人工编译、类型检查和仓颉测试结果待实现后回传；本次文档步不运行 `cjpm build`。

### 10.4 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0 | 2026-10-19 | SDD 文档步 | 基于 IF-10、主工程用例 4/R-04 和已验证源码基线完成双轨拓扑、环错误、order 共存与逆序停机设计 |
