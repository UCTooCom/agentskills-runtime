# 插件系统 - 任务清单

> 版本：v2.5（2026-08-21 阶段二运行时验证通过：宿主启动日志（logs/agentskills-runtime.log）确认插件加载 3/3（hello/doc-helper/entity，failed=0 skipped=0）、entity 反射加载+激活+EntityRoute 经 PluginRouteScanner 注册（success=2/failed=0）、SkillBridge 正常（doc-summary 技能注册 / entity 纯 Service 态）、PluginSyncBridge 正常跳过等待首扫——**晋级门槛"第一个真实新插件不经框架代码修改上线"正式达成**；附带修复 HTTPServer.start() 三处重复注册（/hello 硬编码与 SkillRoutes 重复、webmcp WS 路径 libRouter 注册与 WebMCPRoutes 应用层路由重复，WebSocket 升级实际由顶层 handler 委托 _webSocketRoutes，libRouter 侧注册冗余已删除）；注意：插件系统日志经 LogUtils 输出至 LOG_FILE（logs/agentskills-runtime.log），不在 cmd 控制台）
> v2.4（2026-08-19 阶段二收尾修订：①PS-T013 首个真实插件 entity 已生成并全量编译通过——plugingen 表驱动模式产出三维一体完整目录（SKILL.md/plugin.yaml/五层代码/入口/路由），阶段二晋级门槛"第一个真实新插件不经框架代码修改上线"编码侧达成，待宿主运行时验证；②PS-T015 build-sync 新增步骤 6：扫描 plugin.yaml 的 entry/routes 自动生成 `src/plugins/generated_anchors.cj` 反射锚点（防 LTO 剪除反射类），此后新插件上线零框架改动；③plugingen 修复三类生成缺陷：宏展开 import 缺失（f_data/f_orm）、DateTime 可空字段误强转（对齐宿主注释跳过模式）、std.convert/SqlPartial import 遗漏；④build-sync 修复 Directory.walk 绝对路径切片 bug（改用标记定位法）；⑤本轮实体代码基线：src/plugins/entity/ 7 文件 + 模板修复 + build.cj 锚点机制，全量重编通过）
> v2.3（2026-08-19 fountain 研究修订，见 review-report.md §0：①PS-T002 反射验证风险降级——fountain 框架 28 处生产级 std.reflect 先例（ClassTypeInfo.get/findAnnotation/PackageInfo.load 全有实证），验证目的调整为 magic 包跨包场景确认；②PS-T004 复用 f_base.TypeInfos/TypeMemberInfos 反射缓存 + isSubtypeOf 调用顺序约束；③PS-T001 ServiceRegistry 增加 getService\<T\>() 泛型接口（参考 BeanFactory.getFirst\<T\>）；④PS-T012 参考 f_app.App.run() 完整 L2 实现）
> v2.2（2026-08-19 复核修订，见 review-report.md：①PS-T002 新增反射最小验证子任务（全项目零反射使用先例，风险前移）；②PS-T005 与 design.md 统一为"独立实现、EventKind 语义对齐"（问题#5）；③PS-T008 SkillBridge 依赖改为 SkillManagementService（问题#1）；④PS-T012 验收标准补动态库文件名=包名约束（问题#3）；⑤PS-T001 验收标准补服务命名契约（问题#6））
> v2.1（2026-08-18 修订：①PS-T013 由"crudgen 适配"改为"新建 plugingen，crudgen/crudweb 保留不重构"；②新增 PS-T018 PluginSyncBridge（agent_skills 表零 DDL 回写）；③数据库变更声明补充 agent_skills 复用结论）
> 上游：spec.md v2 / design.md v2；路标依据：可行性报告附7.9.2（存量冻结、增量插件化）

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考（如 `src/interaction/memory_provider.cj` 的接口模式、`src/app/core/annotations/AutoRoute.cj` 的注解模式）
- 插件系统源码位于 `src/plugin/` 目录（新领域包 `magic.plugin`），不混入现有包；插件代码包名用 `magic.plugins.{name}`（复数，与框架包区分）
- **存量零改动红线**：不修改 `src/app/` 任何存量文件；`AutoRouteConfig.cj` 只减不增（详见 design.md §2.8 双轨路由）
- **跨平台纯净约束**：禁止 import `ohos.*` 系统库（含 `ohos.ark_interop`），仅使用仓颉标准库（std.* / stdx.*）
- **目录红线（附7.8）**：插件代码不得放进 `src/skill/`（SkillEngine 引擎包）；新插件的家在项目根 `skills/{name}/`

### 数据库结构变更流程
- 本工程**不涉及数据库变更**（插件注册表为运行时内存结构，见 design.md §2.3）——2026-08-18 复核确认：无新增/变更表需求，故无前置 SQL/CRUD 生成任务
- **agent_skills 表（既有表）复用结论**：无必须 DDL 变更——插件状态回写复用 runtime_status，plugin.yaml 元数据合并进 extra_metadata；可选拓展（is_plugin 过滤列）留待插件市场阶段另议。插件读写该表走 PS-T018 PluginSyncBridge，复用存量 AgentSkillsDAO，不修改 DAO 源码
- 若后续插件市场需要持久化，另立 SDD 处理；届时新表的 CRUD 模块按"增量插件化"原则以插件形态生成（skills/{name}/，用 plugingen），而非追加到 src/app（除非早于阶段二交付，才走宿主 crudgen 通道）
- **crudgen/crudweb 保留不重构**（2026-08-18 决策）：继续作为宿主代码通道——未来宿主功能新增/迭代仍用现有模块机制生成到 src/app 并追加 AutoRouteConfig；插件形态生成由新建 plugingen 承担（PS-T013），两条通道并行独立

---

## 演进路标（2026-08-18 决策：存量冻结、增量插件化）

存量 `src/app` 模块（harness 与框架运行核心）与 `AutoRouteConfig.cj` 不迁移不重构，视为宿主本体；插件机制仅面向新插件。任务与阶段的映射：

| 阶段 | 版本锚点 | 任务 | 晋级门槛 |
|------|---------|------|---------|
| 阶段一：插件框架核心 | v0.5 | PS-T001~T009、T011、T014（P0） | 集成测试全绿，存量功能回归无损（src/app 零改动） |
| 阶段二：增量插件化就位 | v0.6 | PS-T010、T013（plugingen）、T015、T016、T018（P1） | 第一个真实新插件不经框架代码修改上线 |
| 阶段三：L2 动态加载 | v0.7~v0.9 | PS-T017（SPI 抽取，硬前置）、PS-T012（L2 原型） | 不重编宿主装上一个新插件 |
| 阶段四：插件市场 | v1.0/v1.1 | 另立 SDD（市场基础设施） | 第三方可独立发布插件 |

决策记录详见 `docs/ref/cangjie-plugin-system-feasibility.md` 附7.9。

---

