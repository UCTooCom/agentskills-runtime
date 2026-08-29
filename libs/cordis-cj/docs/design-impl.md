# 仓颉 Cordis 动态组合框架 —— 实现级设计文档（v2.0）

**文档状态**：细化稿（v1.0 设计文档的 API 落地版）
**核心变化**：v1.0 中所有伪代码已替换为经官方文档确认的真实仓颉 API；配置格式定为 TOML；宏层后置，先交付运行时库。

---

## 0. API 确认结论（伪代码 → 真实 API 对照）

以下为经 `cangjie-docs` 官方文档逐一确认的结论，v2.0 全部按此实现，不再使用伪代码。

### 0.1 进程管理：`std.process`

| v1.0 伪代码 | 真实 API（std.process） |
| :--- | :--- |
| `Process`（当子进程用） | `SubProcess` 才是子进程类；`Process` 是抽象基类，不可直接实例化 |
| `fork/spawn` 子进程 | `public func launch(command: String, arguments: Array<String>, workingDirectory!: ?Path = None, environment!: ?Map<String, String> = None, stdIn!: ProcessRedirect = Inherit, stdOut!: ProcessRedirect = Inherit, stdErr!: ProcessRedirect = Inherit): SubProcess` |
| 标准流重定向 | `ProcessRedirect` 枚举：`Inherit \| Pipe \| FromFile(File) \| Discard`；宿主侧三流全部用 `Pipe` |
| 写插件 stdin | `subProcess.stdInPipe: OutputStream`（`write(buffer: Array<Byte>)` + `flush()`） |
| 读插件 stdout/stderr | `subProcess.stdOutPipe: InputStream`、`subProcess.stdErrPipe: InputStream`（`read(buffer: Array<Byte>): Int64`，EOF 返回 ≤0） |
| 强制杀进程 | `subProcess.terminate(force: Bool): Unit` |
| 等待退出/回收 | `subProcess.wait(timeout!: ?Duration = None): Int64`（超时抛 `TimeoutException`；正常退出返回退出码，被信号杀死返回信号编号） |
| 进程 id | `subProcess.pid: Int64` |

要点：`launch` 创建后**必须**调用 `wait`/`waitOutput`，否则子进程结束会成为僵尸进程；Pipe 模式下需先处理标准流避免缓冲满死锁（宿主侧由 RPC 接收线程持续消费 stdout，stderr 由独立线程消费）。

### 0.2 RPC 框架：`ystyle::jsonrpc`（本地已有，直接复用）

- 帧协议：**采用 `NewlineFraming`（换行分隔帧）**。v1.0/初稿设想的 `ContentLengthFraming`（`Content-Length: N\r\n\r\n{...}`）在仓颉环境不可行：子进程被 `launch` 拉起后，`ConsoleReader.read(Array<Byte>)` 永久阻塞，无法精确读取帧体；`readln()` 可靠。因此插件侧用 `LineStdioTransport`（readln 逐行 + 补回 `\n`）+ `NewlineFraming`，宿主侧 PipeTransport 同步 `NewlineFraming`（与 mcp-cj 生产方案一致）。
- `Transport` 接口（宿主侧需为子进程管道新实现一个，见 §3.2）：

```cangjie
public interface Transport <: Resource {
    func send(data: Array<Byte>): Unit
    func receive(): ?Array<Byte>
    func isClosed(): Bool
}
```

- 宿主侧（每插件一个连接）：`JsonRpcClient(transport, framing!: Framing = NewlineFraming())`

| 方法 | 签名 | 用途 |
| :--- | :--- | :--- |
| 发请求 | `call<T, R>(method: String, params!: ?T, timeout!: Duration = 30 * Duration.second): Result<R>` | 宿主 → 插件（dispose/ping/invoke） |
| 发通知 | `notify<T>(method: String, params!: ?T): Unit` | 宿主 → 插件（initialized/notify） |
| 收插件请求 | `registerRequestHandler(method: String, handler: RequestCallback): Unit`，`RequestCallback = (Request) -> ?JsonValue` | 处理 initialize/provide |
| 收插件通知 | `setNotificationCallback(cb: NotificationCallback): Unit`，`NotificationCallback = (Notification) -> Unit` | 处理 log |
| 生命周期 | `start()` / `close()` / `isClosed()` | 后台线程收发；stdout EOF 自动关闭 |

