package quic_cj

import quic_cj.protocol.{Version, VERSION_1, Perspective, ECN}
import quic_cj.core.{Connection, ConnectionState, newClientConnection}
import quic_cj.sys.{RawConn, newRawConn, StubRawConn}
import quic_cj.congestion.{CongestionAlgorithm, CubicSender, newCubicSender, NewRenoSender, newNewRenoSender}
import quic_cj.wire.parseHeader
import quic_cj.tls.{generateStatelessResetToken, STATELESS_RESET_TOKEN_SIZE}
import std.convert.*
import std.random.Random
import std.net.{IPAddress, IPv4Address}

/// HandlerFunc 是处理传入包的回调函数。
public type HandlerFunc = (Array<Byte>, String, Int64) -> Unit

/// 传输层 管理 UDP 监听器并创建 QUIC 连接。
public class Transport {
    private var addr: String = ""
    private var config: Config = Config()
    private var packetHandlers: Array<(Array<Byte>, HandlerFunc)> = []
    private var rawConn: RawConn = StubRawConn("", 0)
    private var noop: HandlerFunc = { data, addr, ts => () }
    private var _localAddr: IPAddress = IPv4Address(0, 0, 0, 0)

    public init(addr: String, config: Config) {
        this.addr = addr.trimAsciiStart().trimAsciiEnd()
        this.config = config
    }

    /// 为给定连接 ID 注册处理程序。
    public func setHandler(connId: Array<Byte>, handler: HandlerFunc): Bool {
        let n = packetHandlers.size
        var out = Array<(Array<Byte>, HandlerFunc)>(n + 1, repeat: (connId, noop))
        var i: Int64 = 0
        while (i < n) { out[i] = packetHandlers[i]; i += 1 }
        out[n] = (connId, handler)
        packetHandlers = out
        true
    }

    /// 查找给定连接 ID 的处理程序。
    private func getHandler(connId: Array<Byte>): Option<HandlerFunc> {
        var i: Int64 = 0
        while (i < packetHandlers.size) {
            let (cid, handler) = packetHandlers[i]
            if (cid.size == connId.size) {
                var j: Int64 = 0
                var isMatch = true
                while (j < cid.size) {
                    if (cid[j] != connId[j]) { isMatch = false; break }
                    j += 1
                }
                if (isMatch) { return Some(handler) }
            }
            i += 1
        }
        None
    }

    /// 构建设无状态重置包（RFC 9000 §10.3）。
    private func buildStatelessResetPacket(destConnId: Array<Byte>, token: Array<Byte>): Array<Byte> {
        // 短包头首字节
        let firstByte: UInt8 = 0x40u8
        let rand = Random()
        // 包体：首字节 + DCID + 随机填充 + 令牌
        let paddingLen: Int64 = if (destConnId.size >= 22) { 0 } else { 22 - destConnId.size }
        let totalLen = 1 + destConnId.size + paddingLen + STATELESS_RESET_TOKEN_SIZE
        var buf = Array<Byte>(totalLen, repeat: 0u8)
        buf[0] = firstByte
        var i: Int64 = 0
        while (i < destConnId.size) { buf[1 + i] = destConnId[i]; i += 1 }
        i = 0
        while (i < paddingLen) { buf[1 + destConnId.size + i] = UInt8(rand.nextInt64() & 0xFFi64); i += 1 }
        let tokenStart = 1 + destConnId.size + paddingLen
        i = 0
        while (i < STATELESS_RESET_TOKEN_SIZE) { buf[tokenStart + i] = token[i]; i += 1 }
        buf
    }

