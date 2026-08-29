# cordis-cj 项目进度跟踪

> 仓颉 Cordis 动态组合框架 —— 「微内核 + 进程隔离」插件框架
> 设计文档：`docs/design.md`（v1.0 草案）、`docs/design-impl.md`（v2.0 实现级）
> 仓库：https://atomgit.com/ystyle/cordis-cj.git（MIT）

## 总体计划（P0–P14）

| 阶段 | 内容 | 状态 |
| :--- | :--- | :--- |
| P0 | cordis_core：协议消息类 + 统一配置加载（TOML/JSON） | ✅ 完成 |
| P1 | cordis_host：PipeTransport + PluginManager（进程管理） | ✅ 完成 |
| P2 | cordis_plugin：插件 SDK（PluginRuntime + 服务注册 + invoke 转发） | ✅ 完成 |
| P3 | Reconciler 全量 + 端到端测试 | ✅ 完成 |
| P4 | 宏层 @Plugin/@Provide + 外部插件示例 | ✅ 完成 |
| P5 | 泛型类型安全 API：invoke<T,R> / registerHandler<T,R> | ✅ 完成 |
| P6 | 事件总线：EventRegistry + ctx.on/emit + 端到端 | ✅ 完成 |
| P7 | @Inject 宏：依赖注入 + ServiceProxy + 异步 handler | ✅ 完成 |
| P8 | UDS 传输模式：transport 服务参数 + jsonrpc_unix 接线 | ✅ 完成 |
| P9 | 语义核心（对齐 Cordis）：依赖 Waiting 重试 + 事件 v2 + 依赖变更通知 | ✅ 完成 |
| P10 | 服务系统完善：配置传递 + Config schema 校验 + Service 类化 + 配置热更新 | ✅ 完成 |
| P11 | 第三阶段增强：命名 Logger + timer + effect 诊断树 + on<T> 类型安全 | ✅ 完成 |
| P12 | 类型安全发布 emit<T>/serial<T>/... + async effect（effectAsync） | ✅ 完成 |
| P13 | 完整 waterfall next 洋葱回调（events/next 跨进程远程回调协议） | ✅ 完成 |
| P14 | Fiber 状态机：awaitActive/restartPlugin/updatePlugin + transitionStatus/onStatusChange | ✅ 完成 |
| — | 收尾：合并 master、README、LICENSE、remote、workspace 依赖简化 | ✅ 完成 |

## 已完成

### P0 — cordis_core（提交 `835d369`）

- **`cordis_core/src/methods.cj`**：JSON-RPC 方法名常量（initialize/initialized/provide/dispose/notify/log/invoke/ping/pong）+ NotifyKind/LogLevel 常量。
- **`cordis_core/src/message.cj`**：8 个协议消息类（InitializeParams/Result、ProvideParams/Result、DisposeParams、NotifyParams、LogParams、InvokeParams），全部实现 `JsonSerializable`/`JsonDeserializable<T>`（`stdx.encoding.json.stream` 直通，jsonvalue 仅用于无固定结构的 config/args 字段）。
- **`cordis_core/src/config.cj`**：`PluginEntry`/`CordisConfig` 实现 `Serializable<T>`（`stdx.serialization` DataModel 中间表示）。`ConfigLoader` 提供统一泛型入口：
  - `loadToml<T>(path)` / `parseTomlString<T>(str)` — TOML（`DataModel.fromToml`）
  - `parseJsonString<T>(str)` — JSON（`DataModel.fromJson`）
  - 同一结构 TOML/JSON 双格式读写，无格式耦合。
- **测试**：`cordis_tests` 22 用例全通过（协议往返 16 + 配置 6）。

### P1 — cordis_host（提交 `c4a1e1e`）

- **`cordis_core/src/status.cj`**：`InstanceStatus` 枚举（Starting/Active/Unloading/Failed/Unreachable），`@Derive[Equatable]`。
- **`cordis_host/src/pipe_transport.cj`**：`PipeTransport` 实现 jsonrpc `Transport` 接口——`send` 写子进程 stdin、`receive` 读子进程 stdout（EOF 返回 None，JsonRpcClient 自动停止 = 崩溃检测信号源）、`close` 置标志（OutputStream 无 close()，EOF 通知由 terminate 强杀完成）。
- **`cordis_host/src/plugin_instance.cj`**：`PluginInstance`（entry + SubProcess + JsonRpcClient + status + provides 表）。
- **`cordis_host/src/plugin_manager.cj`**：`PluginManager`——`launch`（三流 Pipe + 建连 + stderr 转发线程）、`terminate`（关连接 + 强杀 + wait 回收防僵尸）、`isExited`（client.isClosed 探测崩溃）、`forwardStderr`（StringReader 逐行转发）。
- **测试**：新增 PipeTransport 5 用例（cat 回显/close/EOF/大消息 5000 字节）+ PluginManager 3 用例（生命周期/stderr 转发/进程退出探测），共 30 用例全通过（含真实子进程）。

### P2 — cordis_plugin（提交 `76f30ae`）

- **`cordis_plugin/src/service_registry.cj`**：`ServiceRegistry`——服务注册/撤销（undo_id → disposer）+ 可逆效果列表（effect，卸载逆序执行）+ 服务处理器注册与 invoke 分发（`invokeHandler(service, method, args)`）。
- **`cordis_plugin/src/plugin_runtime.cj`**：`PluginContext`（provide/dispose/registerHandler/effect/invoke/log）+ `PluginRuntime.run(pluginId, inject, provide, handler)`——握手（initialize 请求）→ 注册服务（provide 请求拿 undo_id）→ 业务 handler → 阻塞等连接关闭 → 逆序 disposeAll。宿主 → 插件处理器：initialized/dispose/notify/ping/invoke。
- **测试基础设施**：`MemoryDuplexTransport`（内存双工管道，两端点共享单向管道）——无需真实子进程即可对接宿主 JsonRpcClient 与插件 JsonRpcServer。
- **测试**：`FakeHost`（模拟宿主）验证完整流程：握手 + 双服务 provide、invoke 转发（calc.add = 2+3 → 5）、dispose 撤销、ping 探活。共 34 用例全通过。
- **关键**：插件侧用 `JsonRpcServer.start()`（后台 receiveLoop）+ `request()`（主动请求宿主），不能 start()+serve() 双 receiveLoop；阻塞等待用轮询 `server.isClosed()`。

