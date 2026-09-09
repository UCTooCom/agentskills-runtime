# 插件系统需求规格

> 版本：v3.1（2026-09-03 复核修订：①L3 进程隔离轨 codelabs 插件完整 V4 CRUD 已实现并测试通过——列表/编辑/删除/回收站/创建全部功能正确；②plugingen 新增 `CrudPluginGenerator` 表驱动生成器，可从数据库结构生成完整 CRUD 进程插件（plugin.yaml + cjpm.toml + main.cj + handlers.cj + effects.cj + README.md）；③host.db 服务支持 `$raw:` 前缀约定生成原始 SQL 函数（如 `CURRENT_TIMESTAMP`、`gen_random_uuid()`）；④回收站筛选基于 `filter` 查询参数动态构建 WHERE 子句（`{"deleted_at":{"not":null}}` → `deleted_at IS NOT NULL`）；⑤`empty-recycle-bin` 路由已实现。⑥README.md/web 端 `codelabs-table.vue` 的 `res.codelabss` 双 s 键名符合 API 规范 §8.2（表名+s 复数）。）
> 版本：v3.0（2026-08-28 阶段四立项修订：新增 REQ-PS-015 L3 进程隔离插件轨（cordis-cj 集成），演进路标插入阶段四（L3 轨），插件市场顺延为阶段五；REQ-PS-012 附 v3 修订——附7.13 HTTP 契约 SPI 拆分对 L3 轨不再是必须。依据：可行性报告附7.14 cordis-cj 完整调研。）
> 版本：v2.2（2026-08-28 实际落地修订：同步实际实现方案与架构/框架/仓颉语言限制条件。①双轨并存退化为单轨（宿主内嵌轨），原因 cjpm `[workspace]` 与 `[package]` 互斥；②插件深度依赖宿主子包，独立包模式产生循环依赖；③仓颉反射 API 在 LTO 下剪除未引用类，需 generated_anchors.cj 显式锚定；④动态库标准库符号重复，需 `--dy-std` 编译选项；⑤插件包名必须为简单标识符（`skill_{name}`），不能是带点号的限定名；⑥HMR/合流性无定理背书，对外表述"确定性插件生命周期"。详见下方"§0 实际落地与限制条件"。）
> v2.1（2026-08-18 修订：①复核 agent_skills 表——无必须 DDL 变更，plugin.yaml 元数据走 extra_metadata；②crudgen/crudweb 保留不重构，REQ-PS-011 改为独立 plugingen 工具；③新增 REQ-PS-013 PluginSyncBridge 插件状态库同步。插件注册表本身仍为运行时内存结构，无新表）
> 修订依据：可行性报告全文（含附篇六跨平台、附篇七模块插件化、附7.8 目录归属修正、附7.9 存量冻结决策）、cordis-vs-npm-plugin.md、鸿蒙仓颉动态特性综合分析

## §0 实际落地与限制条件（v2.2 新增，2026-08-28）

> 本节集中说明编码落地后与原设计需求的差异，以及因当前架构、fountain 框架、仓颉编程语言方面的原因未能完全对标 deepseek-harness（Cordis）"一切皆插件"理念的限制条件。详细技术设计修订见 design.md §0。

### §0.1 实际实现方案摘要

| REQ-PS 需求 | 原设计需求 | 实际实现 | 落地状态 |
|------------|-----------|---------|---------|
| REQ-PS-001~009 | 插件框架核心（Plugin/Context/Registry/Loader/EventBus/Config/Manager/SkillBridge/示例） | ✅ 全部编码完成并编译通过，38 个集成测试全绿 | 阶段一完成 |
| REQ-PS-010 | Agent 自引用工具（plugin_inspect/activate/deactivate） | ✅ 编码完成，集成测试通过 | 阶段二完成 |
| REQ-PS-011 | plugingen 插件生成工具（crudgen 保留不重构） | ✅ 编码完成，entity/feedback 经 plugingen 生成 | 阶段二完成 |
| REQ-PS-008 | 插件路由注册与双轨并存 | ⚠️ **退化为单轨**：entity/feedback 经 build-sync 同步进宿主内嵌轨（`src/plugins/{name}/`，包名 `magic.plugins.{name}`），由 PluginRouteScanner 注册路由。未实现"不重编宿主装上新插件"的完整双轨形态 | 部分达成 |
| REQ-PS-009 | 新插件目录结构与构建集成 | ⚠️ **方案三 build-sync 落地，方案二独立包未完全升格**：build-sync 把 `skills/{name}/scripts/cj/` 同步到 `src/plugins/{name}/`，生成 `generated_anchors.cj` 反射锚点。entity/feedback 的独立 `cjpm.toml`（name="skill_entity"/"skill_feedback"，output-type="dynamic"）保留为 L2 动态库预编译入口，但宿主编译时不引用它们（cjpm `[workspace]` 与 `[package]` 互斥限制） | 部分达成 |
| REQ-PS-012 | SPI 抽取与插件独立包化（阶段三硬前置） | ⚠️ **部分落地**：`libs/plugin-spi` 独立包已抽取（Plugin 接口 / PluginAnnotation / PluginContext 契约 / PluginEventBus 接口 / Controller 基类），但插件独立包化受 cjpm workspace 限制和循环依赖限制，未完全升格 | 部分达成 |
| REQ-PS-013 | PluginSyncBridge 插件状态库同步 | ✅ 编码完成，集成测试通过；PluginSyncBridge 单向回写 agent_skills.runtime_status，plugin.yaml 不被数据库侧覆盖 | 阶段二完成 |
| REQ-PS-014 | 插件卸载（阶段三完整卸载能力） | ✅ 编码完成：pluginuninstall CLI + 运行态卸载 + 回归验证。三层卸载模型（运行时层/静态资产层/数据库痕迹层）落地 | 阶段三完成 |
| PS-T012 | L2 动态库加载原型 | ✅ 编码完成：plugin_dylib_loader.cj 实现 PackageInfo.load 热加载，L2 原型验证通过 | 阶段三完成 |

