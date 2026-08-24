思考过程

我来研究 fountain 框架中可复用的基础设施。先同时探索 fountain 框架结构和插件系统第三阶段的规划。
explore SubAgent: 探索 fountain 框架结构
explore SubAgent: 探索插件系统第三阶段规划
思考过程

现在我对两端都有了深入理解，下面给出综合分析。

Fountain 框架与插件系统第三阶段——可复用基础设施分析
一、高度匹配的可复用机制
1. 动态库加载：PackageInfo.load() 运行时热加载 ✅ 可直接复用
fountain 已有：f_app/App.cj L116-171 有一套完整、生产级、成熟的动态库扫描+加载实现。通过 Directory.walk() + 正则匹配 .so/.dll/.dylib → PackageInfo.load(去扩展名路径) 加载
插件系统需求：PS-T012 L2动态库加载原型需要实现完全相同的机制
复用方式：可直接参考甚至复制 fountain 的加载逻辑，已经处理了跨平台扩展名映射、路径转换、加载状态管理等边界条件
2. IOC/DI 容器：BeanFactory 作为 ServiceRegistry 的超集 ✅ 高复用
fountain 已有：f_bean/BeanFactory 是全局单例容器，支持按类型查找（get<T>() / getList<T>()）、按名称查找、按注解查找、生命周期管理（singleton/prototype）、@Value 配置注入
插件系统需求：plugin-spi 中定义了 ServiceRegistry 契约（registerService / getService / listServices / getService<T>），实际上是 BeanFactory 的精简子集
复用方式：BeanFactory 的 lookup<T>() 和 getFirst<T>() 模式已在 design.md 中被引用作为 ServiceRegistry 泛型类型安全接口的参考。可以直接让 ServiceRegistry 实现委托给 BeanFactory，或者将 BeanFactory 本身作为插件的服务注册中心
3. SPI 扩展发现机制：lookup<T>() = 内置 SPI ✅ 完全等价
fountain 已有：f_bean/src/lookup.cj 中的 lookup<T>() / lookupList<T>() 函数，运行时从容器中查找所有实现了接口 T 的 Bean，无需 META-INF/services 配置文件
插件系统需求：@PluginAnnotation 注解发现机制本质上就是一种 SPI——宿主需要发现所有实现了 Plugin 接口的类
复用方式：将插件实现类用 @Bean 标记（或复用 @PluginAnnotation），通过 lookupList<Plugin>() 自动发现全部插件。fountain 的 AOP 加载（Aspects.cj 中遍历 BeanFactory.instance.iterator<Aspect>()）就是这种模式的现成参考
4. EventBus 事件总线 ✅ 已有成熟实现
fountain 已有：f_concurrent/eventbus/ 包含完整的 EventBus、Event、Worker、JobQueue、EndEvent 实现，支持发布订阅 + 工作队列
插件系统需求：plugin-spi 定义 PluginEventBus 接口（subscribe / emit / waterfall / unsubscribeAll），但目前实现仍在宿主 magic.plugin
复用方式：PluginEventBus 的实现可以直接包装 fountain 的 EventBus，省去从零开发事件总线的成本
5. 配置管理：Config 零配置文件系统 ✅ 可复用模式
fountain 已有：f_config/Config 支持环境变量 + 命令行参数、类型自动转换、配置刷新
插件系统需求：PluginContext.config 参数传递配置
复用方式：插件可共享宿主的 Config 实例，或为每个插件提供带前缀隔离的配置视图
二、中等匹配的可复用机制
6. 模块化编译体系：cjpm 多包架构
fountain 已有：32 个独立 cjpm 子包（每个 f_* 目录自有 cjpm.toml），通过 [dependencies] 声明依赖关系，output-type = "dynamic" 编译为独立动态库
插件系统需求：PS-T017 方案B——每个 skills/{name}/ 升格为独立 cjpm 包，output-type = "dynamic"，只依赖 plugin_spi
复用方式：fountain 的分包编译体系可以直接参考。fountain 已证明仓颉语言完全支持这种模式
7. Bean 生命周期管理：插件生命周期的参考模板
fountain 已有：BeanScope（singleton/prototype）、PostConstruct、Destroy、BeanCondition、BeanMeta.lazy
插件系统需求：五态生命周期 Pending → Loading → Active → Error → Disposed
复用方式：Bean 生命周期比插件更细粒度，但 Destroy 接口（通过 atExit 注册销毁回调）的模式可用于实现插件的 onUnload 清理链
三、不能直接复用但值得研究的机制
8. AOP 切面编程框架
fountain 的 Aspects 管理器从 BeanFactory 加载所有 Aspect 实现并缓存代理函数链。插件系统中如果某些横切关注点（如插件调用日志、权限校验）需要 AOP，可直接复用
9. 响应式编程 f_rx
fountain 的 Observable/Observer/Scheduler/BackPressure 框架可用于插件间异步通信和事件流处理
四、结论与建议
机制	复用程度	plugin-spi 对应物
动态库加载	可直接复用代码	PluginDylibLoader
BeanFactory IOC	可作为 ServiceRegistry 后端	ServiceRegistry
lookup<T>() SPI	等同于 @Plugin 发现机制	PluginRegistry 扫描
EventBus	实现可包装	PluginEventBus
Config	可直接引用	PluginContext.config
cjpm 分包	架构参考	插件独立 cjpm 包
Bean 生命周期	模式参考	插件生命周期