### P3 — Reconciler + 端到端（提交 `776aeef`）

- **`cordis_host/src/host_state.cj`**：`HostState`——desired/actual/serviceIndex/undoMap，服务注册/撤销/按提供者清理。
- **`cordis_host/src/plugin_host.cj`**：`PluginHost`——宿主侧 RPC 处理器（initialize 依赖检查 + provide 分配 undo_id + log 收集）、`launchPlugin`、`reconcile`（读 TOML → diff → 拓扑排序 → 先加后删 → 崩溃自愈 `healCrashed`）、`removePlugin`（终止 + 清理服务注册表）。
- **`cordis_plugin/src/line_stdio_transport.cj`**：`LineStdioTransport`——插件侧换行帧传输（readln 逐行 + 补回 \n）。
- **`cordis_plugin/src/examples/e2e/main.cj`**：端到端测试插件（echo/add 两服务），静态编译为独立可执行。
- **测试**：`EndToEndTest` 3 用例（真实宿主 + 真实插件进程）：完整生命周期（握手→服务注册→invoke 2+3=5→echo→热卸载清理）、配置调谐（TOML 拉起插件）、崩溃自愈（强杀后自动重启）。**共 37 用例全通过**。

### P4 — 宏层 @Plugin/@Provide + 外部插件示例（提交 `264f1a9` + `31ce0a2`）

- **`cordis_plugin/src/macros/plugin_macros.cj`**：`macro package ystyle::cordis_plugin.macros`
  - `@Plugin[]`（属性宏）：解析类声明 → 收集子宏 @Provide 消息（`getChildMessages("Provide")`）→ 生成 `main` + `PluginRuntime.run(类名, [], [keys], { ctx => let __plugin = 类名(); ctx.registerHandler(...) })` → 原类保持不变
  - `@Provide["key"]`（属性宏）：`assertParentContext("Plugin")` + `setItem("serviceKey"/"methodName")` 上报 → 保持原方法不变
  - 宏包 `public import ystyle::cordis_plugin.PluginRuntime` 重导出运行时符号（defer-cj/embed-cj 模式）
- **`cordis_plugin/src/examples/macro_demo/main.cj`**：宏插件示例（@Plugin + 2×@Provide：echo/add），静态编译
- **测试**：`EndToEndTest.testMacroPluginLifecycle`——真实宿主拉起宏插件：握手 → 双服务注册 → invoke add(2,3)=5 → echo("hello-macro") → 热卸载。**共 38 用例全通过**。
- **`cordis_examples/`**：独立模块插件示例（`PluginRuntime.run` 显式 API），模拟外部插件作者项目。
  - 验证带 org 的普通库（cordis_plugin）被独立模块跨模块依赖**完全正常**（cjpm 缺陷只影响宏包，不影响普通库）。
  - 测试：`EndToEndTest.testExternalPluginLifecycle`——真实宿主拉起独立模块插件（握手/服务注册/invoke 7+8=15/热卸载）。**共 39 用例全通过**。
  - 意义：宏缺陷规避方案 B 落地——外部插件作者用显式 API 写法即可。

### P5 — 泛型类型安全 API（提交 `26c76fa` + `c8fb003`，合并 `b51f30a` + `056b23e`）

- **`PluginContext.invoke<T, R>(service, method, args: Array<T>): R`**：参数自动序列化（`T <: JsonSerializable`）、返回自动反序列化（`R <: JsonDeserializable<R>`），与现有 `invoke(Array<JsonValue>)` 共存无冲突。
- **`PluginContext.registerHandler<T, R>(key, handler: (String, Array<T>) -> R)`**：参数自动反序列化（`T <: JsonDeserializable<T>`）、返回自动序列化（`R <: JsonSerializable`）；泛型闭包包装后存入非泛型 handlers map（关键难点，实测可行）。
- **收益**：调用方与服务端均省去手动 jsonvalue 转换，业务代码直接操作仓颉类型（基础类型或自定义 DTO），与 Cordis 类型化服务调用体验对齐。
- **测试**：`GenericInvokeExperiment` 3 用例（Int64→String echo、Int64→Int64 add、自定义 DTO 往返）+ `GenericHandlerExperiment` 2 用例（Int64→String、AddRequest DTO→Int64）。**共 44 用例全通过**。

### P6 — 事件总线（分支 `feat/event-bus`，设计 `docs/design-events.md`）