- 插件侧：`JsonRpcServer(transport, framing!: Framing = NewlineFraming())`

| 方法 | 签名 | 用途 |
| :--- | :--- | :--- |
| 注册处理器 | `register(method: String, handler: Handler): Unit`，`Handler = (HandlerContext) -> HandlerResult` | 处理 initialized/dispose/notify/ping/invoke |
| 主动请求宿主 | `request<T, R>(method: String, params!: ?T, timeout!: Duration = 30 * Duration.second): Result<R>` | 插件 → 宿主（initialize/provide），单飞（单 pendingRequest） |
| 主动通知宿主 | `notify<T>(method: String, params!: ?T): Unit` | 插件 → 宿主（log） |
| 生命周期 | `start()`（后台线程）/ `serve()`（阻塞）/ `close()` | — |

- 上下文与结果：`HandlerContext.getRawParams(): ?JsonValue`、`getParams<T>(): ?T`；`HandlerResult.ok(value: JsonValue)` / `HandlerResult.err(code: Int64, message: String)`；`Result<T> = Ok(T) | Err(String)`。

### 0.3 配置解析：`tomlcj`（本地已有）

| 用法 | API |
| :--- | :--- |
| 文件解析 | `Decoder(File(path, Read)).decode(): TomlObject` |
| 字符串解析 | `parse(str).mapping: TomlObject` |
| 取值 | `obj.get(key: String): Option<TomlValue>`、`obj.contains(key): Bool` |
| 类型转换 | `asBool()/asInt()/asFloat()/asString()/asArray()/asObject()`（返回 `Option`） |
| 数组 | `arr.get(index: Int64): Option<TomlValue>`、`arr.append(tv)` |

### 0.4 协议消息序列化：`stdx.encoding.json.stream`

按工作区规范（AGENTS.md）：**固定结构类必须实现 `JsonSerializable`/`JsonDeserializable<T>`，禁止用 jsonvalue 手动解析**。协议消息均为固定结构，全部实现这两个接口：

```cangjie
public interface JsonSerializable {
    func toJson(w: JsonWriter): Unit
}
public interface JsonDeserializable<T> {
    static func fromJson(r: JsonReader): T
}
```

（jsonrpc 包自身的 `Request`/`Response`/`Notification` 即按此实现，本框架消息照此模式。）

### 0.5 并发原语

- `spawn { ... }` → `Future<T>`（后台线程）；`sleep(dur: Duration)`（`std.core`）。
- `Mutex` + `Condition` + `synchronized(lock) { ... }` 做状态同步（jsonrpc 包内部同款用法）。
- 插件侧阻塞等待请求 → `Handler` 同步执行即可（jsonrpc 在接收线程中直接调用）。

### 0.6 宏（v1.0 §5）—— 可行性已实证，列为 P4 实施

仓颉宏（`macro package` + `@Name[attr](input)` + `quote`/`Tokens`，`std.ast`）**已通过工作区真实项目实证**（`grep -rln "macro package"` 命中 8+ 项目），且能力覆盖本框架全部需求：

| 宏需求 | 实证项目 | 证据 |
| :--- | :--- | :--- |
| 解析 class/struct 声明并生成序列化代码 | `CJson`（`@JsonSerializable`） | 遍历字段生成完整 `toJson/fromJson`，与本框架协议消息需求完全一致 |
| 往类里生成整套方法（含泛型/属性/静态方法） | `storm-cj`（`@Model`） | 生成 `tableName/getIndexes/getPrimaryKey/toJson/fromJson` 等 |
| 生成完整服务类 + 路由注册（属性宏） | `kux-cj`（`@Crud[Todo, "/api/todos"]`） | 生成 inject 字段、list/create/update/delete、`registerRoutes()` |
| 重写函数体（生成 try/catch 包裹逻辑） | `defer-cj`（`@DeferWarp`） | 宏内拆解 `FuncDecl.block` 重组函数体 |
| 宏展开时执行任意宿主代码 + 引用运行时符号 | `embed-cj`（`@EmbedString`）、`CangjieMagic`（DSL） | 宏内读文件/base64；`public import` 运行时包供展开代码引用 |
| cjpm 工程化（宏包与运行时代码共存、发布） | `CJson`/`embed-cj`/`storm-cj`/`kux-cj` | 均为 cjpm 项目，宏包与库/可执行目标同仓；`embed-cj` 已发布中心仓 v1.0.7 |

