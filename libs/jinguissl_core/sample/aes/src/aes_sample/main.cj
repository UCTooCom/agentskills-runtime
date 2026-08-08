package aes_sample

import jinguissl_core.crypto.aes.{aesEcbEncrypt, aesEcbDecrypt, aesCbcEncrypt, aesCbcDecrypt, aesGcmEncrypt, aesGcmDecrypt, aesNewGcmContext, aesGcmEncryptWithContext, aesGcmDecryptWithContext}
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - AES Sample =====")

    let key: Array<Byte> = [
        UInt8(0x00), UInt8(0x01), UInt8(0x02), UInt8(0x03),
        UInt8(0x04), UInt8(0x05), UInt8(0x06), UInt8(0x07),
        UInt8(0x08), UInt8(0x09), UInt8(0x0a), UInt8(0x0b),
        UInt8(0x0c), UInt8(0x0d), UInt8(0x0e), UInt8(0x0f)
    ]
    let pt: Array<Byte> = [
        UInt8(0x00), UInt8(0x11), UInt8(0x22), UInt8(0x33),
        UInt8(0x44), UInt8(0x55), UInt8(0x66), UInt8(0x77),
        UInt8(0x88), UInt8(0x99), UInt8(0xaa), UInt8(0xbb),
        UInt8(0xcc), UInt8(0xdd), UInt8(0xee), UInt8(0xff)
    ]

    // AES-ECB
    let ctEcb = aesEcbEncrypt(key, pt)
    let ptEcb = aesEcbDecrypt(key, ctEcb)
    println("ECB roundtrip: ${ptEcb == pt}")
    if (ptEcb != pt) { throw Exception("AES-ECB roundtrip failed") }

    // AES-CBC
    let iv: Array<Byte> = Array<Byte>(16, repeat: UInt8(0x00))
    let ctCbc = aesCbcEncrypt(key, iv, pt)
    let ptCbc = aesCbcDecrypt(key, iv, ctCbc)
    println("CBC roundtrip: ${ptCbc == pt}")
    if (ptCbc != pt) { throw Exception("AES-CBC roundtrip failed") }

    // AES-GCM (aad is named parameter, decrypt returns Array<Byte>)
    let gcmIv: Array<Byte> = Array<Byte>(12, repeat: UInt8(0x00))
    let aad = "hello".toArray()
    let (ctGcm, tagGcm) = aesGcmEncrypt(key, gcmIv, pt, aad: aad)
    let ptGcm = aesGcmDecrypt(key, gcmIv, ctGcm, tagGcm, aad: aad)
    println("GCM roundtrip: ${ptGcm == pt}")
    if (ptGcm != pt) { throw Exception("AES-GCM roundtrip failed") }

    // AES-GCM with context
    let ctx = aesNewGcmContext(key)
    let (ctCtx, tagCtx) = aesGcmEncryptWithContext(ctx, gcmIv, pt, aad: aad)
    let ptCtx = aesGcmDecryptWithContext(ctx, gcmIv, ctCtx, tagCtx, aad: aad)
    println("GCM+Context roundtrip: ${ptCtx == pt}")
    if (ptCtx != pt) { throw Exception("AES-GCM context roundtrip failed") }

    println("=== AES sample passed ===")
}
