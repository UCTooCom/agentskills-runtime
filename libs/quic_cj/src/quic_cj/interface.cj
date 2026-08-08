package quic_cj

import quic_cj.protocol.{Version, Perspective, VERSION_1}
import quic_cj.stream.{Stream as QuicStream, SendStream, ReceiveStream}
import quic_cj.util.TransportErrorCode
import quic_cj.tls.ServerCryptoSetup
import quic_cj.congestion.CongestionAlgorithm
import quic_cj.core.PathEvent
import std.net.IPAddress

/// ConnectionState 描述 QUIC 连接的状态。
public class ConnState {
    public var version: Version = VERSION_1
    public var handshakeComplete: Bool = false
    public var perspective: Perspective = Perspective.Client
    public var srcConnId: Array<Byte> = []
    public var destConnId: Array<Byte> = []
}


/// Connection 是 QUIC 连接的接口。
open public class Conn {
    open public func openStream(): Option<QuicStream> {
        throw Exception("Conn.openStream: not implemented")
    }

    open public func openUniStream(): Option<SendStream> {
        throw Exception("Conn.openUniStream: not implemented")
    }

    open public func acceptStream(): Option<QuicStream> {
        throw Exception("Conn.acceptStream: not implemented")
    }

    open public func acceptUniStream(): Option<ReceiveStream> {
        throw Exception("Conn.acceptUniStream: not implemented")
    }

    open public func closeWithError(errorCode: TransportErrorCode, reason: String): Unit {
        throw Exception("Conn.closeWithError: not implemented")
    }

    open public func localAddr(): IPAddress {
        throw Exception("Conn.localAddr: not implemented")
    }

    open public func remoteAddr(): String {
        throw Exception("Conn.remoteAddr: not implemented")
    }

   open public func getConnState(): ConnState { ConnState() }

    /// 检查连接是否已关闭。
    open public func isClosed(): Bool {
        throw Exception("Conn.isClosed: not implemented")
    }

    /// 处理传入的 QUIC 包（RFC 9000 §7、§9）。
    /// 返回需要发送到对端的响应数据（如果有）。
    /// 调用者须将返回的数据写入 UDP 套接字。
    open public func handlePacket(data: Array<Byte>): Array<Byte> {
        throw Exception("Conn.handlePacket: not implemented")
    }

    /// 为当前 QUIC 连接执行初始化握手（客户端侧）。
    /// 生成并返回需要发送的第一个 Initial 包数据。
    /// 调用者须将此数据写入 UDP 套接字。
    open public func handshakeInit(): Array<Byte> {
        throw Exception("Conn.handshakeInit: not implemented")
    }

    /// 设置对端 UDP 地址（用于发回响应）。
    open public func setRemoteAddr(addr: String): Unit {
        throw Exception("Conn.setRemoteAddr: not implemented")
    }

    /// 设置连接级读取超时（毫秒）。0 表示不超时。
    /// 超时触发时连接将被关闭。
    open public func setReadTimeoutMs(ms: Int64): Unit {
        throw Exception("Conn.setReadTimeoutMs: not implemented")
    }

    /// 注册数据报接收回调。
    /// 当新数据报到达时，回调函数以数据报负载为参数被调用。
    /// 传递 None 表示取消注册。
    open public func setDatagramCallback(callback: ?(Array<Byte>) -> Unit): Unit {
        throw Exception("Conn.setDatagramCallback: not implemented")
    }
    /// 服务端 TLS：注入 ServerCryptoSetup 以处理服务端 TLS 1.3 握手。
    open public func setServerCryptoSetup(scs: ServerCryptoSetup): Unit {
        throw Exception("Conn.setServerCryptoSetup: not implemented")
    }

    /// 客户端 TLS：设置 TLS 服务器名称和 ALPN 列表。
    /// 在调用 handshakeInit() 前调用此方法以启用客户端 TLS 1.3 握手。
    open public func setTlsParams(serverName: String, alpn: Array<String>): Unit {
        throw Exception("Conn.setTlsParams: not implemented")
    }
    /// 检查 TLS 握手是否已完成。
    open public func isHandshakeComplete(): Bool {
        throw Exception("Conn.isHandshakeComplete: not implemented")
    }

