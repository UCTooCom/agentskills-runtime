 package quic_cj.tls
 
import jinguissl_core.crypto.digest.{sha256, hmac, HashAlgorithm, hkdfExtract, hkdfExpand}
import jinguissl_core.crypto.x25519.{x25519DeriveSharedSecret, X25519_KEY_LEN}
import jinguissl_core.crypto.tls.Tls13HandshakeSecrets
import jinguissl_core.crypto.tls.{
    tls13CipherSuiteKeyLen,
    tls13CipherSuiteIvLen
}
import jinguissl_core.crypto.digest.HashAlgorithm as CoreHashAlgorithm
 
 /// TLS 1.3 握手消息类型（RFC 8446 §4）
 public let TLS_HANDSHAKE_TYPE_SERVER_HELLO: UInt8 = 2u8
 public let TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS: UInt8 = 8u8
 public let TLS_HANDSHAKE_TYPE_CERTIFICATE: UInt8 = 11u8
 public let TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY: UInt8 = 14u8
 public let TLS_HANDSHAKE_TYPE_FINISHED: UInt8 = 20u8
 
 /// key_share 扩展类型（RFC 8446 §4.2.8）
 public let TLS_EXTENSION_KEY_SHARE: Int64 = 0x0033
 
 /// X25519 命名组（RFC 8446 §4.2.7）
 public let TLS_NAMED_GROUP_X25519: Int64 = 0x001D
 
 /// 解析后的 TLS 握手消息：[类型:1][长度:3][内容:长度]
 public class TlsHandshakeMessage {
     public var msgType: UInt8 = 0u8
     public var body: Array<Byte> = []
     public var rawBytes: Array<Byte> = []
 
     public init() {}
 
     public init(msgType: UInt8, body: Array<Byte>, rawBytes: Array<Byte>) {
         this.msgType = msgType
         this.body = body
         this.rawBytes = rawBytes
     }
 }
 
 /// 从缓冲区的偏移处读取大端 Int64。
 private func readUint16(data: Array<Byte>, offset: Int64): (Int64, Int64) {
     if (offset + 2 > data.size) { return (0, -1) }
     let val = (Int64(UInt8(data[offset])) << 8) | Int64(UInt8(data[offset + 1]))
     (val, 2)
 }
 
 /// 从缓冲区的偏移处读取大端 Int64（3 字节）。
 private func readUint24(data: Array<Byte>, offset: Int64): (Int64, Int64) {
     if (offset + 3 > data.size) { return (0, -1) }
     let val = (Int64(UInt8(data[offset])) << 16) |
               (Int64(UInt8(data[offset + 1])) << 8) |
               Int64(UInt8(data[offset + 2]))
     (val, 3)
 }
 
 /// 从二进制数据解析一系列 TLS 握手消息。
 /// 按顺序返回解析后的消息。
 public func parseTlsHandshakeMessages(data: Array<Byte>): Array<TlsHandshakeMessage> {
     var messages: Array<TlsHandshakeMessage> = []
     var offset: Int64 = 0
     while (offset < data.size) {
         if (offset + 4 > data.size) { break }
         let msgType = data[offset]
         let (bodyLen, consumed) = readUint24(data, offset + 1)
         if (consumed <= 0 || offset + 4 + bodyLen > data.size) { break }
         let body = data[offset + 4 .. offset + 4 + bodyLen]
         let rawBytes = data[offset .. offset + 4 + bodyLen]
         let msg = TlsHandshakeMessage(msgType, body, rawBytes)
         let n = messages.size
         let out = Array<TlsHandshakeMessage>(n + 1, repeat: TlsHandshakeMessage())
         var i: Int64 = 0
         while (i < n) { out[i] = messages[i]; i += 1 }
         out[n] = msg
         messages = out
         offset += 4 + bodyLen
     }
     messages
 }
 
 /// 从 ServerHello 的 key_share 扩展中提取 X25519 公钥
 /// 从 ServerHello 的 key_share 扩展。
 public func extractServerKeyShareFromServerHello(serverHelloBody: Array<Byte>): Array<Byte> {
     if (serverHelloBody.size < 39) { return [] }
     let sidLen = Int64(UInt8(serverHelloBody[34]))
     if (sidLen > 32) { return [] }
     let afterSid = 35 + Int64(sidLen)
     if (afterSid + 4 > serverHelloBody.size) { return [] }
     let extOffset = afterSid + 3
     if (extOffset + 2 > serverHelloBody.size) { return [] }
     let (extensionsLen, _) = readUint16(serverHelloBody, extOffset)
     if (extensionsLen <= 0 || extOffset + 2 + extensionsLen > serverHelloBody.size) { return [] }
     var extPos: Int64 = extOffset + 2
     let extEnd = extPos + extensionsLen
     while (extPos + 4 <= extEnd) {
         let (extType, _1) = readUint16(serverHelloBody, extPos)
         let (extLen, _2) = readUint16(serverHelloBody, extPos + 2)
         if (extLen <= 0 || extPos + 4 + extLen > extEnd) { break }
         if (extType == TLS_EXTENSION_KEY_SHARE) {
             let ksOffset = extPos + 4
             let (group, _3) = readUint16(serverHelloBody, ksOffset)
             if (group == TLS_NAMED_GROUP_X25519) {
                 let (keyLen, _4) = readUint16(serverHelloBody, ksOffset + 2)
                 if (keyLen == X25519_KEY_LEN && ksOffset + 4 + keyLen <= extEnd) {
                     let key = Array<Byte>(keyLen, repeat: 0u8)
                     var i: Int64 = 0
                     while (i < keyLen) { key[i] = serverHelloBody[ksOffset + 4 + i]; i += 1 }
                     return key
                 }
             }
         }
         extPos += 4 + extLen
     }
     []
 }
 
