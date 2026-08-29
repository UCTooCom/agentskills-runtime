# Cordis 事件总线 —— 设计文档（v1.0）

**文档状态**：实现前设计稿
**关联**：`docs/design-impl.md` §4（协议）、`docs/progress-tracking.md`（进度）
**目标**：为 cordis-cj 增加插件间**解耦事件通信**，对齐 Cordis `ctx.on/emit/waterfall/parallel/serial` 语义（参考 dsh 的 `docs/cordis-api/events.md` 与 `docs/cordis-tutorial/04-events.md`）。

---

## 1. 设计目标

1. **解耦**：插件 A 发布事件不关心谁在听；插件 B 订阅事件不需要知道 A 是谁（与现有"服务调用"点对点语义互补）。
2. **复用现有链路**：事件经宿主路由（插件 → 宿主 → 订阅者），复用换行帧 JSON-RPC、PluginHost、PipeTransport，不引入新传输。
3. **对齐 Cordis 派发模式**：`emit`（同步广播）为 v1 核心，`waterfall`/`parallel`/`serial` 作为 v2 增强（见 §7）。
4. **生命周期绑定**：订阅是"效果"（effect）——插件卸载时自动取消订阅（对齐 Cordis `ctx.on` 语义）。

## 2. 术语

| 术语 | 含义 |
| :--- | :--- |
| 事件名（event name） | 全局唯一的字符串标识，如 `"stats/report"`、`"agent/request"` |
| 发布者（publisher） | 调用 `ctx.emit` 的插件 |
| 订阅者（subscriber） | 调用 `ctx.on` 的插件 |
| 派发模式（dispatch mode） | 事件的分发策略（emit/waterfall/parallel/serial） |

## 3. 总体流程

```
插件 A（发布者）                     宿 主                      插件 B / C（订阅者）
     │  ctx.emit("stats/report", n)   │                            │
     │ ──────────────RPC────────────▶ │  EventRegistry 查订阅者     │
     │                                │ ────── dispatch ─────────▶ │ B.on(...) 执行
     │                                │ ────── dispatch ─────────▶ │ C.on(...) 执行
     │                                │ ◀────────── 结果/无 ────── │
     │ ◀──────── 汇总（可选）───────── │                            │
```

- 事件参数：`Array<JsonValue>`（复用现有动态值处理，无固定结构 → jsonvalue 合法使用）。
- 订阅注册：插件启动时 `ctx.on` → 宿主 `EventRegistry` 记录（插件 id, 事件名, 回调）。

## 4. 协议扩展（JSON-RPC 2.0，换行帧）

### 4.1 方法名（新增至 `cordis_core/src/methods.cj`）

| 方法 | 方向 | 类型 | 说明 |
| :--- | :--- | :--- | :--- |
| `events/subscribe` | 插件 → 宿主 | 请求（返回订阅 id） | 订阅事件 |
| `events/unsubscribe` | 插件 → 宿主 | 请求 | 取消订阅（插件卸载时） |
| `events/dispatch` | 宿主 → 插件 | 请求（返回处理结果） | 向单个订阅者派发事件 |
| `events/emit` | 插件 → 宿主 | 通知 | 发布事件（宿主负责扇出） |

> 订阅/退订用**请求**（需确认）；派发用**请求**（emit 模式需等订阅者处理完，保证"同步广播"语义）；发布用**通知**（发布者不等待，宿主异步扇出）。
> 说明：`emit` 在 Cordis 中是"同步广播、不等结果"，但跨进程场景发布者的"不等待"是用户感知——内部宿主仍需同步等订阅者处理完，保证订阅者侧的顺序性。v1 按"宿主同步派发"实现。

### 4.2 消息类（新增至 `cordis_core/src/message.cj`，全部实现 JsonSerializable/JsonDeserializable）

```cangjie
// events/subscribe.params
public class SubscribeParams <: JsonSerializable & JsonDeserializable<SubscribeParams> {
    public let event: String      // 事件名
}

// events/subscribe 响应 result
public class SubscribeResult <: JsonSerializable & JsonDeserializable<SubscribeResult> {
    public let subscriptionId: String   // 订阅 id（退订用）
}

// events/unsubscribe.params
public class UnsubscribeParams <: JsonSerializable & JsonDeserializable<UnsubscribeParams> {
    public let subscriptionId: String
}

// events/emit.params（通知）
public class EmitParams <: JsonSerializable & JsonDeserializable<EmitParams> {
    public let event: String
    public let args: Array<JsonValue>
}

// events/dispatch.params（宿主 → 订阅者）
public class DispatchParams <: JsonSerializable & JsonDeserializable<DispatchParams> {
    public let event: String
    public let args: Array<JsonValue>
    public let emitId: String      // 一次 emit 的唯一标识（v2 聚合结果用，v1 仅透传）
}
```

