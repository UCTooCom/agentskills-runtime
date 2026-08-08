package quic_cj.core

import quic_cj.protocol.{PacketNumber, PacketNumberLen, EncryptionLevel, Version, Perspective, StreamId, VERSION_1, INVALID_PACKET_NUMBER, DEFAULT_IDLE_TIMEOUT_MS, MAX_UNDECRYPTABLE_PACKETS, TIMER_GRANULARITY_MS, DEFAULT_HANDSHAKE_IDLE_TIMEOUT_MS, KEY_UPDATE_INTERVAL, packetNumberLengthForHeader, chooseSupportedVersion}
import quic_cj.wire.{Frame, AckFrame, CryptoFrame, PingFrame, ConnectionCloseFrame, ApplicationCloseFrame, parseFrame, parseHeader, Header, readVarint, readVarintAt, parseVersion, parseLongPacketType, FRAME_TYPE_CRYPTO, FRAME_TYPE_ACK, FRAME_TYPE_ACK_ECN, FRAME_TYPE_PING, FRAME_TYPE_CONNECTION_CLOSE, FRAME_TYPE_APPLICATION_CLOSE}
import quic_cj.wire.{StreamFrame, ResetStreamFrame, StopSendingFrame, MaxDataFrame, MaxStreamDataFrame, MaxStreamsFrame, DataBlockedFrame, StreamDataBlockedFrame, PathChallengeFrame, PathResponseFrame, HandshakeDoneFrame, NewConnectionIDFrame, DatagramFrame}
import quic_cj.wire.{FRAME_TYPE_STREAM_BASE, FRAME_TYPE_RESET_STREAM, FRAME_TYPE_STOP_SENDING, FRAME_TYPE_MAX_DATA, FRAME_TYPE_MAX_STREAM_DATA, FRAME_TYPE_MAX_STREAMS_BIDI, FRAME_TYPE_MAX_STREAMS_UNI, FRAME_TYPE_DATA_BLOCKED, FRAME_TYPE_STREAM_DATA_BLOCKED, FRAME_TYPE_STREAMS_BLOCKED_BIDI, FRAME_TYPE_STREAMS_BLOCKED_UNI, FRAME_TYPE_PATH_CHALLENGE, FRAME_TYPE_PATH_RESPONSE, FRAME_TYPE_HANDSHAKE_DONE, FRAME_TYPE_NEW_CONNECTION_ID, FRAME_TYPE_RETIRE_CONNECTION_ID, FRAME_TYPE_NEW_TOKEN, FRAME_TYPE_IMMEDIATE_ACK, FRAME_TYPE_ACK_FREQUENCY, FRAME_TYPE_DATAGRAM}
 import quic_cj.wire.{RetireConnectionIDFrame, NewTokenFrame, AckFrequencyFrame}
 import quic_cj.wire.TransportParameters
 import quic_cj.wire.{parsePreferredAddress, PreferredAddress}
 import quic_cj.tls.{CryptoSetup, ServerCryptoSetup, UpdatableAEAD, AeadSealer, AeadOpener, AesHeaderProtector, UpdatableAEADFull, verifyRetryIntegrity}
import quic_cj.ack.{ReceivedPacketTracker, SentPacketHandler, newSentPacketHandler}
import quic_cj.flow.{StreamFlowController, ConnectionFlowController, BaseFlowController}
import quic_cj.stream.{Stream, StreamMap, SendStream, ReceiveStream}
import quic_cj.protocol.{DEFAULT_MAX_INCOMING_STREAMS, StreamType, ECN}
import quic_cj.congestion.CongestionAlgorithm
import std.net.{IPAddress, IPv4Address}

/// ConnectionState 表示 QUIC 连接的生命周期。
public enum ConnectionState {
    | Initial
    | Handshake
    | Established
    | Closing
    | Closed
}
/// 将 IPv4 地址字节（4 字节）转换为字符串表示（如 "192.168.1.1"）。
internal func ipv4ToString(addr: Array<Byte>): String {
    if (addr.size < 4) { return "0.0.0.0" }
    let a = Int64(UInt8(addr[0])).toString()
    let b = Int64(UInt8(addr[1])).toString()
    let c = Int64(UInt8(addr[2])).toString()
    let d = Int64(UInt8(addr[3])).toString()
    a + "." + b + "." + c + "." + d
}

/// Connection 是主 QUIC 连接状态机，包含包处理。
public class Connection {
    private var state: ConnectionState = ConnectionState.Initial
    private var version: Version = VERSION_1
    private var perspective: Perspective = Perspective.Client
    private var srcConnId: Array<Byte> = []
    private var destConnId: Array<Byte> = []
    private var pktPacker: PacketPacker = PacketPacker(VERSION_1, [], [])
    private var unpacker: PacketUnpacker = PacketUnpacker()
    private var framerObj: Framer = Framer()
    private var sentPacketHandler: SentPacketHandler = newSentPacketHandler()
    private var streamMap: StreamMap = StreamMap()
    private var connFlowCtrl: ConnectionFlowController = ConnectionFlowController()
    private var maxIncomingStreams: Int64 = DEFAULT_MAX_INCOMING_STREAMS
    private var largestReceivedPn: PacketNumber = INVALID_PACKET_NUMBER
    private var closeErrorCode: UInt64 = 0u64
    private var closeReasonPhrase: Array<Byte> = []
    private var closeTimerMs: Int64 = 0
    private var isDraining: Bool = false
    private var idleTimerMs: Int64 = DEFAULT_IDLE_TIMEOUT_MS
    private var configMaxIdleMs: Int64 = DEFAULT_IDLE_TIMEOUT_MS
    private var keepAliveEnabled: Bool = false
    private var keepAliveMs: Int64 = 15000
    private var keepAliveTimerMs: Int64 = 15000
    private var cryptoEnabled: Bool = false
    private var cryptoSetupObj: CryptoSetup = CryptoSetup([], false, "", [])
    // --- 服务端 TLS 设置 ---
    private var _serverCryptoSetup: ?ServerCryptoSetup = None
    private var _serverHandshakeComplete: Bool = false
    // --- TLS 配置参数 ---
    private var _tlsServerName: String = ""
    private var _tlsAlpn: Array<String> = []

    // --- 数据报接收回调 ---
    private var _datagramRcvCallback: ?(Array<Byte>) -> Unit = None

    // --- 各加密级别的 ACK 跟踪 ---
    private var initialPktTracker: ReceivedPacketTracker = ReceivedPacketTracker()
    private var handshakePktTracker: ReceivedPacketTracker = ReceivedPacketTracker()
    private var oneRttPktTracker: ReceivedPacketTracker = ReceivedPacketTracker()

    // --- 加密流管理 ---
    private var cryptoStreamMgr: CryptoStreamManager = newCryptoStreamManager()

    // --- 重传队列 ---
    private var retransmissionQueue: RetransmissionQueue = newRetransmissionQueue()

    // --- 不可解密包缓冲区（密钥可用前的 Initial） ---
    private var undecryptablePackets: Array<Array<Byte>> = []
    
