package ystyle::cordis_host

import ystyle::cordis_core.{Methods, EventMode, EmitParams, DispatchParams}
import ystyle::jsonrpc.JsonRpcClient
import jsonvalue.JsonValue
import std.collection.{HashMap, ArrayList}
import std.sync.Mutex

/**
 * 事件订阅记录（docs/design-events.md §5.1）
 */
public class Subscription {
    public let id: String
    public let pluginId: String
    public let event: String
    public let instance: PluginInstance
    public let once: Bool       // 一次性：首次派发后自动退订
    public let prepend: Bool    // 插到订阅列表头部

    public init(id: String, pluginId: String, event: String, instance: PluginInstance,
                once!: Bool = false, prepend!: Bool = false) {
        this.id = id
        this.pluginId = pluginId
        this.event = event
        this.instance = instance
        this.once = once
        this.prepend = prepend
    }
}

/**
 * 宿主本地事件订阅记录（进程内回调，docs/design-events.md §5.4）
 *
 * 与 Subscription 的区别：不经过插件连接，listener 在宿主进程内
 * 直接回调。用于宿主自身观察插件事件（如 harness 事件桥把
 * agent 事件转发给 UI），无需为宿主伪造 PluginInstance。
 */
public class LocalSubscription {
    public let id: String
    public let event: String
    public let listener: (Array<JsonValue>) -> Unit

    public init(id: String, event: String, listener: (Array<JsonValue>) -> Unit) {
        this.id = id
        this.event = event
        this.listener = listener
    }
}

/**
 * waterfall 进行中的链状态（docs/design-events.md §7 洋葱 next）
 *
 * 一次 waterfall 派发注册一条链：订阅者快照 + 推进索引 + 传入参数。
 * 每个订阅者收到 events/dispatch（nextAllowed=true）后，listener 可调用
 * next 回调推进链（发 events/next 请求）；返回非 null 值则 veto 短路。
 *
 * 链状态跨连接存活：dispatchWaterfall 阻塞在订阅者 0 的响应上，期间
 * events/next 请求在各订阅者连接上依次推进 index。
 */
internal class WaterfallChain {
    public let event: String
    public let targets: ArrayList<Subscription>
    public let args: Array<JsonValue>
    private var index: Int64 = 0
    private let lock: Mutex = Mutex()

    public init(event: String, targets: ArrayList<Subscription>, args: Array<JsonValue>) {
        this.event = event
        this.targets = targets
        this.args = args
    }

    /**
     * 推进到下一个订阅者
     * @return 推进后的索引；>= targets.size 表示链已结束（内置行为）
     */
    public func advance(): Int64 {
        synchronized(this.lock) {
            this.index++
            this.index
        }
    }
}

/**
 * 事件注册表（docs/design-events.md §5、§7）
 *
 * 管理插件的事件订阅与派发：
 * - subscribe：插件订阅事件，分配 subscriptionId（支持 once/prepend）
 * - unsubscribe：取消订阅
 * - unsubscribeAll：插件卸载时清理其全部订阅
 * - dispatch：按派发模式（EventMode.*）向事件所有订阅者派发
 *   · emit：同步广播，忽略返回值
 *   · parallel：并发派发，等待全部完成
 *   · serial：按序派发，遇 bail 值（非 null/false）停止并返回
 *   · bail：同步按序，遇 bail 值停止并返回
 *   · waterfall：洋葱 next 链——每个订阅者收到 (args, next)，
 *     调用 next() 推进链，返回非 null 值 veto 短路；最外层订阅者
 *     的返回值即整条链的结果（对齐 Cordis waterfall，§7）
 */
public class EventRegistry {
    // 事件名 -> 订阅者列表（有序，保持注册顺序）
    private let subscribers: HashMap<String, ArrayList<Subscription>> = HashMap<String, ArrayList<Subscription>>()
    // subscriptionId -> Subscription（退订用）
    private let byId: HashMap<String, Subscription> = HashMap<String, Subscription>()
    // 宿主本地订阅：事件名 -> 本地监听器列表（进程内回调，不经过插件连接）
    private let localSubscribers: HashMap<String, ArrayList<LocalSubscription>> = HashMap<String, ArrayList<LocalSubscription>>()
    // waterfall 进行中的链：emitId -> 链上下文（docs/design-events.md §7 洋葱 next）
    private let chains: HashMap<String, WaterfallChain> = HashMap<String, WaterfallChain>()
    private let lock: Mutex = Mutex()
    private var idCounter: Int64 = 0

    public init() {}