### §0.2 因架构/框架/仓颉语言限制未能完全对标 deepseek-harness 的限制条件

#### 限制 #1：插件无法真正"独立"——cjpm workspace 与 [package] 互斥（架构限制）

**原设计需求**：方案二（阶段三升格）让 `skills/{name}/` 升格为独立 cjpm 包，根 cjpm.toml 追加 `[workspace] members = ["./skills/entity", ...]`，插件以动态库形态独立编译。

**实际限制**：cjpm 规定同一个 `cjpm.toml` 中 `[workspace]` 和 `[package]` **不能共存**。宿主 `cjpm.toml` 既有 `[package]`（name="magic"）又要加 `[workspace]`，编译报错 `only one of 'workspace' or 'package' fields can exist`。fountain fdemo 先例证实：workspace 根 `cjpm.toml` 只有 `[workspace]` 段，没有 `[package]` 段——但我们的宿主本身就是 `magic` 包，不能既是 workspace 根又是 package。

**实际落地方案**：放弃 workspace 成员模式，改用**宿主内嵌轨**——插件源码经 build-sync 同步到 `src/plugins/{name}/`，包名 `magic.plugins.{name}`，属宿主 magic 包编译图。entity/feedback 的 `cjpm.toml`（name="skill_entity"/"skill_feedback"，output-type="dynamic"）保留为独立编译入口，但宿主编译时不引用它们。

**与 DSH 的差距**：DSH 的插件是运行时 fiber，天然独立于宿主进程；agentskills-runtime 的插件是编译期静态资产，必须进入宿主编译图才能被反射发现，无法实现"不重编宿主装上新插件"的完整形态。阶段三 PS-T012 L2 动态库加载原型部分缓解此限制（PackageInfo.load 热加载），但插件仍需预编译为动态库。

#### 限制 #2：插件深度依赖宿主子包——独立包模式产生循环依赖（架构限制）

**原设计需求**：插件包只依赖 `plugin-spi`，不 import 宿主 magic 包（cjpm 依赖单向性）。

**实际限制**：entity 插件源码深度依赖宿主子包：`magic.app.core.http.*`、`magic.app.core.query.*`、`magic.app.core.response.*`、`magic.app.core.router.Router`、`magic.app.utils.PermissionUtils`、`magic.log.LogUtils`。若 entity 升格为独立 cjpm 包（name="skill_entity"），它必须 import 这些宿主子包，但 cjpm 依赖单向——宿主不能依赖 entity（否则循环），entity 又必须依赖宿主 → 循环依赖无解。

**实际落地方案**：entity/feedback 保留对宿主 `magic` 包的依赖（CRUD 插件需要 `magic.app.core.*`、`magic.log.*` 等基础类型），通过宿主内嵌轨编译。独立包模式（skills/entity/cjpm.toml）仅在 L2 动态库预编译场景使用，此时插件动态库符号在运行时由 PackageInfo.load 解析，编译期不检查循环依赖。

**与 DSH 的差距**：DSH 的插件是纯函数 fiber，不依赖宿主内部实现；agentskills-runtime 的 CRUD 插件深度耦合宿主 HTTP/RBAC/日志设施，无法做到插件包"零宿主依赖"。

#### 限制 #3：仓颉反射 API 限制——ClassTypeInfo.get 跨包查询不稳定（语言限制）

**原设计需求**：PluginRouteScanner 通过 `ClassTypeInfo.get("magic.plugins.entity.EntityRoute")` 跨包反射发现插件路由类。

**实际限制**：仓颉反射 API 在 LTO（链接时优化）下会剪除未被静态引用的类，导致 `ClassTypeInfo.get` 返回 `None`。fountain BeanFactory.cj L52 注释警告：`调用isSubtypeOf会导致得不到类实现的直接接口，所以把isSubtypeOf放到if条件最后面`。此外 `TypeInfo`（fountain `TypeInfos.get()`）缺少 `constructors` 属性，必须保留 `ClassTypeInfo.get()` 才能获取构造器信息。

**实际落地方案**：build-sync 自动生成 `generated_anchors.cj`，显式 import 并实例化插件 Route/Plugin 类（`let _anchor_0 = EntityRoute()`），作为 L1 反射锚点防 LTO 剪除。PluginRouteScanner 仍用 `ClassTypeInfo.get` 反射发现，但依赖锚点保证类不被剪除。

**与 DSH 的差距**：DSH 的 `cordis_define` 是运行时动态定义，无编译期限制；agentskills-runtime 受静态语言 + LTO 限制，插件类必须显式锚定才能被反射发现。

#### 限制 #4：仓颉动态库标准库符号重复——--dy-std 编译选项必需（语言/工具链限制）

**原设计需求**：L2 动态库插件编译为 `.so`/`.dll`/`.dylib`，宿主通过 PackageInfo.load 热加载。

**实际限制**：仓颉动态库默认静态链接标准库，多个 `.so` 同时加载会重复包含标准库符号，触发 `ld.lld: error: _CGP15xxx was replaced` 符号冲突。必须为动态库编译添加 `--dy-std` 选项，使动态库使用动态链接的标准库。fountain fdemo cjpm.toml 先例证实：`compile-option = "-O2 --dy-std -Woff unused"` + `[target.x86_64-unknown-linux-gnu.bin-dependencies] path-option = ["${CANGJIE_STDX_DYNAMIC_PATH}"]`。

