package http_lib.http2

import std.collection.HashMap
import http_lib.core.HttpHeaders
import http_lib.buffer.ByteBuffer

/**
 * HTTP/2 流生命周期状态枚举（RFC 9113 §5）。
 * 状态转换规则：
 * IDLE → OPEN → HALF_CLOSED_LOCAL/REMOTE → CLOSED
 * 服务器和客户端各有独立的单/双向关闭语义。
 */
/**
 * HTTP/2。
 */
public enum Http2StreamState {
    | IDLE
    | RESERVED_LOCAL
    | RESERVED_REMOTE
    | OPEN
    | HALF_CLOSED_LOCAL
    | HALF_CLOSED_REMOTE
    | CLOSED

    public operator func ==(that: Http2StreamState): Bool {
        match ((this, that)) {
            case (IDLE, IDLE) => true
            case (RESERVED_LOCAL, RESERVED_LOCAL) => true
            case (RESERVED_REMOTE, RESERVED_REMOTE) => true
            case (OPEN, OPEN) => true
            case (HALF_CLOSED_LOCAL, HALF_CLOSED_LOCAL) => true
            case (HALF_CLOSED_REMOTE, HALF_CLOSED_REMOTE) => true
            case (CLOSED, CLOSED) => true
            case _ => false
        }
    }

    public operator func !=(that: Http2StreamState): Bool {
        !(this == that)
    }
}

/**
 * 表示单个请求/响应交换的 HTTP/2 流。
 */
public class Http2Stream {
    public let streamId: UInt32
    public var state: Http2StreamState
    public var recvWindow: Int64        // 流量控制：接收窗口
    public var sendWindow: Int64        // 流量控制：发送窗口
    public var headerBuffer: ByteBuffer  // 已接收的头部字节数
    public var dataBuffer: ByteBuffer    // 已接收的 DATA 负载字节数
    public var endStream: Bool           // 已收到 END_STREAM 标志
    public var endHeaders: Bool          // 已收到 END_HEADERS 标志
    public var trailers: HttpHeaders      // 此流上已收到的尾部头部
    public var trailersReady: Bool        // 尾部头部已接收

    public init(streamId: UInt32) {
        this.streamId = streamId
        this.state = Http2StreamState.IDLE
        this.recvWindow = 65535
        this.sendWindow = 65535
        this.headerBuffer = ByteBuffer(capacity: 4096)
        this.dataBuffer = ByteBuffer(capacity: 65536)
        this.endStream = false
        this.endHeaders = false
        this.trailers = HttpHeaders()
        this.trailersReady = false
    }
}

/**
 * HTTP/2 流多路复用器 managing concurrent streams.
 *
 * Handles stream creation, state transitions, 流控 windows,
 * 和连接级别窗口管理。
 */
public class Http2Multiplexer {
    private var streams: HashMap<UInt32, Http2Stream>
    private var nextStreamId: UInt32      // 客户端：奇数流，服务器：偶数流
    private var connectionSendWindow: Int64
    private var connectionRecvWindow: Int64
    private var maxConcurrentStreams: Int64
    private var isServer: Bool
    private var priorityTree: PriorityTree
    private var goawayReceived: Bool
    private var lastStreamId: UInt32
    private var goawaySent: Bool

    public init(isServer!: Bool = false) {
        this.streams = HashMap<UInt32, Http2Stream>()
        this.nextStreamId = if (isServer) { 2 } else { 1 }
        this.connectionSendWindow = 65535
        this.connectionRecvWindow = 65535
        this.maxConcurrentStreams = 100
        this.isServer = isServer
        this.priorityTree = PriorityTree()
        this.goawayReceived = false
        this.lastStreamId = 0
        this.goawaySent = false
    }

    /**
     * 创建新的客户端发起的流。
     * 强制执行 MAX_CONCURRENT_STREAMS 和 GOAWAY 限制。
     * 若达到并发流限制或收到 GOAWAY 则返回 None。
     */
    public func createStream(): ?Http2Stream {
        if (goawaySent || goawayReceived) { return None }
        if (!canCreateStream()) { return None }
        let streamId = nextStreamId
        nextStreamId += 2
        let stream = Http2Stream(streamId)
        stream.state = Http2StreamState.IDLE
        streams[streamId] = stream
        priorityTree.addStream(streamId, weight: 16, parent: None)
        Some(stream)
    }

    /**
     * 按 ID 获取已有流。
     */
    public func getStream(streamId: UInt32): ?Http2Stream {
        streams.get(streamId)
    }