    /**
     * 订阅事件
     * @param event 事件名
     * @param pluginId 订阅者插件 id
     * @param instance 订阅者实例（派发目标连接）
     * @param once 一次性订阅：首次派发后自动退订
     * @param prepend 插到订阅列表头部
     * @return 订阅 id
     */
    public func subscribe(event: String, pluginId: String, instance: PluginInstance,
                          once!: Bool = false, prepend!: Bool = false): String {
        let id = this.allocateId()
        let sub = Subscription(id, pluginId, event, instance, once: once, prepend: prepend)
        synchronized(this.lock) {
            if (!this.subscribers.contains(event)) {
                this.subscribers[event] = ArrayList<Subscription>()
            }
            let list = this.subscribers[event]
            if (prepend) {
                list.add(sub, at: 0)
            } else {
                list.add(sub)
            }
            this.byId[id] = sub
        }
        id
    }

    /**
     * 取消订阅
     * @return 是否找到并取消了该订阅
     */
    public func unsubscribe(subscriptionId: String): Bool {
        synchronized(this.lock) {
            if (this.byId.contains(subscriptionId)) {
                let sub = this.byId[subscriptionId]
                this.byId.remove(subscriptionId)
                if (this.subscribers.contains(sub.event)) {
                    let list = this.subscribers[sub.event]
                    var idx: Int64 = -1
                    for (i in 0..list.size) {
                        if (list[i].id == subscriptionId) {
                            idx = i
                            break
                        }
                    }
                    if (idx >= 0) {
                        list.remove(at: idx)
                    }
                    if (list.size == 0) {
                        this.subscribers.remove(sub.event)
                    }
                }
                true
            } else {
                false
            }
        }
    }

    /**
     * 插件卸载时清理其全部订阅
     */
    public func unsubscribeAll(pluginId: String): Unit {
        synchronized(this.lock) {
            let staleIds = ArrayList<String>()
            for ((id, sub) in this.byId) {
                if (sub.pluginId == pluginId) {
                    staleIds.add(id)
                }
            }
            for (id in staleIds) {
                let sub = this.byId[id]
                this.byId.remove(id)
                if (this.subscribers.contains(sub.event)) {
                    let list = this.subscribers[sub.event]
                    var idx: Int64 = -1
                    for (i in 0..list.size) {
                        if (list[i].id == id) {
                            idx = i
                            break
                        }
                    }
                    if (idx >= 0) {
                        list.remove(at: idx)
                    }
                    if (list.size == 0) {
                        this.subscribers.remove(sub.event)
                    }
                }
            }
        }
    }

    /**
     * 某事件的订阅者数量（测试/诊断用）
     */
    public func subscriberCount(event: String): Int64 {
        synchronized(this.lock) {
            if (this.subscribers.contains(event)) {
                this.subscribers[event].size
            } else {
                0
            }
        }
    }

    /**
     * 宿主本地订阅事件（进程内回调，不经过插件连接）
     *
     * 用于宿主自身观察插件事件（如 harness 事件桥把 agent 事件
     * 转发给 UI）。只接收 emit 模式（fire-and-forget）派发的事件；
     * serial/bail/waterfall 模式仍只派发给插件订阅者。
     *
     * @param event 事件名
     * @param listener 本地回调（宿主进程内直接调用，异常被吞掉不影响派发）
     * @return 订阅 id（unsubscribeLocal 用）
     */
    public func subscribeLocal(event: String, listener: (Array<JsonValue>) -> Unit): String {
        let id = this.allocateId()
        let sub = LocalSubscription(id, event, listener)
        synchronized(this.lock) {
            if (!this.localSubscribers.contains(event)) {
                this.localSubscribers[event] = ArrayList<LocalSubscription>()
            }
            this.localSubscribers[event].add(sub)
        }
        id
    }

    /**
     * 取消宿主本地订阅
     * @return 是否找到并取消了该订阅
     */
    public func unsubscribeLocal(subscriptionId: String): Bool {
        synchronized(this.lock) {
            for ((event, list) in this.localSubscribers) {
                var idx: Int64 = -1
                for (i in 0..list.size) {
                    if (list[i].id == subscriptionId) {
                        idx = i
                        break
                    }
                }
                if (idx >= 0) {
                    list.remove(at: idx)
                    if (list.size == 0) {
                        this.localSubscribers.remove(event)
                    }
                    return true
                }
            }
            false
        }
    }

    /**
     * 宿主本地订阅者数量（测试/诊断用）
     */
    public func localSubscriberCount(event: String): Int64 {
        synchronized(this.lock) {
            if (this.localSubscribers.contains(event)) {
                this.localSubscribers[event].size
            } else {
                0
            }
        }
    }

