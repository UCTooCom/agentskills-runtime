package http_lib.http2

import std.collection.{ArrayList, HashMap}
import std.sync.{AtomicBool, Mutex}
import http_lib.buffer.ByteBuffer
import http_lib.utils.{ParsedUrl, arraysEqual}
import std.time.DateTime
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion, ProtocolException}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.connection.Connection

/**
 * HTTP/2 帧编解码（RFC 9113）。
 */
public class Http2Connection {
    // 传输层
    private var conn: Connection
    private var isServer: Bool

    // HPACK 编码
    private var encoder: HPACK
    private var decoder: HPACK

    // 写入互斥锁 — 保护帧序列化和 HPACK 编码器
    // 多个协程可能并发调用 sendResponse()，需串行化帧写入
    private var writeMu: Mutex = Mutex()

    // 流管理
    private var multiplexer: Http2Multiplexer

    // 连接状态
    private var connected: Bool = false
    private var goawayReceived: AtomicBool = AtomicBool(false)
    private var goawaySent: AtomicBool = AtomicBool(false)
    private var lastStreamId: UInt32 = 0
    private var goawayDebugData: Array<UInt8> = []
    private var writeByteTimeout: Duration = Duration.second * 10
    private var countError: ?(String) -> Unit = None
    private var lastDataReceiveTime: DateTime = DateTime.now()
    private var pingSent: Bool = false
    private var sentPingData: Array<UInt8> = Array<UInt8>(8, repeat: 0)
    private var readIdleTimeout: Duration = Duration.second * 60
    private var pingTimeout: Duration = Duration.second * 10  // 上一次 GOAWAY 帧的调试数据
    private var lastPingTime: DateTime = DateTime.UnixEpoch
    private let minPingInterval: Duration = Duration.second * 1
    private var prefaceTimeoutDuration: Duration = Duration.second * 10
    private var unackedSettings: Int64 = 0
    private let MAX_UNACKED_SETTINGS: Int64 = 10
    private var peerSettings: HashMap<Http2SettingsId, UInt32>

    // 流量控制
    private var connSendWindow: Int64 = Int64(DEFAULT_INITIAL_WINDOW_SIZE)
    private var connRecvWindow: Int64 = Int64(DEFAULT_INITIAL_WINDOW_SIZE)
    private var peerMaxFrameSize: Int64 = Int64(DEFAULT_MAX_FRAME_SIZE)
    private let sendWindowLow: Int64 = Int64(DEFAULT_INITIAL_WINDOW_SIZE) / 2
    private let sendWindowMax: Int64 = Int64(DEFAULT_INITIAL_WINDOW_SIZE)
    // 跟踪对端设置的当前初始窗口大小，用于增量计算（RFC 9113 §6.9.2）
    private var currentInitialWindowSize: Int64 = Int64(DEFAULT_INITIAL_WINDOW_SIZE)

    // 基于优先级的流排序写入调度器
    private var writeSched: PriorityWriteScheduler

    // SETTINGS 超时处理器 (RFC 9113 §6.5.3)
    private var settingsTimeout: SettingsTimeoutHandler

    // 服务端推送处理器（客户端侧）—— 收到 PUSH_PROMISE 时调用
    public var onPushPromise: ?(HttpRequest) -> ?HttpResponse = None

    /**
     * 扩展 CONNECT 处理器回调（服务端侧，RFC 8441）。
     * 当收到 CONNECT + :protocol 请求时调用。
     * 参数为 (HttpRequest, streamId)，返回 Some(HttpResponse) 表示接受并建立隧道，
     * 返回 None 表示连接应保持标准处理路径。
     * 设置为 Some 后，服务器不会自动调用 sendResponse()，由回调自行处理。
     */
    public var onExtendedConnect: ?(HttpRequest, UInt32) -> ?HttpResponse = None

    // 等待响应的承诺流（客户端侧，按承诺流 ID 索引）
    private var promisedStreams: HashMap<UInt32, UInt32>  // 承诺流 ID → 关联流 ID

    // 缓冲区
    private var readBuffer: Array<UInt8>
    private var readBufferPos: Int64 = 0
    private var readBufferLen: Int64 = 0

    // 跟踪期待 CONTINUATION 帧的流（RFC 9113 §6.10）
    // 在未带 END_HEADERS 的 HEADERS 或 PUSH_PROMISE 之后，该流上的
    // 后续帧必须是 CONTINUATION，直到 END_HEADERS。任何其他帧类型或
    // CONTINUATION 帧之间的不同流上的帧属于 PROTOCOL_ERROR。
    private var continuationStreamId: UInt32 = 0

    // 我们通告的 SETTINGS
    private var localSettings: Array<(Http2SettingsId, UInt32)> = []
    // 对端声明的 ORIGIN 列表（RFC 8336）
    private var peerOrigins: ArrayList<String> = ArrayList<String>()
    // 对端通告的 ALTSVC 列表（RFC 7838）
    private var peerAltSvc: ArrayList<(String, Array<UInt8>)> = ArrayList<(String, Array<UInt8>)>()

    public init(conn: Connection, isServer!: Bool = false) {
        this.conn = conn
        this.isServer = isServer
        this.encoder = HPACK()
        this.decoder = HPACK()
        this.multiplexer = Http2Multiplexer(isServer: isServer)
        this.peerSettings = HashMap<Http2SettingsId, UInt32>()
        this.readBuffer = Array<UInt8>(Int64(DEFAULT_MAX_FRAME_SIZE), repeat: 0)
        this.localSettings = [
            (Http2SettingsId.ENABLE_PUSH, 0),
            (Http2SettingsId.MAX_CONCURRENT_STREAMS, 100),
            (Http2SettingsId.INITIAL_WINDOW_SIZE, UInt32(DEFAULT_INITIAL_WINDOW_SIZE)),
            (Http2SettingsId.MAX_FRAME_SIZE, DEFAULT_MAX_FRAME_SIZE),
            (Http2SettingsId.ENABLE_CONNECT_PROTOCOL, 1),
            (Http2SettingsId.NO_RFC7540_PRIORITIES, 1),  // RFC 9218 可扩展优先级
        ]
        this.writeSched = PriorityWriteScheduler()
        this.settingsTimeout = SettingsTimeoutHandler()
        this.pendingData = HashMap<UInt32, Array<UInt8>>()
        this.promisedStreams = HashMap<UInt32, UInt32>()
    }

    // ---- 连接建立 ----

