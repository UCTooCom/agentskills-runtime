# 插件系统 - 技术设计文档

> 版本：v4.2（2026-09-03 复核修订：①新增 §0.6 L3 进程隔离轨实际落地——codelabs 插件完整 V4 CRUD 已实现并测试通过；②新增 §0.7 插件轻量化方案——三个可行优化方向（插件安装到宿主目录/插件 SDK 精简包/WASM 沙箱插件）及推荐实施路径；③host.db 服务实际契约（query/count/execute + `$raw:` 前缀约定）记录到正文；④回收站筛选实际机制（`filter` 查询参数动态构建 WHERE 子句）记录到正文。）
> 版本：v4.0（2026-08-24 fountain/agentskills-runtime 基础设施深度复用修订）
> v4.0 核心变更：①将第三章 14 项优化方案**融入第二章设计本体**，消除"设计正文 vs 优化附录"割裂；②修正 HTTP 类型迁移错误——plugin-spi **不依赖 http_lib**（可编译备份验证：dynamic→dynamic 依赖触发 `ld.lld: error: _CGP15http_lib.bufferiiHv was replaced` 符号重复）；③ServiceRegistry/PluginEventBus/PluginDylibLoader 实现方式从"自建"改为"委托/包装 fountain"；④插件发现从"手动反射扫描"改为"BeanFactory.annotationMap + lookupList<Plugin>()"。
> v3.x 历史见 git log（v3.1 runtime 自有基础设施复核、v3.0 fountain 深度复用、v2.3 反射基础设施+类型安全轨、v2.2 SkillBridge/SyncBridge 复核）
> 上游：spec.md v2；决策依据：可行性报告附7.4（路由）、附7.5（打包）、附7.8（目录归属）、附7.9（存量冻结）、附7.11（方案B 独立预编译）

> **v4.1 实际落地修订（2026-08-28）**：阶段一/二编码全部完成并编译通过，但落地过程中原设计多项方案因架构/框架/仓颉语言限制未能完全对标 deepseek-harness"一切皆插件"理念。本修订将实际实现方案同步到设计正文，并集中说明限制条件。关键差异见下方"§0 实际落地与限制说明"。

## §0 实际落地与限制说明（v4.1 新增，2026-08-28）

本节集中记录编码落地后与原设计的差异，以及因当前架构、fountain 框架、仓颉编程语言方面的原因未能完全对标 deepseek-harness（Cordis）"一切皆插件"理念的限制条件。

### §0.1 实际实现方案摘要

| 组件 | 原设计 | 实际实现 | 落地文件 |
|------|--------|----------|----------|
| 插件加载形态 | 方案三 build-sync（`src/generated/skill-plugins/{name}/`）→ 方案二独立 cjpm 包 | **宿主内嵌轨**：`skills/{name}/scripts/cj/` 经 build-sync 同步到 `src/plugins/{name}/`，包名 `magic.plugins.{name}`，属宿主 magic 包 | build.cj stagePluginBuildSync、src/plugins/ |
| 反射锚点 | build-sync 自动生成 `src/plugins/generated_anchors.cj`，引用插件 Route/Plugin 类作为 L1 反射锚点防 LTO 剪除 | ✅ 落地一致；build-sync 解析 `skills/{name}/plugin.yaml` 的 entry/routes 自动生成 import + touch() 实例化 | src/plugins/generated_anchors.cj、build.cj syncGenerateAnchors |
| 插件路由注册 | @ModuleRoute 注解 + PluginRouteScanner 运行时反射注册 | ✅ 落地一致；entity/feedback 经 PluginRouteScanner 注册 EntityRoute/FeedbackRoute | src/plugin/plugin_route_scanner.cj |
| 双轨路由 | 存量轨（AutoRouteConfig.cj）+ 插件轨（PluginRouteScanner）双轨并存 | ⚠️ **退化为单轨**：entity/feedback 路由实际由宿主内嵌轨的 PluginRouteScanner 注册，与 AutoRouteConfig 存量轨并行，但 plugingen 生成的新插件仍需经 build-sync 同步进宿主编译图，未实现"不重编宿主装上新插件" | src/app/registry/AutoRouteConfig.cj、src/plugin/plugin_route_scanner.cj |
| ServiceRegistry | 委托 fountain BeanFactory（getFirst\<T\>/getList\<T\>） | ✅ 落地一致；ServiceRegistry.register 委托 BeanFactory.register，getService\<T\> 委托 BeanFactory.getFirst\<T\> | src/plugin/bean_factory_service_registry.cj |
| PluginEventBus | 包装 fountain EventBus（Worker 线程池 + JobQueue） | ⚠️ **部分落地**：PluginEventBus 自建订阅表 + 优先级 + waterfall，未包装 fountain EventBus（f_concurrent 不在当前依赖中） | src/plugin/plugin_event_bus.cj（实际文件名见 src/plugin/） |
| PluginDylibLoader | 复用 fountain f_app/App.run() 动态库加载管线 | ✅ 落地一致；plugin_dylib_loader.cj 实现 L2 动态库加载原型 | src/plugin/plugin_dylib_loader.cj |
| plugingen | 与 crudgen 同构的插件生成工具 | ✅ 落地一致；plugingen 表驱动模式产出三维一体目录 | src/plugin/tools/plugingen/ |
| pluginuninstall | 与 plugingen 对称的卸载工具 | ✅ 落地一致；pluginuninstall 实现运行时停用 + 静态资产清理 | src/plugin/tools/pluginuninstall/ |
| PluginSyncBridge | 订阅 EventBus 生命周期事件，回写 agent_skills.runtime_status | ✅ 落地一致；PluginSyncBridge 单向回写，plugin.yaml 不被数据库侧覆盖 | src/plugin/plugin_sync_bridge.cj |

### §0.2 因架构/框架/仓颉语言限制未能完全对标 deepseek-harness 的限制条件

#### 限制 #1：插件无法真正"独立"——cjpm workspace 与 [package] 互斥（架构限制）

**原设计**：方案二（阶段三升格）让 `skills/{name}/` 升格为独立 cjpm 包，根 cjpm.toml 追加 `[workspace] members = ["./skills/entity", ...]`，插件以动态库形态独立编译。

**实际限制**：cjpm 规定同一个 `cjpm.toml` 中 `[workspace]` 和 `[package]` **不能共存**。宿主 `cjpm.toml` 既有 `[package]`（name="magic"）又要加 `[workspace]`，编译报错 `only one of 'workspace' or 'package' fields can exist`。fountain fdemo 先例证实：workspace 根 `cjpm.toml` 只有 `[workspace]` 段，没有 `[package]` 段——但我们的宿主本身就是 `magic` 包，不能既是 workspace 根又是 package。

**实际落地方案**：放弃 workspace 成员模式，改用**宿主内嵌轨**——插件源码经 build-sync 同步到 `src/plugins/{name}/`，包名 `magic.plugins.{name}`，属宿主 magic 包编译图。entity/feedback 的 `cjpm.toml`（name="skill_entity"/"skill_feedback"，output-type="dynamic"）保留为独立编译入口，但宿主编译时不引用它们。

**与 DSH 的差距**：DSH 的插件是运行时 fiber，天然独立于宿主进程；agentskills-runtime 的插件是编译期静态资产，必须进入宿主编译图才能被反射发现，无法实现"不重编宿主装上新插件"的完整形态。阶段三 PS-T012 L2 动态库加载原型部分缓解此限制（PackageInfo.load 热加载），但插件仍需预编译为动态库。

#### 限制 #2：插件深度依赖宿主子包——独立包模式产生循环依赖（架构限制）

**原设计**：插件包只依赖 `plugin-spi`，不 import 宿主 magic 包（cjpm 依赖单向性）。

**实际限制**：entity 插件源码深度依赖宿主子包：`magic.app.core.http.*`、`magic.app.core.query.*`、`magic.app.core.response.*`、`magic.app.core.router.Router`、`magic.app.utils.PermissionUtils`、`magic.log.LogUtils`。若 entity 升格为独立 cjpm 包（name="skill_entity"），它必须 import 这些宿主子包，但 cjpm 依赖单向——宿主不能依赖 entity（否则循环），entity 又必须依赖宿主 → 循环依赖无解。

**实际落地方案**：entity/feedback 保留对宿主 `magic` 包的依赖（CRUD 插件需要 `magic.app.core.*`、`magic.log.*` 等基础类型），通过宿主内嵌轨编译。独立包模式（skills/entity/cjpm.toml）仅在 L2 动态库预编译场景使用，此时插件动态库符号在运行时由 PackageInfo.load 解析，编译期不检查循环依赖。

**与 DSH 的差距**：DSH 的插件是纯函数 fiber，不依赖宿主内部实现；agentskills-runtime 的 CRUD 插件深度耦合宿主 HTTP/RBAC/日志设施，无法做到插件包"零宿主依赖"。

#### 限制 #3：仓颉反射 API 限制——ClassTypeInfo.get 跨包查询不稳定（语言限制）

**原设计**：PluginRouteScanner 通过 `ClassTypeInfo.get("magic.plugins.entity.EntityRoute")` 跨包反射发现插件路由类。

**实际限制**：仓颉反射 API 在 LTO（链接时优化）下会剪除未被静态引用的类，导致 `ClassTypeInfo.get` 返回 `None`。fountain BeanFactory.cj L52 注释警告：`调用isSubtypeOf会导致得不到类实现的直接接口，所以把isSubtypeOf放到if条件最后面`。此外 `TypeInfo`（fountain `TypeInfos.get()`）缺少 `constructors` 属性，必须保留 `ClassTypeInfo.get()` 才能获取构造器信息。

**实际落地方案**：build-sync 自动生成 `generated_anchors.cj`，显式 import 并实例化插件 Route/Plugin 类（`let _anchor_0 = EntityRoute()`），作为 L1 反射锚点防 LTO 剪除。PluginRouteScanner 仍用 `ClassTypeInfo.get` 反射发现，但依赖锚点保证类不被剪除。

**与 DSH 的差距**：DSH 的 `cordis_define` 是运行时动态定义，无编译期限制；agentskills-runtime 受静态语言 + LTO 限制，插件类必须显式锚定才能被反射发现。

#### 限制 #4：仓颉动态库标准库符号重复——--dy-std 编译选项必需（语言/工具链限制）

**原设计**：L2 动态库插件编译为 `.so`/`.dll`/`.dylib`，宿主通过 PackageInfo.load 热加载。

**实际限制**：仓颉动态库默认静态链接标准库，多个 `.so` 同时加载会重复包含标准库符号，触发 `ld.lld: error: _CGP15xxx was replaced` 符号冲突。必须为动态库编译添加 `--dy-std` 选项，使动态库使用动态链接的标准库。fountain fdemo cjpm.toml 先例证实：`compile-option = "-O2 --dy-std -Woff unused"` + `[target.x86_64-unknown-linux-gnu.bin-dependencies] path-option = ["${CANGJIE_STDX_DYNAMIC_PATH}"]`。

**实际落地方案**：entity/feedback 的 `cjpm.toml` 编译选项统一为 `compile-option = "-O2 --dy-std -Woff all"`。宿主内嵌轨编译不需要 `--dy-std`（静态链接），仅 L2 动态库预编译时需要。

**与 DSH 的差距**：DSH 是单一运行时进程，无动态库符号冲突问题；agentskills-runtime 受仓颉工具链限制，动态库插件必须显式处理标准库链接方式。

#### 限制 #5：插件包名必须为简单标识符——cjpm name 字段约束（工具链限制）

**原设计**：插件包名 `magic.plugins.{name}`（与框架包 `magic.plugin` 区分，复数形态）。

**实际限制**：cjpm `name` 字段必须是**简单标识符**（如 `plugin_spi`、`skill_entity`），不能是带点号的限定名（如 `magic.plugins.entity`）。fountain 32 个子包均遵循此规范（`f_orm`、`f_data` 等）。

**实际落地方案**：宿主内嵌轨插件包名仍用 `magic.plugins.{name}`（属宿主 magic 包的子包，cjpm 不单独编译）；独立包轨插件包名用 `skill_{name}`（如 `skill_entity`、`skill_feedback`），符合 cjpm 简单标识符规范。两轨包名不同但源码同构，通过 build-sync 同步保持一致。

**与 DSH 的差距**：DSH 无包名约束；agentskills-runtime 受 cjpm 工具链限制，插件包命名需区分内嵌轨/独立轨两套规范。

#### 限制 #6：HMR/合流性无定理背书——对外表述"确定性插件生命周期"（设计限制）

**原设计**：§2.10 与 Cordis 六语义对照中，HMR/合流性标注"工程近似，无定理背书"。

**实际限制**：静态编译语言无运行时 fiber 模型，无法实现 DSH 的响应式 inject、Proxy ctx、HMR、五种事件分发（emit/parallel/serial/bail/waterfall）。agentskills-runtime 以"注解声明 + 反射发现 + 生命周期状态机"覆盖 Cordis 六语义中的五个（Service/inject/effect/Events/检视），事件总线实现 emit/waterfall 两种最常用语义，仅 HMR 延后。

**实际落地方案**：不变量表中明确标注"HMR/合流性无定理背书，对外只表述确定性插件生命周期"。PluginEventBus 实现 emit/waterfall，未实现 parallel/serial/bail（f_concurrent EventBus 不在当前依赖中，且其语义是线程池任务执行器非发布订阅）。

**与 DSH 的差距**：DSH 是响应式 fiber 模型，HMR 原生支持；agentskills-runtime 受静态语言限制，HMR 需待 v1.1+ 增强形态（WASM 沙箱插件）才可能实现。

### §0.3 双轨并存的实际形态（v4.1 修订 §2.8）

原设计 §2.8 描述"双轨并存"：存量轨（AutoRouteConfig.cj 硬编码）+ 插件轨（PluginRouteScanner 运行时反射注册）。实际落地后双轨形态如下：

| 轨道 | 注册机制 | 服务的模块 | 编译图归属 | 维护态 |
|------|----------|------------|------------|--------|
| 存量轨 | `AutoRouteConfig.cj` 硬编码（crudgen 历史生成，实测约 1300 行） | src/app 存量模块（harness/框架核心/RBAC 等） | 宿主 magic 包 | **只减不增** |
| 插件轨（内嵌） | `@ModuleRouteAnnotation` + `PluginRouteScanner` 运行时反射注册 | 新插件（skills/{name}/，经 build-sync 同步到 src/plugins/） | 宿主 magic 包（子包 magic.plugins.{name}） | 增量唯一入口 |
| 插件轨（独立包） | L2 动态库加载：PackageInfo.load → 反射发现 @Plugin → PluginRouteScanner 注册 | L2 动态库插件（skills/{name}/，独立 cjpm 包 name="skill_{name}"） | 独立 cjpm 包（动态库 .so/.dll/.dylib） | 阶段三 L2 原型已验证 |
| 插件轨（进程，L3） | ExternalPluginRouteGateway 网关注册：路由代理经 JSON-RPC invoke 插件进程（v5.0 新增，阶段四） | L3 进程插件（独立可执行文件，`mode: process`） | **不进宿主编译图**（独立 cjpm executable 工程） | 已立项（spec REQ-PS-015） |

**关键约束**：内嵌轨插件必须进入宿主编译图（build-sync 同步 + generated_anchors.cj 反射锚点），无法"不重编宿主装上新插件"。独立包轨插件通过 L2 动态库加载实现"不重编宿主"，但需预编译为动态库且受 `--dy-std` 约束（限制 #4）。两轨通过 `plugins.yaml` 的 `mode: sync` / `mode: dylib` 配置切换。

### §0.4 build-sync 实际机制（v4.1 修订 §2.7 方案三）

build-sync 是阶段二插件进入宿主编译图的核心机制，实际落地后的完整流程如下：

1. **扫描阶段**：`build.cj` stagePluginBuildSync 扫描 `skills/*/plugin.yaml`，识别含 `scripts/cj/` 的插件
2. **同步阶段**：把 `skills/{name}/scripts/cj/*.cj` 复制到 `src/plugins/{name}/`（非 `src/generated/skill-plugins/{name}/`，目录调整见 v2.4）
3. **锚点生成**：解析 `skills/{name}/plugin.yaml` 的 entry/routes 类全名，自动生成 `src/plugins/generated_anchors.cj`：
   - import 插件 Route/Plugin 类（如 `import magic.plugins.entity.EntityRoute`）
   - touch() 方法显式实例化（`let _anchor_0 = EntityRoute()`）防 LTO 剪除
4. **依赖校验**：校验 plugin.yaml 的 dependencies 对应的 `skills/{dep}/` 目录存在
5. **gitignore**：`src/plugins/generated_anchors.cj` 是构建产物，不入库

**build-sync 的双轨兼容**：开发期保留 build-sync（增量编译快、IDE 跳转友好）；发布期用预编译动态库 + PackageInfo.load 热加载。`plugins.yaml` 新增 `mode: sync` / `mode: dylib` 配置切换两种加载机制。两套机制并存，不相互排斥。

**build-sync 的限制**：
- build-sync 要求插件源码包名与宿主内嵌轨一致（`magic.plugins.{name}`），与独立包轨包名（`skill_{name}`）不同，需手动维护两轨包名映射
- build-sync 生成的 `generated_anchors.cj` 引用插件类全名，若 plugin.yaml 的 entry/routes 字段与实际类名不符，编译报错 `can not find package`
- build-sync 不支持删除检测（PS-T020 待完成），插件卸载后 generated_anchors.cj 仍残留 import，需手动清理或等下次 build-sync 覆盖

### §0.5 L3 进程隔离轨对 §0.2 限制的消解（v5.0 新增，2026-08-28）

> 本节为 §0.2 六大限制条件给出阶段四（L3 进程隔离轨，cordis-cj 集成）的消解路径。完整调研见可行性报告附7.14，详细设计见本文第五章。

| §0.2 限制 | L3 轨消解方式 | 消解度 |
|---|---|---|
| #1 插件无法独立进化/发布 | 插件 = 独立可执行文件（cjpm executable），完全不进宿主编译图，第三方可闭源发布二进制 | 彻底消解 |
| #2 插件深度依赖宿主子包 | 插件进程仅依赖 `ystyle::cordis_plugin` SDK + `jsonvalue`，零 magic 包依赖；宿主能力经 RPC 服务代理（host.db/host.log/host.cache）访问 | 彻底消解 |
| #3 卸载依赖 dlclose 行为不确定 | 卸载 = 杀进程 + OS 级资源回收（内存/句柄/线程确定性回收），对齐 Cordis fiber.dispose 语义 | 彻底消解 |
| #4 动态库标准库符号重复（--dy-std） | 独立可执行文件静态链接标准库，无符号冲突问题（ADR-001 类问题不复现） | 彻底消解 |
| #5 反射 LTO 剪除需锚点 | 插件不经反射发现，路由由宿主网关（ExternalPluginRouteGateway）注册，无 generated_anchors.cj 依赖 | 彻底消解 |
| #6 HMR/合流性无定理背书 | 进程边界提供确定性故障隔离（崩溃自愈 reconcile 重拉）；但热替换语义仍非形式化验证，对外表述维持"确定性插件生命周期" | 大幅缓解 |

