/**
 * HTTP/3 连接处理器（RFC 9114）。
 *
 * 管理 HTTP/3 协议在 QUIC 连接上的完整生命周期：
 * - 控制流的创建与管理
 * - QPACK 编码器/解码器流
 * - HTTP 请求/响应的帧交换
 * - SETTINGS / GOAWAY 等连接级帧处理
 * - 流取消与错误处理
 *
 * HTTP/3 帧在 QUIC 流上传输。一条 QUIC 连接上可同时存在多条流，
 * 实现 HTTP 多路复用。具体流类型（RFC 9114 §6.2）：
 * - 控制流（类型 0x00）：单向，传输 SETTINGS、GOAWAY、MAX_PUSH_ID
 * - 推送流（类型 0x01）：单向，传输服务端推送的响应
 * - QPACK 编码器流（类型 0x02）：单向，传输 QPACK 动态表更新
 * - QPACK 解码器流（类型 0x03）：单向，传输 QPACK 确认指令
 * - 请求流：双向，传输 HTTP 请求/响应的 HEADERS+DATA 帧
 *
 * @see https://www.rfc-editor.org/rfc/rfc9114
 */
package http_lib.http3

import std.collection.{ArrayList, HashMap}
import std.collection.concurrent.ConcurrentHashMap
import std.sync.{AtomicBool, AtomicInt64, Mutex}
import std.time.DateTime
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, ProtocolException}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.buffer.ByteBuffer
import http_lib.http2.{encodeQuicVarint, decodeQuicVarint}
import std.convert.Parsable
import http_lib.utils.{findHeaderEnd, containsIgnoreCase}

// ======== 常量 ========

/// HTTP/3 第一个有效字节中的帧类型位掩码（短格式帧类型 <= 0x3F）。
private let H3_FRAME_TYPE_MASK: UInt8 = 0x3Fu8

/// HTTP/3 流类型在第一个字节中的位掩码。
private let H3_STREAM_TYPE_MASK: UInt8 = 0x3Fu8

/// HTTP/3 最大推送 ID 帧类型值。
private let H3_FRAME_MAX_PUSH_ID: UInt8 = 0x0Du8

/// HTTP/3 取消推送帧类型值。
private let H3_FRAME_CANCEL_PUSH: UInt8 = 0x03u8

// ======== HTTP/3 连接状态 ========

/**
 * HTTP/3 连接状态。
 */
public enum H3ConnectionState <: ToString & Equatable<H3ConnectionState> {
    | H3_STATE_INITIAL       // 连接建立，正在等待 SETTINGS
    | H3_STATE_CONNECTED     // SETTINGS 已交换，可处理请求
    | H3_STATE_GOAWAY_SENT   // 已发送 GOAWAY，不再接受新请求
    | H3_STATE_GOAWAY_RECV   // 已收到 GOAWAY，正在排空
    | H3_STATE_CLOSED        // 连接已关闭

    public func toString(): String {
        match (this) {
            case H3_STATE_INITIAL => "INITIAL"
            case H3_STATE_CONNECTED => "CONNECTED"
            case H3_STATE_GOAWAY_SENT => "GOAWAY_SENT"
            case H3_STATE_GOAWAY_RECV => "GOAWAY_RECV"
            case H3_STATE_CLOSED => "CLOSED"
        }
    }

    public operator func ==(that: H3ConnectionState): Bool {
        match ((this, that)) {
            case (H3_STATE_INITIAL, H3_STATE_INITIAL) => true
            case (H3_STATE_CONNECTED, H3_STATE_CONNECTED) => true
            case (H3_STATE_GOAWAY_SENT, H3_STATE_GOAWAY_SENT) => true
            case (H3_STATE_GOAWAY_RECV, H3_STATE_GOAWAY_RECV) => true
            case (H3_STATE_CLOSED, H3_STATE_CLOSED) => true
            case _ => false
        }
    }

    public operator func !=(that: H3ConnectionState): Bool {
        !(this == that)
    }
}

// ======== HTTP/3 连接配置 ========

/**
    private var qpBlockedStreams: HashMap<UInt64, QuicStream> = HashMap<UInt64, QuicStream>()
 */
public class H3ConnectionConfig {
    public var maxFieldSectionSize: Int64 = 65536
    public var qpackMaxTableCapacity: Int64 = 4096
    public var qpackBlockedStreams: Int64 = 100
    public var maxPushId: Int64 = 0
    public var enableConnectProtocol: Bool = true
    public var enableH3Datagram: Bool = false
    public var serverName: String = "http_lib_h3/0.1"
    public var readTimeout: Duration = Duration.second * 30
    public var writeTimeout: Duration = Duration.second * 30
    public var drainTimeout: Duration = Duration.second * 30
    // SETTINGS 交换超时时间。若超时仍未收到对端 SETTINGS，连接将被关闭。
    public var settingsExchangeTimeout: Duration = Duration.second * 10
    public var zeroRttPriorSettings: ?HashMap<UInt16, UInt64> = None

    public init() {}

    public static func from(config: Http3Config): H3ConnectionConfig {
        let c = H3ConnectionConfig()
        c.maxFieldSectionSize = config.maxFieldSectionSize
        c.qpackMaxTableCapacity = config.qpackMaxTableCapacity
        c.qpackBlockedStreams = config.qpackBlockedStreams
        c.maxPushId = config.maxPushId
        c.enableConnectProtocol = config.enableConnectProtocol
        c.enableH3Datagram = config.enableH3Datagram
        c.zeroRttPriorSettings = config.zeroRttPriorSettings
        c
    }
}

// ======== 流状态 ========

/**
 * HTTP/3 中的流状态（简化版 RFC 9114 §3.4）。
 */
private enum StreamState {
    | IDLE
    | OPEN
    | HALF_CLOSED_REMOTE
    | HALF_CLOSED_LOCAL
    | CLOSED
}

// ======== 请求任务 ========

/**
 * 等待被填充的响应（用于服务器端）。
 */
internal class PendingResponse {
    public let request: HttpRequest
    public var response: ?HttpResponse = None
    public var error: ?String = None
    public var completed: Bool = false

    public init(request: HttpRequest) {
        this.request = request
    }
}



// ======== 推送流管理 ========



/**

 * 等待被接收的推送响应（用于客户端）。

 */

internal class PendingPush {

    public let pushId: UInt64

    public var pushRequest: ?HttpRequest = None

    public var response: ?HttpResponse = None

    public var completed: Bool = false

    public var cancelled: Bool = false



    public init(pushId: UInt64) {

        this.pushId = pushId

    }

}



// ======== HTTP/3 连接处理器 ========

/**
 * HTTP/3 连接处理器。
 *
 * 在单个 QUIC 连接上管理 HTTP/3 协议：
 * - 控制流管理（SETTINGS 交换、GOAWAY、MAX_PUSH_ID）
 * - QPACK 编码器/解码器流管理
 * - 请求/响应流处理
 * - 帧读写
 *
 * 用法（服务器端）：
 *   let h3Conn = H3Connection(quicConn, config, isServer: true)
 *   h3Conn.sendSettings()
 *   while (h3Conn.isConnected()) {
 *       match (h3Conn.acceptRequest()) {
 *           case Some(req) => h3Conn.sendResponse(..)
 *           case None => break
 *       }
 *   }
 */
public class H3Connection {
    // ---- QUIC 传输层 ----
    private var quicConn: QuicConnection
    private var config: H3ConnectionConfig
    private var isServer: Bool
    private var remoteAddr: String = ""

    // ---- 连接状态 ----
    private var state: H3ConnectionState = H3ConnectionState.H3_STATE_INITIAL
    private var stateMu: Mutex = Mutex()

    // ---- 控制流 ----
    private var controlStream: ?QuicStream = None
    private var peerControlStream: ?QuicStream = None

    // ---- QPACK ----
    private var encoder: QpackEncoder
    private var decoder: QpackDecoder
    private var encoderStream: ?QuicStream = None
    private var decoderStream: ?QuicStream = None
    private var peerEncoderStream: ?QuicStream = None
    private var peerDecoderStream: ?QuicStream = None

    // ---- SETTINGS ----
    private var localSettings: HashMap<UInt16, UInt64> = HashMap<UInt16, UInt64>()
    private var peerSettings: HashMap<UInt16, UInt64> = HashMap<UInt16, UInt64>()
    private var settingsExchanged: Bool = false
    private var settingsSentAt: ?DateTime = None
    private var zeroRttPriorSettings: ?HashMap<UInt16, UInt64> = None