已知约束（文档确认，不影响本方案）：
- 宏定义必须在独立 `macro package` 中，宏包只能导出宏（非宏声明包内可见）；
- 宏定义与调用不能同包；
- 宏展开生成的代码若引用运行时符号，宏包需 `public import` 这些符号，使用者仅导入宏包即可编译。

**决策（更新）**：P0–P3 仍先交付纯运行时库（插件手写 `main` 调用 `PluginRuntime`），保证框架核心先行验证；P4 实施宏层：`@plugin`（展开 `main` + 事件循环样板）、`@provide`（展开 `invoke` 路由注册）、`@inject`（展开经宿主转发的代理 getter）。宏展开目标与运行时库 API 一一对应，是纯语法糖层，不改变协议。P0–P3 阶段不阻塞 DX 目标——宏可行性已由上述项目实证，无需再单独 spike。

---

## 1. 项目结构（cjpm workspace）

```
cordis-cj/
├── cjpm.toml              # [workspace] 管理
├── cordis_core/           # 协议消息类型 + 常量（无 I/O，纯数据 + 序列化）
│   └── src/
│       ├── message.cj     # InitializeParams/Result、ProvideParams/Result、DisposeParams、NotifyParams、LogParams、InvokeParams
│       ├── methods.cj     # 方法名常量（initialize/initialized/provide/dispose/notify/log/invoke/ping/pong）
│       └── config.cj      # PluginEntry + ConfigLoader（tomlcj → PluginEntry）
├── cordis_host/           # 宿主：进程管理 + PipeTransport + Reconciler
│   └── src/
│       ├── pipe_transport.cj   # SubProcess 管道 Transport（新实现）
│       ├── plugin_manager.cj   # launch/terminate/wait、状态机、RPC client 封装
│       ├── reconciler.cj       # 调谐循环：TOML 读期望 → diff → 拓扑启动 → 先加后删
│       └── logger.cj           # 日志汇聚（stderr 转发 + log RPC）
├── cordis_plugin/         # 插件 SDK（静态库，插件链接）
│   └── src/
│       ├── runtime.cj          # PluginRuntime：main 入口封装、initialize 握手
│       ├── service_registry.cj # provide/dispose、undo_id 管理
│       └── invoke.cj           # 服务调用封装（宿主转发）
└── cordis_tests/          # 单元测试 + 端到端
    └── src/
        ├── protocol_test.cj    # 消息序列化往返测试
        ├── pipe_transport_test.cj
        ├── reconciler_test.cj
        └── e2e_test.cj         # 宿主拉起测试插件进程，验证握手/调用/热卸载
```

根 `cjpm.toml`：

```toml
[workspace]
  members = ["cordis_core", "cordis_host", "cordis_plugin", "cordis_tests"]
  build-members = ["cordis_core", "cordis_host", "cordis_plugin"]
  test-members = ["cordis_core", "cordis_host", "cordis_plugin", "cordis_tests"]

# cordis_host 依赖（示例）
# [dependencies]
#   "cordis_core" = { path = "../cordis_core" }
#   "ystyle::jsonrpc" = "0.4.2"
#   "tomlcj" = "1.0.0"
# cordis_plugin 依赖 cordis_core + ystyle::jsonrpc
```

## 2. 核心数据模型（真实仓颉语法）

### 2.1 配置条目（struct，纯数据）

```cangjie
public struct PluginEntry {
    public var id: String                 // 稳定身份，Reconciler diff 的 key
    public var source: String             // 可执行文件路径（launch 的 command）
    public var args: ArrayList<String>    // 附加参数（默认空）
    public var inject: ArrayList<String>  // 依赖的服务 Key
    public var provide: ArrayList<String> // 提供的服务 Key
    public var config: TomlObject         // 插件私有配置（透传给插件）
    public var enabled: Bool              // disabled 语义

    public init(id: String, source: String, args!: ArrayList<String> = ArrayList(),
                inject!: ArrayList<String> = ArrayList(), provide!: ArrayList<String> = ArrayList(),
                config!: TomlObject = TomlObject(), enabled!: Bool = true) {
        this.id = id
        this.source = source
        this.args = args
        this.inject = inject
        this.provide = provide
        this.config = config
        this.enabled = enabled
    }
}
```