    // --- 发送队列和数据报队列 ---
    private var sendQueue: SendQueue = SendQueue()
    private var datagramQueue: DatagramQueue = DatagramQueue()
    private var pathManagerObj: PathManager = PathManager("0.0.0.0:0")
    private var preferredAddressConfig: Array<Byte> = []
    private var maxDatagramPayloadSize: Int64 = 0
    private var keyUpdateTimer: Int64 = 0
    private var sentPacketCount: Int64 = 0
    private var receivedPacketCount: Int64 = 0
    private var receivedTransportParams: Bool = false
    private var zeroRttAvailable: Bool = false
    private var oneRttAeadFull: UpdatableAEADFull = UpdatableAEADFull([], [])
    
    // --- 路径迁移回调 ---
    private var _pathMigrationCb: ?(PathEvent, String) -> Unit = None
    
    // --- Retry 包处理 ---
    private var retryToken: Array<Byte> = []
    private var retrySrcConnId: Array<Byte> = []
    
    // --- 无状态重置令牌 ---
    private var statelessResetToken: Array<Byte> = []
    
    // --- 0-RTT 早期数据 ---
    private var _earlyDataRcvCallback: ?(Array<Byte>) -> Unit = None
    private var earlyDataSendBuf: Array<Byte> = []
    private var earlyDataRecvBuf: Array<Byte> = []

    private var connStateDirty: Bool = false

    public init(version: Version, perspective: Perspective, srcConnId: Array<Byte>, destConnId: Array<Byte>) {
        this.version = version
        this.perspective = perspective
        this.srcConnId = srcConnId
        this.destConnId = destConnId
        this.pktPacker = PacketPacker(version, srcConnId, destConnId)
        this.cryptoSetupObj = CryptoSetup(destConnId, false, "", [])
    }

    /// 处理传入的 QUIC 包。
    public func handlePacket(data: Array<Byte>): Array<Byte> {
        idleTimerMs = configMaxIdleMs
        if (data.size < 1) { return generateOutgoing() }
        if (isDraining) { return [] }

        // 忽略空闲超时后收到的包
        if (match (state) { case ConnectionState.Closed => true; case _ => false }) { return [] }

        let firstByte = UInt8(data[0])
        let isLong = (firstByte & 0x80u8) != 0u8

        connStateDirty = false
        if (isLong) {
            // 检测 Retry 包（RFC 9000 §8.1）：长包头 type=3
            if (data.size >= 2 && parseLongPacketType(firstByte) == 3u8) {
                handleRetryPacket(data)
                return generateOutgoing()
            }
            // 检测版本协商包（RFC 9000 §6）：长包头 + 版本=0
            if (data.size >= 5 && parseVersion(data) == 0u32) {
                handleVersionNegotiationPacket(data)
                return generateOutgoing()
            }
            handleLongHeaderPacket(data)
        } else {
            handleShortHeaderPacket(data)
        }

        return generateOutgoing()
    }

    public func getState(): ConnectionState { state }
    public func setState(newState: ConnectionState): Unit { state = newState }
    public func getVersion(): Version { version }
    public func getSrcConnId(): Array<Byte> { srcConnId }
    public func getDestConnId(): Array<Byte> { destConnId }
    public func getPerspective(): Perspective { perspective }
    public func setIdleTimeout(ms: Int64): Unit { configMaxIdleMs = ms; idleTimerMs = ms }

    /// 启用连接保活，指定保活间隔（毫秒）。
    public func enableKeepAlive(intervalMs: Int64): Unit {
        keepAliveEnabled = true
        keepAliveMs = intervalMs
        keepAliveTimerMs = intervalMs
    }

    /// 禁用连接保活。
    public func disableKeepAlive(): Unit { keepAliveEnabled = false }
    public func setSendQueue(sq: SendQueue): Unit { sendQueue = sq }
    public func getSendQueue(): SendQueue { sendQueue }
    public func getDatagramQueue(): DatagramQueue { datagramQueue }
    public func getPathManager(): PathManager { pathManagerObj }

    /// 存储对端提供的 Preferred Address 数据。
    /// 握手完成后，客户端应尝试迁移到此地址。
    public func setPreferredAddressData(data: Array<Byte>): Unit {
        preferredAddressConfig = data
    }

    /// 获取 Preferred Address 数据。
    public func getPreferredAddressData(): Array<Byte> { preferredAddressConfig }
    public func setMigrationDisabled(disabled: Bool): Unit { pathManagerObj.setMigrationDisabled(disabled) }
    public func setMaxDatagramPayloadSize(maxSize: Int64): Unit { maxDatagramPayloadSize = maxSize }
    public func getMaxDatagramPayloadSize(): Int64 { maxDatagramPayloadSize }
    /// 应用协商的 QUIC 传输参数（RFC 9000 §18）。
    public func applyTransportParameters(params: TransportParameters): Unit {
        if (params.disableActiveMigration) {
            pathManagerObj.setMigrationDisabled(true)
        }
        if (params.maxDatagramFrameSize > 0) {
            maxDatagramPayloadSize = params.maxDatagramFrameSize
        }
        if (params.preferredAddressData.size > 0) {
            preferredAddressConfig = params.preferredAddressData
            let isClient = match (perspective) { case Perspective.Client => true; case _ => false }
            if (isClient) {
                if (let Some(preferredAddr) <- parsePreferredAddress(params.preferredAddressData)) {
                    if (preferredAddr.connId.size > 0) {
                    // 触发到 preferred address 的连接迁移
                    let _ = pathManagerObj.initiatePreferredAddressMigration(
                        ipv4ToString(preferredAddr.ipv4Addr) + ":" + Int64(preferredAddr.ipv4Port).toString(),
                        0
                    )
                    }
                }
            }
        }
        if (params.maxIdleTimeoutMs > 0) {
            configMaxIdleMs = params.maxIdleTimeoutMs
            idleTimerMs = params.maxIdleTimeoutMs
        }
        receivedTransportParams = true
    }
    public func isZeroRttAvailable(): Bool { zeroRttAvailable }
    public func setZeroRttAvailable(available: Bool): Unit { zeroRttAvailable = available }
    
    // ── 拥塞控制配置 ─────────────────────────────────────────
    
    /// 替换拥塞控制算法。必须在发送任何包之前调用。
    public func setCongestionAlgorithm(algo: CongestionAlgorithm): Unit {
        sentPacketHandler.setCongestionAlgorithm(algo)
    }
    
    // ── 连接迁移路径事件 ─────────────────────────────────────
    
    /// 设置路径迁移事件回调。
    public func setPathMigrationCallback(callback: ?(PathEvent, String) -> Unit): Unit {
        _pathMigrationCb = callback
    }
    
    /// 触发路径事件回调。
    private func firePathEvent(event: PathEvent, addr: String): Unit {
        match (_pathMigrationCb) {
            case Some(cb) => cb(event, addr)
            case None => ()
        }
    }
    
    // ── 0-RTT 早期数据 ────────────────────────────────────────
    