    // ---- 流管理 ----
    private var nextStreamId: AtomicInt64 = AtomicInt64(0)
    private var activeStreams: ConcurrentHashMap<UInt64, QuicStream> = ConcurrentHashMap<UInt64, QuicStream>()
    private var streamStates: ConcurrentHashMap<UInt64, StreamState> = ConcurrentHashMap<UInt64, StreamState>()

    // ---- GOAWAY ----
    private var goawayLastStreamId: UInt64 = 0
    private var goawayReceived: Bool = false

    // ---- 请求/响应队列 ----
    private var incomingRequests: ArrayList<HttpRequest> = ArrayList<HttpRequest>()
    private var requestMu: Mutex = Mutex()

    // ---- 服务器端处理 ----
    private var requestHandler: ?(HttpRequest) -> HttpResponse = None

    // ---- 优先级调度 ----
    private var priorityScheduler: PriorityScheduler = PriorityScheduler()

    // ---- 客户端处理 ----
    private var pendingResponses: HashMap<UInt64, PendingResponse> = HashMap<UInt64, PendingResponse>()
    private var pendingMu: Mutex = Mutex()

    // ---- 错误处理 ----
    private var lastError: ?String = None

    // ---- 写入互斥 ----
    private var writeMu: Mutex = Mutex()


    // ---- WebTransport M-M0M-^M-hM-0M-M-bM-.M-AM-MgM-0M-M-bM-^PM-^F ----
    private var wtSessions: HashMap<UInt64, WebTransportSession> = HashMap<UInt64, WebTransportSession>()
    private var wtMu: Mutex = Mutex()

    // ---- GREASE 计数器（RFC 9114 §9.6）----
    private var greaseFrameCounter: Int64 = 0
    private var greaseStreamCounter: Int64 = 0

    // ---- 推送管理 ----

    private var nextPushId: AtomicInt64 = AtomicInt64(0)

    private var pendingPushes: HashMap<UInt64, PendingPush> = HashMap<UInt64, PendingPush>()

    private var pushStreamMap: HashMap<UInt64, UInt64> = HashMap<UInt64, UInt64>()

    private var pushMu: Mutex = Mutex()

    private var pushResponseHandler: ?(UInt64, HttpResponse) -> Unit = None

    private var completedPushesList: ArrayList<(UInt64, HttpResponse)> = ArrayList<(UInt64, HttpResponse)>()

    // ---- QPACK 阻塞流管理 ----
    private var qpBlockedStreams: HashMap<UInt64, QuicStream> = HashMap<UInt64, QuicStream>()


    /**
     * 创建 HTTP/3 连接处理器。
     *
     * @param quicConn QUIC 连接
     * @param config HTTP/3 连接配置
     * @param isServer 是否为服务器端
     */
    public init(quicConn: QuicConnection, config!: H3ConnectionConfig = H3ConnectionConfig(), isServer!: Bool = false) {
        this.quicConn = quicConn
        this.config = config
        this.isServer = isServer
        this.encoder = QpackEncoder(maxTableCapacity: config.qpackMaxTableCapacity, blockedStreams: config.qpackBlockedStreams)
        this.decoder = QpackDecoder(maxTableCapacity: config.qpackMaxTableCapacity)
        quicConn.setReadTimeout(config.readTimeout)
        zeroRttPriorSettings = config.zeroRttPriorSettings
        remoteAddr = quicConn.getRemoteAddr()
        quicConn.setPathMigrationHandler({addr =>
            remoteAddr = addr
        })
    }

    // ======== 公共 API ========

    /**
     * 发送 SETTINGS 帧并建立控制流和 QPACK 流。
     * 在连接建立后调用。
     */
    public func sendSettings(): Unit {
        stateMu.lock()
        if (state != H3ConnectionState.H3_STATE_INITIAL) {
            stateMu.unlock()
            return
        }
        stateMu.unlock()

        // 创建控制流（单向流，类型 0x00）
        let ctrlStream = quicConn.openUnidirectionalStream()
        match (ctrlStream) {
            case Some(s) =>
                this.controlStream = Some(s)
                // 写入流类型字节 (0x00 = 控制流)
                s.write([0x00u8])
                // 编码并写入 SETTINGS
                let settings = buildLocalSettings()

                // GREASE SETTINGS 自动注入（RFC 9114 §9.6）
                let merged = ArrayList<(Http3SettingsId, UInt64)>()
                for (s in settings) { merged.add(s) }
                for (g in buildGreaseSettings()) { merged.add(g) }
                let allSettings = merged.toArray()
                let settingsFrame = buildH3SettingsFrame(allSettings)
                s.write(settingsFrame)
                s.flush()
            case None =>
                setError("无法创建控制流")
                return
        }

        // 创建 QPACK 编码器流（单向流，类型 0x02）
        let encStream = quicConn.openUnidirectionalStream()
        match (encStream) {
            case Some(s) =>
                this.encoderStream = Some(s)
                s.write([0x02u8]) // 流类型字节
                s.flush()
            case None => ()
        }

        // 创建 QPACK 解码器流（单向流，类型 0x03）
        let decStream = quicConn.openUnidirectionalStream()
        match (decStream) {
            case Some(s) =>
                this.decoderStream = Some(s)
                s.write([0x03u8]) // 流类型字节
                s.flush()
            case None => ()
        }

        // 偶尔发送 GREASE 流类型（RFC 9114 §9.6）
        maybeSendGreaseStream()

        settingsSentAt = Some(DateTime.now())
        stateMu.lock()
        if (state == H3ConnectionState.H3_STATE_INITIAL) {
            state = H3ConnectionState.H3_STATE_CONNECTED
        }
        stateMu.unlock()
    }

    /**
     * 设置请求处理器（服务器端）。
     */
    public func setRequestHandler(handler: (HttpRequest) -> HttpResponse): Unit {
        this.requestHandler = Some(handler)
    }

    /**
     * 获取优先级调度器。
     */
    public func getPriorityScheduler(): PriorityScheduler {
        priorityScheduler
    }

    /**
     * 获取对端 QUIC 地址。
     */
    public func getRemoteAddr(): String { remoteAddr }

    /**
     * 设置对端地址（连接迁移时使用）。
     */
    public func setRemoteAddr(addr: String): Unit { remoteAddr = addr }

    /**
     * 检查 SETTINGS 交换是否超时。
     * 如果尚未收到对端 SETTINGS 且超出配置的超时时间，返回 true。
     */
    public func getPeerSettings(): HashMap<UInt16, UInt64> {
        let copy = HashMap<UInt16, UInt64>()
        for (k in peerSettings.keys()) {
            copy[k] = peerSettings[k]
        }
        copy
    }

    public func hasSettingsExchangeTimedOut(): Bool {
        if (settingsExchanged) { return false }
        match (settingsSentAt) {
            case Some(t) =>
                (DateTime.now() - t) > config.settingsExchangeTimeout
            case None => false
        }
    }

    /**

     * 设置推送响应处理器（客户端）。

     */

    public func setPushResponseHandler(handler: (UInt64, HttpResponse) -> Unit): Unit {

        this.pushResponseHandler = Some(handler)

    }



    /**

     * 发送 PUSH_PROMISE 帧（服务器端）。

     */

    public func sendPushPromise(requestStreamId: UInt64, pushRequest: HttpRequest): ?UInt64 {

        if (config.maxPushId <= 0) {

            setError("服务端推送已被客户端禁用")

            return None

        }

        let pushId = UInt64(nextPushId.fetchAdd(1))

        if (Int64(pushId) > config.maxPushId) {

            nextPushId.fetchSub(1)

            return None

        }

        let h3Headers = buildRequestHeaders(pushRequest)

        let qpackData = encoder.encode(h3Headers)
        encoder.registerEncodedStream(pushId)

        let pushPromiseFrame = buildH3PushPromiseFrame(pushId, qpackData)

        let stream = activeStreams.get(requestStreamId)

        match (stream) {

            case Some(s) =>

                try {

                    s.write(pushPromiseFrame); s.flush()

                    pushMu.lock(); pendingPushes[pushId] = PendingPush(pushId); pushMu.unlock()

                    Some(pushId)

                } catch (e: Exception) {

                    setError("发送 PUSH_PROMISE 失败: ${e.message}"); None

                }

            case None => setError("请求流不存在"); None

        }

    }



    /**

     * 发送推送响应（服务器端）。

     */