    /**
     * 按派发模式向事件的所有订阅者派发
     *
     * 模式语义（docs/design-events.md §7）：
     * - emit：同步按序派发，忽略返回值（fire-and-forget），返回 None
     * - parallel：并发派发并等待全部完成，返回 None
     * - serial：按序派发，遇 bail 值（非 null/false）停止并返回该值
     * - bail：同步按序，遇 bail 值停止并返回该值
     * - waterfall：洋葱 next 链——订阅者调用 next() 推进链、返回非 null
     *   值 veto 短路；返回最外层订阅者的返回值（链全部 next 到底 → None）
     *
     * @param mode 派发模式（EventMode.*）
     * @param emitId 本次 emit 的唯一标识
     * @return 聚合结果（serial/bail/waterfall 有值；emit/parallel 为 None）
     */
    public func dispatch(event: String, args: Array<JsonValue>, mode: String, emitId: String): ?JsonValue {
        if (mode == EventMode.PARALLEL) {
            this.dispatchParallel(event, args, emitId)
            None
        } else if (mode == EventMode.SERIAL || mode == EventMode.BAIL) {
            this.dispatchSerial(event, args, emitId)
        } else if (mode == EventMode.WATERFALL) {
            this.dispatchWaterfall(event, args, emitId)
        } else {
            // 默认 emit：同步广播，忽略返回值
            this.dispatchEmitToAll(event, args, emitId)
            None
        }
    }

    /**
     * 从 emit 通知解析并派发（PluginHost 的 events/emit 回调调用，emit 模式）
     * @return 成功派发的订阅者数量（跳过崩溃/超时的订阅者）
     */
    public func dispatchEmit(emitParams: EmitParams, emitId: String): Int64 {
        this.dispatchEmitToAll(emitParams.event, emitParams.args, emitId)
    }

    // ── 各模式实现 ──────────────────────────────────────────────

    private func snapshot(event: String): ArrayList<Subscription> {
        synchronized(this.lock) {
            if (this.subscribers.contains(event)) {
                ArrayList<Subscription>(this.subscribers[event])
            } else {
                ArrayList<Subscription>()
            }
        }
    }

    /**
     * emit 模式：同步按序派发，忽略返回值；once 订阅派发后自动退订
     * @return 成功派发数量
     */
    private func dispatchEmitToAll(event: String, args: Array<JsonValue>, emitId: String): Int64 {
        let targets = this.snapshot(event)
        var delivered: Int64 = 0
        for (sub in targets) {
            let result = this.callSubscriber(sub, args, event, emitId, EventMode.EMIT)
            if (result.isSome()) {
                delivered++
            }
        }
        // 宿主本地订阅（进程内回调，不经过插件连接）
        this.dispatchLocal(event, args)
        delivered
    }

    /**
     * 向宿主本地订阅者派发（fire-and-forget，异常吞掉不影响派发）
     * @return 成功回调的本地订阅者数量
     */
    private func dispatchLocal(event: String, args: Array<JsonValue>): Int64 {
        let list: ArrayList<LocalSubscription> = synchronized(this.lock) {
            if (this.localSubscribers.contains(event)) {
                ArrayList<LocalSubscription>(this.localSubscribers[event])
            } else {
                ArrayList<LocalSubscription>()
            }
        }
        var delivered: Int64 = 0
        for (sub in list) {
            try {
                sub.listener(args)
                delivered++
            } catch (_) {
                // 本地回调异常不中断派发
            }
        }
        delivered
    }

    /**
     * serial/bail 模式：按序派发，遇 bail 值（非 null/false）停止并返回
     */
    private func dispatchSerial(event: String, args: Array<JsonValue>, emitId: String): ?JsonValue {
        let targets = this.snapshot(event)
        for (sub in targets) {
            let result = this.callSubscriber(sub, args, event, emitId, EventMode.SERIAL)
            match (result) {
                case Some(v) =>
                    if (isBailValue(v)) {
                        return Some(v)
                    }
                case None => ()
            }
        }
        None
    }