## 任务总览

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 | 阶段 | 状态 |
|--------|---------|--------|---------|------|------|------|
| PS-T001 | Plugin接口与PluginContext | P0 | 0.5天 | 无 | 一 | ⏳待完成 |
| PS-T002 | @Plugin注解定义 | P0 | 0.5天 | 无 | 一 | ⏳待完成 |
| PS-T003 | PluginRegistry注册表 | P0 | 1天 | PS-T001 | 一 | ⏳待完成 |
| PS-T004 | PluginLoader反射加载器 | P0 | 1天 | PS-T002, PS-T003 | 一 | ⏳待完成 |
| PS-T005 | PluginEventBus事件总线 | P0 | 1天 | PS-T001 | 一 | ⏳待完成 |
| PS-T006 | PluginConfigParser配置解析 | P0 | 0.5天 | 无 | 一 | ⏳待完成 |
| PS-T007 | PluginManager总控与启动接入 | P0 | 1天 | PS-T003~T006 | 一 | ⏳待完成 |
| PS-T008 | SkillBridge插件技能融合 | P0 | 1天 | PS-T007, 依赖skill工程 | 一 | ⏳待完成 |
| PS-T009 | 示例插件（2个） | P0 | 0.5天 | PS-T007 | 一 | ⏳待完成 |
| PS-T011 | 集成测试与验证 | P0 | 1天 | PS-T001~T009, T014 | 一 | ⏳待完成 |
| PS-T014 | @ModuleRoute注解与PluginRouteScanner | P0 | 1天 | PS-T004, PS-T007 | 一 | ⏳待完成 |
| PS-T010 | Agent自引用工具（3个） | P1 | 1天 | PS-T007 | 二 | ⏳待完成 |
| PS-T015 | 插件目录build-sync构建钩子 | P1 | 1天 | PS-T007, PS-T014 | 二 | ⏳待完成 |
| PS-T013 | plugigen插件生成工具（crudgen保留） | P1 | 1.5天 | PS-T007, PS-T009, PS-T014, PS-T015 | 二 | ⏳待完成 |
| PS-T016 | package_release插件清单打包适配 | P1 | 0.5天 | PS-T015 | 二 | ⏳待完成 |
| PS-T018 | PluginSyncBridge插件状态库同步 | P1 | 1天 | PS-T005, PS-T007, PS-T008 | 二 | ⏳待完成 |
| PS-T017 | plugin-spi抽取与插件独立包化 | P1 | 2天 | PS-T001~T008 稳定 | 三 | ⏳待完成 |
| PS-T012 | L2动态库加载原型 | P1 | 1.5天 | PS-T003, PS-T004, PS-T017 | 三 | ⏳待完成 |
| PS-T019 | pluginuninstall插件卸载工具 | P1 | 2天 | PS-T007, PS-T013, PS-T015, PS-T018 | 三 | ⏳待完成 |
| PS-T020 | build-sync删除检测增强 | P2 | 0.5天 | PS-T015 | 三 | ⏳待完成 |
| PS-T021 | 卸载集成测试与验证 | P1 | 1天 | PS-T019, PS-T020 | 三 | ⏳待完成 |

---

## PS-T001: Plugin接口与PluginContext

**描述**: 定义插件抽象与生命周期载体，是插件系统的心脏。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义 `Plugin` 接口（getName/onLoad/onActivate/onDeactivate/onUnload）
2. 定义 `PluginState` 枚举（Pending/Loading/Active/Error/Disposed）
3. 定义 `PluginError` 枚举（DuplicatePlugin/DependencyMissing/AnnotationInvalid/InstantiationFailed/NotFound）
4. 定义 `PluginContext` 类（pluginName/serviceRegistry/eventBus/skillBridge/config + onCleanup 逆序清理栈）
5. 定义 `PluginRuntimeInfo` 类（插件实例+状态+注解+订阅事件+错误信息）
6. 定义 `ServiceRegistry` 基础版（registerService/getService/listServices）

**关键文件**:
- `src/plugin/plugin.cj` — Plugin 接口
- `src/plugin/plugin_context.cj` — PluginContext
- `src/plugin/plugin_state.cj` — PluginState/PluginError
- `src/plugin/plugin_runtime_info.cj` — PluginRuntimeInfo
- `src/plugin/service_registry.cj` — ServiceRegistry

**验收标准**:
- [ ] Plugin 接口五方法齐全，与 design.md §2.2.2 一致
- [ ] PluginState 五态齐全（Pending/Loading/Active/Error/Disposed）
- [ ] PluginContext 持有三合一容器句柄（ServiceRegistry/EventBus/SkillBridge）与 onCleanup 清理栈
- [ ] ServiceRegistry 可注册/查询/列出服务
- [ ] 服务命名契约落地：注册名为服务接口全限定名，getService 消费方按接口类型检查后转换，失败记 ERROR 日志并返回 None（v2.2，design.md §2.2.2 服务命名契约）
- [ ] v2.3：ServiceRegistry 提供 `getService<T>(): Option<T>` 泛型类型安全接口（TypeInfo 索引+模式匹配转换，参考 f_bean.BeanFactory.getFirst<T> 模式）
- [ ] 编译通过

---

## PS-T002: @Plugin注解定义

**描述**: 定义插件声明注解，语法参照现有 `@AutoRoute`（@Annotation + const init + let 字段）。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 参照 `src/app/core/annotations/AutoRoute.cj` 定义 `@Plugin` 注解（类名 `PluginAnnotation`，使用语法 `@PluginAnnotation[name: "...", ...]`）
2. 字段：name（String）/ version（String）/ dependencies（**String，逗号分隔**——仓颉 const 表达式不支持 `Array<String>` 注解参数，官方文档明确 const 的 Array 字面量"不能是 Array 类型，仅 VArray 可用"；加载时按逗号拆分为 `Array<String>`）
3. const init 构造器（类不能为 abstract/open/sealed，字段必须为 let 且无 var 成员——const init 的 class 规则）
4. 编写一个最小注解使用示例（验证语法）
5. **反射最小验证（v2.2 新增，v2.3 风险降级）**：编写最小验证程序——临时类标注 @PluginAnnotation → `ClassTypeInfo.get(全限定名)` → `findAnnotation<PluginAnnotation>()` 读回字段 → `ConstructorInfo.apply` 实例化并 `as Plugin` 转换，全链路 try/catch 打印结果。**v2.3 修正：原"全项目零反射使用先例"论断有误**——fountain 框架（libs/fountain，已在依赖中）有 28 处生产级 std.reflect 使用（f_bean/BeanFactory.cj 的 findAnnotation<BeanMeta>、f_app/App.cj 的 ClassTypeInfo.get+try-catch 降级），相关 API 均已验证可行（见 review-report.md §0）。验证目的调整为：确认 **magic 包内**跨包（src/plugin ↔ src/plugins）场景行为；验证程序可直接参考 fountain 现成代码编写

**关键文件**:
- `src/plugin/plugin_annotation.cj` — PluginAnnotation
- `src/plugin/integration/plugin_system_check.cj` — 反射与全流程集成验证（原计划 src/plugin/tests/reflection_probe.cj 已并入此处；注意文件名严禁以 _test.cj 结尾——cjpm build 按官方规则排除单元测试文件，会导致 package-configuration 报 can not find the package）

