 package jinguissl_core.crypto.quic

 import jinguissl_core.crypto.aes.{AesGcmContext, aesGcmEncryptWithContext, aesNewGcmContext}
 import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
 import jinguissl_core.crypto.utils.secureCopyInto

 // ── Retry integrity keys & nonces ───────────────────────────────
 //
 // RFC 9001 §5.8 defines fixed key & nonce for QUIC v1.
 // RFC 9369  §5.8 defines distinct values for QUIC v2.

 private let QUIC_RETRY_KEY_V1: Array<Byte> = [
     UInt8(0xbe), UInt8(0x0c), UInt8(0x69), UInt8(0x0b),
     UInt8(0x9f), UInt8(0x66), UInt8(0x57), UInt8(0x5a),
     UInt8(0x1d), UInt8(0x76), UInt8(0x6b), UInt8(0x54),
     UInt8(0xe3), UInt8(0x68), UInt8(0xc8), UInt8(0x4e)
 ]

 private let QUIC_RETRY_KEY_V2: Array<Byte> = [
     UInt8(0x8f), UInt8(0xb4), UInt8(0xb0), UInt8(0x1b),
     UInt8(0x56), UInt8(0xac), UInt8(0x48), UInt8(0xe2),
     UInt8(0x60), UInt8(0xfb), UInt8(0xcb), UInt8(0xce),
     UInt8(0xad), UInt8(0x7c), UInt8(0xcc), UInt8(0x92)
 ]

 private let QUIC_RETRY_NONCE_V1: Array<Byte> = [
     UInt8(0x46), UInt8(0x15), UInt8(0x99), UInt8(0xd3),
     UInt8(0x5d), UInt8(0x63), UInt8(0x2b), UInt8(0xf2),
     UInt8(0x23), UInt8(0x98), UInt8(0x25), UInt8(0xbb)
 ]

 private let QUIC_RETRY_NONCE_V2: Array<Byte> = [
     UInt8(0xd8), UInt8(0x69), UInt8(0x69), UInt8(0xbc),
     UInt8(0x2d), UInt8(0x7c), UInt8(0x6d), UInt8(0x99),
     UInt8(0x90), UInt8(0xef), UInt8(0xb0), UInt8(0x4a)
 ]

 // ── Retry Integrity Tag ─────────────────────────────────────────
 //
 // RFC 9001 §5.8 / RFC 9369 §5.8:
 //   aad = concat(OriginalDestinationConnectionID_length (1 byte),
 //                OriginalDestinationConnectionID,
 //                RetryPacketData)
 //   tag = AES-128-GCM(RetryIntegrityKey, RetryIntegrityNonce, nil, aad)[0..16]
 //
 // The 16-byte tag occupies the last 16 bytes of the Retry packet.

 /// Compute the Retry Integrity Tag.
 /// - retryPacket:    the Retry packet bytes WITHOUT the trailing 16-byte tag
 /// - origDestConnId: the Original Destination Connection ID from the client's Initial
 /// - isV2:           true for QUIC v2, false for QUIC v1
 public func quicRetryIntegrityTag(
     retryPacket: Array<Byte>,
     origDestConnId: Array<Byte>,
     isV2: Bool
 ): Array<Byte> {
     let key   = if (isV2) { QUIC_RETRY_KEY_V2   } else { QUIC_RETRY_KEY_V1   }
     let nonce = if (isV2) { QUIC_RETRY_NONCE_V2 } else { QUIC_RETRY_NONCE_V1 }

     let aadLen = 1 + origDestConnId.size + retryPacket.size
     let aad = Array<Byte>(aadLen, repeat: 0)
     aad[0] = UInt8(origDestConnId.size)
     secureCopyInto(origDestConnId, aad, dstOffset: 1)
     secureCopyInto(retryPacket, aad, dstOffset: 1 + origDestConnId.size)

     let ctx = aesNewGcmContext(key)
     let (_, tag) = aesGcmEncryptWithContext(ctx, nonce, [], aad: aad)
     tag
 }

 /// Verify the Retry Integrity Tag.
 /// - retryPacketWithTag: the full Retry packet INCLUDING the 16-byte tag
 /// - origDestConnId:     the Original Destination Connection ID
 /// - isV2:               true for QUIC v2
 public func quicVerifyRetryIntegrity(
     retryPacketWithTag: Array<Byte>,
     origDestConnId: Array<Byte>,
     isV2: Bool
 ): Bool {
     if (retryPacketWithTag.size < 16) {
         return false
     }
     let tagStart = retryPacketWithTag.size - 16
     let retryPacket = retryPacketWithTag[..tagStart]
     let receivedTag = retryPacketWithTag[tagStart..]
     let computedTag = quicRetryIntegrityTag(retryPacket, origDestConnId, isV2)

     // Constant-time comparison
     var diff: UInt8 = 0
     var i: Int64 = 0
     while (i < 16) {
         diff = diff | (UInt8(computedTag[i]) ^ UInt8(receivedTag[i]))
         i += 1
     }
     diff == UInt8(0)
 }
