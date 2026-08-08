/**
 * HTTP/3 Extensible Priorities（RFC 9218）。
 *
 * HTTP/3 使用 Priority 头字段传递优先级信号，而非 HTTP/2 的优先级树。
 * Priority 头字段格式：
 *   Priority: u=<urgency>, i=<incremental?>
 *
 * - urgency: 0-7（0 最高优先级，7 最低，默认 3）
 * - incremental: ?0（默认）或 ?1
 *
 * @see https://www.rfc-editor.org/rfc/rfc9218
 */
package http_lib.http3

import std.collection.{ArrayList, HashMap}
import http_lib.core.{HttpHeaders, ProtocolException}
import std.convert.Parsable

// ======== 常量 ========

/// 默认优先级（RFC 9218 §3）
public let H3_DEFAULT_URGENCY: UInt8 = 3u8
public let H3_DEFAULT_INCREMENTAL: Bool = false
public let H3_MIN_URGENCY: UInt8 = 0u8
public let H3_MAX_URGENCY: UInt8 = 7u8

// ======== HTTP/3 优先级 ========

/**
 * HTTP/3 优先级信号。
 *
 * 包含 urgency（紧急度 0-7）和 incremental（增量标记）。
 * urgency 越低优先级越高，incremental 表示是否可增量处理。
 */
public class Http3Priority <: ToString {
    public let urgency: UInt8
    public let incremental: Bool

    public init(urgency!: UInt8 = H3_DEFAULT_URGENCY, incremental!: Bool = H3_DEFAULT_INCREMENTAL) {
        this.urgency = if (urgency < H3_MIN_URGENCY) { H3_MIN_URGENCY }
                       else if (urgency > H3_MAX_URGENCY) { H3_MAX_URGENCY }
                       else { urgency }
        this.incremental = incremental
    }

    public static func defaultPriority(): Http3Priority {
        Http3Priority()
    }

    public func compareTo(other: Http3Priority): Int64 {
        if (urgency < other.urgency) { return -1 }
        if (urgency > other.urgency) { return 1 }
        if (incremental && !other.incremental) { return 1 }
        if (!incremental && other.incremental) { return -1 }
        0
    }

    public func toString(): String {
        let incStr = if (incremental) { "?1" } else { "?0" }
        "Priority: u=${urgency}, i=${incStr}"
    }
}

// ======== Priority 头部解析 ========

/**
 * 解析 Priority HTTP 头字段。
 * 格式：Priority: u=<urgency>, i=<incremental>
 */
public func parsePriorityHeader(headerValue: String): Http3Priority {
    var urgencyVal: UInt8 = H3_DEFAULT_URGENCY
    var incrementalVal: Bool = H3_DEFAULT_INCREMENTAL

    let parts = headerValue.split(",")
    for (part in parts) {
        match (part.indexOf("u=")) {
            case Some(idx) =>
                let val = part[idx+2..]
                try {
                    urgencyVal = UInt8(Int64.parse(val))
                } catch (_: Exception) {}
            case None =>
                match (part.indexOf("U=")) {
                    case Some(idx) =>
                        let val = part[idx+2..]
                        try {
                            urgencyVal = UInt8(Int64.parse(val))
                        } catch (_: Exception) {}
                    case None => ()
                }
        }
        match (part.indexOf("i=")) {
            case Some(idx) =>
                let val = part[idx+2..]
                incrementalVal = (val == "?1")
            case None =>
                match (part.indexOf("I=")) {
                    case Some(idx) =>
                        let val = part[idx+2..]
                        incrementalVal = (val == "?1")
                    case None => ()
                }
        }
    }

    Http3Priority(urgency: urgencyVal, incremental: incrementalVal)
}

/**
 * 编码 Priority HTTP 头字段值。
 */
public func encodePriorityHeader(priority: Http3Priority): String {
    let incStr = if (priority.incremental) { "?1" } else { "?0" }
    "u=${priority.urgency}, i=${incStr}"
}

/**
 * 从 HttpHeaders 中提取请求优先级。
 */
public func extractPriorityFromHeaders(headers: HttpHeaders): Http3Priority {
    match (headers.get("priority")) {
        case Some(val) => parsePriorityHeader(val)
        case None => match (headers.get("Priority")) {
            case Some(val) => parsePriorityHeader(val)
            case None => Http3Priority.defaultPriority()
        }
    }
}

// ======== 优先级调度器 ========

/**
 * 优先级调度队列。
 * 管理基于优先级的请求处理顺序。
 */
public class PriorityScheduler {
    private var queues: HashMap<UInt8, ArrayList<UInt64>>
    private var incrementalQueues: HashMap<UInt8, ArrayList<UInt64>>
    private var totalPending: Int64 = 0

    public init() {
        this.queues = HashMap<UInt8, ArrayList<UInt64>>()
        this.incrementalQueues = HashMap<UInt8, ArrayList<UInt64>>()
    }

    public func addStream(streamId: UInt64, priority!: Http3Priority = Http3Priority.defaultPriority()): Unit {
        let urgencyKey = priority.urgency
        if (priority.incremental) {
            match (incrementalQueues.get(urgencyKey)) {
                case Some(list) => list.add(streamId)
                case None =>
                    let newList = ArrayList<UInt64>()
                    newList.add(streamId)
                    incrementalQueues[urgencyKey] = newList
            }
        } else {
            match (queues.get(urgencyKey)) {
                case Some(list) => list.add(streamId)
                case None =>
                    let newList = ArrayList<UInt64>()
                    newList.add(streamId)
                    queues[urgencyKey] = newList
            }
        }
        totalPending += 1
    }

    public func removeStream(streamId: UInt64): Unit {
        for (i in 0..8) {
            let key = UInt8(i)
            match (queues.get(key)) {
                case Some(list) =>
                    for (j in 0..list.size) {
                        if (list[j] == streamId) {
                            list.remove(j..j+1)
                            totalPending -= 1
                            return
                        }
                    }
                case None => ()
            }
            match (incrementalQueues.get(key)) {
                case Some(list) =>
                    for (j in 0..list.size) {
                        if (list[j] == streamId) {
                            list.remove(j..j+1)
                            totalPending -= 1
                            return
                        }
                    }
                case None => ()
            }
        }
    }

    public func nextHighest(): ?UInt64 {
        for (i in 0..8) {
            let key = UInt8(i)
            match (queues.get(key)) {
                case Some(list) =>
                    if (list.size > 0) {
                        let streamId = list[0]
                        list.remove(0..1)
                        totalPending -= 1
                        return Some(streamId)
                    }
                case None => ()
            }
            match (incrementalQueues.get(key)) {
                case Some(list) =>
                    if (list.size > 0) {
                        let streamId = list[0]
                        list.remove(0..1)
                        totalPending -= 1
                        return Some(streamId)
                    }
                case None => ()
            }
        }
        None
    }

    public func hasPending(): Bool { totalPending > 0 }
    public func getPendingCount(): Int64 { totalPending }

    public func clear(): Unit {
        for (i in 0..8) {
            let key = UInt8(i)
            match (queues.get(key)) {
                case Some(list) => list.clear()
                case None => ()
            }
            match (incrementalQueues.get(key)) {
                case Some(list) => list.clear()
                case None => ()
            }
        }
        totalPending = 0
    }
}