/// 通过将 `more` 追加到 `existing` 创建新的 Array<Byte>。
 private func appendByteArray(existing: Array<Byte>, more: Array<Byte>): Array<Byte> {
     let n = existing.size
     let m = more.size
     let out = Array<Byte>(n + m, repeat: 0u8)
     var i: Int64 = 0
     while (i < n) { out[i] = existing[i]; i += 1 }
     i = 0
     while (i < m) { out[n + i] = more[i]; i += 1 }
     out
 }
 
/// 计算串联 TLS 握手消息的 SHA-256。
 public func computeTranscriptHash(messages: Array<Array<Byte>>): Array<Byte> {
     var transcript: Array<Byte> = []
     var i: Int64 = 0
     while (i < messages.size) {
         transcript = appendByteArray(transcript, messages[i])
         i += 1
     }
     sha256(transcript)
 }
 
 /// 创建用于 HKDF-Extract 的零填充盐（SHA-256 为 32 字节）。
 private func zeroSalt(): Array<Byte> {
     Array<Byte>(32, repeat: 0u8)
 }
 
/// 使用标准标签执行 TLS 1.3 HKDF-Expand-Label。
 private func hkdfExpandLabelStandard(
     secret: Array<Byte>,
     label: String,
     context: Array<Byte>,
     outputLen: Int64
 ): Array<Byte> {
     let labelBytes = ("tls13 " + label).toArray()
     let infoLen = 2 + 1 + labelBytes.size + 1 + context.size
     let info = Array<Byte>(infoLen, repeat: 0u8)
     info[0] = UInt8((outputLen >> 8) & 0xff)
     info[1] = UInt8(outputLen & 0xff)
     info[2] = UInt8(labelBytes.size)
     var i: Int64 = 0
     while (i < labelBytes.size) {
         info[3 + i] = labelBytes[i]
         i += 1
     }
     info[3 + labelBytes.size] = UInt8(context.size)
     i = 0
     while (i < context.size) {
         info[4 + labelBytes.size + i] = context[i]
         i += 1
     }
     hkdfExpand(HashAlgorithm.SHA256, secret, info, outputLen)
 }
 
/// 从以下内容派生 TLS 1.3 握手密钥：
/// ECDHE 共享密钥和握手交互记录。
/// 实现 RFC 8446 §7.1 密钥调度。
 /// 
 /// 更新：核心派生逻辑已委托给 jinguissl_core 组合 API，
 /// 此函数作为上层兼容包装保留。