**实际落地方案**：entity/feedback 的 `cjpm.toml` 编译选项统一为 `compile-option = "-O2 --dy-std -Woff all"`。宿主内嵌轨编译不需要 `--dy-std`（静态链接），仅 L2 动态库预编译时需要。

**与 DSH 的差距**：DSH 是单一运行时进程，无动态库符号冲突问题；agentskills-runtime 受仓颉工具链限制，动态库插件必须显式处理标准库链接方式。

#### 限制 #5：插件包名必须为简单标识符——cjpm name 字段约束（工具链限制）

**原设计需求**：插件包名 `magic.plugins.{name}`（与框架包 `magic.plugin` 区分，复数形态）。

**实际限制**：cjpm `name` 字段必须是**简单标识符**（如 `plugin_spi`、`skill_entity`），不能是带点号的限定名（如 `magic.plugins.entity`）。fountain 32 个子包均遵循此规范（`f_orm`、`f_data` 等）。

**实际落地方案**：宿主内嵌轨插件包名仍用 `magic.plugins.{name}`（属宿主 magic 包的子包，cjpm 不单独编译）；独立包轨插件包名用 `skill_{name}`（如 `skill_entity`、`skill_feedback`），符合 cjpm 简单标识符规范。两轨包名不同但源码同构，通过 build-sync 同步保持一致。

**与 DSH 的差距**：DSH 无包名约束；agentskills-runtime 受 cjpm 工具链限制，插件包命名需区分内嵌轨/独立轨两套规范。

#### 限制 #6：HMR/合流性无定理背书——对外表述"确定性插件生命周期"（设计限制）

**原设计需求**：§2.10 与 Cordis 六语义对照中，HMR/合流性标注"工程近似，无定理背书"。

**实际限制**：静态编译语言无运行时 fiber 模型，无法实现 DSH 的响应式 inject、Proxy ctx、HMR、五种事件分发（emit/parallel/serial/bail/waterfall）。agentskills-runtime 以"注解声明 + 反射发现 + 生命周期状态机"覆盖 Cordis 六语义中的五个（Service/inject/effect/Events/检视），事件总线实现 emit/waterfall 两种最常用语义，仅 HMR 延后。

**实际落地方案**：不变量表中明确标注"HMR/合流性无定理背书，对外只表述确定性插件生命周期"。PluginEventBus 实现 emit/waterfall，未实现 parallel/serial/bail（f_concurrent EventBus 不在当前依赖中，且其语义是线程池任务执行器非发布订阅）。

**与 DSH 的差距**：DSH 是响应式 fiber 模型，HMR 原生支持；agentskills-runtime 受静态语言限制，HMR 需待 v1.1+ 增强形态（WASM 沙箱插件）才可能实现。

## 项目背景

agentskills-runtime 需要一套跨平台的纯仓颉插件系统，支撑 ROADMAP 中 v1.0"插件市场基础设施"和 v1.1"插件市场上线"两个里程碑。

前置研究已确认可行性（详见 `docs/ref/cangjie-plugin-system-feasibility.md`）：

- **L1 编译时插件（注解 + 反射动态实例化）是主形态**：仓颉反射 API（`ClassTypeInfo.get` / `ConstructorInfo.apply` / `findAnnotation`）完整支撑"运行时发现 + 实例化"闭环，工程上等价于 Java ServiceLoader + 注解扫描但更强。
- **L2 运行时动态加载是扩展形态**：仓颉标准库 `std.reflect` 的 `PackageInfo.load()` / `ModuleInfo.load()` 可运行时加载仓颉动态库（Linux `.so` / Windows `.dll` / macOS `.dylib`）并反射访问，全平台可用。
- **Cordis 六大语义全部可仓颉化**：服务定位（显式注册表）、声明式依赖（注解 + 启动校验）、可逆卸载（逆序清理栈）、事件分发（emit/waterfall）、运行时反射（注册表快照）、合流性（幂等加载工程近似）——语义等价，实现路径不同，类型安全更强。
- **编译约束已验证**：cjpm 目录扫描规则要求每级目录含 `.cj` 文件（pkg.cj 占位机制，项目现有 13 个占位文件正常运行）；`build.cj` 支持 pre-build/post-build 钩子。

## 范围边界（三条硬边界）

1. **跨平台纯净（排除 ArkTS）**：ArkTS 互操作（`requireArkModule`）依赖 `ohos.ark_interop` 系统库，仅鸿蒙可用；agentskills-runtime 跨平台运行于 Windows/macOS/Linux/鸿蒙，本插件系统**不采用** ArkTS 通道，只做全平台可用的纯仓颉方案（L1 + PackageInfo.load）。禁止 import `ohos.*`。
2. **存量冻结（2026-08-18 架构师决策，附7.9）**：`src/app` 已有模块（97 controller / 83 route / 69 model + 69 dao，大部分与 harness 及框架运行主要功能相关）**不迁移、不重构、不改包名**，视为宿主（host）本体。`AutoRouteConfig.cj`（1364 行）继续作为存量模块的路由注册机制，进入**只减不增**的维护态。本插件系统**仅面向未来新插件的开发**——新能力一律以插件形态交付，不再向 `src/app` 与 `AutoRouteConfig.cj` 追加代码。
3. **不在本 SDD 范围**：插件市场服务端（v1.0/v1.1 另立 SDD）；WASM 沙箱插件（v1.1+ 增强形态）；126 张冗余数据库表的清理（与插件系统无关，另行立项）。

## 核心问题