**验收标准**:
- [ ] @Plugin 注解可编译
- [ ] 字段不可变（let），const init 构造
- [ ] 示例类标注 @Plugin 后编译通过
- [ ] 反射最小验证通过：ClassTypeInfo.get + findAnnotation 能读回注解字段，ConstructorInfo.apply 能实例化（含跨包场景）；若验证失败，立即上报并重新评估 PS-T004 技术方案，不带病推进

---

## PS-T003: PluginRegistry注册表

**描述**: 实现插件注册表：注册/查询/注销/快照回滚/幂等加载。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现 `PluginRegistry` 类
2. `register`：同名已存在返回已存在实例（幂等），不重复执行 onLoad
3. `get` / `list` / `listAll`：按名/按状态/全量查询
4. `unregister`：注销并触发逆序清理（先 onDeactivate 后 onUnload）
5. `snapshot` / `restore`：注册表快照与回滚
6. 内部用 HashMap\<String, PluginRuntimeInfo\> 存储

**关键文件**:
- `src/plugin/plugin_registry.cj`

**验收标准**:
- [ ] 同名插件重复注册返回同一实例且 onLoad 只执行一次
- [ ] 按名/按状态/全量查询正确
- [ ] 注销触发 onDeactivate → onUnload 顺序
- [ ] 快照恢复后注册表状态与快照一致

---

## PS-T004: PluginLoader反射加载器

**描述**: 实现基于反射的插件加载器：按类全名发现→校验注解→实例化。（使用cangjie-coder技能编写仓颉代码，需查阅仓颉反射文档）

**子任务**:
1. 查阅仓颉反射 API：`ClassTypeInfo.get(String)` / `ClassTypeInfo.findAnnotation<T>()` / `ConstructorInfo.apply(args)`——**v2.3：这些 API 在 fountain 框架均有生产级使用先例可直接参考**（`f_bean/BeanFactory.cj` L124 的 findAnnotation 读 BeanMeta 模式、`f_app/App.cj` L133-137 的 ClassTypeInfo.get+try-catch 优雅降级模式）
2. 实现 `PluginLoader.load(className, context)`：
   - `ClassTypeInfo.get(className)` 按类全名查类型（`public redef static func get(qualifiedName: String): ClassTypeInfo`）——**v2.3：优先经 f_base.TypeInfos.get(qualifiedName) 缓存（ConcurrentHashMap+双检锁），避免重复解析**；类型不存在用 try-catch 包裹走优雅降级（f_app/App.cj 模式）
   - `findAnnotation<PluginAnnotation>()` 获取注解声明（返回 `Option<PluginAnnotation>`，`where T <: Annotation`）
   - 校验注解 name 与 plugins.yaml 一致
   - 校验 `dependencies`（逗号拆分后）依赖已注册
   - `ConstructorInfo.apply(args: Array<Any>): Any` 实例化（无参构造优先，支持按注解注入）——**返回 `Any` 且可能抛反射异常（InfoNotFoundException 等），需 try/catch 包装并 `as Plugin` 转换**
   - **v2.3 实战约束（fountain BUG 经验）**：凡组合条件判断中调用 `isSubtypeOf`，必须放在条件表达式最后（f_bean/BeanFactory.cj L52 注释实证：调用 isSubtypeOf 会导致得不到类实现的直接接口）
3. 依赖缺失 → 返回 `DependencyMissing` 错误
4. 注解非法/实例化失败 → 对应错误码
5. 实例化后绑定 PluginContext

**关键文件**:
- `src/plugin/plugin_loader.cj`

**验收标准**:
- [ ] 可按类全名加载并实例化插件
- [ ] 注解 name/version/dependencies 正确读取
- [ ] 依赖缺失正确返回 DependencyMissing
- [ ] 重复加载返回幂等结果
- [ ] 反射调用在热路径之外（仅启动时/显式激活时）

---

## PS-T005: PluginEventBus事件总线

**描述**: 实现插件协作事件总线：emit 广播 + waterfall 链式 + 订阅与插件生命周期绑定。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现 `PluginEventBus` 类
2. `subscribe(pluginName, eventType, handler, priority!)`：记录订阅者与插件绑定。**注意仓颉参数顺序规则："非命名参数须在命名参数之前"——`priority!: Int32 = 0` 必须放在参数列表末尾，不能插在 `handler`（非命名函数参数）之前**
3. `emit(eventType, payload)`：广播分发，按 priority 排序，收集结果
4. `waterfall(eventType, initial)`：链式分发，前一个返回值作为后一个入参
5. `unsubscribeAll(pluginName)`：插件卸载时清理全部订阅
6. 与存量 EventHandlerManager 的关系（v2.2 统一口径，见 review-report.md 问题#5）：**独立实现，EventKind 语义对齐**——PluginEventBus 自建订阅表（插件维度绑定+优先级+waterfall），不直调 EventHandlerManager；事件类型命名对齐存量 EventKind 语义，为 v1.0 后融合留接口

**关键文件**:
- `src/plugin/plugin_event_bus.cj`

**验收标准**:
- [ ] emit 广播所有订阅者且按优先级排序
- [ ] waterfall 链式传递返回值正确
- [ ] unsubscribeAll 后订阅者不再收到事件
- [ ] 订阅者异常不影响其他订阅者（捕获并记录）

---

## PS-T006: PluginConfigParser配置解析

**描述**: 实现 plugins.yaml 解析器，产出插件加载清单。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义 `PluginList` / `PluginEntry` 数据类（name/className/enabled/config/order/routeClass）
2. 实现 `PluginConfigParser.parse(yamlContent)` / `parseFromFile(path)`
3. **复用现有 YAML 解析设施解析 plugins.yaml**：项目已有 `yaml4cj.yaml.decode` + `magic.skill.infrastructure.utils.YamlUtils`，参照 `src/agent_group/yaml_team_config_parser.cj` 的模式（decode → JsonObject → fromJsonValue）。**注意：JSON 解析器无法解析 YAML，不得用 stdx.encoding.json 解析 plugins.yaml**（JsonValue 仅作为解析结果的数据载体）
4. enabled=false 的条目标记跳过（不报错）
5. 未声明 order 时收集 dependencies 供拓扑排序（PS-T007 使用）

**关键文件**:
- `src/plugin/plugin_config_parser.cj`
- `src/plugin/plugin_config_models.cj`

**验收标准**:
- [ ] plugins.yaml 正确解析为 PluginList
- [ ] enabled=false 正确标记跳过
- [ ] config 字段正确注入 JsonValue
- [ ] 缺省 order 时依赖信息正确收集

---

## PS-T007: PluginManager总控与启动接入

**描述**: 实现插件总控：编排加载流程、生命周期管理、启动接入主程序。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现 `PluginManager` 类（registry/loader/eventBus/skillBridge/configParser 组装）
2. `loadAll(configPath)`：解析配置→依依赖拓扑排序→逐个加载→激活→注册技能
3. 依赖拓扑排序：order 显式优先，否则按 dependencies 拓扑
4. `activate(name)`：含依赖校验，成功后触发 onActivate
5. `deactivate(name)`：逆序清理 + 注册表快照回滚
6. `inspect()`：输出可读的插件状态报告（Agent 工具用）
7. 启动接入：在 `src/app/main.cj` 启动流程中初始化 PluginManager 并 loadAll（**存量注册流程不动，插件加载排在其后**）
8. 错误处理：单插件加载失败不阻塞其他插件（记录错误，继续）

