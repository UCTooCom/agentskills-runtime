package quic_cj.tls

import jinguissl.contract.contractX25519GenerateKeyPair
import jinguissl_core.crypto.x25519.X25519_KEY_LEN
import jinguissl.live.{ContractTlsSessionCache, ContractTlsSessionTicket, ContractTlsSessionIdentity, ContractTlsVersion, ContractTls13EarlyDataReplayCache}
import jinguissl_core.crypto.tls.{
    Tls13HandshakeSecrets,
    Tls13PskIdentityEntry,
    Tls13ServerHandshakeContext,
    Tls13ServerHandshakeFlight,
    tls13BuildServerHandshakeContextX25519,
    tls13BuildServerHelloForPskFromSessionTicket,
    tls13CipherSuiteKeyLen,
    tls13CipherSuiteIvLen,
    tls13ExtractClientPskIdentities
}
import jinguissl_core.crypto.ecc.EcPrivateKey
import jinguissl_core.crypto.rsa.RsaPrivateKey
import quic_cj.protocol.EncryptionLevel
import quic_cj.wire.{appendVarint, appendByte, appendBytes}

/// ServerCryptoSetup 处理 QUIC 服务端的 TLS 1.3 握手。
///
/// 使用 jinguissl_core 的 tls13BuildServerHandshakeContextX25519 一次完成
/// 完整的服务端握手飞行（ServerHello + EncryptedExtensions + CertificateVerify + Finished）
/// 和密钥派生，消除手动握手逻辑。
public class ServerCryptoSetup {
    private var state: HandshakeState = HandshakeState.Initial
    private var serverPrivateKey: Array<Byte> = []
    private var serverPublicKey: Array<Byte> = []
    private var isV2: Bool = false

    // 服务端证书链及签名私钥
    private var certChainDer: Array<Array<Byte>> = []
    private var ecdsaKey: ?EcPrivateKey = None
    private var rsaKey: ?RsaPrivateKey = None

    // ALPN 偏好
    private var alpnPreference: Array<String> = []

    // 握手密钥
    private var initialKey: Array<Byte> = []
    private var initialIv: Array<Byte> = []
    private var initialHpKey: Array<Byte> = []
    private var handshakeKey: Array<Byte> = []
    private var handshakeIv: Array<Byte> = []
    private var handshakeHpKey: Array<Byte> = []
    private var oneRttKey: Array<Byte> = []
    private var oneRttIv: Array<Byte> = []
    private var oneRttHpKey: Array<Byte> = []
    private var oneRttAeadFull: UpdatableAEADFull = UpdatableAEADFull([], [])

    private var keyLen: Int64 = 16
    private var ivLen: Int64 = 12
    private var zeroRttKey: Array<Byte> = []
    private var zeroRttIv: Array<Byte> = []
    private var zeroRttHpKey: Array<Byte> = []
    private var zeroRttAvailable: Bool = false

    // jinguissl 服务端握手上下文
    private var serverCtx: ?Tls13ServerHandshakeContext = None

    /// 创建 ServerCryptoSetup。
    /// connId — 连接 ID（用于初始密钥派生）
    /// isV2 — 是否使用 QUIC v2
    /// certChain — 服务端证书链 DER
    /// ecdsaPrivate — ECDSA 签名私钥（可选，与 rsaPrivate 二选一）
    /// rsaPrivate — RSA-PSS 签名私钥（可选，与 ecdsaPrivate 二选一）
    /// alpn — ALPN 协议列表
    public init(
        connId: Array<Byte>,
        isV2: Bool,
        certChain: Array<Array<Byte>>,
        ecdsaPrivate!: ?EcPrivateKey = None,
        rsaPrivate!: ?RsaPrivateKey = None,
        alpn!: Array<String> = []
    ) {
        this.isV2 = isV2
        this.certChainDer = certChain
        this.ecdsaKey = ecdsaPrivate
        this.rsaKey = rsaPrivate
        this.alpnPreference = alpn

        // 派生初始密钥
        let initial = InitialAEAD(connId, isV2)
        initialKey = initial.getKey()
        initialIv = initial.getIv()
        initialHpKey = initial.getHpKey()

        // 确定密钥长度
        try {
            let suiteId: Int64 = 0x1301
            let actualKeyLen = tls13CipherSuiteKeyLen(suiteId)
            if (actualKeyLen > 0) { keyLen = actualKeyLen }
            let actualIvLen = tls13CipherSuiteIvLen(suiteId)
            if (actualIvLen > 0) { ivLen = actualIvLen }
        } catch (_: Exception) {}
    }

