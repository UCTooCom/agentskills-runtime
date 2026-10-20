# 子系统集成契约（dependency-graph）

> 模板：`skills/sdd/templates/subsystem-contract-template.md`
> 产出阶段：`spec` / `design`
> 铁律依据：铁律 15（集成契约先定、先改契约再改实现）

> 本契约是承诺，不是实现说明。IF-10 的任何语义变更必须先更新本文件与主工程权威账本，再进入实现。

## 文档信息

- 所属主工程：`plugin-system-enhancement`
- 子系统 ID：`dependency-graph`
- 子系统 `feature_name`：`plugin-system-enhancement--dependency-graph`
- 契约编号：`IF-10`；下列 4 项均为 IF-10 子项，不新增全局接口编号
- 契约版本：`v1`
- 冻结日期 / 状态：2026-10-19 / 草案
- 上游依赖：无；主工程 DAG 明确本子系统可独立开工（`specs/plugin-system-enhancement/SPECS_INDEX.md:89-103`）
- 下游消费方：宿主 `PluginHostManager`、进程轨 `CordisHostManager`、主工程 L2/L3 验收
- 权威边界：主工程登记本子系统为 v1 / 4 接口 / 0 新表（`specs/plugin-system-enhancement/SPECS_INDEX.md:49-58`），全局接口为 IF-10 `DependencyResolver.resolve(entries)`（`specs/plugin-system-enhancement/SPECS_INDEX.md:66-83`）

---

## 1. 本子系统提供什么（能力清单）

| 编号 | 类型 | 路径或标识 | 方法 | 请求形态 | 响应形态 | 错误约定 | 幂等性 | 备注 |
|---|---|---|---|---|---|---|---|---|
| IF-10.1 | 进程内调用 | `DependencyResolver.resolve(entries)` | `resolve` | 已启用的 `PluginManifestEntry` 集合 | `Result<DependencyPlan, PluginError>`（新增设计类型） | 依赖缺失复用 `PluginError.DependencyMissing`；环新增 `PluginError.DependencyCycle`，消息含闭合环路径 | 同一输入必得同一结果 | sync/dylib 读取 `@PluginAnnotation.dependencies`；`order` 仅作同层稳定优先级。现有错误枚举已有 `DependencyMissing`、`ConfigInvalid` 等统一错误（`libs/plugin-spi/src/plugin_types.cj:53-84`）。 |
| IF-10.2 | 进程内调用 | `PluginManifestEntry.fromJsonValue` | 解析 process 依赖声明 | `plugin.yaml` 的 `provide` / `inject` 字符串数组 | `PluginManifestEntry.provide/inject` | 字段非字符串数组时返回 `PluginError.ConfigInvalid`，不得静默吞掉 | 纯解析、幂等 | 这是新增清单字段；当前解析范围止于 `httpRoutes`，无依赖字段（`src/plugin/plugin_config.cj:72-112,122-208`）。 |
| IF-10.3 | L3 插件跨轨 | `CordisHostManager.toCordisEntry` | 映射 process 编排元数据 | `PluginManifestEntry.provide/inject` | `PluginEntry.provide/inject` | process 环在交给 cordis 前以 `DependencyCycle` 明确拒绝；不另写 process 拓扑排序 | 同一条目映射结果一致 | `PluginEntry` 已原生提供 `inject` / `provide`（`libs/cordis-cj/cordis_core/src/config.cj:16-37`），cordis 既有 `topoSort` 消费二者（`libs/cordis-cj/cordis_host/src/plugin_host.cj:980-1031`）。 |
| IF-10.4 | 进程内调用 | `DependencyPlan.reverseOrder` / 宿主批量停机入口 | 逆序卸载/停机 | 已成功激活的拓扑序 | 依赖方先、被依赖方后完成清理 | 单插件清理错误沿用既有生命周期错误并继续清理其余插件 | 对空集合安全；每个插件至多处理一次 | sync 批量卸载消费反序计划；process 停机必须复用 cordis 同一拓扑结果再反转。现有 sync 只有单插件清理（`src/plugin/plugin_host_manager.cj:414-454`），现有 process `shutdownAll` 仅顺序遍历 `startedIds`（`src/plugin/cordis_host_manager.cj:418-438`）。 |

### 1.1 稳定排序契约

1. 依赖边永远高于 `order`：若 B 依赖 A，即使 `B.order < A.order`，A 仍必须先于 B。
2. 在同一时刻可调度的零入度节点中，先按 `order` 升序，再按输入声明顺序稳定选择；未声明 `order` 沿用当前默认值 0。现有 `order` 默认值与稳定冒泡语义见 `src/plugin/plugin_config.cj:88-89,337-350`。
3. 无依赖声明时，结果必须逐项等于现有 `sortByOrder()` 结果；现有发现和集中解析均调用该排序（`src/plugin/plugin_discovery_service.cj:79-81`；`src/plugin/plugin_config_parser.cj:58-60`）。
4. 解析依赖字符串时沿用“逗号拆分、trim、过滤空项”语义，不复制不同规则；现有实现见 `src/plugin/plugin_loader.cj:132-149`。