核心结论：fountain 框架已经实现了插件系统第三阶段需要的全部 7 项关键基础设施，部分是生产级代码可直接复用（动态库加载、EventBus），部分是更强大的超集可作为后端（BeanFactory → ServiceRegistry）。最大节省在于不需要从零开发动态库加载和事件总线，这两块在 fountain 中已是经过验证的成熟实现。


## 三、阶段三 fountain 基础设施深度复用优化方案（v3.0 修订）

> 修订日期：2026-08-24
> 修订依据：fountain 框架 (libs/fountain/, 630 个 .cj 文件, 32 个子包) 深度研究报告
> 核心原则：**优先复用 fountain 已验证的生产级基础设施，而非从零重复开发**。fountain 已在 28 处生产场景中使用 std.reflect，经受过跨平台（Linux/Windows/macOS/OpenHarmony）验证。

### 3.1 复用总览——fountain 能力 → 插件系统组件的映射

```
fountain 基础设施                  →  插件系统组件               复用程度
─────────────────────────────────────────────────────────────────────
f_bean/BeanFactory (IOC 容器)     →  ServiceRegistry 实现后端   完全复用（作为后端引擎）
f_bean/BeanManager (生命周期)     →  Plugin 生命周期管理        模式复用（PostConstruct→onActivate 映射）
f_bean/@Bean + annotationMap      →  @Plugin 注解自动发现        机制复用（注解索引代替手动扫描）
f_bean/@Value 宏 (配置注入)       →  PluginContext.config       模式复用（类型安全的编译期注入）
f_app/App.run() (动态库加载)      →  PluginDylibLoader          代码复用（99% 逻辑一致）
f_concurrent/EventBus (事件总线)  →  PluginEventBus 实现        包装复用（内置 worker/priority/JobQueue）
f_aspect/Aspects (AOP 框架)       →  插件横切关注点             直接复用（日志/监控/权限拦截）
f_config/Config (配置管理)        →  PluginConfigParser 辅助    模式复用（零文件配置理念）
f_base/TypeInfos (类型缓存)       →  PluginLoader 反射缓存      直接复用（已有双检锁缓存）
f_ticktock (CRON 调度)            →  插件定时任务               直接复用（插件注册 CRON 任务）
f_rx/Observable (响应式)          →  插件间异步数据流           直接复用（替代自定义事件）
```