1. **无统一插件抽象**：除 MemoryProvider 的"接口+多实现"（L0 形态）外，框架能力（工具、数据源、服务）没有统一的注册/发现/生命周期机制，新增能力需要改框架代码。
2. **Agent 无法检视运行时能力**：Agent 只能使用预先暴露的工具，无法查看"当前有哪些插件、什么状态、依赖什么、提供什么技能"。
3. **无生命周期管理**：能力加载/卸载没有状态机、没有依赖校验、没有逆序清理，出问题时无法回滚。
4. **确定性能力与 AI 行为两张皮**：工具（Service）和技能（Skill）是两套体系，插件机制应让一个插件同时携带两者——"AI 驱动插件"是默认形态而非事后扩展。
5. **新增 CRUD 模块仍走硬编码通道**：现状每新增一个模块就要改 `AutoRouteConfig.cj` 并追加 `src/app` 代码；需要为**新**模块提供"插件形态 + 运行时反射注册路由"的第二通道，与存量通道双轨并存。
6. **动态加载通道未利用**：仓颉标准库已有 `PackageInfo.load()` 跨平台动态加载 API，但尚未封装进框架，无法运行时装载新插件。

## 功能需求

### REQ-PS-001: Plugin 接口与生命周期
- 定义 `Plugin` 接口（仓颉接口）：`getName` / `onLoad` / `onActivate` / `onDeactivate` / `onUnload`
- 定义 `PluginContext`：每个插件一个，作为生命周期载体，持有 ServiceRegistry / EventBus / SkillBridge 访问句柄与 config 参数
- 生命周期状态机：`PENDING → LOADING → ACTIVE → ERROR / DISPOSED`，状态转换有明确语义
- 逆序清理：`onUnload` 时按"后注册先清理"执行插件清理栈（disposer 逆序栈，对应 cordis effect/disposer 语义）

### REQ-PS-002: @Plugin 注解与反射发现
- 定义 `@Plugin` 注解（类名 `PluginAnnotation`）：`name` / `version` / `dependencies`
  - `dependencies` 为逗号分隔字符串（如 `"memory-builtin,tool-http"`）——仓颉 const 表达式不支持 `Array<String>` 类型注解参数（官方文档：const 的 Array 字面量"不能是 Array 类型，仅 VArray 可用"，而 VArray 长度固定不适用），加载时按逗号拆分为 `Array<String>` 再校验
- `PluginLoader` 通过反射按名发现插件类：`ClassTypeInfo.get` → `findAnnotation<PluginAnnotation>` → `ConstructorInfo.apply` 实例化（`apply` 返回 `Any` 且可能抛反射异常如 `InfoNotFoundException`，需 try/catch 包装并转换为 `Plugin`）
- 依赖声明与启动校验：加载前检查依赖插件是否已注册，缺失则进入 `ERROR` 态并回滚注册表快照

### REQ-PS-003: PluginRegistry 注册表
- 插件注册、查询（按名/按状态/全量）、注销
- **幂等加载**：同名插件重复注册不产生副作用（返回已存在实例）——合流性的工程近似
- **快照与回滚**：注册表可拍快照，加载失败时可恢复快照——"试运行后干净撤回"（对应 dsh tool-cordis 灵魂能力的 L1 等价物）

### REQ-PS-004: 插件事件总线
- 编译期事件接口 + 运行时总线（插件间协作通道）
- 支持 `emit`（广播，一对多）与 `waterfall`（链式，前一个返回值作为后一个入参）
- 事件订阅支持优先级与按插件生命周期自动清理（插件卸载时其订阅自动移除）
- 订阅参数遵循仓颉命名参数规则："非命名参数须在命名参数之前"，`priority!` 必须位于参数列表末尾

### REQ-PS-005: 配置驱动
- `plugins.yaml` 插件清单：启用的插件、插件类全名、参数注入、加载顺序
- 框架启动时按配置加载插件，未在清单中的插件不加载（即使类存在）
- 支持通过配置切换同名插件的实现（如 memory-postgres / memory-builtin）
- 解析复用项目现有 YAML 设施（`yaml4cj.yaml.decode` + `YamlUtils`，参照 `yaml_team_config_parser.cj` 模式），不得用 JSON 解析器解析 YAML

### REQ-PS-006: Agent 自引用工具
- `plugin_inspect`：检视已注册插件、状态、依赖、提供的服务与技能
- `plugin_activate`：激活已注册插件（含依赖校验）
- `plugin_deactivate`：停用插件（逆序清理 + 快照回滚）
- 不实现"运行时定义新插件"（`cordis_define` 等价物）——受静态语言限制，留待 L2 形态

### REQ-PS-007: 插件 + Skills 融合（神经系统）
- 插件目录内 SKILL.md 自动注册到 SkillRegistry，Agent 可发现并调用
- 插件能力目录：AI 可消费的插件能力描述（插件名/服务/技能/参数/示例）
- 复用现有 SkillEngine（ProgressiveSkillLoader / SkillRegistrationService），不另造技能体系
- 插件 = Service（确定性能力）+ Skill（AI 行为），由 PluginContext（ServiceRegistry + EventBus + SkillBridge 三合一容器）组装

### REQ-PS-008: 插件路由注册与双轨并存（存量冻结的配套）
- 定义 `@ModuleRoute` 注解（类名 `ModuleRouteAnnotation`，语法参照 @Plugin）：`basePath` / `table` / `database` / `controllerClass`
- 新插件的 Route 类通过注解声明路由，由 `PluginRouteScanner` 运行时反射发现并注册（`ClassTypeInfo.get` → `findAnnotation` → `ConstructorInfo.apply` → `register(router, controller)`）
- **双轨并存**：存量模块继续走 `AutoRouteConfig.cj` 硬编码注册（只减不增），新插件走 PluginRouteScanner 动态注册；两套机制在 RouteRegistry 汇合，依赖 HTTPServer 已有去重逻辑保证无冲突
- crudgen 停止向 `AutoRouteConfig.cj` 追加新条目（见 REQ-PS-011）

