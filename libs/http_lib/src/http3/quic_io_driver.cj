/**
 * QUIC I/O 驱动 — 服务器端和客户端的 UDP 循环。
 *
 * 在 quic_cj 的 RFC 9000 协议层之上，提供：
 * - 带 Mutex 的线程安全连接包装
 * - 服务器端：UDP 读取循环、包路由、写出站数据
 * - 客户端：UDP 拨号、握手发起、I/O 循环
 *
 * @see RFC 9000 (QUIC), RFC 9114 (HTTP/3)
 */
package http_lib.http3

import std.collection.HashMap
import std.sync.{Mutex, AtomicBool}
import quic_cj.{Conn, ConnImpl}
import quic_cj.core.{Connection as QuicCoreConnection, ConnectionState}
import quic_cj.protocol.{Perspective, Version, VERSION_1, VERSION_2, chooseSupportedVersion, ECN}
import quic_cj.stream.{Stream as QStream}
import quic_cj.sys.{RawConn, newRawConn, ReceivedPacket}
import quic_cj.wire.{parseHeader, Header}
import quic_cj.tls.{ServerCryptoSetup, parseEcPrivateKeyFromPem, parseRsaPrivateKeyFromPem}
import std.fs.{File, Path}
import jinguissl_core.crypto.x509.{x509ParsePemChain}
import std.time.DateTime
import http_lib.utils.{hexEncode}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, ProtocolException}
import http_lib.message.{HttpRequest, HttpResponse}


// ======== 十六进制工具 ========



// ======== 线程安全的 QUIC 连接包装 ========

/**
 * 包装 quic_cj.Conn + Mutex，同时实现 QuicConnection 接口
 * 和 feedPacket() 供 I/O 驱动使用。
 */
public class H3QuicIoConnection <: QuicConnection {
    private var conn: Conn
    private var mu: Mutex = Mutex()
    private var _remoteAddr: String = ""
    private var _closed: Bool = false
    private var migrationHandler: ?(String) -> Unit = None
    private var _readTimeoutDuration: Duration = Duration.millisecond * 0  // 读取超时时长，Duration.millisecond * 0 = 不超时
    private var _writeTimeoutDuration: Duration = Duration.millisecond * 0  // 写入超时时长
    private var _lastActivity: DateTime = DateTime.now()  // 上次 I/O 活动时间
    private var _lastWriteActivity: DateTime = DateTime.now()  // 上次写入活动时间
    private var _datagramCallback: ?(Array<UInt8>) -> Unit = None

    public init(conn: Conn) {
        this.conn = conn
    }

    public static func fromConn(c: Conn): H3QuicIoConnection {
        H3QuicIoConnection(c)
    }

    // ======== 包级 I/O ========

    public func feedPacket(data: Array<Byte>): Array<Byte> {
        mu.lock()
        // 检查读写超时
        let now = DateTime.now()
        if (_readTimeoutDuration > Duration.millisecond * 0) {
            if (now - _lastActivity > _readTimeoutDuration) {
                _closed = true
                mu.unlock()
                return []
            }
        }
        // 检查写入超时
        if (_writeTimeoutDuration > Duration.millisecond * 0) {
            if (now - _lastWriteActivity > _writeTimeoutDuration) {
                _closed = true
                mu.unlock()
                return []
            }
        }
        let result = conn.handlePacket(data)
        _lastActivity = now
        mu.unlock()
        // 数据包到达后轮询数据报回调
        match (_datagramCallback) {
            case Some(cb) =>
                match (conn.receiveDatagram()) {
                    case Some(dg) => cb(dg)
                    case None => ()
                }
            case None => ()
        }
        result
    }
    public func handshakeInit(): Array<Byte> {
        mu.lock()
        let result = conn.handshakeInit()
        mu.unlock()
        result
    }

    public func setRemoteAddr(addr: String): Unit {
        mu.lock()
        _remoteAddr = addr
        if (!addr.isEmpty()) {
            conn.setRemoteAddr(addr)
        }
        mu.unlock()
    }

