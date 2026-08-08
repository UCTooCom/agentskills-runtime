package quic_cj

import quic_cj.core.Connection
import quic_cj.core.{ConnectionState as CoreConnState}
import quic_cj.protocol.{Perspective, Version, StreamType, ECN}
import quic_cj.stream.{Stream as QuicStream, SendStream, ReceiveStream}
import quic_cj.util.TransportErrorCode
import quic_cj.sys.{RawConn, StubRawConn}
import quic_cj.tls.ServerCryptoSetup
import std.time
import quic_cj.core.PathEvent
import quic_cj.congestion.CongestionAlgorithm
import std.net.IPAddress


/// ConnImpl 将 core::Connection 包装为 Conn，用于传输/API 层。
public class ConnImpl <: Conn {
    private var inner: Connection
    private var _remoteAddr: String = ""
    private var _rawConn: RawConn = StubRawConn("", 0)
    private var _readTimeoutMs: Int64 = 0
    private var _datagramCallback: ?(Array<Byte>) -> Unit = None

    public init(conn: Connection) {
        inner = conn
    }

    override public func openStream(): Option<QuicStream> {
        inner.openStream()
    }

    override public func openUniStream(): Option<SendStream> {
        if (let Some(s) <- inner.openStream()) {
            Some(s.getSendStream())
        } else {
            None
        }
    }

    override public func acceptStream(): Option<QuicStream> {
        inner.acceptStream()
    }

    override public func acceptUniStream(): Option<ReceiveStream> {
        if (let Some(stream) <- inner.acceptUniStream()) {
            Some(stream)
        } else {
            None
        }
    }

    override public func closeWithError(errorCode: TransportErrorCode, reason: String): Unit {
        inner.closeWithError(errorCode, reason)
    }

    override public func localAddr(): IPAddress {
        inner.localAddr()
    }

    override public func remoteAddr(): String {
        _remoteAddr
    }

    /// 连接是否已关闭。
    override public func isClosed(): Bool {
        inner.isClosed()
    }

    override public func handlePacket(data: Array<Byte>): Array<Byte> {
        let out = inner.handlePacket(data)
        // 如果有数据需要发送，写入 UDP 套接字
        if (out.size > 0 && _remoteAddr != "") {
            let _ = _rawConn.writePacket(out, _remoteAddr, ECN.Unsupported)
        }
        out
    }

    override public func handshakeInit(): Array<Byte> {
        // 客户端侧：触发初始密钥派生并构建 ClientHello
        if (inner.getVersion() != 0u32) {
            inner.enableCrypto()
            let outgoing = inner.handlePacket([])
            if (outgoing.size > 0 && _remoteAddr != "") {
                let _ = _rawConn.writePacket(outgoing, _remoteAddr, ECN.Unsupported)
            }
            return outgoing
        }
        []
    }

    override public func setRemoteAddr(addr: String): Unit {
        _remoteAddr = addr.trimStart().trimEnd()
    }

    /// 设置连接级读取超时（毫秒）。0 表示不超时。
    override public func setReadTimeoutMs(ms: Int64): Unit {
        _readTimeoutMs = ms
    }

    /// 注册数据报接收回调。
    override public func setDatagramCallback(callback: ?(Array<Byte>) -> Unit): Unit {
        _datagramCallback = callback
    }
    /// 服务端 TLS：注入 ServerCryptoSetup 以处理服务端 TLS 1.3 握手。
    override public func setServerCryptoSetup(scs: ServerCryptoSetup): Unit {
        inner.setServerCryptoSetup(scs)
    }
    /// TLS 握手是否已完成（连接处于 Handshake 或 Established 状态）。

    /// 客户端 TLS：设置 TLS 服务器名称（SNI）和 ALPN 列表。
    /// 调用 handshakeInit() 前调用此方法以启用客户端 TLS 握手。
    override public func setTlsParams(serverName: String, alpn: Array<String>): Unit {
        inner.setTlsParams(serverName, alpn)
    }
    override public func isHandshakeComplete(): Bool {
        let state = inner.getState()
        match (state) {
            case CoreConnState.Handshake => true
            case CoreConnState.Established => true
            case _ => false
        }
    }
    /// 等待握手完成，最多等待 timeoutMs 毫秒。
    /// 在 ClientHello 发送后调用此方法，循环处理入站包直至握手完成。
    public func waitForHandshake(timeoutMs: Int64): Bool {
        let deadline = if (timeoutMs <= 0) { 9223372036854775807 } else { timeoutMs }
        var elapsed: Int64 = 0
        while (elapsed < deadline) {
            if (isHandshakeComplete()) { return true }
            // 注：实际 I/O 循环由调用方驱动（feedPacket / run）
            // 此方法仅检查状态；调用方应在每次 feedPacket 后调用此方法
            sleep(Duration.millisecond * 10)
            elapsed += 10
        }
        isHandshakeComplete()
    }

    override public func sendDatagram(data: Array<Byte>): Bool {
        inner.sendDatagram(data)
    }

    override public func receiveDatagram(): Option<Array<Byte>> {
        inner.receiveDatagram()
    }

    override public func maxDatagramSize(): Int64 {
        inner.getMaxDatagramPayloadSize()
    }

    override public func datagramSendQueue(): Int64 {
        inner.datagramSendQueue()
    }
    
    // ── Keep-Alive ──────────────────────────────────────────────
    
    override public func enableKeepAlive(intervalMs: Int64): Unit {
        inner.enableKeepAlive(intervalMs)
    }
    
    override public func disableKeepAlive(): Unit {
        inner.disableKeepAlive()
    }
    
    // ── 拥塞控制配置 ─────────────────────────────────────────
    
    override public func setCongestionAlgorithm(algo: CongestionAlgorithm): Unit {
        inner.setCongestionAlgorithm(algo)
    }
    
    // ── 连接迁移事件 ──────────────────────────────────────────
    
    override public func setPathMigrationHandler(callback: ?(PathEvent, String) -> Unit): Unit {
        inner.setPathMigrationCallback(callback)
    }
    
    // ── 0-RTT 早期数据 ────────────────────────────────────────
    
    override public func canSendEarlyData(): Bool {
        inner.canSendEarlyData()
    }
    
    override public func sendEarlyData(data: Array<Byte>): Bool {
        inner.sendEarlyData(data)
    }
    
    override public func receiveEarlyData(): Option<Array<Byte>> {
        inner.receiveEarlyData()
    }
    
    override public func setEarlyDataCallback(callback: ?(Array<Byte>) -> Unit): Unit {
        inner.setEarlyDataRcvCallback(callback)
    }
    
    /// 设置底层 UDP RawConn。
    public func setRawConn(conn: RawConn): Unit {
        _rawConn = conn
    }

    /// 获取底层 UDP RawConn。
    public func getRawConn(): RawConn { _rawConn }

    override public func getConnState(): ConnState {
        let state = inner.getState()
        let cs = ConnState()
        cs.version = inner.getVersion()
        cs.handshakeComplete = match (state) {
            case CoreConnState.Handshake => true
            case CoreConnState.Established => true
            case _ => false
        }
        cs.perspective = match (state) {
            case CoreConnState.Initial => inner.getPerspective()
            case _ => inner.getPerspective()
        }
        cs.srcConnId = inner.getSrcConnId()
        cs.destConnId = inner.getDestConnId()
        cs
    }
}