**关键文件**:
- `src/plugin/plugin_manager.cj`
- `src/app/main.cj`（仅追加插件初始化调用，不改存量逻辑）

**验收标准**:
- [ ] loadAll 按配置正确加载启用的插件
- [ ] 依赖顺序正确（被依赖者先加载）
- [ ] 单插件失败不阻塞整体启动
- [ ] activate/deactivate 正确流转状态
- [ ] inspect 输出包含插件名/状态/依赖/服务/技能

---

## PS-T008: SkillBridge插件技能融合

**描述**: 实现插件技能桥：插件目录内 SKILL.md 自动注册到 SkillRegistry（神经系统衔接）。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现 `SkillBridge` 类
2. `registerPluginSkills(pluginDir, pluginName)`：扫描插件目录内 SKILL.md
3. **复用 SkillManagementService.loadSkillsFromDirectory 加载插件目录技能**（v2.2 修订，见 review-report.md 问题#1：原方案的 ProgressiveSkillLoader 仅面向全局技能根目录批量扫描，无按单插件目录加载入口；且 SkillRegistrationService.registerSkill 入参为 Skill 对象而非 SkillManifest，两者无法衔接。loadSkillsFromDirectory 内部已含 SKILL.md 解析（YAML frontmatter）→ manifest 校验 → Skill 实例创建（SkillRegistry 工厂 + BaseSkill 兜底）完整管线）
4. 逐个调用 `SkillManagementService.registerSkill(skill, skillManager)` 注册到 SkillManager（存量方法已含异常处理）；返回注册技能数量，SKILL.md 缺失时返回 0（纯 Service 插件）
5. `buildCapabilityCatalog(pluginName)`：生成 AI 可消费的插件能力目录（名称/服务/技能/参数/示例）

**关键文件**:
- `src/plugin/skill_bridge.cj`

**验收标准**:
- [ ] 插件目录内 SKILL.md 自动注册到 SkillManager（v2.2：经 SkillManagementService 存量管线，非另建注册通道）
- [ ] 无 SKILL.md 的插件正常以纯 Service 态运行
- [ ] 能力目录可被 Agent 读取（JSON 格式）
- [ ] 与现有技能加载管线一致（不另造技能体系）

---

## PS-T009: 示例插件（2个）

**描述**: 编写 2 个示例插件（in-tree，位于 src/examples/plugins/），演示 L1 反射加载、插件技能融合与插件路由。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. `HelloPlugin`（纯 Service 插件）：注册 `greeting` 服务，无 SKILL.md
2. `DocHelperPlugin`（Service + Skill + Route 插件）：注册 `doc-summary` 工具服务 + 携带 SKILL.md（描述文档总结能力）+ 一个 @ModuleRouteAnnotation 路由（供 PS-T014 双轨验证）
3. 编写示例插件目录结构（src/plugins/hello/、src/plugins/doc_helper/，另有 src/plugins/pkg.cj 目录标记使 cjpm 递归扫描）
4. 编写 plugins.yaml 示例（含 enabled 开关与 config 注入）
5. 验证：两个插件均可通过 plugins.yaml 启停

**关键文件**:
- `src/plugins/hello/` — HelloPlugin（包 magic.plugins.hello）
- `src/plugins/doc_helper/` — DocHelperPlugin（包 magic.plugins.doc_helper）+ 项目根 plugins/doc-helper/SKILL.md
- `config/plugins.yaml` — 示例配置

**验收标准**:
- [ ] HelloPlugin 通过反射加载并注册服务
- [ ] DocHelperPlugin 加载后 SKILL.md 自动注册
- [ ] DocHelperPlugin 路由经 PluginRouteScanner 注册并可访问
- [ ] plugins.yaml 置 enabled=false 后插件不加载
- [ ] config 参数正确注入 PluginContext.config

---

## PS-T014: @ModuleRoute注解与PluginRouteScanner（阶段一，双轨并存）

**描述**: 实现插件路由的第二通道：@ModuleRoute 注解声明 + 运行时反射注册，与存量 AutoRouteConfig 双轨并存。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义 `ModuleRouteAnnotation` 注解（basePath/table/database/controllerClass，const init，语法参照 @Plugin）
2. 实现 `PluginRouteScanner.scanAndRegister(router, pluginManager)`：
   - 从 plugins.yaml 的 routeClass / plugin.yaml 的 routes 收集 Route 类全名
   - `ClassTypeInfo.get` → `findAnnotation<ModuleRouteAnnotation>` → `ConstructorInfo.apply` 实例化 Route
   - 反射实例化 controllerClass 对应 Controller，调用 `route.register(router, controller)`
   - 全程 try/catch，单条路由失败记录日志不阻塞
3. 启动接入：在存量 AutoRouteRegistry.registerAllRoutes() **之后**调用（只追加，不修改存量注册）
4. 冲突处理：依赖 HTTPServer 已有路由去重逻辑，重复注册记录警告
5. 编写一个最小路由示例（DocHelperPlugin 内，见 PS-T009）

**关键文件**:
- `src/plugin/module_route_annotation.cj`
- `src/plugin/plugin_route_scanner.cj`

**验收标准**:
- [ ] @ModuleRoute 注解可编译且可被反射发现
- [ ] 插件路由运行时注册成功，API 可访问
- [ ] 存量 AutoRouteConfig 路由不受影响（双轨并存）
- [ ] 单条路由注册失败不阻塞其他路由
- [ ] `AutoRouteConfig.cj` 无任何修改（红线验证）

---

## PS-T011: 集成测试与验证

**描述**: 编写插件系统集成测试，覆盖生命周期、幂等、回滚、事件、技能融合、双轨路由。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 生命周期测试：PENDING→LOADING→ACTIVE→DISPOSED 全流程
2. 幂等测试：同名插件重复注册无副作用
3. 回滚测试：模拟依赖缺失/实例化失败，注册表恢复快照
4. 事件测试：emit 广播与 waterfall 链式正确性
5. 技能融合测试：插件 SKILL.md 自动注册并可被技能系统发现
6. 配置测试：enabled=false 不加载、config 注入正确
7. 不变量测试：跨平台纯净性（源码扫描无 ohos.* import）
8. 双轨路由并存测试：插件路由（PluginRouteScanner 反射注册）与存量路由（AutoRouteConfig 硬编码注册）同时加载，无冲突、无重复注册（HTTPServer 去重逻辑兜底），存量 API 响应回归无损
9. 端到端测试：启动→加载插件→Agent 调用插件工具→停用插件

**验收标准**:
- [ ] 全部测试通过
- [ ] 生命周期状态流转正确
- [ ] 幂等/回滚/事件/技能融合验证通过
- [ ] 源码扫描确认无 ohos.* 依赖
- [ ] 双轨路由并存无冲突，存量 API 回归无损（**存量 src/app 模块零改动的直接验证**）
- [ ] 端到端流程跑通

