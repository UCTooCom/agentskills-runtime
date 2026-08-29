package ystyle::cordis_core

import jsonvalue.*
import stdx.encoding.json.stream.*
import std.collection.HashMap

/**
 * initialize.params（插件 → 宿主）
 */
public class InitializeParams <: JsonSerializable & JsonDeserializable<InitializeParams> {
    public let id: String
    public let inject: Array<String>
    public let provide: Array<String>
    public let config: ?HashMap<String, JsonValue>

    public init(id: String, inject: Array<String>, provide: Array<String>,
                config!: ?HashMap<String, JsonValue> = None) {
        this.id = id
        this.inject = inject
        this.provide = provide
        this.config = config
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("id").writeValue(this.id)
        w.writeName("inject").writeValue(this.inject)
        w.writeName("provide").writeValue(this.provide)
        if (let Some(cfg) <- this.config) {
            w.writeName("config")
            w.writeValue(cfg)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): InitializeParams {
        r.startObject()
        var id: ?String = None
        var inject: ?Array<String> = None
        var provide: ?Array<String> = None
        var config: ?HashMap<String, JsonValue> = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "id" => id = r.readValue<String>()
                case "inject" => inject = r.readValue<Array<String>>()
                case "provide" => provide = r.readValue<Array<String>>()
                case "config" => config = r.readValue<HashMap<String, JsonValue>>()
                case _ => r.skip()
            }
        }
        r.endObject()
        InitializeParams(id.getOrThrow(), inject.getOrThrow(), provide.getOrThrow(), config: config)
    }
}

/**
 * initialize 响应 result（宿主 → 插件）
 * @param config 插件私有配置（宿主从 entry.config 下发，JsonValue 透传）
 */
public class InitializeResult <: JsonSerializable & JsonDeserializable<InitializeResult> {
    public let ok: Bool
    public let providers: HashMap<String, String>   // serviceKey -> 提供者插件 id
    public let config: ?JsonValue

    public init(ok: Bool, providers: HashMap<String, String>, config!: ?JsonValue = None) {
        this.ok = ok
        this.providers = providers
        this.config = config
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("ok").writeValue(this.ok)
        w.writeName("providers").writeValue(this.providers)
        if (let Some(cfg) <- this.config) {
            w.writeName("config").writeValue(cfg)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): InitializeResult {
        r.startObject()
        var ok: ?Bool = None
        var providers: ?HashMap<String, String> = None
        var config: ?JsonValue = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "ok" => ok = r.readValue<Bool>()
                case "providers" => providers = r.readValue<HashMap<String, String>>()
                case "config" => config = r.readValue<JsonValue>()
                case _ => r.skip()
            }
        }
        r.endObject()
        InitializeResult(ok.getOrThrow(), providers.getOrThrow(), config: config)
    }
}

/**
 * provide.params（插件 → 宿主）
 */
public class ProvideParams <: JsonSerializable & JsonDeserializable<ProvideParams> {
    public let key: String

    public init(key: String) {
        this.key = key
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("key").writeValue(this.key)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): ProvideParams {
        r.startObject()
        var key: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "key" => key = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        ProvideParams(key.getOrThrow())
    }
}

/**
 * provide 响应 result（宿主 → 插件）：返回 undo_id，dispose 时凭此撤销
 */
public class ProvideResult <: JsonSerializable & JsonDeserializable<ProvideResult> {
    public let undoId: String

    public init(undoId: String) {
        this.undoId = undoId
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("undoId").writeValue(this.undoId)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): ProvideResult {
        r.startObject()
        var undoId: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "undoId" => undoId = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        ProvideResult(undoId.getOrThrow())
    }
}

/**
 * dispose.params（宿主 → 插件）：按 undo_id 撤销指定服务
 */
public class DisposeParams <: JsonSerializable & JsonDeserializable<DisposeParams> {
    public let undoId: String

    public init(undoId: String) {
        this.undoId = undoId
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("undoId").writeValue(this.undoId)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): DisposeParams {
        r.startObject()
        var undoId: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "undoId" => undoId = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        DisposeParams(undoId.getOrThrow())
    }
}

/**
 * notify.params（宿主 → 插件）：广播依赖图变化
 */
