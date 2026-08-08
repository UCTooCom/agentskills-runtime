/**
 * WebTransport over HTTP/3 (RFC 9220) 实现。
 *
 * WebTransport 在 HTTP/3 之上提供：
 * - 双向流通信（可靠、有序）
 * - 单向流通信（可靠、有序）
 * - QUIC 数据报通信（不可靠、无序）
 * - 胶囊协议数据报（不可靠、无序，作为 QUIC 数据报回退）
 *
 * 通过 Extended CONNECT 机制建立会话。
 * 会话建立后，客户端和服务端可使用流和数据报交换应用数据。
 *
 * @see https://www.rfc-editor.org/rfc/rfc9220
 */
package http_lib.http3

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, ProtocolException}
import http_lib.message.HttpRequest
import http_lib.message.HttpResponse

// ======== 会话级流控（RFC 9220 §4.1）========

/**
 * WebTransport 会话级流控。
 *
 * RFC 9220 §4.1：每个 WebTransport 会话拥有独立的流控窗口，
 * 防止单个会话消耗整个 QUIC 连接的流控额度。
 *
 * 会话级 MAX_DATA 帧携带 64 位窗口值，表示该会话允许对端发送的字节总数。
 * 收到 MAX_DATA 帧后，对端可在额度范围内发送 WS_DATA 帧中的数据。
 * 当接收端消耗了数据后，可以更新窗口并发送新的 MAX_DATA。
 *
 * @see https://www.rfc-editor.org/rfc/rfc9220#section-4.1
 */
public class SessionFlowController {
    /// 当前发送窗口（对端累计可发送的字节数）
    private var sendWindow: Int64 = 262144  // 256KB 初始窗口
    /// 已从本端视角发送的字节数（对端已收到的数据量）
    private var bytesSent: Int64 = 0
    /// 已从对端视角接收的字节数
    private var bytesReceived: Int64 = 0
    /// 本端可用的接收窗口初始值
    private var initialReceiveWindow: Int64 = 262144  // 256KB
    /// 本端接收窗口当前剩余值
    private var receiveWindow: Int64 = initialReceiveWindow
    /// 上次发出 MAX_DATA 时的字节计数
    private var lastMaxDataSent: Int64 = 0
    /// 当本端接收窗口消耗超过此比例时，发送 MAX_DATA 更新
    private var windowUpdateRatio: Float64 = 0.5
    private var mu: Mutex = Mutex()

    public init() {}

    /**
     * 对端是否还有额度发送数据。
     */
    public func canSend(): Bool {
        mu.lock()
        let result = bytesSent < sendWindow
        mu.unlock()
        result
    }

    /**
     * 记录发送了 n 字节（计入已使用额度）。
     */
    public func recordSent(n: Int64): Unit {
        mu.lock()
        bytesSent += n
        mu.unlock()
    }

    /**
     * 记录接收了 n 字节。
     */
    public func recordReceived(n: Int64): Unit {
        mu.lock()
        bytesReceived += n
        receiveWindow -= n
        mu.unlock()
    }

    /**
     * 本端是否需要发送新的 MAX_DATA 以更新对端的发送窗口。
     */
    public func needsMaxDataUpdate(): Bool {
        mu.lock()
        let consumed = bytesReceived - lastMaxDataSent
        let total = initialReceiveWindow
        let ratio = if (total > 0) { Float64(consumed) / Float64(total) } else { 1.0 }
        let result = ratio >= windowUpdateRatio
        mu.unlock()
        result
    }

    /**
     * 构造会话级 MAX_DATA 帧负载。
     * 返回最大字节数，供对端在本会话内发送。
     */
    public func buildMaxDataWindow(): UInt64 {
        mu.lock()
        let newWindow = bytesReceived + (initialReceiveWindow / 2)
        lastMaxDataSent = bytesReceived
        mu.unlock()
        UInt64(newWindow)
    }
}

/**
 * WebTransport 会话。
 *
 * 封装 Extended CONNECT 握手和流/数据报管理。
 * 建立成功后，通过 openStream()/sendDatagram() 进行通信。
 *
 * 流归属（RFC 9220 §3.1）：
 * 会话建立后，该会话的请求流（双向流）是会话的第一个流。
 * 该会话内的后续双向/单向流由应用层标识关联，而非自动绑定。
 * ownsStream() 方法提供可选的流归属检查，供上层逻辑使用。
 */
