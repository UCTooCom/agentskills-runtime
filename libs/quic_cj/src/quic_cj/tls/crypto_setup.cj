package quic_cj.tls

import jinguissl_core.crypto.x25519.{x25519GeneratePrivateKey, x25519PublicFromPrivate}
 import jinguissl.contract.{contractX25519GenerateKeyPair}
import jinguissl.live.{ContractTlsSessionCache, ContractTlsSessionIdentity, ContractTlsSessionTicket, ContractTlsVersion, contractTlsEncodeSessionTicket}
 import jinguissl_core.crypto.tls.{Tls13HandshakeSecrets, tls13BuildClientHelloX25519, Tls13EarlyDataSecrets, tls13BuildClientHelloPskWithBinder, tls13VerifyClientPskBinder}
import jinguissl_core.crypto.tls.{tls13CipherSuiteKeyLen, tls13CipherSuiteIvLen}
import jinguissl_core.crypto.x25519.{x25519DeriveSharedSecret}
import quic_cj.protocol.{EncryptionLevel, PacketNumber}
import quic_cj.wire.{appendVarint, appendByte, appendBytes}

public enum HandshakeState {
    | Initial
    | SentClientHello
    | ReceivedServerFlight
    | SentClientFlight
    | Complete
    | Failed
}

private func encLevelIs(level: EncryptionLevel, target: EncryptionLevel): Bool {
    match (level) {
        case EncryptionLevel.Initial => match (target) { case EncryptionLevel.Initial => true; case _ => false }
        case EncryptionLevel.Handshake => match (target) { case EncryptionLevel.Handshake => true; case _ => false }
        case EncryptionLevel.ZeroRTT => match (target) { case EncryptionLevel.ZeroRTT => true; case _ => false }
        case EncryptionLevel.OneRTT => match (target) { case EncryptionLevel.OneRTT => true; case _ => false }
    }
}

public class CryptoSetup {
    private var state: HandshakeState = HandshakeState.Initial
    private var clientPrivateKey: Array<Byte> = []
    private var clientPublicKey: Array<Byte> = []
    private var encodedClientHello: Array<Byte> = []
    private var serverFlight: Array<Byte> = []
    private var isV2: Bool = false
    private var serverName: String = ""

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

     // 会话缓存（用于 PSK 会话恢复和 0-RTT）
     private var sessionCache: ?ContractTlsSessionCache = None
     private var sessionIdentity: ?ContractTlsSessionIdentity = None
     private var sessionTicket: ?ContractTlsSessionTicket = None
 
     // 0-RTT / 早期数据
     private var earlyDataSecrets: ?Tls13EarlyDataSecrets = None
     private var zeroRttKey: Array<Byte> = []
     private var zeroRttIv: Array<Byte> = []
     private var zeroRttHpKey: Array<Byte> = []
     private var zeroRttAvailable: Bool = false
 
    private var keyLen: Int64 = 16
    private var ivLen: Int64 = 12

    public init(connId: Array<Byte>, isV2: Bool, serverName: String, alpn: Array<String>) {
        this.isV2 = isV2
        this.serverName = serverName
        let initial = InitialAEAD(connId, isV2)
        initialKey = initial.getKey()
        initialIv = initial.getIv()
        initialHpKey = initial.getHpKey()
 
         // 初始化会话缓存和身份
         try {
             let cache = ContractTlsSessionCache(maxEntries: 16, defaultTtlSeconds: 7200)
             sessionCache = Some(cache)
            let identity = ContractTlsSessionIdentity(
                 ContractTlsVersion.Tls13,
                connId,
                serverName: serverName
            )
             sessionIdentity = Some(identity)
         } catch (_: Exception) {
             sessionCache = None
             sessionIdentity = None
         }
    }

    public func buildClientHello(): Array<Byte> {
        let keyPair = contractX25519GenerateKeyPair()
        clientPrivateKey = keyPair.privateKey
        clientPublicKey = keyPair.publicKey
 
         // 检查是否有可用的会话缓存 ticket
         var ch: Array<Byte> = []
         match (sessionCache) {
             case Some(cache) =>
                 match (sessionIdentity) {
                     case Some(identity) =>
                         let now = 0
                         let loaded = cache.load(identity, nowUnixSeconds: now)
                         match (loaded) {
                             case Some(ticket) =>
                                 sessionTicket = Some(ticket)
                                 // 使用 PSK 构建 ClientHello（通过 contractTlsEncodeSessionTicket 获取 PSK 标识）
                                 try {
                                     let pskIdentity = contractTlsEncodeSessionTicket(ticket)
                                     ch = tls13BuildClientHelloPskWithBinder(pskIdentity, ticket.secret)
                                 } catch (_: Exception) {
                                     ch = tls13BuildClientHelloX25519(clientPublicKey)
                                 }
                             case None =>
                                 ch = tls13BuildClientHelloX25519(clientPublicKey)
                         }
                     case None =>
                         ch = tls13BuildClientHelloX25519(clientPublicKey)
                 }
             case None =>
                 ch = tls13BuildClientHelloX25519(clientPublicKey)
         }
 
         encodedClientHello = ch
        state = HandshakeState.SentClientHello
        encodedClientHello
    }