public class NotifyParams <: JsonSerializable & JsonDeserializable<NotifyParams> {
    public let kind: String        // NotifyKind.DEPENDENCY_LOST | PROVIDER_CHANGED
    public let key: String         // 受影响的 serviceKey
    public let provider: ?String   // 新提供者插件 id（provider-changed 时）

    public init(kind: String, key: String, provider!: ?String = None) {
        this.kind = kind
        this.key = key
        this.provider = provider
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue(this.kind)
        w.writeName("key").writeValue(this.key)
        if (let Some(p) <- this.provider) {
            w.writeName("provider").writeValue(p)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): NotifyParams {
        r.startObject()
        var kind: ?String = None
        var key: ?String = None
        var provider: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "kind" => kind = r.readValue<String>()
                case "key" => key = r.readValue<String>()
                case "provider" => provider = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        NotifyParams(kind.getOrThrow(), key.getOrThrow(), provider: provider)
    }
}

/**
 * log.params（插件 → 宿主，通知）
 * @param logger 命名日志器名称（ctx.logger(name) 时携带，None = 默认 ctx.log）
 */
public class LogParams <: JsonSerializable & JsonDeserializable<LogParams> {
    public let level: String   // LogLevel.TRACE|DEBUG|INFO|WARN|ERROR
    public let message: String
    public let logger: ?String

    public init(level: String, message: String, logger!: ?String = None) {
        this.level = level
        this.message = message
        this.logger = logger
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("level").writeValue(this.level)
        w.writeName("message").writeValue(this.message)
        if (let Some(l) <- this.logger) {
            w.writeName("logger").writeValue(l)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): LogParams {
        r.startObject()
        var level: ?String = None
        var message: ?String = None
        var logger: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "level" => level = r.readValue<String>()
                case "message" => message = r.readValue<String>()
                case "logger" => logger = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        LogParams(level.getOrThrow(), message.getOrThrow(), logger: logger)
    }
}

/**
 * invoke.params（宿主转发服务调用；双向）
 */
public class InvokeParams <: JsonSerializable & JsonDeserializable<InvokeParams> {
    public let service: String
    public let method: String
    public let args: Array<JsonValue>

    public init(service: String, method: String, args: Array<JsonValue>) {
        this.service = service
        this.method = method
        this.args = args
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("service").writeValue(this.service)
        w.writeName("method").writeValue(this.method)
        w.writeName("args").writeValue(this.args)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): InvokeParams {
        r.startObject()
        var service: ?String = None
        var method: ?String = None
        var args: ?Array<JsonValue> = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "service" => service = r.readValue<String>()
                case "method" => method = r.readValue<String>()
                case "args" => args = r.readValue<Array<JsonValue>>()
                case _ => r.skip()
            }
        }
        r.endObject()
        InvokeParams(service.getOrThrow(), method.getOrThrow(), args.getOrThrow())
    }
}

/**
 * events/subscribe.params（插件 → 宿主）
 * @param once 一次性订阅：首次派发后自动退订（对齐 Cordis ctx.once）
 * @param prepend 插到订阅列表头部（对齐 Cordis EventOptions.prepend）
 */
public class SubscribeParams <: JsonSerializable & JsonDeserializable<SubscribeParams> {
    public let event: String
    public let once: Bool
    public let prepend: Bool

    public init(event: String, once!: Bool = false, prepend!: Bool = false) {
        this.event = event
        this.once = once
        this.prepend = prepend
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("event").writeValue(this.event)
        w.writeName("once").writeValue(this.once)
        w.writeName("prepend").writeValue(this.prepend)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): SubscribeParams {
        r.startObject()
        var event: ?String = None
        var once: Bool = false
        var prepend: Bool = false
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "event" => event = r.readValue<String>()
                case "once" => once = r.readValue<Bool>()
                case "prepend" => prepend = r.readValue<Bool>()
                case _ => r.skip()
            }
        }
        r.endObject()
        SubscribeParams(event.getOrThrow(), once: once, prepend: prepend)
    }
}

/**
 * events/subscribe 响应 result（宿主 → 插件）：返回订阅 id
 */
public class SubscribeResult <: JsonSerializable & JsonDeserializable<SubscribeResult> {
    public let subscriptionId: String