    // ======== QuicConnection 接口 ========

    public func openStream(): ?QuicStream {
        mu.lock()
        match (conn.openStream()) {
            case Some(s) =>
                mu.unlock()
                Some(AdapterQuicStream(s))
            case None =>
                mu.unlock()
                None
        }
    }

    public func openUnidirectionalStream(): ?QuicStream {
        mu.lock()
        match (conn.openUniStream()) {
            case Some(s) =>
                mu.unlock()
                Some(AdapterSendStream(s))
            case None =>
                mu.unlock()
                None
        }
    }

    public func acceptStream(): ?QuicStream {
        mu.lock()
        match (conn.acceptStream()) {
            case Some(s) =>
                mu.unlock()
                Some(AdapterQuicStream(s))
            case None =>
                mu.unlock()
                None
        }
    }

    public func acceptUnidirectionalStream(): ?QuicStream {
        mu.lock()
        match (conn.acceptUniStream()) {
            case Some(s) =>
                mu.unlock()
                Some(AdapterReceiveStream(s))
            case None =>
                mu.unlock()
                None
        }
    }

    public func closeWithError(errorCode: QuicErrorCode, message: String): Unit {
        mu.lock()
        _closed = true
        let code: UInt64 = UInt64(errorCode.toUInt16())
        conn.closeWithError(code, message)
        mu.unlock()
    }

    public func close(): Unit {
        mu.lock()
        _closed = true
        conn.closeWithError(0u64, "closed")
        mu.unlock()
    }

    /// 获取当前连接的源连接 ID。
    /// 用于握手后更新路由表。
    public func getCurrentSrcConnId(): Array<Byte> {
        mu.lock()
        let state = conn.getConnState()
        mu.unlock()
        state.srcConnId
    }

    public func isClosed(): Bool {
        mu.lock()
        let c = _closed
        mu.unlock()
        c
    }

    public func getRemoteAddr(): String {
        mu.lock()
        let addr = _remoteAddr
        mu.unlock()
        addr
    }

    public func setReadTimeout(timeout: Duration): Unit {
        mu.lock()
        _readTimeoutDuration = timeout
        mu.unlock()
    }
    public func getConnectionId(): ?Array<UInt8> {
        mu.lock()
        let state = conn.getConnState()
        mu.unlock()
        if (state.srcConnId.size == 0) { return None }
        Some(state.srcConnId)
    }

    public func migrateTo(addr: String): Bool {
        mu.lock()
        _remoteAddr = addr
        conn.setRemoteAddr(addr)
        mu.unlock()
        true
    }

    public func setPathMigrationHandler(handler: (String) -> Unit): Unit {
        mu.lock()
        migrationHandler = Some(handler)
        mu.unlock()
    }

    public func getVersion(): QuicVersion {
        mu.lock()
        let state = conn.getConnState()
        mu.unlock()
        QuicVersion.fromUInt32(state.version)
    }

    public func sendDatagram(data: Array<UInt8>): Bool {
        mu.lock()
        let result = conn.sendDatagram(data)
        mu.unlock()
        result
    }

    public func receiveDatagram(): ?Array<UInt8> {
        mu.lock()
        let result = conn.receiveDatagram()
        mu.unlock()
        result
    }

    /// TLS 握手是否已完成（连接是否已完全加密）。
    public func isHandshakeComplete(): Bool {
        mu.lock()
        let result = conn.isHandshakeComplete()
        mu.unlock()
        result
    }

    public func setDatagramCallback(callback: (Array<UInt8>) -> Unit): Unit {
        mu.lock()
        _datagramCallback = Some(callback)
        mu.unlock()
    }

    public func maxDatagramSize(): Int64 {
        mu.lock()
        let result = conn.maxDatagramSize()
        mu.unlock()
        result
    }