    public func handleServerFlight(serverFlightData: Array<Byte>): Bool {
        if (encodedClientHello.size == 0 || clientPrivateKey.size == 0) { return false }
        let messages = parseTlsHandshakeMessages(serverFlightData)
        if (messages.size == 0) { return false }
        var serverHelloMsg: TlsHandshakeMessage = TlsHandshakeMessage()
        var foundHello: Bool = false
        var i: Int64 = 0
        while (i < messages.size) {
            let isSh = match (messages[i].msgType) { case 2u8 => true; case _ => false }
            if (isSh) { serverHelloMsg = messages[i]; foundHello = true; break }
            i += 1
        }
        if (!foundHello) { return false }
        let serverKey = extractServerKeyShareFromServerHello(serverHelloMsg.body)
        if (serverKey.size != 32) { return false }
 
         // 尝试使用 PSK binder 验证
         match (sessionTicket) {
             case Some(ticket) =>
                 var binderOk: Bool = false
                 try {
                     let _ = tls13VerifyClientPskBinder(encodedClientHello, ticket.secret)
                     binderOk = true
                 } catch (_: Exception) {
                     binderOk = false
                 }
             case None => ()
         }
 
        let sharedSecret = x25519DeriveSharedSecret(clientPrivateKey, serverKey)
        var transcriptMessages: Array<Array<Byte>> = [encodedClientHello]
        var j: Int64 = 0
        while (j < messages.size) {
            transcriptMessages = appendTranscriptBytes(transcriptMessages, messages[j].rawBytes)
            j += 1
        }
        let secrets = deriveTls13HandshakeSecrets(sharedSecret, transcriptMessages)
        deriveHandshakeKeys(secrets)
 
         // 检查 0-RTT / 早期数据可用性
         let earlySecret = secrets.earlySecret
         if (earlySecret.size > 0) {
             zeroRttAvailable = true
             let keyLabel = if (isV2) { "quicv2 key" } else { "quic key" }
             let ivLabel  = if (isV2) { "quicv2 iv"  } else { "quic iv"  }
             let hpLabel  = if (isV2) { "quicv2 hp"  } else { "quic hp"  }
             zeroRttKey    = quicHkdfExpandLabel(earlySecret, keyLabel, [], keyLen)
             zeroRttIv     = quicHkdfExpandLabel(earlySecret, ivLabel,  [], ivLen)
             zeroRttHpKey  = quicHkdfExpandLabel(earlySecret, hpLabel,  [], 16)
         }
 
         // 将会话 ticket 保存到缓存
         match (sessionCache) {
             case Some(cache) =>
                 match (sessionIdentity) {
                     case Some(identity) =>
                         try {
                             let now = 0
                             let storedTicket = cache.storeFromSecret(
                                 identity,
                                 secrets.clientHsTrafficSecret,
                                 nonce: [],
                                 nowUnixSeconds: now,
                                 ttlSeconds: 7200
                             )
                             sessionTicket = Some(storedTicket)
                         } catch (_: Exception) {
                             // 缓存故障可安全忽略
                         }
                     case None => ()
                 }
             case None => ()
         }
 
        state = HandshakeState.ReceivedServerFlight
        true
    }

    public func deriveHandshakeKeys(secrets: Tls13HandshakeSecrets): Unit {
        let keyLabel = if (isV2) { "quicv2 key" } else { "quic key" }
        let ivLabel  = if (isV2) { "quicv2 iv"  } else { "quic iv"  }
        let hpLabel  = if (isV2) { "quicv2 hp"  } else { "quic hp"  }

         // 使用 jinguissl_core 密码套件查询确定密钥长度
         let suiteId: UInt16 = 0x1301u16 // TLS_AES_128_GCM_SHA256
         try {
             let actualKeyLen = tls13CipherSuiteKeyLen(Int64(suiteId))
             if (actualKeyLen > 0) { keyLen = actualKeyLen }
             let actualIvLen = tls13CipherSuiteIvLen(Int64(suiteId))
             if (actualIvLen > 0) { ivLen = actualIvLen }
         } catch (_: Exception) {
             // 使用默认值
         }
 
        handshakeKey = quicHkdfExpandLabel(secrets.clientHsTrafficSecret, keyLabel, [], keyLen)
        handshakeIv  = quicHkdfExpandLabel(secrets.clientHsTrafficSecret, ivLabel,  [], ivLen)
        handshakeHpKey = quicHkdfExpandLabel(secrets.clientHsTrafficSecret, hpLabel,  [], 16)

        oneRttKey   = quicHkdfExpandLabel(secrets.clientAppTrafficSecret, keyLabel, [], keyLen)
        oneRttIv    = quicHkdfExpandLabel(secrets.clientAppTrafficSecret, ivLabel,  [], ivLen)
        oneRttHpKey = quicHkdfExpandLabel(secrets.clientAppTrafficSecret, hpLabel,  [], 16)
        oneRttAeadFull = newUpdatableAEADFull(oneRttKey, oneRttIv)
    }

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

