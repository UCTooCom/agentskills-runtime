package sm4_sample

import jinguissl_core.crypto.sm4.{sm4Encrypt, sm4Decrypt}
import jinguissl_core.crypto.digest.bytesToHexLower
import std.collection.ArrayList

main() {
    println("===== JinguiSSL Core - SM4 Sample =====")

    let key: Array<Byte> = [
        UInt8(0x01), UInt8(0x23), UInt8(0x45), UInt8(0x67),
        UInt8(0x89), UInt8(0xab), UInt8(0xcd), UInt8(0xef),
        UInt8(0xfe), UInt8(0xdc), UInt8(0xba), UInt8(0x98),
        UInt8(0x76), UInt8(0x54), UInt8(0x32), UInt8(0x10)
    ]

    let pt: Array<Byte> = [UInt8(0x00), UInt8(0x11), UInt8(0x22), UInt8(0x33),
        UInt8(0x44), UInt8(0x55), UInt8(0x66), UInt8(0x77),
        UInt8(0x88), UInt8(0x99), UInt8(0xaa), UInt8(0xbb),
        UInt8(0xcc), UInt8(0xdd), UInt8(0xee), UInt8(0xff)]

    // SM4-ECB encrypt
    let ct = sm4Encrypt(key, pt)
    println("SM4 ciphertext: ${bytesToHexLower(ct)}")
    if (ct.size != 16) { throw Exception("SM4 output length wrong") }

    // SM4-ECB decrypt
    let dec = sm4Decrypt(key, ct)
    println("Decrypt match: ${dec == pt}")
    if (dec != pt) { throw Exception("SM4 decrypt mismatch") }

    // Multi-block using ArrayList
    let multiList = ArrayList<Byte>()
    var i = 0
    while (i < pt.size) {
        multiList.add(pt[i])
        i += 1
    }
    i = 0
    while (i < pt.size) {
        multiList.add(pt[i])
        i += 1
    }
    let multiBlock = multiList.toArray()

    let ct2 = sm4Encrypt(key, multiBlock)
    let pt2 = sm4Decrypt(key, ct2)
    println("Multi-block match: ${pt2 == multiBlock}")
    if (pt2.size != 32) { throw Exception("SM4 multi-block length wrong") }
    if (pt2 != multiBlock) { throw Exception("SM4 multi-block mismatch") }

    println("=== SM4 sample passed ===")
}