    /// 检查是否可以向对端发送 0-RTT 早期数据。
    public func canSendEarlyData(): Bool { zeroRttAvailable }
    
    /// 将数据排队等待以 0-RTT 级别发送。
    /// 返回 false 表示 0-RTT 不可用或数据过大。
    public func sendEarlyData(data: Array<Byte>): Bool {
        if (!zeroRttAvailable) { return false }
        if (maxDatagramPayloadSize > 0 && data.size > maxDatagramPayloadSize) { return false }
        earlyDataSendBuf = data
        true
    }
    
    /// 接收对端发送的 0-RTT 早期数据。
    public func receiveEarlyData(): Option<Array<Byte>> {
        if (earlyDataRecvBuf.size == 0) { return None }
        let data = earlyDataRecvBuf
        earlyDataRecvBuf = []
        Some(data)
    }
    
    /// 注册 0-RTT 早期数据到达回调（服务端侧）。
    public func setEarlyDataRcvCallback(callback: ?(Array<Byte>) -> Unit): Unit {
        _earlyDataRcvCallback = callback
    }

    /// 设置无状态重置令牌（用于检测对端发起的无状态重置）。
    public func setStatelessResetToken(token: Array<Byte>): Unit {
        if (token.size == 16) {
            statelessResetToken = token
        }
    }

    /// 获取无状态重置令牌。
    public func getStatelessResetToken(): Array<Byte> { statelessResetToken }
    /// 初始化 1-RTT UpdatableAEADFull 以支持密钥更新。
    public func initOneRttAEADFull(key: Array<Byte>, iv: Array<Byte>): Unit {
        oneRttAeadFull = UpdatableAEADFull(key, iv)
    }

    public func sendDatagram(data: Array<Byte>): Bool {
        if (maxDatagramPayloadSize > 0 && data.size > maxDatagramPayloadSize) { return false }
        let df = DatagramFrame()
        df.data = data
        return datagramQueue.add(df)
    }

    /// 从接收队列获取一个到达的数据报。
    /// 返回 data 或 None。
    public func receiveDatagram(): Option<Array<Byte>> {
        datagramQueue.receive()
    }

    /// 返回待发送的数据报队列长度（用于背压）。
    public func datagramSendQueue(): Int64 {
        datagramQueue.sendLen()
    }

    /// 获取重传队列。
    public func getRetransmissionQueue(): RetransmissionQueue { retransmissionQueue }

    /// 接收下一个传入的双向流。
    public func acceptStream(): Option<Stream> {
        let id: StreamId = streamMap.len()
        if (id <= 0) { return None }
        let stream = streamMap.getOrOpenStream(id)
        Some(stream)
    }

    /// 接收下一个传入的单向流。
    public func acceptUniStream(): Option<ReceiveStream> {
        if (let Some(stream) <- acceptStream()) {
            Some(stream.getReceiveStream())
        } else {
            None
        }
    }

    public func localAddr(): IPAddress { IPv4Address(0, 0, 0, 0) }
    public func remoteAddr(): String { "<<remote>>" }

    /// 打开一个新的双向流。
    public func openStream(): Option<Stream> {
        if (streamMap.len() >= maxIncomingStreams) { return None }
        let sid: StreamId = streamMap.len()
        let stream = streamMap.getOrOpenStream(sid)
        Some(stream)
    }

    /// 初始化加密设置并启用包加密。
    public func enableCrypto(): Unit {
        cryptoSetupObj = CryptoSetup(destConnId, false, _tlsServerName, _tlsAlpn)
        let ch = cryptoSetupObj.buildClientHello()
        if (ch.size > 0) {
            cryptoStreamMgr.getInitialStream().writeData(ch)
        }
        cryptoEnabled = true
        connStateDirty = true
    }

    public func setCryptoSetup(cs: CryptoSetup): Unit {
        cryptoSetupObj = cs
        cryptoEnabled = true
    }
    /// 设置服务端 TLS 握手处理器（ServerCryptoSetup）。
    /// 启用服务端加密并在收到 ClientHello 时自动响应。
    public func setServerCryptoSetup(scs: ServerCryptoSetup): Unit {
        _serverCryptoSetup = Some(scs)
        cryptoEnabled = true
        connStateDirty = true
    }

    /// 设置 TLS 参数（服务器名称和 ALPN）。
    /// 在 enableCrypto() 之前调用，使 ClientHello 包含 SNI/ALPN 扩展。
    public func setTlsParams(serverName: String, alpn: Array<String>): Unit {
        _tlsServerName = serverName
        _tlsAlpn = alpn
    }

    /// 注册数据报接收回调。
    /// 当收到 DATAGRAM 帧（RFC 9221）时，在入队后立即调用此回调。
    /// 回调接收数据报负载的副本，原数据仍保留在接收队列中供 poll 读取。
    public func setDatagramRcvCallback(callback: ?(Array<Byte>) -> Unit): Unit {
        _datagramRcvCallback = callback
    }
    // ── 加密密钥分发助手 ──
    /// 获取指定加密级别的头部保护密钥，优先使用服务端密钥。
    private func _getActiveHpKey(level: EncryptionLevel): Array<Byte> {
        match (_serverCryptoSetup) {
            case Some(scs) =>
                let key = scs.getHpKey(level)
                if (key.size >= 16) { return key }
            case None => ()
        }
        cryptoSetupObj.getHpKey(level)
    }
    /// 获取指定加密级别的 AEAD，优先使用服务端 AEAD。
    private func _getActiveAead(level: EncryptionLevel): UpdatableAEAD {
        match (_serverCryptoSetup) {
            case Some(scs) =>
                let aead = scs.getAead(level)
                if (aead.getKey().size >= 16) { return aead }
            case None => ()
        }
        cryptoSetupObj.getAead(level)
    }
    /// 检查握手是否完成（客户端或服务端）。
    private func _isHandshakeComplete(): Bool {
        _serverHandshakeComplete || cryptoSetupObj.handshakeComplete()
    }
    /// 检查 1-RTT 密钥是否可用。
    private func _hasActiveOneRttKeys(): Bool {
        match (_serverCryptoSetup) {
            case Some(scs) => scs.hasOneRttKeys()
            case None => cryptoSetupObj.hasOneRttKeys()
        }
    }
    /// 获取 1-RTT UpdatableAEADFull。
    private func _getActiveOneRttAeadFull(): UpdatableAEADFull {
        match (_serverCryptoSetup) {
            case Some(scs) => scs.getOneRttAeadFull()
            case None => cryptoSetupObj.getOneRttAeadFull()
        }
    }

    // ── 长包头包处理 ──