### 2.2 运行时实例（class，可变状态）

```cangjie
public enum InstanceStatus {
    | Starting       // 已 launch，等待 initialize 握手
    | Pending        // initialize 依赖缺失，保持等待重试（对齐 Cordis PENDING）
    | Active         // 握手完成，服务已注册
    | Unloading      // dispose 流程中
    | Failed         // 启动失败/崩溃
    | Unreachable    // ping 超时
}

public class PluginInstance {
    public var entry: PluginEntry
    public var process: SubProcess          // launch 返回的真实句柄
    public var client: JsonRpcClient        // 宿主 → 插件 RPC 连接
    public var status: InstanceStatus
    public var provides: HashMap<String, String>   // serviceKey -> undo_id（本插件提供）
    public var injects: ArrayList<String>          // 插件上报的依赖（握手时记录）
    public let settleLock: Mutex            // 状态转换同步（Fiber 状态机）
    public let settleCond: Condition        // awaitActive 等待状态变化
    public let terminateLock: Mutex         // 终止互斥（防并发重复杀进程）
    public var error: ?String               // 启动失败/崩溃原因（对齐 Cordis Fiber._error）

    public init(entry: PluginEntry, process: SubProcess, client: JsonRpcClient) {
        this.entry = entry
        this.process = process
        this.client = client
        this.status = InstanceStatus.Starting
        this.provides = HashMap<String, String>()
    }
}
```

**Fiber 状态机**（P14，对齐 Cordis Fiber 的 await/restart/update 语义，docs/cordis-comparison.md §4）：

- **`transitionStatus(instance, newStatus, error?)`**（PluginHost 私有）：状态转换统一入口——更新状态 + 唤醒 awaitActive 等待者 + 通知 `onStatusChange` 监听器（对齐 Cordis `internal/status` 事件）。所有状态变更必须经此方法。
- **`awaitActive(id, timeout)`**：阻塞等待插件 Active **且其 provide 服务全部注册**（Active 是握手完成，服务注册在其后）。进程死亡 → 标记 Failed 并返回错误（对齐 Cordis `await()` 重抛启动错误）；Pending（依赖缺失）继续等待；超时返回 Err。
- **`restartPlugin(id)`**：终止当前进程 → 用当前 desired entry（无 desired 时用 instance.entry）重新拉起 → awaitActive（对齐 Cordis `restart()`）。
- **`updatePlugin(id, newEntry)`**：校验新 config（schema，失败不重启）→ 更新 desired/实例 entry → restart → awaitActive（对齐 Cordis `update(config)`）。
- **`onStatusChange(listener)`**：注册状态转换监听（(pluginId, old, new)，对齐 Cordis `internal/status` 事件）。
- reconcile 的配置热更新路径复用 `updatePlugin`；崩溃自愈先标记 Failed 再重启。

### 2.3 宿主全局状态

```cangjie
public class HostState {
    public var desired: HashMap<String, PluginEntry>   // id -> 期望条目（来自 TOML）
    public var actual: HashMap<String, PluginInstance> // id -> 存活实例
    public var serviceIndex: HashMap<String, String>   // serviceKey -> 提供者插件 id
    public let lock: Mutex = Mutex()
}
```

## 3. 传输层与进程管理（宿主侧新实现）

### 3.1 通道分工（与 v1.0 §4 一致）

- 插件 **stdin**：宿主 → 插件（请求/通知）。
- 插件 **stdout**：插件 → 宿主（响应 + 插件主动请求 initialize/provide + log 通知）。
- 插件 **stderr**：仅供插件打日志，宿主起独立线程逐行转发到全局日志（同时作为崩溃诊断依据）。

### 3.2 PipeTransport（新实现，实现 `Transport`）