- **协议（P6.1，提交 `732b0d1`）**：`methods.cj` 新增 `events/subscribe`/`events/unsubscribe`/`events/emit`/`events/dispatch`；`message.cj` 新增 SubscribeParams/Result、UnsubscribeParams、EmitParams、DispatchParams（全部 JsonSerializable）。10 用例。
- **宿主 EventRegistry（P6.2，提交 `c129de3`）**：`event_registry.cj`——订阅/退订/按插件清理/subscriberCount/dispatch（同步按注册顺序，派发失败自动清理崩溃订阅者）；`plugin_host.cj` 接入 subscribe/unsubscribe/emit 处理器 + removePlugin 清理订阅。4 用例。
- **插件侧 API（P6.3，提交 `3545ebf`）**：`PluginContext.on(event, listener)`（effect 自动退订）/ `emit(event, args)`；PluginRuntime 注册 `events/dispatch` 本地处理器（按事件名分发监听器）。2 用例。
- **端到端（P6.4，提交 `afe6d17`）**：`examples/event_sub` + `examples/event_emit` 真实插件；`EndToEndTest.testEventBusEndToEnd`——订阅者先注册 → 发布者 emit 2 事件 → 宿主路由 → 订阅者收到并 log → 卸载后订阅清理。**共 61 用例全通过**。
- **关键修复（演进）**：早期 `setNotificationCallback` 是单回调覆盖语义，log 与 events/emit 需合并处理（独立回调会覆盖）。已给 json-rpc 的 `JsonRpcClient` 增加多回调支持（`setNotificationCallback(cb)` 单覆盖 / `setNotificationCallback(cbs)` 多覆盖 / `addNotificationCallback(cb)` 追加，提交 `5848937`）——cordis 改用 `addNotificationCallback` 独立注册 log 与 events/emit，消除合并脆弱性（提交 `cbb79d2`）。
- **事件参数**：`Array<JsonValue>`（动态结构，jsonvalue 合法使用）；v2 增强：waterfall/parallel/serial 派发模式、`on<T>` 类型安全重载（见 design-events.md §11 范围外）。

### P7 — @Inject 宏（分支 `feat/inject-macro`，提交 `3e67e69`）

- **`cordis_plugin/src/macros/plugin_macros.cj`**：`@Inject["key"]` 字段宏——`assertParentContext("Plugin")` + `setItem("injectKey"/"injectField")` 上报，字段保持原声明；`@Plugin` 宏收集 inject 列表传给 `PluginRuntime.run`、给类生成 `init(__ctx: PluginContext)` 构造函数为每个 @Inject 字段注入 `ServiceProxy`。
- **`cordis_plugin/src/service_proxy.cj`**：`ServiceProxy`——封装经宿主 invoke 转发（`call<R>` 泛型返回自动反序列化），@Inject 字段的类型。
- **`plugin_runtime.cj`**：`PluginContext.proxy(key)` 创建代理。
- **关键：异步 handler（json-rpc 0.6.0 能力，提交 `85839a9`）**：`JsonRpcServer.registerAsync`——handler 在接收线程调用但约定内部 spawn 异步任务后立即返回，接收线程不阻塞，可处理嵌套请求的响应。解决"handler 内调远程服务（@Inject 代理）的单线程事件循环死锁"。`PluginRuntime` 的 invoke/events-dispatch 改用 `registerAsync`。
- **宿主 invoke 转发**（`plugin_host.cj`）：消费者发 invoke → 查 serviceIndex 找提供者 → 用提供者连接转发 → 返回结果（@Inject 代理链路的宿主侧路由）。
- **测试**：`examples/inject_demo` 消费者插件（@Inject["add"]，经代理调用 add 5+6=11）；`EndToEndTest.testInjectMacroEndToEnd`——真实宿主 + 双插件进程（提供者 e2e + 消费者 inject_demo）。**共 62 用例全通过**。
- **用法**：
  ```cangjie
  @Plugin[]
  public class MyPlugin {
      @Inject["db"]
      public var db: ServiceProxy   // 宏注入 ServiceProxy(ctx, "db")
      @Provide["api"]
      public func query(args: Array<JsonValue>): JsonValue {
          return this.db.call<JsonValue>("query", ["SELECT 1"])  // 经宿主 invoke 转发
      }
  }
  ```

### 收尾（提交 `c9ce254` / `647c1ca` / `584c2d2` / `1e78121` / `89f1e74`）

- **分支合并**：P0–P4 + 泛型分支全部 `--no-ff` 合并回 master，feat 分支已删除。
- **README**：架构图、宏插件/显式 API/泛型三种写法、模块划分、协议、测试指南。
- **LICENSE**：根目录 MIT，各包 cjpm.toml 标注 license + repository。
- **Git remote**：`https://atomgit.com/ystyle/cordis-cj.git`，已推送。
- **workspace 依赖简化**：内部依赖从 path 改为纯版本号（cjpm 自动解析）；json-rpc 仓库的 `jsonrpc_tests` 同样纳入 workspace 成员（提交 `e3dced9`，35 用例通过）。

## 关键决策记录

1. **配置格式**：采用 tomlcj + `Serializable<T>` 统一接口，TOML/JSON 皆可（atelier 同款模式），不绑定具体格式。
2. **宏后置 P4**：运行时库先行；宏可行性已由工作区项目实证（kux-cj @Crud 生成完整服务类、CJson @JsonSerializable 生成序列化代码、defer-cj 重写函数体、embed-cj 宏内执行宿主代码）。
3. **序列化规范**：固定结构类实现 json.stream 接口；jsonvalue 仅用于无固定结构的动态字段（config/args）。
4. **jsonrpc 依赖**：中心仓 jsonrpc 0.4.2 无配套 jsonrpc_stdio（0.4.1 未发布）→ 全部改用本地 path 依赖 `../../json-rpc/jsonrpc`（版本一致、stdio 可用）。
5. **帧协议改为换行帧（重要修正）**：仓颉 `ConsoleReader.read(Array<Byte>)` 在管道 stdin（子进程被 launch 拉起的场景）下永久阻塞，无法用于 Content-Length 帧；`readln()` 可靠。→ 插件侧 `LineStdioTransport`（readln 逐行 + 补回 `\n`）+ `NewlineFraming`，宿主侧 PipeTransport 同步 `NewlineFraming`（与 mcp-cj 生产方案一致）。设计文档 §4 的 Content-Length 帧在此环境不可行，已修正。
6. **宏架构（P4）**：宏包与插件 SDK 同模块（CJson 模式）；宏展开代码引用运行时符号需宏包 `public import` 重导出；`@Plugin`/`@Provide` 是属性宏（双 Tokens 参数），调用须带 `[]`（`@Plugin[]` 空属性合法）且大小写匹配定义。
7. **泛型 API（P5）**：`invoke<T,R>` / `registerHandler<T,R>` 用分开的约束（`T <: JsonSerializable, R <: JsonDeserializable<R>`），避免交集约束 `T <: A & B<T>` 的推断问题；与 JsonValue 版共存无重载冲突（实测）。
8. **workspace 依赖**：成员间依赖用纯版本号自动解析，不写 path（cjpm workspace 自动处理）；非成员外部依赖（jsonrpc）保留 path。