    private func handleLongHeaderPacket(data: Array<Byte>): Unit {
        let prevLargest = unpacker.getLargestReceived()
        let parsed = unpacker.unpackLongHeader(data)
        if (parsed.consumed <= 0) { return }

        let encLevel = parsed.encryptionLevel
        var pn = parsed.packetNumber

        if (cryptoEnabled && parsed.payload.size > 0) {
            let hpKey = _getActiveHpKey(encLevel)
            if (hpKey.size >= 16) {
                // 密钥可用——先移除包头保护，再解密
                let (hdr, hdrLen) = parseHeader(data)
                let pnOffset = computePnOffset(data, hdr, hdrLen)
                let pnLenI: Int64 = Int64((hdr.typeByte & 0x03u8) + 1u8)
                let hp = AesHeaderProtector(hpKey)
                pn = removeHeaderProtectionAndDecodePn(
                    data, pnOffset, pnLenI, prevLargest, hp)
                unpacker.setLargestReceived(pn)

                let aead = _getActiveAead(encLevel)
                let opener = AeadOpener(aead)
                let decrypted = unsealPacket(data, pn, pnOffset, pnLenI, opener, hp)
                if (decrypted.size > 0) {
                    processDecryptedFrames(decrypted, encLevel)
                }
            } else if ((match (encLevel) { case EncryptionLevel.Initial => true; case _ => false })) {
                // Initial 级别尚无密钥——缓存待后续处理
                if (undecryptablePackets.size < MAX_UNDECRYPTABLE_PACKETS) {
                    undecryptablePackets = appendByteArray(undecryptablePackets, data)
                }
            } else {
                processFrames(parsed)
            }
        } else if (parsed.payload.size > 0) {
            processFrames(parsed)
        }

        registerReceivedPacket(encLevel, pn)
        updateStateFromHandshake()
        connStateDirty = true
    }

    /// 处理版本协商包（RFC 9000 §6）。
    /// 客户端收到 VN 包后，提取对端支持的版本列表并尝试协商。
    private func handleVersionNegotiationPacket(data: Array<Byte>): Unit {
        // 仅客户端处理 VN（服务端不应收到 VN）
        let isClient = match (perspective) { case Perspective.Client => true; case _ => false }
        if (!isClient) { return }

        // 解析包头获取连接 ID
        let (hdr, hdrLen) = parseHeader(data)
        if (hdrLen <= 0) { return }

        // VN 包负载是 4 字节版本列表（RFC 9000 §6.2）
        let payloadOffset = hdrLen
        let payload = data[payloadOffset..]
        var supportedVersions: Array<Version> = []
        var i: Int64 = 0
        while (i + 4 <= payload.size) {
            let ver = UInt32(UInt8(payload[i])) << 24 | UInt32(UInt8(payload[i+1])) << 16 |
                      UInt32(UInt8(payload[i+2])) << 8 | UInt32(UInt8(payload[i+3]))
            if (ver != 0u32) {
                let n = supportedVersions.size
                var out = Array<Version>(n + 1, repeat: 0u32)
                var j: Int64 = 0
                while (j < n) { out[j] = supportedVersions[j]; j += 1 }
                out[n] = ver
                supportedVersions = out
            }
            i += 4
        }

        if (supportedVersions.size == 0) { return }

        // 从对端支持的版本中选择一个（优先保持当前版本）
        let ourVersions: Array<Version> = [VERSION_1, version]
        if (let Some(chosenVer) <- chooseSupportedVersion(ourVersions, supportedVersions)) {
            if (chosenVer == version) { return }

            // 切换版本并重置连接状态以重新握手
            version = chosenVer
            pktPacker = PacketPacker(version, srcConnId, destConnId)
            state = ConnectionState.Initial
            cryptoEnabled = false
            cryptoSetupObj = CryptoSetup(destConnId, false, _tlsServerName, _tlsAlpn)
            // 重新生成 ClientHello
            enableCrypto()
        }
    }

    /// 处理 Retry 包（RFC 9000 §8）。
    /// 客户端收到 Retry 后，提取 token 并替换目标连接 ID。
    private func handleRetryPacket(data: Array<Byte>): Unit {
        let isClient = match (perspective) { case Perspective.Client => true; case _ => false }
        if (!isClient) { return }

        let (hdr, hdrLen) = parseHeader(data)
        if (hdrLen <= 0) { return }

        // Retry 包格式：首字节 + 版本(4) + DCID(1+len) + SCID(1+len) + token(varint+data) + integrity_tag(16)
        // 提取 retrySrcConnId（即包头中的源连接 ID）
        retrySrcConnId = hdr.srcConnId
        if (retrySrcConnId.size == 0) { return }

        // 提取 token：位于 SCID 之后，varint 编码的长度 + 数据
        var pos = hdrLen
        if (pos >= data.size) { return }
        let (tokenLen, tl) = readVarintAt(data, pos)
        pos += tl
        if (pos + tokenLen + 16 > data.size) { return }
        retryToken = data[pos..pos + tokenLen]

        // 验证 Retry 完整性标签（RFC 9001 §5.8）
        let origDestConnId = destConnId
        if (!verifyRetryIntegrity(data, origDestConnId, version)) {
            // 完整性标签无效，忽略此 Retry 包
            retryToken = []
            retrySrcConnId = []
            return
        }

        // 用 retrySrcConnId 替换目标连接 ID（RFC 9000 §8.2）
        destConnId = retrySrcConnId
        // 更新 packer 中的目标连接 ID
        pktPacker = PacketPacker(version, srcConnId, destConnId)
        // 重新发送 Initial 包（携带 retryToken）
        cryptoEnabled = false
        cryptoSetupObj = CryptoSetup(destConnId, false, _tlsServerName, _tlsAlpn)
        enableCrypto()
    }

    /// 计算长包头包的 PN 偏移量。
    private func computePnOffset(data: Array<Byte>, hdr: Header, hdrLen: Int64): Int64 {
        var pnOffset = hdrLen
        if (hdr.packetType == 0u8) {
            if (pnOffset < data.size) {
                let (tokenLen, tl) = readVarintAt(data, pnOffset)
                pnOffset += tl + tokenLen
            }
        }
        if (pnOffset < data.size) {
            let (payloadLen, n) = readVarintAt(data, pnOffset)
            pnOffset += n
        }
        pnOffset
    }

    // ── 短包头包处理 ──

    private func handleShortHeaderPacket(data: Array<Byte>): Unit {
        let prevLargest = unpacker.getLargestReceived()
        let parsed = unpacker.unpackShortHeader(data)
        if (parsed.consumed <= 0) { return }

        let encLevel = EncryptionLevel.OneRTT
        var pn = parsed.packetNumber

        if (parsed.payload.size > 0) {
            let hpKey = _getActiveHpKey(EncryptionLevel.OneRTT)
            if (hpKey.size >= 16) {
                let pnOffset = 1 + Int64(destConnId.size)
                let pnLenI: Int64 = Int64((data[0] & 0x03u8) + 1u8)
                let hp = AesHeaderProtector(hpKey)
                pn = removeHeaderProtectionAndDecodePn(
                    data, pnOffset, pnLenI, prevLargest, hp)
                unpacker.setLargestReceived(pn)

                let aead = _getActiveAead(EncryptionLevel.OneRTT)
                let opener = AeadOpener(aead)
                let decrypted = unsealPacket(data, pn, pnOffset, pnLenI, opener, hp)
                if (decrypted.size > 0) {
                    processDecryptedFrames(decrypted, EncryptionLevel.OneRTT)
                } else {
                    // 解密失败：检查无状态重置（RFC 9000 §10.3）
                    checkStatelessReset(data)
                }
            } else {
                processFrames(parsed)
            }
        }

        registerReceivedPacket(encLevel, pn)
        updateStateFromHandshake()
        connStateDirty = true
    }