```cangjie
public class PipeTransport <: Transport {
    private let sub: SubProcess
    private var closed: Bool = false
    private let lock: Mutex = Mutex()

    public init(sub: SubProcess) {
        this.sub = sub
    }

    // 宿主 → 插件：写子进程 stdin
    public func send(data: Array<Byte>): Unit {
        synchronized(this.lock) {
            if (this.closed) { return }
            this.sub.stdInPipe.write(data)
            this.sub.stdInPipe.flush()
        }
    }

    // 宿主 ← 插件：读子进程 stdout（阻塞；EOF 返回 None → JsonRpcClient 自动关闭）
    public func receive(): ?Array<Byte> {
        let buffer = Array<Byte>(4096, repeat: 0)
        let len = this.sub.stdOutPipe.read(buffer)
        if (len <= 0) {
            None
        } else {
            buffer[0..len]
        }
    }

    public func close(): Unit {
        synchronized(this.lock) {
            this.closed = true
        }
        // 关闭写端，通知插件 EOF
        try { this.sub.stdInPipe.close() } catch (e: Exception) { () }
    }

    public func isClosed(): Bool {
        synchronized(this.lock) {
            this.closed
        }
    }
}
```

> 说明：`JsonRpcClient.receiveLoop` 在 `transport.receive()` 返回 `None`（stdout EOF，即插件进程退出）时自动 `running = false`，宿主据此判定意外退出（v1.0 §8.1 的自愈信号源）。

### 3.3 PluginManager（进程生命周期）

```cangjie
public class PluginManager {
    private let logger: HostLogger

    // 拉起插件进程并建立 RPC 连接（不等待握手）
    public func launch(entry: PluginEntry): PluginInstance {
        let proc = launch(entry.source, entry.args.toArray(),
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let transport = PipeTransport(proc)
        let client = JsonRpcClient(transport)
        client.start()
        return PluginInstance(entry, proc, client)
    }

    // 热卸载：先发 dispose（可选）再强杀；进程退出码由 wait 回收，避免僵尸
    public func terminate(instance: PluginInstance): Int64 {
        instance.status = InstanceStatus.Unloading
        try { instance.client.close() } catch (e: Exception) { () }
        instance.process.terminate(force: true)
        return instance.process.wait()
    }

    // stderr 转发线程
    public func forwardStderr(instance: PluginInstance): Unit {
        spawn {
            let reader = StringReader(instance.process.stdErrPipe)
            while (let Some(line) <- reader.readln()) {
                this.logger.log(instance.entry.id, "stderr", line)
            }
        }
    }
}
```

### 3.4 UDS 传输模式（`ystyle::jsonrpc_unix`，P8 新增）

除默认的 stdio（管道）外，宿主与插件可通过 **Unix Domain Socket**（UDS）通信，由主框架服务参数（`CordisConfig.transport` / `uds_path`）全局切换：

```toml
transport = "uds"              # "stdio"（默认）| "uds"
uds_path = "/tmp/cordis.sock"  # UDS 监听地址
```

**架构**：宿主为服务端（bind `uds_path`），插件为客户端（连接）。`PluginManager(udsPath)` 构造进入 UDS 模式，`launch` 时向插件进程 argv 追加 `--uds <path>`；插件侧 `PluginRuntime.run(...)` 内部用 `std.env.getCommandLine()` 自动检测 `--uds`（无需用户从 main 传参），命中则以 `UnixClientTransport` 连接。**握手/服务注册/事件/调用协议逻辑零改动**——仅替换传输层与帧协议：

| 维度 | stdio（默认） | UDS |
| :--- | :--- | :--- |
| 传输层（宿主） | `PipeTransport`（子进程管道） | `UnixServerTransport.acceptConnection()` |
| 传输层（插件） | `LineStdioTransport`（readln 逐行） | `UnixClientTransport(path)` |
| 帧协议 | `NewlineFraming`（管道 read 阻塞坑） | `ContentLengthFraming`（标准，UDS read 可靠） |
| 平台 | 全平台 | Linux/macOS（std.net 明确不支持 Windows） |
| 崩溃检测 | stdout EOF | socket EOF（`read` 返回 -1/0 → `receive()` None） |

**关键点**：

- `jsonrpc_unix` 提供 `UnixServerTransport`（bind/accept）、`UnixClientTransport`（connect）、`UnixConnectionTransport`（包装已连接 socket），均实现 jsonrpc `Transport` 接口。
- UDS 的 `UnixSocket.read(Array<Byte>)` 是标准流式读（EOF 返回 -1/0），**没有**管道 stdin 的 `ConsoleReader.read` 永久阻塞坑，因此使用 jsonrpc 默认的 `ContentLengthFraming`（与 MCP 等标准一致）。
- bind 前必须 `removeIfExists(uds_path)` 清理残留 socket 文件（std.net 文档明确：文件已存在则 bind 失败）。
- 宿主一次 bind，多插件依次连接：`launch` 同步 `acceptConnection`（超时 10s，超时判定插件启动失败并回收进程），accept 顺序与 launch 顺序一致。
- 插件进程仍由宿主 spawn（`launch`），`terminate`/`isExited`/`forwardStderr` 逻辑与 stdio 模式完全一致；进程退出 → socket EOF → `JsonRpcClient` 自关 → 崩溃自愈信号源不变。

