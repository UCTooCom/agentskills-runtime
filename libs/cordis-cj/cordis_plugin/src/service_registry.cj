package ystyle::cordis_plugin

import jsonvalue.JsonValue
import stdx.encoding.json.stream.{JsonSerializable, JsonDeserializable}
import std.collection.{HashMap, ArrayList, map, collectArray}
import std.sync.Mutex

/**
 * 服务注册表（docs/design-impl.md §6）
 *
 * 管理插件提供的服务（provide/dispose）与可逆效果（disposer 列表）：
 * - register：注册服务，宿主返回 undo_id，凭此可撤销
 * - dispose：按 undo_id 撤销单个服务
 * - effect：注册可逆效果（disposer），卸载时逆序执行（对应 Cordis ctx.effect）
 * - disposeAll：插件卸载时调用，逆序执行全部 disposer 并清空
 */
public class ServiceRegistry {
    // undo_id -> 撤销回调（disposer），按注册顺序维护
    private let services: HashMap<String, () -> Unit> = HashMap<String, () -> Unit>()
    private let serviceOrder: ArrayList<String> = ArrayList<String>()
    // 可逆效果 disposer（无 undo_id），按注册顺序维护：label -> disposer
    // disposer 返回 ?Future<Unit>：None = 同步；Some = 异步（disposeAll 等待完成）
    private let effects: ArrayList<(String, () -> ?Future<Unit>)> = ArrayList<(String, () -> ?Future<Unit>)>()
    // 服务 Key -> invoke 处理器（宿主转发服务调用时分发）
    private let handlers: HashMap<String, (String, Array<JsonValue>) -> JsonValue> = HashMap<String, (String, Array<JsonValue>) -> JsonValue>()
    private let lock: Mutex = Mutex()

    public init() {}

    /**
     * 注册服务处理器：宿主 invoke 转发到本插件的服务时调用
     * @param key 服务 Key（与 provide 的 Key 对应）
     * @param handler (method, args) -> result
     */
    public func registerHandler(key: String, handler: (String, Array<JsonValue>) -> JsonValue): Unit {
        synchronized(this.lock) {
            this.handlers[key] = handler
        }
    }

    /**
     * 注册服务处理器（泛型版）
     *
     * 参数自动反序列化（T <: JsonDeserializable<T>），返回值自动序列化
     * （R <: JsonSerializable），服务端 handler 直接操作仓颉类型，
     * 省去手动 JsonValue 转换。
     *
     * @param key 服务 Key（与 provide 的 Key 对应）
     * @param handler (method, args: Array<T>) -> R
     */
    public func registerHandler<T, R>(key: String, handler: (String, Array<T>) -> R): Unit
        where T <: JsonDeserializable<T>, R <: JsonSerializable {
        let wrapped: (String, Array<JsonValue>) -> JsonValue = { method, jsonArgs =>
            // JsonValue[] → Array<T>（逐个反序列化）
            let typedArgs = jsonArgs |> map { j => JsonValue.toObject<T>(j) } |> collectArray
            let result = handler(method, typedArgs)
            JsonValue.fromObject(result)
        }
        synchronized(this.lock) {
            this.handlers[key] = wrapped
        }
    }

    /**
     * 分发宿主转发的服务调用
     * @throws Exception 服务不存在时
     */
    public func invokeHandler(service: String, method: String, args: Array<JsonValue>): JsonValue {
        var handler: ?(String, Array<JsonValue>) -> JsonValue = None
        synchronized(this.lock) {
            if (this.handlers.contains(service)) {
                handler = this.handlers[service]
            }
        }
        match (handler) {
            case Some(h) => h(method, args)
            case None => throw Exception("service '${service}' not provided by this plugin")
        }
    }

    /**
     * 注册一个服务，返回宿主下发的 undo_id
     * @param undoId 宿主分配的撤销标识
     */
    public func register(undoId: String): Unit {
        this.register(undoId, { => () })
    }

    /**
     * 注册一个服务，返回宿主下发的 undo_id
     * @param undoId 宿主分配的撤销标识
     * @param disposer 撤销该服务时执行的回调
     */
    public func register(undoId: String, disposer: () -> Unit): Unit {
        synchronized(this.lock) {
            this.services[undoId] = disposer
            this.serviceOrder.add(undoId)
        }
    }

