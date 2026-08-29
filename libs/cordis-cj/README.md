# cordis-cj

仓颉（Cangjie）Cordis 动态组合框架 —— 「微内核 + 进程隔离」插件系统。

基于北京大学 & DeepSeek-AI《Revertible Effects and Reactive Coeffects》论文思想，对标 [Cordis](https://github.com/shigma/cordis)（DeepSeek Harness 的插件框架）的语义，用仓颉语言实现：

- **进程隔离**：插件以独立子进程运行，卸载即杀进程，操作系统回收全部资源（规避静态语言无法卸载模块的问题）
- **双传输模式**：stdio（管道，默认）或 UDS（Unix Domain Socket），由服务参数 `transport` 全局切换
- **声明式配置**：TOML/JSON 定义期望状态，调和器自动 diff 并执行 Add/Remove/Update
- **服务注入/提供**：插件声明 `inject`/`provide`，宿主按依赖拓扑启动，崩溃自动重启
- **零样板插件开发**：`@Plugin[]` / `@Provide["key"]` / `@Inject["key"]` 宏自动生成 main、握手与路由注册
- **事件总线**：`ctx.on` / `ctx.emit` 解耦插件间通信，宿主扇出路由
- **类型安全**：`invoke<T, R>` / `registerHandler<T, R>` 泛型 API 自动序列化/反序列化

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│                       宿 主 进 程                             │
│  ┌─────────────┐   ┌─────────────────────────────────────┐  │
│  │  Reconciler │   │  PluginHost                         │  │
│  │  调谐循环    │──▶│  initialize/provide/log 处理器       │  │
│  └─────────────┘   │  serviceIndex / undoMap / 事件注册表   │  │
│                    └──────────────┬──────────────────────┘  │
└───────────────────────────────────┼─────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │ stdio：stdin/stdout 管道    │ uds：Unix Domain Socket     │
        │ NewlineFraming             │ ContentLengthFraming       │
        │ PipeTransport (宿主)        │ UnixServerTransport (宿主)  │
        │ LineStdioTransport (插件)   │ UnixClientTransport (插件)  │
        ▼                            ▼
┌────────────────────────────┐  ┌────────────────────────────┐
│              插件进程 A      │  │              插件进程 B      │
│  PluginRuntime             │  │  PluginRuntime             │
│  握手 → provide → handler   │  │  握手 → provide → handler   │
│  ServiceRegistry（可逆效果） │  │  ServiceRegistry（可逆效果） │
└────────────────────────────┘  └────────────────────────────┘
```

## 模块划分

| 模块 | 包 | 职责 |
|---|---|---|
| `cordis_core` | `ystyle::cordis_core` | 协议消息类（JsonSerializable）、统一 TOML/JSON 配置加载 |
| `cordis_host` | `ystyle::cordis_host` | 进程管理（PipeTransport/UnixServerTransport/PluginManager）、调和器（PluginHost/Reconciler） |
| `cordis_plugin` | `ystyle::cordis_plugin` | 插件 SDK（PluginRuntime/ServiceRegistry）、宏（`ystyle::cordis_plugin.macros`） |

## 快速开始

### 1. 定义插件（两种写法二选一）

#### 写法 A：宏（零样板，推荐框架内置插件）

`@Plugin[]` 宏自动生成 `main` + 握手 + 服务注册 + invoke 路由；`@Provide["key"]` 声明提供服务；`@Inject["key"]` 声明依赖注入（自动生成 `ServiceProxy`）。

```cangjie
// my_plugin/src/main.cj
import ystyle::cordis_plugin.macros.*
import jsonvalue.*

@Plugin[]
public class MyPlugin {
    @Provide["echo"]
    public func echo(args: Array<JsonValue>): JsonValue {
        if (args.size > 0) { args[0] } else { JsonValue.Null }
    }

    @Provide["add"]
    public func add(args: Array<JsonValue>): JsonValue {
        let a = match (args[0]) { case JsonValue.Number(n) => n; case _ => 0.0 }
        let b = match (args[1]) { case JsonValue.Number(n) => n; case _ => 0.0 }
        JsonValue.Number(a + b)
    }
}
```

> 注意：宏包与调用方需**同模块**（`cordis_plugin.macros` 与插件示例同属 `cordis_plugin` 模块的 CJson 模式）。跨模块消费带 organization 的宏库存在 cjpm 缺陷，详见 [docs/macro-org-dependency-issue.md](docs/macro-org-dependency-issue.md)。

#### 写法 B：显式 API（推荐外部插件作者）

手写 `main` + `PluginRuntime.run`，不依赖宏，不受宏跨模块缺陷影响。**同一份代码可同时支持 stdio 与 UDS 两种传输，插件完全无感**——`run()` 内部用 `std.env.getCommandLine()` 自动检测宿主传入的 `--uds <path>` 参数，有则走 UDS，否则走 stdio；`main` 无需接收/透传命令行参数。

```cangjie
// my_plugin/src/main.cj（独立模块）
import ystyle::cordis_plugin.*
import jsonvalue.*

main(): Int64 {
    let handler = { ctx: PluginContext =>
        ctx.registerHandler("echo", { method, args =>
            if (args.size > 0) { args[0] } else { JsonValue.Null }
        })
        ctx.log("info", "plugin ready")
    }
    // run 自动选择传输：宿主 uds 模式传 --uds <path>（getCommandLine 获取），否则 stdio
    PluginRuntime.run("my-plugin", [], ["echo"], handler)
    return 0
}
```

编译为独立可执行文件（两种写法相同配置）：

```toml
[package]
  name = "my_plugin"
  output-type = "executable"
  compile-option = "--static"

[dependencies]
  "ystyle::cordis_plugin" = { path = "../cordis_plugin" }   # 带 org 的普通库跨模块依赖正常
  "jsonvalue" = "1.1.0"
```

#### 泛型类型安全 API（推荐）

`registerHandler<T, R>` 与 `invoke<T, R>` 自动完成序列化/反序列化，业务代码直接操作仓颉类型（基础类型或自定义 DTO），省去手动 JsonValue 转换：

```cangjie
// 自定义 DTO（实现 json.stream 的 JsonSerializable / JsonDeserializable 接口）
public class AddRequest <: JsonSerializable & JsonDeserializable<AddRequest> {
    public let a: Int64
    public let b: Int64
    public init(a: Int64, b: Int64) { this.a = a; this.b = b }
    public func toJson(w: JsonWriter): Unit { /* ... */ }
    public static func fromJson(r: JsonReader): AddRequest { /* ... */ }
}

main(): Int64 {
    PluginRuntime.run("my-plugin", [], ["calc"], { ctx =>
        // 服务端：参数 Array<AddRequest> 自动反序列化，返回 Int64 自动序列化
        ctx.registerHandler<AddRequest, Int64>("calc", { method, args =>
            args[0].a + args[0].b
        })
    })
    return 0
}
```

##### 类模型写法（`Service` 子类，类即服务）

也可以继承 `Service` 基类组织服务：构造时 `super(ctx, name)` 自动注册服务到宿主，`register(method, handler)` 声明方法路由（构造末尾 `bind()` 接入 invoke 分发），业务逻辑集中在类内：

```cangjie
// 服务类：封装计算服务（提供 add 方法）
public class CalcService <: Service {
    public init(ctx: PluginContext) {
        super(ctx, "calc")                       // 自动 ctx.provide("calc")
        this.register("add", { args =>           // 方法路由：宿主 invoke calc.add
            let a = match (args[0]) { case JsonValue.Number(n) => n; case _ => 0.0 }
            let b = match (args[1]) { case JsonValue.Number(n) => n; case _ => 0.0 }
            JsonValue.Number(a + b)
        })
        this.bind()                              // 构造末尾接入 invoke 分发（仓颉限制）
    }
    // 可选：覆写 check() 声明服务可用性（对齐 Cordis [Service.check]）
    // public override func check(): Bool { /* 连接就绪等 */ true }
}

main(): Int64 {
    PluginRuntime.run("my-plugin", [], ["calc"], { ctx =>
        let svc = CalcService(ctx)               // 构造即完成 provide + 方法注册
    })
    return 0
}
```

两种写法等价，最终都注册为宿主 `serviceIndex` 中的服务；类模型适合服务方法较多的插件（状态内聚、`check()` 谓词、撤销回调）。

`PluginContext` 提供：`provide` / `dispose` / `registerHandler`（含泛型版）/ `effect`（可逆效果）/ `invoke`（含泛型版）/ `log` / `on` / `emit` / `proxy`。

### 2. 编写配置（TOML）

```toml
# cordis.toml
interval = 5          # 调谐周期（秒）
ping_interval = 30    # 探活周期（秒）
transport = "stdio"   # 传输模式："stdio"（管道，默认）| "uds"（Unix Domain Socket）
uds_path = ""         # UDS 模式下的监听 socket 路径（如 "/tmp/cordis.sock"）

[[plugins]]
id = "my-plugin"
source = "./target/release/bin/my_plugin"
provide = ["echo", "add"]
enabled = true

[plugins.config]
# 插件私有配置（透传）
```

### 3. 宿主加载

```cangjie
import ystyle::cordis_host.*

main() {
    let cfg = ConfigLoader.load("cordis.toml")
    // 按服务参数选择传输模式：uds → PluginManager(uds_path)；默认 stdio → PluginManager()
    let manager = if (cfg.transport == "uds") {
        PluginManager(cfg.udsPath)
    } else {
        PluginManager()
    }
    let host = PluginHost(manager)
    // 启动调谐循环（spawn 后台线程，每 interval 秒一轮）
    spawn {
        while (true) {
            host.reconcile("cordis.toml")
            sleep(5 * Duration.second)
        }
    }
    // 阻塞主进程
    while (true) { sleep(Duration.hour) }
}
```

宿主会自动：拉起插件 → 握手 → 依赖拓扑排序 → 崩溃自愈重启 → 配置变更热调整。

### 4. 服务调用（invoke 转发）

宿主侧通过插件连接的 RPC 调用其服务：

```cangjie
// 向插件实例发起 invoke
let result = instance.client.call<JsonValue, JsonValue>("invoke",
    params: Some(JsonValue.fromObject(InvokeParams("add", "add",
        [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
// result == Ok(JsonValue.Number(5.0))
```

插件侧经宿主转发调用其他插件的服务（`ctx.invoke`），或通过 `@Inject` 注入的 `ServiceProxy`：

```cangjie
// 写法 A：显式调用
let sum = ctx.invoke<AddRequest, Int64>("calc", "add", [AddRequest(2, 3)])

// 写法 B：@Inject 注入的代理（宏生成，自动注入依赖）
@Inject["add"]
public var add: ServiceProxy
// this.add.call<JsonValue>("add", [JsonValue.Number(5.0), JsonValue.Number(6.0)])
```

## 传输模式：stdio 与 UDS

由 `CordisConfig.transport` 服务参数切换，**插件代码零感知**——`PluginRuntime.run` 内部用 `std.env.getCommandLine()` 自动检测宿主传入的 `--uds <path>` 参数，自动选择传输层（无需用户从 main 传参判断）：

| 维度 | stdio（默认） | UDS |
| :--- | :--- | :--- |
| 宿主传输层 | `PipeTransport`（子进程管道） | `UnixServerTransport`（bind + accept） |
| 插件传输层 | `LineStdioTransport`（readln 逐行） | `UnixClientTransport`（connect） |
| 帧协议 | `NewlineFraming`（管道 read 阻塞坑） | `ContentLengthFraming`（标准） |
| 插件侧入口 | `PluginRuntime.run(...)`（自动检测，二选一） | 同左 |
| 平台 | 全平台 | Linux/macOS（std.net 不支持 Windows） |
| 崩溃检测 | stdout EOF | socket EOF（语义一致，自愈逻辑共用） |

> **为什么帧协议不同**：仓颉 `ConsoleReader.read(Array<Byte>)` 在管道 stdin 下永久阻塞，stdio 只能用 `readln()` + 换行帧；UDS 的 `read` 是标准流式读（EOF 返回 -1/0），可用 jsonrpc 默认的 Content-Length 帧（与 MCP 等标准一致）。详见 [docs/design-impl.md §3.4](docs/design-impl.md)。

## 事件总线

插件间解耦通信：任意插件 `emit` 事件，宿主扇出给所有 `on` 订阅者（发布者不等待、不感知订阅者）：

```cangjie
// 订阅者：收到 stats/report 事件时回调（订阅是效果，卸载自动退订）
ctx.on("stats/report", { args => ctx.log("info", "received: ${args[0]}") })

// 发布者：通知宿主扇出（不等待订阅者）
ctx.emit("stats/report", [JsonValue.Number(1.0)])
```

## 协议

- **传输**：stdio（换行帧）或 UDS（Content-Length 帧），由 `transport` 服务参数切换
- **消息**：JSON-RPC 2.0
- **方法**：`initialize` / `initialized` / `provide` / `dispose` / `notify` / `log` / `invoke` / `ping` / `events/subscribe|unsubscribe|emit|dispatch`

## 配置加载（统一 TOML/JSON）

`ConfigLoader` 基于 `Serializable<T>` + DataModel 中间表示，同一结构可读写 TOML 或 JSON：

```cangjie
let cfg = ConfigLoader.parseString<CordisConfig>(tomlStr)   // TOML
let cfg = ConfigLoader.parseJsonString<CordisConfig>(jsonStr)  // JSON
let cfg = ConfigLoader.load("cordis.toml")                  // 文件
```

## API 参考

### 插件侧（`ystyle::cordis_plugin`）

#### `PluginRuntime`（插件入口）

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `run` | `static run(pluginId: String, inject: Array<String>, provide: Array<String>, handler: (PluginContext) -> Unit)` | 标准入口：自动检测传输（`getCommandLine()` 找 `--uds`，有则 UDS 否则 stdio） |
| `run` | `static run(transport: Transport, pluginId: String, inject: Array<String>, provide: Array<String>, handler: (PluginContext) -> Unit)` | 自定义传输层（测试/特殊场景） |
| `runUds` | `static runUds(udsPath: String, pluginId: String, inject: Array<String>, provide: Array<String>, handler: (PluginContext) -> Unit)` | 显式 UDS 入口（Content-Length 帧） |
| `parseUdsArg` | `static parseUdsArg(args: Array<String>): ?String` | 解析 `--uds <path>`，未指定返回 None |
| `autoUdsPath` | `static autoUdsPath(): ?String` | 从进程命令行自动解析 UDS 路径（`getCommandLine()`，异常退化为 None） |
| `parseUdsArg` | `static parseUdsArg(args: Array<String>): ?String` | 解析 `--uds <path>`，未指定返回 None |

#### `PluginContext`（插件业务上下文，`ctx`）

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `provide` | `provide(key: String): String` | 提供服务到宿主，返回 `undo_id` |
| `provide` | `provide(key: String, disposer: () -> Unit): String` | 提供服务 + 撤销回调 |
| `dispose` | `dispose(undoId: String): Bool` | 撤销指定服务 |
| `registerHandler` | `registerHandler(key: String, handler: (String, Array<JsonValue>) -> JsonValue): Unit` | 注册服务实现（JsonValue 版） |
| `registerHandler<T, R>` | `registerHandler<T, R>(key: String, handler: (String, Array<T>) -> R): Unit` | 泛型版：参数自动反序列化、返回自动序列化 |
| `effect` | `effect(disposer: () -> Unit): Unit` | 注册可逆效果，卸载时逆序执行（对齐 Cordis `ctx.effect`） |
| `effectAsync` | `effectAsync(disposer: () -> Future<Unit>, label!: String = "async"): Unit` | 异步可逆效果：disposer 返回 Future，卸载时等待完成 |
| `invoke` | `invoke(service: String, method: String, args: Array<JsonValue>): JsonValue` | 经宿主转发调用其他插件的服务 |
| `invoke<T, R>` | `invoke<T, R>(service: String, method: String, args: Array<T>): R` | 泛型版：参数/返回自动转换 |
| `log` | `log(level: String, message: String): Unit` | 发日志到宿主（`LogLevel.*`） |
| `on` | `on(event: String, listener: (Array<JsonValue>) -> Unit): String` | 订阅事件（订阅是效果，卸载自动退订） |
| `on<T>` | `on<T>(event: String, listener: (T) -> Unit): String` | 类型安全订阅：args[0] 自动反序列化为 T |
| `onVal` | `onVal(event: String, listener: (Array<JsonValue>) -> ?JsonValue): String` | 返回值版订阅（serial/bail 用） |
| `onWaterfall` | `onWaterfall(event: String, listener: (Array<JsonValue>, () -> ?JsonValue) -> ?JsonValue): String` | 洋葱 next 订阅（对齐 Cordis waterfall，见 design-events.md §7.1） |
| `emit` | `emit(event: String, args: Array<JsonValue>): Unit` | 发布事件（宿主扇出，不等待订阅者） |
| `emit<T>` | `emit<T>(event: String, args: Array<T>): Unit` | 类型安全发布：参数自动序列化 |
| `serial` / `bail` | `serial(event, args): ?JsonValue` | 按序派发，遇 bail 值（非 null/false）停止并返回 |
| `waterfall` | `waterfall(event: String, args: Array<JsonValue>): ?JsonValue` | 洋葱链派发（最外层订阅者返回值 = 链结果） |
| `proxy` | `proxy(serviceKey: String): ServiceProxy` | 创建服务代理（@Inject 宏产物） |

#### `ServiceProxy`（远程服务代理）

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `call<R>` | `call<R>(method: String, args: Array<JsonValue>): R where R <: JsonDeserializable<R>` | 调用远程服务（`R = JsonValue` 时原样返回） |

#### `ServiceRegistry`（服务注册表，插件内部）

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `register` | `register(undoId: String)` / `register(undoId: String, disposer: () -> Unit)` | 登记服务 |
| `dispose` | `dispose(undoId: String): Bool` | 按 undo_id 撤销服务 |
| `effect` | `effect(disposer: () -> Unit): Unit` | 注册可逆效果 |
| `disposeAll` | `disposeAll(): Unit` | 卸载时逆序执行全部 disposer 并清空 |
| `invokeHandler` | `invokeHandler(service: String, method: String, args: Array<JsonValue>): JsonValue` | 分发宿主转发的调用 |
| `serviceCount` / `effectCount` | `prop ... : Int64` | 诊断用 |

#### `Service`（服务基类，类即服务）

对齐 Cordis `Service`：继承并在构造中 `super(ctx, name)` 自动 `ctx.provide`；`register(method, handler)` 注册服务方法；构造末尾 `bind()` 接入 invoke 分发；`check()` 可用性谓词可覆写。

```cangjie
public class CalcService <: Service {
    public init(ctx: PluginContext) {
        super(ctx, "calc")
        this.register("add", { args => /* ... */ })
        this.bind()   // 构造末尾（仓颉可继承类构造不能捕获 this）
    }
}
```

#### `PluginLogger`（命名日志器）

`ctx.logger(name)` 返回带名称的日志器，日志经宿主 log 通知并携带 `logger` 来源字段：

```cangjie
let db = ctx.logger("db")
db.info("connected")        // 宿主 LogParams(logger="db", ...)
ctx.log("info", "plain")    // 默认日志（logger=None）
```

#### timer 工具（`ctx.timeout/interval/throttle/debounce`）

基于 `std.sync.Timer`，全部可撤销（返回 `() -> Unit` cancel 函数）：

```cangjie
let cancel = ctx.interval(1000, { => /* 每秒 */ })
// ctx.timeout(ms, cb) 一次性；ctx.throttle(ms, cb) 节流；ctx.debounce(ms, cb) 防抖
```

#### 事件类型安全（`ctx.on<T>` / `once<T>` / `onVal<T>`）

事件参数自动反序列化为 T（`T <: JsonDeserializable<T>`），订阅者直接操作仓颉类型：

```cangjie
ctx.on<GreetPayload>("greet", { payload =>
    // payload: GreetPayload（自动从 args[0] 反序列化）
})
```

### 宿主侧（`ystyle::cordis_host`）

#### `PluginManager`（进程管理）

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `init` | `init()` | stdio 模式（默认） |
| `init` | `init(udsPath: String)` / `init(udsPath: String, logger: (String, String) -> Unit)` | UDS 模式：宿主 bind `uds_path` 监听 |
| `launch` | `launch(entry: PluginEntry): PluginInstance` | 拉起插件进程并建连（uds 模式自动追加 `--uds <path>` 参数 + accept） |
| `terminate` | `terminate(instance: PluginInstance): Int64` | 热卸载：关连接 → 强杀 → 回收退出码 |
| `isExited` | `isExited(instance: PluginInstance): Bool` | 探测连接是否关闭（崩溃检测信号源） |
| `close` | `close(): Unit` | 关闭 UDS 监听（stdio 无操作） |
| `isUdsMode` | `prop isUdsMode: Bool` | 是否 UDS 模式 |

#### `PluginHost`（协调器）

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `init` | `init(manager: PluginManager, logger?: (String, String) -> Unit)` | 构造（注入 PluginManager） |
| `launchPlugin` | `launchPlugin(entry: PluginEntry): PluginInstance` | 拉起插件并注册宿主侧 RPC 处理器 |
| `reconcile` | `reconcile(configPath: String): Unit` | 读 TOML → diff → 拓扑启动 → 崩溃自愈 |
| `reconcileDesired` | `reconcileDesired(): Unit` | 对当前 desired 执行一轮调谐 |
| `removePlugin` | `removePlugin(id: String): Unit` | 终止插件并清理服务注册表 |
| `state` / `eventRegistry` | `prop` | `HostState` / `EventRegistry`（公共字段） |

#### `HostState`（状态）

`desired` / `actual` / `serviceIndex`（serviceKey → providerId）/ `undoMap`（undoId → (key, providerId)），方法：`addDesired` / `removeDesired` / `addInstance` / `removeInstance` / `getInstance(id)` / `hasService(key)` / `registerService` / `unregisterService` / `clearServicesByProvider` / `servicesOf(providerId)`。

#### `EventRegistry`（事件注册表）

`subscribe(event, pluginId, instance): String` / `unsubscribe(subscriptionId): Bool` / `unsubscribeAll(pluginId)` / `subscriberCount(event): Int64` / `dispatch(event, args, emitId): Int64`（同步按注册顺序派发，失败自动清理订阅）。

### 核心类型（`ystyle::cordis_core`）

#### `CordisConfig`（根配置，`Serializable<T>`）

| 字段 | 类型 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `interval` | `Int64` | `5` | 调谐周期（秒） |
| `pingInterval` | `Int64` | `30` | 探活周期（秒） |
| `transport` | `String` | `"stdio"` | `"stdio"` / `"uds"` |
| `udsPath` | `String` | `""` | UDS 监听 socket 路径 |
| `entries` | `ArrayList<PluginEntry>` | — | 插件期望状态列表 |

#### `PluginEntry`（插件条目）

`id` / `source`（可执行文件路径）/ `args`（附加参数）/ `inject`（依赖服务 Key）/ `provide`（提供服务 Key）/ `config`（DataModel 私有配置透传）/ `enabled`（默认 true）。

#### `ConfigLoader`（统一配置加载）

`loadToml<T>(path)` / `parseTomlString<T>(str)` / `parseJsonString<T>(str)`（泛型，`T <: Serializable<T>`）/ `load(path): CordisConfig` / `parseString(str): CordisConfig`。

#### `ConfigSchema`（配置 schema 校验）

`ConfigFieldSpec(name, typeName, required)` + `ConfigSchema(fields)`：`validate(config, path)`（宽松）/ `validateStrict(config, path)`（含未知字段检查）；类型 string/bool/int/float/array/object；错误带完整路径（如 `plugins[0].config.port: expected int, got string`）。宿主侧 `PluginHost.registerSchema(pluginId, schema)` 后 `launchPlugin` 前置校验，失败抛路径化异常。

#### `InstanceStatus`

`Starting` / `Active` / `Unloading` / `Failed` / `Unreachable`（`@Derive[Equatable, ToString]`）。

#### 常量

`Methods.*`：`INITIALIZE` / `INITIALIZED` / `PROVIDE` / `DISPOSE` / `NOTIFY` / `LOG` / `INVOKE` / `PING` / `PONG` / `EVENTS_SUBSCRIBE` / `EVENTS_UNSUBSCRIBE` / `EVENTS_EMIT` / `EVENTS_DISPATCH`；`NotifyKind.*`：`DEPENDENCY_LOST` / `PROVIDER_CHANGED`；`LogLevel.*`：`TRACE` / `DEBUG` / `INFO` / `WARN` / `ERROR`。

### 宏（`ystyle::cordis_plugin.macros`）

| 宏 | 用法 | 说明 |
| :--- | :--- | :--- |
| `@Plugin[]` | 标注插件类 | 自动生成 `main` + 握手 + 服务注册 + invoke 路由 |
| `@Provide["key"]` | 标注服务方法 `func f(args: Array<JsonValue>): JsonValue` | 声明提供服务，注册到宿主 |
| `@Inject["key"]` | 标注字段 `var f: ServiceProxy` | 声明依赖注入，宏生成 `ServiceProxy(ctx, "key")` |

> 宏包与调用方需**同模块**；跨模块消费带 organization 的宏库有 cjpm 缺陷（见 [docs/macro-org-dependency-issue.md](docs/macro-org-dependency-issue.md)），外部插件建议用显式 API 写法。

## 测试

```shell
eval "$(cjvs env zsh)" && eval "$(cjvs stdx-env zsh)"
cjpm test -j 16 --no-progress
```

72 个用例，覆盖：协议序列化往返、配置解析（含 UDS 服务参数）、管道传输（真实子进程）、UDS 传输回环、进程管理、插件运行时（内存双端对接）、端到端（stdio + UDS 双模式真实宿主 ↔ 真实插件进程：握手/服务注册/invoke/热卸载/崩溃自愈）、宏插件生命周期、独立模块外部插件生命周期、泛型 invoke/registerHandler 全链路、事件总线。

## 文档

- [设计文档（v1.0 草案）](docs/design.md)
- [实现级设计文档（v2.0，真实 API）](docs/design-impl.md)
- [进度跟踪与踩坑记录](docs/progress-tracking.md)
- [cjpm 宏包 organization 缺陷排查](docs/macro-org-dependency-issue.md)

## License

MIT