## 工程要点（踩坑记录）

- cjpm workspace 中，源码包声明必须用全限定名：`package ystyle::cordis_core`（`organization::name`）。
- workspace 成员间依赖用纯版本号（`"ystyle::cordis_core" = "0.1.0"`）自动解析；test-members 必须是 build-members 的子集。
- `ArrayList` 构造：`ArrayList.of([...])`（Array→ArrayList）；`ArrayList(x)` 是容量构造。
- tomlcj 的 `parse(str).mapping` 的 mapping 非 public，字符串解析应走 `Decoder(ByteBuffer(str.toArray()))`。
- `@Expect` 比较 JsonValue 需要 Equatable（jsonvalue 未实现）→ 用 `match` 断言。
- 泛型交集约束 `T <: A & B<T>` 在 `JsonValue.fromObject/toObject` 处推断困难 → 泛型方法用分开的约束（`T <: JsonSerializable, R <: JsonDeserializable<R>`）；测试往返直接用 `JsonWriter`/`JsonReader` 直通。
- `OutputStream` 无 `close()` 接口 → PipeTransport.close 只置标志，通知插件 EOF 由 terminate 强杀完成（stdout 关闭 → 宿主 receive EOF）。
- 函数类型参数不能直接用 lambda 字面量做默认值 → 拆两个 init 重载。
- `InstanceStatus` 枚举比较需要 `@Derive[Equatable]`（默认无 `==`）。
- 测试真实子进程：cat 不退出时 `readToEnd` 会永久阻塞 → 循环 receive 计数收满 + `terminate(force: true)` + `wait()` 防僵尸。
- 测试挂起时用 `timeout 120 cjpm test` 包裹防死锁。
- 仓颉测试类内不能嵌套 class → 辅助类（FakeHost）放 @Test 类外顶层；测试辅助文件若无 @Test 宏会报 main 缺失 → 辅助类并入有 @Test 的测试文件；executable 包不能自 import → 测试辅助类需在文件内内嵌。
- 无参 lambda 语法是 `{ => expr }`，不是 `{ () => expr }`。
- `JsonValue` 的 `[](key)` 返回 `?JsonValue`（Option），match 需 `case Some(JsonValue.String(k))`。
- `JsonRpcClient.call("method")` 无参重载是非泛型的，不能带 `<T, R>` 类型参数。
- 插件侧不能 `start()` + `serve()` 并用（双 receiveLoop 竞争读 transport）→ `start()` 后台接收 + 轮询 `isClosed()` 阻塞主线程。
- **仓颉 ConsoleReader 管道 bug（P3 最大坑）**：子进程被 launch 拉起后，`getStdIn().read(Array<Byte>)` 永久阻塞，`readln()` 正常 → 插件侧必须用 readln 逐行 + 换行帧协议。
- **双重去换行**：readln 已去掉行尾 `\n`，若再让 NewlineFraming 找 `\n` 永远解析不了 → LineStdioTransport.receive() 必须补回 `\n`。
- 测试类 `@Expect(exists(Path(...)))` 等路径断言；`File` 无 delete()，用 `std.fs.remove(Path(p))`。
- cjpm package-configuration 键：`"cordis_plugin.examples.e2e"`（无 organization 前缀），examples 目录需父包声明文件（examples.cj），子包目录名 = 包尾名（e2e 而非 e2e_plugin）。
- **宏踩坑（P4）**：
  - `macro` 是仓颉关键字，不能做包名（`examples.macro` 非法）→ 用 `macro_demo` 等。
  - TokenKind 无 LBRACKET/RBRACKET，方括号是 `LSQUARE`/`RSQUARE`。
  - 属性宏调用必须带 `[]` 且大小写匹配定义：`@Plugin[]`（不是 `@plugin`）。
  - 宏展开代码引用运行时符号：宏包 `public import ystyle::cordis_plugin.PluginRuntime`，展开代码用短名（不能用 `ystyle::cordis_plugin.PluginRuntime` 限定路径，宏展开上下文解析失败）。
  - **跨模块带 organization 的宏依赖传递有 cjpm 缺陷**（详见 [macro-org-dependency-issue.md](./macro-org-dependency-issue.md)：同模块带 org 可用、跨模块失败、去掉 org 跨模块立即可用；`organization` 必须是合法标识符，不能含 `.`）。
  - `getChildMessages("Provide")` 收集子宏消息：子宏 `assertParentContext("Plugin")` + `setItem("serviceKey"/"methodName")`。
  - quote 插值：`$(String)` 生成带引号字符串字面量；标识符用 `Token(TokenKind.IDENTIFIER, name)`；`$(ArrayList<Tokens>)` 有限制 → 用 `Tokens + Token(TokenKind.NL)` 手动拼接。