    /**
     * 撤销指定服务（宿主下发 dispose 时调用）
     * @return 是否找到并撤销了该服务
     */
    public func dispose(undoId: String): Bool {
        var disposer: ?() -> Unit = None
        synchronized(this.lock) {
            if (this.services.contains(undoId)) {
                disposer = this.services[undoId]
                this.services.remove(undoId)
                var idx: Int64 = -1
                for (i in 0..this.serviceOrder.size) {
                    if (this.serviceOrder[i] == undoId) {
                        idx = i
                        break
                    }
                }
                if (idx >= 0) {
                    this.serviceOrder.remove(at: idx)
                }
            }
        }
        match (disposer) {
            case Some(f) =>
                f()
                true
            case None => false
        }
    }

    /**
     * 注册可逆效果：返回 disposer，插件卸载时逆序执行（对应 Cordis ctx.effect）
     */
    public func effect(disposer: () -> Unit): Unit {
        this.effect(disposer, "anonymous")
    }

    /**
     * 注册可逆效果（带 label，docs/cordis-comparison.md §4 getEffects 诊断树）
     * @param disposer 撤销回调
     * @param label 效果标签（getEffects() 诊断展示）
     */
    public func effect(disposer: () -> Unit, label: String): Unit {
        synchronized(this.lock) {
            this.effects.add((label, { => disposer(); None }))
        }
    }

    /**
     * 注册异步可逆效果（docs/cordis-comparison.md §4 async effect，对齐 Cordis async disposer）
     *
     * disposer 返回 Future<Unit>（如 spawn 的异步清理任务）；插件卸载时
     * disposeAll 会等待所有异步 disposer 完成（顺序仍逆序，但异步可并发）。
     *
     * @param disposer 撤销回调（返回 Future，卸载时等待完成）
     * @param label 效果标签
     */
    public func effectAsync(disposer: () -> Future<Unit>, label!: String = "async"): Unit {
        synchronized(this.lock) {
            this.effects.add((label, { => Some(disposer()) }))
        }
    }

    /**
     * 当前已注册的服务数量
     */
    public prop serviceCount: Int64 {
        get() {
            synchronized(this.lock) {
                this.services.size
            }
        }
    }

    /**
     * 当前已注册的效果数量
     */
    public prop effectCount: Int64 {
        get() {
            synchronized(this.lock) {
                this.effects.size
            }
        }
    }

    /**
     * 效果诊断树（docs/cordis-comparison.md §4，对齐 Cordis Fiber.getEffects）：
     * 返回当前已注册效果的 label 列表（按注册顺序）
     */
    public func getEffects(): ArrayList<String> {
        synchronized(this.lock) {
            let result = ArrayList<String>()
            for ((label, _) in this.effects) {
                result.add(label)
            }
            result
        }
    }

    /**
     * 卸载全部：逆序执行所有 disposer（效果 + 服务），然后清空
     * 对应 Cordis 卸载时逆序撤销效果（docs/design-impl.md §8）。
     * 异步效果（effectAsync）的 Future 会被等待完成。
     */
    public func disposeAll(): Unit {
        let reversedEffects = ArrayList<() -> ?Future<Unit>>()
        let reversedServices = ArrayList<() -> Unit>()
        synchronized(this.lock) {
            // 逆序复制 effects（解构元组取 disposer）
            // 注意：仓颉 range a..b 仅递增（a<=b），逆序需显式倒序索引
            let effectCount = this.effects.size
            var i: Int64 = effectCount - 1
            while (i >= 0) {
                let (_, disposer) = this.effects[i]
                reversedEffects.add(disposer)
                i--
            }
            // 逆序复制 services
            let svcCount = this.serviceOrder.size
            var j: Int64 = svcCount - 1
            while (j >= 0) {
                let undoId = this.serviceOrder[j]
                if (this.services.contains(undoId)) {
                    reversedServices.add(this.services[undoId])
                }
                j--
            }
            this.effects.clear()
            this.services.clear()
            this.serviceOrder.clear()
        }
        // 先效果后服务（效果通常先注册，逆序时后执行）
        let asyncFutures = ArrayList<Future<Unit>>()
        for (f in reversedEffects) {
            match (f()) {
                case Some(fut) => asyncFutures.add(fut)
                case None => ()
            }
        }
        for (f in reversedServices) {
            f()
        }
        // 等待所有异步效果完成
        for (fut in asyncFutures) {
            fut.get()
        }
    }
}