public class WebTransportSession {
    private var h3Conn: H3Connection
    private var quicConn: QuicConnection
    private var sessionStreamId: UInt64
    /// 已打开/接收的流 ID 集（用于归属验证）
    private var ownedStreamIds: ArrayList<UInt64> = ArrayList<UInt64>()
    private var established: Bool = false
    private var closed: Bool = false
    private var incomingStreams: ArrayList<QuicStream> = ArrayList<QuicStream>()
    private var path: String
    private var origin: String
    private var handshakeStreamId: UInt64 = 0
    /// 会话级流控
    public var flowController: SessionFlowController = SessionFlowController()
    /// 胶囊数据报缓冲区（用于接收回退路径的数据报）
    private var capsuleDatagramBuffer: ArrayList<Array<UInt8>> = ArrayList<Array<UInt8>>()
    /// 胶囊协议是否开启
    private var capsuleProtocolEnabled: Bool = true

    public init(
        h3Conn: H3Connection,
        quicConn: QuicConnection,
        sessionStreamId: UInt64,
        path: String,
        origin: String
    ) {
        this.h3Conn = h3Conn
        this.quicConn = quicConn
        this.sessionStreamId = sessionStreamId
        this.path = path
        this.origin = origin
    }

    /**
     * 获取会话是否已建立。
     */
    public func isEstablished(): Bool { established }

    /**
     * 获取会话是否已关闭。
     */
    public func isClosed(): Bool { closed }

    /**
     * 标记会话为已建立（收到 200 响应后调用）。
     */
    public func markEstablished(): Unit {
        established = true
    }
    
    /**
     * 执行 WebTransport 握手（客户端侧）。
     * 发送 Extended CONNECT 请求并等待 200 响应。
     * @param req CONNECT 请求，必须包含 :protocol: webtransport
     * @return 握手成功返回 true
     */
    public func handshake(req: HttpRequest): Bool {
        if (established || closed) { return false }
        if (req.method != HttpMethod.CONNECT) { return false }
        let protoOk = match (req.headers.get(":protocol")) {
            case Some(v) => v == "webtransport"
            case None => match (req.headers.get("protocol")) {
                case Some(v) => v == "webtransport"
                case None => false
            }
        }
        if (!protoOk) { return false }
        match (h3Conn.sendRequest(req)) {
            case Some(sid) =>
                handshakeStreamId = sid
                sessionStreamId = sid
                match (h3Conn.recvResponse(sessionStreamId)) {
                    case Some(resp) =>
                        if (resp.status.code == 200) {
                            established = true
                            recordSessionStream(handshakeStreamId)
                            true
                        } else { false }
                    case None => false
                }
            case None => false
        }
    }
    
    /**
     * 标记会话为已建立（服务端侧带流 ID 版本）。
     * 服务端在收到 CONNECT 请求并发送 200 响应后调用此方法，
     * 记录使用的流 ID 并激活会话。
     */
    public func markEstablished(sid: UInt64): Unit {
        sessionStreamId = sid
        established = true
        recordSessionStream(sid)
    }

    /// 记录一条流为会话所属（RFC 9220 §3.1 流归属）。
    private func recordSessionStream(streamId: UInt64): Unit {
        ownedStreamIds.add(streamId)
    }

    /**
     * 获取会话的主流 ID（CONNECT 请求流）。
     */
    public func getSessionStreamId(): UInt64 { sessionStreamId }

    /**
     * 检查给定的流 ID 是否属于此会话（RFC 9220 §3.1）。
     *
     * 流归属逻辑：
     * - 会话的 CONNECT 请求流（sessionStreamId）归属此会话
     * - 通过 openBidirectionalStream/openUnidirectionalStream 打开的流归属此会话
     * - 通过 addIncomingStream 加入的流归属此会话
     */
    public func ownsStream(streamId: UInt64): Bool {
        for (id in ownedStreamIds) {
            if (id == streamId) { return true }
        }
        false
    }

    /**
     * 打开一条 WebTransport 双向流。
     * 实际在底层 QUIC 连接上打开一条双向流，
     * 用于在该会话内传输可靠数据。
     *
     * @return 新打开的 QUIC 流，失败时返回 None
     */
    public func openBidirectionalStream(): ?QuicStream {
        if (closed) { return None }
        let stream = quicConn.openStream()
        match (stream) {
            case Some(s) =>
                recordSessionStream(s.getStreamId())
                stream
            case None => None
        }
    }

    /**
     * 打开一条 WebTransport 单向流。
     *
     * @return 新打开的 QUIC 单向流，失败时返回 None
     */
    public func openUnidirectionalStream(): ?QuicStream {
        if (closed) { return None }
        let stream = quicConn.openUnidirectionalStream()
        match (stream) {
            case Some(s) =>
                recordSessionStream(s.getStreamId())
                stream
            case None => None
        }
    }