    public func datagramSendQueue(): Int64 {
        mu.lock()
        let result = conn.datagramSendQueue()
        mu.unlock()
        result
    }

    // ======== 0-RTT 数据传输（RFC 9000 §7.4.1）========

    public func canSendEarlyData(): Bool {
        mu.lock()
        let result = conn.canSendEarlyData()
        mu.unlock()
        result
    }

    public func sendEarlyData(data: Array<UInt8>): Bool {
        mu.lock()
        let result = conn.sendEarlyData(data)
        mu.unlock()
        result
    }

    public func receiveEarlyData(): ?Array<UInt8> {
        mu.lock()
        let result = conn.receiveEarlyData()
        mu.unlock()
        result
    }

    public func setEarlyDataCallback(callback: ?(Array<UInt8>) -> Unit): Unit {
        mu.lock()
        conn.setEarlyDataCallback(callback)
        mu.unlock()
    }
}

// ======== 连接路由 ========

internal class ConnectionRouter {
    private var connById: HashMap<String, H3QuicIoConnection> = HashMap<String, H3QuicIoConnection>()
    private var addrByConnId: HashMap<String, String> = HashMap<String, String>()
    private var mu: Mutex = Mutex()
    public var tlsConfig: H3TlsConfig = H3TlsConfig()
    /// 服务端 TLS 处理器工厂：传入连接 ID 返回 ServerCryptoSetup 实例
    /// 若未设置，服务端不会启用加密（仅用于测试/开发）
    private var serverCryptoFactory: ?(Array<Byte>) -> ServerCryptoSetup = None
    public func setTlsConfig(cfg: H3TlsConfig): Unit { tlsConfig = cfg }

    /// 设置服务端 TLS 处理器工厂。
    /// factory 接收连接 ID 并返回配置好的 ServerCryptoSetup 实例。
    public func setServerCryptoFactory(factory: (Array<Byte>) -> ServerCryptoSetup): Unit {
        serverCryptoFactory = Some(factory)
    }


    public func getOrCreateConn(pkt: ReceivedPacket, isServer: Bool): (H3QuicIoConnection, Bool) {
        if (pkt.data.size < 1) { return (H3QuicIoConnection(Conn()), false) }

        let (hdr, _) = parseHeader(pkt.data)
        let connIdKey = hexEncode(hdr.destConnId)

        mu.lock()
        match (connById.get(connIdKey)) {
            case Some(existing) =>
                mu.unlock()
                return (existing, true)
            case None =>
                if (!isServer) {
                    mu.unlock()
                    return (H3QuicIoConnection(Conn()), false)
                }

                // 版本协商（RFC 9369）：支持 V1 和 V2
                let ourVersions: Array<Version> = [VERSION_1, VERSION_2]
                let chosenVer = match (chooseSupportedVersion(ourVersions, [hdr.version])) {
                    case Some(v) => v
                    case None => VERSION_1
                }

                let coreConn = QuicCoreConnection(
                    chosenVer, Perspective.Server,
                    hdr.destConnId,
                    hdr.srcConnId
                )
                coreConn.setState(ConnectionState.Handshake)
                // 注入服务端 TLS 处理器（若已配置工厂）
                match (serverCryptoFactory) {
                    case Some(factory) =>
                        let scs = factory(hdr.destConnId)
                        coreConn.setServerCryptoSetup(scs)
                    case None => ()
                }

                let connImpl = ConnImpl(coreConn)
                let wrapper = H3QuicIoConnection.fromConn(connImpl)
                wrapper.setRemoteAddr(pkt.remoteAddr)

                connById[connIdKey] = wrapper
                addrByConnId[connIdKey] = pkt.remoteAddr
                mu.unlock()
                (wrapper, false)
        }
    }

    public func getConnByConnId(connId: Array<Byte>): ?H3QuicIoConnection {
        let key = hexEncode(connId)
        mu.lock()
        let result = connById.get(key)
        mu.unlock()
        result
    }