**三轨并存原则**：L3 轨为新增第三轨，不推翻内嵌轨（开发期增量编译便利）与 L2 轨（预编译动态库热加载）；`plugins.yaml` 的 `mode` 扩展三值 `sync` / `dylib` / `process`，缺省 `sync` 向后兼容。

### §0.6 L3 进程隔离轨实际落地（v4.2 新增，2026-09-03）

> 阶段四 L3 进程隔离轨（cordis-cj 集成）编码完成并测试通过。本节记录实际实现方案与设计文档的差异。

#### 实际实现组件清单

| 组件 | 落地文件 | 实际实现 |
|------|----------|----------|
| CordisHostManager | `src/plugin/cordis_host_manager.cj` | 包装 `ystyle::cordis_host` 的 PluginManager(stdio)/PluginHost/reconcile 循环；`installHostServicesHook` 在 `InstanceStatus.Active` 时触发 `CordisHostServices.registerFor` |
| ExternalPluginRouteGateway | `src/plugin/external_plugin_route_gateway.cj` | 为 process 插件注册 V4 路由；`serializeRequest` 从 `req.uri.query` 解析 `queryParams`，`parseBody(req)` 转发 POST 请求体；`userId`/`permissions` 从 `req.getLocals` 提取（String UUID） |
| CordisHostServices | `src/plugin/cordis_host_services.cj` | 宿主侧服务代理：`host.db`/`host.log`/`host.cache`；`executeDbOperation` 分发 query/execute/count；`buildRowLevelCondition` 基于 `creator` 字段（String UUID）的行级权限；`jsonValueToSqlLiteral` 支持 `$raw:` 前缀生成原始 SQL 函数 |
| codelabs 插件 | `skills/codelabs/` | 独立 cjpm executable 工程（`--dy-std -Woff all`），完整 V4 CRUD：list/get/add/edit/del/empty-recycle-bin，回收站筛选基于 `filter` 查询参数 |
| CrudPluginGenerator | `src/plugin/tools/plugingen/CrudPluginGenerator.cj` | 表驱动 CRUD 进程插件生成器：从数据库结构生成完整插件（plugin.yaml + cjpm.toml + main.cj + handlers.cj + effects.cj + README.md），对标 codelabs 参考实现 |

#### host.db 服务实际契约

| 操作 | subOp | 参数 | 返回 |
|------|-------|------|------|
| query | - | `table`, `where`, `orderBy`, `limit`, `offset`, `userId`, `permissions` | `{ "rows": [...] }` |
| count | - | `table`, `where`, `userId`, `permissions` | `{ "count": N }` |
| execute | insert/update/delete | `table`, `subOp`, `where`, `data`, `userId`, `permissions` | `{ "affected": N }` |

**`$raw:` 前缀约定**：`jsonValueToSqlLiteral` 对 `JsonValue.String` 检查 `$raw:` 前缀，去除前缀后作为原始 SQL 片段直接输出（不加引号）：
- `"$raw:CURRENT_TIMESTAMP"` → `CURRENT_TIMESTAMP`（SQL 函数，用于软删除 SET deleted_at=CURRENT_TIMESTAMP）
- `"$raw:gen_random_uuid()"` → `gen_random_uuid()`（SQL 函数，用于 id 生成）

#### 回收站筛选实际机制

Web 前端通过 `filter` 查询参数区分普通模式与回收站模式：
- 普通模式：`filter={"deleted_at":null}` → WHERE `deleted_at IS NULL`
- 回收站模式：`filter={"deleted_at":{"not":null}}` → WHERE `deleted_at IS NOT NULL`

`buildWhereFromFilter` 从 `queryParams.filter` 解析 URL 编码的 JSON，构建 WHERE 子句。`parseQueryParams(req.uri.query)` 从查询字符串（而非 path）解析参数。

#### 插件轻量化方向（v4.2 新增）

当前 L3 进程插件已实现完整 V4 CRUD 并测试通过，但插件发布包仍然较重——编译产物需要将宿主中的大量依赖（cordis-cj、jsonvalue、jsonrpc 等）复制到插件目录才能运行。后续优化方向见 §0.7。

### §0.7 插件轻量化方案（v4.2 新增，2026-09-03）

> 本节为插件系统成熟度提升方向，目标是使 L3 进程插件达到可商业化应用和推广的水平。

#### 当前问题：插件发布包过重

以 codelabs 插件为例，最终编译出的发布包需要将宿主中的大量依赖复制到插件中才能正常运行。这导致：
1. 插件包体积大（包含完整 cordis-cj 库、jsonvalue 库、jsonrpc 库等）
2. 依赖重复复制（每个插件都包含相同的基础库）
3. 版本管理复杂（插件依赖版本需与宿主一致）
4. 分发不便（插件包不能简单复制即用）

#### 可行优化方向

**方向一：插件安装到宿主目录（宿主共享依赖）**

插件安装时不将依赖复制到插件目录，而是将插件二进制复制到宿主中的合适位置运行。宿主提供共享依赖目录，所有插件共享同一份基础库。

实现要点：
1. 宿主启动时设置 `CANGJIE_STDX_DYNAMIC_PATH` 等环境变量指向宿主共享目录
2. 插件 cjpm.toml 的 `[target.*.bin-dependencies]` path-option 指向宿主共享目录（相对路径 `../../libs/...`）
3. 插件安装工具将插件二进制复制到 `plugins/{name}/` 目录，宿主通过 `plugins.yaml` 的 `command` 字段定位
4. 基础库（cordis-cj、jsonvalue、jsonrpc）由宿主统一管理，插件只包含业务逻辑代码

**方向二：插件 SDK 精简包**

将 `cordis-cj` 拆分为：
- `cordis-plugin-sdk`（精简 SDK，仅含 PluginRuntime/PluginContext/HostContext 等核心接口）
- `cordis-host`（完整宿主实现，仅宿主使用）

插件只依赖精简 SDK，体积大幅减小。SDK 可进一步静态链接基础库，生成单一静态库文件。

**方向三：WASM 沙箱插件（v1.1+ 增强形态）**

插件编译为 WASM 模块，宿主通过 WASM 运行时加载执行。WASM 模块天然轻量（仅含业务逻辑），基础库由宿主 WASM 运行时提供。

#### 推荐实施路径

1. **短期（v1.0）**：实施方向一（插件安装到宿主目录），最小改动达到轻量化目标
2. **中期（v1.1）**：实施方向二（插件 SDK 精简包），进一步减小插件体积
3. **长期（v1.2+）**：评估方向三（WASM 沙箱插件），实现极致轻量化

## 一、需求与存量功能关系分析

### 1.0 设计前提：存量冻结、增量插件化

`src/app` 存量模块（harness 与框架运行核心）不迁移、不重构；`AutoRouteConfig.cj` 只减不增。本设计的全部新增组件位于 `src/plugin/`（框架包 `magic.plugin`）与 `src/examples/plugins/`（示例），不动存量文件一行代码。新插件代码的家在项目根 `skills/{name}/`，经构建同步进入编译（见 §2.7）。

### 1.1 需求功能与存量功能对比

#### 1.1.1 已实现功能（可复用，只读）

| 需求功能 | 存量功能 | 代码位置 | 匹配度 |
|---------|---------|---------|--------|
| 事件分发 | InteractionEvent 事件模型 + EventHandlerManager | src/interaction/events.cj、event_handler_manager.cj | 70% |
| 技能注册 | SkillRegistrationService | src/skill/api/skill_registration_service.cj | 80% |
| 技能加载 | ProgressiveSkillLoader / EnhancedProgressiveSkillLoader | src/skill/application/progressive_skill_loader.cj | 75% |
| 技能管理 | SkillManager 接口（core 层） | src/core/skill/skill_manager.cj | 85% |
| 技能目录加载注册 | SkillManagementService（loadSkillsFromDirectory + registerSkill） | src/skill/application/skill_management_service.cj | 90% |
| 记忆插件（L0 先例） | MemoryProvider 接口 + BuiltinProvider/PostgresProvider | src/interaction/memory_provider.cj、memory_providers.cj | 60% |
| 自定义注解先例 | @AutoRoute 注解（@Annotation + const init） | src/app/core/annotations/AutoRoute.cj | 90% |
| 路由注册设施 | RouteRegistry（priority 排序 + registerFunc 回调）+ AutoRouteRegistry | src/app/registry/ | 85% |
| 显式注册模式先例 | AutoRouteRegistry + RouteRegistry | src/app/registry/AutoRouteRegistry.cj | 85% |
| 配置系统 | EnvWrapper + Config（.env 加载） | src/config/config.cj | 50% |
| YAML 解析 | yaml4cj.yaml.decode + YamlUtils | libs/yaml4cj、magic.skill.infrastructure.utils | 90% |
| 沙箱执行 | SandboxExecutor / PermissionService | src/security/sandbox_executor.cj | 40% |
| 构建钩子 | build.cj（pre-build 下载 stdx / post-build 调 package_release） | build.cj | 70% |
| 打包发布 | package_release（递归扫描 target/release/magic/） | src/scripts/package_release/main.cj | 80% |
| **反射基础设施（fountain）** | f_base.TypeInfos（类型缓存+双检锁）/ TypeMemberInfos（成员级反射缓存，含继承链+函数签名索引） | libs/fountain/f_base/src/TypeInfos.cj、TypeMemberInfos.cj | 95% |
| **IOC 容器（fountain）** | f_bean.BeanFactory（TypeInfo 多级索引+getFirst\<T\> 泛型查找）/ BeanManager（PostConstruct/Destroy 生命周期） | libs/fountain/f_bean/src/BeanFactory.cj、BeanManager.cj | 85% |
| **L2 动态加载先例（fountain）** | f_app.App.run()：递归扫描+PackageInfo.load(去扩展名)+try-catch 优雅降级+反射引导 | libs/fountain/f_app/src/App.cj L116-171 | 90% |
| **事件总线（fountain）** | f_concurrent/eventbus/EventBus（多 Worker 线程池+JobQueue+背压策略+任务窃取） | libs/fountain/f_concurrent/src/eventbus/EventBus.cj | 80% |
| **AOP 框架（fountain）** | f_aspect/Aspects（从 BeanFactory 加载所有 Aspect 实现并缓存代理函数链） | libs/fountain/f_aspect/src/Aspects.cj | 75% |
| **调度引擎（runtime 自有）** | SchedulerEngine（f_ticktock 之上的生产级调度：7 个可插拔执行器+失败重试+Misfire 补偿+执行日志持久化+AsyncLogWriter+优雅关闭） | src/app/services/crontab/ | 85% |
| **中间件链（runtime 自有）** | MiddlewareChain（CORS → DeserializeUser → RequirePermission → RowLevel → OperateLog） | src/app/core/middleware/ | 80% |
| **实时事件桥（runtime 自有）** | WebSocketEventBridge（单例，监听 14 种 Agent 事件，序列化为 JSON 推送）+ SSEEventBridge | src/app/services/bridge/ | 70% |
| **同步引擎（runtime 自有）** | SyncManager（完整双向同步引擎：AgentSkillSyncHandler+ChangeDetector+DataMapper+sync_status 五态） | src/app/services/sync/ | 75% |
| **模型管理（runtime 自有）** | ModelManager（16 个 AI 模型 Provider，通过 {PROVIDER}_API_KEY/BASE_URL 环境变量配置） | src/model/model_manager.cj | 70% |
| **缓存管理（runtime 自有）** | CacheManager（基于 Redis 的单例缓存管理器，getInstance/get/set/delete） | src/app/core/cache/CacheManager.cj | 65% |

#### 1.1.2 需要扩展的功能

| 需求功能 | 存量功能 | 差异说明 | 扩展方向 |
|---------|---------|---------|---------|
| 插件事件总线 | EventHandlerManager 仅按事件类型注册回调 | 无插件生命周期联动（卸载自动清理订阅）、无 waterfall 链式分发 | 新增 PluginEventBus：**包装 fountain EventBus**（多 Worker 并发+背压+任务窃取），上层接口契约不变（subscribe/emit/waterfall/unsubscribeAll），订阅与插件生命周期绑定 |
| 插件技能注册 | SkillManagementService 面向技能目录加载注册（loadSkillsFromDirectory） | 面向技能根目录的全量扫描，无"插件目录=特殊技能目录"的按插件调用入口 | 新增 SkillBridge 包装 SkillManagementService，实现按插件目录的技能加载与注册 |
| 插件配置 | Config 基于 .env 环境变量 | 无 YAML 插件清单解析 | 新增 PluginConfigParser 解析 plugins.yaml（复用 yaml4cj） |
| 插件路由注册 | AutoRouteConfig.cj 硬编码集中注册（crudgen 生成维护，实测约 1300 行） | 每新增模块须追加 import + 注册条目，编译期静态绑定 | 新增 @ModuleRoute 注解 + PluginRouteScanner 运行时反射注册，双轨并存 |
| 运行时动态加载 | 无封装 | std.reflect 的 PackageInfo.load 未使用 | 新增 PluginDylibLoader：**直接复用 fountain f_app/App.run() 动态库加载管线**（Directory.walk + 正则匹配 + PackageInfo.load(去扩展名)） |
| 插件服务注册 | 无（自建 ServiceRegistry） | 自建注册表无类型安全、无生命周期管理 | ServiceRegistry **委托 fountain BeanFactory**：register→BeanFactory.register，getService\<T\>→BeanFactory.getFirst\<T\>，复用 IOC 容器的类型安全+并发控制+生命周期管理 |
| 插件发现机制 | 无（自建 PluginRegistry 手动反射扫描） | 手动 ClassTypeInfo.get + findAnnotation 逐插件扫描 | 插件发现**走 BeanFactory.annotationMap**：@Plugin 注解类自动进入 annotationMap，PluginLoader 通过 lookupList<Plugin>() 批量发现 |
| 插件定时任务 | f_ticktock（单一闭包 executor，无重试/Misfire/持久化） | 原生 f_ticktock 缺生产级能力 | 插件定时任务**复用宿主 SchedulerEngine**（7 个可插拔执行器+失败重试+Misfire 补偿+执行日志持久化+AsyncLogWriter+优雅关闭） |

#### 1.1.3 需要新增的功能或接口

1. **Plugin 接口 + PluginContext**：插件抽象与生命周期载体
2. **@Plugin 注解（PluginAnnotation）**：插件声明（name/version/dependencies）
3. **PluginRegistry**：注册表（幂等 + 快照回滚）
4. **PluginLoader**：反射发现与实例化
5. **PluginEventBus**：插件协作事件总线（包装 fountain EventBus）
6. **PluginConfigParser**：plugins.yaml 解析
7. **PluginManager**：总控（生命周期编排 + 启动接入）
8. **SkillBridge**：插件技能自动注册（神经系统衔接）
9. **PluginAgentTools**：三个 Agent 自引用工具
10. **ModuleRouteAnnotation + PluginRouteScanner**：插件路由注解与运行时注册（双轨并存）
11. **PluginBuildSync**：build.cj 插件同步钩子（skills/ → src/generated/）
12. **PluginDylibLoader**：L2 动态库加载（阶段三，复用 fountain App.run() 管线）
13. **ServiceRegistry**：插件服务注册表（委托 fountain BeanFactory）
14. **示例插件**：2 个示例（验证 L1 + 技能融合 + 插件路由）

### 1.2 存量功能详细分析

**EventHandlerManager**（src/interaction/event_handler_manager.cj）：
- **接口契约**: 按 InteractionEvent 类型注册/触发事件处理器，返回处理结果
- **业务规则**: 事件处理器按类型注册，触发时按注册顺序执行；支持事件响应（EventResponse）
- **扩展点**: 事件类型体系（EventKind）可直接复用；缺插件维度的订阅清理和 waterfall 链式
- **约束**: 与插件生命周期无绑定关系。PluginEventBus **包装 fountain EventBus 独立实现**（自带订阅表，不直调 EventHandlerManager），事件类型命名与 EventKind 语义对齐，为 v1.0 后融合留接口

**SkillManagementService**（src/skill/application/skill_management_service.cj）：
- **接口契约**: `loadSkillFromPath(path): Option<Skill>`（含 manifest 解析→校验→Skill 实例创建完整管线）、`loadSkillsFromDirectory(dir): Array<Skill>`（目录批量加载）、`registerSkill(skill, skillManager): Bool`（注册到 SkillManager，内含异常处理）
- **业务规则**: 目录加载内部复用 SkillLoadingService（SkillMdLoader 解析 SKILL.md YAML frontmatter）与 SkillValidationService
- **扩展点**: 插件技能的完整加载注册管线——SkillBridge 按插件目录调用 loadSkillsFromDirectory + 逐个 registerSkill 即可，无需自建 manifest→Skill 转换
- **约束**: 面向技能根目录设计，无按插件名过滤/关联的语义，由 SkillBridge 包装补齐

**fountain BeanFactory**（libs/fountain/f_bean/src/BeanFactory.cj）：
- **接口契约**: `instance` 全局单例；`getFirst<T>()`/`getList<T>()` 类型安全查找（带 primary/order 排序）；`register<T>(meta, creator)` 动态注册（singleton/prototype 双作用域）；`annotationMap: HashMap<TypeInfo, TreeSet<RegisteredBean>>` 按注解索引
- **业务规则**: IOC 容器，自动管理 Bean 生命周期（PostConstruct/Destroy）、配置注入（@Value 宏）
- **扩展点**: ServiceRegistry **委托 BeanFactory 作为后端引擎**——register 委托 BeanFactory.register，getService\<T\> 委托 BeanFactory.getFirst\<T\>，复用 IOC 容器的类型安全+并发控制+生命周期管理
- **约束**: BeanFactory 是全局单例，插件与宿主共享同一容器。需约定命名规范（如 `plugin.{name}.{serviceName}` 前缀隔离）

**fountain EventBus**（libs/fountain/f_concurrent/src/eventbus/EventBus.cj）：
- **接口契约**: `register(event, ability)` 注册事件处理器；`arrange(event)` 分发事件；`retireAll()` 优雅停止
- **业务规则**: 多 Worker 线程池 + JobQueue 异步事件处理，内置背压策略（Block/Abort/DiscardOldest/...）、任务窃取（seize）、EndEvent 终止信号
- **扩展点**: PluginEventBus **包装 fountain EventBus**——subscribe 委托 EventBus.register，emit 委托 EventBus.arrange，从同步单线程升级为多 Worker 并发+背压的生产级实现
- **约束**: fountain EventBus 的事件分发是**异步**的（Worker 线程池），而 PluginEventBus 的 emit/waterfall 是**同步**的（直接调用 handler）。包装时需保留同步语义（currentThread 策略）或提供同步模式