    /// 检查包尾部是否匹配已知的无状态重置令牌。
    /// 如果匹配则进入 draining 状态（RFC 9000 §10.3）。
    private func checkStatelessReset(data: Array<Byte>): Unit {
        if (data.size < 16) { return }
        let trailing = data[data.size - 16..]
        // 检查原始连接令牌
        if (statelessResetToken.size == 16) {
            var matched: Bool = true
            var i: Int64 = 0
            while (i < 16) {
                if (trailing[i] != statelessResetToken[i]) { matched = false; break }
                i += 1
            }
            if (matched) {
                enterDrainingOnReset()
                return
            }
        }
        // 检查额外连接 ID 的令牌
        var j: Int64 = 0
        while (j < extraConnIds.size) {
            let (_, _, token) = extraConnIds[j]
            if (token.size == 16) {
                var matched: Bool = true
                var k: Int64 = 0
                while (k < 16) {
                    if (trailing[k] != token[k]) { matched = false; break }
                    k += 1
                }
                if (matched) {
                    enterDrainingOnReset()
                    return
                }
            }
            j += 1
        }
    }

    /// 收到无状态重置后进入 draining 状态。
    private func enterDrainingOnReset(): Unit {
        isDraining = true
        state = ConnectionState.Closed
        closeTimerMs = 0
    }

    // ── 帧处理 ──

    private func processDecryptedFrames(payload: Array<Byte>, encLevel: EncryptionLevel): Unit {
        let frames = unpacker.parseFramesFromPayload(payload)
        var i: Int64 = 0
        while (i < frames.size) {
            processFrame(frames[i], encLevel)
            i += 1
        }
    }

    private func processFrames(parsed: ParsedPacket): Unit {
        let frames = unpacker.parseFramesFromPayload(parsed.payload)
        var i: Int64 = 0
        while (i < frames.size) {
            processFrame(frames[i], parsed.encryptionLevel)
            i += 1
        }
    }

    private func processFrame(frame: Frame, encLevel: EncryptionLevel): Unit {
        let ft = frame.frameType()
        if (ft == FRAME_TYPE_CRYPTO) { processCryptoFrame(frame, encLevel)
        } else if (ft == FRAME_TYPE_ACK || ft == FRAME_TYPE_ACK_ECN) { processAckFrame(frame, encLevel)
        } else if (ft == FRAME_TYPE_PING) { _ = 0 // no auto-pong
        } else if (ft >= 0x08u8 && ft <= 0x0fu8) { processStreamFrame(frame)
        } else if (ft == FRAME_TYPE_RESET_STREAM) { processResetStreamFrame(frame)
        } else if (ft == FRAME_TYPE_STOP_SENDING) { processStopSendingFrame(frame)
        } else if (ft == FRAME_TYPE_MAX_DATA) { processMaxDataFrame(frame)
        } else if (ft == FRAME_TYPE_MAX_STREAM_DATA) { processMaxStreamDataFrame(frame)
        } else if (ft == FRAME_TYPE_MAX_STREAMS_BIDI || ft == FRAME_TYPE_MAX_STREAMS_UNI) { processMaxStreamsFrame(frame)
        } else if (ft == FRAME_TYPE_DATA_BLOCKED || ft == FRAME_TYPE_STREAM_DATA_BLOCKED) { processBlockedFrame(frame)
        } else if (ft == FRAME_TYPE_PATH_CHALLENGE) { processPathChallengeFrame(frame)
        } else if (ft == FRAME_TYPE_PATH_RESPONSE) { processPathResponseFrame(frame)
        } else if (ft == FRAME_TYPE_CONNECTION_CLOSE || ft == FRAME_TYPE_APPLICATION_CLOSE) { processCloseFrame(frame)
        } else if (ft == FRAME_TYPE_HANDSHAKE_DONE) { processHandshakeDoneFrame()
        } else if (ft == FRAME_TYPE_NEW_CONNECTION_ID) { processNewConnectionIdFrame(frame)
        } else if (ft == FRAME_TYPE_RETIRE_CONNECTION_ID) { processRetireConnectionIdFrame(frame)
        } else if (ft == FRAME_TYPE_NEW_TOKEN) { processNewTokenFrame(frame)
        } else if (ft == FRAME_TYPE_IMMEDIATE_ACK) { processImmediateAckFrame(encLevel)
        } else if (ft == FRAME_TYPE_ACK_FREQUENCY) { processAckFrequencyFrame(frame)
        } else if (ft == FRAME_TYPE_DATAGRAM) { processDatagramFrame(frame)
        }
    }

    // ── 单个帧处理器 ──

    private func processCryptoFrame(frame: Frame, encLevel: EncryptionLevel): Unit {
        match (frame as CryptoFrame) {
            case Some(cf) =>
                cryptoStreamMgr.handleCryptoFrame(cf, encLevel)
                // 清空加密流数据
                let data = cryptoStreamMgr.getCryptoData(encLevel)
                if (data.size > 0) {
                    // 服务端：路由到 ServerCryptoSetup 处理 ClientHello
                    match (_serverCryptoSetup) {
                        case Some(scs) =>
                            handleServerCrypto(scs, data, encLevel)
                        case None =>
                            cryptoSetupObj.handleMessage(data, encLevel)
                    }
                }
            case None => ()
        }
    }
    /// 服务端 CRYPTO 帧处理。
    /// 在 Initial 级别处理 ClientHello 并构建服务端飞行；
    /// 在 Handshake 级别接收客户端 Finished 以确认握手完成。
    private func handleServerCrypto(scs: ServerCryptoSetup, data: Array<Byte>, encLevel: EncryptionLevel): Unit {
        let isInitial = match (encLevel) { case EncryptionLevel.Initial => true; case _ => false }
        let isHandshake = match (encLevel) { case EncryptionLevel.Handshake => true; case _ => false }
        if (isInitial) {
            let (ok, _) = scs.handleClientHello(data)
            if (ok) {
                // ServerHello 放入 Initial 加密流
                let sh = scs.getServerHelloData()
                if (sh.size > 0) {
                    cryptoStreamMgr.getInitialStream().writeData(sh)
                }
                // 剩余飞行（EncryptedExtensions + Certificate + Verify + Finished）放入 Handshake 加密流
                let hf = scs.getHandshakeFlightData()
                if (hf.size > 0) {
                    cryptoStreamMgr.getHandshakeStream().writeData(hf)
                }
                _serverHandshakeComplete = true
            }
        } else if (isHandshake) {
            // 客户端 Finished 到达 → 服务端握手完成
            _serverHandshakeComplete = true
        }
    }