    /**
     * Initialize HTTP/2 连接 on the client side.
     * 发送前言 + SETTINGS，等待服务器 SETTINGS + 可选的 SETTINGS ACK。
     */
    public func connect(): Unit {
        // 发送连接前言
        conn.write(HTTP2_CLIENT_PREFACE_BYTES)
        // 发送我们的 SETTINGS 并启动超时（RFC 9113 §6.5.3）
        sendSettings(localSettings)
        unackedSettings += 1
        conn.flush()
        settingsTimeout.start()

        // 等待服务器前言（SETTINGS 帧，可能带有 ACK）
        var settingsReceived = false
        let prefaceStartTime = DateTime.now()
        while (!settingsReceived) {
            // 检查 SETTINGS 超时
            if (settingsTimeout.isExpired()) {
                throw Http2Exception(Http2ErrorCode.SETTINGS_TIMEOUT, "SETTINGS timeout")
            }
            if (DateTime.now() - prefaceStartTime > prefaceTimeoutDuration) {
                throw Http2Exception(Http2ErrorCode.SETTINGS_TIMEOUT, "Preface timeout waiting for server SETTINGS")
            }
            let header = readFrameHeader()
            if (header.frameType == Http2FrameType.SETTINGS) {
                if ((header.flags & FLAG_ACK) != 0) {
                    // 服务器已确认我们的 SETTINGS
                    settingsTimeout.ack()
                    unackedSettings -= 1
                    continue
                }
                let payload = readFramePayload(header)
                let settings = decodeSettings(payload)
                for ((id, value) in settings) {
                    peerSettings[id] = value
                    applyPeerSetting(id, value)
                }
                // 发送 SETTINGS ACK
                conn.write(buildSettingsAckFrame())
                conn.flush()
                settingsReceived = true
            } else if (header.frameType == Http2FrameType.GOAWAY) {
                let payload = readFramePayload(header)
                handleGoaway(payload)
                throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR, "Server sent GOAWAY during preface")
            }
        }
        connected = true
    }

    /**
     * Accept HTTP/2 连接 on the server side.
     * 等待客户端前言 + SETTINGS，然后发送我们的 SETTINGS。
     *
     * @param preReadPreface 可选的预读前言字节（来自 H2C 窥探检测）。
     *   提供时跳过从线路读取前言并直接验证。
     *   这是因为服务器中的 H2C 窥探已从原始套接字读取（消费）了前言字节
     *   以检测 HTTP/1.1 与 HTTP/2。
     */
    public func accept(preReadPreface: Option<Array<UInt8> >): Unit {
        // 读取或验证客户端前言字节
        match (preReadPreface) {
            case Some(preface) =>
                // H2C 窥探检测已预读前言 —— 直接验证
                if (preface != HTTP2_CLIENT_PREFACE_BYTES) {
                    throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR, "Invalid client preface")
                }
            case None =>
                let prefaceBytes = Array<UInt8>(HTTP2_CLIENT_PREFACE_BYTES.size, repeat: 0)
                readExact(prefaceBytes, 0, prefaceBytes.size)
                if (prefaceBytes != HTTP2_CLIENT_PREFACE_BYTES) {
                    throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR, "Invalid client preface")
                }
        }
        // 发送服务器 SETTINGS 并启动超时
        sendSettings(localSettings)
        unackedSettings += 1
        conn.flush()
        settingsTimeout.start()

        // 等待客户端 SETTINGS
        var settingsReceived = false
        let prefaceStartTime = DateTime.now()
        while (!settingsReceived) {
            if (settingsTimeout.isExpired()) {
                throw Http2Exception(Http2ErrorCode.SETTINGS_TIMEOUT, "SETTINGS timeout")
            }
            if (DateTime.now() - prefaceStartTime > prefaceTimeoutDuration) {
                throw Http2Exception(Http2ErrorCode.SETTINGS_TIMEOUT, "Preface timeout waiting for client SETTINGS")
            }
            let header = readFrameHeader()
            if (header.frameType == Http2FrameType.SETTINGS && (header.flags & FLAG_ACK) == 0) {
                let payload = readFramePayload(header)
                let settings = decodeSettings(payload)
                for ((id, value) in settings) {
                    peerSettings[id] = value
                    applyPeerSetting(id, value)
                }
                settingsReceived = true
                // 发送 SETTINGS ACK
                conn.write(buildSettingsAckFrame())
                conn.flush()
            } else if (header.frameType == Http2FrameType.SETTINGS && (header.flags & FLAG_ACK) != 0) {
                // 客户端已确认我们的 SETTINGS
                settingsTimeout.ack()
                unackedSettings -= 1
            } else if (header.frameType == Http2FrameType.GOAWAY) {
                throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR, "Client sent GOAWAY during preface")
            }
        }
        connected = true
    }

    // ---- 请求/响应（客户端） ----

    /**
     * Send an HTTP 请求 over a new HTTP/2 stream。
     * 由 writeMu 保护，防止多协程并发帧写入。
     */
    public func sendRequest(request: HttpRequest): UInt32 {
        synchronized(writeMu) {
            let stream = match (multiplexer.createStream()) {
                case Some(s) => s
                case None => throw Http2Exception(Http2ErrorCode.REFUSED_STREAM, "Max concurrent streams reached")
            }
            let streamId = stream.streamId
            multiplexer.transitionState(streamId, Http2StreamState.OPEN)
            // 向写入调度器注册以实现基于优先级的排序
            writeSched.openStream(streamId, weight: 16, parent: None)

            // 构建伪头部 + 常规头部
            let h2Headers = buildH2RequestHeaders(request, streamId)

            // 通过 HPACK 编码头部
            let headerBlock = encoder.encode(h2Headers)

            // 发送 HEADERS 帧
            let headersFrame = buildHeadersFrame(streamId, headerBlock, endStream: request.body.getLimit() == 0)
            sendFrame(headersFrame)

            // 若存在主体则发送 DATA 帧
            if (request.body.getLimit() > 0) {
                let bodyData = request.bodyAsBytes()
                sendDataFrames(streamId, bodyData)
            }

            streamId
        }
    }

    /**
     * Receive an HTTP 响应 from a stream.
     */
    public func recvResponse(streamId: UInt32): HttpResponse {
        var responseHeaders: HttpHeaders = HttpHeaders()
        var bodyBuffer = ByteBuffer(capacity: 65536)
        var endStream = false
        var hasInitialHeaders: Bool = false
        var responseTrailers: HttpHeaders = HttpHeaders()
        var headerFragments = ArrayList<Array<UInt8>>()

        while (!endStream) {
            checkIdleTimeout()
            let header = readFrameHeader()
            checkContinuationOrder(header)
            match (header.frameType) {
                case Http2FrameType.HEADERS =>
                    if (header.streamId != streamId) { continue }
                    let rawPayload = readFramePayload(header)
                    let payload = stripHeadersPriorityField(header.flags, rawPayload, streamId)
                    if (hasInitialHeaders) {
                        headerFragments.add(payload)
                        let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                        endStream = (header.flags & FLAG_END_STREAM) != 0 || endStream
                        if (hasEndHeaders) {
                            let trailerHeaders = decodeAccumulatedHeaders(headerFragments)
                            mergeHeaders(responseTrailers, trailerHeaders)
                            headerFragments = ArrayList<Array<UInt8>>()
                        }
                        continue
                    }
                    headerFragments.add(payload)
                    let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                    endStream = (header.flags & FLAG_END_STREAM) != 0
                    if (hasEndHeaders) {
                        responseHeaders = decodeAccumulatedHeaders(headerFragments)
                        hasInitialHeaders = true
                        headerFragments = ArrayList<Array<UInt8>>()
                        // RFC 9218 §4：从 Priority 头字段提取优先级信号
                        match (responseHeaders.get("priority")) {
                            case Some(pv) => applyPriorityToStream(streamId, unsafe { pv.rawData() })
                            case None => ()
                        }
                    }
                case Http2FrameType.CONTINUATION =>
                    if (header.streamId != streamId) { continue }
                    let payload = readFramePayload(header)
                    if (hasInitialHeaders) {
                        headerFragments.add(payload)
                        let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                        endStream = (header.flags & FLAG_END_STREAM) != 0 || endStream
                        if (hasEndHeaders) {
                            let trailerHeaders = decodeAccumulatedHeaders(headerFragments)
                            mergeHeaders(responseTrailers, trailerHeaders)
                            headerFragments = ArrayList<Array<UInt8>>()
                        }
                        continue
                    }
                    headerFragments.add(payload)
                    let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                    endStream = (header.flags & FLAG_END_STREAM) != 0 || endStream
                    if (hasEndHeaders) {
                        responseHeaders = decodeAccumulatedHeaders(headerFragments)
                        hasInitialHeaders = true
                        headerFragments = ArrayList<Array<UInt8>>()
                        // RFC 9218 §4：从 Priority 头字段提取优先级信号
                        match (responseHeaders.get("priority")) {
                            case Some(pv) => applyPriorityToStream(streamId, unsafe { pv.rawData() })
                            case None => ()
                        }
                    }
                case Http2FrameType.DATA =>
                    let payload = readFramePayload(header)
                    if (header.streamId != streamId) { continue }
                    if (payload.size > 0) {
                        bodyBuffer.write(payload)
                    }
                    endStream = (header.flags & FLAG_END_STREAM) != 0
                    // 更新流控 — 从流窗口和连接窗口中消耗
                    multiplexer.consumeStreamRecvWindow(streamId, payload.size)
                    replenishRecvWindows(streamId, payload.size)
                case Http2FrameType.RST_STREAM =>
                    let payload = readFramePayload(header)
                    if (header.streamId != streamId) { continue }
                    let ec = decodeRstStream(payload)
                    // 根据 RFC 9113 §5.1，RST_STREAM 仅终止特定流，
                    // 而非整个连接。移除该流并返回错误。
                    multiplexer.removeStream(streamId)
                    writeSched.closeStream(streamId)
                    throw Http2Exception(ec, "Stream ${streamId} reset by peer: ${ec}")
                case Http2FrameType.GOAWAY =>
                    let payload = readFramePayload(header)
                    handleGoaway(payload)
                    endStream = true
                case Http2FrameType.PING =>
                    handlePing(header)
                case Http2FrameType.SETTINGS =>
                    handlePeerSettings(header)
                case Http2FrameType.WINDOW_UPDATE =>
                    handleWindowUpdate(header)
                case Http2FrameType.PRIORITY =>
                    handlePriority(header)
                case Http2FrameType.PUSH_PROMISE =>
                    // Handle 服务器推送 (RFC 9113 Section 8.2)
                    if (header.streamId == streamId) {
                        let payload = readFramePayload(header)
                        let (promisedId, pushRequest) = decodePushPromise(payload, header.flags)
                        promisedStreams[promisedId] = streamId
                        // 通知处理器关于推送的资源
                        match (onPushPromise) {
                            case Some(handler) =>
                                let pushResp = handler(pushRequest)
                                match (pushResp) {
                                    case Some(_) => ()  // 处理器已接受推送
                                    case None =>
                    // 处理器拒绝了推送 —— 取消它 (RFC 9113 §8.2.2)
                                        cancelPush(promisedId)
                                }
                            case None =>
                                // 无处理器 —— 取消推送 (RFC 9113 §8.2.2)
                                cancelPush(promisedId)
                        }
                    }
                    // PUSH_PROMISE 不会结束主响应流
                case Http2FrameType.ORIGIN =>
                    handleOrigin(header)
                case Http2FrameType.ALTSVC =>
                    handleAltSvc(header)
                case Http2FrameType.PRIORITY_UPDATE =>
                    handlePriorityUpdate(header)

                case _ =>
                    let _ = readFramePayload(header)  // 跳过未知帧
            }
        }

        // 从伪头部提取状态
        let statusStr = match (responseHeaders.get(":status")) {
            case Some(s) => s
            case None => "200"
        }
        let status = parseStatus(statusStr)
        responseHeaders.remove(":status")

        // 构建响应版本
        let resp = HttpResponse(status: status, headers: responseHeaders, body: bodyBuffer)
        resp.version = HttpVersion.HTTP_2_0
        if (!responseTrailers.isEmpty()) {
            resp.trailers = responseTrailers
        }
        resp
    }

    // ---- 请求处理（服务器） ----

    /**
     * Read the next incoming HTTP 请求 from any stream.
     * Handles HEADERS + CONTINUATION 帧 sequences.
     */
    public func recvRequest(): (UInt32, HttpRequest) {
        var headerFragments = ArrayList<Array<UInt8>>()
        var pendingStreamId: UInt32 = 0

        while (true) {
            let header = readFrameHeader()
            checkContinuationOrder(header)
            match (header.frameType) {
                case Http2FrameType.HEADERS =>
                    let rawPayload = readFramePayload(header)
                    let sid = header.streamId
                    pendingStreamId = sid
                    match (multiplexer.ensureStream(sid)) {
                        case Some(_) => ()
                        case None =>
                            let rstFrame = buildRstStreamFrame(sid, Http2ErrorCode.REFUSED_STREAM)
                            sendFrame(rstFrame)
                            continue
                    }
                    multiplexer.transitionState(sid, Http2StreamState.OPEN)
                    let payload = stripHeadersPriorityField(header.flags, rawPayload, sid)
                    headerFragments.add(payload)
                    let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                    let hasEndStream = (header.flags & FLAG_END_STREAM) != 0

                    if (hasEndHeaders) {
                        let (request, _) = buildRequestFromHeaders(headerFragments, sid)
                        headerFragments = ArrayList<Array<UInt8>>()
                        // RFC 9218 §4：从 Priority 头字段提取优先级信号
                        match (request.headers.get("priority")) {
                            case Some(pv) => applyPriorityToStream(sid, unsafe { pv.rawData() })
                            case None => ()
                        }
                        if (hasEndStream) {
                            multiplexer.transitionState(sid, Http2StreamState.HALF_CLOSED_REMOTE)
                        }
                        return (sid, request)
                    }
                case Http2FrameType.CONTINUATION =>
                    let payload = readFramePayload(header)
                    let sid = header.streamId
                    if (sid != pendingStreamId) { continue }
                    headerFragments.add(payload)
                    let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                    let hasEndStream = (header.flags & FLAG_END_STREAM) != 0

                    if (hasEndHeaders) {
                        let (request, _) = buildRequestFromHeaders(headerFragments, sid)
                        headerFragments = ArrayList<Array<UInt8>>()
                        // RFC 9218 §4：从 Priority 头字段提取优先级信号
                        match (request.headers.get("priority")) {
                            case Some(pv) => applyPriorityToStream(sid, unsafe { pv.rawData() })
                            case None => ()
                        }
                        if (hasEndStream) {
                            multiplexer.transitionState(sid, Http2StreamState.HALF_CLOSED_REMOTE)
                        }
                        return (sid, request)
                    }
                case Http2FrameType.DATA =>
                    let payload = readFramePayload(header)
                    let sid = header.streamId
                    // RFC 9113 §8.1: 拒绝空闲流上的 DATA 帧
                    match (multiplexer.getStream(sid)) {
                        case Some(stream) =>
                            if (payload.size > 0) {
                                stream.dataBuffer.write(payload)
                                multiplexer.consumeStreamRecvWindow(sid, payload.size)
                                replenishRecvWindows(sid, payload.size)
                            }
                            if ((header.flags & FLAG_END_STREAM) != 0) {
                                multiplexer.transitionState(sid, Http2StreamState.HALF_CLOSED_REMOTE)
                            }
                        case None =>
                            // 流不存在：发送 RST_STREAM (PROTOCOL_ERROR)
                            let rstFrame = buildRstStreamFrame(sid, Http2ErrorCode.STREAM_CLOSED)
                            sendFrame(rstFrame)
                    }
                case Http2FrameType.SETTINGS =>
                    handlePeerSettings(header)
                case Http2FrameType.PING =>
                    handlePing(header)
                case Http2FrameType.GOAWAY =>
                    let payload = readFramePayload(header)
                    handleGoaway(payload)
                    return (0u32, HttpRequest(method: HttpMethod.GET, url: ""))
                case Http2FrameType.WINDOW_UPDATE =>
                    handleWindowUpdate(header)
                case Http2FrameType.ORIGIN =>
                    handleOrigin(header)
                case Http2FrameType.ALTSVC =>
                    handleAltSvc(header)
                case Http2FrameType.PRIORITY_UPDATE =>
                    handlePriorityUpdate(header)

                case _ =>
                    let _ = readFramePayload(header)
            }
        }
        // 不可达 — 循环只能通过 return 或 throw 退出
        throw Http2Exception(Http2ErrorCode.INTERNAL_ERROR, "unreachable")
    }

    /**
     * 读取给定流（服务器端）的主体数据。
     */
    public func recvRequestBody(streamId: UInt32): Array<UInt8> {
        let stream = multiplexer.getStream(streamId)
        match (stream) {
            case Some(s) =>
                // 读取剩余的 DATA 帧
                while (s.state != Http2StreamState.HALF_CLOSED_REMOTE && s.state != Http2StreamState.CLOSED) {
                    let header = readFrameHeader()
                    checkContinuationOrder(header)
                    if (header.frameType == Http2FrameType.DATA && header.streamId == streamId) {
                        let payload = readFramePayload(header)
                        if (payload.size > 0) {
                            s.dataBuffer.write(payload)
                            // 流量控制: consume receive window and send WINDOW_UPDATE if needed
                            multiplexer.consumeStreamRecvWindow(streamId, payload.size)
                            replenishRecvWindows(streamId, payload.size)
                        }
                        if ((header.flags & FLAG_END_STREAM) != 0) {
                            multiplexer.transitionState(streamId, Http2StreamState.HALF_CLOSED_REMOTE)
                            break
                        }
                    } else if (header.frameType == Http2FrameType.SETTINGS) {
                        handlePeerSettings(header)
                    } else if (header.frameType == Http2FrameType.PING) {
                        handlePing(header)
                    } else if (header.frameType == Http2FrameType.GOAWAY) {
                        let payload = readFramePayload(header)
                        handleGoaway(payload)
                        break
                    } else if (header.frameType == Http2FrameType.RST_STREAM) {
                        let payload = readFramePayload(header)
                        multiplexer.removeStream(streamId)
                        break
                    } else {
                        let _ = readFramePayload(header)
                    }
                }
                s.dataBuffer.toArray()
            case None => []
        }
    }

    /**
     * Send an HTTP 响应 on a stream (server side)。
     * 由 writeMu 保护，防止多协程并发帧写入导致数据交错。
     */
    public func sendResponse(streamId: UInt32, response: HttpResponse): Unit {
        synchronized(writeMu) {
            // 构建伪头部 + 常规头部
            let h2Headers = buildH2ResponseHeaders(response)
            let headerBlock = encoder.encode(h2Headers)

            let hasBody = response.body.getLimit() > 0
            let headersFrame = buildHeadersFrame(streamId, headerBlock, endStream: !hasBody)
            sendFrame(headersFrame)

            if (hasBody) {
                let bodyData = response.bodyAsBytes()
                sendDataFrames(streamId, bodyData)
            }

            multiplexer.transitionState(streamId, Http2StreamState.HALF_CLOSED_LOCAL)
        }
    }

    // ---- 帧 I/O ----

    /**
     * Validate CONTINUATION 帧 ordering per RFC 9113 Section 6.10.
     * 在未带 END_HEADERS 的 HEADERS/PUSH_PROMISE 之后，同一流上只允许
     * CONTINUATION 帧，直到收到 END_HEADERS。
     * 任何其他帧类型或不同流上的帧都属于 PROTOCOL_ERROR。
     */
    private func checkContinuationOrder(header: Http2FrameHeader): Unit {
        if (header.frameType == Http2FrameType.CONTINUATION && header.streamId == 0u32) {
            throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                "CONTINUATION frame with stream ID 0")
        }
        if (continuationStreamId != 0) {
            if (header.streamId != continuationStreamId) {
                throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                    "Expected CONTINUATION on stream ${continuationStreamId}, got ${header.frameType} on stream ${header.streamId}")
            }
            // RST_STREAM 允许中断 CONTINUATION 序列（RFC 9113 §5.1）
            if (header.frameType != Http2FrameType.CONTINUATION &&
                header.frameType != Http2FrameType.RST_STREAM) {
                throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                    "Expected CONTINUATION on stream ${continuationStreamId}, got ${header.frameType}")
            }
            if (header.frameType == Http2FrameType.RST_STREAM) {
                continuationStreamId = 0
                return
            }
        }
        // 更新 CONTINUATION 跟踪状态
        if (header.frameType == Http2FrameType.HEADERS || header.frameType == Http2FrameType.PUSH_PROMISE) {
            if ((header.flags & FLAG_END_HEADERS) == 0) {
                continuationStreamId = header.streamId
            }
        } else if (header.frameType == Http2FrameType.CONTINUATION) {
            if ((header.flags & FLAG_END_HEADERS) != 0) {
                continuationStreamId = 0
            }
            // 无 END_HEADERS 的 CONTINUATION 保持 continuationStreamId 不变
        }
    }

    private func readFrameHeader(): Http2FrameHeader {
        updateLastDataReceiveTime()
        let headerBytes = Array<UInt8>(FRAME_HEADER_SIZE, repeat: 0)
        readExact(headerBytes, 0, FRAME_HEADER_SIZE)
        Http2FrameHeader.parse(headerBytes)
    }

    private func readFramePayload(header: Http2FrameHeader): Array<UInt8> {
        let payloadLen = header.payloadLength
        if (payloadLen == 0) {
            return []
        }
        // 根据对端通告的 MAX_FRAME_SIZE 验证载荷长度 per RFC 9113 Section 4.2
        if (payloadLen > peerMaxFrameSize) {
            throw Http2Exception(Http2ErrorCode.FRAME_SIZE_ERROR,
                "Frame payload length ${payloadLen} exceeds peer's MAX_FRAME_SIZE ${peerMaxFrameSize}")
        }
        // 对于未知帧类型，按 RFC 9113 Section 4.1 跳过载荷 per RFC 9113 Section 4.1
        if (!header.isKnown) {
            let skipBuf = Array<UInt8>(payloadLen, repeat: 0)
            readExact(skipBuf, 0, payloadLen)
            return []
        }
        let payload = Array<UInt8>(payloadLen, repeat: 0)
        readExact(payload, 0, payloadLen)
        payload
    }

    private func fireCountError(errType: String): Unit {
        match (countError) {
            case Some(cb) => cb(errType)
            case None => ()
        }
    }

    private func sendFrame(frameData: Array<UInt8>): Unit {
        let startTime = DateTime.now()
        conn.write(frameData)
        conn.flush()
        let elapsed = DateTime.now() - startTime
        if (elapsed > writeByteTimeout) {
            fireCountError("write_byte_timeout")
            try { conn.close() } catch (_: Exception) {}
            throw Http2Exception(Http2ErrorCode.INTERNAL_ERROR, "write byte timeout")
        }
    }

    private func sendSettings(settings: Array<(Http2SettingsId, UInt32)>): Unit {
        let payload = encodeSettings(settings)
        let header = Http2FrameHeader(payload.size, Http2FrameType.SETTINGS, streamId: 0)
        sendFrame(encodeFrame(header, payload))
    }

    private func sendDataFrames(streamId: UInt32, data: Array<UInt8>): Unit {
        var offset: Int64 = 0
        var remaining = data.size
        while (remaining > 0) {
            // 遵守连接级别发送窗口
            if (connSendWindow <= 0) {
                // 窗口耗尽 —— 将剩余数据排队，等待 WINDOW_UPDATE
                var remainingData = Array<UInt8>(remaining, repeat: 0)
                data[offset..offset + remaining].copyTo(remainingData, 0, 0, remaining)
                pendingData[streamId] = remainingData
                return
            }
            // 遵守流级别发送窗口 (RFC 9113 §6.9.1)
            let streamSendWindow = getStreamSendWindow(streamId)
            let effectiveWindow = if (connSendWindow < streamSendWindow) { connSendWindow } else { streamSendWindow }
            if (effectiveWindow <= 0) {
                var remainingData = Array<UInt8>(remaining, repeat: 0)
                data[offset..offset + remaining].copyTo(remainingData, 0, 0, remaining)
                pendingData[streamId] = remainingData
                return
            }
            let maxChunk = effectiveWindow
            let maxChunk2 = if (maxChunk < peerMaxFrameSize) { maxChunk } else { peerMaxFrameSize }
            let chunkSize = if (remaining > maxChunk2) { maxChunk2 } else { remaining }
            let endStream = (offset + chunkSize >= data.size)
            let flags: UInt8 = if (endStream) { FLAG_END_STREAM } else { 0 }
            let chunk = Array<UInt8>(chunkSize, repeat: 0)
            // 使用 copyTo 批量复制，避免逐字节循环
            data[offset..offset + chunkSize].copyTo(chunk, 0, 0, chunkSize)
            let header = Http2FrameHeader(chunkSize, Http2FrameType.DATA, flags: flags, streamId: streamId)
            let frameData = encodeFrame(header, chunk)

            writeSched.push(Http2FrameWriteRequest(streamId, frameData, flowControlBytes: chunkSize))
            offset += chunkSize
            remaining -= chunkSize
        }
        flushScheduledFrames()
    }

    // 阻塞在流控上的流的待处理 DATA
    private var pendingData: HashMap<UInt32, Array<UInt8>> = HashMap<UInt32, Array<UInt8>>()

    /**
     * Flush all frames queued in the 写入调度器.
     * 先发送控制帧，然后按优先级顺序发送 DATA 帧。
     * 跳过超过可用发送窗口的 DATA 帧（RFC 9113 §6.9）。
     */
    private func flushScheduledFrames(): Unit {
        var sent = true
        while (sent) {
            sent = false
            match (writeSched.pop()) {
                case Some(wr) =>
                    // 对于 DATA 帧，检查流控窗口
                    if (wr.flowControlBytes > 0) {
                        // 检查连接级别发送窗口 (RFC 9113 §6.9)
                        if (connSendWindow < wr.flowControlBytes) {
                            // 窗口不足 —— 重新排队并停止刷新
                            // 帧将在 WINDOW_UPDATE 到达时发送
                            writeSched.push(wr)
                            conn.flush()
                            return
                        }
                        // 检查流级别发送窗口
                        let streamWindow = getStreamSendWindow(wr.streamId)
                        if (streamWindow < wr.flowControlBytes) {
                            // 流窗口不足 —— 重新排队
                            writeSched.push(wr)
                            conn.flush()
                            return
                        }
                        // 两个窗口都有足够容量 —— 原子地扣除并发送
                        connSendWindow -= wr.flowControlBytes
                        multiplexer.consumeStreamSendWindow(wr.streamId, wr.flowControlBytes)
                    }
                    conn.write(wr.frameData)
                    sent = true
                case None => ()
            }
        }
        conn.flush()
    }

    /**
     * 刷新因流控窗口耗尽而排队的所有待处理 DATA 帧。
     * 在 WINDOW_UPDATE 增加可用发送窗口后调用。
     * 根据 RFC 9113 §6.9，阻塞在流控上的数据必须在窗口增大时重新发送。
     */
    private func flushPendingData(): Unit {
        synchronized(writeMu) {
            if (pendingData.isEmpty()) { return }
            let pending = HashMap<UInt32, Array<UInt8>>()
            for ((sid, data) in pendingData) { pending[sid] = data }
            pendingData.clear()
            for ((sid, data) in pending) {
                // 发送前重新检查流控窗口
                let streamWindow = getStreamSendWindow(sid)
                if (connSendWindow > 0 && streamWindow > 0) {
                    sendDataFrames(sid, data)
                } else {
                    // 仍然阻塞 —— 重新排队
                    pendingData[sid] = data
                }
            }
        }
    }


    /**
     * 补充连接级和流级接收窗口（RFC 9113 §6.9）。
     * 消费 payloadSize 字节后调用，自动发送 WINDOW_UPDATE。
     */
    private func replenishRecvWindows(streamId: UInt32, consumedSize: Int64): Unit {
        connRecvWindow -= consumedSize
        if (connRecvWindow < sendWindowLow) {
            let increment = sendWindowMax - connRecvWindow
            sendConnectionWindowUpdate(UInt32(increment))
        }
        match (multiplexer.getStream(streamId)) {
            case Some(s) =>
                if (s.recvWindow < Int64(DEFAULT_INITIAL_WINDOW_SIZE) / 2) {
                    let streamIncrement = Int64(DEFAULT_INITIAL_WINDOW_SIZE) - s.recvWindow
                    if (streamIncrement > 0) {
                        sendStreamWindowUpdate(streamId, UInt32(streamIncrement))
                        multiplexer.addStreamRecvWindow(streamId, streamIncrement)
                    }
                }
            case None => ()
        }
    }
    private func sendConnectionWindowUpdate(increment: UInt32): Unit {
        synchronized(writeMu) {
            let frame = buildConnectionWindowUpdate(increment)
            sendFrame(frame)
            connSendWindow += Int64(increment)
        }
    }

    private func handlePing(header: Http2FrameHeader): Unit {
        let payload = readFramePayload(header)
        if ((header.flags & FLAG_ACK) == 0) {
            // PING 速率限制（RFC 9113 §6.7）：最小间隔 1 秒，超限则静默丢弃
            let now = DateTime.now()
            if (now - lastPingTime < minPingInterval) {
                return
            }
            lastPingTime = now
            // 回复 PING ACK
            let ackFrame = buildPingFrame(payload, ack: true)
            sendFrame(ackFrame)
        }
    }

    private func handlePeerSettings(header: Http2FrameHeader): Unit {
        let payload = readFramePayload(header)
        let settings = decodeSettings(payload)
        for ((id, value) in settings) {
            peerSettings[id] = value
            applyPeerSetting(id, value)
        }
        if ((header.flags & FLAG_ACK) == 0) {
            // 发送 SETTINGS ACK
            sendFrame(buildSettingsAckFrame())
        }
    }

    private func handleWindowUpdate(header: Http2FrameHeader): Unit {
        let payload = readFramePayload(header)
        let increment = decodeWindowUpdate(payload)
        // 按 RFC 9113 Section 6.9：WINDOW_UPDATE 增量必须 > 0
        if (increment == 0) {
            if (header.streamId == 0) {
                throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                    "Connection-level WINDOW_UPDATE with zero increment")
            } else {
                // 流级别零增量是流错误（RFC 9113 §6.9）
                let rstFrame = buildRstStreamFrame(header.streamId, Http2ErrorCode.PROTOCOL_ERROR)
                sendFrame(rstFrame)
                multiplexer.removeStream(header.streamId)
                return
            }
        }
        if (header.streamId == 0) {
            // 连接级别窗口更新
            connSendWindow += Int64(increment)
        } else {
            // 流级别窗口更新 —— 仅影响流窗口
            // 按 RFC 9113 §6.9：流的 WINDOW_UPDATE 仅应用于该流。
            // 此处不得增加连接级别发送窗口。
            match (multiplexer.getStream(header.streamId)) {
                case Some(stream) =>
                    stream.sendWindow += Int64(increment)
                case None => ()
            }
        }
        // 窗口增加后，尝试刷新任何因窗口不足而阻塞的待处理 DATA
        // （RFC 9113 §6.9 — 阻塞在流控上的数据在窗口增大时恢复）
        flushScheduledFrames()
        flushPendingData()
    }

    private func handleGoaway(payload: Array<UInt8>): Unit {
        // 在标记 goaway 前提取 last-stream-id 以验证单调性
        var newLastStreamId: UInt32 = 0
        if (payload.size >= 8) {
            newLastStreamId = (UInt32(payload[0] & 0x7f) << 24) |
                (UInt32(payload[1]) << 16) |
                (UInt32(payload[2]) << 8) |
                UInt32(payload[3])
        }
        // 根据 RFC 9113 Section 6.8：last-stream-id 不得减小
        // 若减小则对端行为异常 —— 按 PROTOCOL_ERROR 处理
        if (goawayReceived.load() && lastStreamId > 0 && newLastStreamId < lastStreamId) {
            throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                "GOAWAY last-stream-id decreased from ${lastStreamId} to ${newLastStreamId}")
        }
        goawayReceived.store(true)
        lastStreamId = newLastStreamId
        // 提取调试数据（RFC 9113 §6.8：8 字节头部后的附加调试数据）
        if (payload.size > 8) {
            let debugLen = payload.size - 8
            goawayDebugData = Array<UInt8>(debugLen, repeat: 0)
            var i: Int64 = 0
            while (i < debugLen) { goawayDebugData[i] = payload[8 + i]; i += 1 }
        }
        multiplexer.markGoawayReceived(lastStreamId)
    }

    private func handlePriority(header: Http2FrameHeader): Unit {
        let payload = readFramePayload(header)
        if (payload.size < 5) { return }
        // 解析 PRIORITY 载荷：E(1bit) + Stream Dependency(31bit) + Weight(8bit)
        let exclusive = (payload[0] & 0x80) != 0
        let streamDep = (UInt32(payload[0] & 0x7f) << 24) |
            (UInt32(payload[1]) << 16) |
            (UInt32(payload[2]) << 8) |
            UInt32(payload[3])
        let weight = if (payload.size > 4) { payload[4] } else { UInt8(16) }
        multiplexer.updatePriority(header.streamId, exclusive, streamDep, weight)
        // Also update the 写入调度器's own 优先级树 (RFC 9113 §5.3)
        // 写入调度器拥有自己的 PriorityTree，必须保持同步
        writeSched.adjustStream(header.streamId, exclusive, streamDep, weight)
    }

    /**
     * 从 HEADERS 帧载荷中剥离 PRIORITY 字段。
     * 按 RFC 9113 §6.2，若设置了 PRIORITY 标志，载荷以：
     *   E (1 bit) + Stream Dependency (31 bits) + Weight (8 bits) = 5 字节
     * 若同时设置了 PADDED，stripPadding() 已处理两者（dataStart = 6）。
     * 此方法处理设置了 PRIORITY 但未设置 PADDED 的情况。
     */
    private func stripHeadersPriorityField(flags: UInt8, payload: Array<UInt8>, streamId: UInt32): Array<UInt8> {
        if ((flags & FLAG_PADDED) != 0) {
            // stripPadding 已处理 PRIORITY+PADDED 组合
            return stripPadding(Http2FrameType.HEADERS, flags, payload)
        }
        if ((flags & FLAG_PRIORITY) != 0 && payload.size >= 5) {
            // 解析优先级信息并路由到多路复用器
            let exclusive = (payload[0] & 0x80) != 0
            let streamDep = (UInt32(payload[0] & 0x7f) << 24) |
                (UInt32(payload[1]) << 16) |
                (UInt32(payload[2]) << 8) |
                UInt32(payload[3])
            let weight = payload[4]
            multiplexer.updatePriority(streamId, exclusive, streamDep, weight)
            // 去除 5 字节优先级字段并返回头部块片段
            let remaining = payload.size - 5
            if (remaining <= 0) { return [] }
            let result = Array<UInt8>(remaining, repeat: 0)
            var i: Int64 = 0
            while (i < remaining) { result[i] = payload[5 + i]; i += 1 }
            return result
        }
        payload
    }

    private func buildHeadersFrame(streamId: UInt32, headerBlock: Array<UInt8>, endStream!: Bool = false): Array<UInt8> {
        var flags: UInt8 = FLAG_END_HEADERS
        if (endStream) { flags = flags | FLAG_END_STREAM }
        let header = Http2FrameHeader(headerBlock.size, Http2FrameType.HEADERS, flags: flags, streamId: streamId)
        encodeFrame(header, headerBlock)
    }

    /**
     * 从累积的 HPACK 头部片段构建 HttpRequest。
     * 提取伪头部并转换为标准请求。
     */
    private func buildRequestFromHeaders(fragments: ArrayList<Array<UInt8>>, streamId: UInt32): (HttpRequest, HttpHeaders) {
        let headers = decodeAccumulatedHeaders(fragments)
        let method = match (headers.get(":method")) { case Some(v) => parseMethod(v) case None => HttpMethod.GET }
        let path = match (headers.get(":path")) { case Some(v) => v case None => "/" }
        let scheme = match (headers.get(":scheme")) { case Some(v) => v case None => "https" }
        let authority = match (headers.get(":authority")) { case Some(v) => v case None => "" }
        headers.remove(":method")
        headers.remove(":path")
        headers.remove(":scheme")
        headers.remove(":authority")
        let url = "${scheme}://${authority}${path}"
        let request = HttpRequest(method: method, url: url, version: HttpVersion.HTTP_2_0, headers: headers)
        (request, headers)
    }

    // ---- 头部转换 ----

    private func buildH2RequestHeaders(request: HttpRequest, streamId: UInt32): HttpHeaders {
        let h2Headers = HttpHeaders()
        // 从 URL 提取 scheme + authority + path
        let url = ParsedUrl.parse(request.url)
        let host = url.host
        let isSecure = url.isSecure
        let path = url.path
        h2Headers.set(":method", request.method.toString())
        h2Headers.set(":scheme", if (isSecure) { "https" } else { "http" })
        h2Headers.set(":authority", host)
        h2Headers.set(":path", path)
        // 扩展 CONNECT（RFC 8441）：若存在则包含 :protocol 伪头部
        match (request.headers.get(":protocol")) {
            case Some(protocol) => h2Headers.set(":protocol", protocol)
            case None => ()
        }
        // 复制常规头部
        let names = request.headers.names()
        for (name in names) {
            if (name == "host" || name == "connection" || name == "Keep-Alive" ||
                name == "transfer-encoding" || name == "upgrade") {
                continue  // 跳过连接相关的头部
            }
            // RFC 9113 Section 8.1.2.2：TE 头必须过滤，除了 "trailers"
            if (name == "te") {
                match (request.headers.get(name)) {
                    case Some(v) =>
                        if (v == "trailers") {
                            h2Headers.set(name, v)
                        }
                    case None => ()
                }
                continue
            }
            match (request.headers.get(name)) {
                case Some(v) => h2Headers.set(name, v)
                case None => ()
            }
        }
        h2Headers
    }

    private func buildH2ResponseHeaders(response: HttpResponse): HttpHeaders {
        let h2Headers = HttpHeaders()
        h2Headers.set(":status", "${response.status.code}")
        // 扩展 CONNECT（RFC 8441）：若存在则包含 :protocol 伪头部
        match (response.headers.get(":protocol")) {
            case Some(protocol) => h2Headers.set(":protocol", protocol)
            case None => ()
        }
        // 复制常规头部
        let names = response.headers.names()
        for (name in names) {
            if (name == "connection" || name == "Keep-Alive" ||
                name == "transfer-encoding" || name == "upgrade") {
                continue
            }
            // RFC 9113 Section 8.1.2.2：TE 头必须过滤，除了 "trailers"
            if (name == "te") {
                match (response.headers.get(name)) {
                    case Some(v) =>
                        if (v == "trailers") {
                            h2Headers.set(name, v)
                        }
                    case None => ()
                }
                continue
            }
            match (response.headers.get(name)) {
                case Some(v) => h2Headers.set(name, v)
                case None => ()
            }
        }
        h2Headers
    }

    /**
     * 将累积的头部片段解码为 HttpHeaders。
     * 拼接所有片段，然后通过 HPACK 解码。
     */
    private func decodeAccumulatedHeaders(fragments: ArrayList<Array<UInt8>>): HttpHeaders {
        // 计算总大小
        var totalSize: Int64 = 0
        for (fragment in fragments) { totalSize += fragment.size }

        if (totalSize == 0) {
            return HttpHeaders()
        }

        // 拼接所有片段
        let combined = Array<UInt8>(totalSize, repeat: 0)
        var offset: Int64 = 0
        for (fragment in fragments) {
            var i: Int64 = 0
            while (i < fragment.size) { combined[offset + i] = fragment[i]; i += 1 }
            offset += fragment.size
        }

        // 解码完整头部块
        decoder.decode(combined)
    }

    private func mergeHeaders(target: HttpHeaders, source: HttpHeaders): Unit {
        let names = source.names()
        for (name in names) {
            match (source.get(name)) {
                case Some(v) => target.set(name, v)
                case None => ()
            }
        }
    }

    // ---- 流量控制 ----

    private func applyPeerSetting(id: Http2SettingsId, value: UInt32): Unit {
        match (id) {
            case Http2SettingsId.HEADER_TABLE_SIZE =>
                // 更新 HPACK 编码器以遵守对端的最大表大小
                // 使用 setMaxTableSize 保留动态表状态（RFC 7541 §4.2）
                encoder.setMaxTableSize(Int64(value))
            case Http2SettingsId.MAX_FRAME_SIZE =>
                // RFC 9113 Section 6.5.2：值必须在 2^14 (16384) 和 2^24-1 (16777215) 之间
                let v = Int64(value)
                if (v < Int64(DEFAULT_MAX_FRAME_SIZE) || v > Int64(MAX_FRAME_SIZE_LIMIT)) {
                    throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                        "Invalid MAX_FRAME_SIZE ${v}: must be between ${DEFAULT_MAX_FRAME_SIZE} and ${MAX_FRAME_SIZE_LIMIT}")
                }
                peerMaxFrameSize = v
            case Http2SettingsId.INITIAL_WINDOW_SIZE =>
                // RFC 9113 Section 6.9.2：值不得超过 2^31-1
                if (Int64(value) > MAX_WINDOW_SIZE) {
                    throw Http2Exception(Http2ErrorCode.FLOW_CONTROL_ERROR,
                        "Invalid INITIAL_WINDOW_SIZE ${value}: exceeds maximum ${MAX_WINDOW_SIZE}")
                }
                let newSize = Int64(value)
                let delta = newSize - currentInitialWindowSize
                if (delta != 0) {
                    // 调整连接级别发送窗口
                    connSendWindow += delta
                    // 调整所有现有流的发送窗口
                    multiplexer.adjustAllStreamSendWindows(delta)
                    currentInitialWindowSize = newSize
                }
            case Http2SettingsId.MAX_HEADER_LIST_SIZE =>
                encoder.setMaxHeaderListSize(Int64(value))
                decoder.setMaxHeaderListSize(Int64(value))
           case Http2SettingsId.MAX_CONCURRENT_STREAMS =>
               multiplexer.setMaxConcurrentStreams(Int64(value))
           case Http2SettingsId.NO_RFC7540_PRIORITIES =>
               // RFC 9218 §5: 指示发送方将使用 RFC 9218 可扩展优先级方案。
               // 当收到该设置时，我方应优先使用 PRIORITY_UPDATE 帧的优先级信息，
               // 而非 HEADERS 帧的 PRIORITY 标志。
               // 当前实现已支持 PRIORITY_UPDATE 帧处理，此处无需额外操作。
                ()
            case Http2SettingsId.ENABLE_PUSH =>
                // RFC 9113 §6.5.2: ENABLE_PUSH 只能设置为 0（禁用）或 1（启用）
                if (value != 0u32 && value != 1u32) {
                    throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                        "Invalid SETTINGS_ENABLE_PUSH value: ${value}")
                }
                // 值已存储在 peerSettings 中，pushPromise() 方法动态检查该值
                // 当对端设为 0 时，不会发送 PUSH_PROMISE 帧
            case Http2SettingsId.ENABLE_CONNECT_PROTOCOL =>
                // RFC 8441 §4: 端点必须接受 SETTINGS_ENABLE_CONNECT_PROTOCOL。
                // 值为 0（禁用）或 1（启用），其余值视为 PROTOCOL_ERROR。
                if (value != 0u32 && value != 1u32) {
                    throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                        "Invalid SETTINGS_ENABLE_CONNECT_PROTOCOL value: ${value}")
                }
                // 收到 1 时表明对端支持扩展 CONNECT，无需特殊处理
                // 本端按 RFC 8441 处理 CONNECT + :protocol 请求即可
            case _ => ()
        }
    }

    // ---- 服务端推送（RFC 9113 Section 8.2） ----

    /**
     * 在服务器发起的流上向客户端推送资源。
     * 仅在服务器连接上有效。
     *
     * 返回推送流 ID，若推送被禁用或流被拒绝则返回 0。
     */
    public func pushPromise(associatedStreamId: UInt32, request: HttpRequest): UInt32 {
        synchronized(writeMu) {
            if (!isServer) { return 0 }

            // 检查对端是否启用了推送
            match (peerSettings.get(Http2SettingsId.ENABLE_PUSH)) {
                case Some(v) =>
                    if (v == 0) { return 0 }  // 对端已禁用 Push
                case None => ()
            }

            match (multiplexer.createPushStream(associatedStreamId)) {
                case Some(pushStream) =>
                    let pushId = pushStream.streamId

                    // 构建推送承诺头部
                    let h2Headers = buildH2RequestHeaders(request, pushId)
                    let headerBlock = encoder.encode(h2Headers)

                    // 构建 PUSH_PROMISE 帧
                    let promisedId = pushId
                    let padLen = headerBlock.size + 4  // 4 字节的承诺流 ID
                    let payload = Array<UInt8>(padLen, repeat: 0)
                    // 承诺流 ID（31 位）
                    payload[0] = UInt8((promisedId >> 24) & 0x7f)
                    payload[1] = UInt8((promisedId >> 16) & 0xff)
                    payload[2] = UInt8((promisedId >> 8) & 0xff)
                    payload[3] = UInt8(promisedId & 0xff)
                    // 头部块片段
                    var i: Int64 = 0
                    while (i < headerBlock.size) { payload[4 + i] = headerBlock[i]; i += 1 }

                    let ppHeader = Http2FrameHeader(payload.size, Http2FrameType.PUSH_PROMISE,
                        flags: FLAG_END_HEADERS, streamId: associatedStreamId)
                    sendFrame(encodeFrame(ppHeader, payload))

                    // 发送推送响应（简化版 —— 调用方单独发送响应）
                    pushId
                case None => 0
            }
        }
    }

    /**
     * 在推送流上发送响应（服务器端）。
     * 在 pushPromise() 之后使用此方法来发送实际响应。
     *
     * 根据 RFC 9113 第 8.2 节：服务器推送流状态转换
     * 在发送响应头部后从 RESERVED_LOCAL 变为 HALF_CLOSED_REMOTE。
     */
    public func sendPushResponse(pushStreamId: UInt32, response: HttpResponse): Unit {
        synchronized(writeMu) {
            // 构建伪头部 + 常规头部
            let h2Headers = buildH2ResponseHeaders(response)
            let headerBlock = encoder.encode(h2Headers)

            let hasBody = response.body.getLimit() > 0
            let headersFrame = buildHeadersFrame(pushStreamId, headerBlock, endStream: !hasBody)
            sendFrame(headersFrame)

            if (hasBody) {
                let bodyData = response.bodyAsBytes()
                sendDataFrames(pushStreamId, bodyData)
            }

            // RFC 9113 Section 5.1：推送流从 RESERVED_LOCAL 转换
            // 到 HALF_CLOSED_REMOTE（不是 HALF_CLOSED_LOCAL，后者用于常规流）
            multiplexer.transitionState(pushStreamId, Http2StreamState.HALF_CLOSED_REMOTE)
        }
    }

    /**
     * 发送扩展 CONNECT 响应（RFC 8441）。
     * 用于 WebSocket over HTTP/2：设置 :protocol 和 :status 伪头部。
     */
    public func sendExtendedConnectResponse(streamId: UInt32, protocol: String, status!: UInt16 = 200): Unit {
        synchronized(writeMu) {
            let h2Headers = HttpHeaders()
            h2Headers.set(":status", "${status}")
            h2Headers.set(":protocol", protocol)
            let headerBlock = encoder.encode(h2Headers)
            let headersFrame = buildHeadersFrame(streamId, headerBlock, endStream: false)
            sendFrame(headersFrame)
            multiplexer.transitionState(streamId, Http2StreamState.OPEN)
        }
    }

    /**
     * 服务端接受扩展 CONNECT 请求并建立隧道（RFC 8441）。
     * 发送 200 响应并返回 H2WebSocketTunnel 用于双向数据传输。
     * 发送响应后，调用方通过 tunnel.send() / tunnel.recv() 进行 I/O。
     *
     * @param streamId  扩展 CONNECT 请求的流 ID
     * @param protocol  :protocol 值（如 "websocket"）
     * @return 用于双向数据传输的 H2WebSocketTunnel
     */
    public func acceptExtendedConnect(streamId: UInt32, protocol: String): H2WebSocketTunnel {
        sendExtendedConnectResponse(streamId, protocol, status: 200)
        multiplexer.transitionState(streamId, Http2StreamState.OPEN)
        H2WebSocketTunnel(this, streamId)
    }

    /**
     * 将 PUSH_PROMISE 帧负载解码为 (promisedStreamId, request)。
     * PUSH_PROMISE 负载：4 字节承诺流 ID + 头部块片段。
     * 头部片段可能通过 CONTINUATION 帧（END_HEADERS 标志）延续。
     *
     * RFC 9113 第 6.6 节。
     */
    private func decodePushPromise(payload: Array<UInt8>, flags: UInt8): (UInt32, HttpRequest) {
        // 按 RFC 7540 §6.6：PUSH_PROMISE 帧支持 PADDED 标志
        let effectivePayload = stripPadding(Http2FrameType.PUSH_PROMISE, flags, payload)
        if (effectivePayload.size < 4) {
            throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR, "PUSH_PROMISE too short")
        }
        // 承诺流 ID（31 位，保留位忽略）
        let promisedId = (UInt32(effectivePayload[0] & 0x7f) << 24) |
            (UInt32(effectivePayload[1]) << 16) |
            (UInt32(effectivePayload[2]) << 8) |
            UInt32(effectivePayload[3])

        // 验证：必须是偶数流 ID（服务器发起）
        if (promisedId % 2 != 0 || promisedId == 0) {
            throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                "PUSH_PROMISE reserved stream ID is invalid: ${promisedId}")
        }

        // 收集所有头部块片段（初始 + CONTINUATION）
        let fragments = ArrayList<Array<UInt8>>()
        // 提取头部块片段 (after 4-byte promised stream ID)
        let initialFragment = Array<UInt8>(effectivePayload.size - 4, repeat: 0)
        var i: Int64 = 0
        while (i < effectivePayload.size - 4) { initialFragment[i] = effectivePayload[4 + i]; i += 1 }
        fragments.add(initialFragment)

        // 若未设置 END_HEADERS，则读取 CONTINUATION 帧（RFC 9113 §6.10）
        if ((flags & FLAG_END_HEADERS) == 0) {
            while (true) {
                let contHeader = readFrameHeader()
                if (contHeader.frameType != Http2FrameType.CONTINUATION ||
                    contHeader.streamId != promisedId) {
                    throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
                        "Expected CONTINUATION on stream ${promisedId}")
                }
                let contPayload = readFramePayload(contHeader)
                fragments.add(contPayload)
                if ((contHeader.flags & FLAG_END_HEADERS) != 0) { break }
            }
        }

        // 连接所有头部块片段
        var totalSize: Int64 = 0
        for (frag in fragments) { totalSize += frag.size }
        let headerBlockData = Array<UInt8>(totalSize, repeat: 0)
        var offset: Int64 = 0
        for (frag in fragments) {
            var j: Int64 = 0
            while (j < frag.size) { headerBlockData[offset + j] = frag[j]; j += 1 }
            offset += frag.size
        }

        let headers = decoder.decode(headerBlockData)

        // 从伪头部构建推送请求
        let method = match (headers.get(":method")) {
            case Some(v) => parseMethod(v)
            case None => HttpMethod.GET
        }
        let path = match (headers.get(":path")) {
            case Some(v) => v
            case None => "/"
        }
        let scheme = match (headers.get(":scheme")) {
            case Some(v) => v
            case None => "https"
        }
        let authority = match (headers.get(":authority")) {
            case Some(v) => v
            case None => ""
        }
        headers.remove(":method")
        headers.remove(":path")
        headers.remove(":scheme")
        headers.remove(":authority")
        let url = "${scheme}://${authority}${path}"
        let request = HttpRequest(method: method, url: url, version: HttpVersion.HTTP_2_0, headers: headers)

        (promisedId, request)
    }

    /**
     * 在承诺的流上接收推送的响应（客户端）。
     * 在 onPushPromise 返回后调用此方法以获取推送的资源。
     *
     * 读取承诺流上的 HEADERS + DATA 帧直到 END_STREAM。
     * 成功时返回 Some(HttpResponse)，如果推送被取消则返回 None。
     */
    public func recvPushResponse(promisedStreamId: UInt32): ?HttpResponse {
        var responseHeaders: HttpHeaders = HttpHeaders()
        var bodyBuffer = ByteBuffer(capacity: 65536)
        var endStream = false
        var headerFragments = ArrayList<Array<UInt8>>()

        while (!endStream) {
            let header = readFrameHeader()
            checkContinuationOrder(header)
            match (header.frameType) {
                case Http2FrameType.HEADERS =>
                    if (header.streamId != promisedStreamId) { continue }
                    let payload = readFramePayload(header)
                    headerFragments.add(payload)
                    let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                    endStream = (header.flags & FLAG_END_STREAM) != 0
                    if (hasEndHeaders) {
                        responseHeaders = decodeAccumulatedHeaders(headerFragments)
                        headerFragments = ArrayList<Array<UInt8>>()
                    }
                case Http2FrameType.CONTINUATION =>
                    if (header.streamId != promisedStreamId) { continue }
                    let payload = readFramePayload(header)
                    headerFragments.add(payload)
                    let hasEndHeaders = (header.flags & FLAG_END_HEADERS) != 0
                    endStream = (header.flags & FLAG_END_STREAM) != 0 || endStream
                    if (hasEndHeaders) {
                        responseHeaders = decodeAccumulatedHeaders(headerFragments)
                        headerFragments = ArrayList<Array<UInt8>>()
                    }
                case Http2FrameType.DATA =>
                    if (header.streamId != promisedStreamId) { continue }
                    let payload = readFramePayload(header)
                    if (payload.size > 0) { bodyBuffer.write(payload) }
                    endStream = (header.flags & FLAG_END_STREAM) != 0
                    multiplexer.consumeStreamRecvWindow(promisedStreamId, payload.size)
                    replenishRecvWindows(promisedStreamId, payload.size)
                case Http2FrameType.RST_STREAM =>
                    let payload = readFramePayload(header)
                    if (header.streamId != promisedStreamId) { continue }
                    let ec = decodeRstStream(payload)
                    // 推送已被服务器取消
                    multiplexer.removeStream(promisedStreamId)
                    return None
                case Http2FrameType.GOAWAY =>
                    let payload = readFramePayload(header)
                    handleGoaway(payload)
                    return None
                case Http2FrameType.PING =>
                    handlePing(header)
                case Http2FrameType.SETTINGS =>
                    handlePeerSettings(header)
                case Http2FrameType.WINDOW_UPDATE =>
                    handleWindowUpdate(header)
                case Http2FrameType.ORIGIN =>
                    handleOrigin(header)
                case Http2FrameType.ALTSVC =>
                    handleAltSvc(header)
                case Http2FrameType.PRIORITY_UPDATE =>
                    handlePriorityUpdate(header)
                case Http2FrameType.RST_STREAM =>
                    let payload = readFramePayload(header)
                    if (header.streamId != promisedStreamId) { continue }
                    let ec = decodeRstStream(payload)
                    // 推送已被服务器取消
                    multiplexer.removeStream(promisedStreamId)
                    return None

                case _ =>
                    let _ = readFramePayload(header)
            }
        }

        let statusStr = match (responseHeaders.get(":status")) {
            case Some(s) => s
            case None => "200"
        }
        let status = parseStatus(statusStr)
        responseHeaders.remove(":status")

        let resp = HttpResponse(status: status, headers: responseHeaders, body: bodyBuffer)
        resp.version = HttpVersion.HTTP_2_0
        Some(resp)
    }

    /**
     * 通过发送 RST_STREAM 取消推送的流（客户端）。
     * 当客户端已经缓存了资源时使用。
     *
     * RFC 9113 第 8.2.2 节。
     */
    public func cancelPush(promisedStreamId: UInt32, errorCode!: Http2ErrorCode = Http2ErrorCode.CANCEL): Unit {
        let rstFrame = buildRstStreamFrame(promisedStreamId, errorCode)
        sendFrame(rstFrame)
        multiplexer.removeStream(promisedStreamId)
        promisedStreams.remove(promisedStreamId)
    }

    // ---- 优雅关闭（RFC 9113 Section 6.8） ----

    /**
     * Initiate 优雅关闭 by sending GOAWAY.
     * 超过 lastStreamId 的新流将被拒绝。
     * 现有流继续处理。
     */
    public func gracefulShutdown(errorCode!: Http2ErrorCode = Http2ErrorCode.NO_ERROR, debugData!: Array<UInt8> = []): Unit {
        let lastId = multiplexer.getNextStreamId()
        let goaway = buildGoawayFrame(lastId, errorCode)
        sendFrame(goaway)
        goawaySent.store(true)
        goawayReceived.store(true)  // 本地发起的关闭也标记为已接收
        lastStreamId = lastId
    }

    /**
     * 检查连接是否正在排空（已发送或接收 GOAWAY）。
     */
    public func isDraining(): Bool { goawaySent.load() || goawayReceived.load() }

    /**
     * Send a PING 帧 for keepalive.
     * 如果 PING 已被确认则返回 true。
     * 在 ping 等待期间处理中间帧（SETTINGS、WINDOW_UPDATE 等）
     * 而不是丢弃它们（RFC 9113 §6.7）。
     */
    public func ping(opaqueData: Array<UInt8>): Bool {
        let pingFrame = buildPingFrame(opaqueData)
        conn.write(pingFrame)
        conn.flush()
        // 等待 PING ACK —— 按 RFC 9113 §6.7 处理中间帧
        let maxAttempts: Int64 = 100  // 防止无限循环
        var attempts: Int64 = 0
        try {
            while (attempts < maxAttempts) {
                let header = readFrameHeader()
                if (header.frameType == Http2FrameType.PING && (header.flags & FLAG_ACK) != 0) {
                    // 消费 PING ACK 载荷并返回
                    let _ = readFramePayload(header)
                    return true
                }
                // 处理中间帧以避免丢失
                match (header.frameType) {
                    case Http2FrameType.SETTINGS =>
                        handlePeerSettings(header)
                    case Http2FrameType.WINDOW_UPDATE =>
                        handleWindowUpdate(header)
                    case Http2FrameType.GOAWAY =>
                        let payload = readFramePayload(header)
                        handleGoaway(payload)
                        return false
                    case Http2FrameType.PRIORITY =>
                        handlePriority(header)
                    case Http2FrameType.ORIGIN =>
                        let _ = readFramePayload(header)
                    case Http2FrameType.ALTSVC =>
                        let _ = readFramePayload(header)
                    case Http2FrameType.PRIORITY_UPDATE =>
                        handlePriorityUpdate(header)

                    case _ =>
                        let _ = readFramePayload(header)  // 消费并丢弃其他帧
                }
                attempts++
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    // ---- I/O 辅助函数 ----

    private func readExact(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        updateLastDataReceiveTime()
        var received: Int64 = 0
        while (received < length) {
            let n = conn.read(buf, offset + received, length - received)
            if (n <= 0) {
                throw ProtocolException("HTTP/2 连接 closed")
            }
            received += n
        }
        received
    }

    /**
     * 更新最后数据接收时间。
     */
    private func updateLastDataReceiveTime(): Unit {
        lastDataReceiveTime = DateTime.now()
    }

    /**
     * 检查空闲超时并在必要时发送 PING 保活。
     * 若超过 readIdleTimeout 未收到数据，发送 PING。
     * 若已发送 PING 且超过 pingTimeout 未收到回复，关闭连接。
     * 在读取帧之前调用。
     */
    private func checkIdleTimeout(): Unit {
        let now = DateTime.now()
        let elapsed = now - lastDataReceiveTime
        if (pingSent && elapsed > pingTimeout) {
            pingSent = false
            throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR, "PING timeout")
        }
        if (!pingSent && elapsed > readIdleTimeout) {
            // 发送 PING
            let pingData: Array<UInt8> = [0x48u8, 0x54u8, 0x54u8, 0x50u8, 0x32u8, 0x50u8, 0x49u8, 0x4Eu8] 
            sentPingData = pingData
            let pingFrame = buildPingFrame(pingData)
            sendFrame(pingFrame)
            conn.flush()
            pingSent = true
            lastDataReceiveTime = now
        }
    }

    /**
     * 处理收到的 PING 帧。若为 ACK，重置 pingSent 标志。
     */
    private func handlePingWithTimeout(header: Http2FrameHeader): Unit {
        handlePing(header)
        if ((header.flags & FLAG_ACK) != 0 && pingSent) {
            // 检查 PING 数据是否匹配
            let payload = readFramePayload(header)
            if (payload.size == 8 && arraysEqual(payload, sentPingData)) {
                pingSent = false
            }
        }
    }


    private func parseStatus(s: String): HttpStatus {
        let bytes = s.toArray()
        var code: UInt16 = 0
        for (b in bytes) {
            if (b >= b'0' && b <= b'9') {
                code = UInt16(Int64(code) * 10 + Int64(b - b'0'))
            }
        }
        HttpStatus(code)
    }

    private func parseMethod(s: String): HttpMethod {
        match (HttpMethod.parse(s)) {
            case Some(m) => m
            case None => HttpMethod.GET
        }
    }

    // ---- 公开辅助函数 ----

    public func isConnected(): Bool { connected && !goawayReceived.load() }
    public func isGoawayReceived(): Bool { goawayReceived.load() }
    /**
     * 设置对端最大帧大小用于测试目的。
     * 在生产环境中，这是在握手期间通过 SETTINGS 帧设置的。
     */
    public func setPeerMaxFrameSize(size: Int64): Unit { peerMaxFrameSize = size }
    /**
     * 从最后收到的 GOAWAY 帧获取调试数据。
     * 如果未收到 GOAWAY 或未发送调试数据，则返回空数组。
     */
    public func getGoawayDebugData(): Array<UInt8> { goawayDebugData }

    /**
     * 获取特定流的发送窗口。
     * 如果流不存在则返回 Int64_MAX（对于活动流不应发生）。
     */
    private func getStreamSendWindow(streamId: UInt32): Int64 {
        match (multiplexer.getStream(streamId)) {
            case Some(s) => s.sendWindow
            case None => 2147483647  // 未跟踪的流无限制
        }
    }

    /**
     * 发送流级 WINDOW_UPDATE 帧。
     * 当流的接收窗口需要补充时使用（RFC 9113 §6.9）。
     */
    private func sendStreamWindowUpdate(streamId: UInt32, increment: UInt32): Unit {
        let frame = buildStreamWindowUpdate(streamId, increment)
        sendFrame(frame)
    }

    // ---- 新帧类型处理（RFC 8336, RFC 7838, RFC 9218）----

    /**
     * 处理 ORIGIN 帧（RFC 8336）。
     * 服务器用于声明此连接对哪些 origin 具有权威性。
     */
    private func handleOrigin(header: Http2FrameHeader): Unit {
        let payload = readFramePayload(header)
        let origins = decodeOriginPayload(payload)
        peerOrigins.clear()
        for (o in origins) {
            peerOrigins.add(o)
        }
    }

    /**
     * 处理 ALTSVC 帧（RFC 7838）。
     * 通知客户端可用的替代服务（如 HTTP/3）。
     */
    private func handleAltSvc(header: Http2FrameHeader): Unit {
        let payload = readFramePayload(header)
        let (origin, fieldValue) = decodeAltSvcPayload(payload)
        peerAltSvc.add((origin, fieldValue))
    }

    /**
     * 处理 PRIORITY_UPDATE 帧（RFC 9218）。
     * 接收到的优先级更新通知写入调度器调整流优先级。
     */
   private func handlePriorityUpdate(header: Http2FrameHeader): Unit {
       let payload = readFramePayload(header)
       let (psid, fieldValue) = decodePriorityUpdatePayload(payload)
        if (psid == 0u32) { return }  // 连接级优先级更新暂不支持
        applyPriorityToStream(psid, fieldValue)
    }

    /**
     * 应用 Priority 信号到指定流（RFC 9218 §4）。
     * 支持来自 PRIORITY_UPDATE 帧和 Priority 头字段的优先级信号。
     */
    private func applyPriorityToStream(streamId: UInt32, priorityValue: Array<UInt8>): Unit {
        let (urgency, incremental) = parsePriorityFieldValue(priorityValue)
       let weight = urgencyToWeight(urgency)
        // RFC 9218 §4：incremental 标志表示流应尽快获取带宽（非公平共享）
        // 在权重调度中提升 incremental 流的优先级
        let effectiveWeight = if (incremental) {
            let w = Int64(weight) * 2
            if (w > 255) { 255u8 } else { UInt8(w) }
        } else { weight }
        writeSched.adjustStream(streamId, false, 0u32, effectiveWeight)
        multiplexer.updatePriority(streamId, false, 0u32, effectiveWeight)
    }

    /**
     * 获取对端声明的 ORIGIN 列表（RFC 8336）。
     */
    public func getPeerOrigins(): Array<String> {
        peerOrigins.toArray()
    }

    /**
     * 获取对端通告的 ALTSVC 列表（RFC 7838）。
     */
    public func getPeerAltSvc(): ArrayList<(String, Array<UInt8>)> {
        peerAltSvc
    }

    public func close(): Unit {
        // 发送 GOAWAY
        try {
            let goaway = buildGoawayFrame(multiplexer.getNextStreamId(), Http2ErrorCode.NO_ERROR)
            conn.write(goaway)
            conn.flush()
        } catch (_: Exception) {}
        // 刷新待处理数据 —— 为每个待处理流发送 RST_STREAM
        for ((sid, _) in pendingData) {
            try {
                let rstFrame = buildRstStreamFrame(sid, Http2ErrorCode.CANCEL)
                conn.write(rstFrame)
            } catch (_: Exception) {}
        }
        pendingData.clear()
        multiplexer.closeAll(Http2ErrorCode.NO_ERROR)
        connected = false
    }
    /**
     * Send tunnel data on a stream (RFC 8441 Extended CONNECT).
     * Data is sent as HTTP/2 DATA frames with flow control.
     */
    public func sendTunnelData(streamId: UInt32, data: Array<UInt8>): Unit {
        sendDataFrames(streamId, data)
    }

    /**
     * Read a single DATA frame from a tunnel stream (RFC 8441).
     * Blocks until a DATA frame for the stream arrives or the stream is closed.
     *
     * @param streamId  Tunnel stream ID
     * @return (data, endStream) Payload and end-of-stream flag
     */
    public func readStreamDataFrame(streamId: UInt32): (Array<UInt8>, Bool) {
        while (true) {
            let header = readFrameHeader()
            checkContinuationOrder(header)

            if (header.frameType == Http2FrameType.DATA && header.streamId == streamId) {
                let payload = readFramePayload(header)
                let endStream = (header.flags & FLAG_END_STREAM) != 0
                if (payload.size > 0) {
                    multiplexer.consumeStreamRecvWindow(streamId, payload.size)
                    replenishRecvWindows(streamId, payload.size)
                }
                return (payload, endStream)
            } else if (header.frameType == Http2FrameType.RST_STREAM && header.streamId == streamId) {
                return (Array<UInt8>(), true)
            } else if (header.frameType == Http2FrameType.GOAWAY) {
                return (Array<UInt8>(), true)
            } else if (header.frameType == Http2FrameType.WINDOW_UPDATE) {
                handleWindowUpdate(header)
            } else if (header.frameType == Http2FrameType.PING) {
                handlePing(header)
            }
        }
        return (Array<UInt8>(), true)
    }


}