**fountain f_app/App.run()**（libs/fountain/f_app/src/App.cj L116-171）：
- **接口契约**: `load(path, pattern)` 递归扫描目录+正则匹配动态库+PackageInfo.load(去扩展名路径) 加载；加载后反射引导各模块初始化（BeanFactory.afterRegistered/MVCStarter.initialize/ORM.initialize）
- **业务规则**: 生产级动态库加载管线，处理跨平台扩展名映射、路径转换、加载状态管理
- **扩展点**: PluginDylibLoader **直接复用这套管线**——仅需修改两个差异点：①去掉 walk，改为遍历 plugins.yaml 清单精确加载；②加载后按 @PluginAnnotation 注解发现（lookupList<Plugin>()）而非硬编码类名引导
- **约束**: `PackageInfo.load` 要求动态库文件名与包名严格一致（仓颉官方文档约束）。插件独立 cjpm 包的 `name = "skill_{name}"` 编译产物为 `libskill_{name}.so`，加载时传入 `"skill_{name}"`（去扩展名去掉 `lib` 前缀）即可

## 二、增量设计方案

### 2.1 实现模型

#### 2.1.1 上下文视图

```plantuml
@startuml
rectangle "agentskills-runtime 插件系统（新增，src/plugin/）" {
    rectangle "PluginManager\n(插件总控)" as PM
    rectangle "PluginRegistry\n(注册表)" as PR
    rectangle "PluginLoader\n(反射加载 L1)" as PL
    rectangle "PluginEventBus\n(事件总线,包装fountain)" as PEB
    rectangle "ServiceRegistry\n(委托BeanFactory)" as SR
    rectangle "SkillBridge\n(技能桥)" as SB
    rectangle "PluginRouteScanner\n(插件路由注册)" as PRS
    rectangle "PluginAgentTools\n(Agent工具)" as PAT
    rectangle "PluginDylibLoader\n(L2动态库,复用f_app)" as PDL
}
rectangle "fountain 基础设施（深度复用）" {
    rectangle "BeanFactory\n(IOC容器)" as BF
    rectangle "EventBus\n(多Worker并发)" as FEB
    rectangle "App.run()\n(动态库加载管线)" as APP
    rectangle "TypeInfos\n(反射缓存)" as TI
}
rectangle "存量设施（只读复用，零改动）" {
    rectangle "SkillManagementService" as SMS
    rectangle "EventHandlerManager" as EHM
    rectangle "RouteRegistry / AutoRouteConfig" as RR
    rectangle "SchedulerEngine" as SE
    rectangle "MiddlewareChain" as MC
    rectangle "Config" as CFG
}
rectangle "外部" {
    rectangle "plugins.yaml" as YAML
    rectangle "Agent (LLM)" as AGENT
    rectangle "skills/{name}/\n(SKILL.md+scripts/cj+plugin.yaml)" as PDIR
    rectangle "src/generated/skill-plugins/\n(build-sync 产物)" as GEN
}

PM --> PR : 注册/查询/快照
PM --> PL : 发现/实例化
PM --> PEB : 分发事件
PM --> SB : 注册插件技能
PM --> CFG : 读取配置
PL --> YAML : 按清单加载
SB --> SMS : 按插件目录加载并注册技能
PEB ..> FEB : 包装(fountain EventBus)
SR ..> BF : 委托(fountain BeanFactory)
PDL ..> APP : 复用加载管线
PL ..> TI : 反射缓存(TypeInfos.get)
PEB ..> EHM : EventKind 语义对齐(独立实现,不直调)
PRS --> RR : 追加注册(双轨汇合)
PRS --> PL : 反射实例化Route/Controller
PAT --> AGENT : 自引用工具
PDIR --> GEN : build.cj pre-build 同步
GEN --> PL : @Plugin 类(编译期已链接)
PDIR --> SB : SKILL.md
@enduml
@enduml
```

#### 2.1.2 服务/组件总体架构（三合一容器：神经系统）

```plantuml
@startuml
package "plugin-system (magic.plugin)" {
    component [PluginManager\n(总控)] as PM
    component [PluginRegistry\n(注册表)] as PR
    component [PluginLoader\n(反射加载)] as PL
    component [PluginEventBus\n(事件总线,包装fountain)] as PEB
    component [PluginConfigParser\n(配置解析)] as PCP
    component [SkillBridge\n(技能桥)] as SB
    component [PluginRouteScanner\n(路由注册)] as PRS
    component [PluginAgentTools\n(Agent工具)] as PAT
    component [PluginDylibLoader\n(L2动态库,复用f_app)] as PDL
}
package "fountain 基础设施（深度复用）" {
    component [BeanFactory\n(IOC容器,ServiceRegistry后端)] as BF
    component [EventBus\n(多Worker并发,PluginEventBus包装)] as FEB
    component [App.run()\n(动态库加载管线,PluginDylibLoader复用)] as APP
    component [TypeInfos\n(反射缓存,PluginLoader复用)] as TI
}
package "PluginContext (每插件一个)" {
    component [ServiceRegistry\n确定性能力,委托BeanFactory] as SR
    component [EventBus 订阅句柄] as EBH
    component [SkillBridge 句柄] as SBH
    component [config 参数] as CFG2
}
package "现有基础设施 (只读)" {
    component [SkillManagementService] as SMS
    component [EventHandlerManager] as EHM
    component [RouteRegistry] as RR
    component [SchedulerEngine] as SE
    component [MiddlewareChain] as MC
}

PM --> PCP : 解析plugins.yaml
PM --> PL : 按清单加载插件
PL --> PR : 注册插件实例
PL --> PEB : 绑定插件事件订阅
PM --> SB : 触发插件技能注册
SB --> SMS : 按插件目录加载并注册技能
PEB ..> FEB : 包装(fountain EventBus)
SR ..> BF : 委托(fountain BeanFactory)
PDL ..> APP : 复用加载管线
PL ..> TI : 反射缓存(TypeInfos.get)
PEB ..> EHM : EventKind 语义对齐(独立实现,不直调)
PRS --> RR : 插件路由追加注册
PAT --> PM : inspect/activate/deactivate
PDL --> PR : L2动态库注册
@enduml
@enduml
```

插件 = Service（确定性能力）+ Skill（AI 行为）。PluginContext 是三合一容器的句柄：ServiceRegistry（血管骨骼，委托 BeanFactory）、EventBus（神经信号，包装 fountain EventBus）、SkillBridge（神经系统入口）。

#### 2.1.3 插件加载流程（启动时，fountain 基础设施复用版）

```plantuml
@startuml
start
:PluginManager.loadAll();
:PluginConfigParser 解析 plugins.yaml\n(复用 yaml4cj);
:读取启用的插件清单(含依赖顺序);

repeat
    :获取下一个插件定义;
    :检查是否已注册(幂等);
    if (已注册?) then (是)
        :跳过(返回已存在实例);
    else (否)
        :PluginLoader 反射发现插件类;
        :TypeInfos.get(插件类全名)\n(复用 fountain f_base.TypeInfos 缓存);
        :findAnnotation<PluginAnnotation> 校验声明;
        :ConstructorInfo.apply 实例化\n(try/catch 包装反射异常);
        :校验依赖插件已注册(逗号拆分后);
        if (依赖缺失?) then (是)
            :进入 ERROR 态;
            :注册表快照回滚;
            :记录错误日志(不阻塞其他插件);
            stop
        else (否)
            :调用 onLoad(context);
            :注册到 PluginRegistry;
            :注册到 BeanFactory\n(plugin.{name}.{serviceName} 前缀隔离);
            :绑定事件订阅(PluginEventBus);
        endif
    endif
repeat while (还有未加载插件?) is (是)
-> 否

:触发全部插件的 onActivate(按依赖顺序);
:SkillBridge 扫描插件目录SKILL.md并注册;
:PluginRouteScanner 扫描插件路由并追加注册\n(在 AutoRouteRegistry 存量注册之后);
stop
@enduml
@enduml
```

**加载流程与 fountain 的衔接点**：
1. **TypeInfos.get 替换 ClassTypeInfo.get**：PluginLoader 中所有反射类型查找走 `f_base.TypeInfos.get(qualifiedName)`（ConcurrentHashMap+双检锁缓存），避免重复反射开销。fountain 实测（f_bean/BeanFactory 启动时 100+ 次 ClassTypeInfo.get）表明 TypeInfos 缓存可显著降低反射开销
2. **ServiceRegistry 委托 BeanFactory**：插件注册的服务通过 ServiceRegistry.register 委托 BeanFactory.register，复用 IOC 容器的类型安全+并发控制+生命周期管理。命名规范：`plugin.{name}.{serviceName}` 前缀隔离
3. **PluginEventBus 包装 fountain EventBus**：subscribe 委托 EventBus.register，emit 委托 EventBus.arrange，从同步单线程升级为多 Worker 并发+背压的生产级实现
4. **L2 动态库加载复用 App.run() 管线**：PluginDylibLoader 直接复用 fountain 的 Directory.walk + 正则匹配 + PackageInfo.load(去扩展名) 加载逻辑

#### 2.1.4 生命周期状态机

```plantuml
@startuml
state "PENDING" as P
state "LOADING" as L
state "ACTIVE" as A
state "ERROR" as E
state "DISPOSED" as D

[*] --> P : 插件定义被发现
P --> L : PluginLoader 开始加载
L --> A : 依赖校验通过 + onLoad + onActivate
L --> E : 依赖缺失/注解非法/实例化失败
A --> E : 运行时异常(可重试)
A --> D : deactivate(逆序清理) + onUnload
E --> D : dispose(回收)
E --> L : 重新加载(依赖修复后)
A --> A : 重激活(无需重新加载)

note right of A
  ACTIVE 态插件：
  - 服务已注册到 BeanFactory
  - 事件订阅已绑定到 PluginEventBus
  - SKILL.md 已注册到 SkillManager
  - 路由已追加到 RouteRegistry
end note

note right of E
  ERROR 态边界约定（§2.1.4 触发条件表）：
  仅生命周期钩子异常（onLoad/onActivate）与依赖关系破坏触发 ERROR；
  事件回调与 Service 调用的业务异常不触发状态迁移（由日志观测）。
end note
@enduml
@enduml
```

**生命周期钩子异常约定**：

| 钩子 | 异常处理 | 状态迁移 |
|------|---------|---------|
| onLoad | 捕获异常，记 ERROR 日志 | Loading → Error |
| onActivate | 捕获异常，记 ERROR 日志 | Loading → Error |
| onDeactivate | 捕获异常，记日志，清理栈仍逆序执行 | Active → Disposed |
| onUnload | 捕获异常，记日志，清理栈仍逆序执行 | Active → Disposed |
| 事件回调 | 捕获异常，记 ERROR 日志 | 不迁移状态 |
| Service 调用 | 捕获异常，记 ERROR 日志 | 不迁移状态 |

#### 2.1.5 ERROR 态触发条件表

| 触发条件 | 来源 | 处理方式 |
|---------|------|---------|
| 依赖插件缺失 | PluginLoader.checkDependencies | 进入 ERROR 态，注册表快照回滚，记错误日志，不阻塞其他插件加载 |
| 注解字段非法（缺失/不一致） | PluginLoader.findAnnotation | 进入 ERROR 态，记错误日志 |
| 反射实例化失败 | ConstructorInfo.apply | 进入 ERROR 态，记错误日志 |
| onLoad 钩子抛异常 | Plugin.onLoad | 进入 ERROR 态，记错误日志 |
| onActivate 钩子抛异常 | Plugin.onActivate | 进入 ERROR 态，记错误日志 |
| 事件回调抛异常 | PluginEventBus.emit/waterfall | 捕获记 ERROR 日志，不影响其他订阅者，不触发状态迁移 |
| Service 调用抛异常 | ServiceRegistry.getService | 捕获记 ERROR 日志，不触发状态迁移 |

### 2.2 接口设计

#### 2.2.1 总体设计

| 接口分类 | 接口名称 | 稳定性 | 阶段 | 说明 |
|---------|---------|--------|------|------|
| 框架核心 | Plugin 接口 | 稳定 | 一 | 插件生命周期契约 |
| 框架核心 | PluginContext | 稳定 | 一 | 插件运行时上下文（三合一容器句柄） |
| 框架核心 | @Plugin 注解 | 稳定 | 一 | 插件声明（name/version/dependencies） |
| 框架核心 | PluginRegistry | 稳定 | 一 | 注册表（幂等 + 快照回滚） |
| 框架核心 | PluginLoader | 稳定 | 一 | 反射发现与实例化（复用 fountain TypeInfos 缓存） |
| 框架核心 | PluginManager | 稳定 | 一 | 总控与启动入口 |
| 协作 | PluginEventBus | 稳定 | 一 | 事件分发（emit/waterfall，**包装 fountain EventBus**） |
| 协作 | ServiceRegistry | 稳定 | 一 | 插件服务注册表（**委托 fountain BeanFactory**） |
| 配置 | PluginConfigParser | 稳定 | 一 | plugins.yaml 解析 |
| 路由 | ModuleRouteAnnotation | 稳定 | 一 | 插件路由声明注解 |
| 路由 | PluginRouteScanner | 稳定 | 一 | 运行时反射注册插件路由 |
| 协作 | SkillBridge | 实验 | 一 | 插件技能注册桥（包装 SkillManagementService） |
| Agent 工具 | PluginAgentTools | 实验 | 二 | inspect/activate/deactivate |
| 构建 | PluginBuildSync | 实验 | 二 | skills/ → src/generated/ 同步钩子 |
| 扩展 | PluginDylibLoader | 实验 | 三 | L2 动态库加载（**复用 fountain f_app/App.run() 管线**） |
| 扩展 | plugin-spi 基础包 | 稳定 | 三 | 插件面向的稳定 API（libs/plugin-spi） |

#### 2.2.2 接口清单

**Plugin 接口**：

```cangjie
public interface Plugin {
    func getName(): String
    func onLoad(context: PluginContext): Unit
    func onActivate(): Unit
    func onDeactivate(): Unit
    func onUnload(): Unit
}
```

**PluginContext**：

```cangjie
public class PluginContext {
    public let pluginName: String
    public let serviceRegistry: ServiceRegistry
    public let eventBus: PluginEventBus
    public let skillBridge: SkillBridge
    public let config: JsonValue   // 来自 plugins.yaml 的插件参数

    public init(
        pluginName: String,
        serviceRegistry: ServiceRegistry,
        eventBus: PluginEventBus,
        skillBridge: SkillBridge,
        config: JsonValue
    )

    // 确定性能力注册（ServiceRegistry 转发，委托 BeanFactory）
    public func registerService(name: String, service: Any): Bool
    public func getService(name: String): Option<Any>

    // v2.3 新增：类型安全服务获取（参考 f_bean.BeanFactory.getFirst<T> 模式）
    public func getService<T>(): Option<T>

    // 可逆清理栈（cordis effect/disposer 语义，逆序执行）
    public func onCleanup(f: () -> Unit): Unit
}
```

**ServiceRegistry（委托 fountain BeanFactory，优化方案 3.2）**：

```cangjie
public class ServiceRegistry {
    // 委托给 fountain IOC 容器（BeanFactory 全局单例）
    private let beanFactory: BeanFactory
    private let pluginName: String

    public init(beanFactory: BeanFactory, pluginName: String) {
        this.beanFactory = beanFactory
        this.pluginName = pluginName
    }

    // 字符串名轨 → 注册为命名 Bean（plugin.{name}.{serviceName} 前缀隔离）
    public func registerService(name: String, service: Any): Bool {
        let fullName = "plugin.${pluginName}.${name}"
        beanFactory.registerByName(fullName, service)
        true
    }

    // 类型安全轨 → 直接委托 getFirst<T>（一步到位，无需自建 HashMap<TypeInfo,...>）
    public func getService<T>(): Option<T> {
        beanFactory.getFirst<T>()
    }

    public func getService(name: String): Option<Any> {
        beanFactory.get(name)
    }

    public func listServices(): Array<String> {
        beanFactory.getAllBeanNames()
    }
}
```

**服务命名契约（v2.2 补充，v2.3 升级为类型安全双轨，v4.0 委托 BeanFactory）**：ServiceRegistry 提供两轨服务获取：

1. **类型安全轨（推荐，v2.3）**：`getService<T>()` 泛型接口——**委托 BeanFactory.getFirst<T>()**，一步到位，无需自建 HashMap<TypeInfo,...>。消除 Any 承载的类型安全损失
2. **字符串名轨（兼容保留）**：注册名 = `plugin.{pluginName}.{serviceName}`（前缀隔离，避免与宿主服务命名冲突），消费方按接口类型检查后转换
3. **实现类必须实现注册名对应的接口**；实现方在开发期自查，运行期框架不强校验
4. 跨插件服务获取应与 @Plugin.dependencies 声明一致；获取未声明依赖的服务记 WARN 日志
5. **v4.0 委托实现（替代 v1 后评估的"演进方向"）**：ServiceRegistry 的内部实现直接委托给 fountain BeanFactory——register 委托 BeanFactory.register，getService\<T\> 委托 BeanFactory.getFirst\<T\>，复用 IOC 容器的类型安全+并发控制+生命周期管理。plugin-spi 无需依赖 fountain（接口层纯净），实现层在宿主 magic.plugin 中引入 fountain 依赖

**@Plugin 注解**：

```cangjie
@Annotation
public class PluginAnnotation {
    /// 插件名（全局唯一，注册表键）
    public let name: String
    /// 语义化版本
    public let version: String
    /// 依赖的插件名列表（逗号分隔字符串，如 "memory-builtin,tool-http"）
    /// 仓颉 const 表达式不支持 Array 类型字面量（官方文档明确"不能是 Array 类型，
    /// 可以使用 VArray 类型"，而 VArray 长度固定不适用），故注解字段用 String 承载，
    /// PluginLoader 加载时按逗号拆分为 Array<String> 再做依赖校验
    public let dependencies: String

    public const init(
        name: String,
        version: String,
        dependencies: String
    )
}
```

**注解使用语法**（类名即注解名，无 `@Plugin` 简写形式）：

```cangjie
@PluginAnnotation[
    name: "memory-postgres",
    version: "1.0.0",
    dependencies: "memory-builtin"
]
public class MemoryPostgresPlugin <: Plugin { ... }
```

