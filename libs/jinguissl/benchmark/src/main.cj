package jinguissl_benchmark

import std.time.MonoTime
import jinguissl.contract.*

private let ONE_KIB: Int64 = 1024
private let REPEAT: Int64 = 100

main() {
    let overallStart = MonoTime.now()

    println("========================================================================")
    println("   JinguiSSL Contract Benchmark Suite")
    println("========================================================================")
    println()

    // 1. SHA-256 (1 KiB)
    let sha256Data = Array<Byte>(ONE_KIB, repeat: UInt8(0x61))
    bench("SHA-256 (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractSha256(sha256Data)
            i += 1
        }
    })

    // 2. SHA-256 (64 KiB)
    let sha256Data64 = Array<Byte>(64 * ONE_KIB, repeat: UInt8(0x62))
    bench("SHA-256 (64 KiB)", false, 64 * ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractSha256(sha256Data64)
            i += 1
        }
    })

    // 3. SHA-384 (1 KiB)
    let sha384Data = Array<Byte>(ONE_KIB, repeat: UInt8(0x63))
    bench("SHA-384 (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractSha384(sha384Data)
            i += 1
        }
    })

    // 4. SHA-512 (1 KiB)
    let sha512Data = Array<Byte>(ONE_KIB, repeat: UInt8(0x64))
    bench("SHA-512 (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractSha512(sha512Data)
            i += 1
        }
    })

    // 5. HMAC-SHA256 (1 KiB)
    let hmacKey = Array<Byte>(32, repeat: UInt8(0x2a))
    let hmacData = Array<Byte>(ONE_KIB, repeat: UInt8(0x65))
    bench("HMAC-SHA256 (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractHmac(HashAlgorithm.SHA256, hmacKey, hmacData)
            i += 1
        }
    })

    // 6. HKDF-SHA256 (32-byte output)
    let hkdfSalt = Array<Byte>(32, repeat: UInt8(0x66))
    let hkdfInput = Array<Byte>(ONE_KIB, repeat: UInt8(0x67))
    let hkdfInfo = "bench".toArray()
    bench("HKDF-SHA256 (32B out)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractHkdf(HashAlgorithm.SHA256, hkdfInput, hkdfInfo, 32, salt: hkdfSalt)
            i += 1
        }
    })

    // 7. ChaCha20-Poly1305 encrypt (1 KiB)
    let chachaKey = Array<Byte>(32, repeat: UInt8(0x68))
    let chachaNonce = Array<Byte>(12, repeat: UInt8(0x69))
    let chachaPlain = Array<Byte>(ONE_KIB, repeat: UInt8(0x6a))
    let chachaAad = Array<Byte>(16, repeat: UInt8(0x6b))
    bench("ChaCha20-Poly1305 Encrypt (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractChacha20Poly1305Encrypt(chachaKey, chachaNonce, chachaPlain, aad: chachaAad)
            i += 1
        }
    })

    // 8. ChaCha20-Poly1305 decrypt (1 KiB)
    let (chachaCt, chachaTag) = contractChacha20Poly1305Encrypt(chachaKey, chachaNonce, chachaPlain, aad: chachaAad)
    bench("ChaCha20-Poly1305 Decrypt (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractChacha20Poly1305Decrypt(chachaKey, chachaNonce, chachaCt, chachaTag, aad: chachaAad)
            i += 1
        }
    })

    // 9. X25519 key pair generation
    bench("X25519 Key Pair Gen", true, 32, 50, { =>
        var i: Int64 = 0
        while (i < 50) {
            let _ = contractX25519GenerateKeyPair()
            i += 1
        }
    })

    // 10. X25519 key agreement
    let aliceKeyPair = contractX25519GenerateKeyPair()
    let bobKeyPair = contractX25519GenerateKeyPair()
    bench("X25519 Key Agreement", true, 32, 50, { =>
        var i: Int64 = 0
        while (i < 50) {
            let _ = contractX25519DeriveKeyAgreement(aliceKeyPair.privateKey, bobKeyPair.publicKey)
            i += 1
        }
    })

    // 11. ChaCha20 block (64 bytes)
    let blockKey = Array<Byte>(32, repeat: UInt8(0x6c))
    let blockNonce = Array<Byte>(12, repeat: UInt8(0x6d))
    bench("ChaCha20 Block (64B)", false, 64, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractChacha20Block(blockKey, 0, blockNonce)
            i += 1
        }
    })

    // 12. SHA-384 (64 KiB) — compare throughput with SHA-256 on large data
    let sha384Data64 = Array<Byte>(64 * ONE_KIB, repeat: UInt8(0x63))
    bench("SHA-384 (64 KiB)", false, 64 * ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractSha384(sha384Data64)
            i += 1
        }
    })

    // 13. SHA-512 (64 KiB) — compare throughput with SHA-256 on large data
    let sha512Data64 = Array<Byte>(64 * ONE_KIB, repeat: UInt8(0x64))
    bench("SHA-512 (64 KiB)", false, 64 * ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractSha512(sha512Data64)
            i += 1
        }
    })

    // 14. Poly1305 MAC (1 KiB) — standalone message authentication
    let polyKey = Array<Byte>(32, repeat: UInt8(0x6e))
    let polyMsg = Array<Byte>(ONE_KIB, repeat: UInt8(0x6f))
    bench("Poly1305 MAC (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractPoly1305Mac(polyKey, polyMsg)
            i += 1
        }
    })

    // 15. HMAC-SHA384 (1 KiB) — verify HMAC with SHA-384 performs as expected
    let hmac384Key = Array<Byte>(32, repeat: UInt8(0x70))
    let hmac384Data = Array<Byte>(ONE_KIB, repeat: UInt8(0x71))
    bench("HMAC-SHA384 (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractHmac(HashAlgorithm.SHA384, hmac384Key, hmac384Data)
            i += 1
        }
    })

    // 16. HKDF-SHA256 (64-byte output) — compare with 32-byte output overhead
    let hkdfInfo2 = "bench-64".toArray()
    bench("HKDF-SHA256 (64B out)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractHkdf(HashAlgorithm.SHA256, hkdfInput, hkdfInfo2, 64, salt: hkdfSalt)
            i += 1
        }
    })

    // 17. HMAC-SHA512 (1 KiB) — complement HMAC-SHA256/SHA384 coverage
    let hmac512Key = Array<Byte>(32, repeat: UInt8(0x72))
    let hmac512Data = Array<Byte>(ONE_KIB, repeat: UInt8(0x73))
    bench("HMAC-SHA512 (1 KiB)", false, ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractHmac(HashAlgorithm.SHA512, hmac512Key, hmac512Data)
            i += 1
        }
    })

    // 18. SHA-256 (512 KiB) — large data throughput
    let sha256Data512 = Array<Byte>(512 * ONE_KIB, repeat: UInt8(0x74))
    bench("SHA-256 (512 KiB)", false, 512 * ONE_KIB, REPEAT, { =>
        var i: Int64 = 0
        while (i < REPEAT) {
            let _ = contractSha256(sha256Data512)
            i += 1
        }
    })

    let elapsedNs = (MonoTime.now() - overallStart).toNanoseconds()
    println()
    println("Benchmark suite completed in ${elapsedNs / 1000000000}s")
}

private func bench(name: String, isSmall: Bool, bytesPerOp: Int64, repeat: Int64, body: () -> Unit) {
    // Warmup
    body()

    let start = MonoTime.now()
    body()
    let elapsedNs = (MonoTime.now() - start).toNanoseconds()

    let totalBytes = bytesPerOp * repeat
    let totalBytesF = totalBytes * 1000
    let elapsedMs = elapsedNs / 1000000
    let elapsedMsF = if (elapsedMs == 0) { 1 } else { elapsedMs }

    if (isSmall) {
        let opsPerSec = (repeat * 1000) / elapsedMsF
        println("  ${name}:")
        println("    ${elapsedNs} ns / ${repeat} ops")
        println("    ~${opsPerSec} ops/s")
    } else {
        let miBs = (totalBytesF / elapsedMsF) * 1000 / (1024 * 1024)
        println("  ${name}:")
        println("    ${elapsedNs} ns / ${repeat} ops")
        println("    ~${miBs} MiB/s")
    }
    println()
}