---

## PS-T010: Agent自引用工具（3个）（阶段二）

**描述**: 实现 Agent 可调用的插件管理工具（对应 dsh tool-cordis 的自引用设计）。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. `plugin_inspect`：检视已注册插件/状态/依赖/服务/技能（调用 PluginManager.inspect）
2. `plugin_activate`：激活指定插件（含依赖校验）
3. `plugin_deactivate`：停用指定插件（逆序清理 + 快照回滚）
4. 工具注册进现有工具管线（复用 tool 工程注册机制）
5. 输出格式为结构化文本（Agent 易解析）

**关键文件**:
- `src/plugin/plugin_agent_tools.cj`
- 工具注册点（`src/tool/` 或等价位置）

**验收标准**:
- [ ] 三个工具可被 Agent 正常调用
- [ ] plugin_inspect 输出包含插件名/状态/依赖/服务/技能
- [ ] plugin_activate 对依赖缺失插件返回明确错误
- [ ] plugin_deactivate 后插件状态正确流转为 Disposed

---

## PS-T015: 插件目录build-sync构建钩子（阶段二）

**描述**: 实现 skills/{name}/ → src/generated/skill-plugins/ 的构建期同步（附7.8.1 方案三），让插件代码物理住在 skills/ 又能被 cjpm 编译。（修改 build.cj，使用cangjie-coder技能）

**子任务**:
1. 实现 `PluginBuildSync` pre-build 步骤（追加到 build.cj 现有"下载 stdx"之后）：
   - 扫描 `skills/*/plugin.yaml`，识别含 `scripts/cj/` 的插件
   - 复制 `skills/{name}/scripts/cj/` → `src/generated/skill-plugins/{name}/`
   - 自动生成各级 `pkg.cj` 占位与包声明映射（`magic.plugins.{name}` 及其子包）
   - 校验 plugin.yaml 的 dependencies 对应 skills/{dep}/ 目录存在
2. `src/generated/` 加入 .gitignore（构建产物，不入库）
3. 增量同步：比对文件哈希，未变更的插件不重复复制（保护增量编译缓存）
4. 清理孤儿：skills/ 中已删除的插件对应 generated 目录同步移除
5. 验证：完整构建（clean build）与增量构建（cjpm -i）均通过

**关键文件**:
- `build.cj`（追加 pre-build 步骤）
- `skills/entity/` 等首个真实插件目录（配合 PS-T013）

**验收标准**:
- [ ] skills/{name}/scripts/cj/ 的代码经同步后参与编译
- [ ] 各级 pkg.cj 占位自动生成，cjpm 无"目录被忽略"警告
- [ ] 修改 skills/ 源码后增量构建生效
- [ ] 删除 skills/ 插件后 generated 目录同步清理
- [ ] src/generated/ 不入库

---

## PS-T013: plugingen插件生成工具（阶段二；crudgen/crudweb保留不重构）

**描述**: 新建与 crudgen 同构的确定性插件生成工具 plugingen——从模板生成新插件的三维一体目录。**crudgen/crudweb 源码零改动**，完整保留为宿主代码通道（未来宿主功能新增/迭代继续用现有模块机制生成到 src/app）。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 参照 crudgen 架构（TemplateEngine + templates/ + 从 db_info 读表结构）搭建 plugingen 骨架，位置 `src/plugin/tools/plugingen/`（magic.plugin 包，不放 src/app）
2. 编写插件模板集 `src/plugin/tools/plugingen/templates/`：
   - `SKILL.md.tpl`（技能模板：表结构描述 + CRUD 能力说明）
   - `plugin.yaml.tpl`（插件清单：name/version/dependencies/entry/tables/routes，见 design.md §2.5）
   - `Model.cj.tpl` / `DAO.cj.tpl` / `Service.cj.tpl` / `Controller.cj.tpl` / `Route.cj.tpl`（五层，Route 模板用 `@ModuleRouteAnnotation` 注解声明，AutoCreateCode 区域机制保持）
   - `PluginEntry.cj.tpl`（@Plugin 入口类，onLoad 中组装 Service/Controller）
   - `pkg.cj.tpl`（包占位）
3. 支持两种输入：表名（从 db_info 读表结构生成五层 CRUD 插件）/ 空白插件骨架（--blank）
4. 输出到 `skills/{name}/`（scripts/cj/ 五层 + @Plugin 入口 + @ModuleRoute Route + pkg.cj 占位）
5. 生成后自动追加 plugins.yaml 条目（或提示开发者手动追加）
6. crudgen/crudweb 零改动验证：git diff 确认 src/app/tools/ 无变更

**关键文件**:
- `src/plugin/tools/plugingen/plugingen.cj` — 入口
- `src/plugin/tools/plugingen/PluginGenerator.cj` — 生成器
- `src/plugin/tools/plugingen/TemplateEngine.cj` — 模板引擎（参照 crudgen 同名实现）
- `src/plugin/tools/plugingen/templates/` — 模板集

**验收标准**:
- [ ] 对一张新表执行 plugingen，产出完整插件目录（SKILL.md + plugin.yaml + scripts/cj/ 五层 + 入口类）
- [ ] 也支持 --blank 生成空白插件骨架
- [ ] 构建后插件路由经 PluginRouteScanner 注册成功，API 可访问
- [ ] `AutoRouteConfig.cj` 无任何新增行
- [ ] crudgen/crudweb 源码零改动（git diff src/app/tools/ 为空）
- [ ] 用 crudgen 生成一个宿主模块仍正常走存量通道（并行通道互不干扰验证）

---

## PS-T016: package_release插件清单打包适配（阶段二）

**描述**: package_release 打包工具适配插件产物与插件清单。

**子任务**:
1. 插件产物识别：`src/generated/skill-plugins/` 编译出的 .cjo/.dll 自动收集（Directory.walk 已递归扫描 target/release/magic/ 全目录，验证插件产物路径被覆盖）
2. 插件清单打包：将 `skills/*/plugin.yaml` 复制到发布包 `bin/plugins/{name}/plugin.yaml`
3. 发布包目录结构保持 `plugins/{name}/`（便于按需启用/禁用）
4. post-build 生成 `plugin_manifest.json`（记录所有已编译插件的元信息：name/version/entry/routes/tables）
5. 排除规则核对：examples 插件产物仍被排除（沿用现有 shouldExcludeDll）

**关键文件**:
- `src/scripts/package_release/main.cj`

**验收标准**:
- [ ] 发布包含插件编译产物与 plugin.yaml 清单
- [ ] plugin_manifest.json 内容与实际插件一致
- [ ] examples 产物不被打包
- [ ] 发布包解压后可正常运行（插件加载 + 路由可达）

---

## PS-T018: PluginSyncBridge插件状态库同步（阶段二）