**@ModuleRoute 注解（插件路由声明）**：

```cangjie
@Annotation
public class ModuleRouteAnnotation {
    /// 路由前缀，如 "/api/v1/uctoo/entity"
    public let basePath: String
    /// 数据库表名
    public let table: String
    /// 数据库名，如 "uctoo"
    public let database: String
    /// 控制器全限定类名（反射实例化用）
    public let controllerClass: String

    public const init(
        basePath: String,
        table: String,
        database: String,
        controllerClass: String
    )
}
```

**PluginRoute 接口（插件路由统一接口）**：

```cangjie
public interface PluginRoute {
    /// 注册该插件模块的全部路由（只追加，不修改存量注册）
    func register(router: Any, controller: Any): Unit
}
```

**PluginEventBus（包装 fountain EventBus，优化方案 3.3）**：

```cangjie
public class PluginEventBus {
    // 包装 fountain EventBus（多 Worker 线程池+JobQueue+背压策略）
    private let bus: EventBus
    // 保留插件级订阅追踪（卸载时批量清理）
    private let pluginSubscriptions: HashMap<String, ArrayList<Subscription>>

    public init() {
        bus = EventBus()
        pluginSubscriptions = HashMap<String, ArrayList<Subscription>>()
    }

    public func subscribe(pluginName: String, eventType: String,
                          handler: (JsonValue) -> JsonValue,
                          priority!: Int32 = 0): Bool {
        let sub = Subscription(eventType, handler, priority)
        if (let Some(list) <- pluginSubscriptions.get(pluginName)) {
            list.add(sub)
        } else {
            pluginSubscriptions.put(pluginName, ArrayList<Subscription>([sub]))
        }
        bus.register(eventType, handler)  // 委托给 fountain EventBus
        true
    }

    public func emit(eventType: String, payload: JsonValue): ArrayList<JsonValue> {
        bus.post(eventType, payload)      // fountain EventBus 原生分发
        // 收集结果...
    }

    public func unsubscribeAll(pluginName: String): Unit {
        if (let Some(list) <- pluginSubscriptions.get(pluginName)) {
            for (sub in list) {
                bus.unregister(sub.eventType, sub.handler)
            }
            pluginSubscriptions.remove(pluginName)
        }
    }
}
```

**PluginDylibLoader（复用 fountain f_app/App.run() 管线，优化方案 3.4）**：

```cangjie
public class PluginDylibLoader {
    private let registry: PluginRegistry
    private let beanFactory: BeanFactory
    // 追踪已加载的动态库路径（卸载时 dlclose 用）
    private let loadedLibs: HashMap<String, String>

    public init(registry!: PluginRegistry, beanFactory!: BeanFactory) {
        this.registry = registry
        this.beanFactory = beanFactory
        this.loadedLibs = HashMap<String, String>()
    }

    public func loadFromDylib(pluginName: String, libPath: String): Result<Plugin, PluginError> {
        // Step 1: 加载动态库（复用 fountain 的去扩展名 + PackageInfo.load 模式）
        let libFile = libPath.replace(".so", "").replace(".dll", "").replace(".dylib", "")
        PackageInfo.load(libFile)  // 仓颉标准库，fountain 已验证跨平台可用

        // Step 2: 触发 Bean 扫描（复用 fountain 的 afterRegistered 机制）
        beanFactory.afterRegistered()

        // Step 3: 通过 lookupList 发现 @Plugin 注解的类
        let plugins = beanFactory.lookupList<Plugin>()
        for (p in plugins) {
            if (p.getName() == pluginName) {
                loadedLibs.put(pluginName, libPath)
                return Result.Success(p)
            }
        }
        return Result.Failure(PluginError.NotFound(pluginName))
    }

    public func unloadDylib(pluginName: String): Bool {
        loadedLibs.remove(pluginName)  // dlclose 由仓颉 GC 自动管理
        true
    }
}
```

**反射实现注意事项（fountain 实战经验，v2.3）**：

1. **isSubtypeOf 调用顺序警告**：fountain f_bean/BeanFactory.cj 注释明确"反射 BUG：调用 isSubtypeOf 会导致得不到类实现的直接接口，所以把 isSubtypeOf 放到 if 条件最后面"。PluginLoader/PluginRouteScanner 中若需 isSubtypeOf，必须放在条件表达式最后位置
2. **TypeInfos.get 替换 ClassTypeInfo.get**：fountain f_base/TypeInfos 提供 `get(qualifiedName): TypeInfo`（ConcurrentHashMap+双检锁缓存），在 f_bean/BeanFactory 和 f_aspect/Aspects 等核心模块中生产级使用。PluginLoader 和 PluginRouteScanner 中所有 `ClassTypeInfo.get()` 调用替换为 `TypeInfos.get()`，避免重复反射开销
3. **@Value 宏配置注入**：fountain f_bean/@Value 宏支持环境变量→构造参数的类型安全注入（支持默认值、类型转换、分隔符）。插件类可直接用 `@Value` 宏替代从 PluginContext.config(JsonValue) 手动解析，实现类型安全的编译期注入

### 2.3 数据模型

插件系统为运行时内存结构，**不引入数据库表**（插件清单在 plugins.yaml / plugin.yaml，运行时状态在 PluginRegistry 内存中）。这是与 skill-evolution（需持久化统计）的刻意差异——插件注册表无跨进程持久化需求。

**运行时状态结构**：

```cangjie
public class PluginRuntimeInfo {
    public var plugin: Plugin                 // 插件实例
    public var state: PluginState             // 生命周期状态
    public var annotation: PluginAnnotation   // 注解声明（name/version/dependencies）
    public var loadedAt: Int64                // 加载时间戳
    public var subscribedEvents: ArrayList<String>  // 已订阅事件（卸载时清理）
    public var errorMessage: Option<String>   // ERROR 态错误信息
}
```

**与 agent_skills 表的关系（REQ-PS-013）**：

插件系统不新建表，但**读写一张既有表**——`agent_skills`（54 列，SkillEngine 双向同步的落库目标）。兼容性逐项核对：

| 插件机制信息 | agent_skills 现有字段 | 结论 |
|---|---|---|
| 插件名 / 版本 / 依赖 | name / version / dependencies（JSON 数组） | 已覆盖 |
| 安装路径 / 来源 | install_path / source_path / source / source_type | 已覆盖 |
| PluginState 五态 | runtime_status（varchar） | 已覆盖，直接回写 |
| scripts 目录存在性 | scripts_dir_exists（插件为 scripts/cj/，同一 scripts/ 前缀） | 已覆盖 |
| plugin.yaml entry 类全名 | extra_metadata（JSON） | 合并写入，无需加列 |
| plugin.yaml tables（使用的业务表） | extra_metadata（JSON） | 合并写入，无需加列 |
| 是否插件（过滤用） | 无专用列 | **不加列**（extra_metadata 带 plugin:true 标记）；市场阶段确有过滤需求再 ALTER TABLE 增量加 is_plugin |

**PluginSyncBridge 设计**（新增组件，位于 src/plugin/，不动存量 sync 代码）：

```cangjie
public class PluginSyncBridge {
    // 订阅 EventBus 的插件生命周期事件（PluginActivated/PluginDeactivated/PluginError/PluginUnloaded）
    public func bind(eventBus: PluginEventBus): Unit
    // 状态回写：PluginState → agent_skills.runtime_status（按 name 匹配行）
    public func writeRuntimeState(name: String, state: PluginState, errorMessage: Option<String>): Unit
    // 元数据合并：plugin.yaml 的 entry/tables 合并进 agent_skills.extra_metadata（读-改-写，保留其他键）
    public func mergePluginMetadata(name: String, manifest: PluginManifest): Unit
    // 红线：不提供任何"库 → plugin.yaml"的回写路径（单向桥）
}
```

回写失败（如数据库不可用）只记日志与 sync_status=error，**不影响插件运行**——同步是观测面，不是控制面。

### 2.4 plugins.yaml 配置格式（加载清单）

```yaml
# 插件加载清单：控制加载哪些插件、参数注入、加载顺序
plugins:
  - name: memory-postgres
    className: magic.plugins.memory.MemoryPostgresPlugin
    enabled: true
    order: 1
    config:
      connectionString: "postgres://user:pass@localhost:5432/uctoo"
      layer: "episodic"

  - name: tool-http
    className: magic.plugins.tool.HttpToolPlugin
    enabled: true
    order: 2
    config:
      timeoutMs: 30000
      allowRedirects: true

  - name: entity
    className: magic.plugins.entity.EntityPlugin
    enabled: true
    routeClass: magic.plugins.entity.scripts.routes.EntityRoute
    config: {}
```

**解析规则**：
- `name`：插件名，注册表主键，必须与 `@Plugin(name)` 一致
- `className`：插件类全名（含包路径），`TypeInfos.get` 的入参
- `enabled`：false 则跳过加载（预留给插件市场的"安装但未启用"语义）
- `order`：显式加载顺序；未声明时按 `@Plugin.dependencies` 做拓扑排序
- `routeClass`：可选，插件 Route 类全名，PluginRouteScanner 据此注册路由（缺省则扫描 plugin.yaml 的 routes 声明）
- `config`：JsonValue 注入 `PluginContext.config`，插件内自行解析

### 2.5 plugin.yaml 插件清单格式（插件自描述，分发与同步用）

```yaml
# 每个插件目录一份，与 SKILL.md 同级
name: entity
version: 1.0.0
description: "entity 表 CRUD 技能插件"
entry: magic.plugins.entity.EntityPlugin       # 插件类全名（@Plugin 注解类）
dependencies: ""                                     # 依赖插件名（逗号分隔）
tables:                                              # 使用的数据库表（信息性，供市场/审计）
  - entity
skills:                                              # SKILL.md 相对路径（SkillBridge 扫描）
  - SKILL.md
routes:                                              # Route 类全名（PluginRouteScanner）
  - magic.plugins.entity.scripts.routes.EntityRoute
platform: all                                        # all | harmonyos（市场过滤用）
```

plugins.yaml（宿主加载清单）与 plugin.yaml（插件自描述）职责分离：前者是宿主的启用开关与参数注入，后者是插件的静态元数据。阶段二 build-sync 时 PluginBuildSync 读取 plugin.yaml 生成同步映射；阶段四市场安装时 plugin.yaml 是分发单元的清单。

### 2.6 框架与示例插件代码位置

```
src/
├── plugin/                      # 插件框架源码（magic.plugin 包，新建，不混入现有包）
│   ├── pkg.cj
│   ├── plugin.cj                # Plugin 接口
│   ├── plugin_context.cj        # PluginContext
│   ├── plugin_state.cj          # PluginState / PluginError
│   ├── plugin_registry.cj       # PluginRegistry（幂等 + 快照回滚）
│   ├── plugin_loader.cj         # PluginLoader（反射发现，复用 TypeInfos 缓存）
│   ├── plugin_manager.cj        # PluginManager（总控与启动入口）
│   ├── plugin_event_bus.cj      # PluginEventBus（包装 fountain EventBus）
│   ├── plugin_config_parser.cj  # PluginConfigParser（plugins.yaml 解析）
│   ├── plugin_route_scanner.cj  # PluginRouteScanner（运行时反射注册）
│   ├── skill_bridge.cj          # SkillBridge（包装 SkillManagementService）
│   ├── service_registry.cj      # ServiceRegistry（委托 fountain BeanFactory）
│   ├── plugin_sync_bridge.cj    # PluginSyncBridge（agent_skills 表状态回写）
│   ├── plugin_agent_tools.cj    # PluginAgentTools（inspect/activate/deactivate）
│   ├── plugin_dylib_loader.cj   # PluginDylibLoader（L2 动态库，复用 f_app/App.run()）
│   └── tools/
│       ├── plugingen/           # 插件生成工具（与 crudgen 对称）
│       └── pluginuninstall/     # 插件卸载工具（与 plugingen 对称）
├── examples/plugins/            # 示例插件（验证 L1 + 技能融合 + 插件路由）
│   ├── memory-postgres/
│   └── tool-http/
└── generated/skill-plugins/     # build-sync 产物（.gitignore，构建产物）
    └── {name}/                  # 从 skills/{name}/scripts/cj/ 复制
```

### 2.7 新插件目录结构与构建集成（阶段二核心）

新插件的标准物理目录（**家在项目根 skills/，与 20+ 现有技能资产同构**）：

```
skills/
└── entity/                   # 技能完整地在一个目录里（三维一体）
    ├── SKILL.md                 # AI 行为定义（SkillEngine 资产，不编译）
    ├── plugin.yaml              # 插件清单（见 §2.5）
    ├── templates/  assets/  references/   # 数据资产（不编译）
    └── scripts/
        └── cj/                  # 仓颉可编译代码（源路径）
            ├── pkg.cj           # 占位（包声明 magic.plugins.entity）
            ├── models/          # 五层 CRUD（或任意插件代码）
            │   └── pkg.cj
            ├── dao/
            ├── services/
            ├── controllers/
            ├── routes/
            └── EntityPlugin.cj   # @Plugin 注解的插件入口类
```

**方案三（阶段二）：build-sync 同步**。

`build.cj` pre-build 钩子（在现有"下载 stdx"步骤之后追加）：

1. 扫描 `skills/*/plugin.yaml`，识别含 `scripts/cj/` 的插件
2. 把 `skills/{name}/scripts/cj/` 复制到 `src/generated/skill-plugins/{name}/`
3. 自动生成各级 `pkg.cj` 占位与包声明映射（`magic.plugins.{name}` 及其子包）
4. 校验依赖目录存在（plugin.yaml 的 dependencies 对应的 skills/{dep}/ 目录）
5. `src/generated/` 加入 .gitignore（构建产物，不入库）

- 优点：无依赖方向问题（代码仍属 magic 包），SPI 不用抽取，改动最小，可先行落地
- 缺点：双路径（源路径 skills/ 与生成路径 src/generated/），IDE 跳转落到生成目录，开发者需理解同步机制
- 约束：cjpm 目录扫描规则要求每级目录含 `.cj` 文件——占位文件自动生成保证了这一点（项目已有 13 个 pkg.cj 占位的成熟先例）

**方案二（阶段三升格）：独立 cjpm 包**。

`skills/{name}/` 升格为独立包（自有 `cjpm.toml`，name = `skill_{name}`，output-type = `dynamic`，dependencies = `plugin_spi`）。**方案 B 决策（2026-08-24，见附7.11）：不修改根 cjpm.toml**——插件不进宿主 cjpm 依赖图，插件开发者在自己机器上 `cd skills/{name}/ && cjpm build` 预编译为动态库，宿主运行时通过 `PackageInfo.load()` 热加载，全程不修改根 cjpm.toml，不重启宿主进程。**硬前置是 libs/plugin-spi 抽取**：cjpm 依赖单向，插件包不能 import 根包 magic，Plugin 接口 / 注解 / Controller 基类 / EventBus 接口须先迁入 `libs/plugin-spi`，宿主与插件包都依赖它。反射发现（ClassTypeInfo.get 按包名跨包查类型）在链接后同样有效，PluginRouteScanner 方案不受影响。

**build-sync 双轨保留（方案 B 调整）**：开发期保留 build-sync（增量编译快、IDE 跳转友好）；发布期用预编译动态库 + `PackageInfo.load()` 热加载。`plugins.yaml` 新增 `mode: sync` / `mode: dylib` 配置切换两种加载机制。两套机制并存，不相互排斥。

| 阶段 | 方案 | 触发条件 |
|---|---|---|
| 阶段二 | 方案三（build-sync） | 首个真实新插件开发即启用 |
| 阶段三 | 方案二（独立包 + plugin-spi） | 首个 L2 动态库插件开发前（SPI 抽取成为必须） |

**目录红线（附7.8 教训）**：插件代码不得放进 `src/skill/`（SkillEngine 引擎包 magic.skill，会被污染）；不得在 src 树内另起"第二个技能之家"与根目录 skills/ 分裂。

### 2.8 双轨路由设计（存量冻结的配套）

| 轨道 | 注册机制 | 服务的模块 | 维护态 |
|---|---|---|---|
| 存量轨 | `AutoRouteConfig.cj` 硬编码（crudgen 历史生成，实测约 1300 行） | src/app 存量模块（harness/框架核心/RBAC 等） | **只减不增**（crudgen 停止追加，人工不再新增） |
| 插件轨 | `@ModuleRouteAnnotation` + `PluginRouteScanner` 运行时反射注册 | 新插件（skills/{name}/） | 增量唯一入口 |

- 两轨在 Router/RouteRegistry 汇合；HTTPServer 已有路由去重逻辑兜底冲突
- 注册顺序：存量轨先（main.cj 现有流程不动），插件轨后（PluginManager.loadAll 完成后由 PluginRouteScanner 追加）
- 存量模块演进决策规则：小修就地改（它是宿主的一部分）；功能重写或扩展以新插件叠加；L2 就绪后自然可迁

### 2.9 不变量保证

| 不变量 | 实现机制 |
|--------|---------|
| 幂等加载 | PluginRegistry.register 先查重，同名已存在直接返回既有实例，不执行 onLoad |
| 依赖前置 | PluginLoader.checkDependencies 在实例化前校验，缺失依赖 → ERROR 态并回滚快照 |
| 逆序清理 | 插件卸载按加载顺序的逆序执行 onDeactivate → onUnload；PluginContext 清理栈后注册先清理 |
| 快照回滚 | RegistrySnapshot 保存插件名+状态；加载失败 restore() 恢复 |
| 配置驱动 | 未在 plugins.yaml 启用的插件不加载（即使类存在） |
| 跨平台纯净 | 全部实现仅依赖仓颉标准库（std.reflect/std.collection/stdx.encoding.json），禁止引入 ohos.* 系统库 |
| 插件技能可发现 | 插件激活后 SKILL.md 必须注册成功才视为完整激活（否则记警告，插件以纯 Service 态运行） |
| **存量零改动** | 插件系统不修改 src/app 任何存量文件（含 crudgen/crudweb 与 sync 服务——插件生成走新建 plugingen，库同步走新建 PluginSyncBridge）；AutoRouteConfig 只减不增 |
| **路由无冲突** | 双轨注册依赖 HTTPServer 去重逻辑；PluginRouteScanner 只追加不修改存量注册 |
| **反射在冷路径** | 反射调用仅发生在启动加载/显式激活时；热路径（事件分发、路由响应）走编译期接口直调 |
| **plugin.yaml 单向保护** | PluginSyncBridge 只做内存→库回写，不提供库→plugin.yaml 路径；存量 syncToFileSystem 也只回写 SKILL.md |
| **同步是观测面非控制面** | PluginSyncBridge 回写失败只降级记日志（sync_status=error），绝不阻断插件生命周期 |
| **ERROR 态边界**（v2.2） | 仅生命周期钩子异常与依赖关系破坏触发 ERROR；事件回调/Service 业务异常不迁移状态 |
| **服务命名契约**（v2.2/v2.3/v4.0） | 推荐 getService\<T\>() 类型安全轨（**委托 BeanFactory.getFirst\<T\>**）；字符串名轨须用 `plugin.{name}.{serviceName}` 前缀隔离 |
| **反射有生产先例**（v2.3） | 插件系统所用反射 API（ClassTypeInfo.get/findAnnotation/ConstructorInfo.apply/PackageInfo.load）在 fountain 框架均有生产级使用先例；实现遵守 isSubtypeOf 调用顺序约束 |
| **plugin-spi 不依赖 http_lib**（v4.0） | HTTP 类型保留宿主侧，不迁入 plugin-spi（可编译备份验证：dynamic→dynamic 依赖触发 `ld.lld: error: _CGP15http_lib.bufferiiHv was replaced` 符号重复） |