- **泛型 API 踩坑（P5）**：
  - `Array<T> |> map { a: T => JsonValue.fromObject(a) } |> collectArray` 需要 lambda 参数类型标注（`a: T`），否则无法推断。
  - spawn 内捕获可变局部变量会报错 → 结果收集放进共享对象（如 FakeHost）的方法调用。
  - `JsonValue` 的 map 赋值（`reqJson["a"] = ...`）不支持 → 先构造 `HashMap<String, JsonValue>` 再转 `JsonValue.Map`。

### P8 — UDS 传输模式（分支 `feat/uds-transport`）

- **`jsonrpc_unix` 现成复用**：json-rpc 仓库已发布 `ystyle::jsonrpc_unix` 0.6.0（UnixServerTransport / UnixClientTransport / UnixConnectionTransport），cordis 只接线不改传输实现。
- **`cordis_core/src/config.cj`**：`CordisConfig` 加 `transport`（"stdio"/"uds"，默认 "stdio"）+ `uds_path` 字段（TOML/JSON 双格式序列化）。
- **`cordis_host/src/plugin_manager.cj`**：`PluginManager(udsPath)` 进入 UDS 模式——`launch` 分支：bind `uds_path`（bind 前 `removeIfExists` 清理残留）→ spawn 插件（argv 追加 `--uds <path>`）→ `acceptConnection(10s)` → `JsonRpcClient(ContentLengthFraming)`；新增 `close()` 关闭监听；`terminate`/`isExited`/`forwardStderr` 与 stdio 模式共用。
- **`cordis_plugin/src/plugin_runtime.cj`**：新增 `runUds(udsPath, ...)`（UnixClientTransport + ContentLengthFraming）与 `parseUdsArg(args)`（解析 `--uds <path>`）；e2e 示例插件 main 支持两种模式自动切换。
- **测试**（新增 10 用例，全量 72 通过）：
  - `UdsTransportTest`（5）：回环 echo、生命周期（EOF→isClosed）、多连接、server 关闭拒绝新连接、残留 socket 清理。
  - `ConfigLoaderTest`（2 新）：TOML uds 模式解析、serialize 往返。
  - `UdsModeEndToEndTest`（3）：真实宿主 + 真实插件进程全流程（握手/服务注册/invoke/热卸载）、reconcile 从配置（transport=uds）拉起、崩溃自愈（socket EOF 检测重启）。
- **踩坑（P8）**：
  - `std.fs.remove(Path)` 在文件不存在时抛 FSException → 用 `removeIfExists`。
  - `UnixConnectionTransport.isClosed()` 只反映本端显式关闭；对端关闭需先 `receive()` 感知 EOF（与管道语义一致）。
  - `acceptConnection(timeout: Duration)` 是位置参数（无 `!` 后缀），不能命名调用。
  - 属性初始化 `private let udsPath: ?String = None` 不可再赋值 → UDS 模式用 `var`。

### P9 — 语义核心：依赖 Waiting 重试 + 事件 v2 + 依赖变更通知（分支 `feat/semantic-core`）

对齐 Cordis 4.x 语义核心（[docs/cordis-comparison.md](./cordis-comparison.md) §4 第一阶段），三块：

1. **依赖 Waiting 重试**（对齐 Cordis PENDING）：
   - `InstanceStatus` 加 `Pending`（initialize 依赖缺失时宿主置 Pending，而非 Starting/拒绝）。
   - 插件侧 `PluginRuntime.start` 握手改为重试循环：`ok=false` 不抛异常退出，保持等待（`waitForDependencyChange` 最长 1s，可被宿主 notify 唤醒）。
   - 宿主侧 initialize handler：依赖缺失 → `instance.status = Pending` + 返回 `ok=false`（不再日志 "rejected"）。
   - 测试：`PluginRuntimeTest.testPendingRetryUntilDepsReady`（FakeHost 依赖后置就绪）+ `EndToEndTest.testDependencyWaitingLifecycle`（真实进程：消费者先启动 Pending → 提供者后启动 → 消费者自动 Active）。

2. **事件总线 v2**（对齐 Cordis DispatchMode / once / prepend，docs/design-events.md §7）：
   - 协议：`EmitParams` 加 `mode`；`DispatchParams` 加 `mode`；`SubscribeParams` 加 `once`/`prepend`；新增 `EventMode` 常量类（emit/parallel/serial/bail/waterfall）。
   - 宿主 `EventRegistry`：`subscribe(..., once, prepend)` + `dispatch(event, args, mode, emitId): ?JsonValue`——emit 同步广播 / parallel 并发等待 / serial+bail 按序遇 bail 停 / waterfall 链式传值；once 派发后自动退订；prepend 头部插入。`isBailValue` 对齐 Cordis（null/false 非 bail）。
   - 插件侧 `PluginContext`：`on`（Unit）/ `once` / `onVal`（返回 ?JsonValue，serial/bail/waterfall 用）/ `emit`（通知式）/ `parallel`（通知式）/ `serial` / `bail` / `waterfall`（请求式，宿主聚合返回）；`PluginRuntime` 的 dispatch handler 返回 listener 的 `?JsonValue`。
   - 测试：`EventDispatchModeTest`（7：emit 广播/serial bail 短路/waterfall 链/parallel 并发/once 自动退订/prepend 顺序，内存双端真实往返）+ `PluginEventTest` 4 个新用例（serial/waterfall/parallel 协议往返 + once/prepend 订阅标记）。
   - 踩坑：`on` 的 Unit / `?JsonValue` listener 重载 + 带默认参数版本 → lambda 重载歧义（仓颉无法从 lambda 推断返回类型）→ 返回值版命名为 `onVal`，去掉带默认参数的 `on` 重载；宿主侧 request handler 内不能同步 `client.call`（单线程事件循环死锁）→ 插件侧协议往返测试用「预设响应」而非在 handler 内再发请求（真实聚合逻辑由 EventDispatchModeTest 覆盖）。

