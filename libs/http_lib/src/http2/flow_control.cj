package http_lib.http2

import std.time.DateTime

/**
 * HTTP/2 流控（连接窗口和流窗口）。
 */

// ---- 常量 ----

private let INFLOW_MIN_REFRESH: Int64 = 4 * 1024  // 发送 WINDOW_UPDATE 前的最小累积量（4 KB）
private let INFLOW_AUTO_FLUSH_INTERVAL: Duration = Duration.millisecond * 100  // 自动刷新间隔（100ms）
public let MAX_WINDOW_SIZE: Int64 = 2147483647   // 2^31 - 1

// ---- 入站流量控制 ----

/**
 * Inbound 流控 window (receive side)。
 * 跟踪对端的发送窗口并累积尚未发送的 WINDOW_UPDATE 字节。
 * 支持自动调优：根据窗口消耗比例和定时器自动发送 WINDOW_UPDATE。
 */
public class Http2Inflow {
    private var avail: Int64     // 上次向对端通告的窗口大小
    private var unsent: Int64    // 已累积但尚未发送 WINDOW_UPDATE 的字节数
    private var autoThreshold: Int64  // 自动调优阈值：当 unsent 达到此值时触发发送
    private var lastFlushTime: DateTime  // 上次发送 WINDOW_UPDATE 的时间
    private var pendingFlush: Bool       // 标记是否需要定时刷新

    public init(initialWindow: Int64) {
        this.avail = initialWindow
        this.unsent = 0
        this.autoThreshold = initialWindow / 2  // 默认阈值：窗口的一半
        this.lastFlushTime = DateTime.now()
        this.pendingFlush = false
    }

    /**
     * 设置自动调优阈值。
     * 阈值表示当 unsent 达到此大小时触发 WINDOW_UPDATE 发送。
     * 例如 autoThreshold=32768 表示当累积了 32KB 未发送的 WINDOW_UPDATE 数据时触发。
     */
    public func setAutoThreshold(t: Int64): Unit {
        autoThreshold = t
    }

    /**
     * 获取当前自动调优阈值。
     */
    public func getAutoThreshold(): Int64 { autoThreshold }

    /**
     * 向接收窗口添加 n 字节（已消费的字节数）。
     * 返回作为 WINDOW_UPDATE 发送的字节数（0 = 批量处理）。
     * 支持自动调优：结合阈值检查和定时器刷新。
     */
    public func add(n: Int64): Int64 {
        if (n < 0) { return 0 }
        let totalUnsent = unsent + n
        if (totalUnsent + avail > MAX_WINDOW_SIZE) {
            throw Http2Exception(Http2ErrorCode.FLOW_CONTROL_ERROR, "Flow control window exceeds max size")
        }
        unsent = totalUnsent

        // 自动调优：当累积量超过阈值时标记为待刷新
        if (unsent >= autoThreshold) {
            pendingFlush = true
        }

        // 如果待刷新且距上次发送超过自动刷新间隔，立即发送
        let elapsed = DateTime.now() - lastFlushTime
        if (pendingFlush && elapsed > INFLOW_AUTO_FLUSH_INTERVAL) {
            return flush()
        }

        // 仅在累积足够多或窗口翻倍时才发送 WINDOW_UPDATE
        if (unsent < INFLOW_MIN_REFRESH && unsent < avail) {
            return 0  // 批量累积——还不足以发送一帧
        }

        avail += unsent
        let update = unsent
        unsent = 0
        pendingFlush = false
        lastFlushTime = DateTime.now()
        update
    }

    /**
     * 强制刷新累积的 WINDOW_UPDATE。
     * 当应用程序确定需要立即补充窗口时调用。
     * 返回需要发送的 WINDOW_UPDATE 增量字节数。
     */
    public func flush(): Int64 {
        if (unsent == 0) { return 0 }
        avail += unsent
        let update = unsent
        unsent = 0
        pendingFlush = false
        lastFlushTime = DateTime.now()
        update
    }

    /**
     * 尝试从窗口消费 n 字节。
     * 若消费成功（有足够容量）则返回 true。
     */
    public func take(n: Int64): Bool {
        if (n > avail) { return false }
        avail -= n
        true
    }

    /**
     * 获取当前可用窗口大小。
     */
    public func available(): Int64 { avail }