## 5. 宿主侧：EventRegistry

### 5.1 结构（新增 `cordis_host/src/event_registry.cj`）

```cangjie
public class EventRegistry {
    // 事件名 -> 订阅者列表（有序，保持注册顺序）
    private let subscribers: HashMap<String, ArrayList<Subscription>>
    // subscriptionId -> Subscription（退订用）
    private let byId: HashMap<String, Subscription>
    private let lock: Mutex = Mutex()

    public class Subscription {
        public let id: String
        public let pluginId: String
        public let event: String
        public let instance: PluginInstance   // 派发目标连接
    }
}
```

### 5.2 API

| 方法 | 说明 |
| :--- | :--- |
| `subscribe(event, pluginId, instance): String` | 注册订阅，分配 subscriptionId |
| `unsubscribe(subscriptionId): Bool` | 取消订阅 |
| `unsubscribeAll(pluginId): Unit` | 插件卸载时清理其全部订阅 |
| `dispatch(event, args, emitId): Unit` | 向该事件所有订阅者派发（遍历调用 instance.client 的 `events/dispatch`） |

### 5.3 接入 PluginHost

- `PluginHost` 增加 `eventRegistry: EventRegistry`。
- `registerHostHandlers` 中注册：
  - `events/subscribe` 请求处理器 → `eventRegistry.subscribe` + 返回 subscriptionId
  - `events/unsubscribe` 请求处理器 → `eventRegistry.unsubscribe`
  - `events/emit` 通知回调 → 查订阅者 → 逐个 `dispatch`（同步遍历）
- `removePlugin` 中调用 `eventRegistry.unsubscribeAll(pluginId)`（生命周期绑定）。

## 6. 插件侧 API（`PluginContext` 扩展）

```cangjie
/**
 * 订阅事件：插件卸载时自动取消订阅（效果语义）
 * @param event 事件名
 * @param listener 回调（参数列表）
 * @return 订阅 id
 */
public func on(event: String, listener: (Array<JsonValue>) -> Unit): String {
    // 1. 向宿主发 events/subscribe 请求 → subscriptionId
    // 2. 在 ServiceRegistry 注册 effect：卸载时发 events/unsubscribe
    // 3. 注册本地处理器：宿主 events/dispatch 到达时调用 listener
}

/**
 * 发布事件：不等待订阅者
 * @param event 事件名
 * @param args 参数列表
 */
public func emit(event: String, args: Array<JsonValue>): Unit {
    // 向宿主发 events/emit 通知
}
```

**插件侧实现要点**：
- `ctx.on` 需要注册一个**本地 dispatch 处理器**（`server.register("events/dispatch", ...)`），宿主派发到来时解析 `DispatchParams` 调 listener。
- 退订走 effect：`ctx.effect { => unsubscribe(subscriptionId) }`（对齐 Cordis `ctx.on` 卸载自动移除）。
- 事件参数是动态结构 → jsonvalue `Array<JsonValue>`（符合 AGENTS.md"实在没固定结构可用 jsonvalue"）。

## 7. 派发模式（分层）

| 版本 | 模式 | 语义 | 实现 |
| :--- | :--- | :--- | :--- |
| **v1** | `emit` | 同步广播：宿主按注册顺序逐个派发，不等返回值 | 宿主遍历 `subscribers[event]`，逐连接发 `events/dispatch`（同步等待响应） |
| **v2** | `waterfall` | 链式传值：订阅者返回非 null/false 值作为下一个订阅者的参数 | `DispatchParams.mode` 携带模式，宿主按序传递返回值，返回最后一个结果 |
| **v3** | `waterfall` | **完整洋葱 next（对齐 Cordis）**：订阅者收到 `(args, next)`，调 `next()` 推进链，不调 next 直接返回 = veto 短路 | 宿主按 emitId 存链状态 + `events/next` 远程回调（§7.1） |
| **v2** | `parallel` | 并发派发：宿主并发发 `events/dispatch`，等待全部完成 | `dispatch` 模式分支 spawn 并发 |
| **v2** | `serial` | 按序直到订阅者"表态"：遇 bail 值（非 null/false）停止并返回 | 宿主逐发，检查返回值 `isBailValue` |
| **v2** | `bail` | 同步按序，遇 bail 值停止（serial 的同步语义） | 复用 `dispatchSerial` |