### REQ-PS-009: 新插件目录结构与构建集成
- 新插件的标准物理目录为项目根 `skills/{name}/`，三维一体：
  - `SKILL.md`（AI 行为定义，SkillEngine 资产，不编译）
  - `plugin.yaml`（插件清单：name/version/dependencies/entry 类全名/tables/skills 路径）
  - `scripts/cj/`（仓颉可编译代码，含五层 CRUD 或任意插件代码 + pkg.cj 占位）
- **阶段二采用方案三（build-sync）**：`build.cj` pre-build 钩子把 `skills/{name}/scripts/cj/` 同步到 `src/generated/skill-plugins/{name}/`（自动生成 pkg.cj 占位与包声明映射），代码仍属 magic 包，无依赖方向问题
- **阶段三升格方案二（独立 cjpm 包）**：`skills/{name}/` 升格为独立 cjpm 包（自有 cjpm.toml），根 cjpm.toml 追加 path 依赖——前置条件是 REQ-PS-012 的 SPI 抽取
- 插件包声明规则：同步态包名为 `magic.plugins.{name}`（与框架包 `magic.plugin` 区分）
- 仓库内技能目录（`skills/`）与 SkillEngine 引擎源码（`src/skill/`，magic.skill 包）是两个身份不同的目录，插件代码不得放进 `src/skill/`（附7.8 教训）

### REQ-PS-010: L2 动态库加载（扩展形态，阶段三）
- 封装 `PackageInfo.load()`：运行时加载仓颉动态库（`.so` / `.dll` / `.dylib`），反射访问其中声明的插件类型
- 与 L1 统一由 PluginManager 管理，插件开发者无感知
- 加载失败（库缺失/符号不存在/版本不兼容）时明确报错并回滚注册表
- 卸载/回收行为（dlclose 后对象回收）需原型实证，至少一个平台跑通

### REQ-PS-011: 插件生成工具 plugingen（crudgen/crudweb 保留不重构）
- **crudgen / crudweb 完整保留、不做任何重构**：继续作为宿主代码通道——未来需要为宿主新增功能模块或迭代宿主代码时，仍用现有模块机制（crudgen 生成到 `src/app/` + 追加 `AutoRouteConfig.cj`，crudweb 生成管理界面）。"AutoRouteConfig 只减不增"红线约束的是**插件化新业务能力**；宿主本体自身的功能演进不受此限制（宿主开发者自知自控）。
- **新增 plugingen**：与 crudgen 同构的确定性插件生成工具（参照 crudgen 的 TemplateEngine + templates/ 架构，位于 `src/plugin/tools/plugingen/`，属 magic.plugin 包，不放 src/app）：
  - 输入：表名（从 db_info 读表结构，同 crudgen）或空白插件骨架
  - 输出：`skills/{name}/` 完整三维一体目录——SKILL.md 模板 + plugin.yaml + scripts/cj/ 五层 CRUD + @Plugin 入口类 + @ModuleRoute 标注的 Route + pkg.cj 占位
  - 生成的 Route 走 PluginRouteScanner 注册，**不触碰 AutoRouteConfig.cj**
  - 与 crudgen 的关系：两条并行通道，模板独立演进，互不依赖
- package_release 适配：插件编译产物与 plugin.yaml 清单一并打包，发布包保持 `plugins/{name}/` 目录结构

### REQ-PS-013: 插件信息与 agent_skills 表的同步（PluginSyncBridge）
- **表结构结论（2026-08-18 复核）**：`agent_skills` 表（54 列）已具备承载插件技能元数据的字段——name/version/dependencies（JSON 数组）/install_path/source_path/runtime_status/scripts_dir_exists 等一应俱全，**无必须的 DDL 变更**；plugin.yaml 特有信息（entry 类全名、tables 使用的业务表）写入现有 `extra_metadata`（JSON，扩展元数据字段）。若市场/审计阶段需要按"是否插件"过滤，再增量 `ALTER TABLE` 加列（如 `is_plugin`），属可选、阶段二以后按需触发，不阻塞框架。
- **存量同步机制天然兼容**：现有双向同步（AgentSkillSyncHandler）按 SKILL.md 解析、以 source_path 为唯一标识，插件目录的 SKILL.md 会被无差别同步进库，无需改动即工作。
- **新增 PluginSyncBridge（插件侧组件，不动存量 sync 代码）**：位于 `src/plugin/`，订阅 EventBus 插件生命周期事件，把 PluginState（五态）单向回写 `agent_skills.runtime_status`、把 plugin.yaml 元数据合并进 `extra_metadata`——使数据库始终反映插件最新运行态，供 plugin_inspect 与管理界面 JOIN 查询。
- **反向保护红线**：数据库 → 文件方向（syncToFileSystem）只回写 SKILL.md；**plugin.yaml 永不被数据库侧修改覆盖**（插件自描述归插件开发者所有）。此约束在 PluginSyncBridge 实现中强制，不依赖存量 sync 代码。

### REQ-PS-014: 插件卸载（阶段三完整卸载能力）

> **设计动因**：阶段二删除 entitygen/feedbackgen 时全程手工（删目录、清 plugins.yaml、清 generated_anchors.cj、清 target 产物、清数据库痕迹），暴露了阶段二"只有运行时停用（plugin_deactivate）、无工程级卸载"的缺口。阶段三 L2 动态库加载让"不重编宿主装上新插件"成为可能后，对称地需要"不重编宿主卸载一个插件"——这要求卸载能力从"运行时停用 effect"升级为"运行时停用 + 静态资产清理 + 数据库痕迹清理"的完整生命周期闭环。