    /**
     * waterfall 模式（洋葱 next，docs/design-events.md §7）：
     *
     * 1. 注册链上下文（emitId → 订阅者快照 + 参数），调用订阅者 0
     *    （nextAllowed=true，listener 收到 next 回调）。
     * 2. 订阅者返回非 null 值 = veto 短路，该值即链结果；
     *    返回 null 表示已调用 next() 推进链（events/next 请求驱动）。
     * 3. 本方法阻塞在订阅者 0 的 dispatch 响应上——该响应最终包含
     *    整条链的结果（next 递归沿响应路径完成），链结束移除上下文。
     */
    private func dispatchWaterfall(event: String, args: Array<JsonValue>, emitId: String): ?JsonValue {
        let targets = this.snapshot(event)
        if (targets.size == 0) {
            return None
        }
        let chain = WaterfallChain(event, targets, args)
        synchronized(this.lock) {
            this.chains[emitId] = chain
        }
        // 调用订阅者 0（阻塞直至其 dispatch 响应，响应含整条链结果）
        let result = this.callSubscriber(targets[0], args, event, emitId, EventMode.WATERFALL, nextAllowed: true)
        this.removeChain(emitId)
        // 链全部 next 到底（无 veto）→ 订阅者响应为 null → 归一为 None（内置行为无值）
        match (result) {
            case Some(JsonValue.Null) => None
            case other => other
        }
    }

    /**
     * events/next 请求处理：推进 waterfall 链到下一个订阅者
     * @param emitId 链标识
     * @return 下一订阅者的 dispatch 响应（该响应自身可能包含更深层的 next 链结果）
     */
    public func dispatchNext(emitId: String): ?JsonValue {
        let chain: ?WaterfallChain = synchronized(this.lock) {
            if (this.chains.contains(emitId)) {
                Some(this.chains[emitId])
            } else {
                None
            }
        }
        match (chain) {
            case Some(c) => this.waterfallNext(emitId, c)
            case None => None
        }
    }

    /**
     * 推进到链的下一个订阅者
     */
    private func waterfallNext(emitId: String, chain: WaterfallChain): ?JsonValue {
        let index = chain.advance()
        if (index >= chain.targets.size) {
            // 链结束：所有订阅者都调了 next（或无人 veto）→ 内置行为 None
            this.removeChain(emitId)
            return None
        }
        let sub = chain.targets[index]
        // 调用下一个订阅者；其响应可能继续含 next 链
        this.callSubscriber(sub, chain.args, chain.event, emitId, EventMode.WATERFALL, nextAllowed: true)
    }

    /**
     * waterfall 链清理（dispatch 完成后移除）
     */
    private func removeChain(emitId: String): Unit {
        synchronized(this.lock) {
            this.chains.remove(emitId)
        }
    }

    /**
     * parallel 模式：并发派发并等待全部完成
     */
    private func dispatchParallel(event: String, args: Array<JsonValue>, emitId: String): Unit {
        let targets = this.snapshot(event)
        let futures = ArrayList<Future<Unit>>()
        for (sub in targets) {
            let target = sub
            futures.add(spawn {
                this.callSubscriber(target, args, event, emitId, EventMode.PARALLEL)
                ()
            })
        }
        for (fut in futures) {
            fut.get()
        }
    }

    /**
     * 调用单个订阅者的 events/dispatch（携带派发模式）
     * @param nextAllowed waterfall 模式：订阅者 listener 收到 next 回调（可推进链）
     * @return Some(返回值) 派发成功；None 订阅者超时/崩溃（自动清理）
     */
    private func callSubscriber(sub: Subscription, args: Array<JsonValue>,
                                event: String, emitId: String, mode: String,
                                nextAllowed!: Bool = false): ?JsonValue {
        try {
            let params = DispatchParams(event, args, emitId, mode: mode, nextAllowed: nextAllowed)
            let result = sub.instance.client.call<JsonValue, JsonValue>(
                Methods.EVENTS_DISPATCH,
                params: Some(JsonValue.fromObject(params)),
                timeout: 10 * Duration.second)
            match (result) {
                case Ok(v) =>
                    this.consumeOnce(sub)
                    Some(v)
                case Err(e) =>
                    // 派发失败（订阅者超时/崩溃）→ 跳过并自动清理
                    this.unsubscribe(sub.id)
                    None
            }
        } catch (e: Exception) {
            this.unsubscribe(sub.id)
            None
        }
    }

    /**
     * once 订阅派发后自动退订
     */
    private func consumeOnce(sub: Subscription): Unit {
        if (sub.once) {
            this.unsubscribe(sub.id)
        }
    }

    /**
     * 判断是否为 bail 值（对齐 Cordis isBailed：非 null、非 false）
     */
    private static func isBailValue(v: JsonValue): Bool {
        match (v) {
            case JsonValue.Null => false
            case JsonValue.Boolean(b) => b
            case _ => true
        }
    }

    private func allocateId(): String {
        synchronized(this.lock) {
            this.idCounter++
            "sub-${this.idCounter}"
        }
    }
}