    /// 如果 TLS 握手已完成则返回 true。
    public func handshakeComplete(): Bool {
        match (state) {
            case HandshakeState.Complete => true
            case _ => false
        }
    }

    /// 处理给定加密级别的入站 TLS 握手数据。
    /// 将 Initial 级别的数据路由到 handleServerFlight 进行密钥派生。
    public func handleMessage(data: Array<Byte>, level: EncryptionLevel): Unit {
        match (level) {
            case EncryptionLevel.Initial =>
                if (encLevelIs(level, EncryptionLevel.Initial)) {
                    let ok = handleServerFlight(data)
                    if (ok) { state = HandshakeState.Complete }
                }
            case EncryptionLevel.Handshake =>
                // 在完整实现中，处理 EncryptedExtensions/Certificate/Finished
                state = HandshakeState.Complete
            case EncryptionLevel.OneRTT =>
                state = HandshakeState.Complete
            case _ => ()
        }
    }

    public func getState(): HandshakeState { state }
    public func getEncodedClientHello(): Array<Byte> { encodedClientHello }
    /// 获取 1-RTT UpdatableAEADFull 实例，用于密钥更新。
    public func getOneRttAeadFull(): UpdatableAEADFull { oneRttAeadFull }
    /// 返回 1-RTT 密钥导出后的 AEAD 是否就绪。
    public func hasOneRttKeys(): Bool { oneRttKey.size > 0 }
 
     // ── 会话缓存 / PSK ──
 
     /// 返回会话缓存实例（如果有）。
     public func getSessionCache(): ?ContractTlsSessionCache { sessionCache }
 
     /// 获取缓存的会话 ticket（用于 PSK 恢复）。
     public func getSessionTicket(): ?ContractTlsSessionTicket { sessionTicket }
 
     /// 手动将 session ticket 保存到缓存。
     public func storeSessionTicket(ticket: ContractTlsSessionTicket): Unit {
         sessionTicket = Some(ticket)
         match (sessionCache) {
             case Some(cache) =>
                 try {
                     cache.store(ticket)
                 } catch (_: Exception) {
                     // 可安全忽略
                 }
             case None => ()
         }
     }
 
     // ── 0-RTT / 早期数据 ──
 
     /// 0-RTT / 早期数据是否可用。
     public func isZeroRttAvailable(): Bool { zeroRttAvailable }
 
     /// 返回 0-RTT 密钥。
     public func getZeroRttKey(): Array<Byte> { zeroRttKey }
 
     /// 返回 0-RTT IV。
     public func getZeroRttIv(): Array<Byte> { zeroRttIv }
 
     /// 返回 0-RTT 头部保护密钥。
     public func getZeroRttHpKey(): Array<Byte> { zeroRttHpKey }
 
     /// 从 NewSessionTicket 消息加载早期数据密钥。
     public func loadEarlyDataFromSessionTicket(ticket: ContractTlsSessionTicket, earlySecret: Array<Byte>): Bool {
         if (earlySecret.size == 0) { return false }
         let keyLabel = if (isV2) { "quicv2 key" } else { "quic key" }
         let ivLabel  = if (isV2) { "quicv2 iv"  } else { "quic iv"  }
         let hpLabel  = if (isV2) { "quicv2 hp"  } else { "quic hp"  }
         zeroRttKey    = quicHkdfExpandLabel(earlySecret, keyLabel, [], keyLen)
         zeroRttIv     = quicHkdfExpandLabel(earlySecret, ivLabel,  [], ivLen)
         zeroRttHpKey  = quicHkdfExpandLabel(earlySecret, hpLabel,  [], 16)
         zeroRttAvailable = true
         true
     }
}

internal func appendTranscriptBytes(
    arr: Array<Array<Byte>>,
    msg: Array<Byte>
): Array<Array<Byte>> {
    let n = arr.size
    let out = Array<Array<Byte>>(n + 1, repeat: [])
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = msg
    out
}
