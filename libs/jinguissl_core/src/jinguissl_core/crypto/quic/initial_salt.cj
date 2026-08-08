 package jinguissl_core.crypto.quic

 import jinguissl_core.crypto.digest.{HashAlgorithm, hkdfExtract, hkdfExpand}
 import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
 import jinguissl_core.crypto.utils.secureCopyInto

 // ── Initial salts (RFC 9001 §5.2 / RFC 9369 §5.2) ───────────────

 public let QUIC_SALT_V1: Array<Byte> = [
     UInt8(0x38), UInt8(0x76), UInt8(0x2c), UInt8(0xf7),
     UInt8(0xf5), UInt8(0x59), UInt8(0x34), UInt8(0xb3),
     UInt8(0x4d), UInt8(0x17), UInt8(0x9a), UInt8(0xe6),
     UInt8(0xa4), UInt8(0xc8), UInt8(0x0c), UInt8(0xad),
     UInt8(0xcc), UInt8(0xbb), UInt8(0x7f), UInt8(0x0a)
 ]

 public let QUIC_SALT_V2: Array<Byte> = [
     UInt8(0x0d), UInt8(0xed), UInt8(0xe3), UInt8(0xde),
     UInt8(0xf7), UInt8(0x00), UInt8(0xa6), UInt8(0xdb),
     UInt8(0x81), UInt8(0x93), UInt8(0x81), UInt8(0xbe),
     UInt8(0x6e), UInt8(0x26), UInt8(0x9d), UInt8(0xcb),
     UInt8(0xf9), UInt8(0xbd), UInt8(0x2e), UInt8(0xd9)
 ]

 // ── TLS 1.3 HkdfLabel construction ──────────────────────────────
 //
 // Wire format (RFC 8446 §7.1):
 //   struct { uint16 length; uint8 label_length; opaque label[label_length]; uint8 context_length; opaque context[context_length]; } HkdfLabel
 // where label = "tls13 " + actual_label
 private func buildTls13LabelInfo(label: String, context: Array<Byte>, outputLen: Int64): Array<Byte> {
     let labelBytes = ("tls13 " + label).toArray()
     let info = Array<Byte>(2 + 1 + labelBytes.size + 1 + context.size, repeat: 0)
     info[0] = UInt8((outputLen >> 8) & 0xff)
     info[1] = UInt8(outputLen & 0xff)
     info[2] = UInt8(labelBytes.size)
     secureCopyInto(labelBytes, info, dstOffset: 3)
     let ctxOffset = 3 + labelBytes.size
     info[ctxOffset] = UInt8(context.size)
     if (context.size > 0) {
         secureCopyInto(context, info, dstOffset: ctxOffset + 1)
     }
     info
 }

 // ── Initial secret derivation ────────────────────────────────────
 //
 //  initial_secret = HKDF-Extract(salt, conn_id)                                     (RFC 9001 §5.2)
 //  client_secret  = HKDF-Expand-Label(initial_secret, "client in",  SHA256_len)
 //  server_secret  = HKDF-Expand-Label(initial_secret, "server in",  SHA256_len)
 public func quicInitialSecrets(connId: Array<Byte>, isV2: Bool): (Array<Byte>, Array<Byte>) {
     let salt = if (isV2) { QUIC_SALT_V2 } else { QUIC_SALT_V1 }
     let initialSecret = hkdfExtract(HashAlgorithm.SHA256, salt, connId)
     let clientInfo = buildTls13LabelInfo("client in", [], 32)
     let serverInfo = buildTls13LabelInfo("server in", [], 32)
     let clientSecret = hkdfExpand(HashAlgorithm.SHA256, initialSecret, clientInfo, 32)
     let serverSecret = hkdfExpand(HashAlgorithm.SHA256, initialSecret, serverInfo, 32)
     (clientSecret, serverSecret)
 }

 // Derive initial key and IV from an initial traffic secret.
 //   key = HKDF-Expand-Label(secret, "quic key"  / "quicv2 key",  16)
 //   iv  = HKDF-Expand-Label(secret, "quic iv"   / "quicv2 iv",   12)
 public func quicInitialKeyIv(secret: Array<Byte>, isV2: Bool): (Array<Byte>, Array<Byte>) {
     let keyLabel = if (isV2) { "quicv2 key" } else { "quic key" }
     let ivLabel  = if (isV2) { "quicv2 iv"  } else { "quic iv"  }
     let keyInfo = buildTls13LabelInfo(keyLabel, [], 16)
     let ivInfo  = buildTls13LabelInfo(ivLabel,  [], 12)
     let key = hkdfExpand(HashAlgorithm.SHA256, secret, keyInfo, 16)
     let iv  = hkdfExpand(HashAlgorithm.SHA256, secret, ivInfo, 12)
     (key, iv)
 }

 // Derive initial header protection key from an initial traffic secret.
 //   hp = HKDF-Expand-Label(secret, "quic hp" / "quicv2 hp", 16)
 public func quicInitialHpKey(secret: Array<Byte>, isV2: Bool): Array<Byte> {
     let hpLabel = if (isV2) { "quicv2 hp" } else { "quic hp" }
     let hpInfo = buildTls13LabelInfo(hpLabel, [], 16)
     hkdfExpand(HashAlgorithm.SHA256, secret, hpInfo, 16)
 }

 // One-shot: derive all client-side initial key material from connection ID.
 public func quicInitialKeyDerive(connId: Array<Byte>, isV2: Bool):
     (key: Array<Byte>, iv: Array<Byte>, hpKey: Array<Byte>) {
     let (clientSecret, _) = quicInitialSecrets(connId, isV2)
     let (key, iv) = quicInitialKeyIv(clientSecret, isV2)
     let hpKey = quicInitialHpKey(clientSecret, isV2)
     (key, iv, hpKey)
 }