- **卸载三层模型**（对应 Cordis 可逆卸载语义在静态语言工程下的完整等价物）：
  1. **运行时层（L1/L2 统一）**：`PluginManager.deactivate(pluginName)` 停用运行时实例 → 触发 `onDeactivate` → `onUnload` → 逆序执行 PluginContext.onCleanup 清理栈 → 从 PluginRegistry 注销 → 从 ServiceRegistry 移除该插件注册的服务 → PluginEventBus.unsubscribeAll 移除订阅 → PluginRouteScanner 撤销该插件注册的路由。L2 形态额外执行 `dlclose`（见 REQ-PS-010）。
  2. **静态资产层**：删除 `skills/{name}/` 源目录 → 删除 build-sync 同步产物 `src/generated/skill-plugins/{name}/` → 删除编译产物 `target/release/magic/libmagic.plugins.{name}.a` 及对应 `.cjo` → 从 `config/plugins.yaml` 加载清单移除该插件条目 → 从 `src/plugins/generated_anchors.cj` 反射锚点移除该插件的 import 与 entry 注册（build-sync 增强：支持删除检测，而非仅追加新增）。
  3. **数据库痕迹层**：清理 `agent_skills` 表中该插件的记录（PluginSyncBridge 当前只做"内存→库回写"，卸载时需主动清理孤儿记录）→ 清理 `permissions` 表中该插件对应的菜单节点（plugingen 幂等插入的对称删除）→ 清理 `i18` 表中该插件对应的国际化键（同上对称删除）。

- **卸载工具 `pluginuninstall`**（与 plugingen 对称的确定性卸载工具）：
  - 输入：`--name <插件名>`（与 plugingen `--name` 参数对称）
  - 执行顺序：校验插件存在 → 运行时层卸载 → 静态资产层清理 → 数据库痕迹层清理 → 输出卸载报告（清理了哪些文件/配置/数据库记录）
  - 位于 `src/plugin/tools/pluginuninstall/`，属 magic.plugin 包（与 plugingen 同级）
  - 与 `plugin_deactivate` Agent 工具的关系：`plugin_deactivate` 是运行时停用（可重新激活），`pluginuninstall` 是完整卸载（文件资产一并清理，需重新 plugingen 生成）。两者职责正交，不可混用。

- **卸载安全机制**：
  - **依赖检查**：卸载前检查是否有其他插件依赖该插件（@Plugin.dependencies 中声明），有依赖则拒绝卸载并提示依赖方插件名，或提供 `--force` 级联卸载（按依赖逆序先卸载所有依赖方）。
  - **活跃 run 检查**：卸载有活跃业务请求的插件前，等待 in-flight 请求完成或提供 `--force` 强制中断（对应 DSH cancelPending + retract 语义）。
  - **卸载审批**（阶段四增强）：卸载有活跃 run 的插件前需人工审批，对应 DSH approval seam。

- **卸载幂等性**：
  - 重复卸载同一插件不应报错或产生副作用（对应 Cordis fiber.dispose() 幂等语义）。
  - 卸载一个从未安装的插件应返回明确错误，而非崩溃。

- **卸载事件溯源**（阶段四增强，但卸载工具需预留事件发射点）：
  - 卸载过程的每一步（运行时停用/文件删除/配置清理/数据库清理）都应通过 PluginEventBus 发射 `plugin.uninstall.*` 系列事件，供 PluginSyncBridge 同步数据库、供管理界面实时展示卸载进度、供事后审计。

- **与 deepseek-harness（Cordis）卸载机制的对标**（详见 `docs/ref/deepseek-harness-plugin.md`）：

  | 卸载维度 | DSH（Cordis） | agentskills-runtime（REQ-PS-014） | 差异根源 |
  |---|---|---|---|
  | 运行时停用 | ✅ fiber.dispose() 撤销所有 effect | ✅ PluginManager.deactivate + 逆序清理栈 | 基本对齐，agentskills 需插件手写 onCleanup，DSH 自动入栈 |
  | 副作用自动跟踪 | ✅ Cordis effect/disposer 自动入栈 | ⚠️ 依赖插件在 onCleanup 手写清理 | 静态语言限制，阶段三可考虑增强 PluginContext 副作用跟踪 |
  | 取消未决操作 | ✅ cancelPending | ✅ 活跃 run 检查 + 等待/强制中断 | 语义对齐 |
  | 停止活跃 run | ✅ retract | ✅ 等待 in-flight 完成 + 可选强制中断 | 语义对齐 |
  | 通知模型插件状态 | ✅ undefineFromPanel 注入 user 消息 | ⚠️ plugin_inspect 可查，卸载无主动通知 | 阶段三可考虑增强 |
  | 物理文件删除 | ❌ DSH 不做（沙箱级生命周期） | ✅ pluginuninstall 静态资产层清理 | agentskills 插件是"编译期静态资产+运行时实例"双重生命周期 |
  | 加载清单清理 | ❌ DSH 无持久化加载清单 | ✅ 从 plugins.yaml 移除条目 | 同上 |
  | 反射锚点清理 | ❌ DSH 无静态链接锚点 | ✅ 从 generated_anchors.cj 移除 import | 同上 |
  | 数据库痕迹清理 | ❌ DSH 会话级，无持久化 | ✅ 清理 agent_skills/permissions/i18 | 同上 |
  | 级联卸载 | ✅ fiber.dispose() 递归子 fiber | ✅ 依赖检查 + --force 级联卸载 | 语义对齐 |
  | 卸载幂等 | ✅ Cordis fiber.dispose() 幂等 | ✅ 重复卸载不报错不产生副作用 | 语义对齐 |

  **核心结论**：agentskills-runtime 的卸载能力设计对标了 Cordis 的"运行时 effect 撤销"语义，但因为插件生命周期模型不同（编译期静态资产 vs 会话级动态 effect），**工程级卸载（文件/配置/编译产物/数据库痕迹的清理）是 agentskills-runtime 独有的能力，DSH 不需要也不具备这一层**。这个能力应该由新建的 `pluginuninstall` 工具来承载，而不是简单照搬 DSH 的 `undefine`。