    /**
     * 确保流存在（按需创建） (for server-received streams).
     * 强制执行 MAX_CONCURRENT_STREAMS 和 GOAWAY 限制。
     * 若达到限制或已发送 GOAWAY 且流 ID
     * 超过 last-stream-id 则返回 None。
     */
    public func ensureStream(streamId: UInt32): ?Http2Stream {
        // GOAWAY 后拒绝超过 last-stream-id 的流
        if (goawaySent && streamId > lastStreamId) { return None }
        match (streams.get(streamId)) {
            case Some(s) => Some(s)
            case None =>
                if (!canCreateStream()) { return None }
                let s = Http2Stream(streamId)
                s.state = Http2StreamState.IDLE
                streams[streamId] = s
                priorityTree.addStream(streamId, weight: 16, parent: None)
                Some(s)
        }
    }

    /**
     * 设置最大并发流数（来自 SETTINGS）。
     */
    public func setMaxConcurrentStreams(max: Int64): Unit {
        maxConcurrentStreams = max
    }

    /**
     * 移除已关闭的流。
     */
    public func removeStream(streamId: UInt32): Unit {
        streams.remove(streamId)
        priorityTree.removeStream(streamId)
    }

    /**
     * 检查是否可创建新流。
     */
    public func canCreateStream(): Bool {
        let activeCount = countActiveStreams()
        activeCount < maxConcurrentStreams
    }

    /**
     * 获取当前活跃流数量。
     */
    /**
     * 更新连接级别发送窗口。
     */
    public func updateConnectionSendWindow(increment: Int64): Unit {
        connectionSendWindow += increment
    /**
     * 检查是否允许创建新流（未达并发上限且未收到 GOAWAY）。
     */
    }

    /**
     * 获取连接级别发送窗口。
     */
    /**
     * 按状态关闭指定流。关闭时触发相关事件的回调通知。
     */
    public func getConnectionSendWindow(): Int64 { connectionSendWindow }

    /**
     * 调整所有现有流的发送窗口（按增量）。
     * 按 RFC 9113 Section 6.9.2：当 SETTINGS_INITIAL_WINDOW_SIZE 变化时，
    /**
     * 执行流状态转换（RFC 9113 §5）。验证转换合法性，
     * 触发状态变更回调，处理关闭时的资源清理。
     */
     * 所有现有流的流量控制窗口必须按增量调整。
     */
    public func adjustAllStreamSendWindows(delta: Int64): Unit {
        for ((_, stream) in streams) {
            if (stream.state != Http2StreamState.CLOSED && stream.state != Http2StreamState.IDLE) {
                stream.sendWindow += delta
    /**
     * 处理 GOAWAY 帧：停止新流创建，记录最后处理的流 ID。
     */
                // 按 RFC 9113 Section 6.9.2：若新窗口大小导致流发送窗口
                // 超过 2^31-1，作为 FLOW_CONTROL_ERROR 处理
                if (stream.sendWindow < 0 || stream.sendWindow > 2147483647) {
                    throw Http2Exception(Http2ErrorCode.FLOW_CONTROL_ERROR,
                        "Stream ${stream.streamId} send window overflow after INITIAL_WINDOW_SIZE change")
                }
            }
        }
    }

    /**
     * 更新连接级别接收窗口。
     */
    public func updateConnectionRecvWindow(increment: Int64): Unit {
    /**
     * 发送 GOAWAY 帧：发起优雅关闭，记录已发送状态。
     */
        connectionRecvWindow += increment
    }

    /**
     * 从流的发送窗口消费。
     */
    public func consumeStreamSendWindow(streamId: UInt32, amount: Int64): Bool {
        match (streams.get(streamId)) {
            case Some(stream) =>
                if (stream.sendWindow >= amount && connectionSendWindow >= amount) {
                    stream.sendWindow -= amount
                    connectionSendWindow -= amount
                    return true
                }
    /**
     * 检查流 ID 是否为服务端发起的（偶数 = 服务端，奇数 = 客户端）。
     */
                false
            case None => false
        }
    }
    /**
     * 重置多路复用器状态（用于连接重置后的重新初始化）。
     */

    /**
     * 增加到流的接收窗口。
     */
    public func addStreamRecvWindow(streamId: UInt32, amount: Int64): Unit {
        match (streams.get(streamId)) {
            case Some(stream) =>
                stream.recvWindow += amount
            case None => ()
        }
    }

    /**
     * 从流的接收窗口消耗。
     */
    public func consumeStreamRecvWindow(streamId: UInt32, amount: Int64): Bool {
        match (streams.get(streamId)) {
            case Some(stream) =>
                if (stream.recvWindow >= amount) {
                    stream.recvWindow -= amount
                    connectionRecvWindow -= amount
                    return true
                }
                false
            case None => false
        }
    }