    public func sendPushResponse(pushId: UInt64, response: HttpResponse): Unit {

        if (Int64(pushId) > config.maxPushId) { setError("超过推送限制"); return }

        let pushStream = quicConn.openUnidirectionalStream()

        match (pushStream) {

            case Some(s) =>

                try {

                    s.write([0x01u8]); s.write(encodeQuicVarint(pushId))

                    let qpackData = encoder.encode(buildPushResponseHeaders(response))
                    encoder.registerEncodedStream(pushId)

                    s.write(encodeH3Frame(Http3FrameType.HEADERS, qpackData))

                    let bodyBytes = response.bodyAsBytes()

                    if (bodyBytes.size > 0) { s.write(encodeH3Frame(Http3FrameType.DATA, bodyBytes)) }

                    s.flush(); s.closeWrite()

                } catch (e: Exception) { setError("发送推送响应失败: ${e.message}") }

            case None => setError("无法创建推送流")

        }

    }



    /**

     * 获取可用的推送 ID 数量。

     */

    public func getAvailablePushIds(): Int64 {

        let nextId = nextPushId.load(); let maxId = config.maxPushId

        if (nextId > maxId) { 0 } else { maxId - nextId }

    }



    /**

     * 获取等待处理的推送响应列表（客户端）。

     */

    public func getCompletedPushes(): ArrayList<(UInt64, HttpResponse)> {

        let result = ArrayList<(UInt64, HttpResponse)>()

        pushMu.lock()

        for (i in 0..completedPushesList.size) {

            let (pushId, resp) = completedPushesList[i]

            result.add((pushId, resp))

            pendingPushes.remove(pushId)

        }

        completedPushesList = ArrayList<(UInt64, HttpResponse)>()

        pushMu.unlock()

        result

    }



    /**

     * 检查请求是否为 Extended CONNECT（RFC 9220）。

     */

    public func isExtendedConnectRequest(request: HttpRequest): Bool {

        if (!config.enableConnectProtocol) { return false }

        if (request.method != HttpMethod.CONNECT) { return false }

        match (request.headers.get(":protocol")) {

            case Some(_) => true

            case None => match (request.headers.get("protocol")) {

                case Some(_) => true; case None => false

            }

        }

    }



    /**

     * 建立 Extended CONNECT 隧道。

     */

    public func establishTunnel(streamId: UInt64, request: HttpRequest, onData: (Array<UInt8>) -> Unit): Bool {

        let stream = activeStreams.get(streamId)

        match (stream) {

            case Some(s) => try { spawn { relayTunnelData(streamId, s, onData) }; true } catch (e: Exception) { false }

            case None => false

        }

    }



    /**

     * 通过 Extended CONNECT 隧道发送数据。

     */

    public func sendTunnelData(streamId: UInt64, data: Array<UInt8>): Unit {

        let stream = activeStreams.get(streamId)

        match (stream) {

            case Some(s) =>

                try {

                    let dataFrame = encodeH3Frame(Http3FrameType.DATA, data)

                    s.write(dataFrame); s.flush()

                } catch (_: Exception) {}

            case None => ()

        }

    }



    /**

     * 关闭 Extended CONNECT 隧道。

     */

    public func closeTunnel(streamId: UInt64): Unit {

        let stream = activeStreams.get(streamId)

        match (stream) {

            case Some(s) =>

                try { s.closeWrite(); activeStreams.remove(streamId) } catch (_: Exception) {}

            case None => ()

        }

    }



    /**

     * 转发隧道数据。

     */

    private func relayTunnelData(streamId: UInt64, stream: QuicStream, onData: (Array<UInt8>) -> Unit): Unit {

        try {

            let buf = Array<UInt8>(65536, repeat: 0)

            while (true) {

                let n = stream.read(buf)

                if (n <= 0) { break }

                let data = buf[0..n]

                if (n >= 2) {

                    let (typeVal, typeLen) = decodeQuicVarint(data, 0)

                    if (UInt8(typeVal) == Http3FrameType.DATA.toUInt8()) {

                        let afterType = data[typeLen..n]

                        let (lenVal, lenLen) = decodeQuicVarint(afterType, 0)

                        let payloadStart = typeLen + lenLen

                        if (payloadStart < n) { onData(data[payloadStart..n]) }

                    }

                }

            }

        } catch (_: Exception) {}

    }


    /**
     * 获取下一个传入请求（服务器端）。
     * 阻塞直到有新请求到达或连接关闭。
     * 返回 None 表示连接已关闭。
     */
    public func acceptRequest(): ?HttpRequest {
        while (isConnected()) {
            requestMu.lock()
            if (incomingRequests.size > 0) {
                let req = incomingRequests[0]
                incomingRequests.remove(0..1)
                requestMu.unlock()
                // Detect WebTransport CONNECT, route internally
                if (H3Connection.isWebTransportRequest(req)) {
                    handleWebTransportRequest(req)
                    continue  // Handled internally, don't return to caller
                }
                return Some(req)
            }
            requestMu.unlock()
            // 尝试读取下一个流
            if (!processNextStream()) {
                return None
            }
        }
        None
    }

    /// 获取底层 QUIC 连接。
    public func getQuicConnection(): QuicConnection {
        quicConn
    }

    /// 检查请求是否为 WebTransport（RFC 9220）CONNECT 请求。
    public static func isWebTransportRequest(req: HttpRequest): Bool {
        if (req.method != HttpMethod.CONNECT) { return false }
        let protocolVal = match (req.headers.get(":protocol")) {
            case Some(v) => v
            case None => match (req.headers.get("protocol")) {
                case Some(v) => v
                case None => ""
            }
        }
        protocolVal == "webtransport"
    }

    /// 服务端侧接受 WebTransport 会话。
    /// 先检查会话注册表，再检查待处理请求队列中的 WT CONNECT 请求。
    public func acceptWebTransport(): ?WebTransportSession {
        // Check WebTransport session registry first
        wtMu.lock()
        let sessionKeys = ArrayList<UInt64>()
        for (sid in wtSessions.keys()) { sessionKeys.add(sid) }
        if (sessionKeys.size > 0) {
            let streamId = sessionKeys[0]
            match (wtSessions.get(streamId)) {
                case Some(s) =>
                    wtSessions.remove(streamId)
                    wtMu.unlock()
                    return Some(s)
                case None => ()
            }
        }
        wtMu.unlock()
        // Check pending incoming requests for WT CONNECT
        requestMu.lock()
        var found: (?WebTransportSession) = None
        var remaining = ArrayList<HttpRequest>()
        for (req in incomingRequests) {
            if (H3Connection.isWebTransportRequest(req)) {
                let path = req.url
                let origin = match (req.headers.get("origin")) {
                    case Some(o) => o
                    case None => ""
                }
                let streamId = match (req.metadata) {
                    case Some(sv: UInt64) => sv
                    case _ => 0u64
                }
                let session = WebTransportSession(
                    this, quicConn, streamId, path, origin
                )
                session.markEstablished(streamId)
                let resp = HttpResponse(status: HttpStatus.OK)
                sendResponse(streamId, resp)
                found = Some(session)
            } else {
                remaining.add(req)
            }
        }
        incomingRequests = remaining
        requestMu.unlock()
        found
    }



    /**
     * 发送 HTTP 响应（服务器端）。
     *
     * @param streamId QUIC 流 ID
     * @param response HTTP 响应
     */
    /**
     * 发送完整响应（头部 + 体）。
     * 默认全缓冲方式。
     * 对于大响应或流式场景，
     * 请使用 sendResponseHeaders() + sendResponseBody() 组合。
     */

    // ---- WebTransport 内部方法 ----

    /// Internal: handle a WebTransport CONNECT request.
    /// Creates a WebTransportSession, sends 200 response, registers in session registry.
    private func handleWebTransportRequest(req: HttpRequest): Unit {
        let path = req.url
        let origin = match (req.headers.get("origin")) {
            case Some(o) => o
            case None => ""
        }
        let streamId = match (req.metadata) {
            case Some(sv: UInt64) => sv
            case _ => 0u64
        }
        let session = WebTransportSession(
            this, quicConn, streamId, path, origin
        )
        session.markEstablished(streamId)
        // Send 200 response
        let resp = HttpResponse(status: HttpStatus.OK)
        sendResponse(streamId, resp)
        // Register session
        wtMu.lock()
        wtSessions[streamId] = session
        wtMu.unlock()
    }

    /// Route an incoming stream to a WebTransport session if it belongs to one.
    /// Returns true if the stream was routed, false if no session claims it.
    private func routeIncomingStreamToSession(streamId: UInt64, stream: QuicStream): Bool {
        wtMu.lock()
        for (sid in wtSessions.keys()) {
            match (wtSessions.get(sid)) {
                case Some(session) =>
                    if (session.ownsStream(streamId)) {
                        session.addIncomingStream(stream)
                        wtMu.unlock()
                        return true
                    }
                case None => ()
            }
        }
        wtMu.unlock()
        false
    }