### REQ-PS-012: SPI 抽取与插件独立包化（阶段三硬前置）
- 抽取 `libs/plugin-spi` 独立基础包：Plugin 接口 / PluginAnnotation / PluginContext 契约 / PluginEventBus 接口 / Controller 基类（插件面向的稳定 API）
- 宿主（magic 包）与插件包都依赖 plugin-spi；插件包**不得 import 宿主 magic 包**（cjpm 依赖单向性）
- 抽取时点：**首个 L2 动态库插件开发前**（动态库插件编译期不能依赖宿主包）——存量冻结决策下不提前做
- **v3 修订（2026-08-28）**：阶段四引入 L3 进程隔离轨后，附7.13 的 HTTP 契约 SPI 拆分对 L3 轨不再是必须（进程边界使 JSON-RPC 协议契约取代接口契约）；SPI 拆分仅服务于 L2 动态库轨，按需推进，两轨演进解耦

### REQ-PS-015: L3 进程隔离插件轨（cordis-cj 集成，阶段四）

> **设计动因**：阶段三 L2 动态库轨实现了"不重编宿主装插件"，但插件与宿主同进程（无故障隔离、卸载依赖 dlclose 行为不确定），且设计文档 §0.2 六大限制中 #2/#3/#4/#5 仅被部分缓解。经调研第三方库 cordis-cj（`apps/cordis-cj`，MIT，对标 DeepSeek Harness Cordis 的仓颉实现，详见可行性报告附7.14），其"微内核 + 进程隔离"架构（插件 = 独立子进程，卸载 = 杀进程 + OS 资源回收）可彻底消解五大限制、大幅缓解第六限制。集成方案为**三轨并存新增第三轨**，不推翻现有内嵌轨/L2 轨。

- **前置闸门（一票否决项，Spike 先行）**：
  - Spike-1 工具链兼容：cordis-cj 声明 cjc 1.1.3，需用宿主 1.0.5 工具链编译验证（人工独立 cmd 执行）
  - Spike-2 Windows 可编译性：cordis_host 依赖 `ystyle::jsonrpc_unix`（UDS 不支持 Windows），需在 x86_64-w64-mingw32 目标验证；失败则 vendor 后剥离 UDS 代码（stdio 模式不受影响）
- **传输固定 stdio**：宿主开发环境含 Windows，集成后固定 `transport = "stdio"`（NewlineFraming + JSON-RPC 2.0，全平台）；UDS 不启用
- **宿主集成组件**（全部位于 `src/plugin/`，magic.plugin 包，存量 src/app 零改动）：
  - `CordisHostManager`：包装 `ystyle::cordis_host` 的 PluginManager(stdio)/PluginHost/reconcile 循环；从 `plugins.yaml` 读取 `mode: process` 插件生成期望状态
  - `ExternalPluginRouteGateway`：为 process 插件注册 UCTOO V4 路由（POST /add、/edit、/del 等），handler 序列化 HTTP 请求（method/path/pathParams/queryParams/body/userId）→ `invoke` 插件进程 → 插件返回 `{errno, errmsg}` 或数据对象 → 网关回写；中间件链（CORS → DeserializeUser → RequirePermission → RowLevel → OperateLog）在宿主侧执行，V4 API 规范与 RBAC/行级权限体系完全保留
  - **宿主侧服务代理**：宿主在 RPC 连接上注册 `host.db`/`host.log`/`host.cache` 等服务 handler，插件进程经 `ctx.invoke` 反向调用（数据访问复用宿主 f_orm/连接池/权限过滤，插件不直连数据库）
- **插件形态**：独立 cjpm 工程（output-type = "executable"，--static），入口为 `PluginRuntime.run(...)` 显式 API 写法（**禁用 `@Plugin` 宏**——规避 cjpm 宏包 organization 跨模块缺陷，与 cordis-cj 官方对外部插件作者的建议一致）；依赖 `ystyle::cordis_plugin` + `jsonvalue`
- **插件生命周期语义**（对齐 Cordis/DSH）：
  - 启停：`plugin_activate`/`plugin_deactivate` Agent 工具映射为 reconcile 期望状态 enabled 变更 → 拉起/terminate（杀进程 = OS 级资源回收，卸载确定性优于 dlclose）
  - 崩溃自愈：stdout EOF → Failed → 下一轮 reconcile 自动重拉（探活 ping 超时 → Unreachable → 重启）
  - 状态回写：cordis InstanceStatus（Starting/Pending/Active/Unloading/Failed/Unreachable）→ PluginState 五态 → `agent_skills.runtime_status`（PluginHost.onStatusChange → PluginSyncBridge，复用既有通道）
  - 可逆效果：插件侧 `ctx.effect` 注册、卸载逆序执行（对齐 Cordis fiber.dispose 语义）
- **生成与卸载工具适配**：plugingen 新增 `mode: process` 输出形态（三维一体目录 + 独立 cjpm.toml + PluginRuntime.run 入口模板）；pluginuninstall 新增 process 轨支持（终止进程 + 删除二进制与清单 + 清数据库痕迹）
- **跨进程事件（阶段四后期，可选增强）**：cordis EventRegistry（五种派发 emit/parallel/serial/bail/waterfall + 类型安全）与进程内 PluginEventBus 桥接
- **与"一切皆技能"的关系**：L3 轨使"第三方开发者独立发布插件（可闭源、故障隔离、AI 动态启停）"的插件市场门槛真正达成——技能 = SKILL.md（AI 行为）+ 独立可执行插件（确定性能力）+ plugin.yaml（清单），AI 经 Agent 工具对插件进程做 inspect/activate/deactivate 即 DSH tool-cordis 自引用语义的进程级等价物