### 3.2 优化方案一：ServiceRegistry 委托 BeanFactory（影响 PS-T017、设计 §2.2.2）

**现状**：ServiceRegistry 自建独立的 `HashMap<String, Any>` 注册表，类型安全轨走 `HashMap<TypeInfo, ...>` 自建索引。design.md §2.2.2 服务命名契约中写"演进方向：插件 Service 同步注册为 fountain Bean"，把这个能力定位为"v1 后评估"的远期规划。

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
        beanFactory.registerByName(name, service)
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

思考过程

我需要全面探索三个维度：crontab_sched 规格、agentskills-runtime 项目自身的基础设施、以及两者之间的关系。并行启动多个探索任务。
explore SubAgent: 探索 crontab_sched 规格
explore SubAgent: 探索 crontab 代码实现
explore SubAgent: 探索 runtime 整体基础设施
思考过程

三份报告数据非常丰富。我现在来更新 design.md：修正 crontab 优化方案（推荐复用自有的 SchedulerEngine 而非原始 f_ticktock），并新增 runtime 自有基础设施的复用方案
Read
design.md
L:1453 - 1502
思考过程
design.md
+58
-17
思考过程

现在在 3.9 之后、3.10 之前插入 runtime 特有基础设施的复用优化方案。先确认 3.9 末尾
Read
design.md
L:1570 - 1619
思考过程
Read
design.md
L:1618 - 1665
思考过程
design.md
+243
-12
思考过程

现在更新实施建议（3.17）和风险评估（3
design.md
思考过程
Read
design.md
L:1700 - 1799
思考过程
Read
design.md
L:1800 - 1896
思考过程
design.md
+19
-7
思考过程

更新风险评估表格添加新优化的风险，同时更新版本号
design.md
思考过程
Read
design.md
L:1886 - 1905
思考过程
Read
design.md
L:1900 - 1908
思考过程
design.md
+6
-1
思考过程

最后更新文件头版本
design.md
+2
-1
思考过程

design.md 已更新完毕，文件从 1187 行扩展至约 1910+ 行。以下是本次修订的核心变更：

v3.1 修订内容
修正项
原来	修正后	原因
3.6 推荐复用 f_ticktock CRON 框架	推荐复用宿主自有的 SchedulerEngine（基于 f_ticktock 但更完备的生产级调度引擎）	SchedulerEngine 在 f_ticktock 之上增加了：7 个可插拔执行器、失败重试、Misfire 补偿、执行日志持久化、AsyncLogWriter、安全防护、14 个管理 API、12 个 CLI 命令
新增 6 项 runtime 自有基础设施复用方案
编号	优化项	复用目标	优先级
3.10	插件中间件复用 MiddlewareChain	插件路由自动继承宿主认证/权限中间件链 + 可追加自定义中间件	P2
3.11	插件接入 WebSocketEventBridge 实时事件流	插件监听 14 种 Agent 事件 + 向前端推送进度	P3
3.12	插件数据同步复用 SyncManager	PluginSyncBridge 从独立实现改为事件监听，代码量从 ~200 行降至 ~50 行	P1
3.13	插件注册自定义 AI 模型 ModelManager Provider	16 个现有 Provider 体系扩展	P3
3.14	插件缓存复用 CacheManager (Redis)	key 前缀隔离 + 卸载时批量清理	P3
3.15	插件沙箱执行复用 SandboxExecutor	WASM 沙箱隔离 + 自动降级	P3
优化方案总数：从 8 项扩展至 14 项
P0 (阶段三随主线落地)：3.2、3.3、3.4（3 项，fountain 基础设施复用）
P1 (阶段三并行推进)：3.5、3.8、3.12（3 项，2 项 fountain + 1 项 runtime）
P2 (阶段四引入)：3.6、3.7、3.10（3 项）
P3 (远期规划)：3.9、3.11、3.13、3.14、3.15（5 项）
任务完成
共消耗: 3723.6K
17min 45s