    private func processAckFrame(frame: Frame, encLevel: EncryptionLevel): Unit {
        match (frame as AckFrame) {
            case Some(af) =>
                let lostFrames = sentPacketHandler.receivedAck(af, encLevel)
                // 将丢失的帧排队到重传队列
                if (lostFrames.size > 0) {
                    var fi: Int64 = 0
                    while (fi < lostFrames.size) {
                        match (encLevel) {
                            case EncryptionLevel.Initial => retransmissionQueue.addInitial(lostFrames[fi])
                            case EncryptionLevel.Handshake => retransmissionQueue.addHandshake(lostFrames[fi])
                            case _ => retransmissionQueue.addAppData(lostFrames[fi])
                        }
                        fi += 1
                    }
                }
                // 将最大已确认包编号通知给 AEAD（供密钥更新使用）
                match (encLevel) {
                    case EncryptionLevel.OneRTT =>
                        oneRttAeadFull.setLargestAcked(af.largestAcked)
                    case _ => ()
                }
            case None => ()
        }
    }

    private func processStreamFrame(frame: Frame): Unit {
        match (frame as StreamFrame) {
            case Some(sf) => handleStreamFrameData(sf)
            case None => ()
        }
    }

    private func processResetStreamFrame(frame: Frame): Unit {
        match (frame as ResetStreamFrame) {
            case Some(rsf) => handleStreamReset(rsf)
            case None => ()
        }
    }

    private func processStopSendingFrame(frame: Frame): Unit {
        match (frame as StopSendingFrame) {
            case Some(ssf) => handleStopSending(ssf)
            case None => ()
        }
    }

    private func processMaxDataFrame(frame: Frame): Unit {
        match (frame as MaxDataFrame) {
            case Some(mdf) =>
                connFlowCtrl.updateSendWindow(mdf.maxData)
            case None => ()
        }
    }

    private func processMaxStreamDataFrame(frame: Frame): Unit {
        match (frame as MaxStreamDataFrame) {
            case Some(msdf) => handleMaxStreamData(msdf)
            case None => ()
        }
    }

    private func processMaxStreamsFrame(frame: Frame): Unit {
        match (frame as MaxStreamsFrame) {
            case Some(msf) => handleMaxStreamsUpdate(msf)
            case None => ()
        }
    }

    private func processBlockedFrame(frame: Frame): Unit {}

    private func processPathChallengeFrame(frame: Frame): Unit {
        match (frame as PathChallengeFrame) {
            case Some(pcf) => handlePathRequest(pcf)
            case None => ()
        }
    }

    private func processPathResponseFrame(frame: Frame): Unit {
        match (frame as PathResponseFrame) {
            case Some(prf) =>
                let validatedAddr = pathManagerObj.handlePathResponseFrame(prf.data)
                if (validatedAddr != "") {
                    firePathEvent(PathEvent.PathValidated, validatedAddr)
                }
            case None => ()
        }
    }

    private func processHandshakeDoneFrame(): Unit {
        match (state) {
            case ConnectionState.Handshake => state = ConnectionState.Established
            case _ => ()
        }
    }

    private var extraConnIds: Array<(Int64, Array<Byte>, Array<Byte>)> = []  // (seq, connId, statelessResetToken)

    private func processNewConnectionIdFrame(frame: Frame): Unit {
        match (frame as NewConnectionIDFrame) {
            case Some(ncid) =>
                // 跟踪额外的连接 ID（RFC 9000 §19.15）
                // 检查是否已存在相同 seq 的条目
                var found: Bool = false
                var i: Int64 = 0
                while (i < extraConnIds.size) {
                    let (seq, cid, token) = extraConnIds[i]
                    if (seq == ncid.seq) { found = true; break }
                    cid; token
                    i += 1
                }
                if (!found && ncid.connectionId.size > 0) {
                    let n = extraConnIds.size
                    var out = Array<(Int64, Array<Byte>, Array<Byte>)>(n + 1, repeat: (0, [], []))
                    var j: Int64 = 0
                    while (j < n) { out[j] = extraConnIds[j]; j += 1 }
                    out[n] = (ncid.seq, ncid.connectionId, ncid.statelessResetToken)
                    extraConnIds = out
                }
            case None => ()
        }
    }

    private func processRetireConnectionIdFrame(frame: Frame): Unit {
        match (frame as RetireConnectionIDFrame) {
            case Some(rcid) =>
                // 移除指定 seq 的连接 ID
                var i: Int64 = 0
                while (i < extraConnIds.size) {
                    let (seq, cid, token) = extraConnIds[i]
                    if (seq == rcid.seq) {
                        cid; token
                        let n = extraConnIds.size
                        var out = Array<(Int64, Array<Byte>, Array<Byte>)>(n - 1, repeat: (0, [], []))
                        var j: Int64 = 0
                        var k: Int64 = 0
                        while (j < n) {
                            if (j != i) { out[k] = extraConnIds[j]; k += 1 }
                            j += 1
                        }
                        extraConnIds = out
                        break
                    }
                    i += 1
                }
            case None => ()
        }
    }


    private var latestToken: Array<Byte> = []

    private func processNewTokenFrame(frame: Frame): Unit {
        match (frame as NewTokenFrame) {
            case Some(ntf) =>
                if (ntf.token.size > 0) {
                    latestToken = ntf.token
                }
            case None => ()
        }
    }

    /// 获取地址验证令牌供后续连接使用。
    public func getToken(): Array<Byte> { latestToken }

    /// 处理 IMMEDIATE_ACK 帧（RFC 9002 §5）：强制立即为当前加密级别生成 ACK。
    private func processImmediateAckFrame(encLevel: EncryptionLevel): Unit {
        getTracker(encLevel).requestImmediateAck()
    }

    private func processAckFrequencyFrame(frame: Frame): Unit {
        // RFC 9002 §6: ACK_FREQUENCY 帧 — 调整 ACK 发送频率
        match (frame as AckFrequencyFrame) {
            case Some(aff) =>
                // 更新所有加密级别的 ACK 频率
                initialPktTracker.setAckFrequency(aff.packetsAfter, aff.maxAckDelayMicro, aff.ignoreOrder)
                handshakePktTracker.setAckFrequency(aff.packetsAfter, aff.maxAckDelayMicro, aff.ignoreOrder)
                oneRttPktTracker.setAckFrequency(aff.packetsAfter, aff.maxAckDelayMicro, aff.ignoreOrder)
            case None => ()
        }
    }

    private func processDatagramFrame(frame: Frame): Unit {
        match (frame as DatagramFrame) {
            case Some(df) =>
                datagramQueue.handleDatagramFrame(df.data)
                // 如果有数据报接收回调，调用它
                match (_datagramRcvCallback) {
                    case Some(cb) => cb(df.data)
                    case None => ()
                }
            case None => ()
        }
    }

    // ── 流处理辅助 ──

    private func handleStreamFrameData(sf: StreamFrame): Unit {
        // 流 ID 0 用于 0-RTT 早期数据传输
        if (sf.streamId == 0 && zeroRttAvailable && sf.data.size > 0) {
            earlyDataRecvBuf = sf.data
            match (_earlyDataRcvCallback) {
                case Some(cb) => cb(sf.data)
                case None => ()
            }
        }
        let stream = streamMap.getOrOpenStream(sf.streamId)
        stream.getReceiveStream().handleStreamFrame(sf)
        connFlowCtrl.addBytesRead(sf.data.size)
    }