### 2.10 与 Cordis 六语义的对照（设计自检）

| Cordis 语义 | 本设计落点 | 备注 |
|---|---|---|
| Service（服务定位） | ServiceRegistry 显式注册表（**委托 BeanFactory**） | 无 Proxy，类型安全更强 |
| inject（声明式依赖） | @Plugin.dependencies + 启动期校验 | 响应式重载留 v1.1 |
| effect/disposer（可逆卸载） | PluginContext.onCleanup 逆序清理栈 | dispose 加状态位防重入 |
| Events（事件分发） | PluginEventBus emit/waterfall（**包装 fountain EventBus**） | 编译期事件接口 + 运行时总线 |
| 运行时反射检视 | PluginRegistry.snapshot + plugin_inspect | "试运行后干净撤回"用快照回滚 |
| HMR/合流性 | 配置重载 + 幂等加载 | 工程近似，无定理背书，对外表述"确定性插件生命周期" |

### 2.11 插件卸载设计（阶段三，对应 spec REQ-PS-014）

> **设计动因**：阶段二删除 entitygen/feedbackgen 时全程手工（删目录、清 plugins.yaml、清 generated_anchors.cj、清 target 产物、清数据库痕迹），暴露了阶段二"只有运行时停用（plugin_deactivate）、无工程级卸载"的缺口。阶段三 L2 动态库加载让"不重编宿主装上新插件"成为可能后，对称地需要"不重编宿主卸载一个插件"——这要求卸载能力从"运行时停用 effect"升级为"运行时停用 + 静态资产清理 + 数据库痕迹清理"的完整生命周期闭环。

#### 2.11.1 卸载三层模型

卸载分为三层，按"运行时层 → 静态资产层 → 数据库痕迹层"顺序执行，任一层失败不阻断后续层（降级记日志，最终汇总到卸载报告）：

| 层 | 职责 | 关键动作 | 失败策略 |
|---|---|---|---|
| **运行时层** | 停用运行时实例，撤销所有运行时副作用 | `PluginManager.deactivate(name)` → onDeactivate → onUnload → 逆序执行 PluginContext.onCleanup 清理栈 → PluginRegistry.unregister → ServiceRegistry.removeByPlugin（委托 BeanFactory.remove） → PluginEventBus.unsubscribeAll（委托 fountain EventBus.unregister） → PluginRouteScanner.unregisterByPlugin。L2 形态额外执行 `PluginDylibLoader.unloadDylib`（dlclose） | 运行时停用失败 → 记 ERROR，继续静态资产层清理（避免僵尸文件残留） |
| **静态资产层** | 删除插件文件资产与构建产物 | 删除 `skills/{name}/` 源目录 → 删除 build-sync 同步产物 `src/generated/skill-plugins/{name}/` → 删除编译产物 `target/release/magic/libmagic.plugins.{name}.a` 及对应 `.cjo` → 从 `config/plugins.yaml` 加载清单移除该插件条目 → 从 `src/plugins/generated_anchors.cj` 反射锚点移除该插件的 import 与 entry 注册 | 文件删除失败（权限/占用）→ 记 WARNING，继续后续清理 |
| **数据库痕迹层** | 清理数据库中该插件的持久化痕迹 | 清理 `agent_skills` 表中该插件的记录（PluginSyncBridge 当前只做"内存→库回写"，卸载时需主动清理孤儿记录）→ 清理 `permissions` 表中该插件对应的菜单节点（plugingen 幂等插入的对称删除）→ 清理 `i18` 表中该插件对应的国际化键（同上对称删除） | 数据库清理失败 → 记 WARNING，不影响卸载完成判定（数据库孤儿记录可由后续维护任务清理） |

#### 2.11.2 卸载状态机

卸载在 PluginState 五态基础上增加 `UNINSTALLING` 中间态，状态流转如下：

```plantuml
@startuml
title 插件卸载状态机
[*] --> ACTIVE : 已激活
ACTIVE --> UNINSTALLING : pluginuninstall --name
UNINSTALLING --> DISPOSED : 三层清理完成
UNINSTALLING --> ERROR : 运行时层失败(静态资产层仍继续)
ERROR --> DISPOSED : 静态资产层+数据库层清理完成
DISPOSED --> [*] : 卸载报告输出
@enduml
@enduml
```

#### 2.11.3 逆向清理栈（对应 Cordis effect/disposer 可逆卸载语义）

卸载的运行时层核心是**逆向清理栈**，对应 Cordis 的 `fiber.dispose()` 按逆序执行 `_disposables` 栈中每个 disposer 的语义：

```cangjie
public class PluginContext {
    // 逆序清理栈：后注册的清理函数先执行（LIFO）
    private var cleanupStack: Array<(PluginContext) -> Unit>

    /// 插件注册清理函数（对应 Cordis ctx.effect(() => cleanupFn)）
    /// 插件在 onLoad/onActivate 中调用此方法注册自身需要清理的资源
    public func onCleanup(cleanupFn: (PluginContext) -> Unit): Unit {
        cleanupStack.add(cleanupFn)  // 仓颉 Array 用 add 追加
    }

    /// 卸载时按逆序执行清理栈（对应 Cordis fiber.dispose()）
    public func runCleanupInReverseOrder(): Unit {
        var i = cleanupStack.size - 1
        while (i >= 0) {
            try {
                cleanupStack[i].invoke(this)
            } catch (e: Exception) {
                // 单个清理函数失败不阻断后续清理
                // 记录错误日志，继续执行下一个
            }
            i = i - 1
        }
    }
}
```

#### 2.11.4 卸载工具 pluginuninstall

**PluginUninstaller**（与 plugingen 对称的确定性卸载工具，位于 `src/plugin/tools/pluginuninstall/`，属 magic.plugin.tools 包）：

```cangjie
public class PluginUninstaller {
    private let manager: PluginManager
    private let eventBus: PluginEventBus
    private let syncBridge: PluginSyncBridge
    private let buildSync: PluginBuildSync

    public init(
        manager!: PluginManager,
        eventBus!: PluginEventBus,
        syncBridge!: PluginSyncBridge,
        buildSync!: PluginBuildSync
    )

    /// 完整卸载插件（三层模型）
    public func uninstall(name: String, force!: Bool = false): UninstallReport
}

public class UninstallReport {
    public var pluginName: String
    public var success: Bool
    public var runtimeCleanup: CleanupResult       // 运行时层清理结果
    public var staticAssetCleanup: CleanupResult    // 静态资产层清理结果
    public var databaseCleanup: CleanupResult       // 数据库痕迹层清理结果
    public var errors: ArrayList<String>            // 各层失败汇总
    public var duration: Int64                      // 卸载总耗时(ms)
}

public class CleanupResult {
    public var layer: String          // "runtime" | "static_asset" | "database"
    public var success: Bool
    public var itemsCleaned: ArrayList<String>  // 清理的文件/配置/数据库记录列表
    public var itemsFailed: ArrayList<String>   // 清理失败的项目列表
}
```

## 三、阶段三 fountain/agentskills-runtime 基础设施深度复用优化方案（v4.0 融入版）

> 修订日期：2026-08-24
> 修订依据：fountain 框架 (libs/fountain/, 630 个 .cj 文件, 32 个子包) 深度研究报告 + agentskills-runtime 自有基础设施复核
> 核心原则：**优先复用 fountain 已验证的生产级基础设施，而非从零重复开发**。fountain 已在 28 处生产场景中使用 std.reflect，经受过跨平台（Linux/Windows/macOS/OpenHarmony）验证。

### 3.1 复用总览——fountain/agentskills-runtime 能力 → 插件系统组件的映射

```
fountain/agentskills-runtime 基础设施    →  插件系统组件               复用程度
─────────────────────────────────────────────────────────────────────────────────────
f_bean/BeanFactory (IOC 容器)            →  ServiceRegistry 实现后端   完全复用（作为后端引擎）
f_bean/BeanManager (生命周期)            →  Plugin 生命周期管理        模式复用（PostConstruct→onActivate 映射）
f_bean/@Bean + annotationMap             →  @Plugin 注解自动发现        机制复用（注解索引代替手动扫描）
f_bean/@Value 宏 (配置注入)              →  PluginContext.config       模式复用（类型安全的编译期注入）
f_app/App.run() (动态库加载)             →  PluginDylibLoader          代码复用（99% 逻辑一致）
f_concurrent/EventBus (事件总线)         →  PluginEventBus 实现        包装复用（内置 worker/priority/JobQueue）
f_aspect/Aspects (AOP 框架)              →  插件横切关注点             直接复用（日志/监控/权限拦截）
f_config/Config (配置管理)               →  PluginConfigParser 辅助    模式复用（零文件配置理念）
f_base/TypeInfos (类型缓存)              →  PluginLoader 反射缓存      直接复用（已有双检锁缓存）
SchedulerEngine (runtime 自有调度)        →  插件定时任务               直接复用（7 执行器+持久化+重试+Misfire+安全防护）
MiddlewareChain (runtime 自有中间件)      →  插件中间件                 直接复用（CORS→DeserializeUser→RequirePermission→RowLevel→OperateLog）
WebSocketEventBridge (runtime 自有桥)     →  插件接入实时事件流         直接复用（监听 14 种 Agent 事件）
SyncManager (runtime 自有同步)            →  插件数据同步               直接复用（AgentSkillSyncHandler+ChangeDetector+DataMapper+sync_status 五态）
ModelManager (runtime 自有模型)           →  插件注册自定义 AI Provider  直接复用（16 个现有 Provider 体系扩展）
CacheManager (runtime 自有缓存)           →  插件缓存                   直接复用（基于 Redis 的单例缓存管理器）
SandboxExecutor (runtime 自有沙箱)        →  插件沙箱执行               直接复用（WASM 沙箱隔离+PermissionService）
```

### 3.2 优化方案一：ServiceRegistry 委托 BeanFactory（影响 PS-T017、设计 §2.2.2）

**现状**：ServiceRegistry 自建独立的 `HashMap<String, Any>` 注册表，类型安全轨走 `HashMap<TypeInfo, ...>` 自建索引。

**fountain 已有**：`BeanFactory` 是一个完整、成熟的 IOC 容器，支持：
- `getFirst<T>()` / `getList<T>()` 类型安全查找（带 primary/order 排序）
- `beanTypeMap: HashMap<TypeInfo, TreeSet<RegisteredBean>>` 多级类型索引
- `annotationMap: HashMap<TypeInfo, TreeSet<RegisteredBean>>` 按注解索引
- `register<T>(meta, creator)` 动态注册（singleton/prototype 双作用域）
- `PostConstruct` 接口（构造后回调）与 `Destroy` 接口（销毁回调）
- `@Value` 宏配置注入（环境变量→构造参数，支持默认值、类型转换、分隔符）

**优化方案**：将 ServiceRegistry 的"演进方向"提升为**阶段三的默认实现方案**。不是另起一个注册表后再桥接，而是**直接让 ServiceRegistry 的内部实现委托给 BeanFactory**：

```cangjie
// 优化后的 ServiceRegistry 实现
public class ServiceRegistry {
    private let beanFactory: BeanFactory  // 委托给 fountain IOC 容器
    private let pluginName: String

    public init(beanFactory: BeanFactory, pluginName: String) {
        this.beanFactory = beanFactory
        this.pluginName = pluginName
    }

    // 字符串名轨 → 注册为命名 Bean（兼容既有契约）
    public func registerService(name: String, service: Any): Bool {
        beanFactory.registerByName("plugin.${pluginName}.${name}", service)
        true
    }

    // 类型安全轨 → 直接委托 getFirst<T>（一步到位，无需自建 HashMap<TypeInfo,...>）
    public func getService<T>(): Option<T> {
        beanFactory.getFirst<T>()
    }

    public func getService(name: String): Option<Any> {
        beanFactory.get(name)
    }

    public func listServices(): Array<String> {
        beanFactory.getAllBeanNames()
    }
}
```

**收益**：

| 维度 | 自建注册表（当前设计） | 委托 BeanFactory（优化方案） |
|------|----------------------|---------------------------|
| 代码量 | 需自建 TypeInfo 索引、模式匹配转换、并发安全 | ~20 行委托代码，零数据竞争防御（BeanFactory 内部已用 ConcurrentHashMap） |
| 生命周期 | 需手动管理 singleton/prototype | BeanFactory 自带 BeanScope 管理 |
| 配置注入 | 插件从 PluginContext.config(JsonValue) 手动解析 | 插件类可直接用 `@Value` 宏，环境变量自动注入构造参数 |
| 销毁回调 | 依赖插件在 onCleanup 手动注册 | `Destroy` 接口自动注册 atExit 回调 |
| 宿主消费 | 需跨两条 IOC 体系桥接 | 宿主代码直接 `lookup<T>()` 消费，无需桥接层 |
| 跨插件发现 | 无法发现其他插件注册的服务 | `lookupList<T>()` 全局发现所有实现 |

**影响范围**：PS-T017 子任务2（迁入 plugin-spi 的稳定 API）中，ServiceRegistry 契约保持不变，但实现从"自建注册表"变为"委托 BeanFactory"。plugin-spi 无需依赖 fountain（接口层纯净），实现层在宿主 magic.plugin 中引入 fountain 依赖。

**风险与缓解**：BeanFactory 是全局单例，插件与宿主共享同一容器。插件服务与宿主服务在同一命名空间，需约定命名规范（如 `plugin.{name}.{serviceName}` 前缀隔离）。备选方案：为插件创建子 BeanFactory 实例（需 fountain 支持，当前不支持——若不需要可接受全局共享）。

---

### 3.3 优化方案二：PluginEventBus 包装 fountain EventBus（影响 PS-T005、设计 §2.2.2）

**现状**：PluginEventBus 完全独立实现，自带 HashMap 订阅表、优先级排序、emit/waterfall/unsubscribeAll。设计决策为"不直调 EventHandlerManager，独立实现 + EventKind 语义对齐"。

**fountain 已有**：`f_concurrent/eventbus/` 包含完整的事件总线实现：
- `EventBus`：发布订阅核心，支持按事件类型分发
- `Worker` + `JobQueue`：异步工作队列，天然支持并发事件处理
- `EndEvent`：结束事件信号
- 已在 630+ 个 .cj 文件的 fountain 生态中实战验证

**优化方案**：PluginEventBus 的实现层包装 fountain EventBus，上层接口契约不变（subscribe/emit/waterfall/unsubscribeAll 签名保持稳定）：

```cangjie
// 优化后的 PluginEventBus 实现（包装 fountain EventBus）
public class PluginEventBus {
    private let bus: EventBus                     // fountain 事件总线
    private let pluginSubscriptions: HashMap<String, ArrayList<Subscription>>
    // 保留插件级订阅追踪（卸载时批量清理）

    public init() {
        bus = EventBus()
        pluginSubscriptions = HashMap<String, ArrayList<Subscription>>()
    }

    public func subscribe(pluginName: String, eventType: String,
                          handler: (JsonValue) -> JsonValue,
                          priority!: Int32 = 0): Bool {
        let sub = Subscription(eventType, handler, priority)
        if (let Some(list) <- pluginSubscriptions.get(pluginName)) {
            list.add(sub)
        } else {
            pluginSubscriptions.put(pluginName, ArrayList<Subscription>([sub]))
        }
        bus.register(eventType, handler)  // 委托给 fountain EventBus
        true
    }

    public func emit(eventType: String, payload: JsonValue): ArrayList<JsonValue> {
        bus.post(eventType, payload)      // fountain EventBus 原生分发
        // 收集结果...
    }

    public func unsubscribeAll(pluginName: String): Unit {
        if (let Some(list) <- pluginSubscriptions.get(pluginName)) {
            for (sub in list) {
                bus.unregister(sub.eventType, sub.handler)
            }
            pluginSubscriptions.remove(pluginName)
        }
    }
}
```

**收益**：
- fountain EventBus 自带 Worker 线程池 + JobQueue，天然支持异步事件处理（当前设计是同步执行）
- 无需自建优先级排序逻辑（fountain EventBus 已有）
- 减少约 150 行事件总线核心代码

**注意事项**：需确认 fountain EventBus 的事件类型匹配——当前以 `String` 为事件类型标识，与 PluginEventBus 的 `eventType: String` 一致。如果 fountain EventBus 使用类型化事件（泛型 Event<T>），需做一层适配。

---

### 3.4 优化方案三：PluginDylibLoader 直接复用 fountain App.run() 的动态库加载管线（影响 PS-T012、设计 §2.2.2）

**现状**：design.md §2.2.2 中 PluginDylibLoader 的接口设计只留了 `loadFromDylib()` / `unloadDylib()` 两个方法签名。注释中引用了 fountain 的参考实现，但未给出具体复用方式。

**fountain 已有**：`f_app/App.cj` L116-171 有一套完整的、生产级动态库加载管线：

```cangjie
// fountain f_app/App.cj 核心加载逻辑（简化）
func load(path: String, dylibPattern: Regex<RE>): Unit {
    for (f in Directory.walk(path)) {                      // 1. 递归扫描目录
        let ext = fi.path.extension                        // 2. 获取扩展名
        if (dylibPattern.match(fi.path.name)) {            // 3. 正则匹配动态库
            let libPath = fi.path.replace(ext, "")         // 4. 去扩展名
            PackageInfo.load(libPath)                       // 5. 运行时加载
        }
    }
    // 6. 反射引导各模块初始化
    ClassTypeInfo.get("fountain.bean.BeanFactory").getStaticFunction("instance")...
    // → afterRegistered() → 触发 Bean 扫描
}
```

**优化方案**：PluginDylibLoader 直接复用这套管线，仅需修改两个差异点：