**v2 协议扩展**（docs/design-impl.md §4、P9）：

- `EmitParams` 加 `mode` 字段（`EventMode.*`：emit/parallel/serial/bail/waterfall）
- `DispatchParams` 加 `mode` 字段（订阅者侧语义一致，返回值 `?JsonValue` 经 `events/dispatch` 响应回传）
- `SubscribeParams` 加 `once`（一次性：首次派发后自动退订）/ `prepend`（插到订阅列表头部）
- 插件侧 API：`ctx.on`（Unit listener）/ `ctx.once` / `ctx.onVal`（返回 `?JsonValue`）/ `ctx.emit`（通知式）/ `ctx.parallel`（通知式）/ `ctx.serial` / `ctx.bail` / `ctx.waterfall`（请求式，聚合结果返回）
- `EventRegistry.dispatch(event, args, mode, emitId): ?JsonValue`：emit/parallel 返回 None；serial/bail/waterfall 返回聚合结果
- bail 值判定（对齐 Cordis `isBailed`）：`JsonValue.Null` 与 `JsonValue.Boolean(false)` 不视为 bail

> v1 只做 `emit`；waterfall/parallel/serial/bail/once/prepend 在 v2 实现（P9）。v2 的 waterfall 是「链式传值」（返回值作为下一订阅者参数），是 Cordis `next` 洋葱回调的跨进程近似；**v3（P13）实现完整 `next` 洋葱回调**（§7.1），v2 链式传值被取代。

## 7.1 洋葱 next 协议（P13，完整 Cordis waterfall）

**Cordis 语义**（`@deepseek-ai/cordis` events.ts `waterfall`）：

```ts
waterfall(...args) {
  const cbs = this.dispatch('waterfall', args)
  const inner = args.pop()          // 最内层 = 内置行为
  const next = () => {
    const cb = cbs.shift() ?? inner // 推进到下一订阅者（或内置行为）
    return cb(...args)
  }
  args.push(next)
  return next()                     // 最外层订阅者的返回值 = 链结果
}
```

- 订阅者按注册顺序**从外到内**组成洋葱：每个 listener 收到 `(args, next)`
- 调 `next()`：推进到下一个订阅者；所有订阅者都调过 next 后，`next()` 落到**内置行为**
- **不调 next 直接返回 = veto**：短路整条链，该返回值即最终结果
- 链结果 = 最外层订阅者的返回值（通常 `return next()` 透传内层结果，可前/后处理改写）

**跨进程映射**：

```
插件 A（发布者）ctx.waterfall("evt", args)
   │ events/emit (mode=waterfall)      [请求]
   ▼
宿主 EventRegistry.dispatchWaterfall
   │ 1. 注册 WaterfallChain(emitId → targets + index + args)
   │ 2. 调订阅者0：events/dispatch(nextAllowed=true)   ← 阻塞等响应
   ▼
插件 B（订阅者0）onWaterfall listener(args, next)
   │ next() → events/next(emitId)      [请求]  ← 递归推进
   ▼
宿主 dispatchNext(emitId)：index++ → 调订阅者1（或链结束 → 内置行为 None）
   ▼
…… 递归沿响应路径展开，最外层订阅者的响应 = 整条链结果
```

**关键设计**：

1. **链状态在宿主**：`chains[emitId] = WaterfallChain(event, targets, args)`；`dispatchNext` 推进 index 并调 `callSubscriber(sub, args, ..., nextAllowed: true)`。
2. **递归在响应路径完成**：`dispatchWaterfall` 阻塞在订阅者 0 的 `events/dispatch` 响应上——该响应最终包含整条链的结果（每个 `next()` 的响应 = 内层链结果，listener 透传/改写后作为自己的派发结果）。
3. **veto 短路**：订阅者返回非 null 值（不调 next）→ `dispatchWaterfall` 立即返回该值，链上下文移除，后续订阅者不再被调用。
4. **内置行为**：链结束（index 越界）→ `events/next` 响应 `JsonValue.Null` → 最终结果归一为 None。
5. **跨连接无死锁**：每次 `callSubscriber` 阻塞的是"发起方"连接线程，响应由"目标订阅者"连接线程处理——洋葱每层推进在不同连接上串行完成（插件侧 `registerAsync` + spawn 保证接收线程不被 listener 阻塞）。

**协议扩展（P13）**：