    public func removeConn(connId: Array<Byte>): Unit {
        let key = hexEncode(connId)
        mu.lock()
        connById.remove(key)
        addrByConnId.remove(key)
        mu.unlock()
    }

    /// 注册连接 ID 别名。
    /// 当服务端在握手后更换连接 ID 时，用此方法注册新 ID。
    public func updateConnIdAlias(oldConnId: Array<Byte>, newConnId: Array<Byte>): Unit {
        let oldKey = hexEncode(oldConnId)
        let newKey = hexEncode(newConnId)
        if (oldKey == newKey) { return }
        mu.lock()
        match (connById.get(oldKey)) {
            case Some(wrapper) =>
                connById[newKey] = wrapper
                match (addrByConnId.get(oldKey)) {
                    case Some(addr) => addrByConnId[newKey] = addr
                    case None => ()
                }
            case None => ()
        }
        mu.unlock()
    }

}

// ======== 服务器 QUIC 驱动 ========

public class QuicServerDriver {
    private var rawConn: RawConn
    private var router: ConnectionRouter = ConnectionRouter()
    private var running: AtomicBool = AtomicBool(false)
    private var host: String
    private var port: UInt16
    private var h3Handler: (HttpRequest) -> HttpResponse
    private var h3Config: Http3ServerConfig

    public init(host: String, port: UInt16,
                handler: (HttpRequest) -> HttpResponse,
                tlsConfig!: H3TlsConfig = H3TlsConfig(),
                config!: Http3ServerConfig = Http3ServerConfig()) {
        this.host = host
        this.port = port
        this.h3Handler = handler
        this.h3Config = config
        this.rawConn = newRawConn(host, Int64(port))
        this.router.setTlsConfig(tlsConfig)
    }