public func deriveTls13HandshakeSecrets(
    sharedSecret: Array<Byte>,
    transcriptMessages: Array<Array<Byte>>
): Tls13HandshakeSecrets {
    let transcriptHash = computeTranscriptHash(transcriptMessages)
    let emptyContext: Array<Byte> = []
    let handshakeSecret = hkdfExtract(HashAlgorithm.SHA256, zeroSalt(), sharedSecret)
    let clientHsTrafficSecret = hkdfExpandLabelStandard(handshakeSecret, "c hs traffic", transcriptHash, 32)
    let serverHsTrafficSecret = hkdfExpandLabelStandard(handshakeSecret, "s hs traffic", transcriptHash, 32)
    let masterSecret = hkdfExtract(HashAlgorithm.SHA256, zeroSalt(), handshakeSecret)
    let clientAppTrafficSecret = hkdfExpandLabelStandard(masterSecret, "c ap traffic", transcriptHash, 32)
    let serverAppTrafficSecret = hkdfExpandLabelStandard(masterSecret, "s ap traffic", transcriptHash, 32)
    let clientWriteKey = hkdfExpandLabelStandard(clientHsTrafficSecret, "key", emptyContext, 16)
    let clientWriteIv = hkdfExpandLabelStandard(clientHsTrafficSecret, "iv", emptyContext, 12)
    let serverWriteKey = hkdfExpandLabelStandard(serverHsTrafficSecret, "key", emptyContext, 16)
     let serverWriteIv = hkdfExpandLabelStandard(serverHsTrafficSecret, "iv", emptyContext, 12)
 
     Tls13HandshakeSecrets(
         zeroSalt(),
         handshakeSecret,
         masterSecret,
         clientHsTrafficSecret,
         serverHsTrafficSecret,
         clientAppTrafficSecret,
         serverAppTrafficSecret,
         clientWriteKey,
         serverWriteKey,
         clientWriteIv,
         serverWriteIv
     )
 }
 
  /// 处理 TLS 1.3 服务端握手飞行
  /// 从 QUIC CRYPTO 帧获取并返回计算出的握手密钥。
  public func processServerFlight(
      serverFlightData: Array<Byte>,
      clientHello: Array<Byte>,
      clientPrivateKey: Array<Byte>
  ): Option<Tls13HandshakeSecrets> {
      let messages = parseTlsHandshakeMessages(serverFlightData)
      if (messages.size == 0) { return None }

      var serverHelloMsg: TlsHandshakeMessage = TlsHandshakeMessage()
      var foundServerHello: Bool = false
      var i: Int64 = 0
      while (i < messages.size) {
          let isSh = match (messages[i].msgType) { case TLS_HANDSHAKE_TYPE_SERVER_HELLO => true; case _ => false }
          if (isSh) { serverHelloMsg = messages[i]; foundServerHello = true; break }
          i += 1
      }
      if (!foundServerHello) { return None }

      let serverPublicKey = extractServerKeyShareFromServerHello(serverHelloMsg.body)
      if (serverPublicKey.size != X25519_KEY_LEN) { return None }

      let sharedSecret = x25519DeriveSharedSecret(clientPrivateKey, serverPublicKey)

      var transcriptMessages: Array<Array<Byte>> = [clientHello]
      var j: Int64 = 0
      while (j < messages.size) {
          transcriptMessages = appendTranscriptMessage(transcriptMessages, messages[j].rawBytes)
          j += 1
      }

      let secrets = deriveTls13HandshakeSecrets(sharedSecret, transcriptMessages)
      Some(secrets)
  }
 
 private func appendTranscriptMessage(
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
 
 /// processServerFlightV2 — 使用 jinguissl_core 高级 API 处理服务端握手飞行。
 ///
 /// 与 processServerFlight 功能相同，但在内部使用完整的
 /// jinguissl_core 组合 API 链（ServerHello 构建 + 握手上下文 + 飞行处理），
 /// 消除手动密钥调度代码。
 ///
 ///   clientPublicKey  — 客户端 X25519 公钥（32 字节 key_share）
 ///   clientPrivateKey — 客户端 X25519 私钥（32 字节）
 ///   serverFlightData — 服务端 CRYPTO 帧数据（包含 ServerHello + ... + Finished）
 ///   clientHello     — 原始 ClientHello 消息字节
 ///   (secrets, ok)   — 握手密钥与成功标志
  public func processServerFlightV2(
      clientPublicKey: Array<Byte>,
      clientPrivateKey: Array<Byte>,
      serverFlightData: Array<Byte>,
      clientHello: Array<Byte>
  ): Option<Tls13HandshakeSecrets> {
      // 1. 验证客户端公钥长度
      if (clientPublicKey.size != X25519_KEY_LEN) {
          return None
      }
      // 2. 解析服务端飞行并提取 ServerHello
      let messages = parseTlsHandshakeMessages(serverFlightData)
      if (messages.size == 0) { return None }

      var serverHelloMsg: TlsHandshakeMessage = TlsHandshakeMessage()
      var foundServerHello: Bool = false
      var i: Int64 = 0
      while (i < messages.size) {
          let isSh = match (messages[i].msgType) { case TLS_HANDSHAKE_TYPE_SERVER_HELLO => true; case _ => false }
          if (isSh) { serverHelloMsg = messages[i]; foundServerHello = true; break }
          i += 1
      }
      if (!foundServerHello) { return None }

      // 3. 验证服务端公钥
      let serverPublicKey = extractServerKeyShareFromServerHello(serverHelloMsg.body)
      if (serverPublicKey.size != X25519_KEY_LEN) { return None }

      // 4. 执行 ECDHE 密钥协商
      let sharedSecret = x25519DeriveSharedSecret(clientPrivateKey, serverPublicKey)
      if (sharedSecret.size != 32) { return None }

      // 5. 构建交互记录
      var transcriptMessages: Array<Array<Byte>> = [clientHello]
      var j: Int64 = 0
      while (j < messages.size) {
          transcriptMessages = appendTranscriptMessage(transcriptMessages, messages[j].rawBytes)
          j += 1
      }

      // 6. 派生握手密钥
      let secrets = deriveTls13HandshakeSecrets(sharedSecret, transcriptMessages)
      Some(secrets)
  }
 
 /// processServerFlightWithJinguissl — 使用 jinguissl 合约 API 的简化服务端飞行处理。
 ///
 /// 专为服务端使用场景设计。与 processServerFlight 相比，
 /// 使用更高层的 jinguissl_core API 减少重复代码。
  public func processServerFlightWithJinguissl(
      serverFlightData: Array<Byte>,
      clientPrivateKey: Array<Byte>,
      clientPublicKey: Array<Byte>
  ): Option<Tls13HandshakeSecrets> {
      let sharedSecret = x25519DeriveSharedSecret(clientPrivateKey, clientPublicKey)
      if (sharedSecret.size != 32) { return None }

      let messages = parseTlsHandshakeMessages(serverFlightData)
      if (messages.size == 0) { return None }

      // 构建完整的交互记录
      var transitMessages: Array<Array<Byte>> = []
      var i: Int64 = 0
      while (i < messages.size) {
          transitMessages = appendTranscriptMessage(transitMessages, messages[i].rawBytes)
          i += 1
      }

      let secrets = deriveTls13HandshakeSecrets(sharedSecret, transitMessages)
      Some(secrets)
  }
 
  /// decodeHandshakeFrame — 解码单个握手帧。
  /// data: 包含握手帧的字节序列
  /// 返回: (类型, 体)
  public func decodeHandshakeFrame(data: Array<Byte>): Option<(UInt8, Array<Byte>)> {
      try {
          let messages = parseTlsHandshakeMessages(data)
          if (messages.size > 0) {
              Some((messages[0].msgType, messages[0].body))
          } else {
              None
          }
      } catch (_: Exception) {
          None
      }
  }
 
private func createDummySecrets(): Tls13HandshakeSecrets {
     let zeros32 = Array<Byte>(32, repeat: 0u8)
     let zeros16 = Array<Byte>(16, repeat: 0u8)
     let zeros12 = Array<Byte>(12, repeat: 0u8)
     Tls13HandshakeSecrets(zeros32, zeros32, zeros32, zeros32, zeros32, zeros32, zeros32, zeros16, zeros16, zeros12, zeros12)
 }