**描述**: 新增插件侧同步桥——把插件运行态与 plugin.yaml 元数据回写 agent_skills 表，使数据库反映插件最新状态；**不改动存量 sync 服务**（src/app/services/sync/ 零改动，存量双向同步回归无损）。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现 PluginSyncBridge（design.md §2.3 签名）：订阅 EventBus 插件生命周期事件（Activated/Deactivated/Error/Unloaded）
2. 状态回写：PluginState → `agent_skills.runtime_status`（按 name 匹配；agent_skills 无对应行时跳过，等存量 SyncManager 首扫建行）
3. 元数据合并：plugin.yaml 的 entry/tables 以读-改-写方式合并进 `agent_skills.extra_metadata`（保留其他键，带 plugin:true 标记）
4. 失败降级：回写异常只记日志 + sync_status=error，**不阻断插件生命周期**（同步是观测面不是控制面）
5. 单向红线验证：Bridge 无任何"库 → plugin.yaml"回写路径；存量 syncToFileSystem 行为不变（只回写 SKILL.md）
6. 表结构零变更验证：本任务与全工程不执行任何 DDL（可选拓展 is_plugin 列留待市场阶段另议）

**关键文件**:
- `src/plugin/plugin_sync_bridge.cj` — PluginSyncBridge
- 复用 `AgentSkillsDAO`（只读复用存量 DAO 做更新，不改 DAO 源码）

**验收标准**:
- [ ] 插件激活/停用后 agent_skills.runtime_status 及时更新
- [ ] extra_metadata 合并正确（保留原有键，写入 entry/tables/plugin 标记）
- [ ] 回写失败不影响插件运行（拔库测试）
- [ ] agent_skills 表结构无任何变更（无 DDL 执行）
- [ ] 存量 sync 双向机制回归无损（SKILL.md 修改→库更新、库修改→SKILL.md 回写均正常）
- [ ] plugin.yaml 修改后重新加载，元数据合并不覆盖 extra_metadata 其他键

---

## PS-T017: plugin-spi抽取与插件独立包化（阶段三硬前置）

**描述**: 抽取 `libs/plugin-spi` 独立基础包，并把插件目录从方案三（build-sync）升格为方案二（独立 cjpm 包）——首个 L2 动态库插件开发前的必做重构。

**方案 B 决策（2026-08-24，见附7.11）**：采用轻量级方案——插件目录 `skills/{name}/` 增加自有 `cjpm.toml`（name = `skill_{name}`，output-type = `dynamic`，dependencies = `plugin_spi`），**不修改根 cjpm.toml**（插件不进宿主 cjpm 依赖图）。插件开发者在自己机器上 `cd skills/{name}/ && cjpm build` 预编译为动态库，宿主运行时通过 `PackageInfo.load()` 热加载——全程不修改根 cjpm.toml，不重启宿主进程。开发期保留 build-sync 作为便利（增量编译快、IDE 跳转友好）；发布期用预编译动态库 + `PackageInfo.load()` 热加载。两套机制并存，由 `plugins.yaml` 的 `mode: sync` / `mode: dylib` 配置切换。

**子任务**:
1. ✅ 新建 `libs/plugin-spi` 包（自有 cjpm.toml，参照 libs/yaml4cj 等 20+ path 依赖先例）
2. ✅ 迁入插件面向的稳定 API：Plugin 接口 / PluginAnnotation / ModuleRouteAnnotation / PluginContext 契约 / PluginEventBus 接口 / ServiceRegistry 契约（7 个源文件已就位）
3. ✅ 宿主 magic 包改为依赖 plugin-spi（框架内部实现留在 magic.plugin，SPI 只含契约；`spi_reexport.cj` 通过 `public import` 转发 13 个符号让存量使用方零改动）
4. **插件目录升格（方案 B）**：`skills/{name}/` 增加自有 `cjpm.toml`（name = `skill_{name}`，output-type = `dynamic`，dependencies = `plugin_spi`），**不修改根 cjpm.toml**。插件文件 import 从 `magic.plugin.{...}` 改为 `plugin_spi.{...}`（依赖单向性：插件只依赖 plugin-spi，不依赖宿主 magic 包）
5. **build-sync 双轨保留（方案 B 调整）**：**不退役** build-sync，开发期保留（增量编译快、IDE 跳转友好），发布期用预编译动态库 + `PackageInfo.load()` 热加载。`plugins.yaml` 新增 `mode: sync` / `mode: dylib` 配置切换两种加载机制
6. 反射发现回归验证：ClassTypeInfo.get 跨包查类型在链接后有效，插件加载与路由注册不受影响
7. gradle 式依赖校验：插件包 import 扫描，确认无 `import magic.*`（除 plugin-spi）

**关键文件**:
- `libs/plugin-spi/`（新包，已就位）
- `skills/entity/cjpm.toml`（新建，方案 B 独立预编译配置）
- `skills/feedback/cjpm.toml`（新建，方案 B 独立预编译配置）
- `skills/entity/scripts/cj/*.cj`（import 从 `magic.plugin` 改为 `plugin_spi`）
- `skills/feedback/scripts/cj/*.cj`（同上）
- `config/plugins.yaml`（新增 `mode` 字段切换 sync/dylib）

**验收标准**:
- [ ] plugin-spi 包独立编译通过，宿主与插件包都依赖它
- [ ] 插件包源码扫描无宿主 magic 包 import（依赖单向）
- [ ] 全量测试回归通过（PS-T011 用例无退化）
- [ ] build-sync 钩子移除后构建流程简化且可用

---

## PS-T012: L2动态库加载原型（阶段三）

**描述**: 实现基于 `PackageInfo.load()` 的动态库插件加载原型，验证跨平台运行时装载新插件——"不重编宿主装上新插件"晋级门槛的载体。（使用cangjie-coder技能编写仓颉代码，需查阅仓颉动态加载官方文档）

**前置**: PS-T017 已完成（动态库插件编译期不能依赖宿主 magic 包，必须依赖 plugin-spi）。

**子任务**:
1. 查阅仓颉官方文档"动态加载的使用"（PackageInfo.load / ModuleInfo.load API）；**v2.3：同时研究 fountain 现成实现**——`f_app/src/App.cj` L116-171 已有完整生产级 L2 动态加载（Directory.walk 递归扫描→平台扩展名过滤→正则匹配文件名→`PackageInfo.load(去扩展名路径)`→加载后反射引导），PluginDylibLoader 直接参考此实现（差异：按 plugins.yaml 清单加载而非全目录扫描；走 @PluginAnnotation 注解发现而非硬编码类名）
2. 实现 `PluginDylibLoader`：
   - `PackageInfo.load("path/libxxx")` 加载动态库（.so/.dll/.dylib）
   - **约束（v2.2，见 review-report.md 问题#3）：PackageInfo.load 按文件名判断包名——动态库文件名必须与包名严格一致且不得改名，否则抛"无法找到仓颉动态库模块文件"异常（官方文档注意事项）；plugingen（PS-T013）生成的动态库工程名与 package_release（PS-T016）打包产物名都必须遵守**
   - `TypeInfo.get("包名.类型")` 反射访问其中声明的插件类型
   - 实例化并注册到 PluginRegistry（与 L1 统一管理）