    /// 发送不可靠数据报（RFC 9221）。
    /// 数据报按帧发送，不受流控限制（除连接级流控外）。
    /// 返回 false 表示数据报因拥塞或队列满被丢弃。
    open public func sendDatagram(data: Array<Byte>): Bool {
        throw Exception("Conn.sendDatagram: not implemented")
    }

    /// 接收到达的数据报。无可达数据报时返回 None。
    /// 数据报是无序的、不可靠的（RFC 9221 §5）。
    open public func receiveDatagram(): Option<Array<Byte>> {
        throw Exception("Conn.receiveDatagram: not implemented")
    }

    /// 获取当前 QUIC 连接的最大数据报负载大小（基于 PMTU 和传输参数）。
    open public func maxDatagramSize(): Int64 {
        throw Exception("Conn.maxDatagramSize: not implemented")
    }

    /// 获取当前待发送的数据报队列中等待的帧数量（用于背压）。
    open public func datagramSendQueue(): Int64 {
        throw Exception("Conn.datagramSendQueue: not implemented")
    }
    // ── Keep-Alive ──────────────────────────────────────────────
    
    /// 启用连接保活，指定保活间隔（毫秒）。
    /// 保活机制通过在空闲连接上定期发送 PING 帧来维持 NAT 绑定
    /// 和检测对端存活（RFC 9000 §10.1.2）。
    open public func enableKeepAlive(intervalMs: Int64): Unit {
        throw Exception("Conn.enableKeepAlive: not implemented")
    }
    
    /// 禁用连接保活。
    open public func disableKeepAlive(): Unit {
        throw Exception("Conn.disableKeepAlive: not implemented")
    }
    
    // ── 拥塞控制配置 ─────────────────────────────────────────
    
    /// 设置连接使用的拥塞控制算法。
    /// 必须在连接建立前调用。
    open public func setCongestionAlgorithm(algo: CongestionAlgorithm): Unit {
        throw Exception("Conn.setCongestionAlgorithm: not implemented")
    }
    
    // ── 连接迁移事件 ──────────────────────────────────────────
    
    /// PathEvent 描述连接路径变更事件的类型。
    /// 设置路径迁移事件处理器。
    /// 当路径验证、切换或超时时，回调函数被调用。
    /// 回调参数：事件类型、事件描述的新地址（如果是迁移或验证事件）。
    /// 传递 None 可移除已注册的处理器。
    open public func setPathMigrationHandler(callback: ?(PathEvent, String) -> Unit): Unit {
        throw Exception("Conn.setPathMigrationHandler: not implemented")
    }
    
    // ── 0-RTT 早期数据 ────────────────────────────────────────
    
    /// 检查连接是否能够发送 0-RTT 早期数据。
    /// 只有在客户端拥有有效的 PSK（预先共享密钥）且 TLS 配置
    /// 启用了早期数据时才可以发送（RFC 9000 §7.4.1）。
    open public func canSendEarlyData(): Bool {
        throw Exception("Conn.canSendEarlyData: not implemented")
    }
    
    /// 发送 0-RTT 早期数据。
    /// 在握手完成前调用此方法以发送早期数据。
    /// 返回 false 表示早期数据不可用（无 PSK 或未启用）。
    open public func sendEarlyData(data: Array<Byte>): Bool {
        throw Exception("Conn.sendEarlyData: not implemented")
    }
    
    /// 接收 0-RTT 早期数据（服务端侧）。
    /// 服务端在握手完成前调用此方法以接收客户端发送的早期数据。
    /// 无可用的早期数据时返回 None。
    open public func receiveEarlyData(): Option<Array<Byte>> {
        throw Exception("Conn.receiveEarlyData: not implemented")
    }
    
    /// 注册 0-RTT 早期数据到达回调（服务端侧）。
    /// 当收到 0-RTT 数据时，回调函数以数据负载为参数被调用。
    /// 传递 None 表示取消注册。
    open public func setEarlyDataCallback(callback: ?(Array<Byte>) -> Unit): Unit {
        throw Exception("Conn.setEarlyDataCallback: not implemented")
    }
}

/// Listener 接收传入的 QUIC 连接。
open public class Listener {
    open public func accept(): Option<Conn> {
        throw Exception("Listener.accept: not implemented")
    }

    open public func addr(): String {
        throw Exception("Listener.addr: not implemented")
    }

    open public func close(): Unit {
        throw Exception("Listener.close: not implemented")
    }
}