## 演进路标（v3 修订：插入阶段四 L3 进程隔离轨，2026-08-28，与附7.14.8 一致）

| 阶段 | 版本锚点 | 需求 | 晋级门槛 |
|---|---|---|---|
| 阶段一：插件框架核心 | v0.5 | REQ-PS-001~007、008（双轨验证） | 集成测试全绿，存量功能回归无损（src/app 零改动） |
| 阶段二：增量插件化就位 | v0.6 | REQ-PS-006 工具上线、009（方案三）、011（plugingen）、013（SyncBridge） | 第一个真实新插件不经框架代码修改上线 |
| 阶段三：L2 动态加载 | v0.7~v0.9 | REQ-PS-012（SPI）、010（L2）、009 升格方案二、014（卸载） | 不重编宿主装上一个新插件 |
| **阶段四：L3 进程隔离轨（cordis-cj）** | v1.0 | **REQ-PS-015**（Spike 闸门 → 宿主集成 → 网关代理 → 生成/卸载/同步 → 事件桥接） | Spike 双闸门通过；一个 V4 CRUD 插件以进程形态上线（web-admin 回归通过、杀进程 3 秒内自愈）；第三方可独立发布进程插件 |
| 阶段五：插件市场 | v1.1 / v1.2 | 另立 SDD | 第三方可独立发布插件（市场基础设施） |

## 验收标准

- [ ] `Plugin` 接口与 `PluginContext` 定义完整，生命周期状态机正确流转（五态）
- [ ] `@Plugin` 注解可被反射发现，插件类可按名实例化（含依赖校验与错误映射）
- [ ] 注册表幂等：同名插件重复注册返回同一实例且无副作用
- [ ] 快照回滚：模拟加载失败，注册表恢复到失败前状态
- [ ] 事件总线 emit/waterfall 正确分发，插件卸载后其订阅自动移除
- [ ] `plugins.yaml` 正确解析，可控制启停与参数注入
- [ ] 三个 Agent 工具可正常调用（inspect/activate/deactivate）
- [ ] 插件目录内 SKILL.md 自动注册到 SkillRegistry，Agent 可调用插件技能；无 SKILL.md 的插件以纯 Service 态运行
- [ ] 插件路由经 @ModuleRoute + PluginRouteScanner 注册成功；与 AutoRouteConfig 存量路由双轨并存无冲突，存量 API 回归无损
- [ ] plugingen 对新表输出完整插件三维一体目录，`AutoRouteConfig.cj` 无任何新增行；crudgen/crudweb 源码零改动（保留验证）
- [ ] PluginSyncBridge 把插件状态回写 agent_skills.runtime_status；plugin.yaml 不被数据库侧覆盖；存量 sync 双向机制回归无损
- [ ] L2 动态库加载原型可加载一个最小插件动态库并反射访问（阶段三验收）
- [ ] Spike-1/Spike-2 双闸门通过：cordis-cj 在宿主 1.0.5 工具链 + Windows（x86_64-w64-mingw32）目标编译通过（阶段四前置验收）
- [ ] CordisHostManager 以 stdio 传输拉起 process 插件：握手/provide/日志汇聚/terminate 全链路日志可见（阶段四验收）
- [ ] 一个 V4 CRUD 插件以进程形态上线：web-admin 数据表格页面 CRUD 回归通过，行级权限拦截行为与内嵌轨一致（阶段四验收）
- [ ] 崩溃自愈：杀插件进程后 reconcile 自动重拉，宿主与相邻插件无感知（阶段四验收）
- [ ] plugin_activate/plugin_deactivate 对 process 插件生效（拉起/杀进程），agent_skills.runtime_status 正确回写
- [ ] plugingen `mode: process` 生成 → 独立 `cjpm build` → 放置即生效（不重编宿主、不重启宿主）
- [ ] 全部代码仅依赖仓颉标准库（不依赖 `ohos.ark_interop` 等鸿蒙系统库）
- [ ] 存量 `src/app` 代码零改动（阶段一硬约束的直接验证，L3 轨同样适用——集成代码全部在 src/plugin/）

## 依赖

- 依赖 skill 工程的 SkillEngine（`src/skill/`：SkillRegistrationService / ProgressiveSkillLoader / SkillManager）
- 依赖 interaction 的事件基础设施（`src/interaction/events.cj` 事件模型、EventHandlerManager）
- 依赖 app 的路由设施（`src/app/registry/`：RouteRegistry / AutoRouteRegistry——只读复用，不修改存量行为）
- 依赖构建设施（`build.cj` pre-build 钩子、`src/scripts/package_release/`）
- **阶段四新增依赖**：cordis-cj（vendor 至 `apps/cordis-cj`，MIT）——`ystyle::cordis_host`（宿主侧）/ `ystyle::cordis_plugin`（插件侧 SDK）+ 中心仓依赖 `ystyle::jsonrpc` 0.7.0 / `ystyle::jsonrpc_stdio` 0.7.0 / `ystyle::jsonrpc_unix` 0.7.0（Windows 需剥离验证）/ `tomlcj` 1.0.0 / `jsonvalue` 1.1.0；选型决策矩阵与风险清单见可行性报告附7.14.6/附7.14.7
- 前置研究报告：`docs/ref/cangjie-plugin-system-feasibility.md`（含附7.8/附7.9 决策、附7.14 cordis-cj 调研）、`docs/ref/cordis-vs-npm-plugin.md`
- 路线图：`ROADMAP.md`（v0.5 生产就绪、v1.0 插件市场基础设施、v1.1 插件市场上线）