| fountain App.run() | PluginDylibLoader | 差异处理 |
|---|---|---|
| 全目录扫描（`Directory.walk`） | 按 plugins.yaml 清单精确加载 | 去掉 walk，改为遍历 PluginList.plugins |
| 加载后硬编码类名引导（BeanFactory/MVCStarter） | 加载后按 @PluginAnnotation 注解发现 | 加载完成后调用 `lookupList<Plugin>()` 扫描所有 @Plugin 实现 |
| 正则匹配文件名 | 按包名推断动态库文件名（`libskill_{name}.so`） | 用仓颉 `PackageInfo.load` 命名规则推断路径 |

```cangjie
// 优化后的 PluginDylibLoader（直接复用 fountain 加载模式）
public class PluginDylibLoader {
    private let registry: PluginRegistry
    private let beanFactory: BeanFactory
    // 追踪已加载的动态库路径（卸载时 dlclose 用）
    private let loadedLibs: HashMap<String, String>

    public init(registry!: PluginRegistry, beanFactory!: BeanFactory) {
        this.registry = registry
        this.beanFactory = beanFactory
        this.loadedLibs = HashMap<String, String>()
    }

    public func loadFromDylib(pluginName: String, libPath: String): Result<Plugin, PluginError> {
        // Step 1: 加载动态库（复用 fountain 的去扩展名 + PackageInfo.load 模式）
        let libFile = libPath.replace(".so", "").replace(".dll", "").replace(".dylib", "")
        PackageInfo.load(libFile)  // 仓颉标准库，fountain 已验证跨平台可用

        // Step 2: 触发 Bean 扫描（复用 fountain 的 afterRegistered 机制）
        beanFactory.afterRegistered()

        // Step 3: 通过 lookupList 发现 @Plugin 注解的类（无需 ClassTypeInfo.get + findAnnotation）
        let plugins = beanFactory.lookupList<Plugin>()
        for (p in plugins) {
            if (p.getName() == pluginName) {
                loadedLibs.put(pluginName, libPath)
                return Result.Success(p)
            }
        }
        return Result.Failure(PluginError.NotFound(pluginName))
    }

    public func unloadDylib(pluginName: String): Bool {
        loadedLibs.remove(pluginName)  // dlclose 由仓颉 GC 自动管理
        true
    }
}
```

**收益**：
- 无需从零开发动态库扫描、加载、跨平台路径处理等底层逻辑
- fountain 已在 Windows/Linux/macOS/OpenHarmony 四平台上验证 `PackageInfo.load` 行为
- `beanFactory.afterRegistered()` 后自动触发 @Bean/@Plugin 注解扫描，省去手动 ClassTypeInfo.get + findAnnotation 循环

**注意事项**：`PackageInfo.load` 要求动态库文件名与包名严格一致（仓颉官方文档约束）。插件独立 cjpm 包的 `name = "skill_{name}"` 编译产物为 `libskill_{name}.so`，加载时传入 `"skill_{name}"`（去扩展名去掉 `lib` 前缀）即可。

---

### 3.5 优化方案四：@Plugin 注解发现走 BeanFactory.annotationMap（影响 PS-T003、设计 §2.1.3 加载流程）

**现状**：PluginLoader 的 `load()` 方法走 `ClassTypeInfo.get(qualifiedName) → findAnnotation<PluginAnnotation>() → ConstructorInfo.apply(args)` 三步手动反射。每加载一个插件需一次 ClassTypeInfo.get 调用。

**fountain 已有**：`@Bean` 宏在编译期为被注解的类生成静态注册代码，启动时自动注册到 `BeanFactory.annotationMap`（`HashMap<TypeInfo, TreeSet<RegisteredBean>>`）。这个机制支持：
- 按注解类型高效索引（O(1) 查找所有 @Bean 类）
- 支持 `primary`/`order` 排序
- 支持 `lazy` 懒加载

**优化方案**：为 `@PluginAnnotation` 同步生成 @Bean 注册代码（或让 @PluginAnnotation 继承 @Bean 的注册机制），使得插件类自动进入 BeanFactory 的 annotationMap。PluginLoader 的加载流程从"三步手动反射"简化为"从 BeanFactory 按 @PluginAnnotation 类型索引取插件"：

```
优化前：PluginLoader.load(className) 
  → ClassTypeInfo.get(className)        // 反射查类型
  → findAnnotation<PluginAnnotation>()  // 反射查注解
  → ConstructorInfo.apply(args)         // 反射实例化
  → 返回 Plugin

优化后：PluginLoader.load(pluginName)
  → beanFactory.getByAnnotation<PluginAnnotation>(pluginName)  // O(1) 索引查找
  → 返回 Plugin（已由 BeanFactory 管理生命周期）
```

**收益**：
- 启动时无需遍历 plugins.yaml 逐一手动反射加载——所有 @Plugin 类在动态库加载后自动进入 annotationMap
- BeanFactory 已内置 singleton/prototype 管理，插件实例生命周期交给成熟容器
- 减少 PluginLoader 中约 50 行反射代码

**实现方式**：有两种可选路径：
1. **轻量方案**：在 PluginLoader 中调用 `beanFactory.lookupByAnnotation<PluginAnnotation>()` 批量获取所有插件类，按 plugins.yaml 的 enabled 过滤
2. **深度方案**：修改 @PluginAnnotation 宏（或新建配套宏），编译期生成与 @Bean 相同的静态注册代码，使 PluginAnnotation 成为 BeanMeta 的一个子类型

推荐先走轻量方案（改动最小），阶段四再评估深度方案。

---

### 3.6 优化方案五（修订）：插件定时任务复用宿主的 SchedulerEngine（而非原生 f_ticktock）

**现状**：当前设计未涉及插件定时任务能力。原 3.6 初版建议直接复用 fountain `f_ticktock`，但经深度研究发现 agentskills-runtime 已在 `f_ticktock` 之上构建了更完备的生产级调度引擎 `SchedulerEngine`（位于 `src/app/services/crontab/`），应优先复用宿主自有基础设施。

**agentskills-runtime 已有**：`SchedulerEngine` 是通过 crontab_sched 规格（`D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\.codeartsdoer\specs\crontab_sched`）实现的完整调度引擎，架构分层如下：

```
接入层: CrontabController (HTTP API, 14 个端点) / CrontabCLI (12 个子命令)
服务层: CrontabSchedulerService (CRUD+调度联动) / SchedulerService (门面)
引擎层: SchedulerEngine (任务加载/执行/重试/Misfire/优雅关闭)
执行器层: ExecutorRegistry + 7 个可插拔执行器
数据层: crontab / crontab_log / crontab_task_registry 三表持久化
底层: f_ticktock (时间轮 + CRON 编译)
```

**SchedulerEngine 比原生 f_ticktock 多出的关键能力**：

| 能力 | f_ticktock | SchedulerEngine | 插件系统受益 |
|------|-----------|----------------|-------------|
| 执行器可插拔 | ❌ 单一闭包 `executor: () -> Unit` | ✅ ExecutorRegistry + 7 个执行器（script/http/builtin/agent_execution/quota_reset/evaluation/skill-curator），按 URI scheme 自动分发 | 插件可注册自定义 `CrontabExecutor` 实现 |
| 失败重试 | ❌ 无 | ✅ RetryManager：FixedDelay / ExponentialBackoff 两种策略 | 插件定时任务自动获得重试能力 |
| 错过执行补偿 | ❌ 无 | ✅ MisfireManager：FireNow / FireOnce / Ignore 三种策略 + misfire_threshold | 插件服务重启后自动补偿未执行任务 |
| 执行日志持久化 | ❌ 仅 f_log debug | ✅ crontab_log 表 15 个字段（start_time/end_time/trigger_type/retry_attempt/executor_type/result_summary） | 插件定时任务执行记录自动入库 |
| 异步日志写入 | ❌ 无 | ✅ AsyncLogWriter：生产者-消费者模式，Channel 有界队列，批量写入 100 条/批 | 高并发插件任务不阻塞调度主循环 |
| 优雅关闭 | ❌ 仅 `shutdown()` 停止时钟 | ✅ 完整流程：停止接受新触发 → 等待运行中任务（最长 30s）→ 取消重试 → 关闭 AsyncLogWriter → 持久化状态 | 插件卸载时定时任务安全退出 |
| 并发控制 | ✅ `executing(stamp)` 框架层 | ✅ 复用 f_ticktock 并发控制 + `runningTasks ConcurrentHashMap` + `concurrentable` 字段 | 防止插件定时任务重复执行 |
| 一次性任务 | ✅ `once` 属性 | ✅ `once=true` 执行后自动 `status=3` 并从调度器移除 + 持久化 | 插件初始化/迁移等一次性任务 |
| 安全防护 | ❌ 无 | ✅ 脚本路径穿越检测、HTTP SSRF 防护（内网 IP 黑名单）、参数脱敏（password/token/secret → `***`）、执行器白名单校验 | 插件定时任务继承宿主安全策略 |
| 管理 API/CLI | ❌ 无 | ✅ 14 个 HTTP API + 12 个 CLI 命令 | 插件定时任务可通过统一管理面监控 |
| 环境变量配置 | ❌ 无 | ✅ 9 个配置项（CRONTAB_SCHEDULER_ENABLED 等） | 插件定时任务行为可配置 |

**优化方案**：在 `PluginContext` 中暴露 `SchedulerEngine`（或 `SchedulerService` 门面）而非原始 `Ticktock`，插件通过标准化的 `CrontabExecutor` 接口注册定时任务：

```cangjie
public class PluginContext {
    // ... 现有成员
    public let schedulerService: SchedulerService  // 宿主 crontab 调度服务
    
    // 便捷方法：插件注册 CRON 定时任务（自动持久化 + 卸载自动清理）
    public func registerCronTask(taskUri: String, cronExpr: String,
                                  concurrentable: Bool = false,
                                  once: Bool = false,
                                  timeout: Int64 = 0,
                                  maxRetries: Int32 = 3): String {
        let taskName = "plugin.${pluginName}.${taskUri.hash()}"
        // 注册到 SchedulerEngine，自动获得：持久化/重试/Misfire/日志/安全防护
        schedulerService.registerAndSchedule(taskName, taskUri, cronExpr,
                                              concurrentable, once, timeout, maxRetries)
        // 卸载时自动清理（含数据库 crontab 表记录）
        onCleanup({ _ =>
            schedulerService.pauseTask(taskName)
            schedulerService.deleteTask(taskName)
        })
        taskName
    }
    
    // 插件也可注册自定义执行器（通过 ExecutorRegistry）
    public func registerExecutor(scheme: String, executor: CrontabExecutor): Unit {
        schedulerService.getExecutorRegistry().register(scheme, executor)
        onCleanup({ _ => schedulerService.getExecutorRegistry().unregister(scheme) })
    }
}
```

**收益**：
- 插件定时任务一步到位获得：数据库持久化、失败重试、错过执行补偿、执行日志、优雅关闭、安全防护、管理 API/CLI —— 这些都是原生 f_ticktock 不具备的
- 插件注册自定义执行器（`registerExecutor`）与宿主现有的 7 个执行器共享同一 `ExecutorRegistry`，统一管理
- `AsyncLogWriter` 的 Channel 生产者-消费者模式可被插件系统独立复用——不仅是定时任务，任何高并发日志写入场景都可用

**与 f_ticktock 的关系**：`SchedulerEngine` 内部持有 `Ticktock` 实例，通过 `Ticktock.addOrReplaceTask()` 注册。插件系统不直接操作 f_ticktock，而是通过 SchedulerEngine 的标准化接口间接使用。这符合"复用已有基础设施"原则——SchedulerEngine 已经是 agentskills-runtime 自有的、经过测试的生产级调度引擎。

---

### 3.7 优化方案六：fountain AOP 直接复用于插件横切关注点

**现状**：插件系统当前设计未考虑横切关注点（如调用日志、性能监控、权限校验）。

**fountain 已有**：`f_aspect` 提供完整的 AOP 框架：
- `Aspect` 接口：before / around / after / throwing / final 五种通知
- `@AspectRoute` 注解：声明切面匹配规则
- `@PointCut` + `@WeavedBean` 宏：编译期织入
- `Aspects` 管理器：从 BeanFactory 加载所有切面实现并缓存代理

当前 agentskills-runtime 已使用 fountain AOP（ORM 的事务切面 `TransactionAspect` 就是基于此框架实现的）。

**优化方案**：插件系统的以下横切关注点可直接用 fountain AOP 实现，无需在 Plugin 接口上额外定义拦截器：

| 横切关注点 | AOP 实现方式 | 通知类型 |
|-----------|-------------|---------|
| 插件服务调用日志 | @AspectRoute 匹配 `magic.plugins.*` 包下所有方法 | @Before + @After |
| 插件服务性能监控 | 同上，记录调用耗时 | @Around |
| 插件权限校验 | 匹配服务方法，校验调用方身份 | @Before |
| 插件异常统一处理 | 捕获插件服务异常并转换为 PluginError | @AfterThrowing |

**收益**：AOP 切面独立于插件代码，插件开发者无需感知横切逻辑。所有横切关注点可在一个 Aspect 实现中集中管理。

---

### 3.8 优化方案七：f_base.TypeInfos 替换手写反射缓存（影响 PS-T003 PluginLoader）

**现状**：design.md §2.2.2 "反射实现注意事项"中已提到"优先复用 f_base.TypeInfos.get(qualifiedName)（ConcurrentHashMap+双检锁缓存）"，但将其定位为"建议"而非"必须"。

**fountain 已有**：`f_base.TypeInfos` 和 `f_base.TypeMemberInfos` 提供：
- `TypeInfos.get(qualifiedName): TypeInfo`：线程安全的类型信息缓存（ConcurrentHashMap + 双检锁）
- `TypeMemberInfos`：成员级反射缓存，含继承链处理与函数签名索引
- 在 f_bean/BeanFactory 和 f_aspect/Aspects 等核心模块中生产级使用

**优化方案**：将"建议"提升为"强制规范"——PluginLoader 和 PluginRouteScanner 中所有 `ClassTypeInfo.get()` 调用替换为 `TypeInfos.get()`：

```cangjie
// 优化前（每次反射都走 std.reflect 裸调）
let ct = ClassTypeInfo.get("magic.plugins.entity.EntityPlugin")

// 优化后（走 fountain 缓存，避免重复反射）
let ct = TypeInfos.get("magic.plugins.entity.EntityPlugin")
```

**收益**：fountain 实测（f_bean/BeanFactory 启动时 100+ 次 ClassTypeInfo.get）表明 TypeInfos 缓存可显著降低反射开销。插件数量增长时收益更明显。

---

### 3.9 优化方案八：f_rx Observable 替代插件间复杂数据流

**现状**：插件间数据流走 PluginEventBus 的 emit/waterfall，是"请求-响应"模式。

**fountain 已有**：`f_rx` 提供完整的响应式编程框架：
- `Observable<T>` / `Observer<T>`：观察者模式
- `Emitter<T>`：数据发射器
- `Scheduler`：调度器（控制回调线程）
- `BackPressure`：背压策略

**优化方案**：对于需要"持续数据流"而非"一次性事件"的场景（如插件 A 实时产出数据、插件 B 持续消费），用 f_rx Observable 替代 PluginEventBus：

```cangjie
// 插件 A：暴露 Observable 数据流
public class DataProducerPlugin <: Plugin {
    private let emitter = Emitter<DataRecord>()
    public let dataStream: Observable<DataRecord> = emitter.asObservable()

    public func onActivate(): Unit {
        // 启动数据生产...
        emitter.onNext(record)
    }
}

// 插件 B：订阅 Observable 数据流
public class DataConsumerPlugin <: Plugin {
    public func onLoad(context: PluginContext): Unit {
        let producer = context.getService<DataProducerPlugin>()
        if (let Some(p) <- producer) {
            p.dataStream.subscribe(Observer({ r => processRecord(r) }))
        }
    }
}
```

**收益**：f_rx 支持背压（数据生产过快时自动降速）、调度器（控制回调在哪个线程执行）、操作符链（map/filter/debounce）——这些都是 PluginEventBus 的 emit/waterfall 不具备的能力。

**影响范围**：此优化为**可选增强**，不替代 PluginEventBus（emit/waterfall 更适合一次性事件的请求-响应语义），仅作为插件间持续数据流的推荐模式。

---

### 3.10 优化方案九：插件中间件复用宿主 MiddlewareChain

**现状**：插件系统当前设计未涉及 HTTP 中间件能力。插件注册的 Route 直接走 PluginRouteScanner 注入 Router，但无法为插件路由追加中间件（认证、权限、日志等）。

**agentskills-runtime 已有**：`src/app/core/middleware/MiddlewareChain` 是成熟的中间件链实现，当前宿主中间件链为：`CORS → DeserializeUser → RequirePermission → RowLevel → OperateLog`。中间件接口 `Middleware` 已抽取到 `plugin_spi`（`libs/plugin-spi/src/middleware.cj`），使得宿主和插件可共享同一套中间件契约。

**优化方案**：在 `PluginContext` 中暴露中间件注册能力，插件可声明自己路由需要的中间件：

```cangjie
public class PluginContext {
    // ... 现有成员
    public let middlewareChain: MiddlewareChain

    // 插件注册自己的中间件（按优先级插入宿主中间件链）
    public func registerMiddleware(middleware: Middleware, priority: Int32 = 50): Unit {
        middlewareChain.insert(middleware, priority)
        onCleanup({ _ => middlewareChain.remove(middleware) })
    }
}
```

插件 `plugin.yaml` 可声明中间件依赖：
```yaml
# plugin.yaml 新增字段
middleware:
  - class: magic.plugins.entity.middleware.EntityAuditMiddleware
    priority: 60    # 在 RequirePermission(50) 之后、RowLevel(70) 之前插入
```

**收益**：
- 插件路由自动获得宿主中间件链（认证/权限/操作日志），无需插件开发者重复实现
- 插件可声明额外中间件（如业务审计、数据脱敏），融入宿主中间件链
- `Middleware` 接口已在 `plugin_spi` 中定义，无需引入新依赖
- PluginRouteScanner 注册路由时自动关联插件声明的中间件

---

### 3.11 优化方案十：插件接入 WebSocket 实时事件流

**现状**：插件系统当前未涉及 WebSocket 实时通信能力。

**agentskills-runtime 已有**：两条独立的实时事件通道：

| 组件 | 位置 | 能力 |
|------|------|------|
| **WebSocketEventBridge** | `src/app/services/bridge/websocket_event_bridge.cj` | 单例，监听 14 种 Agent 事件（ToolCallStart/End、ChatModelStart/End、AgentStart/End 等），序列化为 JSON 推送到 ConcurrentHashMap 缓冲区 |
| **SSEEventBridge** | `src/app/services/bridge/sse_event_bridge.cj` | SSE 事件桥，与 WebSocket 平行的推送通道 |
| **WebSocketSessionManager** | `src/app/services/bridge/websocket_session_manager.cj` | 会话管理，支持 sendApprovalRequest / cancelFlag |