3. **依赖变更通知**（对齐 Cordis reflect.notify）：
   - `PluginInstance` 加 `injects`（initialize 握手时记录插件上报的依赖）；`HostState.dependentsOf(key)` 返回依赖该服务的存活实例。
   - 宿主 `PluginHost.notifyDependents(key, kind, provider)`：`provide` 成功 → `PROVIDER_CHANGED` 通知 Pending 依赖者（唤醒立即重试）；`removePlugin` 服务撤销 → `DEPENDENCY_LOST` 通知依赖者。通知为 fire-and-forget notify 消息。
   - 插件侧 `handleNotify`：记录 `lastNotify`；`PROVIDER_CHANGED` 置 `dependencyChanged` + `retryCond.notifyAll()` 唤醒等待中的握手循环。
   - 测试：`PluginRuntimeTest.testNotifyWakeupAcceleratesRetry`（FakeHost 发 PROVIDER_CHANGED → 600ms 内恢复，快于 1s 轮询）+ `EndToEndTest.testDependencyNotificationOnRemove`（提供者移除 → 宿主日志含 "notify dependency-lost add"）。

**全量 87 用例通过**（新增 13）。

### P10 — 服务系统完善：配置传递 + Config schema + Service 类化 + 配置热更新（分支 `feat/service-phase2`）

1. **配置传递**（热更新前置）：
   - `InitializeResult` 加 `config: ?JsonValue`（宿主下发 `entry.config`，DataModel→JsonValue）。
   - 插件侧 `PluginRuntime.pluginConfig` + `PluginContext.config` 属性（`cfg.toDataModel()` 转回 DataModel）。
   - 测试：`PluginRuntimeTest.testConfigPassedToPlugin`（FakeHost 下发 host/port → 插件读到）。
   - 踩坑：`DataModel.fromJson`（stdx）与 jsonvalue 的 `JsonValue` 是**不同类型**（stdx class vs jsonvalue enum）→ 用 jsonvalue 包自带的 `JsonValue.toDataModel()`（jsonvalue.cj 已实现）避免跨包转换；`stdx.encoding.json.*` 与 `jsonvalue.*` 同时 import 会 JsonValue 冲突。

2. **Config schema 校验**（`cordis_core/src/config_schema.cj`）：
   - `ConfigFieldSpec`（name/typeName/required）+ `ConfigSchema`：`validate`（宽松）/ `validateStrict`（含未知字段检查）；类型 string/bool/int/float/array/object；错误路径化（如 `plugins[0].config.port: expected int, got string`）。
   - `PluginHost.registerSchema(pluginId, schema)` + `launchPlugin` 前置校验（失败抛异常，reconcile 捕获记录日志）。
   - 测试：`ConfigSchemaTest`（7 用例：合法通过/缺必填/类型不匹配/未知字段严格模式/空配置/int 接受整值 float/宿主拒绝非法配置）。
   - 踩坑：`type` 是仓颉关键字 → 字段名 `typeName`；`DataModelStruct.get(name)` 返回 DataModel 非 Option（缺失为 DataModelNull）→ 用 `is DataModelNull` 判断。

3. **Service 类化**（`cordis_plugin/src/service.cj`，对齐 Cordis `Service`）：
   - `Service` 抽象基类：构造 `super(ctx, name)` 自动 `ctx.provide`；`register(method, handler)` 方法路由；`bind()` 构造末尾接入 invoke 分发；`check()` 可用性谓词（可覆写）。
   - **仓颉限制**：可继承类的构造函数不能捕获 `this` → registerHandler 闭包移到 `bind()`（对齐 Cordis `[Service.init]` 构造后钩子）；可覆写方法需 `open`。
   - 测试：`ServiceClassTest`（2 用例：自动注册+invoke 往返、check 谓词）。
   - 踩坑：构造参数默认值需 `!` 后缀（`ready!: Bool = true`）；子类成员变量需在构造最前初始化（`register` 前）。

4. **配置热更新**（e2e）：
   - `entryChanged` 已比较 config（DataModel stringify）→ `computeToUpdate` → 重启插件；配置传递打通后热更新真正生效。
   - e2e 插件加 `config.offset`（add 结果加偏移）；测试：`EndToEndTest.testConfigHotReload`（offset 10→100，add 结果 15→105）。
   - 踩坑：`cjpm test` 只编译测试目标，**插件二进制需 `cjpm build` 重建**才生效（修改 examples 后直接跑测试会得到旧二进制行为）。

**全量 98 用例通过**（新增 11）。

### P11 — 第三阶段增强：命名 Logger + timer + effect 诊断树 + on<T>（分支 `feat/phase3-tools`）

1. **命名 Logger**（`cordis_plugin/src/logger.cj`，对齐 Cordis `ctx.logger(name)`）：
   - `PluginLogger`（trace/debug/info/warn/error）；`LogParams` 加 `logger: ?String`（向后兼容 None）；`ctx.logger(name)` 创建。
   - 测试：`Phase3ToolsTest.testNamedLogger`（logger="db" 与默认区分）。
2. **timer 工具**（`cordis_plugin/src/timer.cj`，对齐 Cordis timer）：
   - `ctx.timeout/interval`（std.sync.Timer.once/repeat，可撤销）；`ctx.throttle/debounce`（ThrottleState/DebounceState 类封装状态，避免闭包捕获可变变量）。
   - 测试：timeout 触发+撤销、interval 周期+撤销、throttle 合并（3 次调 1 次执行）、debounce 只执行最后一次。
   - 踩坑：DateTime 无 toMillisecond → throttle 用 `MonoTime.now()` 相减比 Duration；throttle 首次应执行 → `lastRun: ?MonoTime = None` 首调必执行。