3. 编写一个最小插件动态库（`cjpm init --type=dynamic` 工程，依赖 plugin-spi）
4. 验证：运行时加载动态库 → 反射发现 @Plugin 类 → 实例化 → 注册 → 路由/技能可用
5. 验证卸载/回收行为（dlclose 时对象回收，无崩溃/泄漏）
6. 记录跨平台验证结果（Linux/Windows/macOS 至少当前开发平台跑通）

**关键文件**:
- `src/plugin/plugin_dylib_loader.cj`
- `src/examples/plugins/dylib-sample/` — 最小动态库插件

**验收标准**:
- [ ] 动态库可被运行时加载并反射访问插件类
- [ ] 动态库文件名与包名严格一致（改名后 load 失败的行为已验证并记录，v2.2）
- [ ] 加载的插件注册进 PluginRegistry 且状态正确
- [ ] 不重编宿主完成新插件安装（晋级门槛）
- [ ] 卸载行为验证通过（无崩溃/泄漏）
- [ ] 至少一个平台（建议当前开发平台）跑通
- [ ] 记录结果到 design.md 或单独验证报告

---

## PS-T019: pluginuninstall插件卸载工具（阶段三）

**描述**: 实现与 plugingen 对称的确定性插件卸载工具 `pluginuninstall`，执行"运行时停用 + 静态资产清理 + 数据库痕迹清理"三层完整卸载闭环——阶段二删除 entitygen/feedbackgen 全程手工暴露的缺口。（使用cangjie-coder技能编写仓颉代码）

**设计依据**: spec.md REQ-PS-014 / design.md §2.11 插件卸载设计。

**前置**: PS-T007（PluginManager）、PS-T013（plugingen，卸载需对称删除 plugingen 生成的资产）、PS-T015（build-sync 同步产物）、PS-T018（PluginSyncBridge 数据库同步）。PS-T020（build-sync 删除检测增强）可与 PS-T019 并行开发，PS-T019 依赖 PS-T020 完成后才能实现"反射锚点自动清理"。

**子任务**:

1. **PluginUninstaller 主类**（位于 `src/plugin/tools/pluginuninstall/`，属 magic.plugin.tools 包）：
   - `uninstall(name: String, force!: Bool = false): UninstallReport`
   - 三层卸载顺序：运行时层 → 静态资产层 → 数据库痕迹层
   - 任一层失败不阻断后续层（降级记日志，最终汇总到 UninstallReport）

2. **运行时层卸载**（对应 Cordis fiber.dispose() 撤销所有 effect）：
   - 调用 `PluginManager.deactivate(name)` 停用运行时实例
   - 触发 `onDeactivate` → `onUnload` 生命周期钩子
   - 逆序执行 `PluginContext.runCleanupInReverseOrder()`（逆向清理栈）
   - `PluginRegistry.unregister(name)` 从注册表注销
   - `ServiceRegistry.removeByPlugin(name)` 移除该插件注册的服务
   - `PluginEventBus.unsubscribeAll(name)` 移除该插件的事件订阅
   - `PluginRouteScanner.unregisterByPlugin(name)` 撤销该插件注册的路由
   - L2 形态额外执行 `PluginDylibLoader.unloadDylib(path)`（dlclose）

3. **静态资产层清理**（agentskills-runtime 独有，DSH 不需要）：
   - 删除 `skills/{name}/` 源目录
   - 删除 build-sync 同步产物 `src/generated/skill-plugins/{name}/`
   - 删除编译产物 `target/release/magic/libmagic.plugins.{name}.a` 及对应 `.cjo`
   - 从 `config/plugins.yaml` 加载清单移除该插件条目
   - 从 `src/plugins/generated_anchors.cj` 反射锚点移除该插件的 import 与 entry 注册（依赖 PS-T020 build-sync 删除检测增强）

4. **数据库痕迹层清理**（agentskills-runtime 独有，DSH 不需要）：
   - 清理 `agent_skills` 表中该插件的记录（PluginSyncBridge 当前只做"内存→库回写"，卸载时需主动清理孤儿记录）
   - 清理 `permissions` 表中该插件对应的菜单节点（plugingen 幂等插入的对称删除）
   - 清理 `i18` 表中该插件对应的国际化键（同上对称删除）

5. **卸载安全机制**：
   - **依赖检查**：卸载前遍历 PluginRegistry 中所有插件的 @Plugin.dependencies，查询是否有其他插件依赖该插件，有依赖则拒绝卸载并提示依赖方插件名；`--force` 时按依赖逆序先卸载所有依赖方（对应 Cordis fiber 递归 dispose 子 fiber）
   - **活跃 run 检查**：卸载有 in-flight 业务请求的插件前，等待完成或 `--force` 强制中断（对应 DSH cancelPending + retract）
   - **卸载幂等**：重复卸载同一插件不报错不产生副作用（UNINSTALLING 状态位防重入，对应 Cordis fiber.dispose() 幂等）；卸载一个从未安装的插件返回明确错误而非崩溃

6. **卸载报告输出**：
   - 汇总三层清理结果，输出结构化报告（UninstallReport）
   - 报告包含：清理的文件列表、清理的配置条目、清理的数据库记录、各层失败汇总、卸载总耗时

7. **卸载事件发射点预留**（阶段四完整实现事件溯源）：
   - 卸载过程通过 PluginEventBus 发射 `plugin.uninstall.*` 系列事件（UninstallStarted/RuntimeDeactivated/StaticAssetRemoved/DatabaseTracesRemoved/UninstallCompleted/UninstallFailed）
   - 供 PluginSyncBridge 同步数据库、供管理界面实时展示卸载进度、供事后审计

**关键文件**:
- `src/plugin/tools/pluginuninstall/pluginuninstall.cj` — pluginuninstall CLI 工具主入口
- `src/plugin/tools/pluginuninstall/plugin_uninstaller.cj` — PluginUninstaller 主类
- `src/plugin/tools/pluginuninstall/uninstall_report.cj` — UninstallReport / CleanupResult 报告模型
- `src/plugin/plugin_context.cj` — 增强：`runCleanupInReverseOrder()` 逆向清理栈执行方法（对应 Cordis fiber.dispose()）
- `src/plugin/plugin_route_scanner.cj` — 增强：`unregisterByPlugin(name)` 撤销指定插件注册的路由
- `src/plugin/service_registry.cj` — 增强：`removeByPlugin(name)` 移除指定插件注册的所有服务
- `src/plugin/plugin_sync_bridge.cj` — 增强：`cleanupPluginTraces(name)` 清理 agent_skills 表中该插件的孤儿记录
- `src/plugin/tools/plugingen/plugingen.cj` — 增强：对称删除 permissions/i18 表中该插件对应的菜单节点与国际化键