    /// 处理客户端 ClientHello，构建完整的服务端飞行并派生密钥。
    /// clientHelloData — 完整的 ClientHello 握手帧字节
    /// 返回 (ok, serverFlightData)
    public func handleClientHello(clientHelloData: Array<Byte>): (Bool, Array<Byte>) {
        if (clientHelloData.size == 0) { return (false, []) }

        // 1. 生成服务端 X25519 密钥对
        let keyPair = contractX25519GenerateKeyPair()
        serverPrivateKey = keyPair.privateKey
        serverPublicKey = keyPair.publicKey

        // 2. 使用 jinguissl_core 构建完整的服务端握手上下文
        var ctx: Tls13ServerHandshakeContext = try {
            tls13BuildServerHandshakeContextX25519(
                clientHelloData,
                serverPrivateKey,
                serverPublicKey,
                certChainDer,
                certificatePrivateKeyEcdsa: ecdsaKey,
                certificatePrivateKeyRsa: rsaKey,
                alpnPreference: alpnPreference,
                acknowledgeServerName: true
            )
        } catch (_: Exception) {
            return (false, [])
        }
        serverCtx = Some(ctx)

        // 3. 从握手密钥派生 QUIC 密钥
        let secrets = ctx.secrets
        deriveKeys(secrets)

        state = HandshakeState.Complete

        // 4. 串联飞行消息
        let flight = concatServerFlight(ctx.flight)
        (true, flight)
    }

    /// 派生 QUIC 握手、1-RTT 和 0-RTT 密钥
    private func deriveKeys(secrets: Tls13HandshakeSecrets): Unit {
        let keyLabel = if (isV2) { "quicv2 key" } else { "quic key" }
        let ivLabel  = if (isV2) { "quicv2 iv"  } else { "quic iv"  }
        let hpLabel  = if (isV2) { "quicv2 hp"  } else { "quic hp"  }

        // 服务端握手写入密钥
        handshakeKey = quicHkdfExpandLabel(secrets.serverHsTrafficSecret, keyLabel, [], keyLen)
        handshakeIv  = quicHkdfExpandLabel(secrets.serverHsTrafficSecret, ivLabel,  [], ivLen)
        handshakeHpKey = quicHkdfExpandLabel(secrets.serverHsTrafficSecret, hpLabel,  [], 16)

        // 服务端 1-RTT 写入密钥
        oneRttKey   = quicHkdfExpandLabel(secrets.serverAppTrafficSecret, keyLabel, [], keyLen)
        oneRttIv    = quicHkdfExpandLabel(secrets.serverAppTrafficSecret, ivLabel,  [], ivLen)
        oneRttHpKey = quicHkdfExpandLabel(secrets.serverAppTrafficSecret, hpLabel,  [], 16)
        oneRttAeadFull = newUpdatableAEADFull(oneRttKey, oneRttIv)

        // 服务端 0-RTT 密钥：从 earlySecret 派生（PSK 会话恢复时可用）
        let earlySecret = secrets.earlySecret
        if (earlySecret.size > 0) {
            zeroRttKey    = quicHkdfExpandLabel(earlySecret, keyLabel, [], keyLen)
            zeroRttIv     = quicHkdfExpandLabel(earlySecret, ivLabel,  [], ivLen)
            zeroRttHpKey  = quicHkdfExpandLabel(earlySecret, hpLabel,  [], 16)
            zeroRttAvailable = true
        }
    }

    /// 获取 ServerHello（Initial 级别 CRYPTO 帧数据）
    public func getServerHelloData(): Array<Byte> {
        match (serverCtx) {
            case Some(ctx) => ctx.flight.serverHello
            case None => []
        }
    }

    /// 获取服务端 Handshake 级别飞行（EncryptedExtensions + Certificate + CertificateVerify + Finished）
    public func getHandshakeFlightData(): Array<Byte> {
        match (serverCtx) {
            case Some(ctx) => concatHandshakeFlight(ctx.flight)
            case None => []
        }
    }

    /// 获取完整的服务端飞行数据（所有消息串联）
    public func getFullFlightData(): Array<Byte> {
        match (serverCtx) {
            case Some(ctx) => concatServerFlight(ctx.flight)
            case None => []
        }
    }