   private func handleMaxStreamData(msdf: MaxStreamDataFrame): Unit {
       let stream = streamMap.getOrOpenStream(msdf.streamId)
       // 如果发送流已重置，忽略 MAX_STREAM_DATA（RFC 9000 §3.4）
      if (stream.getSendStream().isResetSent()) { return }
       stream.getFlowController().updateSendWindow(msdf.maxStreamData)
   }

    private func handleMaxStreamsUpdate(msf: MaxStreamsFrame): Unit {
        if (msf.maxStreams > maxIncomingStreams) {
            maxIncomingStreams = msf.maxStreams
        }
    }

    private func handlePathRequest(pcf: PathChallengeFrame): Unit {
        let prf = PathResponseFrame()
        prf.data = pcf.data
        framerObj.queueFrame(prf)
    }

   private func handleStreamReset(rsf: ResetStreamFrame): Unit {
       let stream = streamMap.getOrOpenStream(rsf.streamId)
       stream.getReceiveStream().handleResetStreamFrame(rsf)
        // 流控处理：RESET_STREAM 的 finalSize 替代实际接收量（RFC 9000 §7.3）
        let finalSize = rsf.finalSize
        if (finalSize > 0) {
            let fc = stream.getFlowController()
            if (finalSize > fc.getHighestReceived()) {
                let _ = fc.updateHighestReceived(finalSize, true)
            }
            let unread = fc.getHighestReceived() - fc.getBytesRead()
            if (unread > 0) {
                fc.addBytesRead(unread)
                connFlowCtrl.addBytesRead(unread)
            }
        }
   }

   private func handleStopSending(ssf: StopSendingFrame): Unit {
       let stream = streamMap.getOrOpenStream(ssf.streamId)
        let sendStream = stream.getSendStream()
        sendStream.handleStopSendingFrame(ssf)
        // 排队 RESET_STREAM 帧以回应 STOP_SENDING（RFC 9000 §3.5）
        if (sendStream.isResetSent()) {
            let rsf = ResetStreamFrame(ssf.streamId, 0u64, sendStream.getOffset())
            framerObj.queueFrame(rsf)
        }
   }

    // ── 状态转换 ──

    /// 同步 0-RTT 可用性：从 CryptoSetup 或 ServerCryptoSetup 获取。
    private func syncZeroRttAvailability(): Unit {
        if (zeroRttAvailable) { return }
        match (_serverCryptoSetup) {
            case Some(scs) =>
                if (scs.isZeroRttAvailable()) {
                    zeroRttAvailable = true
                }
            case None =>
                if (cryptoSetupObj.isZeroRttAvailable()) {
                    zeroRttAvailable = true
                }
        }
    }

    private func updateStateFromHandshake(): Unit {
        // 同步 0-RTT 可用性
        syncZeroRttAvailability()

        match (state) {
            case ConnectionState.Initial =>
                if (_isHandshakeComplete()) {
                    state = ConnectionState.Handshake
                    // 处理缓冲中无法解密的包
                    processBufferedPackets()
                }
            case ConnectionState.Handshake =>
                if (_isHandshakeComplete()) {
                    state = ConnectionState.Established
                    // 初始化 1-RTT UpdatableAEADFull 以支持密钥更新
                    if (_hasActiveOneRttKeys()) {
                        oneRttAeadFull = _getActiveOneRttAeadFull()
                        oneRttAeadFull.setHandshakeConfirmed()
                    }
                }
            case _ => ()
        }
    }

    private func processBufferedPackets(): Unit {
        var i: Int64 = 0
        while (i < undecryptablePackets.size) {
            handleLongHeaderPacket(undecryptablePackets[i])
            i += 1
        }
        undecryptablePackets = []
    }

    // ── 关闭处理 ──

    public func closeWithError(errorCode: UInt64, reason: String): Unit {
        if (isDraining) { return }
        closeErrorCode = errorCode
        closeReasonPhrase = reason.toArray()
        state = ConnectionState.Closing
        closeTimerMs = 3000
        let cf = ConnectionCloseFrame()
        cf.errorCode = errorCode
        cf.reasonPhrase = closeReasonPhrase
        framerObj.queueFrame(cf)
    }

    public func isClosed(): Bool { match (state) { case ConnectionState.Closed => true; case _ => false } }

    private func processCloseFrame(frame: Frame): Unit {
        state = ConnectionState.Closed
        isDraining = true
        closeTimerMs = 0
    }

    public func tick(ms: Int64): Unit {
        if (idleTimerMs > 0 && !isDraining) {
            idleTimerMs -= ms
            if (idleTimerMs <= 0) { closeWithError(0u64, "idle timeout") }
        }
        if (keepAliveEnabled && !isDraining) {
            keepAliveTimerMs -= ms
            if (keepAliveTimerMs <= 0) {
                keepAliveTimerMs = keepAliveMs
                // 排队 PING 帧以维持连接活性
                framerObj.queueFrame(PingFrame())
            }
        }
        if (closeTimerMs > 0) {
            closeTimerMs -= ms
            if (closeTimerMs <= 0) {
                state = ConnectionState.Closed
                isDraining = true
                closeTimerMs = 0
            }
        }
        // 自动密钥更新检查
        if (!isDraining && sentPacketCount > 0) {
            keyUpdateTimer += ms
            if (keyUpdateTimer >= 1000) {
                keyUpdateTimer = 0
                // 委托给 UpdatableAEADFull，由其根据包计数决定是否 rollKeys()
                let _ = oneRttAeadFull.currentKeyPhase()
            }
        }
    }

    public func getCloseError(): (UInt64, Array<Byte>) { (closeErrorCode, closeReasonPhrase) }
    public func isCryptoEnabled(): Bool { cryptoEnabled }

    // ── ACK 包注册 ──

    private func registerReceivedPacket(encLevel: EncryptionLevel, pn: PacketNumber): Unit {
        receivedPacketCount += 1
        match (encLevel) {
            case EncryptionLevel.Initial => initialPktTracker.receivedPacket(pn, ECN.Unsupported, true)
            case EncryptionLevel.Handshake => handshakePktTracker.receivedPacket(pn, ECN.Unsupported, true)
            case _ => oneRttPktTracker.receivedPacket(pn, ECN.Unsupported, true)
        }
    }

    private func getTracker(encLevel: EncryptionLevel): ReceivedPacketTracker {
        match (encLevel) {
            case EncryptionLevel.Initial => initialPktTracker
            case EncryptionLevel.Handshake => handshakePktTracker
            case _ => oneRttPktTracker
        }
    }

    // ── 出站包生成 ──

