# 插件系统 SDD 文档复核报告

> 复核日期：2026-08-19
> 复核对象：spec.md v2 / design.md v2.1 / tasks.md v2.1
> 复核方法：仓颉语言规范核对（cangjie-language-guide / cangjie-full-docs 技能）+ 项目源码逐项核实 + deepseek-harness（Cordis）对标分析 + **fountain 框架反射基础设施研究（2026-08-19 补充）**
> 复核结论：**文档质量优秀，可以进入实施阶段**；发现 6 项问题（P1×2、P2×2、P3×2），已于 2026-08-19 全部修订入 design.md v2.2 / tasks.md v2.2；**同日补充 fountain 研究，形成 v2.3 修订（复用 fountain 反射设施、ServiceRegistry 类型安全增强）**

---

## 〇、fountain 框架补充研究（2026-08-19，重要修正）

### 0.1 对原复核结论的修正

**原报告论断 #12"全项目无 ClassTypeInfo/findAnnotation/PackageInfo 使用先例"有误**——该结论仅扫描了 `src/` 目录，遗漏了 `libs/fountain`。实测 fountain 框架有 **28 个文件导入 std.reflect**，且全部是生产级用法。此项修正同时影响问题 #2（反射首用风险）的风险评级：**从"未知领域首用"降级为"有成熟生产先例可参考"**。

### 0.2 fountain 反射使用先例清单（与插件系统直接相关）

| API | 使用位置 | 插件系统对应场景 |
|---|---|---|
| `ClassTypeInfo.get(全限定名)` + try-catch 优雅降级 | f_app/src/App.cj L133-137 | PluginLoader 按名发现插件类 |
| `PackageInfo.load(去扩展名路径)` 递归目录扫描 + 正则匹配文件名 | f_app/src/App.cj L116-131 | **L2 动态加载的完整现成参考** |
| `TypeInfo.of<T>().findAnnotation<BeanMeta>()` | f_bean/src/BeanFactory.cj L124 | PluginLoader 读 @PluginAnnotation（**模式完全一致，已验证可行**） |
| `getStaticVariable('instance').getValue()` / `getInstanceFunction(...).apply(instance, [])` | f_app/src/App.cj L139-171 | 反射调用静态/实例方法 |
| `isSubtypeOf` 子类型判断 | 全框架大量使用 | 依赖/接口校验 |
| `TypeMemberInfos.instanceFunction(...)?.findAnnotation<A>()` | f_base/src/TypeInfos.cj L71-73 | 函数级注解查找（PluginRouteScanner 可用） |

