package quic_cj

import std.random.Random
import quic_cj.core.{Connection, ConnectionState}
import quic_cj.protocol.{VERSION_1, Perspective}
import quic_cj.protocol.{ECN}
import quic_cj.congestion.{CongestionAlgorithm, CubicSender, newCubicSender, NewRenoSender, newNewRenoSender}
import quic_cj.sys.{RawConn, StubRawConn, getUdpBuffer, putUdpBuffer}
import quic_cj.tls.{TokenGenerator, newTokenProtector, TokenProtectorKey, TOKEN_KEY_SIZE, getRetryIntegrityTag}
import quic_cj.wire.{parseHeader, parseLongPacketType, readVarintAt, appendVarint, appendBytes}

/// 构建 QUIC Retry 包（RFC 9000 §8.1 / §17.2.5）。
/// clientSrcConnId: 客户端 Initial 包中的源连接 ID，用作 Retry 包的目标连接 ID
/// serverNewConnId:  服务端为此次 Retry 分配的新源连接 ID
/// origDestConnId:  客户端 Initial 包中的原始目标连接 ID（用于完整性标签计算）
private func buildRetryPacket(
    version: UInt32,
    clientSrcConnId: Array<Byte>,
    serverNewConnId: Array<Byte>,
    token: Array<Byte>,
    origDestConnId: Array<Byte>
): Array<Byte> {
    let firstByte: UInt8 = 0xF0u8 | UInt8(Random().nextInt64() & 0x0Fi64)
    let versionBytes: Array<Byte> = [
        UInt8((version >> 24) & 0xffu32),
        UInt8((version >> 16) & 0xffu32),
        UInt8((version >> 8) & 0xffu32),
        UInt8(version & 0xffu32),
    ]
    var tokenPayload: Array<Byte> = []
    tokenPayload = appendVarint(tokenPayload, Int64(token.size))
    var ti: Int64 = 0
    while (ti < token.size) { tokenPayload = appendBytes(tokenPayload, [token[ti]]); ti += 1 }

    let headerLen = 1 + 4 + 1 + clientSrcConnId.size + 1 + serverNewConnId.size + tokenPayload.size
    var buf = Array<Byte>(headerLen + 16, repeat: 0u8)
    buf[0] = firstByte
    var i: Int64 = 1
    while (i < 5) { buf[i] = versionBytes[i - 1]; i += 1 }
    buf[5] = UInt8(clientSrcConnId.size)
    i = 0
    while (i < clientSrcConnId.size) { buf[6 + i] = clientSrcConnId[i]; i += 1 }
    let srcLenPos = 6 + clientSrcConnId.size
    buf[srcLenPos] = UInt8(serverNewConnId.size)
    i = 0
    while (i < serverNewConnId.size) { buf[srcLenPos + 1 + i] = serverNewConnId[i]; i += 1 }
    let tokenPos = srcLenPos + 1 + serverNewConnId.size
    i = 0
    while (i < tokenPayload.size) { buf[tokenPos + i] = tokenPayload[i]; i += 1 }

    let integrityTag = getRetryIntegrityTag(buf[..headerLen], origDestConnId, version)
    let tagStart = headerLen
    i = 0
    while (i < 16 && i < integrityTag.size) { buf[tagStart + i] = integrityTag[i]; i += 1 }
    buf
}

/// ListenerImpl 提供一个具体的 Listener，用于接收 QUIC 连接。
public class ListenerImpl <: Listener {
    private var addrStr: String = ""
    private var transport: Transport
    private var isClosed: Bool = false
    private var rawConn: RawConn = StubRawConn("", 0)
    private var incomingPackets: Array<(Array<Byte>, String)> = []
    private var acceptSeq: Int64 = 0
    private var _config: Config = Config()
    private var retryAttempts: Int64 = 0

    public init(addr: String, t: Transport) {
        addrStr = addr
        transport = t
        rawConn = t.getRawConn()
    }