    private func setupServerTlsFactory(): Unit {
        let tlsCfg = router.tlsConfig
        if (tlsCfg.serverCertPath.size == 0 || tlsCfg.serverKeyPath.size == 0) {
            return
        }
        try {
            let certPem = String.fromUtf8(File.readFrom(Path(tlsCfg.serverCertPath)))
            let certObjs = x509ParsePemChain(certPem)
            var certChain: Array<Array<Byte>> = Array(certObjs.size, repeat: [])
            for (idx in 0..certObjs.size) {
                certChain[idx] = certObjs[idx].der
            }
            if (certChain.size == 0) {
                println("[QuicServerDriver] 警告: 无法解析证书链，跳过 TLS")
                return
            }

            // 解析 PEM 私钥（支持 PKCS#8 和传统格式）
            let keyPem = String.fromUtf8(File.readFrom(Path(tlsCfg.serverKeyPath)))
            // quic_cj 已在 pem.cj 中提供 EC/RSA 私钥 PEM 解析
            let ecdsaKey = parseEcPrivateKeyFromPem(keyPem)
            let rsaKey = parseRsaPrivateKeyFromPem(keyPem)

            println("[QuicServerDriver] 服务器证书已加载: " + tlsCfg.serverCertPath)
            println("[QuicServerDriver] 服务器密钥已加载: " + tlsCfg.serverKeyPath)
            let chainRef = certChain
            let ecdsaRef = ecdsaKey
            let rsaRef = rsaKey
            router.setServerCryptoFactory({ connId =>
                ServerCryptoSetup(connId, false, chainRef,
                    ecdsaPrivate: ecdsaRef,
                    rsaPrivate: rsaRef,
                    alpn: ["h3", "h3-29"])
            })
            println("[QuicServerDriver] 服务端 TLS 工厂已配置")
        } catch (e: Exception) {
            println("[QuicServerDriver] 无法加载 TLS 证书/密钥: ${e.message}. 跳过 TLS。")
        }
    }
    public func serve(): Unit {
        // 加载服务端 TLS 证书（若已配置）
        setupServerTlsFactory()
        running.store(true)
        while (running.load()) {
            try {
                let pkt = rawConn.readPacket()
                if (pkt.data.size < 1) { continue }

                let (hdr, _) = parseHeader(pkt.data)
                let connIdKey = hexEncode(hdr.destConnId)

                let (wrapper, exists) = router.getOrCreateConn(pkt, true)
                if (!exists) {
                    let handlerFn = h3Handler
                    let http3Config = h3Config.toHttp3Config()
                    let connConfig = H3ConnectionConfig.from(http3Config)
                    let h3Quic = wrapper
                    spawn {
                        try {
                            let h3Conn = H3Connection(
                                h3Quic,
                                config: connConfig,
                                isServer: true
                            )
                            h3Conn.setRequestHandler(handlerFn)
                            h3Conn.sendSettings()
                            while (h3Conn.isConnected()) {
                                // 优先检查 WebTransport 会话
                                    match (h3Conn.acceptWebTransport()) {
                                        case Some(wtSession) =>
                                            // WebTransport 会话已由 acceptRequest() 内部处理
                                            // 应用层可通过 wtSession 进行后续通信
                                            continue
                                        case None =>
                                            match (h3Conn.acceptRequest()) {
                                                case Some(req) =>
                                                    if (H3Connection.isWebTransportRequest(req)) {
                                                        // WebTransport 请求已被 acceptRequest() 内部处理并路由到会话注册表
                                                        // 此处不再需要手动创建 WebTransportSession
                                                        // 调用方可通过 h3Conn.acceptWebTransport() 获取会话
                                                        // 标记流 ID 用于完整性
                                                        let wtSid: UInt64 = match (req.metadata) {
                                                            case Some(streamIdObj) =>
                                                                match (streamIdObj) {
                                                                    case sv: UInt64 => sv
                                                                    case _ => 0u64
                                                                }
                                                            case None => 0u64
                                                        }
                                                        // acceptRequest() 已内部处理此 WT CONNECT
                                                        // 包括创建会话、发送 200、注册到会话注册表
                                                        continue
                                                } else {
                                                        let resp = handlerFn(req)
                                                        let sid: UInt64 = match (req.metadata) {
                                                            case Some(streamIdObj) =>
                                                                match (streamIdObj) {
                                                                    case sv: UInt64 => sv
                                                                    case _ => 0u64
                                                                }
                                                            case None => 0u64
                                                        }
                                                        h3Conn.sendResponse(sid, resp)
                                                }
                                                case None =>
                                                    h3Conn.gracefulShutdown()
                                                    break
                                            }
                                    }
                            }
                        } catch (_: Exception) {}
                    }
                }

                let outgoing = wrapper.feedPacket(pkt.data)
                if (outgoing.size > 0) {
                    rawConn.writePacket(outgoing, pkt.remoteAddr, ECN.Unsupported)
                }

                // 握手后检查服务端连接 ID 是否变更，更新路由表
                let currentSrcId = wrapper.getCurrentSrcConnId()
                if (currentSrcId.size > 0) {
                    let currentKey = hexEncode(currentSrcId)
                    if (currentKey != connIdKey) {
                        router.updateConnIdAlias(hdr.destConnId, currentSrcId)
                    }
                }
            } catch (_: Exception) {
                if (running.load()) {}
            }
        }
    }

    public func stop(): Unit {
        running.store(false)
        rawConn.close()
    }

    public func isRunning(): Bool { running.load() }
}

// ======== 连接 ID 生成器 ========

/// 生成指定长度的随机连接 ID（RFC 9000 §5.1）。
/// 用于客户端 dial 时的源连接 ID 和目标连接 ID。
/// 若系统随机数不可用，使用固定模式作为回退。
internal func generateConnId(len: Int64): Array<Byte> {
    let id = Array<Byte>(len, repeat: 0u8)
    var seed: UInt64 = 0
    try {
        // 使用 DateTime.second 作为熵源（v1.0.5 中无 Unix 时间戳 API）
        seed = UInt64(DateTime.now().second) ^ 0x9E3779B97F4A7C15u64
    } catch (_: Exception) {
    } catch (_: Exception) {
        seed = 0x4A7C159E3779B97Fu64
    }
    for (i in 0..len) {
        seed = seed * 6364136223846793005u64 + 1442695040888963407u64
        id[i] = UInt8((seed >> (UInt64(i % 8) * 8u64)) & 0xFFu64)
    }
    id
}