**验收标准**:
- [ ] `pluginuninstall --name <插件名>` 可完整卸载一个已安装插件
- [ ] 运行时层卸载完整：deactivate → onDeactivate → onUnload → 逆序清理栈 → unregister → removeByPlugin → unsubscribeAll → unregisterByPlugin
- [ ] 静态资产层清理完整：skills/{name}/、src/generated/skill-plugins/{name}/、target 编译产物、plugins.yaml 条目、generated_anchors.cj import 全部清除
- [ ] 数据库痕迹层清理完整：agent_skills、permissions、i18 表中该插件对应记录全部清除
- [ ] 依赖检查生效：卸载被依赖的插件时拒绝并提示依赖方插件名
- [ ] `--force` 级联卸载生效：按依赖逆序先卸载所有依赖方
- [ ] 活跃 run 检查生效：卸载有 in-flight 请求的插件时等待完成或 `--force` 强制中断
- [ ] 卸载幂等性生效：重复卸载同一插件不报错不产生副作用
- [ ] 卸载一个从未安装的插件返回明确错误而非崩溃
- [ ] 卸载报告输出完整：清理的文件列表、配置条目、数据库记录、各层失败汇总、卸载总耗时
- [ ] 卸载事件发射点预留：`plugin.uninstall.*` 系列事件通过 PluginEventBus 发射
- [ ] 不重编宿主完成插件卸载（晋级门槛）
- [ ] 编译通过

---

## PS-T020: build-sync删除检测增强（阶段三）

**描述**: 增强现有 build-sync（PS-T015）使其支持"删除检测"——当 `skills/{name}/` 目录被删除时，自动清理 `src/generated/skill-plugins/{name}/` 同步产物与 `src/plugins/generated_anchors.cj` 中该插件的 import 与 entry 注册。当前 build-sync 只做"新增同步"（追加 import），不检测删除。

**设计依据**: spec.md REQ-PS-014 静态资产层 / design.md §2.11.1 静态资产层。

**前置**: PS-T015（build-sync 现有实现）。

**子任务**:

1. **build-sync 删除检测逻辑**：
   - pre-build 钩子扫描 `skills/*/plugin.yaml`，识别当前存在的插件集合
   - 扫描 `src/generated/skill-plugins/*/pkg.cj`，识别已同步的插件集合
   - 差集（已同步但 skills/ 中不存在）即为待清理的插件
   - 删除 `src/generated/skill-plugins/{name}/` 目录
   - 删除 `target/release/magic/libmagic.plugins.{name}.a` 及对应 `.cjo`

2. **generated_anchors.cj 删除支持**：
   - 当前 build-sync 只追加 import（PS-T015 步骤 6 扫描 plugin.yaml 的 entry/routes 自动生成反射锚点）
   - 增强为：先清空 generated_anchors.cj 中所有插件锚点，再根据当前存在的插件集合重新生成
   - 或：精确删除指定插件的 import 与 entry 注册（更复杂但更安全）

3. **plugins.yaml 删除支持**：
   - 当 build-sync 检测到插件目录被删除时，从 `config/plugins.yaml` 加载清单移除该插件条目
   - 注意：plugins.yaml 可能含手工编辑的注释与配置，删除时需精确定位插件条目

**关键文件**:
- `build.cj` — 增强 PluginBuildSync 的 pre-build 钩子，支持删除检测
- `src/plugins/generated_anchors.cj` — 自动生成，支持删除后重新生成

**验收标准**:
- [ ] 删除 `skills/{name}/` 目录后，下次 build 时自动清理 `src/generated/skill-plugins/{name}/` 与 `target/` 编译产物
- [ ] 删除 `skills/{name}/` 目录后，`generated_anchors.cj` 中该插件的 import 与 entry 注册被自动移除
- [ ] 删除 `skills/{name}/` 目录后，`config/plugins.yaml` 中该插件的条目被自动移除
- [ ] 新增插件仍能正常同步（不破坏现有 build-sync 新增同步功能）
- [ ] 编译通过

---

## PS-T021: 卸载集成测试与验证（阶段三）

**描述**: 为 PS-T019 pluginuninstall 工具与 PS-T020 build-sync 删除检测增强编写集成测试，验证卸载三层模型的完整性与安全性。

**设计依据**: spec.md REQ-PS-014 验收标准 / design.md §2.11 插件卸载设计。

**前置**: PS-T019（pluginuninstall 工具）、PS-T020（build-sync 删除检测增强）。

**子任务**:

1. **卸载完整性测试**：
   - 安装一个测试插件（plugingen --name test-uninstall --table ...）
   - 执行 `pluginuninstall --name test-uninstall`
   - 验证运行时层：PluginRegistry 中无该插件、ServiceRegistry 无该插件服务、EventBus 无该插件订阅、RouteScanner 无该插件路由
   - 验证静态资产层：skills/test-uninstall/ 目录已删除、src/generated/skill-plugins/test-uninstall/ 已删除、target 编译产物已删除、plugins.yaml 无该插件条目、generated_anchors.cj 无该插件 import
   - 验证数据库痕迹层：agent_skills 表无该插件记录、permissions 表无该插件菜单节点、i18 表无该插件国际化键

2. **卸载安全机制测试**：
   - 依赖检查测试：安装两个有依赖关系的插件 A → B（A 依赖 B），执行 `pluginuninstall --name B`，应拒绝卸载并提示 A 依赖 B
   - `--force` 级联卸载测试：执行 `pluginuninstall --name B --force`，应按依赖逆序先卸载 A 再卸载 B
   - 活跃 run 检查测试：向一个插件发送 in-flight 请求，执行 `pluginuninstall --name <该插件>`，应等待请求完成或 `--force` 强制中断
   - 卸载幂等性测试：连续两次执行 `pluginuninstall --name test-uninstall`，第二次不应报错或产生副作用
   - 从未安装插件卸载测试：执行 `pluginuninstall --name never-installed`，应返回明确错误而非崩溃

3. **不重编宿主卸载验证**（晋级门槛）：
   - 运行中的宿主上执行 `pluginuninstall --name <已安装插件>`
   - 验证插件被完整卸载且宿主无需重新编译即可继续运行
   - 验证卸载后宿主其他插件与存量功能回归无损

4. **卸载报告验证**：
   - 执行卸载后检查 UninstallReport 输出
   - 验证报告包含：清理的文件列表、清理的配置条目、清理的数据库记录、各层失败汇总、卸载总耗时

**关键文件**:
- `src/plugin/integration/plugin_uninstall_check.cj` — 卸载完整性集成测试（注意文件名严禁以 _test.cj 结尾——cjpm build 按官方规则排除单元测试文件）
- `src/plugin/integration/plugin_uninstall_safety_check.cj` — 卸载安全机制集成测试

**验收标准**:
- [ ] 卸载完整性测试通过：三层清理后所有痕迹（运行时/文件/配置/数据库）均已清除
- [ ] 依赖检查测试通过：卸载被依赖的插件时拒绝并提示依赖方插件名
- [ ] `--force` 级联卸载测试通过：按依赖逆序先卸载所有依赖方
- [ ] 活跃 run 检查测试通过：等待 in-flight 请求完成或 `--force` 强制中断
- [ ] 卸载幂等性测试通过：重复卸载同一插件不报错不产生副作用
- [ ] 从未安装插件卸载测试通过：返回明确错误而非崩溃
- [ ] 不重编宿主卸载验证通过（晋级门槛）
- [ ] 卸载报告验证通过：UninstallReport 输出完整且准确
- [ ] 卸载后宿主其他插件与存量功能回归无损