## 4. 协议定义（JSON-RPC 2.0，换行分隔帧）

所有消息类实现 `JsonSerializable` / `JsonDeserializable<T>`（`stdx.encoding.json.stream`）。方法名常量：

```cangjie
public class Methods {
    public static let INITIALIZE: String = "initialize"      // 插件 → 宿主（请求）
    public static let INITIALIZED: String = "initialized"    // 宿主 → 插件（通知）
    public static let PROVIDE: String = "provide"            // 插件 → 宿主（请求，返回 undo_id）
    public static let DISPOSE: String = "dispose"            // 宿主 → 插件（请求）
    public static let NOTIFY: String = "notify"              // 宿主 → 插件（通知，依赖图变化）
    public static let LOG: String = "log"                    // 插件 → 宿主（通知）
    public static let INVOKE: String = "invoke"              // 双向：宿主转发服务调用
    public static let PING: String = "ping"                  // 宿主 → 插件（请求，探活）
    public static let PONG: String = "pong"                  // 插件 → 宿主（响应 ping）
}
```

### 4.1 消息体（params 的固定结构）

```cangjie
// initialize.params
public class InitializeParams <: JsonSerializable & JsonDeserializable<InitializeParams> {
    public let id: String
    public let inject: Array<String>
    public let provide: Array<String>
    public let config: ?HashMap<String, JsonValue>   // 插件私有配置（宿主透传）
    // toJson / fromJson 按 JsonWriter/JsonReader 手写实现
}

// initialize 响应 result
public class InitializeResult <: JsonSerializable & JsonDeserializable<InitializeResult> {
    public let ok: Bool
    public let providers: HashMap<String, String>   // serviceKey -> 提供者插件 id（依赖满足情况）
}

// provide.params
public class ProvideParams <: JsonSerializable & JsonDeserializable<ProvideParams> {
    public let key: String
}

// provide 响应 result
public class ProvideResult <: JsonSerializable & JsonDeserializable<ProvideResult> {
    public let undoId: String   // UUID 字符串
}

// dispose.params
public class DisposeParams <: JsonSerializable & JsonDeserializable<DisposeParams> {
    public let undoId: String
}

// notify.params（依赖图变化广播）
public class NotifyParams <: JsonSerializable & JsonDeserializable<NotifyParams> {
    public let kind: String        // "dependency-lost" | "provider-changed"
    public let key: String         // 受影响的 serviceKey
    public let provider: ?String   // 新提供者插件 id（provider-changed 时）
}

// log.params（通知）
public class LogParams <: JsonSerializable & JsonDeserializable<LogParams> {
    public let level: String   // trace/debug/info/warn/error
    public let message: String
}

// invoke.params（宿主转发服务调用；宏层后置，运行时库先提供显式调用）
public class InvokeParams <: JsonSerializable & JsonDeserializable<InvokeParams> {
    public let service: String
    public let method: String
    public let args: Array<JsonValue>
}
```

### 4.2 握手时序（对应 v1.0 §7.1，改用真实方法）

1. 宿主 `launch` 插件 B，`JsonRpcClient` 注册 `initialize` 请求处理器与 `log` 通知回调。
2. 插件 B `main` 启动 `PluginRuntime`：`JsonRpcServer.serve()` 前先 `request<InitializeParams, InitializeResult>("initialize", ...)` 完成握手。
3. 宿主 `initialize` 处理器：校验 id/依赖，回复 `InitializeResult(ok, providers)`，状态 `Starting → Active`。
4. 宿主发 `notify("initialized")` 通知插件可开始工作。
5. 插件注册服务：`request<ProvideParams, ProvideResult>("provide", ProvideParams("db"))`，宿主分配 `undoId`（UUID），更新 `serviceIndex`，回复 `ProvideResult(undoId)`。
6. Reconciler 检测 `db` 就绪 → 启动依赖方插件 A，重复 2–4。