## 2. 数据契约

| 表/对象 | 本子系统读/写 | 对外暴露字段 | 对外屏蔽字段 | 行级权限 | 软删约束 |
|---|---|---|---|---|---|
| 数据库表 | 不读不写 | 无 | 无 | 不适用 | 不适用 |
| `PluginManifestEntry` | 读现有 `name/mode/enabled/order/className`；新增读写 `provide/inject` | `provide: ArrayList<String>`、`inject: ArrayList<String>`，缺省空数组 | `config/env` 等非依赖字段 | 不适用 | 不适用 |
| `PluginAnnotation` | 只读 `name/dependencies` | `dependencies` 的规范化名称序列 | `version` 不由本子系统解释 | 不适用 | 不适用 |
| `DependencyPlan`（新增设计对象） | 生成并供宿主只读 | 正向拓扑序、逆向拓扑序、声明序索引 | 内部邻接表与入度表 | 不适用 | 不适用 |

- 本子系统 0 新表、0 新列，不执行 `loaddbinfo`、`plugingen`、`crudgen`、`crudweb`，不产生 `sql/incremental/`、`permissions` 或 `role_has_permission` 变更；主工程总览与子系统登记均明确 0 新表（`specs/plugin-system-enhancement/SPECS_INDEX.md:15-27,49-58`）。
- sync 依赖的权威来源是逗号分隔的 `@PluginAnnotation.dependencies`；该字符串形态是仓颉 const Array 限制下的既有约定（`libs/plugin-spi/src/plugin_annotation.cj:25-49`）。
- process 依赖的权威来源是 `plugin.yaml.provide/inject` 服务 Key 数组；缺省空数组保持现有 process 插件行为。`provide` 同时参与 cordis 的服务就绪判定，声明必须与插件实际注册服务一致（`libs/cordis-cj/cordis_host/src/plugin_host.cj:598-610,640-652`）。

## 3. 依赖方向

- **我依赖的上游子系统**：无。主工程 DAG 中 `dependency-graph` 为孤立可并行节点（`specs/plugin-system-enhancement/SPECS_INDEX.md:89-103`）。
- **我复用的存量基础设施**：
  1. sync 排序借鉴 `CompositionExecutor` / `LrtCompositionRunner` 的 Kahn 入度表、邻接表与环检测范式，不直接接入其不同领域模型（`src/skill/composition_executor.cj:286-345`；`src/skill/lrt_composition_runner.cj:359-423`）。
  2. process 排序只复用 cordis 既有 `PluginHost.topoSort`，不得另写第二套 process 拓扑排序（`libs/cordis-cj/cordis_host/src/plugin_host.cj:980-1031`）。
- **我不依赖谁**：不依赖 `version-guard`、`capability-governance`、`capability-handshake`、`lifecycle-observability`、`authoring-toolchain` 的实现或私有数据。
- **与 capability-handshake 的共享文件边界**：双方可能相邻修改 `src/plugin/cordis_host_manager.cj:263-274` 的 `toCordisEntry`。本子系统只写 `PluginEntry.provide/inject`；`capability-handshake` 只写其能力字段/握手载荷。本子系统不得修改 capabilities、协议版本或握手拒绝逻辑。若同轮合并，按字段分区合并并执行同文件冲突复核；主工程已规定共享结构变更必须按契约串行协调（`specs/plugin-system-enhancement/SPECS_INDEX.md:104-105,154-156`）。
- **禁止成环**：本子系统不向上述邻接子系统反向 import；任何新增跨子系统依赖必须先更新本契约与主工程 DAG。

## 4. 我明确不提供什么

| 能力 | 归属子系统 | 原因/备注 |
|---|---|---|
| 宿主/插件 API 版本协商 | `version-guard` | IF-01～IF-04 范围（`specs/plugin-system-enhancement/SPECS_INDEX.md:68-74`）。 |
| 能力清单、运行时门禁、环境与密钥治理 | `capability-governance` | IF-05～IF-07 范围（`specs/plugin-system-enhancement/SPECS_INDEX.md:74-77`）。 |
| L3 能力宣告与握手比对 | `capability-handshake` | IF-08～IF-09 范围（`specs/plugin-system-enhancement/SPECS_INDEX.md:77-79`）。 |
| 崩溃退避、计数、熔断与事件观测 | `lifecycle-observability` | IF-11 范围；cordis 已有自愈但不属本次修改（`specs/plugin-system-enhancement/SPECS_INDEX.md:80,158-159`）。 |
| `plugin validate`、模板与生成器增强 | `authoring-toolchain` | IF-12 范围（`specs/plugin-system-enhancement/SPECS_INDEX.md:81`）。 |
| 复活未接通的 dylib 运行轨 | 主工程 R-01 指定的后续独立立项 | 本子系统仅保证进入现有 Sync/Dylib 分支的条目可排序，不接通 `PluginDylibLoader`（`specs/plugin-system-enhancement/SPECS_INDEX.md:150-153`）。 |
| 数据库表、HTTP API、权限点 | 不适用 | IF-10 是纯进程内编排契约，主工程登记 0 新表（`specs/plugin-system-enhancement/SPECS_INDEX.md:56,79`）。 |