3. **effect 诊断树**（`ServiceRegistry`，对齐 Cordis Fiber.getEffects）：
   - `effect(disposer)` / `effect(disposer, label)`；effects 存 `(label, disposer)` 元组；`getEffects(): ArrayList<String>`（注册顺序）。
   - 测试：`testGetEffectsDiagnostics`（两个带 label 效果可见）。
4. **事件 `on<T>` 类型安全**（PluginContext，对齐 Cordis TS 泛型）：
   - `ctx.on<T>` / `once<T>` / `onVal<T>`（`T <: JsonDeserializable<T>`）：事件 args[0] 自动反序列化为 T，listener 直接操作仓颉类型。
   - 测试：`testOnTypedEvent`（GreetPayload DTO 经宿主 dispatch → 插件 on<T> 反序列化 → listener 收到）。
   - 踩坑：jsonvalue 序列化 Number 为 float → DTO 数值字段用 Float64（Int64 反序列化失败）；`--show-all-output` 会把测试宏展开源码混入输出，断言失败时看 `logs=[...]` 实际值而非源码行；Float64 42.0 的 toString 是 "42.000000"（断言 startsWith 匹配）。

**全量 104 用例通过**（新增 6）。

### P11.5 — 传输自动检测（`PluginRuntime.run` 免传参）

- `PluginRuntime.run(...)` 内部用 `std.env.getCommandLine()` 获取进程命令行，`autoUdsPath()` 检测宿主传入的 `--uds <path>`（有则 UDS + ContentLengthFraming，无则 stdio + NewlineFraming）——**插件 main 无需接收/透传 args，直接 `main(): Int64 { PluginRuntime.run(...); return 0 }`**。
- `parseUdsArg(args)` 保留（公共辅助）；`runUds(udsPath, ...)` 保留（显式 UDS 入口）；新增 `autoUdsPath()`（`getCommandLine()` 异常时退化为 None → stdio）。
- 示例插件（e2e 等）main 去掉 `args` 参数与 match 分支；宏生成 main 本就无参，自动受益。
- 测试：`Phase3ToolsTest.testAutoUdsPathDetection`（parseUdsArg 带/不带 --uds + autoUdsPath 当前进程 None）+ `UdsModeEndToEndTest`（真实宿主拉起，getCommandLine 识别 --uds 全过）。
- 踩坑：`std.env.getCommandLine()` 文档标注平台差异（Windows 可获取/其他场景可能异常），`autoUdsPath` 用 try-catch 兜底退化为 stdio。

### P12 — 类型安全发布 emit<T> + async effect（分支 `feat/typed-emit-async`）

1. **`ctx.emit<T>/parallel<T>/serial<T>/bail<T>/waterfall<T>`**（`T <: JsonSerializable`）：
   - 发布侧参数自动序列化（`args |> map { a: T => JsonValue.fromObject(a) } |> collectArray`），与订阅侧 `on<T>` 配套，发布者直接传仓颉类型。
   - 测试：`Phase3ToolsTest.testEmitTyped`（非泛型 emit + 泛型 emit<T> 对照，事件经宿主扇出）、`testSerialTyped`（请求式 + 聚合结果）。
2. **async effect（`ctx.effectAsync`）**：
   - `ServiceRegistry` effects 改存 `(String, () -> ?Future<Unit>)`：`effect(disposer)` 同步包装为 `{ => disposer(); None }`；`effectAsync(disposer, label)` 返回 Future；`disposeAll` 逆序执行并 `fut.get()` 等待异步 disposer 完成。
   - 顺带修复 P11 遗留 bug：仓颉 range `a..b` 仅递增（a<=b）→ 逆序遍历 effects 用显式 `var i = size-1; while (i >= 0)`（原 for-range 逆序为空循环，disposeAll 从不执行 disposer）；元组取元素需解构 `let (_, disposer)`（`tuple[1]` 触发 IndexOutOfBoundsException）。
   - 测试：`testAsyncEffectWaitedOnDispose`（同步 + 异步 + 服务三 disposer，200ms 异步被等待，disposeAll 后 snapshot.size == 3 全部执行）。
3. 踩坑：FakeHost 的 `setNotificationCallback` 是**覆盖语义**（多次 set 互相覆盖）——setupToolsHost 曾有两个 set（EMIT 与 LOG）互相覆盖导致 testEmitTyped 收不到 EMIT 通知，改为合并成一个 callback（`if EVENTS_EMIT {...} else if LOG {...}`）。

**全量 108 用例通过**（新增 3）。

### P13 — 完整 waterfall next 洋葱回调（跨进程远程回调协议，分支 `feat/typed-emit-async`）

- **协议扩展**（`cordis_core`）：
  - `DispatchParams` 加 `nextAllowed: Bool`（默认 false，仅 true 时序列化）——waterfall 派发时订阅者侧构造 next 回调。
  - 新方法 `Methods.EVENTS_NEXT` + `NextParams(emitId)`（插件 → 宿主请求，waterfall 链推进）。
- **宿主侧**（`cordis_host`）：
  - `EventRegistry`：`chains[emitId] = WaterfallChain(event, targets, args)`（订阅者快照 + 推进索引 + 参数，索引同步推进）；`dispatchWaterfall` 注册链并阻塞在订阅者 0 的 dispatch 响应上，`dispatchNext(emitId)` 推进 index 调下一个订阅者（`callSubscriber(..., nextAllowed: true)`），链结束返回 None（内置行为）。
  - **递归在响应路径完成**：每个 `next()` 的响应 = 内层链结果，listener 透传/改写后作为自己的派发结果 → `dispatchWaterfall` 的响应即整条链结果（最外层订阅者返回值，对齐 Cordis）。
  - veto 短路：订阅者返回非 null 值（不调 next）→ 立即返回该值，后续订阅者不再被调用。
  - `PluginHost` 注册 `events/next` request handler → `eventRegistry.dispatchNext(emitId)`。