    /// Enqueue an incoming HTTP request for processing.
    /// Used internally when a complete HTTP request has been read from a QUIC stream.
    /// Also available as a public test hook for simulating incoming requests.
    public func enqueueIncomingRequest(streamId: UInt64, request: HttpRequest): Unit {
        request.metadata = Some(streamId)
        requestMu.lock()
        incomingRequests.add(request)
        requestMu.unlock()
    }

    public func sendResponse(streamId: UInt64, response: HttpResponse): Unit {
        sendResponseHeaders(streamId, response)
        let bodyBytes = response.bodyAsBytes()
        sendResponseBody(streamId, bodyBytes, true)
    }

    /**
     * 发送 HTTP/3 响应头（HEADERS 帧）。
     * 可与 sendResponseBody() 配合实现流式响应。
     *
     * @param streamId 流 ID
     * @param response 响应对象（仅使用 headers）
     */
    public func sendResponseHeaders(streamId: UInt64, response: HttpResponse): Unit {
        let stream = activeStreams.get(streamId)
        match (stream) {
            case Some(s) =>
                try {
                    let headerData = encoder.encode(response.headers)
                    encoder.registerEncodedStream(streamId)
                    let headersFrame = encodeH3Frame(Http3FrameType.HEADERS, headerData)
                    s.write(headersFrame)
                    s.flush()
                } catch (e: Exception) {
                    setError("发送响应头失败: ${e.message}")
                }
            case None =>
                setError("流 ${streamId} 不存在或已关闭")
        }
    }

    /**
     * 发送 HTTP/3 响应内容（DATA 帧）。
     * 可多次调用以实现流式输出。
     *
     * @param streamId 流 ID
     * @param data 内容数据
     * @param endStream 是否为最后一个数据块（错误关闭流）
     */
    public func sendResponseBody(streamId: UInt64, data: Array<UInt8>, endStream: Bool): Unit {
        let stream = activeStreams.get(streamId)
        match (stream) {
            case Some(s) =>
                try {
                    if (data.size > 0) {
                        let dataFrame = encodeH3Frame(Http3FrameType.DATA, data)
                        s.write(dataFrame)
                    }
                    if (endStream) {
                        s.flush()
                        s.closeWrite()
                        streamStates[streamId] = StreamState.CLOSED
                        activeStreams.remove(streamId)
                    } else {
                        s.flush()
                    }
                } catch (e: Exception) {
                    setError("发送响应体失败: ${e.message}")
                }
            case None =>
                setError("流 ${streamId} 不存在或已关闭")
        }
    }

    /**
     * 发送 HTTP 请求（客户端）。
     *
     * @param request HTTP 请求
     * @return 响应的 QUIC 流 ID
     */
    public func sendRequest(request: HttpRequest): ?UInt64 {

        let streamId = UInt64(nextStreamId.fetchAdd(1))
        let stream = quicConn.openStream()
        match (stream) {
            case Some(s) =>
                activeStreams[streamId] = s
                streamStates[streamId] = StreamState.OPEN
                try {
                    // 构建包含伪头部的完整头
                    let h3Headers = buildRequestHeaders(request)
                    // QPACK 编码
                    let headerData = encoder.encode(h3Headers)
                    encoder.registerEncodedStream(streamId)
                    let headersFrame = encodeH3Frame(Http3FrameType.HEADERS, headerData)
                    s.write(headersFrame)
                    // 写入请求体
                    let bodyBytes = request.bodyAsBytes()
                    if (bodyBytes.size > 0) {
                        let dataFrame = encodeH3Frame(Http3FrameType.DATA, bodyBytes)
                        s.write(dataFrame)
                    }
                    s.flush()
                    s.closeWrite()
                    streamStates[streamId] = StreamState.HALF_CLOSED_LOCAL
                    // 注册待处理响应
                    let pending = PendingResponse(request)
                    pendingMu.lock()
                    pendingResponses[streamId] = pending
                    pendingMu.unlock()
                    Some(streamId)
                } catch (e: Exception) {
                    setError("发送请求失败: ${e.message}")
                    activeStreams.remove(streamId)
                    streamStates.remove(streamId)
                    None
                }
            case None =>
                None
        }
    }

    /**
     * 接收 HTTP 响应（客户端）。
     * 等待流上的响应到达。
     *
     * @param streamId QUIC 流 ID
     * @return HTTP 响应
     */
    public func recvResponse(streamId: UInt64): ?HttpResponse {
        let startTime = DateTime.now()
        let timeoutDuration = config.readTimeout

        while (DateTime.now() - startTime < timeoutDuration) {
            pendingMu.lock()
            let pending = pendingResponses.get(streamId)
            pendingMu.unlock()
            match (pending) {
                case Some(p) =>
                    if (p.completed) {
                        pendingMu.lock()
                        pendingResponses.remove(streamId)
                        pendingMu.unlock()
                        return p.response
                    }
                case None => return None
            }
            // 处理流数据
            let stream = activeStreams.get(streamId)
            match (stream) {
                case Some(s) =>
                    if (tryReadResponseFromStream(streamId, s)) {
                        pendingMu.lock()
                        let updated = pendingResponses.get(streamId)
                        pendingMu.unlock()
                        match (updated) {
                            case Some(p) =>
                                if (p.completed) {
                                    pendingMu.lock()
                                    pendingResponses.remove(streamId)
                                    pendingMu.unlock()
                                    return p.response
                                }
                            case _ => ()
                        }
                    } else {
                        // 流关闭，无更多数据
                        return None
                    }
                case None => return None
            }
            // 短暂让步
        }
        None  // 超时
    }

    /**
     * 发送 GOAWAY 帧。
     * 通知对端我们将关闭连接。
     */
    public func sendGoaway(lastStreamId!: UInt64 = 0): Unit {

        match (controlStream) {
            case Some(s) =>
                try {
                    let goawayFrame = buildH3GoawayFrame(lastStreamId)
                    s.write(goawayFrame)
                    s.flush()
                } catch (_: Exception) {}
            case None => ()
        }

        stateMu.lock()
        if (state == H3ConnectionState.H3_STATE_CONNECTED) {
            state = H3ConnectionState.H3_STATE_GOAWAY_SENT
        }
        stateMu.unlock()
    }