**优化方案**：插件通过 `PluginEventBus` 发射业务事件，WebSocketEventBridge 新增对插件事件的监听，将插件事件推送到前端。同时插件可通过 `PluginContext` 订阅宿主事件：

```cangjie
public class PluginContext {
    // ... 现有成员
    public let eventBridge: WebSocketEventBridge

    // 插件向前端推送实时事件
    public func pushToClient(clientId: String, eventType: String, payload: JsonValue): Unit {
        eventBridge.push(clientId, eventType, payload)
    }

    // 插件监听宿主 Agent 事件（14 种事件类型）
    public func onAgentEvent<T>(eventType: EventKind, handler: (T) -> Unit): Unit {
        let sub = eventBridge.subscribe(eventType, handler)
        onCleanup({ _ => eventBridge.unsubscribe(sub) })
    }
}
```

**应用场景**：
- 插件执行长时间任务时推送进度到前端（如代码生成进度条）
- 插件监听 `AgentStepEvent` 获取 Agent 执行步骤，实现自定义可视化
- 插件监听 `ToolCallEndEvent` 获取工具调用结果，实现工具审计面板

**影响范围**：此优化为可选增强，不影响阶段三主线。WebSocketEventBridge 已稳定运行，新增插件事件监听只需在 bridge 中增加 `PluginEventBus.subscribe()` 调用。

---

### 3.12 优化方案十一：插件数据同步复用宿主 SyncManager

**现状**：PluginSyncBridge（`src/plugin/plugin_sync_bridge.cj`）已实现插件状态→agent_skills 表的单向回写。但未利用宿主已有的 SyncManager（`src/app/services/sync/`）的完整同步管线。

**agentskills-runtime 已有**：`SyncManager` 是完整的双向同步引擎：
- **SyncManager**：总控，管理同步生命周期
- **AgentSkillSyncHandler**：文件系统 ↔ agent_skills 表双向同步
- **ChangeDetector**：变更检测（识别新增/修改/删除的技能文件）
- **DataMapper**：SkillManifest ↔ AgentSkillsPO 数据映射
- **sync_status 五态**：synced / pending / error / dependency_missing 等

关键发现：**plugins.yaml / plugin.yaml 中的 `skills: [SKILL.md]` 声明已使插件目录的 SKILL.md 被现有 SyncManager 无差别扫描同步**（见 design.md §1.2 skills 双向同步机制）。这是存量兼容的天然产物。

**优化方案**：PluginSyncBridge 的"状态回写"从独立实现改为订阅 SyncManager 事件，实现"同步完成→自动回写插件状态"的闭环：

```cangjie
// 优化后的 PluginSyncBridge（复用 SyncManager 事件）
public class PluginSyncBridge {
    public func bind(syncManager: SyncManager, eventBus: PluginEventBus): Unit {
        // 1. 监听 SyncManager 同步完成事件
        syncManager.onSyncCompleted({ result =>
            // 2. 同步完成后自动回写插件状态到 agent_skills 表
            for (plugin in result.syncedPlugins) {
                writeRuntimeState(plugin.name, plugin.state, plugin.errorMessage)
                mergePluginMetadata(plugin.name, plugin.manifest)
            }
        })

        // 3. 监听 PluginEventBus 的插件生命周期事件
        eventBus.subscribe("system", "plugin.activated", { j =>
            // 触发增量同步（只同步该插件的技能）
            syncManager.syncByPlugin(j["name"].asString())
            j
        })
    }
}
```

**收益**：
- PluginSyncBridge 从 ~200 行独立同步逻辑简化为 ~50 行事件监听代码
- 插件技能同步复用 SyncManager 已有的成熟管线（变更检测/冲突解决/重试）
- `sync_status` 五态自动关联插件状态，可观测性提升

---

### 3.13 优化方案十二：插件注册自定义 AI 模型 Provider

**现状**：插件系统当前未涉及 AI 模型 Provider 扩展能力。

**agentskills-runtime 已有**：`ModelManager`（`src/model/model_manager.cj`）管理 16 个 AI 模型 Provider（openai / stepfun / siliconflow / zhipuai / dashscope / ollama / tokendance / sophnet / orbitai / deepseek / ark / maas / google / moonshot / openrouter / llamacpp），通过 `{PROVIDER}_API_KEY` / `{PROVIDER}_BASE_URL` 环境变量配置。

**优化方案**：`ServiceRegistry`（已委托 BeanFactory）中注册的新 Provider 实现，由 `ModelManager` 通过 `lookupList<ChatModelProvider>()` 自动发现：

```cangjie
// 插件注册自定义 AI Provider
public class CustomModelPlugin <: Plugin, ChatModelProvider {
    public func onLoad(context: PluginContext): Unit {
        // 注册到 BeanFactory（ServiceRegistry 委托）
        context.registerService("CustomModelProvider", this)
        // ModelManager 通过 lookupList<ChatModelProvider>() 自动发现
    }

    // 实现 ChatModelProvider 接口
    public func createChatModel(modelName: String): ChatModel { ... }
    public func getProviderName(): String { "custom-provider" }
}
```

**收益**：
- 插件可透明注册新的 AI 模型 Provider（如本地模型、私有部署模型）
- ModelManager 通过 BeanFactory 泛型查找自动发现，无需手动注册
- 配置注入复用 `@Value` 宏（如 `@Value["CUSTOM_API_KEY"]`），类型安全

---

### 3.14 优化方案十三：插件缓存复用宿主 CacheManager (Redis)

**现状**：插件系统当前未涉及缓存能力。

**agentskills-runtime 已有**：`CacheManager`（`src/app/core/cache/CacheManager.cj`）是基于 Redis 的单例缓存管理器：
- `getInstance()`：获取单例
- `get(key)` / `set(key, value)` / `delete(key)`：KV 操作
- Redis 连接池管理

**优化方案**：在 `PluginContext` 中暴露插件隔离的缓存命名空间：

```cangjie
public class PluginContext {
    // ... 现有成员
    public let cache: PluginCache  // 插件隔离缓存（key 自动加 pluginName 前缀）

    public class PluginCache {
        private let cacheManager: CacheManager
        private let prefix: String

        public func get(key: String): Option<String> {
            cacheManager.get("${prefix}:${key}")
        }
        public func set(key: String, value: String, ttl: Int64 = 0): Unit {
            cacheManager.set("${prefix}:${key}", value, ttl)
        }
        public func delete(key: String): Unit {
            cacheManager.delete("${prefix}:${key}")
        }
    }
}
```

**收益**：
- 插件自动获得 Redis 缓存能力，key 以 `plugin.{name}:` 前缀隔离
- 插件卸载时 `cache.deletePattern("plugin.{name}:*")` 批量清理
- 复用宿主已有的 Redis 连接池，无需插件自行管理连接

---

### 3.15 优化方案十四：插件沙箱执行复用宿主 SandboxExecutor

**现状**：插件系统当前未涉及代码安全执行能力。

**agentskills-runtime 已有**：`SandboxExecutor`（`src/security/sandbox_executor.cj`）支持 WASM 沙箱隔离执行不受信任的代码，配合 `PermissionService`（`src/security/permission_service.cj`）提供细粒度权限控制。

**优化方案**：插件可在 `PluginContext` 中请求沙箱执行能力：

```cangjie
public class PluginContext {
    // ... 现有成员
    public let sandbox: Option<SandboxExecutor>  // 可选沙箱执行器

    // 插件请求沙箱执行
    public func executeInSandbox(code: String, language: String,
                                  permissions: PermissionSet): SandboxResult {
        if (let Some(sb) <- sandbox) {
            sb.execute(code, language, permissions)
        } else {
            SandboxResult.error("沙箱不可用")
        }
    }
}
```

**收益**：
- 插件执行第三方脚本/代码时获得 WASM 沙箱隔离保护
- 复用宿主已有的 `PermissionService`（能力权限 + 资源限制检查）
- 未配置沙箱的插件降级到直接执行（向后兼容）

---

### 3.16 优化方案总览表

| 编号 | 优化项 | 影响的组件/任务 | 复用基础设施 | 优先级 | 对现有设计的影响 |
|------|--------|---------------|-------------|--------|----------------|
| 3.2 | ServiceRegistry 委托 BeanFactory | PS-T017, §2.2.2 | fountain f_bean | **P0 强烈建议** | 中等——实现层变更，契约层不变 |
| 3.3 | PluginEventBus 包装 fountain EventBus | PS-T005, §2.2.2 | fountain f_concurrent/eventbus | **P0 强烈建议** | 低——接口合约不变，实现层简化 |
| 3.4 | PluginDylibLoader 复用 App.run() 管线 | PS-T012, §2.2.2 | fountain f_app | **P0 强烈建议** | 低——直接复用代码 |
| 3.5 | @Plugin 发现走 BeanFactory.annotationMap | PS-T003, §2.1.3 | fountain f_bean | **P1 推荐** | 中等——需修改 PluginLoader 加载流程 |
| 3.6 | 插件定时任务复用宿主 SchedulerEngine | 新增能力 | **agentskills-runtime SchedulerEngine** | **P2 可选** | 无——新增能力 |
| 3.7 | AOP 复用于插件横切关注点 | 新增能力 | fountain f_aspect | P2 可选 | 无——新增能力 |
| 3.8 | TypeInfos 替换手写反射缓存 | PS-T003 | fountain f_base | **P1 推荐** | 极低——替换 API 调用 |
| 3.9 | f_rx Observable 补充数据流 | 新增能力 | fountain f_rx | P3 远期 | 无——补充模式 |
| 3.10 | 插件中间件复用宿主 MiddlewareChain | 新增能力 | **agentskills-runtime MiddlewareChain** | P2 可选 | 低——plugin.yaml 新增 middleware 字段 |
| 3.11 | 插件接入 WebSocket 实时事件流 | 新增能力 | **agentskills-runtime WebSocketEventBridge** | P3 远期 | 低——WebSocketEventBridge 新增插件事件监听 |
| 3.12 | 插件数据同步复用宿主 SyncManager | PluginSyncBridge | **agentskills-runtime SyncManager** | **P1 推荐** | 中——PluginSyncBridge 从独立实现改为事件监听 |
| 3.13 | 插件注册自定义 AI 模型 Provider | 新增能力 | **agentskills-runtime ModelManager** | P3 远期 | 无——新增能力 |
| 3.14 | 插件缓存复用宿主 CacheManager (Redis) | 新增能力 | **agentskills-runtime CacheManager** | P3 远期 | 无——新增能力 |
| 3.15 | 插件沙箱执行复用宿主 SandboxExecutor | 新增能力 | **agentskills-runtime SandboxExecutor** | P3 远期 | 无——新增能力 |

### 3.17 实施建议——分步推进顺序

考虑到阶段三已有 5 大任务（PS-T017 → PS-T012 → PS-T019 → PS-T020 → PS-T021），优化方案的引入应遵循"不阻塞现有任务、不增加风险"原则：

```
阶段三原计划                 优化方案插入点
─────────────────────────────────────────────────────
PS-T017: plugin-spi 抽取    ← 3.2 ServiceRegistry 委托 BeanFactory（契约不变，实现层在宿主侧改）
                            ← 3.8 TypeInfos 替换（API 替换，零风险）
                            ← 3.12 PluginSyncBridge 简化（复用 SyncManager 事件）

PS-T012: L2 动态库加载      ← 3.4 复用 App.run() 管线（代码复用，降低开发量）
                            ← 3.5 @Plugin 注解发现走 annotationMap（简化 PluginLoader）

PS-T019: pluginuninstall     （不受影响，但 3.6 SchedulerEngine 的优雅关闭模式可参考）

PS-T020: build-sync 增强     （不受影响）

PS-T021: 集成测试            ← 需验证 3.2/3.4/3.5/3.12 的变更

──── 阶段四可引入 ─────────────────────────────────
3.6  SchedulerEngine 插件定时任务
3.7  AOP 插件横切关注点
3.10 MiddlewareChain 插件中间件
3.11 WebSocketEventBridge 实时事件流
3.13 ModelManager 自定义 AI Provider
3.14 CacheManager 插件缓存
3.15 SandboxExecutor 插件沙箱
3.9  f_rx Observable 数据流
```

**关键决策点**：
1. **3.2（ServiceRegistry → BeanFactory）**应在 PS-T017 实施时同步落地——此时确定"实现层委托 BeanFactory"可避免先自建再迁移的二次工作
2. **3.4（复用 App.run()）**应在 PS-T012 实施时直接采用，避免"先写 PluginDylibLoader 学习版再替换为复用版"的重复劳动
3. **3.5（@Plugin 注解发现）**可与 3.4 同时落地——L2 动态库加载完成后自然触发 BeanFactory.afterRegistered()
4. **3.12（PluginSyncBridge 简化）**可在 PS-T017 时顺带优化——SyncManager 已在宿主中稳定运行，PluginSyncBridge 从独立实现改为事件监听降低代码量
5. **3.6/3.7/3.10/3.11/3.13/3.14/3.15/3.9** 为新增能力或远期优化，不阻塞阶段三主线

### 3.18 风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| BeanFactory 是全局单例，插件与宿主服务命名冲突 | 低 | 约定插件服务前缀 `plugin.{name}.`；BeanFactory 已有 duplicate detection |
| fountain EventBus 的事件模型与 PluginEventBus 不兼容 | 低 | 先验证 fountain EventBus 源码中的事件类型——根据 f_concurrent/eventbus/Event.cj 代码签名确认适配方式 |
| PackageInfo.load 跨包反射行为不确定性 | 中 | fountain 已在四平台验证；阶段三增加专门的跨包反射验证测试（PS-T017 子任务6已规划） |
| 插件数量增长导致 BeanFactory 膨胀 | 低 | BeanFactory 使用 ConcurrentHashMap，O(1) 查找；支持 lazy 加载 |
| fountain 版本升级导致 API 不兼容 | 低 | fountain 是仓颉企业级框架，稳定版本 1.0.48；在 cjpm.toml 中锁定版本 |
| SchedulerEngine 任务命名空间与插件冲突 | 低 | 约定插件任务名前缀 `plugin.{name}.`；SchedulerEngine 已有 duplicate detection |
| PluginSyncBridge 从独立实现改为事件监听后，SyncManager 事件接口变更 | 低 | SyncManager 是宿主自有基础设施，接口变更可控；PluginSyncBridge 关注点分离（只监听，不修改） |
| MiddlewareChain 中间件顺序冲突（插件中间件 vs 宿主中间件） | 低 | 通过 `priority` 字段排序，宿主中间件 priority 保留 0-49 段，插件 50+ |
| CacheManager Redis 连接池被插件耗尽 | 低 | 复用宿主连接池，连接数由 `REDIS_MAX_CONNECTIONS` 环境变量统一控制 |
| SandboxExecutor WASM 执行引擎不可用导致插件降级 | 低 | 插件代码中判空 `Option<SandboxExecutor>`，不可用时自动降级到直接执行并记 WARN |
| **plugin-spi 依赖 http_lib 触发符号重复**（v4.0 新增） | 高 | **plugin-spi 不依赖 http_lib**——HTTP 类型保留宿主侧，不迁入 plugin-spi（可编译备份验证：dynamic→dynamic 依赖触发 `ld.lld: error: _CGP15http_lib.bufferiiHv was replaced` 符号重复） |

---

## 四、设计决策记录（ADR）

### ADR-001：plugin-spi 不依赖 http_lib（v4.0）

**状态**：已采纳（2026-08-24）

**背景**：PS-T017 子任务 4（方案 B，转发模式）中，HTTP 类型自 magic.app.core.http 迁入 plugin-spi 包。HttpRequest 含 `connection: ?Connection` 字段，故 plugin-spi 的 cjpm.toml 需声明 http_lib 依赖。

**决策**：**plugin-spi 不依赖 http_lib**，HTTP 类型保留宿主侧，不迁入 plugin-spi。

**理由**：
1. plugin-spi 是 dynamic 库，它依赖 http_lib（也 dynamic）时，cjpm 仍会把 http_lib 符号复制进 plugin_spi.dll
2. 宿主 magic.app 又链接了 http_lib，导致同一符号 `_CGP15http_lib.bufferiiHv` 被定义两次 → `ld.lld: error: _CGP15http_lib.bufferiiHv was replaced`
3. 可编译备份版本验证：plugin-spi 的 `[dependencies]` 为空，HTTP 类型保留宿主侧，编译通过

**影响**：
- plugin-spi 的 cjpm.toml `[dependencies]` 保持为空
- HTTP 类型（HttpMethod/HttpUrl/HttpHeader/HttpRequest/HttpResponse）保留宿主侧 `src/app/core/http/HttpTypes.cj`，不迁入 plugin-spi
- 插件如需 HTTP 类型，通过宿主转发机制访问（与查询/响应类型迁移方式一致）

### ADR-002：方案 B 独立预编译（2026-08-24）

**状态**：已采纳

**背景**：阶段三 L2 动态库加载需要决定插件的编译与加载方式。

**决策**：**方案 B 独立预编译**——插件 precompile as independent dynamic libraries; host loads via `PackageInfo.load()` at runtime — no root `cjpm.toml` modification, no host rebuild。

**理由**：
1. `PackageInfo.load(path)` 是运行时 API，bypasses cjpm compile-time dependency resolution
2. 不修改根 cjpm.toml，插件开发者在自己机器上 `cd skills/{name}/ && cjpm build` 预编译为动态库
3. 宿主运行时通过 `PackageInfo.load()` 热加载，全程不修改根 cjpm.toml，不重启宿主进程

### ADR-003：转发模式（2026-08-24）

**状态**：已采纳

**背景**：PS-T017 中，查询/响应/HTTP/中间件/路由/权限/日志类型自宿主迁入 plugin-spi。宿主 362+ 个 importing files 需要零改动访问迁移后的类型。

**决策**：**转发模式**——Migrated types use host `public import plugin_spi.{...}` forwarding。

**理由**：
1. `spi_reexport.cj` validates `public import plugin_spi.{...}` cross-package forwarding pattern
2. 宿主 362+ 个 importing files 零改动访问
3. plugin-spi 接口层纯净，不依赖宿主 magic 包

### ADR-004：ServiceRegistry 委托 BeanFactory（v4.0）

**状态**：已采纳

**背景**：ServiceRegistry 的实现方式——自建注册表 vs 委托 fountain BeanFactory。

**决策**：**委托 BeanFactory**——ServiceRegistry 的内部实现委托给 fountain BeanFactory。