- **插件侧**（`cordis_plugin`）：
  - listener 内部签名改为 `(Array<JsonValue>, ?(() -> ?JsonValue)) -> ?JsonValue`（next 仅 waterfall 派发时非 None）；on/once/onVal/on<T>/once<T>/onVal<T> 适配忽略 next。
  - 新 API：`ctx.onWaterfall(event, (args, next) -> ?JsonValue)` + 泛型 `onWaterfall<T>`。
  - EVENTS_DISPATCH handler：`nextAllowed=true` 时构造 next 闭包（`server.request<NextParams, JsonValue>(EVENTS_NEXT, ...)`，`JsonValue.Null` → None）。
- **测试**（新增 4，全量 111 通过）：
  - `EventDispatchModeTest.testWaterfallVetoShortCircuits`（veto 短路，订阅者2 不被调用）
  - `testWaterfallNextChainsToNext`（next 推进链，结果 = 订阅者2 返回值）
  - `testWaterfallAllNextReturnsBuiltin`（全部调 next → 内置行为 None）
  - `PluginEventTest.testOnWaterfallNextRoundTrip`（插件侧 onWaterfall → listener 调 next() → 宿主 events/next 响应 → 结果回宿主）
- **设计要点**：跨连接无死锁——每次 `callSubscriber` 阻塞"发起方"连接线程，响应由"目标订阅者"连接线程处理；插件侧 `registerAsync` + spawn 保证接收线程不被 listener 阻塞。详见 `docs/design-events.md §7.1`。

### P14 — Fiber 状态机：await/restart/update（分支 `feat/fiber-state-machine`）

对齐 Cordis Fiber（fiber.ts）的 `await()/restart()/update()` 语义与 `internal/status` 事件：

1. **状态转换统一入口 `transitionStatus(instance, newStatus, error?)`**（PluginHost 私有）：
   - 更新状态 + 唤醒 awaitActive 等待者（settleCond.notifyAll）+ 通知 `onStatusChange` 监听器（对齐 Cordis `_updateState` 的 `internal/status` 事件）。
   - initialize 握手（Active/Pending）、removePlugin（Unloading）、崩溃自愈（Failed）全部改走此入口。
2. **`PluginHost.awaitActive(id, timeout): Result<PluginInstance>`**（对齐 Cordis `await()`）：
   - 阻塞等待插件 Active **且其 provide 服务全部注册**（Active 是握手完成，服务注册在其后——invoke 前必须可用）。
   - 进程死亡/启动失败 → 标记 Failed 并返回错误（对齐 Cordis await 重抛启动错误 `_error`）；Pending（依赖缺失）继续等待（依赖就绪自动 Active）；超时 Err。
   - 条件变量等待 + 总超时（MonoTime 截止线），非轮询。
3. **`PluginHost.restartPlugin(id)`**（对齐 Cordis `restart()`）：
   - 终止当前进程 → 用当前 desired entry（无 desired 时用 instance.entry）重新拉起 → awaitActive。
   - 实例不存在 → Err（对齐 Cordis assertActive 已 dispose）。
4. **`PluginHost.updatePlugin(id, newEntry)`**（对齐 Cordis `update(config)`）：
   - Config schema 校验（失败 Err 且不重启，对齐 Cordis resolveConfig 抛 ValidationError）→ 更新 desired/实例 entry → restart → awaitActive。
   - reconcile 的配置热更新（computeToUpdate）复用此路径。
5. **`PluginHost.onStatusChange(listener)`**：注册状态转换监听（(pluginId, old, new)），宿主应用可感知生命周期（对齐 Cordis `internal/status`）。
6. **PluginInstance 增强**：settleLock/settleCond（状态同步）、terminateLock（终止幂等：防并发重复杀进程）、error（Failed 原因）。
7. **修复**：PluginManager.terminate 幂等判断改为 terminateLock.tryLock（原"状态已 Unloading 即跳过"在 removePlugin 预置状态后会导致进程泄漏）。

**测试**（新增 `FiberStateTest` 8 用例，全量 119 通过）：
- `testAwaitActiveWaitsForHandshake`（launch 后 awaitActive 等到 Active + 服务注册，替代轮询 sleep）
- `testAwaitActiveTimeout`（/bin/sleep 永不握手 → 超时 Err）
- `testAwaitActiveFailedWhenProcessDies`（/bin/false 启动即死 → Failed + Err）
- `testRestartPluginKeepsEntry`（重启后新实例 Active + 服务可用 + invoke 5.0）
- `testRestartPluginNotFound`（实例不存在 → Err）
- `testUpdatePluginConfigRestarts`（offset 0→100 重启后 add(2,3)=105）
- `testUpdatePluginInvalidConfigRejected`（schema 校验失败 → Err 且 pid 不变不重启）
- `testStatusListenersReceiveTransitions`（onStatusChange 收到 Starting→Active）
- 踩坑：InstanceStatus 的 ToString 输出带限定名 `InstanceStatus.Active`（断言 contains 用全名）；`while(true)` 表达式是 Unit，需尾部兜底 return。

## 待办 / 下一步

- [ ] 发布流程（cangjie-publish）：注意宏库带 organization 跨模块消费缺陷——若对外发布宏，评估去 org 或实测中心仓拉取路径
- [ ] cordis-cj 发版 0.2.0（P8 UDS + P9 语义核心 + P10 服务系统 + P11 增强 + P12/P13/P14）（中心仓 gjson 1.2.1 同步问题待恢复后继续）
