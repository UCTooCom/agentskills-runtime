package ystyle::cordis_core

/**
 * JSON-RPC 2.0 方法名常量（协议定义见 docs/design-impl.md §4）
 */
public class Methods {
    public static let INITIALIZE: String = "initialize"      // 插件 → 宿主（请求）
    public static let INITIALIZED: String = "initialized"    // 宿主 → 插件（通知）
    public static let PROVIDE: String = "provide"            // 插件 → 宿主（请求，返回 undo_id）
    public static let DISPOSE: String = "dispose"            // 宿主 → 插件（请求）
    public static let NOTIFY: String = "notify"              // 宿主 → 插件（通知，依赖图变化）
    public static let LOG: String = "log"                    // 插件 → 宿主（通知）
    public static let INVOKE: String = "invoke"              // 宿主转发服务调用
    public static let PING: String = "ping"                  // 宿主 → 插件（请求，探活）
    public static let PONG: String = "pong"                  // 插件 → 宿主（响应 ping）
    // 事件总线（docs/design-events.md §4）
    public static let EVENTS_SUBSCRIBE: String = "events/subscribe"      // 插件 → 宿主（请求，返回订阅 id）
    public static let EVENTS_UNSUBSCRIBE: String = "events/unsubscribe"  // 插件 → 宿主（请求）
    public static let EVENTS_EMIT: String = "events/emit"                // 插件 → 宿主（通知，发布事件）
    public static let EVENTS_DISPATCH: String = "events/dispatch"        // 宿主 → 插件（请求，派发事件）
    public static let EVENTS_NEXT: String = "events/next"                // 插件 → 宿主（请求，waterfall 链推进）

    private init() {}
}

/**
 * notify.params 的 kind 取值
 */
public class NotifyKind {
    public static let DEPENDENCY_LOST: String = "dependency-lost"
    public static let PROVIDER_CHANGED: String = "provider-changed"

    private init() {}
}

/**
 * 事件派发模式（docs/design-events.md §7，对齐 Cordis DispatchMode）
 *
 * - EMIT：同步广播，忽略订阅者返回值（fire-and-forget）
 * - PARALLEL：并发派发，等待全部订阅者完成
 * - SERIAL：按序派发，遇 bail 值（非 null/false）停止并返回
 * - BAIL：同步按序派发，遇 bail 值停止并返回
 * - WATERFALL：链式传值，前一个订阅者返回的非 null 值作为下一个的参数
 */
public class EventMode {
    public static let EMIT: String = "emit"
    public static let PARALLEL: String = "parallel"
    public static let SERIAL: String = "serial"
    public static let BAIL: String = "bail"
    public static let WATERFALL: String = "waterfall"

    private init() {}
}

/**
 * log.params 的 level 取值
 */
public class LogLevel {
    public static let TRACE: String = "trace"
    public static let DEBUG: String = "debug"
    public static let INFO: String = "info"
    public static let WARN: String = "warn"
    public static let ERROR: String = "error"

    private init() {}
}