    private func generateOutgoing(): Array<Byte> {
        // 确定要使用的加密级别
        let (outEncLevel, isLong, pktType) = getOutgoingEncryptionLevel()
        let maxLen = framerObj.maxPayloadLen(1280, outEncLevel)

        // 0. 优先添加重传帧
        if (retransmissionQueue.hasData(outEncLevel)) {
            while (retransmissionQueue.hasData(outEncLevel)) {
                if (let Some(rf) <- retransmissionQueue.getFrame(outEncLevel)) {
                    framerObj.queueFrame(rf)
                } else { break }
                if (framerObj.frameCount() >= 16) { break }
            }
        }

        // 1. 需要时添加 ACK 帧
        var hasAck: Bool = false
        if (let Some(ackFrame) <- getTracker(outEncLevel).getAckFrame()) {
            framerObj.setAckFrame(ackFrame)
            hasAck = true
        }

        // 2. 从加密流管理器添加 CRYPTO 帧
        addCryptoFramesToFramer(outEncLevel, maxLen)

        // 2b. 0-RTT 级别时，将早期数据作为流帧发送
        let isZeroRtt = match (outEncLevel) { case EncryptionLevel.ZeroRTT => true; case _ => false }
        if (isZeroRtt && earlyDataSendBuf.size > 0) {
            let sf = StreamFrame()
            sf.streamId = 0
            sf.offset = 0
            sf.data = earlyDataSendBuf
            sf.fin = true
            framerObj.queueFrame(sf)
            earlyDataSendBuf = []
        }

        // 3. 检查连接级流控是否阻塞

        // 4. 获取所有待处理帧
        let frames = framerObj.getFrames()
        if (frames.size == 0 && !hasAck) { return [] }

        // 5. 构建包
        let pnLen: PacketNumberLen = selectPnLen(outEncLevel)
        var plaintext: Array<Byte>
        if (isLong) {
            // Long header Initial 包携带 retry token（如果有）
            let isInitial = match (outEncLevel) { case EncryptionLevel.Initial => true; case _ => false }
            let token: Array<Byte> = if (isInitial && retryToken.size > 0) {
                retryToken
            } else {
                Array<Byte>(0, repeat: 0u8)
            }
            if (token.size > 0) {
                plaintext = pktPacker.packLongHeaderPacketWithToken(pktType, outEncLevel, frames, pnLen, token)
            } else {
                plaintext = pktPacker.packLongHeaderPacket(pktType, outEncLevel, frames, pnLen)
            }
        } else {
            plaintext = pktPacker.packShortHeaderPacket(frames, pnLen)
        }

        // 7. 注册已发送包以用于丢包检测
        let sentPn = pktPacker.getPn(outEncLevel)
        sentPacketHandler.sentPacket(sentPn, frames, outEncLevel, plaintext.size)
        sentPacketCount += 1

        // 8. 如果加密已启用，密封包
        if (cryptoEnabled) {
            let hpKey = _getActiveHpKey(outEncLevel)
            if (hpKey.size >= 16) {
                let pnOffset = pktPacker.getLastPnOffset()
                let pn = pktPacker.getPn(outEncLevel)
                let aead = _getActiveAead(outEncLevel)
                let hp = AesHeaderProtector(hpKey)
                let sealer = AeadSealer(aead)
                return sealPacket(plaintext, pn, pnOffset, Int64(pnLen), sealer, hp)
            }
        }
        plaintext
    }

    /// 确定出站包的加密级别和包头类型。
    private func getOutgoingEncryptionLevel(): (EncryptionLevel, Bool, UInt8) {
        // 有 0-RTT 早期数据待发送时，输出 ZeroRTT 包（长包头 type=1）
        if (zeroRttAvailable && earlyDataSendBuf.size > 0) {
            return (EncryptionLevel.ZeroRTT, true, 1u8)
        }
        // 0-RTT 可用时也支持发送纯 PING/ACK 帧（保持连接活性 / 确认对端数据）
        if (zeroRttAvailable && !_isHandshakeComplete()) {
            let isInitial = match (state) { case ConnectionState.Initial => true; case _ => false }
            if (isInitial) { return (EncryptionLevel.ZeroRTT, true, 1u8) }
        }
        match (state) {
            case ConnectionState.Initial => (EncryptionLevel.Initial, true, 0u8)
            case ConnectionState.Handshake => (EncryptionLevel.Handshake, true, 2u8)
            case _ => (EncryptionLevel.OneRTT, false, 0u8)
        }
    }

    /// 根据下一个 PN 值选择最优包编号长度。
    private func selectPnLen(encLevel: EncryptionLevel): PacketNumberLen {
        let pn = pktPacker.getPn(encLevel)
        let largestAcked = pktPacker.getLargestAckedPn(encLevel)
        packetNumberLengthForHeader(pn, largestAcked)
    }

    /// 将加密流管理器的 CRYPTO 帧添加到帧调度器。
    private func addCryptoFramesToFramer(encLevel: EncryptionLevel, maxLen: Int64): Unit {
        let remaining = maxLen - estimateHeaderOverhead(encLevel)
        if (remaining <= 64) { return }

        match (encLevel) {
            case EncryptionLevel.Initial =>
                if (cryptoStreamMgr.getInitialStream().hasData()) {
                    if (let Some(cf) <- cryptoStreamMgr.getInitialStream().popCryptoFrame(remaining)) {
                        framerObj.queueFrame(cf)
                    }
                }
            case EncryptionLevel.Handshake =>
                if (cryptoStreamMgr.getHandshakeStream().hasData()) {
                    if (let Some(cf) <- cryptoStreamMgr.getHandshakeStream().popCryptoFrame(remaining)) {
                        framerObj.queueFrame(cf)
                    }
                }
            case _ =>
                if (cryptoStreamMgr.getOneRTTStream().hasData()) {
                    if (let Some(cf) <- cryptoStreamMgr.getOneRTTStream().popCryptoFrame(remaining)) {
                        framerObj.queueFrame(cf)
                    }
                }
        }
    }

    /// 估计给定加密级别的包头开销。
   private func estimateHeaderOverhead(encLevel: EncryptionLevel): Int64 {
       match (encLevel) {
           case EncryptionLevel.Initial => 50 + Int64(destConnId.size) + Int64(srcConnId.size)
          case EncryptionLevel.Handshake => 30 + Int64(destConnId.size) + Int64(srcConnId.size)
           case EncryptionLevel.ZeroRTT => 30 + Int64(destConnId.size) + Int64(srcConnId.size)
          case _ => 5 + Int64(destConnId.size)
       }
   }
}

/// 创建客户端 QUIC 连接。
public func newClientConnection(destConnId: Array<Byte>, srcConnId: Array<Byte>): Connection {
    Connection(VERSION_1, Perspective.Client, srcConnId, destConnId)
}

/// 创建服务端 QUIC 连接。
public func newServerConnection(destConnId: Array<Byte>): Connection {
    Connection(VERSION_1, Perspective.Server, destConnId, destConnId)
}

/// appendByteArray 将一个字节数组追加到字节数组的数组中。
internal func appendByteArray(arr: Array<Array<Byte>>, item: Array<Byte>): Array<Array<Byte>> {
    let n = arr.size
    var out = Array<Array<Byte>>(n + 1, repeat: [])
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = item
    out
}