### 4.3 热卸载时序（对应 v1.0 §7.2）

1. TOML 变更删除插件 B → 下个调谐周期 diff 出 `ToRemove`。
2. 检查依赖：A 的 `inject` 含 `db`，而 `serviceIndex["db"] == B` → 先通知 A：`notify(NotifyParams("dependency-lost", "db", None))`，A 执行内部注销逻辑后退出（或宿主等 EOF）。
3. 宿主对 B：`call<DisposeParams, JsonValue>("dispose", DisposeParams(undoId))`，B 释放本地资源后返回。
4. `PluginManager.terminate(B)`：close client + `terminate(force: true)` + `wait()` 回收。
5. 清理 `serviceIndex`、`actual` 注册表。

### 4.4 探活（v1.0 §8.2）

宿主每 N 秒对每个 `Active` 实例 `call<JsonValue, JsonValue>("ping", timeout: 3s)`；`Err`/超时 → 状态 `Unreachable` → 触发重启流程（terminate + launch + 重新握手）。

## 5. Reconciler（v1.0 §6 落地）

```cangjie
public class Reconciler {
    private let manager: PluginManager
    private let state: HostState
    private let interval: Duration = 5 * Duration.second
    private let lock: Mutex = Mutex()

    // 调谐循环：spawn 后台线程，每 interval 跑一轮
    public func start(): Unit {
        spawn {
            while (true) {
                this.reconcile()
                sleep(this.interval)
            }
        }
    }

    public func reconcile(): Unit {
        let desired = this.loadDesired()          // tomlcj 解析 → HashMap<String, PluginEntry>
        synchronized(this.lock) {
            let toRemove = this.computeToRemove(desired)   // actual - desired 或 enabled=false
            let toAdd = this.computeToAdd(desired)         // desired - actual
            let toUpdate = this.computeToUpdate(desired)   // 交叉且 source/config 变更
            // 先加后删：新进程握手成功后再杀旧进程
            this.applyAdds(toAdd)
            this.applyRemoves(toRemove)
            this.applyUpdates(toUpdate)
        }
    }

    // 拓扑排序：按 inject 依赖构建 DAG，依赖先启动；依赖缺失 → 该插件保持 Starting/Waiting
    private func topoOrder(entries: ArrayList<PluginEntry>): ArrayList<PluginEntry>
}
```

- `computeToUpdate` 的变更判定：`source` 或 `args` 不同，或 `config` 序列化字符串不同（`TomlObject.toString()` 或规范化比较）。
- 崩溃自愈：`actual` 中存在但 `client.isClosed()` 为 true（stdout EOF）→ 视为 `Failed`，下轮若 `desired` 仍存在则自动重新 launch（v1.0 §8.1）。

## 6. 插件 SDK（cordis_plugin）

```cangjie
public class PluginRuntime {
    private let server: JsonRpcServer
    private let registry: ServiceRegistry

    // 插件 main 调用：启动握手 + 事件循环，阻塞直到宿主关闭
    public static func run(pluginId: String, inject: Array<String>, provide: Array<String>): Unit {
        let transport = StdioTransport()          // 插件自身 stdin/stdout
        let server = JsonRpcServer(transport)     // NewlineFraming（换行帧）
        // 1) 握手：向宿主发 initialize 请求
        let result = server.request<InitializeParams, InitializeResult>("initialize",
            params: InitializeParams(pluginId, inject, provide))
        // 2) 注册宿主 → 插件处理器
        server.register("initialized", { ctx => ... })   // 收到可开始工作通知
        server.register("dispose", { ctx => ... })       // 按 undo_id 撤销服务
        server.register("notify", { ctx => ... })        // 依赖图变化
        server.register("ping", { _ => HandlerResult.ok(JsonValue.Boolean(true)) })
        server.register("invoke", { ctx => ... })        // 服务调用入口
        // 3) 提供服务
        for (key in provide) {
            let undoId = server.request<ProvideParams, ProvideResult>("provide",
                params: ProvideParams(key)).getOrThrow().undoId
            this.registry.register(key, undoId)
        }
        // 4) 事件循环（阻塞）
        server.serve()
    }

    public func log(level: String, message: String): Unit {
        this.server.notify<LogParams>("log", params: LogParams(level, message))
    }
}
```