    /**
     * 发送 MAX_PUSH_ID 帧。
     * 允许服务器端推送的最大流 ID。
     */
    public func sendMaxPushId(maxPushId: UInt64): Unit {

        match (controlStream) {
            case Some(s) =>
                try {
                    let frame = buildH3MaxPushIdFrame(maxPushId)
                    s.write(frame)
                    s.flush()
                } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 优雅关闭连接。
     */
    public func gracefulShutdown(): Unit {
        sendGoaway(lastStreamId: UInt64(nextStreamId.load()))
        // 等待已有流排空（drain）
        let drainTimeout = config.drainTimeout
        if (drainTimeout.toNanoseconds() > 0) {
            let deadline = DateTime.now() + drainTimeout
            while (activeStreams.size > 0) {
                if (DateTime.now() > deadline) { break }
                sleep(Duration.millisecond * 100)
            }
        }
        stateMu.lock()
        state = H3ConnectionState.H3_STATE_CLOSED
        stateMu.unlock()
        try {
            quicConn.closeWithError(QuicErrorCode.QUIC_NO_ERROR, "HTTP/3 优雅关闭")
        } catch (_: Exception) {
            try { quicConn.close() } catch (_: Exception) {}
        }
    }

    /**
     * 立即关闭连接。
     */
    public func close(): Unit {
        stateMu.lock()
        state = H3ConnectionState.H3_STATE_CLOSED
        stateMu.unlock()
        try {
            quicConn.closeWithError(QuicErrorCode.QUIC_NO_ERROR, "HTTP/3 连接关闭")
        } catch (_: Exception) {
            try { quicConn.close() } catch (_: Exception) {}
        }
    }

    /**
     * 设置 0-RTT 数据传输（RFC 9000 §7.4.1 / RFC 9114 §7.2.4）。
     * 在连接恢复场景中，尝试使用之前缓存的 SETTINGS 发送 0-RTT 数据。
     * 返回 true 表示 0-RTT 已启用，可以在握手完成前发送请求。
     */
    public func setupZeroRtt(): Bool {
        if (quicConn.canSendEarlyData()) {
            let priorSettings = match (zeroRttPriorSettings) {
                case Some(s) => s
                case None =>
                    HashMap<UInt16, UInt64>()
            }
            // 若存在先前的 SETTINGS，提前注入以支持 0-RTT 请求编码
            for ((id, val) in priorSettings) {
                peerSettings[id] = val
            }
            settingsExchanged = true
            return true
        }
        false
    }

    /**
     * 连接是否仍处于活动状态。
     */
    public func isConnected(): Bool {
        stateMu.lock()
        let st = state
        stateMu.unlock()
        st == H3ConnectionState.H3_STATE_CONNECTED ||
        st == H3ConnectionState.H3_STATE_GOAWAY_SENT ||
        st == H3ConnectionState.H3_STATE_GOAWAY_RECV
    }

    /**
     * 获取连接状态。
     */
    public func getState(): H3ConnectionState {
        stateMu.lock()
        let st = state
        stateMu.unlock()
        st
    }

    /**
     * 获取最后错误。
     */
    public func getLastError(): ?String {
        lastError
    }

    /**
     * 处理 QUIC 连接上到达的流。
     * 返回 false 表示连接已关闭。
     */
    public func processNextStream(): Bool {
        try {
            // 先尝试接受双向流（请求流）
            let bidirStream = quicConn.acceptStream()
            match (bidirStream) {
                case Some(s) =>
                    spawn { handleBidirectionalStream(s) }
                    return true
                case None => ()
            }

            // 再尝试接受单向流（控制流或 QPACK 流）
            let unidirStream = quicConn.acceptUnidirectionalStream()
            match (unidirStream) {
                case Some(s) =>
                    spawn { handleUnidirectionalStream(s) }
                    return true
                case None => ()
            }

            // 无可用流，短暂等待
            return true
        } catch (e: Exception) {
            // 连接已关闭
            stateMu.lock()
            state = H3ConnectionState.H3_STATE_CLOSED
            stateMu.unlock()
            setError("processNextStream 错误: ${e.message}")
            return false
        }
    }

    // ======== 内部方法 ========

    /**
     * 处理双向流（HTTP 请求流）。
     */
    private func handleBidirectionalStream(stream: QuicStream): Unit {
        let streamId = stream.getStreamId()
        activeStreams[streamId] = stream
        streamStates[streamId] = StreamState.OPEN

        // 检查连接状态：GOAWAY 后拒绝新流
        let curState = getState()
        if (curState == H3ConnectionState.H3_STATE_GOAWAY_SENT ||
            curState == H3ConnectionState.H3_STATE_GOAWAY_RECV) {
            activeStreams.remove(streamId)
            streamStates.remove(streamId)
            try { stream.close() } catch (_: Exception) {}
            return
        }

        try {

        try {
            // 读取 HEADERS 帧的 QPACK 载荷
            let qpackData = readHeadersFramePayload(stream)

            // 尝试解码（支持 QPACK 阻塞，RFC 9204 §2.2.2）
            match (decoder.decodeBlocked(qpackData, streamId)) {
                case Some(reqHeaders) =>
                    let httpRequest = buildHttpRequestFromHeaders(reqHeaders)
                    httpRequest.metadata = Some(streamId)

                    // 提取 HTTP/3 Priority 信号（RFC 9218）
                    let priority = extractPriorityFromHeaders(httpRequest.headers)
                    priorityScheduler.addStream(streamId, priority: priority)

                    if (isServer) {
                        // 服务器端：将请求加入队列
                        requestMu.lock()
                        incomingRequests.add(httpRequest)
                        requestMu.unlock()

                        // 如果有处理器，自动处理
                        match (requestHandler) {
                            case Some(handler) =>
                                let response = handler(httpRequest)
                                sendResponse(streamId, response)
                                priorityScheduler.removeStream(streamId)
                            case None => ()
                        }
                    } else {
                        // 客户端：读取响应
                        let response = tryReadResponseFromStream(streamId, stream)
                        if (response) { () }
                    }
                    // 发送 QPACK Header Ack（RFC 9204 §4.4.1）
                    sendQpackHeaderAck(streamId)
                case None =>
                    // QPACK 阻塞：存储流引用，等待编码器流数据解除阻塞
                    qpBlockedStreams[streamId] = stream
            }
        } catch (e: Exception) {
            setError("处理双向流 ${streamId} 失败: ${e.message}")
            streamStates[streamId] = StreamState.CLOSED
            // 流异常结束时发送 QPACK Stream Cancellation（RFC 9204 §4.4.3）
            sendQpackStreamCancellation(streamId)
            }
        } catch (e: Exception) {
            setError("处理双向流 ${streamId} 失败: ${e.message}")
            streamStates[streamId] = StreamState.CLOSED
            activeStreams.remove(streamId)
            // 流异常结束时发送 QPACK Stream Cancellation
            sendQpackStreamCancellation(streamId)
        }
    }

    /**
     * 处理单向流（控制流或 QPACK 流）。
     */
    private func handleUnidirectionalStream(stream: QuicStream): Unit {
        try {
            // 读取流类型首字节
            let typeBuf = Array<UInt8>(1, repeat: 0)
            let n = stream.read(typeBuf)
            if (n <= 0) { return }

            let streamType = typeBuf[0] & H3_STREAM_TYPE_MASK
            match (streamType) {
                case 0x00 => // 控制流
                    peerControlStream = Some(stream)
                    handleControlStream(stream)
                case 0x01 => // 推送流
                    handlePushStream(stream)
                case 0x02 => // QPACK 编码器流
                    peerEncoderStream = Some(stream)
                    handleEncoderStream(stream)
                case 0x03 => // QPACK 解码器流
                    peerDecoderStream = Some(stream)
                    handleDecoderStream(stream)
                case _ => // 未知类型，忽略
                    ()
            }
        } catch (e: Exception) {
            setError("处理单向流失败: ${e.message}")
        }
    }

    /**
     * 处理控制流上的帧。
     */
    private func handleControlStream(stream: QuicStream): Unit {
        try {
            while (true) {
                let frameBytes = readFrameBytes(stream)
                if (frameBytes.size == 0) { break }
                let (header, headerLen) = decodeH3FrameHeader(frameBytes)
                let payload = frameBytes[headerLen..headerLen + header.payloadLength]
                processControlFrame(header, payload)
            }
        } catch (_: Exception) {}
    }

    /**
     * 处理控制帧。
     */
    private func processControlFrame(header: Http3FrameHeader, payload: Array<UInt8>): Unit {
        match (header.frameType) {
            case Http3FrameType.SETTINGS =>
                decodePeerSettings(payload)
                // 客户端：收到服务端 SETTINGS 后发送 MAX_PUSH_ID （RFC 9114 §7.2.5）
                if (!isServer && config.maxPushId > 0) {
                    sendMaxPushId(UInt64(config.maxPushId))
                }
            case Http3FrameType.GOAWAY =>
                handleGoaway(payload)
            case Http3FrameType.MAX_PUSH_ID =>
                handleMaxPushId(payload)
            case Http3FrameType.CANCEL_PUSH =>
                handleCancelPush(payload)
            case _ => () // 忽略未知帧
        }
    }

    /**
     * 处理 GOAWAY 帧。
     */
    private func handleGoaway(payload: Array<UInt8>): Unit {
        if (payload.size > 0) {
            let (lastStreamId, _) = decodeQuicVarint(payload, 0)
            goawayLastStreamId = lastStreamId
            goawayReceived = true
            stateMu.lock()
            if (state == H3ConnectionState.H3_STATE_CONNECTED) {
                state = H3ConnectionState.H3_STATE_GOAWAY_RECV
            }
            stateMu.unlock()
        }
    }

    /**
     * 处理 MAX_PUSH_ID 帧。
     */
    /**

     * 处理 MAX_PUSH_ID 帧。

     */

    private func handleMaxPushId(payload: Array<UInt8>): Unit {

        if (payload.size > 0) {

            let (pushId, _) = decodeQuicVarint(payload, 0)

            config.maxPushId = Int64(pushId)

        }

    }



    /**

     * 处理 CANCEL_PUSH 帧。

     */

    private func handleCancelPush(payload: Array<UInt8>): Unit {

        if (payload.size > 0) {

            let (pushId, _) = decodeQuicVarint(payload, 0)

            pushMu.lock()

            match (pendingPushes.get(pushId)) {

                case Some(pending) =>

                    pending.cancelled = true

                    pending.completed = true

                    match (pushStreamMap.get(pushId)) {

                        case Some(streamId) =>

                            match (activeStreams.get(streamId)) {

                                case Some(s) => try { s.close() } catch (_: Exception) {}

                                case None => ()

                            }

                            activeStreams.remove(streamId)

                            pushStreamMap.remove(pushId)

                        case None => ()

                    }

                    pending.response = None

                case None => ()

            }

            pushMu.unlock()

        }

    }



    /**

     * 处理推送流（服务端推送）。

     * 推送流格式：流类型(0x01) + 推送ID(varint) + 响应 HEADERS + DATA

     */

    private func handlePushStream(stream: QuicStream): Unit {

        try {

            let buf = Array<UInt8>(65536, repeat: 0)

            var offset: Int64 = 0

            while (offset < 8) {

                let n = stream.read(buf[offset..])

                if (n <= 0) { return }; offset += n

                var idLen: Int64 = 0; var decodedId: UInt64 = 0; var idOk: Bool = false

                try { (decodedId, idLen) = decodeQuicVarint(buf[0..offset], 0)

                    if (idLen <= offset && idLen > 0) { idOk = true } } catch (_: Exception) {}

                if (idOk) {

                    let pushId = decodedId

                    while (true) { let n2 = stream.read(buf[offset..]); if (n2 <= 0) { break }; offset += n2 }

                    let frameStart = idLen

                    if (frameStart >= offset) { return }

                    let data = buf[0..offset]

                    let (typeVal, typeLen) = decodeQuicVarint(data[frameStart..offset], 0)

                    if (UInt8(typeVal) == Http3FrameType.HEADERS.toUInt8() || UInt8(typeVal) == 0x01u8) {

                        let afterType = data[(frameStart + typeLen)..offset]

                        let (lenVal, lenLen) = decodeQuicVarint(afterType, 0)

                        let payloadStart = frameStart + typeLen + lenLen

                        let qpackEnd = payloadStart + Int64(lenVal)

                        if (qpackEnd > offset) { return }

                        let respHeaders = decoder.decode(data[payloadStart..qpackEnd])

                        let response = buildHttpResponseFromHeaders(respHeaders)

                        if (qpackEnd < offset) { response.body.write(data[qpackEnd..offset]) }

                        pushMu.lock()

                        match (pendingPushes.get(pushId)) {

                            case Some(pending) =>

                                pending.response = Some(response)

                                pending.completed = true

                                completedPushesList.add((pushId, response))

                            case None =>

                                match (pushResponseHandler) {

                                    case Some(handler) => pushMu.unlock(); handler(pushId, response); return

                                    case None => ()

                                }

                                let np = PendingPush(pushId)

                                np.response = Some(response); np.completed = true

                                pendingPushes[pushId] = np

                        }

                        pushMu.unlock()

                    }

                    return

                }

            }

        } catch (_: Exception) {}

    }


    /**
     * 处理 QPACK 编码器流。
     */
    private func handleEncoderStream(stream: QuicStream): Unit {
        try {
            let buf = Array<UInt8>(4096, repeat: 0)
            while (true) {
                let n = stream.read(buf)
                if (n <= 0) { break }
                decoder.processEncoderStream(buf[0..n])
                // 处理编码器流数据后解除阻塞流并发送 QPACK 确认
                processUnblockedQpackStreams()
                sendQpackInsertCountIncrement()
            }
        } catch (_: Exception) {}
    }

    /**
     * 处理 QPACK 解码器流。
     */
    private func handleDecoderStream(stream: QuicStream): Unit {
        try {
            let buf = Array<UInt8>(4096, repeat: 0)
            while (true) {
                let n = stream.read(buf)
                if (n <= 0) { break }
                encoder.processDecoderInstruction(buf[0..n])
            }
        } catch (_: Exception) {}
    }

    /**
     * 从 QUIC 流中读取一个完整的 HTTP/3 帧数据。
     */
    private func readFrameBytes(stream: QuicStream): Array<UInt8> {
        // 先读取帧头（至少 2 字节）
        let headerBytes = Array<UInt8>(1024, repeat: 0)
        var offset: Int64 = 0
        // 读取至少 2 字节以解析最小帧头
        while (offset < 2) {
            let n = stream.read(headerBytes[offset..])
            if (n <= 0) { return [] }
            offset += n
        }
        // 解析帧类型和长度
        let (typeVal, typeLen) = decodeQuicVarint(headerBytes[0..offset], 0)
        if (typeLen > offset) { return [] }
        // 继续读取长度字段
        while (true) {
            if (offset > headerBytes.size) { return [] }
            let slice = headerBytes[typeLen..offset]
            var lenVal: UInt64 = 0
            var lenLen: Int64 = 0
            var decodedLen: Bool = true
            try {
                (lenVal, lenLen) = decodeQuicVarint(slice, 0)
            } catch (_: Exception) {
                decodedLen = false
            }
            if (!decodedLen) {
                // 需要更多数据
                let n = stream.read(headerBytes[offset..])
                if (n <= 0) { return [] }
                offset += n
                continue
            }
            let frameHeaderLen = typeLen + lenLen
            let totalFrameLen = frameHeaderLen + Int64(lenVal)
            // 读取完整帧
            while (offset < totalFrameLen) {
                let n = stream.read(headerBytes[offset..])
                if (n <= 0) { return [] }
                offset += n
            }
            return headerBytes[0..totalFrameLen]
        }
        return []
    }

    /**
     * 从 QUIC 流中读取请求头。
     * 返回解码后的 HttpHeaders。
     */
    private func readRequestHeaders(stream: QuicStream): HttpHeaders {
        let bufSize: Int64 = 65536
        let buf = Array<UInt8>(bufSize, repeat: 0)
        var offset: Int64 = 0

        while (offset < bufSize) {
            let n = stream.read(buf[offset..])
            if (n <= 0) { throw ProtocolException("流意外关闭") }

            // 检查是否读到完整帧头
            if (offset + n >= 2) {
                let slice = buf[0..offset + n]
                let (typeVal, typeLen) = decodeQuicVarint(slice, 0)
                // 检查是否为 HEADERS 帧
                if (UInt8(typeVal) == Http3FrameType.HEADERS.toUInt8() || UInt8(typeVal) == 0x01u8) {
                    let afterType = slice[typeLen..]
                    let (lenVal, lenLen) = decodeQuicVarint(afterType, 0)
                    let totalHeaderLen = typeLen + lenLen + Int64(lenVal)
                    if (offset + n >= totalHeaderLen) {
                        let payloadStart = typeLen + lenLen
                        let qpackData = slice[payloadStart..totalHeaderLen]
                        return decoder.decode(qpackData)
                    }
                }
            }
            offset += n
        }
        throw ProtocolException("请求头过大")
    }

    /**
     * 尝试从流中读取响应数据。
     * 返回 true 表示流仍活动，false 表示已关闭或完成。
     */
    private func tryReadResponseFromStream(streamId: UInt64, stream: QuicStream): Bool {
        try {
            let buf = Array<UInt8>(65536, repeat: 0)
            let n = stream.read(buf)
            if (n <= 0) {
                // 流关闭但没有完整响应 — 可能是错误
                pendingMu.lock()
                match (pendingResponses.get(streamId)) {
                    case Some(p) =>
                        p.completed = true
                        p.error = Some("流提前关闭")
                    case None => ()
                }
                pendingMu.unlock()
                return false
            }
            // 解析 HEADERS 帧
            let data = buf[0..n]
            let (typeVal, typeLen) = decodeQuicVarint(data, 0)
            if (UInt8(typeVal) == Http3FrameType.HEADERS.toUInt8() || UInt8(typeVal) == 0x01u8) {
                let afterType = data[typeLen..]
                let (lenVal, lenLen) = decodeQuicVarint(afterType, 0)
                let payloadStart = typeLen + lenLen
                let qpackData = data[payloadStart..payloadStart + Int64(lenVal)]
                let respHeaders = decoder.decode(qpackData)
                let response = buildHttpResponseFromHeaders(respHeaders)
                // 读取剩余帧（DATA + 可选的尾部 HEADERS）
                let bodyBytes = readResponseFrames(stream, data, Int64(lenVal) + payloadStart, response)
                response.body.write(bodyBytes)
                pendingMu.lock()
                match (pendingResponses.get(streamId)) {
                    case Some(p) =>
                        p.response = Some(response)
                        p.completed = true
                    case None => ()
                }
                pendingMu.unlock()
            }
            return true
        } catch (e: Exception) {
            pendingMu.lock()
            match (pendingResponses.get(streamId)) {
                case Some(p) =>
                    p.completed = true
                    p.error = Some("读取响应失败: ${e.message}")
                case None => ()
            }
            pendingMu.unlock()
            return false
        }
    }

    /**
     * 从流中读取 DATA 帧，返回所有 body 数据。
     */
    private func readDataFrames(stream: QuicStream, firstBuf: Array<UInt8>, consumedLen: Int64): Array<UInt8> {
        let result = ArrayList<UInt8>()
        // 检查第一个缓冲区的剩余部分
        if (firstBuf.size > consumedLen) {
            for (i in consumedLen..firstBuf.size) {
                result.add(firstBuf[i])
            }
        }
        // 继续读取后续帧
        let buf = Array<UInt8>(4096, repeat: 0)
        while (true) {
            let n = stream.read(buf)
            if (n <= 0) { break }
            for (i in 0..n) { result.add(buf[i]) }
        }
        result.toArray()
    }

    /**
     * ä» H3 æµä¸­è¯»åååºå©ä½å¸§ï¼DATA + å¯éçå°¾é¨ HEADERSï¼
     * æ¯æå¸§è¾¹çè§£æï¼å°åç»­ HEADERS å¸§è§£ç ä¸º Trailer å¹¶å­å¨å° response ä¸­ã
     */
    private func readResponseFrames(stream: QuicStream, firstBuf: Array<UInt8>, startOffset: Int64, response: HttpResponse): Array<UInt8> {
        let bodyData = ArrayList<UInt8>()
        var offset = startOffset

        // è§£æç¬¬ä¸ä¸ªç¼å²åºçå©ä½å¸§
        while (offset < firstBuf.size) {
            if (offset + 2 > firstBuf.size) { break }
            let (typeVal, typeLen) = decodeQuicVarint(firstBuf, offset)
            let afterType = offset + typeLen
            if (afterType > firstBuf.size) { break }
            let (lenVal, lenLen) = decodeQuicVarint(firstBuf, afterType)
            let payloadStart = afterType + lenLen
            let payloadEnd = payloadStart + Int64(lenVal)
            if (payloadEnd > firstBuf.size) { break }

            let frameType = UInt8(typeVal)
            let payload = firstBuf[payloadStart..payloadEnd]
            if (frameType == Http3FrameType.DATA.toUInt8()) {
                for (i in 0..payload.size) { bodyData.add(payload[i]) }
            } else if (frameType == Http3FrameType.HEADERS.toUInt8()) {
                let trailerHeaders = decoder.decode(payload)
                for ((name, value) in trailerHeaders.entries()) {
                    response.trailers.add(name, value)
                }
            }
            offset = payloadEnd
        }

        // ç»§ç»­ä»æµä¸­è¯»åå©ä½å¸§
        let readBuf = Array<UInt8>(4096, repeat: 0)
        while (true) {
            let n = stream.read(readBuf)
            if (n <= 0) { break }
            var pos: Int64 = 0
            while (pos < n) {
                if (pos + 2 > n) { break }
                let (typeVal, typeLen) = decodeQuicVarint(readBuf, pos)
                let afterType = pos + typeLen
                if (afterType > n) { break }
                let (lenVal, lenLen) = decodeQuicVarint(readBuf, afterType)
                let payloadStart = afterType + lenLen
                let payloadEnd = payloadStart + Int64(lenVal)
                if (payloadEnd > n) { break }

                let frameType = UInt8(typeVal)
                let payload = readBuf[payloadStart..payloadEnd]
                if (frameType == Http3FrameType.DATA.toUInt8()) {
                    for (i in 0..payload.size) { bodyData.add(payload[i]) }
                } else if (frameType == Http3FrameType.HEADERS.toUInt8()) {
                    let trailerHeaders = decoder.decode(payload)
                    for ((name, value) in trailerHeaders.entries()) {
                        response.trailers.add(name, value)
                    }
                }
                pos = payloadEnd
            }
        }

        bodyData.toArray()
    }

    /**
     * 构建 HTTP/3 请求头（包含伪头部）。
     */
    private func buildRequestHeaders(request: HttpRequest): HttpHeaders {
        let headers = HttpHeaders()
        headers.set(":method", request.method.toString())
        headers.set(":scheme", extractScheme(request))
        headers.set(":authority", extractAuthority(request))
        headers.set(":path", extractPath(request))
        // 复制非伪头部
        for ((name, value) in request.headers.entries()) {
            if (!name.startsWith(":")) {
                headers.add(name, value)
            }
        }
        headers
    }

    /**
     * 从 HTTP/3 头部构建 HttpResponse。
     */
    private func buildHttpResponseFromHeaders(headers: HttpHeaders): HttpResponse {
        var statusCode: UInt16 = 200
        match (headers.get(":status")) {
            case Some(s) =>
                try {
                    statusCode = UInt16(Int64.parse(s))
                } catch (_: Exception) {}
            case None => ()
        }
        // 移除伪头部
        let cleanHeaders = HttpHeaders()
        for ((name, value) in headers.entries()) {
            if (!name.startsWith(":")) {
                cleanHeaders.add(name, value)
            }
        }
        HttpResponse(
            status: HttpStatus(statusCode),
            headers: cleanHeaders
        )
    }

    /**
     * 从 HTTP/3 头部构建 HttpRequest。
     */
    private func buildHttpRequestFromHeaders(headers: HttpHeaders): HttpRequest {
        let method = match (headers.get(":method")) {
            case Some(m) => HttpMethod.GET
            case None => HttpMethod.GET
        }
        let path = match (headers.get(":path")) {
            case Some(p) => p
            case None => "/"
        }
        let cleanHeaders = HttpHeaders()
        for ((name, value) in headers.entries()) {
            if (!name.startsWith(":")) {
                cleanHeaders.add(name, value)
            }
        }
        HttpRequest(
            method: method,
            url: path,
            headers: cleanHeaders
        )
    }

    /**
     * 解析对端 SETTINGS。
     */
    private func decodePeerSettings(payload: Array<UInt8>): Unit {
        let settings = ArrayList<(Http3SettingsId, UInt64)>()
        var offset: Int64 = 0
        while (offset < payload.size) {
            let (idVal, idLen) = decodeQuicVarint(payload, offset)
            offset += idLen
            if (offset >= payload.size) { break }
            let (val, valLen) = decodeQuicVarint(payload, offset)
            offset += valLen
            peerSettings[UInt16(idVal)] = val
            match (Http3SettingsId.fromUInt16(UInt16(idVal))) {
                case Some(sid) => settings.add((sid, val))
                case None => ()
            }
        }
        match (zeroRttPriorSettings) {
            case Some(prior) =>
                if (!validateZeroRttSettings(prior)) {
                    closeWithHttp3Error(Http3ErrorCode.H3_SETTINGS_ERROR, "0-RTT settings validation failed")
                    return
                }
            case None => ()
        }
        settingsExchanged = true
        stateMu.lock()
        if (state == H3ConnectionState.H3_STATE_INITIAL) {
            state = H3ConnectionState.H3_STATE_CONNECTED
        }
        stateMu.unlock()
    }

    /**
     * 构建本地 SETTINGS 列表。
     */
    private func buildLocalSettings(): Array<(Http3SettingsId, UInt64)> {
        [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, UInt64(config.qpackMaxTableCapacity)),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, UInt64(config.maxFieldSectionSize)),
            (Http3SettingsId.SETTINGS_QPACK_BLOCKED_STREAMS, UInt64(config.qpackBlockedStreams)),
            (Http3SettingsId.ENABLE_CONNECT_PROTOCOL, if (config.enableConnectProtocol) { 1u64 } else { 0u64 }),
            (Http3SettingsId.H3_DATAGRAM, if (config.enableH3Datagram) { 1u64 } else { 0u64 }),
        ]
    }

