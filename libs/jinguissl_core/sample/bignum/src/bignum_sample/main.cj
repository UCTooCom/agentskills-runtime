package bignum_sample

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.error.CryptoException

main() {
    println("===== JinguiSSL Core - BigNum Sample =====")

    // Construction
    let a = BigNum.fromHex("1a2b3c")
    let b = BigNum.fromHex("0a")
    println("a = ${a.toHex()}")
    println("b = ${b.toHex()}")

    // Basic arithmetic
    let sum = a.add(b)
    println("a + b = ${sum.toHex()}")

    let diff = a.sub(b)
    println("a - b = ${diff.toHex()}")

    let product = a.mul(b)
    println("a * b = ${product.toHex()}")

    let (q, r) = a.divMod(b)
    println("a / b = ${q.toHex()}, remainder = ${r.toHex()}")
    if (q.isZero()) { throw Exception("Division failed") }

    // Modulo arithmetic
    let m = BigNum.fromHex("10")
    let modResult = a.mod(m)
    println("a mod 0x10 = ${modResult.toHex()}")

    // Exponentiation
    let base = BigNum.fromHex("03")
    let exp = BigNum.fromHex("04")
    let power = base.exp(exp)
    println("3^4 = ${power.toHex()}")
    if (power.toHex() != "51") { throw Exception("Exponentiation failed") }

    // Modular exponentiation
    let modExpResult = base.modExp(BigNum.fromHex("04"), BigNum.fromHex("07"))
    println("3^4 mod 7 = ${modExpResult.toHex()}")

    // Mod inverse
    let inv = a.modInverse(BigNum.fromHex("1b"))
    println("a^{-1} mod 0x1b = ${inv.toHex()}")

    // Shift operations
    let shifted = BigNum.one().lshift(8)
    println("1 << 8 = ${shifted.toHex()}")
    if (shifted.toHex() != "100") { throw Exception("Lshift failed") }

    let unshifted = shifted.rshift(4)
    println("0x100 >> 4 = ${unshifted.toHex()}")

    // GCD
    let gcd = BigNum.gcd(BigNum.fromHex("0c"), BigNum.fromHex("08"))
    println("gcd(0xc, 0x8) = ${gcd.toHex()}")

    // Byte conversion
    let bytes = a.toBytesBE()
    println("a as bytes: [${bytes[0]}, ${bytes[1]}, ${bytes[2]}]")

    let fromBytes = BigNum.fromBytesBE(bytes)
    println("roundtrip: ${a == fromBytes}")

    // Comparison
    let lhs = BigNum.fromHex("10")
    let rhs = BigNum.fromHex("20")
    println("cmp(0x10, 0x20) = ${lhs.cmp(rhs)}")  // -1
    println("cmp(0x20, 0x10) = ${rhs.cmp(lhs)}")  // 1
    println("cmp(0x10, 0x10) = ${lhs.cmp(BigNum.fromHex("10"))}")  // 0
    if (lhs.cmp(rhs) >= 0) { throw Exception("Comparison failed") }

    // Zero and one
    let z = BigNum.zero()
    let o = BigNum.one()
    println("zero = ${z.toHex()}, isZero = ${z.isZero()}")
    println("one = ${o.toHex()}")
    if (!z.isZero()) { throw Exception("Zero check failed") }

    // Properties
    let neg = BigNum.fromHex("-0a")
    println("negative = ${neg.toHex()}, isNegative = ${neg.isNegative()}")

    let val = BigNum.fromHex("12345678")
    println("limbs count = ${val.limbs.size}")
    println("sign = ${val.sign}")

    println("=== BigNum sample passed ===")
}