**实战 BUG 警告（宝贵经验）**：[BeanFactory.cj](file:///d:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/libs/fountain/f_bean/src/BeanFactory.cj#L52) L52 注释——`调用isSubtypeOf会导致得不到类实现的直接接口，所以把isSubtypeOf放到if条件最后面`。插件系统实现时必须遵守此调用顺序约束。

### 0.3 可复用的 fountain 基础设施（f_bean/f_base 已在 agentskills-runtime 依赖中）

cjpm.toml 已依赖 fountain 七模块：**f_orm、f_data、f_config、f_util、f_ticktock、f_aspect、f_bean**（f_bean 传递依赖 f_base）。

| 组件 | 能力 | 复用方式 |
|---|---|---|
| **f_base.TypeInfos** | 按全限定名取 TypeInfo，ConcurrentHashMap+双检锁缓存；getGenericTypes 泛型参数解析；isInstanceOf | PluginLoader 复用其缓存，避免裸调 ClassTypeInfo.get |
| **f_base.TypeMemberInfos** | 属性/函数/变量全维度成员反射缓存，含继承链处理（沿 superClass 至 Object）与 FuncMeta 函数签名索引 | PluginRouteScanner 扫描插件 Route/Controller 方法 |
| **f_bean.BeanFactory** | IOC 容器：`beanTypeMap: HashMap<TypeInfo, TreeSet<BeanManager>>` 按 TypeInfo 多级索引（BFS 建立父接口/父类/注解索引）；`getFirst<T>()/getList<T>()` 泛型类型安全查找；registered 注册期/使用期分离；check() 条件过滤级联删除；atExit 统一销毁 | **ServiceRegistry 类型安全化的实现蓝本**（解决问题 #6 的更优路径） |
| **f_bean.BeanManager/BeanMeta** | Bean 生命周期：PostConstruct/Destroy 接口、lazy/scope/order/primary/condition 元数据、FactoryBean 工厂、单例双检锁 | 与 Plugin 概念同构（BeanMeta↔PluginAnnotation、PostConstruct/Destroy↔onLoad/onUnload），生命周期实现参考 |
| **f_app.App.run()** | L2 动态加载完整实现：Directory.walk 递归扫描 → 扩展名过滤 → 正则匹配 → `PackageInfo.load(path去扩展名)`；`--dylibPattern=` 自定义模式；try-catch+None 可选组件优雅降级 | **PS-T012 PluginDylibLoader 直接参考**（比官方文档示例更完整：含扫描、匹配、降级、加载后引导） |
| f_bean @Bean 宏 | 编译期生成 `BeanFactory.instance.register<T>{T()}` 顶层匿名闭包，模块加载即自动注册 | 宏注册路线的实证（与反射发现路线对比见 0.4） |

**不可复用项**：f_concurrent.eventbus.EventBus 是**线程池任务执行器**（工作窃取+满队列策略+Worker 线程），非订阅-发布语义，与 PluginEventBus（Cordis 式发布订阅）语义不同，且 f_concurrent 不在当前依赖中——设计文档"PluginEventBus 独立实现"决策维持正确。

### 0.4 架构洞察：fountain 宏注册 vs 插件系统反射发现（两条互补路线）

| 维度 | fountain @Bean 宏注册 | 插件系统 @Plugin 反射发现 |
|---|---|---|
| 注册时机 | 编译期生成代码，模块加载即注册 | 运行时按 plugins.yaml 发现 |
| 发现方式 | 无需清单（自动） | 需 className 清单 |
| 类型安全 | `lookup<T>()` 完全类型安全 | Any 承载（可参考 BeanFactory 改进） |
| 动态启停 | registered 置位后不可变 | 支持激活/停用/依赖管理 |
| AI 融合 | 无 | SKILL.md 三维一体 |
| 适用场景 | 宿主内部组件装配 | 可插拔扩展 |

**结论**：两者互补而非竞争。插件系统 v1 后可考虑桥接——插件注册 Service 时同步注册为 Bean，宿主代码经 `lookup<T>()` 类型安全消费插件能力（design.md v2.3 已记为演进方向）。

### 0.5 fountain 研究对 6 项问题处置的影响

| 问题 | 原处置 | fountain 研究后的调整 |
|---|---|---|
| #1 SkillBridge 依赖 | 改 SkillManagementService | 不变 |
| #2 反射首用风险 | PS-T002 最小验证前移 | **风险降级**：fountain 已验证全部关键 API；验证子任务保留但目的变为"magic 包跨包场景确认"（fountain 验证的是 f_bean 等包），且可直接参考 fountain 现成代码写验证程序 |
| #3 PackageInfo.load 文件名 | PS-T012 验收标准 | **增强**：App.cj 实证加载路径是"去掉扩展名"（`fi.path.toString().replace(ext, '')`），与官方文档示例一致，补充到 PS-T012 |
| #4 状态机触发条件 | §2.1.4 触发条件表 | 不变 |
| #5 PEB/EHM 表述 | 独立实现+语义对齐 | **获新证据支持**：f_concurrent EventBus 亦不可复用（执行器非总线） |
| #6 Service 契约 | String 全限定名+is 检查 | **方案升级（v2.3）**：参考 BeanFactory.getTypeMap 模式，ServiceRegistry 增加 `getService<T>(): Option<T>` 泛型接口（TypeInfo 索引+模式匹配转换），String 名保留为别名兼容 |

---

## 一、仓颉语言规范符合性复核

设计文档中的仓颉代码片段与关键语言论断，逐项对照官方文档验证，**全部通过**：

| # | 设计文档论断 | 官方依据 | 结论 |
|---|---|---|---|
| 1 | 注解类 `@Annotation` + `const init` + `let` 字段模式 | 注解类不能为 abstract/open/sealed；须提供至少一个 `const init`；const init 的 class 不能有 `var` 实例成员变量 | ✅ 与存量 AutoRoute.cj 同构 |
| 2 | `dependencies` 用逗号分隔 String，不用 `Array<String>` | const 表达式规则：Array 字面量"不能是 Array 类型，可以使用 VArray 类型"；VArray 定长不适用 | ✅ 设计正确并注明理由 |
| 3 | `ClassTypeInfo.get(qualifiedName: String): ClassTypeInfo` | std.reflect 官方示例 `ClassTypeInfo.get("test.Rectangular")` | ✅ |
| 4 | `findAnnotation<T>(): Option<T> where T <: Annotation` | std.reflect 包 API 文档 | ✅ |
| 5 | `ConstructorInfo.apply(args: Array<Any>): Any`，可能抛反射异常 | 官方签名一致；可抛 InvocationTargetException / IllegalArgumentException / IllegalTypeException；设计要求 try/catch 包装 + `as Plugin` 转换 | ✅ |
| 6 | `PackageInfo.load(path)` 动态库加载（L2） | 官方"动态加载的使用"文档：`cjpm init --type=dynamic` + `PackageInfo.load("../pkg/target/release/pkg/libpkg")` | ✅ L2 可行性成立 |
| 7 | `priority!: Int32 = 0` 必须尾置 | 函数参数规则："非命名参数须在命名参数之前，命名参数后不能跟非命名参数" | ✅ |
| 8 | §2.3 构造器说明：无默认值成员的类须显式 init | 仓颉自动无参构造器生成条件（未定义构造器且所有实例成员变量有默认初始值） | ✅ |

## 二、代码论断核实（对照项目实际实现）

14 项关键论断核实结果，全部成立（2 项数字/表述需微调）：

| # | 论断 | 核实结果 |
|---|---|---|
| 1 | RouteRegistry 按 priority 排序后调用 registerFunc(router) | ✅ RouteRegistry.cj L28-L62：过滤 enabled + priority 冒泡排序 + registerAll |
| 2 | HTTPServer 有重复路由去重逻辑 | ✅ HTTPServer.cj L122-L145：按 `METHOD\|PATH` 键去重并打印警告 |
| 3 | main.cj 启动流程：AutoRouteRegistry → registerAllRoutes → server.start | ✅ main.cj L489-L490、L643；插件加载插入点明确 |
| 4 | AutoRouteConfig.cj 硬编码集中注册"1364 行" | ⚠️ 实测 **1302 行**，已修订为"约 1300 行"（design.md §1.1.2） |
| 5 | agent_skills 表 54 列，runtime_status / extra_metadata / sync_status / scripts_dir_exists 均存在 | ✅ uctooDB.sql L446-L500；零 DDL 复用结论成立 |
| 6 | 存量 sync 库→文件只回写 SKILL.md | ✅ AgentSkillSyncHandler.cj L83-L110 |
| 7 | SyncManager 按 entityType 分发 handler，agent_skill 有对应 handler | ✅ SyncManager.cj L35-L45 |
| 8 | package_release 递归扫描 target/release/magic/ 收集动态库 | ✅ package_release/main.cj L174-L201 |
| 9 | skills/ 目录 20+ 技能资产 | ✅ 实测 28 个技能目录 |
| 10 | libs/ 有 20+ path 依赖先例（yaml4cj 等） | ✅ 实测 23 个；尚无 plugin-spi（与阶段三规划一致） |
| 11 | yaml4cj 使用模式：decode → JsonObject → fromJsonValue | ✅ yaml_team_config_parser.cj L27-L35 |
| 12 | 全项目无 ClassTypeInfo / findAnnotation / PackageInfo / ConstructorInfo 使用先例 | ✅ 仅 AutoRoute.cj 导入过 std.reflect（只用 Annotation 基类）——反射首用风险成立，已前移验证（tasks.md PS-T002） |
| 13 | SkillRegistrationService / ProgressiveSkillLoader 可复用 | ⚠️ 部分成立：SkillRegistrationService.registerSkill 需 Skill 对象而非 SkillManifest；ProgressiveSkillLoader 公开方法面向全局技能目录批量扫描，**无单插件目录加载能力** → SkillBridge 依赖已改为 SkillManagementService（见问题 #1） |
| 14 | crudgen 架构（TemplateEngine + templates/ + db_info）可作 plugingen 蓝本 | ✅ src/app/tools/crudgen/ 结构属实 |

## 三、设计合理性评估（对标 deepseek-harness / Cordis）

**架构决策质量高，五项关键决策均稳健：**

1. **存量冻结 + 增量插件化**：不动 src/app 一行代码，AutoRouteConfig 只减不增，双轨路由把插件机制风险与存量 1300 行路由注册表完全解耦——优于业界常见的大爆炸重构路径。
2. **三阶段演进**（L1 反射 → build-sync → 独立包 + plugin-spi → L2 动态库）：正确处理静态语言"先编译期注册、后运行时加载"的约束，每阶段有明确晋级门槛。
3. **plugins.yaml（宿主开关）与 plugin.yaml（插件自描述）职责分离**：对应 Cordis 的 Config 与 plugin 定义分离，干净。
4. **Skill-Plugin 三维一体**（Service + Skill + 数据资产同目录）：**超越业界实践的亮点**——Cordis/VSCode 插件只有确定性 Service，本设计让插件天然携带 AI 行为（SKILL.md 经 SkillBridge 自动注册），是 AI-native 插件系统的差异化设计。
5. **不变量表（§2.9）+ Cordis 六语义对照自检（§2.10）**：自我批判意识强，诚实标注"HMR/合流性无定理背书，对外只表述确定性插件生命周期"，不夸大。

**对标结论**：Cordis 是动态语言运行时 fiber 模型（响应式 inject、Proxy ctx、HMR、五种事件分发 emit/parallel/serial/bail/waterfall）。本设计在静态编译语言中以"注解声明 + 反射发现 + 生命周期状态机"覆盖 Cordis 六语义中的五个（Service/inject/effect/Events/检视），事件总线实现 emit/waterfall 两种最常用语义，仅 HMR 延后——是合理的工程近似而非缺陷。

## 四、问题清单与修订记录

以下 6 项问题已全部修订入 SDD 文档（design.md v2.2 / tasks.md v2.2）：

### #1 [P1] SkillBridge 依赖签名与存量 API 不匹配 — 已修订

- **问题**：design.md §2.2.2 SkillBridge 持有 `ProgressiveSkillLoader`，但其公开方法（loadSkillsProgressively / loadSkillsToManager）面向全局技能目录批量扫描，无法按单个插件目录加载；且 `SkillRegistrationService.registerSkill` 需要 `Skill` 对象而非 `SkillManifest`，两者拼不起来。
- **修订**：SkillBridge 依赖改为 **SkillManagementService**（src/skill/application/skill_management_service.cj）。其 `loadSkillsFromDirectory(directoryPath: String): Array<Skill>` 正是按目录批量加载能力，内部已含 manifest 解析（SkillMdLoader）→ 校验（SkillValidationService）→ Skill 实例创建（SkillRegistry 工厂 + BaseSkill 兜底）完整管线；`registerSkill(skill, skillManager): Bool` 已封装 addSkill + 异常处理。SkillBridge 签名同步调整：`registerPluginSkills(pluginDir: String, pluginName: String): Int64`（Path → String，贴合存量 API）。§1.1.2 / §1.2 / §2.1.1 / §2.1.2 图中 PSL 引用同步改为 SMS。
- **修订位置**：design.md §1.1.2、§1.2、§2.1.1、§2.1.2、§2.2.2；tasks.md PS-T008。

### #2 [P1] 反射首用风险 — 已前移验证

- **问题**：全项目零反射 API 使用先例（仅 AutoRoute.cj 导入过 std.reflect 的 Annotation 基类），ClassTypeInfo.get / findAnnotation / ConstructorInfo.apply 的实际行为（尤其跨包场景）未经验证。若 PS-T004 才发现问题，前期 4 个任务可能返工。
- **修订**：PS-T002 增加"反射最小验证"子任务与验收标准：注解定义完成后立即编写最小验证程序（@PluginAnnotation 标注的临时类 → ClassTypeInfo.get → findAnnotation → ConstructorInfo.apply 实例化），在动工 PS-T004 前确认反射链路可行；同时明确 SkillBridge 复用存量管线后已不依赖反射加载技能。
- **修订位置**：tasks.md PS-T002。

### #3 [P2] PackageInfo.load 按文件名判断包名 — 已写入验收标准

- **问题**：官方文档注意事项——PackageInfo.load 根据文件名判断包名，不允许修改动态库文件名，否则抛"无法找到仓颉动态库模块文件"异常。L2 的 plugingen 生成与 package_release 打包若改名即翻车。
- **修订**：PS-T012 验收标准新增"动态库文件名与包名严格一致（PackageInfo.load 按文件名判断包名，官方文档注意事项）"。
- **修订位置**：tasks.md PS-T012。

### #4 [P2] PluginState ACTIVE→ERROR 触发条件未定义 — 已补明

- **问题**：状态机有 `A --> E : 运行时异常(可重试)` 迁移，但何种异常触发（onActivate 抛异常？服务调用异常？事件处理器异常？）未定义，状态机不可测试。
- **修订**：design.md §2.1.4 状态机下补触发条件定义：① onActivate 抛异常 → ERROR（加载期，可修复后重试）；② 事件处理器抛异常 → 仅记日志不影响状态（事件总线捕获）；③ Service 调用异常 → 插件自治，不触发状态迁移。ERROR 态仅由生命周期钩子异常与依赖校验失败触发。
- **修订位置**：design.md §2.1.4。

### #5 [P3] PEB 与存量 EventHandlerManager 关系表述不一致 — 已统一

- **问题**：§2.1.1/§2.1.2 架构图标注"PEB --> EHM 复用事件模型/复用事件分发"，但 tasks.md PS-T005 说"可先独立实现，v1.0 后融合"——两处口径不一。
- **修订**：统一为"**独立实现，EventKind 语义对齐**"：PluginEventBus 自建订阅表（插件维度绑定 + 优先级 + waterfall），不调用存量 EventHandlerManager；事件类型命名对齐存量 EventKind 语义，为 v1.0 后融合留接口。图中 `PEB --> EHM` 改为虚线"语义对齐（不直调）"。
- **修订位置**：design.md §2.1.1、§2.1.2、§1.1.2、§1.2；tasks.md PS-T005。

### #6 [P3] getService: Option<Any> 缺服务契约约定 — 已补约定

- **问题**：ServiceRegistry 以 Any 承载服务实例，若注册名随意（"db"、"db1"、"database"），消费方拿到的 Any 无法安全转换，类型安全形同虚设。
- **修订**：design.md §2.2.2 PluginContext 部分补服务契约约定：注册名必须用**服务接口全限定名**（如 `magic.plugin.spi.MemoryProvider`），实现类须实现同名接口；getService 消费方按接口 `as` 转换，转换失败视为编程错误记 ERROR 日志。PS-T001 验收标准同步补充。
- **修订位置**：design.md §2.2.2；tasks.md PS-T001。

### 附：数字修正

- AutoRouteConfig.cj 行数：文档"1364 行" → 实测 1302 行，统一改为"约 1300 行"（design.md §1.1.2、§2.8）。

## 五、总体结论

**该 SDD 文档可以进入实施阶段。**

- **语言规范**：仓颉代码片段全部符合规范，对 const / 注解 / 反射 / 命名参数等语言细节的把握准确（dependencies 用 String 承载、priority! 尾置、构造器显式声明等易错点均正确规避）。
- **设计合理性**：存量冻结、双轨路由、三阶段演进决策稳健；Skill-Plugin 融合、agent_skills 零 DDL 复用、plugingen/crudgen 双通道三处属于超越业界常规实践的原创设计。
- **复用与兼容**：对存量设施（RouteRegistry / HTTPServer 去重 / SkillManagementService / yaml4cj / sync 管线 / package_release）的复用清单经代码核实真实可用；唯一不匹配项（SkillBridge 依赖）已修订。
- **风险**：反射 API 全项目首用是最大技术风险，验证已前移至 PS-T002；L2 动态加载文件名约束已写入 PS-T012 验收标准。

---

## 六、实际落地复核（2026-08-28，v4.1/v3.0/v2.2 修订依据）

> 阶段一/二/三编码全部完成并编译通过后，对原设计 SDD 的复核回归。本节记录实际落地与原设计的差异，以及因当前架构、fountain 框架、仓颉编程语言方面的原因未能完全对标 deepseek-harness（Cordis）"一切皆插件"理念的限制条件。详细技术设计修订见 design.md §0。

### 6.1 原复核结论的回归验证

| 原复核结论 | 实际落地验证 | 结果 |
|-----------|------------|------|
| 反射 API 全项目首用是最大技术风险 | fountain 28 处生产级 std.reflect 先例证实可行；但 LTO 下 ClassTypeInfo.get 跨包查询会被剪除 | ⚠️ 风险部分兑现，需 generated_anchors.cj 显式锚定 |
| L2 动态加载文件名=包名约束 | PS-T012 plugin_dylib_loader.cj 实现 PackageInfo.load 热加载，文件名约束落地 | ✅ 验证通过 |
| SkillBridge 依赖改为 SkillManagementService | SkillBridge 复用 SkillManagementService.loadSkillsFromDirectory，按插件目录加载技能 | ✅ 验证通过 |
| PluginEventBus 独立实现 + EventKind 语义对齐 | PluginEventBus 自建订阅表 + 优先级 + waterfall，未包装 fountain EventBus（f_concurrent 不在当前依赖中） | ✅ 验证通过 |
| ServiceRegistry getService\<T\> 委托 BeanFactory.getFirst\<T\> | ServiceRegistry.register 委托 BeanFactory.register，getService\<T\> 委托 BeanFactory.getFirst\<T\> | ✅ 验证通过 |
| cordis_define 等价物（运行时定义新插件）受静态语言限制留待 L2 | L2 动态库加载原型实现，但插件仍需预编译为动态库，无法真正"运行时定义" | ⚠️ 部分达成，受架构/语言限制 |
| 双轨路由（存量轨 + 插件轨）双轨并存 | ⚠️ **退化为单轨**：entity/feedback 经 build-sync 同步进宿主内嵌轨（`src/plugins/{name}/`，包名 `magic.plugins.{name}`），由 PluginRouteScanner 注册路由。未实现"不重编宿主装上新插件"的完整双轨形态 | ⚠️ 部分达成，受架构限制 |
| 插件包只依赖 plugin-spi，不 import 宿主 magic 包 | ⚠️ entity/feedback 深度依赖宿主子包（`magic.app.core.*`、`magic.log.*` 等），独立包模式产生循环依赖，无法做到插件包"零宿主依赖" | ⚠️ 部分达成，受架构限制 |

### 6.2 因架构/框架/仓颉语言限制未能完全对标 deepseek-harness 的限制条件

#### 限制 #1：插件无法真正"独立"——cjpm workspace 与 [package] 互斥（架构限制）

**原复核论断**：方案二（阶段三升格）让 `skills/{name}/` 升格为独立 cjpm 包，根 cjpm.toml 追加 `[workspace] members = ["./skills/entity", ...]`，插件以动态库形态独立编译。

**实际限制**：cjpm 规定同一个 `cjpm.toml` 中 `[workspace]` 和 `[package]` **不能共存**。宿主 `cjpm.toml` 既有 `[package]`（name="magic"）又要加 `[workspace]`，编译报错 `only one of 'workspace' or 'package' fields can exist`。fountain fdemo 先例证实：workspace 根 `cjpm.toml` 只有 `[workspace]` 段，没有 `[package]` 段——但我们的宿主本身就是 `magic` 包，不能既是 workspace 根又是 package。

**实际落地方案**：放弃 workspace 成员模式，改用**宿主内嵌轨**——插件源码经 build-sync 同步到 `src/plugins/{name}/`，包名 `magic.plugins.{name}`，属宿主 magic 包编译图。entity/feedback 的 `cjpm.toml`（name="skill_entity"/"skill_feedback"，output-type="dynamic"）保留为独立编译入口，但宿主编译时不引用它们。

**与 DSH 的差距**：DSH 的插件是运行时 fiber，天然独立于宿主进程；agentskills-runtime 的插件是编译期静态资产，必须进入宿主编译图才能被反射发现，无法实现"不重编宿主装上新插件"的完整形态。阶段三 PS-T012 L2 动态库加载原型部分缓解此限制（PackageInfo.load 热加载），但插件仍需预编译为动态库。

#### 限制 #2：插件深度依赖宿主子包——独立包模式产生循环依赖（架构限制）

**原复核论断**：插件包只依赖 `plugin-spi`，不 import 宿主 magic 包（cjpm 依赖单向性）。

**实际限制**：entity 插件源码深度依赖宿主子包：`magic.app.core.http.*`、`magic.app.core.query.*`、`magic.app.core.response.*`、`magic.app.core.router.Router`、`magic.app.utils.PermissionUtils`、`magic.log.LogUtils`。若 entity 升格为独立 cjpm 包（name="skill_entity"），它必须 import 这些宿主子包，但 cjpm 依赖单向——宿主不能依赖 entity（否则循环），entity 又必须依赖宿主 → 循环依赖无解。

**实际落地方案**：entity/feedback 保留对宿主 `magic` 包的依赖（CRUD 插件需要 `magic.app.core.*`、`magic.log.*` 等基础类型），通过宿主内嵌轨编译。独立包模式（skills/entity/cjpm.toml）仅在 L2 动态库预编译场景使用，此时插件动态库符号在运行时由 PackageInfo.load 解析，编译期不检查循环依赖。

**与 DSH 的差距**：DSH 的插件是纯函数 fiber，不依赖宿主内部实现；agentskills-runtime 的 CRUD 插件深度耦合宿主 HTTP/RBAC/日志设施，无法做到插件包"零宿主依赖"。

#### 限制 #3：仓颉反射 API 限制——ClassTypeInfo.get 跨包查询不稳定（语言限制）

**原复核论断**：反射 API 全项目首用是最大技术风险，fountain 28 处生产级先例证实可行，验证前移至 PS-T002。

**实际限制**：仓颉反射 API 在 LTO（链接时优化）下会剪除未被静态引用的类，导致 `ClassTypeInfo.get` 返回 `None`。fountain BeanFactory.cj L52 注释警告：`调用isSubtypeOf会导致得不到类实现的直接接口，所以把isSubtypeOf放到if条件最后面`。此外 `TypeInfo`（fountain `TypeInfos.get()`）缺少 `constructors` 属性，必须保留 `ClassTypeInfo.get()` 才能获取构造器信息。

**实际落地方案**：build-sync 自动生成 `generated_anchors.cj`，显式 import 并实例化插件 Route/Plugin 类（`let _anchor_0 = EntityRoute()`），作为 L1 反射锚点防 LTO 剪除。PluginRouteScanner 仍用 `ClassTypeInfo.get` 反射发现，但依赖锚点保证类不被剪除。

**与 DSH 的差距**：DSH 的 `cordis_define` 是运行时动态定义，无编译期限制；agentskills-runtime 受静态语言 + LTO 限制，插件类必须显式锚定才能被反射发现。

#### 限制 #4：仓颉动态库标准库符号重复——--dy-std 编译选项必需（语言/工具链限制）

**原复核论断**：PS-T012 验收标准补动态库文件名=包名约束（问题#3）。

**实际限制**：仓颉动态库默认静态链接标准库，多个 `.so` 同时加载会重复包含标准库符号，触发 `ld.lld: error: _CGP15xxx was replaced` 符号冲突。必须为动态库编译添加 `--dy-std` 选项，使动态库使用动态链接的标准库。fountain fdemo cjpm.toml 先例证实：`compile-option = "-O2 --dy-std -Woff unused"` + `[target.x86_64-unknown-linux-gnu.bin-dependencies] path-option = ["${CANGJIE_STDX_DYNAMIC_PATH}"]`。

**实际落地方案**：entity/feedback 的 `cjpm.toml` 编译选项统一为 `compile-option = "-O2 --dy-std -Woff all"`。宿主内嵌轨编译不需要 `--dy-std`（静态链接），仅 L2 动态库预编译时需要。

**与 DSH 的差距**：DSH 是单一运行时进程，无动态库符号冲突问题；agentskills-runtime 受仓颉工具链限制，动态库插件必须显式处理标准库链接方式。

#### 限制 #5：插件包名必须为简单标识符——cjpm name 字段约束（工具链限制）

**原复核论断**：dependencies 用 String 承载（不能用 Array<String>）——const 表达式规则。

**实际限制**：cjpm `name` 字段必须是**简单标识符**（如 `plugin_spi`、`skill_entity`），不能是带点号的限定名（如 `magic.plugins.entity`）。fountain 32 个子包均遵循此规范（`f_orm`、`f_data` 等）。

**实际落地方案**：宿主内嵌轨插件包名仍用 `magic.plugins.{name}`（属宿主 magic 包的子包，cjpm 不单独编译）；独立包轨插件包名用 `skill_{name}`（如 `skill_entity`、`skill_feedback`），符合 cjpm 简单标识符规范。两轨包名不同但源码同构，通过 build-sync 同步保持一致。

**与 DSH 的差距**：DSH 无包名约束；agentskills-runtime 受 cjpm 工具链限制，插件包命名需区分内嵌轨/独立轨两套规范。

#### 限制 #6：HMR/合流性无定理背书——对外表述"确定性插件生命周期"（设计限制）

**原复核论断**：§2.10 与 Cordis 六语义对照中，HMR/合流性标注"工程近似，无定理背书"。

**实际限制**：静态编译语言无运行时 fiber 模型，无法实现 DSH 的响应式 inject、Proxy ctx、HMR、五种事件分发（emit/parallel/serial/bail/waterfall）。agentskills-runtime 以"注解声明 + 反射发现 + 生命周期状态机"覆盖 Cordis 六语义中的五个（Service/inject/effect/Events/检视），事件总线实现 emit/waterfall 两种最常用语义，仅 HMR 延后。

**实际落地方案**：不变量表中明确标注"HMR/合流性无定理背书，对外只表述确定性插件生命周期"。PluginEventBus 实现 emit/waterfall，未实现 parallel/serial/bail（f_concurrent EventBus 不在当前依赖中，且其语义是线程池任务执行器非发布订阅）。

**与 DSH 的差距**：DSH 是响应式 fiber 模型，HMR 原生支持；agentskills-runtime 受静态语言限制，HMR 需待 v1.1+ 增强形态（WASM 沙箱插件）才可能实现。

### 6.3 复核结论修订

**原结论**：该 SDD 文档可以进入实施阶段。

**修订结论**：该 SDD 文档已进入实施阶段并完成阶段一/二/三编码。实际落地过程中，因 cjpm 工具链约束（`[workspace]` 与 `[package]` 互斥、包名必须为简单标识符）、仓颉反射 API 在 LTO 下的剪除行为、插件对宿主子包的深度依赖、动态库标准库符号重复等架构/框架/语言限制，原设计多项方案未能完全对标 deepseek-harness（Cordis）"一切皆插件"理念。核心差距在于：DSH 的插件是运行时 fiber，天然独立于宿主进程；agentskills-runtime 的插件是编译期静态资产，必须进入宿主编译图才能被反射发现。阶段三 PS-T012 L2 动态库加载原型部分缓解此限制（PackageInfo.load 热加载），但插件仍需预编译为动态库，无法实现 DSH 级别的"运行时动态定义新插件"。六项关键限制的详细说明见 design.md §0.2 / spec.md §0.2。