    /**
     * 构建 GREASE SETTINGS 并与主要设置合并（RFC 9114 §9.6）。
      * 随机选取一个 GREASE 设置标识符并赋予随机值，防止协议僵化。
      */
    private func buildGreaseSettings(): Array<(Http3SettingsId, UInt64)> {
        let now = DateTime.now()
        let nanos = Int64(now.nanosecond)
        let idx = (nanos ^ 2654435761) % GREASE_SETTINGS_IDS.size
        let greaseId = GREASE_SETTINGS_IDS[if (idx < 0) { 0 } else { idx }]
        let randomVal = UInt64((nanos * 2654435761 + 12345) % 65536)
        match (Http3SettingsId.fromUInt16(greaseId)) {
            case Some(id) => [(id, if (randomVal == 0) { 1u64 } else { randomVal })]
            case None => []
        }
    }

    /**
     * 构建 GREASE 帧（RFC 9114 §9.6）。
     * 随机选择帧类型和载荷，用于抗协议僵化。
     */
    private func buildGreaseFrame(): Array<UInt8> {
        let now = DateTime.now()
        let idx = Int64(now.second * 2654435761 + Int64(now.nanosecond)) % GREASE_FRAME_TYPES.size
        let frameType = GREASE_FRAME_TYPES[if (idx < 0) { 0 } else { idx }]
        let frameTypeBytes = encodeQuicVarint(frameType)
        let payloadLen = (Int64(now.nanosecond) % 64) + 1
        let payload = Array<UInt8>(payloadLen, repeat: 0)
        for (i in 0..payloadLen) {
            payload[i] = UInt8(Int64(now.nanosecond * (i + 1) * 7) % 256)
        }
        let lenBytes = encodeQuicVarint(UInt64(payloadLen))
        let total = frameTypeBytes.size + lenBytes.size + payloadLen
        let result = Array<UInt8>(total, repeat: 0)
        var offset: Int64 = 0
        for (b in frameTypeBytes) { result[offset] = b; offset += 1 }
        for (b in lenBytes) { result[offset] = b; offset += 1 }
        for (i in 0..payloadLen) { result[offset] = payload[i]; offset += 1 }
        result
    }