**理由**：
1. 复用 IOC 容器的类型安全（getFirst<T>）+ 并发控制（ConcurrentHashMap）+ 生命周期管理（BeanScope）
2. ~20 行委托代码替代 ~166 行自建注册表
3. 宿主代码直接 `lookup<T>()` 消费，无需桥接层

### ADR-005：PluginEventBus 包装 fountain EventBus（v4.0）

**状态**：已采纳

**背景**：PluginEventBus 的实现方式——独立自建 vs 包装 fountain EventBus。

**决策**：**包装 fountain EventBus**——PluginEventBus 的实现层包装 fountain EventBus。

**理由**：
1. 从同步单线程升级为多 Worker 并发+背压的生产级实现
2. 减少约 150 行事件总线核心代码
3. 复用 fountain 已在 630+ 个 .cj 文件中实战验证的 EventBus

### ADR-006：引入 cordis-cj 作为 L3 进程隔离轨（v5.0）

**状态**：已采纳（2026-08-28，阶段四立项）

**背景**：阶段三落地后，§0.2 六大限制中 #2/#3/#4/#5 仅被 L2 轨部分缓解；"第三方可独立发布插件（可闭源）"的插件市场门槛未真正达成。经调研仓颉社区第三方库 cordis-cj（`apps/cordis-cj`，MIT，对标 DeepSeek Harness Cordis 的仓颉实现），其"微内核 + 进程隔离"架构可作为第三轨。

**决策**：**引入 cordis-cj 作为 L3 进程隔离轨**——三轨并存（内嵌 sync / L2 dylib / L3 process），L3 轨以 cordis_host 为宿主侧进程管理器、cordis_plugin 为插件侧 SDK、JSON-RPC over stdio 为传输，宿主新增 CordisHostManager + 宿主侧服务代理 + ExternalPluginRouteGateway 三个组件（全部位于 `src/plugin/`，存量 src/app 零改动）。

**理由**：
1. 插件 = 独立可执行文件，完全不进宿主编译图——彻底消解 §0.2 限制 #1/#4/#5（见 §0.5 消解对照表）
2. 卸载 = 杀进程 + OS 级资源回收，确定性优于 dlclose（限制 #3）
3. 崩溃自愈（reconcile 重拉）提供进程级故障隔离，对齐 DSH sandbox 语义
4. MIT 许可证、纯仓颉标准库实现（无 ohos.* 依赖）、源码已 vendor 本地（apps/cordis-cj）
5. 不推翻已落地的内嵌轨/L2 轨——三轨并存，plugins.yaml mode 切换，缺省向后兼容

**权衡与放弃的替代方案**：
- 自研进程管理：工作量数倍于集成，且 reconcile 语义（依赖拓扑/diff/自愈）需长期打磨——放弃
- 等待工具链升级再评估：阶段四门槛（v1.0 插件市场基础设施）时间线不允许——放弃
- 仅增强 L2 轨：无法解决故障隔离与闭源发布——放弃

**前置闸门（一票否决）**：Spike-1 工具链兼容（cordis-cj 声明 cjc 1.1.3 vs 宿主 1.0.5）；Spike-2 Windows 可编译性（jsonrpc_unix UDS 不支持 Windows，失败则 vendor 剥离 UDS 仅留 stdio）。闸门验证为纯编译验证（人工独立 cmd 执行），失败则本决策回退至"暂缓"状态。

**影响**：
- 宿主新增依赖：`ystyle::cordis_host` + `ystyle::jsonrpc`/`jsonrpc_stdio`（UDS 视 Spike-2 结论）/ `tomlcj` / `jsonvalue`（与宿主既有依赖查重对齐）
- 插件侧 SDK（cordis_plugin + jsonvalue）仅供插件工程引用，不进宿主依赖图
- 传输固定 stdio（UDS 不启用）；插件禁用 `@Plugin` 宏（cjpm 宏 organization 跨模块缺陷），入口统一 `PluginRuntime.run` 显式 API
- 详细设计见第五章；任务分解 PS-T022~T030 见 tasks.md v4.0

---

## 五、L3 进程隔离插件轨设计（cordis-cj 集成，v5.0 新增）

> 本章为阶段四（v1.0）L3 进程隔离轨的技术设计，对应 spec.md REQ-PS-015。前置调研：可行性报告附7.14（cordis-cj 完整源码研究）。决策记录：ADR-006。任务分解：tasks.md PS-T022~T030。

### 5.0 设计动因与三轨定位

**动因**：阶段三 L2 轨实现"不重编宿主装插件"，但插件与宿主同进程——无故障隔离、卸载依赖 dlclose 行为不确定、插件可闭源发布未达成。cordis-cj 的"微内核 + 进程隔离"（插件 = 独立子进程）补齐最后一块拼图。

**三轨定位**（详见 §0.3/§0.5）：

| 轨 | mode | 插件形态 | 适用场景 |
|---|---|---|---|
| 内嵌轨 | sync | 源码 build-sync 进宿主（magic.plugins.{name}） | 开发期（增量编译快、IDE 友好） |
| L2 轨 | dylib | 预编译动态库（skill_{name}，--dy-std） | 预编译热加载、轻量扩展 |
| **L3 轨（本章）** | process | **独立可执行文件（cjpm executable）** | **故障隔离、闭源发布、第三方市场、AI 动态启停** |

三轨并存互斥于单个插件（一个插件声明一种 mode），宿主同时支持三轨加载。存量 src/app 零改动红线继续有效；全部新增组件位于 `src/plugin/`（magic.plugin 包）。

### 5.1 cordis-cj 架构概览（集成视角）

完整源码研究见可行性报告附7.14，此处仅列集成直接相关的语义：

- **进程模型**：`cordis_host`（宿主侧）以 PluginManager 拉起插件子进程，经 JSON-RPC 2.0 通信（stdio：NewlineFraming 换行分帧 / UDS：ContentLengthFraming——本集成固定 stdio）
- **生命周期握手**：插件进程入口 `PluginRuntime.run(...)` → initialize 握手 → provide 注册服务/效果 → 宿主 invoke 调用 → terminate 终止
- **Reconciler**：期望状态（desired）vs 实际状态（actual）diff 驱动——拉起/终止/重启；插件间依赖拓扑排序；崩溃自愈（stdout EOF → Failed → 下轮 reconcile 重拉；探活 ping 超时 → Unreachable → 重启）
- **InstanceStatus**：Starting / Pending / Active / Unloading / Failed / Unreachable
- **服务注入**：插件 `ctx.invoke("serviceName", method, params)` 反向调用宿主或其他插件注册的服务——宿主能力暴露的安全通道
- **可逆效果**：插件 `ctx.effect` 注册清理动作，卸载逆序执行（对齐 Cordis fiber.dispose）
- **EventRegistry**：五种派发（emit/parallel/serial/bail/waterfall）——阶段四后期可选桥接（PS-T030）

### 5.2 宿主侧集成组件

#### 5.2.1 CordisHostManager（`src/plugin/cordis_host_manager.cj`）

L3 轨总控，职责：

1. **启动编排**：PluginManager 启动时扫描 `plugins.yaml` 中 `mode: process` 条目，构造 cordis 期望状态（name/command/args/env/enabled/autoRestart），交给 cordis PluginManager(stdio)
2. **reconcile 托管**：diff/拓扑排序/自愈全部委托 cordis Reconciler，宿主不重复实现
3. **优雅停机**：宿主退出时按依赖逆序 terminate 全部 process 插件
4. **Agent 工具映射**：`plugin_activate`/`plugin_deactivate` → 期望状态 enabled 变更（true 拉起 / false terminate）；`plugin_inspect` 展示进程级信息（pid/status/restartCount/lastError）——DSH tool-cordis 自引用语义的进程级等价物
5. **日志汇聚**：插件进程 stdout/stderr 经 cordis 采集转发宿主 LogUtils（LOG_FILE 统一沉淀）

与既有 PluginManager 的关系：PluginManager 扩展为三轨分发器——sync 走 build-sync 反射、dylib 走 PluginDylibLoader、process 委托 CordisHostManager。

#### 5.2.2 状态映射与回写

| cordis InstanceStatus | PluginState | agent_skills.runtime_status |
|---|---|---|
| Starting | Loading | loading |
| Pending | Pending | pending |
| Active | Active | active |
| Unloading | Disposed | disposed |
| Failed / Unreachable | Error | error |

回写链路复用既有通道：`PluginHost.onStatusChange` 回调 → PluginRuntimeInfo 更新 → PluginSyncBridge → `agent_skills.runtime_status`（零 DDL，复用 AgentSkillsDAO）。

#### 5.2.3 宿主侧服务代理（`src/plugin/cordis_host_services.cj`）

宿主在 RPC 连接上注册的服务 handler，插件进程经 `ctx.invoke` 反向调用——插件访问宿主能力的**唯一**入口：

- **host.db**：query/execute 两方法；参数为受限查询描述（参数化 + 表白名单，禁透传任意 SQL 文本）；实现委托宿主 f_orm 数据源/连接池；**行级权限条件由宿主侧强制附加**（插件无法绕过）
- **host.log**：日志转发 LogUtils（级别/消息/插件名前缀）
- **host.cache**：键值缓存委托宿主 CacheManager；键空间以插件名隔离（防跨插件越权）

契约（JSON-RPC method/params/result 签名）作为插件 SDK 契约文档随 cordis_plugin 模板分发（PS-T026 子任务 4）。

#### 5.2.4 ExternalPluginRouteGateway（`src/plugin/external_plugin_route_gateway.cj`）

为 process 插件代理 UCTOO V4 API 路由：

1. **注册**：读取 plugin.yaml 声明的 routes，以宿主标准路径签名（/:version/:module/:entity/...）注册；与 PluginRouteScanner（内嵌轨反射注册）互不冲突；静态路径优先于动态路径的注册顺序约束（项目硬约束）继续有效
2. **转发**：handler 序列化 `ExternalRequest`（method/path/pathParams/queryParams/body/userId/permissions）→ JSON-RPC `invoke` 插件进程 → 插件返回 `{errno, errmsg}` 或数据对象 → 网关按 V4 规范回写（成功直接返回数据对象，错误 `{errno, errmsg}`；列表 `{ currentPage, totalCount, totalPage, entitys }`）
3. **中间件链宿主侧执行**：CORS → DeserializeUser → RequirePermission → RowLevel → OperateLog 在网关 handler 前完成——插件进程只处理纯业务（userId/权限上下文随请求传入），V4 API 规范与 RBAC/行级权限体系完全保留
4. **兜底**：invoke 超时（缺省 30s 可配）→ 504 风格错误；插件 Unreachable → 503 风格错误；请求 id 透传关联日志
5. **OperateLog**：宿主侧记录（含插件名模块标识），与内嵌轨行为一致

### 5.3 插件侧形态（独立 cjpm 工程）

```
skills/{name}/
├── SKILL.md              # AI 行为描述（三维一体不变）
├── plugin.yaml           # 清单：mode: process + command 指向编译产物
├── cjpm.toml             # output-type = "executable"，name = "skill_{name}"
├── src/
│   ├── main.cj           # 入口：PluginRuntime.run(...) 显式 API（禁用 @Plugin 宏）
│   ├── handlers.cj       # V4 CRUD RPC handler（add/edit/del/get/list）
│   └── effects.cj        # ctx.effect 可逆效果注册
└── README.md             # 第三方开发者手册（生成→build→放置→生效）
```

**约束**：
- 依赖仅 `ystyle::cordis_plugin` + `jsonvalue`（+仓颉标准库）——零 magic 包依赖、零 `ohos.*` 依赖
- **禁用 `@Plugin` 宏**：cjpm 宏包 organization 跨模块缺陷（cordis-cj 官方同样建议外部插件作者用显式 API）
- 数据访问一律经 host.db 服务代理（不直连数据库）
- 独立 `cjpm build` 产出可执行文件，放置 + plugins.yaml 登记即生效（不重编宿主、不重启宿主）

### 5.4 生命周期语义（对齐 Cordis/DSH）

| 语义 | 实现 | 对齐对象 |
|---|---|---|
| 启停 | plugin_activate/deactivate → 期望状态变更 → 拉起/terminate | DSH tool-cordis 自引用 |
| 卸载 | terminate（杀进程）+ OS 资源回收 + 静态/数据库层清理（pluginuninstall process 轨） | Cordis fiber.dispose |
| 崩溃自愈 | stdout EOF → Failed → reconcile 重拉（≤3s）；ping 超时 → Unreachable → 重启 | DSH sandbox restart |
| 可逆效果 | 插件 ctx.effect 注册、卸载逆序执行 | Cordis revertible effects |
| 状态回写 | InstanceStatus → PluginState → agent_skills.runtime_status | — |

### 5.5 配置扩展

**plugins.yaml**（加载清单，宿主侧）：

```yaml
plugins:
  - name: entity
    mode: process              # 新增第三值；缺省 sync 向后兼容
    command: ./skills/entity/target/release/skill_entity.exe
    args: []
    env: { LOG_LEVEL: "info" }
    enabled: true
    autoRestart: true          # 缺省 true
```

**plugin.yaml**（插件自描述，新增字段）：`mode: process`、`command`（产物路径）、`protocol`（缺省 "jsonrpc-stdio"）。

### 5.6 安全边界

- 插件进程对宿主能力的访问**仅经服务代理**（host.db/host.log/host.cache），参数化+表白名单+行级权限宿主侧强制
- 插件间服务调用受 cordis 服务隔离约束（默认不可见其他插件服务）
- 中间件链（认证/权限/行级/操作日志）全部宿主侧执行，插件无法绕过
- host.cache 键空间按插件名隔离
- 进程边界本身即最小权限容器：插件崩溃/内存越界不影响宿主与其他插件

### 5.7 风险与对策（Spike 双闸门）

| 风险 | 等级 | 对策 |
|---|---|---|
| R1 工具链不兼容（cordis-cj 声明 cjc 1.1.3 vs 宿主 1.0.5） | 高 | Spike-1 一票否决闸门（人工独立 cmd 编译验证）；不兼容则评估最小补丁或暂缓阶段四 |
| R2 Windows 不可编译（jsonrpc_unix UDS） | 高 | Spike-2 一票否决闸门；失败则 vendor 剥离 UDS 仅留 stdio（传输已固定 stdio，剥离不影响集成目标） |
| R3 依赖符号冲突（jsonvalue 等与宿主重复） | 中 | PS-T024 依赖查重 + 符号冲突预检（ADR-001 教训） |
| R4 网关延迟开销（跨进程 RPC vs 进程内调用） | 中 | 列表查询等高频路径可先走内嵌轨/L2 轨；L3 轨面向隔离优先场景 |
| R5 cordis-cj 上游演进分叉 | 低 | vendor 本地（apps/cordis-cj），锁定快照，升级自主决策 |

### 5.8 可选增强：跨进程事件桥接（PS-T030，阶段四后期）

cordis EventRegistry（emit/parallel/serial/bail/waterfall）↔ 进程内 PluginEventBus（包装 fountain EventBus）桥接；缺省映射 emit；进程重启期间事件补偿语义（至少一次/至多一次）需显式声明。非晋级门槛，仅在主体验证通过且有真实需求时启动。

---

## 六、版本历史

| 版本 | 日期 | 核心变更 |
|------|------|---------|
| v5.0 | 2026-08-28 | 阶段四立项修订（cordis-cj 集成）：①新增第五章 L3 进程隔离插件轨设计（三轨定位/宿主三组件/插件形态/生命周期/配置/安全边界/风险闸门）；②新增 ADR-006 引入 cordis-cj 决策（含权衡与一票否决闸门）；③§0.3 路由表新增 L3 进程轨行；④新增 §0.5 六大限制消解对照表；⑤版本历史章节号顺延为第六章。依据：可行性报告附7.14 cordis-cj 完整调研 |
| v4.0 | 2026-08-24 | fountain/agentskills-runtime 基础设施深度复用修订：①将第三章 14 项优化方案融入第二章设计本体，消除"设计正文 vs 优化附录"割裂；②修正 HTTP 类型迁移错误——plugin-spi 不依赖 http_lib；③ServiceRegistry/PluginEventBus/PluginDylibLoader 实现方式从"自建"改为"委托/包装 fountain"；④插件发现从"手动反射扫描"改为"BeanFactory.annotationMap + lookupList<Plugin>()" |
| v3.x | 2026-08-24 | v3.1 runtime 自有基础设施复核、v3.0 fountain 深度复用（新增第三章优化方案，从"参考 fountain"升级为"直接复用 fountain 生产级基础设施"） |
| v2.3 | 2026-08-19 | fountain 研究修订：①§1.1.1 新增 fountain 反射基础设施复用清单；②§2.2.2 ServiceRegistry 增加 getService<T>() 泛型类型安全接口；③PluginLoader 复用 f_base.TypeInfos 缓存 + isSubtypeOf 调用顺序警告；④L2 动态加载参考 f_app.App.run() 完整实现 |
| v2.2 | 2026-08-19 | 复核修订：①SkillBridge 依赖由 ProgressiveSkillLoader/SkillRegistrationService 改为 SkillManagementService；②§2.1.4 补 PluginState ACTIVE→ERROR 触发条件定义；③PluginEventBus 与存量 EventHandlerManager 关系统一为"独立实现、EventKind 语义对齐"；④§2.2.2 补 ServiceRegistry 服务命名契约；⑤AutoRouteConfig.cj 行数修正为实测约 1300 行 |
| v2.1 | 2026-08-18 | 修订：①crudgen/crudweb 保留不重构，插件生成改由新建 plugingen 承担；②§2.3 新增 agent_skills 表兼容性核对与 PluginSyncBridge 设计；③§1.2 补 skills 双向同步机制存量分析与扩展点 |
| v2.0 | 2026-08-15 | 初始版本：基于 spec.md v2，设计插件系统三层模型（运行时层 → 静态资产层 → 数据库痕迹层） |

---

> **文档状态**：v5.0 阶段四立项（cordis-cj 集成 L3 进程隔离轨）——第五章设计 + ADR-006 决策 + §0.5 限制消解对照就绪，与 spec.md v3.0（REQ-PS-015）、tasks.md v4.0（PS-T022~T030）、可行性报告附7.14 四文档同步。阶段一~三落地状态见 §0（v4.1 实际落地与限制说明）。
>
> **下一步**：①Spike-1 工具链兼容验证（PS-T022：人工独立 cmd 在 apps/cordis-cj 用宿主 cjc 1.0.5 编译，一票否决闸门）；②Spike-2 Windows 可编译性验证（PS-T023：失败则 vendor 剥离 UDS 仅留 stdio）；③双闸门通过后按 PS-T024~T029 顺序推进（vendor → CordisHostManager → 服务代理 → 网关 → 工具适配 → 集成测试）。
```