// ======== 客户端 QUIC 驱动 ========

public class QuicClientDriver {
    private var rawConn: RawConn
    private var wrapper: H3QuicIoConnection
    private var remoteAddr: String
    private var running: AtomicBool = AtomicBool(false)

    private init(rawConn: RawConn, wrapper: H3QuicIoConnection, remoteAddr: String) {
        this.rawConn = rawConn
        this.wrapper = wrapper
        this.remoteAddr = remoteAddr
    }

    public static func dial(host: String, port: UInt16, version!: Version = VERSION_1, tlsConfig!: ?H3TlsConfig = None): ?QuicClientDriver {
        let addr = host + ":" + port.toString()
        let rawConn = newRawConn("0.0.0.0", 0)

        // 从配置读取连接 ID，若未配置则使用随机生成
        let srcConnId: Array<Byte> = generateConnId(8)
        let destConnId: Array<Byte> = generateConnId(8)
        // 使用指定的 QUIC 版本，后续通过版本协商处理
        let chosenVer = version
        let coreConn = QuicCoreConnection(chosenVer, Perspective.Client, srcConnId, destConnId)
        coreConn.setState(ConnectionState.Initial)

        let connImpl = ConnImpl(coreConn)
        // 注入客户端 TLS 参数（若已配置）
        match (tlsConfig) {
            case Some(tc) =>
                connImpl.setTlsParams(tc.serverName, ["h3", "h3-29"])
            case None => ()
        }
        let wrapper = H3QuicIoConnection.fromConn(connImpl)
        wrapper.setRemoteAddr(addr)

        let initialOutgoing = wrapper.handshakeInit()
        if (initialOutgoing.size > 0) {
            rawConn.writePacket(initialOutgoing, addr, ECN.Unsupported)
        } else {
            let triggered = wrapper.feedPacket([])
            if (triggered.size > 0) {
                rawConn.writePacket(triggered, addr, ECN.Unsupported)
            }
        }

        // 等待握手完成（最多尝试 5 个数据包）
        for (i in 0..5) {
            if (wrapper.isHandshakeComplete()) { break }
            try {
                let pkt = rawConn.readPacket()
                if (pkt.data.size > 0) {
                    let outgoing = wrapper.feedPacket(pkt.data)
                    if (outgoing.size > 0) {
                        rawConn.writePacket(outgoing, addr, ECN.Unsupported)
                    }
                }
            } catch (_: Exception) { break }
        }
        Some(QuicClientDriver(rawConn, wrapper, addr))
    }

    public func run(iterations: Int64): Unit {
        running.store(true)
        var i: Int64 = 0
        while (running.load() && (iterations <= 0 || i < iterations)) {
            try {
                let pkt = rawConn.readPacket()
                if (pkt.data.size < 1) { continue }
                let outgoing = wrapper.feedPacket(pkt.data)
                if (outgoing.size > 0) {
                    rawConn.writePacket(outgoing, remoteAddr, ECN.Unsupported)
                }
                i += 1
            } catch (_: Exception) {
                if (running.load()) {}
            }
        }
    }

    public func stop(): Unit {
        running.store(false)
        rawConn.close()
    }

    public func getSupportedVersions(): Array<Version> {
        [VERSION_1, VERSION_2]
    }

    public func getQuicConnection(): H3QuicIoConnection { wrapper }
    public func isConnected(): Bool {
        !wrapper.isClosed() && wrapper.isHandshakeComplete()
    }
}
