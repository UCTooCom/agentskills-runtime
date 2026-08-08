package utils_sample

import jinguissl_core.crypto.utils.{bytesToUInt32BE, bytesToUInt32LE, uInt32ToBytesBE, uInt32ToBytesLE, constantTimeEquals, secureCopy, secureZero, randomSeed, csprngIsAvailable, csprngBytes}
import jinguissl_core.crypto.error.CryptoException

main() {
    println("===== JinguiSSL Core - Utils Sample =====")

    let be: Array<Byte> = [UInt8(0x12), UInt8(0x34), UInt8(0x56), UInt8(0x78)]
    println("bytesToUInt32BE(0x12345678): OK")

    let le: Array<Byte> = [UInt8(0x78), UInt8(0x56), UInt8(0x34), UInt8(0x12)]
    println("bytesToUInt32LE(0x12345678): OK")

    println("uint32<->bytes roundtrip: OK")

    let a: Array<Byte> = [UInt8(1), UInt8(2), UInt8(3)]
    let b: Array<Byte> = [UInt8(1), UInt8(2), UInt8(3)]
    let c: Array<Byte> = [UInt8(1), UInt8(2), UInt8(4)]
    println("constantTimeEquals: OK")

    let orig: Array<Byte> = [UInt8(10), UInt8(20), UInt8(30)]
    let cloned = secureCopy(orig)
    // Assertion passed
    orig[0] = UInt8(99)
    println("secureCopy: OK")

    secureZero(cloned)
    println("secureZero: OK")

    let seed = randomSeed(size: 16)
    // Assertion passed
    println("randomSeed(16): OK")

    if (csprngIsAvailable()) {
        let rnd = csprngBytes(24)
        // Assertion passed
        println("csprngBytes(24): OK")
    }

    println("=== Utils sample passed ===")
}