- **零胶水体验（v3.0 宏）**：`@plugin` 宏将展开为上述 `main` 样板；`@provide func foo` 宏将自动注册 `invoke` 路由（反序列化 args → 调用 → 序列化返回）；`@inject var svc` 宏将生成经宿主 `invoke` 转发的代理 getter。运行时库先提供等价的显式 API（`ServiceRegistry.invoke(service, method, args)`）。

## 7. 配置格式（TOML）

```toml
# cordis.toml
interval = 5          # 调谐周期（秒），默认 5
ping_interval = 30    # 探活周期（秒），默认 30

[[plugins]]
id = "db"
source = "./target/release/bin/plugin-db"
args = []
inject = []
provide = ["db"]
enabled = true

[plugins.config]
host = "127.0.0.1"
port = 5432

[[plugins]]
id = "api"
source = "./target/release/bin/plugin-api"
inject = ["db"]
provide = ["api"]
enabled = true

[plugins.config]
listen = ":8080"
```

`ConfigLoader`（cordis_core/config.cj）：`Decoder(File(path, Read)).decode()` → 遍历 `TomlArray`，每个元素 `asObject()` → 字段用 `asString()/asArray()/asBool()` 提取 → 构造 `PluginEntry`；缺失字段用默认值。

## 8. 错误处理与可观测性（v1.0 §8 落地）

- **崩溃检测**：`PipeTransport.receive()` EOF → `JsonRpcClient` 自关 → 宿主轮询 `client.isClosed()` 或为 client 加关闭回调（spawn 等待 `client` 接收线程结束）→ 标记 `Failed`。
- **重启策略**：下个调谐周期 `desired` 仍存在 → 自动重新 launch（含 stderr 重挂、RPC 重连、重新握手）。
- **日志汇聚**：插件 `log` 通知 → 宿主 `setNotificationCallback` 统一加时间戳 + `plugin_id` 写全局日志；stderr 行由 `forwardStderr` 同样处理。
- **超时与断路**：宿主所有 `call` 使用默认 30s 超时（jsonrpc 内置）；`ping` 使用 3s 超时，避免阻塞调谐主循环。

## 9. 单元测试计划

| 包 | 测试 | 覆盖 |
| :--- | :--- | :--- |
| cordis_core | `ProtocolTest` | 每个消息类 `toJson`→`fromJson` 往返一致；方法名常量 |
| cordis_core | `ConfigTest` | TOML 字符串 → `PluginEntry` 列表；缺省字段、`enabled=false`、数组/嵌套表 |
| cordis_host | `PipeTransportTest` | 用 `launch("cat")` 子进程：`send` 后 `receive` 回显；EOF → `None` |
| cordis_host | `PluginManagerTest` | launch/terminate/wait 回收；stderr 转发 |
| cordis_host | `ReconcilerTest` | diff 四类（add/remove/update/noop）；拓扑排序；崩溃自愈 |
| cordis_plugin | `RuntimeTest` | 握手、provide/dispose 往返（用 PipeTransport 模拟宿主） |
| cordis_tests | `E2ETest` | 真实宿主拉起测试插件可执行文件：握手 → provide → 宿主 invoke 转发 → dispose → 热卸载 → 进程回收 |

## 10. 实施阶段（P0–P4）

1. **P0**：`cordis_core`（消息类 + 序列化 + ConfigLoader）+ 单测 → 提交。
2. **P1**：`cordis_host` 的 `PipeTransport` + `PluginManager` + 单测（含真实子进程）→ 提交。
3. **P2**：`cordis_plugin` SDK（PluginRuntime + ServiceRegistry + invoke 转发）+ 单测（PipeTransport 模拟宿主）→ 提交。
4. **P3**：`Reconciler` 全量 + `cordis_tests` 端到端（真实插件进程：握手/服务调用/热卸载/崩溃自愈）→ 提交。
5. **P4**：宏层 `@plugin`/`@inject`/`@provide` 宏包（参考 `kux-cj @Crud`、`CJson @JsonSerializable` 的成熟范式），作为运行时库的样板代码生成层，实现与 dsh 对齐的插件作者 DX（写业务类 + 注解即可，零样板 main/路由/序列化）。

每阶段遵循工作区规范：功能分支开发、仓颉单元测试为主、测试通过后提交、更新 `progress-tracking.md` 并沉淀 `cangjie-mem` 项目级记忆。