    /**
     * 接收该会话内的一条入站双向流。
     *
     * @return 入站的 QUIC 流，无可用流时返回 None
     */
    public func acceptStream(): ?QuicStream {
        if (closed) { return None }
        // 首先检查已缓冲的入站流
        if (incomingStreams.size > 0) {
            let s = incomingStreams[0]
            incomingStreams.remove(0..1)
            return Some(s)
        }
        quicConn.acceptStream()
    }

    /**
     * 添加一条入站流到会话的待处理队列。
     * 由 H3Connection 在新流到达时调用。
     */
    public func addIncomingStream(stream: QuicStream): Unit {
        incomingStreams.add(stream)
        recordSessionStream(stream.getStreamId())
    }

    /**
     * 通过 WebTransport 会话发送不可靠数据报。
     * 底层优先使用 QUIC DATAGRAM 帧（RFC 9221），
     * 不可用时回退到胶囊协议 DATAGRAM（RFC 9297）。
     *
     * @param data  要发送的数据报负载
     * @return 发送成功返回 true，因队列满或拥塞被丢弃时返回 false
     */
    public func sendDatagram(data: Array<UInt8>): Bool {
        if (closed) { return false }
        // 优先使用 QUIC DATAGRAM (RFC 9221)
        if (quicConn.sendDatagram(data)) {
            return true
        }
        // 回退：使用 DATAGRAM 胶囊（RFC 9297）通过 QUIC 流传输
        sendCapsuleDatagram(data)
    }

    /**
     * 通过胶囊协议发送数据报（QUIC DATAGRAM 不可用时的回退路径）。
     * 将数据封装为 DATAGRAM 胶囊（RFC 9297 §5），
     * 通过会话流 DATA 帧发送。
     */
    public func sendCapsuleDatagram(data: Array<UInt8>): Bool {
        try {
            let capsule = buildDatagramCapsule(data)
            let rawData = encodeH3Capsule(capsule)
            h3Conn.sendTunnelData(sessionStreamId, rawData)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 从 WebTransport 会话接收不可靠数据报。
     * 先尝试 QUIC DATAGRAM，不可用时检查胶囊协议缓冲区。
     *
     * @return 接收到的数据报负载，无可用数据报时返回 None
     */
    public func receiveDatagram(): ?Array<UInt8> {
        if (closed) { return None }
        // 先尝试 QUIC DATAGRAM
        match (quicConn.receiveDatagram()) {
            case Some(dg) => return Some(dg)
            case None => ()
        }
        // 回退：检查胶囊数据报缓冲区
        receiveCapsuleDatagram()
    }

    /**
     * 从胶囊数据报缓冲区接收一个 DATAGRAM 胶囊。
     */
    public func receiveCapsuleDatagram(): ?Array<UInt8> {
        if (capsuleDatagramBuffer.size > 0) {
            let dg = capsuleDatagramBuffer[0]
            capsuleDatagramBuffer.remove(0..1)
            return Some(dg)
        }
        None
    }

    /**
     * 关闭 WebTransport 会话。
     * 发送 CLOSE 胶囊并关闭关联的流和数据报通道。
     */
    public func close(): Unit {
        if (closed) { return }
        closed = true
        established = false
        ownedStreamIds = ArrayList<UInt64>()
        try {
            h3Conn.closeTunnel(sessionStreamId)
        } catch (_: Exception) {}
        // 发送 CLOSE 胶囊（RFC 9297）
        try {
            let closeCapsule = buildCloseCapsule()
            let rawData = encodeH3Capsule(closeCapsule)
            h3Conn.sendTunnelData(sessionStreamId, rawData)
        } catch (_: Exception) {}
    }

    /**
     * 启用/禁用胶囊协议数据报。
     */
    public func setCapsuleProtocolEnabled(enabled: Bool): Unit {
        capsuleProtocolEnabled = enabled
    }

    /**
     * 处理从 QUIC 流到达的胶囊协议数据。
     * 由 H3Connection 在接收 DATA 帧时调用。
     */
    public func onCapsuleData(data: Array<UInt8>): Unit {
        try {
            let capsule = decodeH3Capsule(data)
            match (capsule.capsuleType) {
                case H3CapsuleType.DATAGRAM =>
                    capsuleDatagramBuffer.add(capsule.payload)
                case H3CapsuleType.CLOSE => ()
                case _ => ()
            }
        } catch (_: Exception) {}
    }

    /**
     * 获取 WebTransport 会话路径。
     */
    public func getPath(): String { path }

    /**
     * 获取 WebTransport 会话来源。
     */
    public func getOrigin(): String { origin }

    /**
     * 获取已归属的流 ID 列表。
     */
    public func getOwnedStreamIds(): ArrayList<UInt64> { ownedStreamIds }
}