    /// 获取指定加密级别的 AEAD。
    public func getAead(level: EncryptionLevel): UpdatableAEAD {
        if (encLevelIs(level, EncryptionLevel.Initial)) {
            UpdatableAEAD(initialKey, initialIv)
        } else if (encLevelIs(level, EncryptionLevel.Handshake)) {
            UpdatableAEAD(handshakeKey, handshakeIv)
        } else if (encLevelIs(level, EncryptionLevel.ZeroRTT)) {
            UpdatableAEAD(zeroRttKey, zeroRttIv)
        } else {
            UpdatableAEAD(oneRttKey, oneRttIv)
        }
    }

    /// 获取指定加密级别的头部保护密钥。
    public func getHpKey(level: EncryptionLevel): Array<Byte> {
        if (encLevelIs(level, EncryptionLevel.Initial)) {
            initialHpKey
        } else if (encLevelIs(level, EncryptionLevel.Handshake)) {
            handshakeHpKey
        } else if (encLevelIs(level, EncryptionLevel.ZeroRTT)) {
            zeroRttHpKey
        } else {
            oneRttHpKey
        }
    }

    /// 获取已协商的 ALPN 协议。
    public func getSelectedAlpn(): String {
        match (serverCtx) {
            case Some(ctx) => ctx.flight.selectedAlpn
            case None => ""
        }
    }

    /// 握手是否完成。
    public func handshakeComplete(): Bool {
        match (state) {
            case HandshakeState.Complete => true
            case _ => false
        }
    }

    /// 1-RTT 密钥是否就绪。
    public func hasOneRttKeys(): Bool { oneRttKey.size > 0 }

    /// 0-RTT 是否可用（PSK 会话恢复时）。
    public func isZeroRttAvailable(): Bool { zeroRttAvailable }

    /// 获取 1-RTT UpdatableAEADFull。
    public func getOneRttAeadFull(): UpdatableAEADFull { oneRttAeadFull }

    /// 串联 ServerHello 和后续握手飞行。
    private static func concatServerFlight(flight: Tls13ServerHandshakeFlight): Array<Byte> {
        let sh = flight.serverHello
        let ee = flight.encryptedExtensions
        let auth = flight.authFlight
        let cert = auth.certificateHandshake
        let cv = auth.certificateVerifyHandshake
        let fin = auth.finishedHandshake
        concatThree(sh, ee, cert, cv, fin)
    }

    /// 串联 EncryptedExtensions + Certificate + CertificateVerify + Finished。
    private static func concatHandshakeFlight(flight: Tls13ServerHandshakeFlight): Array<Byte> {
        let ee = flight.encryptedExtensions
        let auth = flight.authFlight
        let cert = auth.certificateHandshake
        let cv = auth.certificateVerifyHandshake
        let fin = auth.finishedHandshake
        concatThree(ee, cert, cv, fin)
    }

    /// 串联 5 个字节数组。
    private static func concatThree(
        a: Array<Byte>, b: Array<Byte>, c: Array<Byte>,
        d: Array<Byte>, e: Array<Byte>
    ): Array<Byte> {
        let n1 = a.size; let n2 = b.size; let n3 = c.size
        let n4 = d.size; let n5 = e.size
        let total = n1 + n2 + n3 + n4 + n5
        let out = Array<Byte>(total, repeat: 0u8)
        var i: Int64 = 0
        while (i < n1) { out[i] = a[i]; i += 1 }
        i = 0
        while (i < n2) { out[n1 + i] = b[i]; i += 1 }
        i = 0
        while (i < n3) { out[n1 + n2 + i] = c[i]; i += 1 }
        i = 0
        while (i < n4) { out[n1 + n2 + n3 + i] = d[i]; i += 1 }
        i = 0
        while (i < n5) { out[n1 + n2 + n3 + n4 + i] = e[i]; i += 1 }
        out
    }
}

private func encLevelIs(level: EncryptionLevel, target: EncryptionLevel): Bool {
    match (level) {
        case EncryptionLevel.Initial => match (target) { case EncryptionLevel.Initial => true; case _ => false }
        case EncryptionLevel.Handshake => match (target) { case EncryptionLevel.Handshake => true; case _ => false }
        case EncryptionLevel.ZeroRTT => match (target) { case EncryptionLevel.ZeroRTT => true; case _ => false }
        case EncryptionLevel.OneRTT => match (target) { case EncryptionLevel.OneRTT => true; case _ => false }
    }
}