    public init(subscriptionId: String) {
        this.subscriptionId = subscriptionId
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("subscriptionId").writeValue(this.subscriptionId)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): SubscribeResult {
        r.startObject()
        var subscriptionId: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "subscriptionId" => subscriptionId = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        SubscribeResult(subscriptionId.getOrThrow())
    }
}

/**
 * events/unsubscribe.params（插件 → 宿主）
 */
public class UnsubscribeParams <: JsonSerializable & JsonDeserializable<UnsubscribeParams> {
    public let subscriptionId: String

    public init(subscriptionId: String) {
        this.subscriptionId = subscriptionId
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("subscriptionId").writeValue(this.subscriptionId)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): UnsubscribeParams {
        r.startObject()
        var subscriptionId: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "subscriptionId" => subscriptionId = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        UnsubscribeParams(subscriptionId.getOrThrow())
    }
}

/**
 * events/emit.params（插件 → 宿主）：发布事件
 * @param mode 派发模式（EventMode.*，默认 emit）
 */
public class EmitParams <: JsonSerializable & JsonDeserializable<EmitParams> {
    public let event: String
    public let args: Array<JsonValue>
    public let mode: String

    public init(event: String, args: Array<JsonValue>, mode!: String = EventMode.EMIT) {
        this.event = event
        this.args = args
        this.mode = mode
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("event").writeValue(this.event)
        w.writeName("args").writeValue(this.args)
        w.writeName("mode").writeValue(this.mode)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): EmitParams {
        r.startObject()
        var event: ?String = None
        var args: ?Array<JsonValue> = None
        var mode: String = EventMode.EMIT
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "event" => event = r.readValue<String>()
                case "args" => args = r.readValue<Array<JsonValue>>()
                case "mode" => mode = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        EmitParams(event.getOrThrow(), args.getOrThrow(), mode: mode)
    }
}

/**
 * events/dispatch.params（宿主 → 插件，请求）：向单个订阅者派发事件
 * @param mode 派发模式（插件侧根据模式决定返回值语义）
 */
public class DispatchParams <: JsonSerializable & JsonDeserializable<DispatchParams> {
    public let event: String
    public let args: Array<JsonValue>
    public let emitId: String
    public let mode: String
    // waterfall 模式：订阅者可调用 next 回调推进链（docs/design-events.md §7）
    public let nextAllowed: Bool

    public init(event: String, args: Array<JsonValue>, emitId: String, mode!: String = EventMode.EMIT,
                nextAllowed!: Bool = false) {
        this.event = event
        this.args = args
        this.emitId = emitId
        this.mode = mode
        this.nextAllowed = nextAllowed
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("event").writeValue(this.event)
        w.writeName("args").writeValue(this.args)
        w.writeName("emitId").writeValue(this.emitId)
        w.writeName("mode").writeValue(this.mode)
        if (this.nextAllowed) {
            w.writeName("nextAllowed").writeValue(true)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): DispatchParams {
        r.startObject()
        var event: ?String = None
        var args: ?Array<JsonValue> = None
        var emitId: ?String = None
        var mode: String = EventMode.EMIT
        var nextAllowed: Bool = false
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "event" => event = r.readValue<String>()
                case "args" => args = r.readValue<Array<JsonValue>>()
                case "emitId" => emitId = r.readValue<String>()
                case "mode" => mode = r.readValue<String>()
                case "nextAllowed" => nextAllowed = r.readValue<Bool>()
                case _ => r.skip()
            }
        }
        r.endObject()
        DispatchParams(event.getOrThrow(), args.getOrThrow(), emitId.getOrThrow(), mode: mode,
            nextAllowed: nextAllowed)
    }
}

/**
 * events/next.params（插件 → 宿主，请求）：waterfall 链推进
 * 订阅者调用 next 回调时携带，宿主推进到下一个订阅者（或最终内置行为）
 */
public class NextParams <: JsonSerializable & JsonDeserializable<NextParams> {
    public let emitId: String

    public init(emitId: String) {
        this.emitId = emitId
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("emitId").writeValue(this.emitId)
        w.endObject()
    }

    public static func fromJson(r: JsonReader): NextParams {
        r.startObject()
        var emitId: ?String = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "emitId" => emitId = r.readValue<String>()
                case _ => r.skip()
            }
        }
        r.endObject()
        NextParams(emitId.getOrThrow())
    }
}