- `DispatchParams` 加 `nextAllowed` 字段（默认 false，仅 true 时序列化）：订阅者侧据此构造 next 回调
- 新方法 `events/next`（`Methods.EVENTS_NEXT`）+ 参数 `NextParams(emitId)`（插件 → 宿主请求）
- 宿主 `PluginHost` 注册 `events/next` handler → `EventRegistry.dispatchNext(emitId)`
- 插件侧新 API：`ctx.onWaterfall(event, (args, next) -> ?JsonValue)` 及泛型版 `onWaterfall<T>`

**插件侧 next 闭包**（`plugin_runtime.cj` EVENTS_DISPATCH handler，nextAllowed=true 时）：

```cangjie
let next: () -> ?JsonValue = { =>
    let result = this.server.request<NextParams, JsonValue>(
        Methods.EVENTS_NEXT, params: NextParams(params.emitId))
    match (result) {
        case Ok(v) => match (v) {
            case JsonValue.Null => None   // 链到底（内置行为）
            case other => Some(other)
        }
        case Err(e) => None
    }
}
```

**测试**（`EventDispatchModeTest` / `PluginEventTest`）：

- `testWaterfallVetoShortCircuits`：订阅者1 veto → 订阅者2 不被调用，结果 = veto 值
- `testWaterfallNextChainsToNext`：订阅者1 调 next() → 链推进到订阅者2 → 结果 = 订阅者2 返回值
- `testWaterfallAllNextReturnsBuiltin`：全部调 next（无人 veto）→ 内置行为 None
- `testOnWaterfallNextRoundTrip`：插件侧 onWaterfall → listener 调 next() → 宿主 events/next 响应 → 结果回宿主

## 8. 错误处理与边界

- **订阅者进程已退出**：派发时 `client.call` 超时/EOF → 跳过该订阅者并自动 `unsubscribe`（崩溃清理）。
- **事件无订阅者**：`emit` 静默成功（发布者不感知）。
- **重复订阅**：同一插件对同一事件多次 `on` 允许（各自独立订阅 id）。
- **卸载清理**：`removePlugin` → `unsubscribeAll`（防幽灵订阅）。
- **参数序列化失败**：emit 参数为 JsonValue 数组，宿主直接透传，不反序列化（减少出错面）。

## 9. 测试计划

| 测试 | 覆盖 |
| :--- | :--- |
| `SubscribeParams/Result/EmitParams/DispatchParams/NextParams` 序列化往返 | 消息类（cordis_core） |
| `EventRegistryTest` | 订阅/退订/按插件清理/dispatch 遍历（MemoryDuplexTransport 模拟） |
| `EventDispatchModeTest` | **派发模式全量**：emit 广播 / serial bail 短路 / waterfall 洋葱（veto 短路 / next 推进 / 全 next 内置行为）/ parallel 并发 / once 自动退订 / prepend 顺序 |
| `PluginEventTest` | 插件侧 on/once/onVal/onWaterfall/serial/bail/waterfall/parallel 协议往返（FakeHost），含洋葱 next 往返 |
| `EndToEndTest.testEventBusEndToEnd` | **真实双插件进程**：插件 A emit → 宿主路由 → 插件 B 收到并响应 |
| `EndToEndTest.testEventCleanupOnUnload` | 插件卸载后订阅自动清理 |

## 10. 实施步骤（P6-Events / P9-Events v2 / P13 洋葱 next）

1. **P6.1**：cordis_core 消息类 + 方法常量 + 单测。
2. **P6.2**：cordis_host EventRegistry + PluginHost 接入 + 单测（MemoryDuplexTransport）。
3. **P6.3**：cordis_plugin `ctx.on`/`ctx.emit` + 单测（FakeHost）。
4. **P6.4**：端到端（真实双插件进程 emit → 订阅者收到；卸载清理）。
5. **P9.1**：协议扩展（EmitParams/DispatchParams 加 mode、SubscribeParams 加 once/prepend）+ 单测。
6. **P9.2**：EventRegistry 派发模式（emit/parallel/serial/bail/waterfall）+ `EventDispatchModeTest`。
7. **P9.3**：插件侧 onVal/once/parallel/serial/bail/waterfall API + FakeHost 协议往返测试。
8. **P13**：完整洋葱 next——DispatchParams.nextAllowed + `events/next` 协议 + WaterfallChain 链状态 + `ctx.onWaterfall` + 洋葱用例（§7.1）。
9. 每步遵循 TDD：先写用例 → 实现 → `cjpm test` 通过 → 提交。

## 11. 不做的事（当前范围外）

- 事件参数类型安全（`Array<JsonValue>` 为底层；已提供 `on<T>`/`emit<T>`/`onVal<T>`/`onWaterfall<T>` 泛型封装）。
- 跨宿主的分布式事件（单宿主内路由）。
- 事件持久化/重放。