    /**
     * 将窗口重置为初始大小。
     */
    public func reset(initialWindow: Int64): Unit {
        avail = initialWindow
        unsent = 0
        autoThreshold = initialWindow / 2
        pendingFlush = false
        lastFlushTime = DateTime.now()
    }
}

// ---- 出站流量控制 ----

/**
 * Outbound 流控 window (send side)。
 * 关联：流级别出站流量共享连接级别出站流量。
 */
public class Http2Outflow {
    private var n: Int64           // 允许发送的字节数
    private var conn: ?Http2Outflow  // 共享的连接级流出（空值表示连接级本身）

    public init(initialWindow: Int64, conn!: ?Http2Outflow = None) {
        this.n = initialWindow
        this.conn = conn
    }

    /**
     * 设置连接级别出站流量（用于流级别出站流量）。
     */
    public func setConnFlow(cf: Http2Outflow): Unit {
        conn = Some(cf)
    }

    /**
     * 获取可发送的字节数。受流和连接窗口共同限制。
     */
    public func available(): Int64 {
        match (conn) {
            case Some(cf) =>
                let connAvail = cf.n
                if (connAvail < n) { connAvail } else { n }
            case None => n
        }
    }

    /**
     * 从流和连接窗口同时消费 n 字节。
     */
    public func take(n: Int64): Bool {
        if (n > available()) { return false }
        this.n -= n
        match (conn) {
            case Some(cf) => cf.n -= n
            case None => ()
        }
        true
    }

    /**
     * 将 n 个字节添加到发送窗口（来自 WINDOW_UPDATE）。
     * 如果总和超过最大窗口则返回 false。
     */
    public func add(n: Int64): Bool {
        let sum = this.n + n
        if (sum > MAX_WINDOW_SIZE) { return false }
        this.n = sum
        true
    }

    /**
     * 获取原始窗口大小（不带连接级限制）。
     */
    public func raw(): Int64 { n }
}

// ---- 组合流量控制器 ----

/**
 * 连接的组合 HTTP/2 流控器。
 * Manages both inbound and outbound 流控 at connection and stream levels.
 */
public class Http2FlowController {
    // 连接级
    public var connInflow: Http2Inflow
    public var connOutflow: Http2Outflow

    public init(initialWindow!: Int64 = 65535) {
        this.connInflow = Http2Inflow(initialWindow)
        this.connOutflow = Http2Outflow(initialWindow)
    }

    /**
     * 创建与此连接关联的流级出站流量。
     */
    public func createStreamOutflow(initialWindow!: Int64 = 65535): Http2Outflow {
        let outflow = Http2Outflow(initialWindow)
        outflow.setConnFlow(connOutflow)
        outflow
    }

    /**
     * 创建流级入站流量。
     */
    public func createStreamInflow(initialWindow!: Int64 = 65535): Http2Inflow {
        Http2Inflow(initialWindow)
    }

    /**
     * 更新初始窗口大小（来自 SETTINGS）。
     * 将所有窗口调整 delta 值。
     */
    public func updateInitialWindow(newSize: Int64): Unit {
        // 这需要遍历所有流——目前，更新连接级
        connOutflow = Http2Outflow(newSize, conn: None)
    }
}

// ---- SETTINGS 超时强制执行 ----

/**
 * Settings 超时处理器（RFC 9113 第 6.5.3 节）。
 *
 * 如果对端未能在 SETTINGS_TIMEOUT 持续时间内，
 * 我们必须以 SETTINGS_TIMEOUT 错误响应。
 */
public class SettingsTimeoutHandler {
    private var startTime: ?DateTime
    private let timeout: Duration
    private var expired: Bool

    public init(timeout!: Duration = Duration.second * 2) {
        this.startTime = None
        this.timeout = timeout
        this.expired = false
    }

    /**
     * 启动 settings 超时倒计时。
     */
    public func start(): Unit {
        startTime = Some(DateTime.now())
        expired = false
    }

    /**
     * 检查 settings 超时是否已到期。
     */
    public func isExpired(): Bool {
        if (expired) { return true }
        match (startTime) {
            case Some(st) =>
                let elapsed = DateTime.now() - st
                if (elapsed > timeout) {
                    expired = true
                    return true
                }
                false
            case None => false
        }
    }

    /**
     * 标记为已确认（收到 SETTINGS ACK）。
     */
    public func ack(): Unit {
        expired = false
        startTime = None
    }

    /**
     * 重置处理器。
     */
    public func reset(): Unit {
        startTime = None
        expired = false
    }
}