    /// 将传入的 UDP 包分派到正确的连接处理程序。
    public func handleReceivedPacket(data: Array<Byte>, addr: String, timeReceived: Int64): Unit {
        if (data.size < 1) { return }
        let (hdr, _) = parseHeader(data)
        let connId = hdr.destConnId
        if (let Some(handler) <- getHandler(connId)) {
            handler(data, addr, timeReceived)
        } else if (!hdr.isLongHeader && config.statelessResetKey.size == STATELESS_RESET_TOKEN_SIZE) {
            // 短包头包且无对应处理程序 → 发送无状态重置
            let token = generateStatelessResetToken(config.statelessResetKey, connId)
            let resetPkt = buildStatelessResetPacket(connId, token)
            rawConn.writePacket(resetPkt, addr, ECN.Unsupported)
        }
    }

    /// 获取底层 RawConn 引用。
    public func getRawConn(): RawConn { rawConn }

    /// 返回本地地址。
    public func localAddr(): IPAddress { _localAddr }

    /// 检查 RawConn 是否已初始化。
    public func isInitialized(): Bool {
        match (rawConn as StubRawConn) {
            case Some(_) => false
            case None => true
        }
    }

    /// 绑定 UDP 套接字（内部调用）。
    private func bindSocket(host: String, port: Int64): Unit {
        rawConn = newRawConn(host, port)
        _localAddr = rawConn.localAddr()
        if (rawConn is StubRawConn) {
            rawConn = StubRawConn(host, port)
            _localAddr = IPAddress.parse(host)
        }
    }

    /// 开始监听传入的 QUIC 连接。
    public func listen(): Option<Listener> {
        if (!config.validate()) { return None }
        let parts = addr.split(":")
        let host = if (parts.size > 0 && parts[0] != "") { parts[0] } else { "0.0.0.0" }
        let port = if (parts.size > 1) { Int64.parse(parts[1]) } else { 0 }
        bindSocket(host, port)
        let listener = ListenerImpl(addr, this)
        listener.setConfig(config)
        Some(listener)
    }

    /// 客户端拨号：创建并连接到指定的 QUIC 服务器。
    public func dial(addr: String): Option<Conn> {
        if (!config.validate()) { return None }
        let parts = addr.split(":")
        let host = if (parts.size > 0 && parts[0] != "") { parts[0] } else { "127.0.0.1" }
        let port = if (parts.size > 1) { Int64.parse(parts[1]) } else { 4433 }
        bindSocket(host, port)
        let srcConnId: Array<Byte> = [0x00u8, 0x01u8, 0x02u8, 0x03u8]
        let destConnId: Array<Byte> = [0x04u8, 0x05u8, 0x06u8, 0x07u8]
        let conn = Connection(VERSION_1, Perspective.Client, srcConnId, destConnId)
        conn.setMigrationDisabled(config.disableActiveMigration)
        conn.setMaxDatagramPayloadSize(config.maxDatagramFrameSize)
        if (config.congestionAlgorithm == CONGESTION_ALGORITHM_NEW_RENO) {
            conn.setCongestionAlgorithm(newNewRenoSender())
        } else {
            conn.setCongestionAlgorithm(newCubicSender())
        }
        match (config.tlsConfig) {
            case Some(tls) => conn.setTlsParams(tls.serverName, tls.alpn)
            case None => ()
        }
        let ci = ConnImpl(conn)
        ci.setRemoteAddr(addr)
        ci.setRawConn(rawConn)
        // 注册初始包处理程序（客户端使用完整的 destConnId 作为键）
        setHandler(destConnId, { data, raddr, ts =>
            let out = conn.handlePacket(data)
            if (out.size > 0) {
                rawConn.writePacket(out, raddr, ECN.Unsupported)
            }
        })
        // 对于客户端，如果配置了无状态重置密钥，生成并设置令牌
        if (config.statelessResetKey.size == STATELESS_RESET_TOKEN_SIZE) {
            let token = generateStatelessResetToken(config.statelessResetKey, destConnId)
            conn.setStatelessResetToken(token)
        }
        // 触发 ClientHello
        let out = conn.handlePacket([])
        if (out.size > 0) {
            rawConn.writePacket(out, addr, ECN.Unsupported)
        }
        Some(ci)
    }
}