## 5. 契约兼容与演进

| 档位 | 判定 | 怎么处理 |
|---|---|---|
| 内部实现改动 | 不改变 IF-10.1～IF-10.4 的输入、结果、错误与稳定序语义 | 仅更新 `tasks.md` 修订记录；process 仍必须复用 cordis `topoSort`。 |
| 向后兼容（minor） | 只增加可选依赖元数据或诊断字段，缺省行为不变 | 更新本文与主工程 §3；存量清单无需迁移。 |
| 破坏性（major） | 改变 `order` 同层语义、改变 `provide/inject` 含义、删除 IF-10 子项、改变错误类型 | 提供方与宿主消费方同轮修改；登记主工程 §6；单侧先改按 P0。 |

- 演进顺序固定为“先改契约 → 再改实现”；主工程规定全局接口只能由权威账本裁决（`specs/plugin-system-enhancement/SPECS_INDEX.md:66-85`）。
- `provide/inject` 均为可选空数组，旧 `plugin.yaml` 不修改即可维持原排序与启动行为。
- `order` 字段保留，不删除、不改默认值；它从“全局唯一排序依据”降为“拓扑同层稳定优先级”。

## 6. 集成验收（本子系统对下游的交付承诺）

| 编号 | 冒烟用例 | 验证方式 | 依赖的上游 | 通过判据 |
|---|---|---|---|---|
| DG-CT-01 | sync 插件 B 依赖 A，但 `B.order < A.order` | 扩展 `src/plugin/integration/plugin_system_check.cj` | 无 | 注册与激活顺序为 A、B；`PluginRegistry.listAll()` 同序输出。注册表按注册顺序输出的现状见 `src/plugin/plugin_registry.cj:23-24,79-112`。 |
| DG-CT-02 | 三个无依赖 sync 插件含不同/相同 order | 对比新解析结果与旧 `sortByOrder` 黄金序 | 无 | 顺序逐项一致；同 order 保持声明序。 |
| DG-CT-03 | process 插件 provider 提供 Key、consumer 注入同一 Key，consumer 的 order 更小 | 扩展 `src/plugin/integration/cordis_l3_check.cj` | 无 | `toCordisEntry` 完整映射，cordis 先拉起 provider 再拉起 consumer；测试入口已有 process 配置与停机基座（`src/plugin/integration/cordis_l3_check.cj:126-197`）。 |
| DG-CT-04 | sync 或 process 出现 A→B→A | 单元/集成测试 | 无 | 加载前整体拒绝，错误为 `DependencyCycle` 且消息至少含 `A -> B -> A`，无插件进入 Active。 |
| DG-CT-05 | 批量停机 A←B←C | 钩子/进程终止日志断言 | 无 | 卸载/terminate 顺序为 C、B、A；单插件异常不阻断其余清理。 |
| DG-CT-06 | 存量回归 | 执行既有插件集成检查并由人工运行仓颉编译/测试 | 无 | 4 个 sync 锚点与 51 个 skill 插件加载顺序、注册顺序和行为零回归。锚点见 `src/plugins/generated_anchors.cj:1-16`，51 个 skill 防回退要求见 `specs/plugin-system-enhancement/SPECS_INDEX.md:127-155`。 |

- L1：本子系统排序、解析、环检测、逆序测试全部通过。
- L2：IF-10 与宿主 sync/process 两条消费边界的 DG-CT-01～DG-CT-05 全绿。
- L3：由主工程执行“依赖方 order 更小仍后加载”及全量 51 个 skill 零回归（`specs/plugin-system-enhancement/SPECS_INDEX.md:127-134`）。
- AI 不运行 `cjpm build`；编译、类型检查、lint 与可执行集成检查由人工在独立环境执行并回传。

---

## 修订记录

| 日期 | 版本 | 触发来源 | 改动条目 | 影响面（下游子系统） |
|---|:---:|---|---|---|
| 2026-10-19 | v1 | IF-10 初始契约 | 定义 4 个子接口、双轨声明、稳定拓扑、环错误与逆序停机 | 宿主加载器、CordisHostManager；与 capability-handshake 仅有同文件相邻字段 |

> 主工程账本同步：本节后续每次变更必须同步到 `specs/plugin-system-enhancement/SPECS_INDEX.md` §3 / §6。