    /**
     * 将流转换到新状态。
     * 根据 RFC 9113 第 5.1 节验证状态转换。
     * 在无效转换时抛出 Http2Exception(PROTOCOL_ERROR)。
     */
    public func transitionState(streamId: UInt32, newState: Http2StreamState): Unit {
        match (streams.get(streamId)) {
            case Some(stream) =>
                if (!validTransition(stream.state, newState)) {
                    throw Http2Exception(
                        Http2ErrorCode.PROTOCOL_ERROR,
                        "invalid stream state transition on stream ${streamId}"
                    )
                }
                stream.state = newState
            case None => ()
        }
    }

    /**
     * 根据 RFC 9113 第 5.1 节验证流状态转换。
     */
    private func validTransition(from: Http2StreamState, to: Http2StreamState): Bool {
        match (from) {
            case Http2StreamState.IDLE =>
                to == Http2StreamState.OPEN ||
                to == Http2StreamState.RESERVED_LOCAL ||
                to == Http2StreamState.RESERVED_REMOTE
            case Http2StreamState.RESERVED_LOCAL =>
                to == Http2StreamState.HALF_CLOSED_REMOTE ||
                to == Http2StreamState.CLOSED
            case Http2StreamState.RESERVED_REMOTE =>
                to == Http2StreamState.HALF_CLOSED_LOCAL ||
                to == Http2StreamState.CLOSED
            case Http2StreamState.OPEN =>
                to == Http2StreamState.HALF_CLOSED_LOCAL ||
                to == Http2StreamState.HALF_CLOSED_REMOTE ||
                to == Http2StreamState.CLOSED
            case Http2StreamState.HALF_CLOSED_LOCAL =>
                to == Http2StreamState.CLOSED
            case Http2StreamState.HALF_CLOSED_REMOTE =>
                to == Http2StreamState.CLOSED
            case Http2StreamState.CLOSED => false  // 无法从 CLOSED 状态转换
        }
    }

    /**
     * 标记已收到带有给定最后流 ID 的 GOAWAY 帧。
     */
    public func markGoawayReceived(lastId: UInt32): Unit {
        goawayReceived = true
        lastStreamId = lastId
    }

    /**
     * 标记已发送带有给定最后流 ID 的 GOAWAY 帧。
     */
    public func markGoawaySent(lastId: UInt32): Unit {
        goawaySent = true
        lastStreamId = lastId
    }

    /**
     * 检查 GOAWAY 是否已发送。
     */
    public func isGoawaySent(): Bool { goawaySent }

    /**
     * 检查 GOAWAY 是否已接收。
     */
    public func isGoawayReceived(): Bool { goawayReceived }

    /**
     * 获取下一个可用流 ID。
     */
    public func getNextStreamId(): UInt32 { nextStreamId }

    /**
     * 获取连接接收窗口大小。
     */
    public func getConnectionRecvWindow(): Int64 { connectionRecvWindow }

    /**
     * 计数活动（未关闭）流。
     */
    public func countActiveStreams(): Int64 {
        var count: Int64 = 0
        for ((_, stream) in streams) {
            if (stream.state != Http2StreamState.CLOSED) {
                count++
            }
        }
        count
    }

    /**
     * 关闭所有流（在 GOAWAY 或连接关闭时）。
     * 根据 RFC 9113 第 5.1.1 节，流 ID 不得重复使用。
     */
    public func closeAll(errorCode: Http2ErrorCode): Unit {
        for ((id, stream) in streams) {
            stream.state = Http2StreamState.CLOSED
        }
        streams.clear()
        priorityTree.clear()
        // 注意：nextStreamId 不会重置 — 根据 RFC 9113，流 ID 不得重复使用
    }

    /**
     * 从 PRIORITY 帧更新流优先级。
     */
    public func updatePriority(streamId: UInt32, exclusive: Bool, streamDep: UInt32, weight: UInt8): Unit {
        priorityTree.processPriority(streamId, exclusive, streamDep, weight)
    }

    /**
     * Get the 优先级树 for scheduling decisions.
     */
    public func getPriorityTree(): PriorityTree { priorityTree }

    /**
     * 创建服务器推送的流（偶数流 ID）。
     */
    public func createPushStream(parentStreamId: UInt32): ?Http2Stream {
        let pushId = nextStreamId
        nextStreamId += 2
        let stream = Http2Stream(pushId)
        stream.state = Http2StreamState.RESERVED_LOCAL
        streams[pushId] = stream
        // 推送的流依赖于父流
        priorityTree.addStream(pushId, weight: 16, parent: Some(parentStreamId))
        Some(stream)
    }
}