    /**
     * 主动发送 GREASE 帧（RFC 9114 §9.6）。
     * 在空闲连接上偶尔发送以抗协议僵化。
     */
    public func sendGreaseFrame(): Unit {
        match (controlStream) {
            case Some(s) =>
                let frame = buildGreaseFrame()
                try { s.write(frame); s.flush(); greaseFrameCounter += 1 } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 偶尔创建 GREASE 流类型（RFC 9114 §9.6）。
     * 每 10 个单向流机会发送一条 GREASE 流类型。
     */
    private func maybeSendGreaseStream(): Unit {
        greaseStreamCounter += 1
        if (greaseStreamCounter % 10 == 0) {
            let now = DateTime.now()
            let idx = Int64(now.second * 2654435761 + Int64(now.nanosecond)) % GREASE_STREAM_TYPES.size
            let streamType = GREASE_STREAM_TYPES[if (idx < 0) { 0 } else { idx }]
            let greaseStream = quicConn.openUnidirectionalStream()
            match (greaseStream) {
                case Some(s) =>
                    try {
                        s.write([streamType])
                        let frame = buildGreaseFrame()
                        s.write(frame)
                        s.flush()
                        s.closeWrite()
                    } catch (_: Exception) {}
                case None => ()
            }
        }
    }

    /**
     * 验证 0-RTT 设置（RFC 9114 §7.2.4.2）。
     */
    private func validateZeroRttSettings(priorSettings: HashMap<UInt16, UInt64>): Bool {
        match (peerSettings.get(0x01u16)) {
            case Some(currentCap) =>
                match (priorSettings.get(0x01u16)) {
                    case Some(priorCap) =>
                        if (currentCap < priorCap) { setError("0-RTT: QPACK_MAX_TABLE_CAPACITY decreased"); return false }
                    case None => ()
                }
            case None => ()
        }
        match (peerSettings.get(0x06u16)) {
            case Some(currentSize) =>
                match (priorSettings.get(0x06u16)) {
                    case Some(priorSize) =>
                        if (currentSize < priorSize) { setError("0-RTT: MAX_FIELD_SECTION_SIZE decreased"); return false }
                    case None => ()
                }
            case None => ()
        }
        true
    }

    /**
     * 提取 scheme（从请求 URL 或默认值）。
     */
    private func extractScheme(request: HttpRequest): String {
        let url = request.url
        if (url.startsWith("https://")) { return "https" }
        if (url.startsWith("http://")) { return "http" }
        match (request.headers.get(":scheme")) {
            case Some(s) => s
            case None => "https"
        }
    }

    /**
     * 提取 authority（host:port）。
     */
    private func extractAuthority(request: HttpRequest): String {
        match (request.headers.get("host")) {
            case Some(h) => h
            case None => "localhost"
        }
    }

    /**
     * 提取路径（含查询参数）。
     */
    private func extractPath(request: HttpRequest): String {
        // 如果是完整 URL，提取路径部分
        let url = request.url
        if (url.startsWith("http://") || url.startsWith("https://")) {
            let slashIdx = url.indexOf("/", schemeEndIndex(url))
            match (slashIdx) {
                case Some(idx) => url[idx..]
                case None => "/"
            }
        } else {
            url
        }
    }

    /**
     * 找到 scheme 后的索引（"https://" 后下一个字符的位置）。
     */
    /**

     * 构建推送响应头（服务端推送响应）。

     */

    private func buildPushResponseHeaders(response: HttpResponse): HttpHeaders {

        let headers = HttpHeaders()

        headers.set(":status", response.status.code.toString())

        for ((name, value) in response.headers.entries()) {

            if (!name.startsWith(":")) { headers.add(name, value) }

        }

        headers

    }



    private func schemeEndIndex(url: String): Int64 {
        if (url.startsWith("https://")) { 8 }
        else if (url.startsWith("http://")) { 7 }
        else { 0 }
    }

    /**
     * 记录错误。
     */
    private func setError(msg: String): Unit {
        lastError = Some(msg)
}

    /**
     * 使用 HTTP/3 应用层错误码关闭连接。
     */
    private func closeWithHttp3Error(errorCode: Http3ErrorCode, msg: String): Unit {
        lastError = Some(msg)
        stateMu.lock()
        state = H3ConnectionState.H3_STATE_CLOSED
        stateMu.unlock()
        try {
            quicConn.closeWithError(QuicErrorCode.QUIC_APPLICATION_ERROR, msg)
        } catch (_: Exception) {}
    }

    /**
     * 处理 QPACK 编码器流到达后解除阻塞的流。
     * RFC 9204 §2.2.2：当新的动态表条目到达时，尝试解码之前被阻塞的流。
     */
    private func processUnblockedQpackStreams(): Unit {
        let unblocked = decoder.tryUnblockAll()
        let keys = ArrayList<UInt64>()
        for (key in unblocked.keys()) {
            keys.add(key)
        }
        for (sid in keys) {
            let headers = unblocked.get(sid)
            match (headers) {
                case Some(h) =>
                    match (qpBlockedStreams.get(sid)) {
                        case Some(s) =>
                            qpBlockedStreams.remove(sid)
                            let httpRequest = buildHttpRequestFromHeaders(h)
                            httpRequest.metadata = Some(sid)
                            // 解除阻塞后发送 QPACK Header Ack（RFC 9204 §4.4.1）
                            sendQpackHeaderAck(sid)
                            if (isServer) {
                                requestMu.lock()
                                incomingRequests.add(httpRequest)
                                requestMu.unlock()
                                match (requestHandler) {
                                    case Some(handler) =>
                                        let response = handler(httpRequest)
                                        sendResponse(sid, response)
                                    case None => ()
                                }
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }

    /**
     * 发送 QPACK Header Ack（RFC 9204 §4.4.1）。
     * 成功解码一条流的 HEADERS 帧后，通过解码器流通知对端。
     */
    private func sendQpackHeaderAck(streamId: UInt64): Unit {
        match (decoderStream) {
            case Some(s) =>
                try {
                    s.write(buildHeaderAck(streamId))
                    s.flush()
                } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 发送 QPACK Insert Count Increment（RFC 9204 §4.4.2）。
     * 定期发送，通知对端解码器已处理到指定插入计数。
     */
    private func sendQpackInsertCountIncrement(): Unit {
        match (decoderStream) {
            case Some(s) =>
                try {
                    // 以增量 1 发送，默认每次处理编码器流数据后确认
                    s.write(buildInsertCountIncrementFrame(1u64))
                    s.flush()
                } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 发送 QPACK Stream Cancellation（RFC 9204 §4.4.3）。
     * 流异常终止或重置时通知对端，使编码器可以释放动态表引用。
     */
    private func sendQpackStreamCancellation(streamId: UInt64): Unit {
        match (decoderStream) {
            case Some(s) =>
                try {
                    s.write(buildStreamCancellationFrame(streamId))
                    s.flush()
                } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 从 QUIC 流中读取 HEADERS 帧的原始 QPACK 载荷。
     * 与 readRequestHeaders 类似，但不做 QPACK 解码。
     */
    private func readHeadersFramePayload(stream: QuicStream): Array<UInt8> {
        let bufSize: Int64 = 65536
        let buf = Array<UInt8>(bufSize, repeat: 0)
        var offset: Int64 = 0

        while (offset < bufSize) {
            let n = stream.read(buf[offset..])
            if (n <= 0) { throw ProtocolException("流意外关闭") }

            if (offset + n >= 2) {
                let slice = buf[0..offset + n]
                let (typeVal, typeLen) = decodeQuicVarint(slice, 0)
                if (UInt8(typeVal) == Http3FrameType.HEADERS.toUInt8() || UInt8(typeVal) == 0x01u8) {
                    let afterType = slice[typeLen..]
                    let (lenVal, lenLen) = decodeQuicVarint(afterType, 0)
                    let totalHeaderLen = typeLen + lenLen + Int64(lenVal)
                    if (offset + n >= totalHeaderLen) {
                        let payloadStart = typeLen + lenLen
                        return slice[payloadStart..totalHeaderLen]
                    }
                }
            }
        }
        throw ProtocolException("请求头过大")
    }


}