    public func accept(): Option<Conn> {
        if (isClosed) { return None }
        // 生成服务端连接 ID
        var srcConnId: Array<Byte> = Array<Byte>(4, repeat: 0u8)
        var i: Int64 = 0
        while (i < 4) {
            srcConnId[i] = UInt8((i * 7 + acceptSeq * 13 + 42) & 0xff)
            i += 1
        }
        acceptSeq += 1

        // 若启用 Retry，初始化 TokenGenerator
        var tokenGen: ?TokenGenerator = None
        if (_config.enableRetry) {
            let key: TokenProtectorKey = if (_config.retryTokenKey.size == TOKEN_KEY_SIZE) {
                _config.retryTokenKey
            } else {
                let rand = Random()
                var autoKey = Array<Byte>(TOKEN_KEY_SIZE, repeat: 0u8)
                var ki: Int64 = 0
                while (ki < TOKEN_KEY_SIZE) { autoKey[ki] = UInt8(rand.nextInt64() & 0xFFi64); ki += 1 }
                autoKey
            }
            tokenGen = Some(TokenGenerator(key))
        }

        // 从 UDP 套接字读取 Initial 包
        var attempts: Int64 = 0
        while (attempts < 100 && !isClosed) {
            let pkt = rawConn.readPacket()
            if (pkt.data.size > 4) {
                let firstByte = UInt8(pkt.data[0])
                let isLong = (firstByte & 0x80u8) != 0u8
                if (isLong) {
                    let typeField = (firstByte >> 4) & 0x07u8
                    if (typeField == 0u8) {
                        // 如果启用了 Retry，发送 Retry 包进行地址验证
                        if (_config.enableRetry) {
                            match (tokenGen) {
                                case Some(tg) =>
                                    retryAttempts += 1
                                    let (hdr, hdrLen) = parseHeader(pkt.data)
                                    if (hdrLen > 0) {
                                        // 客户端源连接 ID → 作为 Retry 包的目标连接 ID
                                        let clientSrcConnId = hdr.srcConnId
                                        // 客户端原始目标连接 ID → 用于完整性标签
                                        let origDestConnId = hdr.destConnId
                                        // 生成 Retry 源连接 ID
                                        var retrySrcConnId = Array<Byte>(4, repeat: 0u8)
                                        var ri: Int64 = 0
                                        while (ri < 4) {
                                            retrySrcConnId[ri] = UInt8((ri * 3 + retryAttempts * 7 + 42) & 0xff)
                                            ri += 1
                                        }
                                        // 生成 Retry 令牌
                                        let retryToken = tg.newRetryToken(
                                            pkt.remoteAddr.toArray(),
                                            origDestConnId,
                                            retrySrcConnId
                                        )
                                        // 构建并发送 Retry 包
                                        let retryPacket = buildRetryPacket(
                                            VERSION_1,
                                            clientSrcConnId,
                                            retrySrcConnId,
                                            retryToken,
                                            origDestConnId
                                        )
                                        rawConn.writePacket(retryPacket, pkt.remoteAddr, ECN.Unsupported)
                                    }
                                case None => ()
                            }
                            attempts += 1
                            continue
                        }

                        // 解析源连接 ID 作为客户端连接 ID
                        let destConnId = srcConnId
                        let conn = Connection(VERSION_1, Perspective.Server, srcConnId, destConnId)
                        conn.setState(ConnectionState.Initial)
                        let ci = ConnImpl(conn)
                        ci.setRemoteAddr(pkt.remoteAddr)
                        ci.setRawConn(rawConn)
                        conn.setMigrationDisabled(_config.disableActiveMigration)
                        conn.setMaxDatagramPayloadSize(_config.maxDatagramFrameSize)
                        if (_config.congestionAlgorithm == CONGESTION_ALGORITHM_NEW_RENO) {
                            conn.setCongestionAlgorithm(newNewRenoSender())
                        } else {
                            conn.setCongestionAlgorithm(newCubicSender())
                        }
                        match (_config.tlsConfig) {
                            case Some(tls) => conn.setTlsParams(tls.serverName, tls.alpn)
                            case None => ()
                        }
                        transport.setHandler(srcConnId, { data, addr, ts =>
                            let out = conn.handlePacket(data)
                            if (out.size > 0) {
                                rawConn.writePacket(out, pkt.remoteAddr, ECN.Unsupported)
                            }
                        })
                        let out = conn.handlePacket(pkt.data)
                        if (out.size > 0) {
                            rawConn.writePacket(out, pkt.remoteAddr, ECN.Unsupported)
                        }
                        return Some(ci)
                    }
                }
            }
            attempts += 1
        }
        None
    }

    public func addr(): String { addrStr }

    public func close(): Unit {
        isClosed = true
    }

    public func setConfig(cfg: Config): Unit {
        _config = cfg
    }
}
