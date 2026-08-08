package jinguissl_core.tests

import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.error.CryptoException

@Test
public class CoreBignumTestSuite {

    // ========== Construction ==========

    @TestCase
    public func testZero(): Unit {
        let z = BigNum.zero()
        @Assert(z.isZero(), true)
        @Assert(z.isNegative(), false)
    }

    @TestCase
    public func testOne(): Unit {
        let o = BigNum.one()
        @Assert(o.isZero(), false)
    }

    @TestCase
    public func testFromHexPositive(): Unit {
        let bn = BigNum.fromHex("1a2b3c")
        @Assert(bn.isNegative(), false)
    }

    @TestCase
    public func testFromHexWith0xPrefix(): Unit {
        let bn = BigNum.fromHex("0x1a2b")
        @Assert(bn.toHex(), "1a2b")
    }

    @TestCase
    public func testFromHexUpperCase(): Unit {
        let bn = BigNum.fromHex("1A2B3C")
        @Assert(bn.toHex(), "1a2b3c")
    }

    @TestCase
    public func testFromHexNegative(): Unit {
        let bn = BigNum.fromHex("-1a")
        @Assert(bn.isNegative(), true)
        @Assert(bn.toHex(), "-1a")
    }

    @TestCase
    public func testFromHexEmptyThrows(): Unit {
        try {
            _ = BigNum.fromHex("")
            @Fail("empty hex should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testFromHexInvalidThrows(): Unit {
        try {
            _ = BigNum.fromHex("xyz")
            @Fail("invalid hex should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testFromBytesBE(): Unit {
        let bytes: Array<Byte> = [0x12, 0x34]
        let bn = BigNum.fromBytesBE(bytes)
        @Assert(bn.toHex(), "1234")
    }

    @TestCase
    public func testFromBytesBEEmpty(): Unit {
        let bn = BigNum.fromBytesBE([])
        @Assert(bn.isZero(), true)
    }

    // ========== Arithmetic ==========

    @TestCase
    public func testAdd(): Unit {
        let a = BigNum.fromHex("0a")
        let b = BigNum.fromHex("14")
        let c = a.add(b)
        @Assert(c.toHex(), "1e")
    }

    @TestCase
    public func testAddWithNegative(): Unit {
        let a = BigNum.fromHex("14")
        let b = BigNum.fromHex("-05")
        let c = a.add(b)
        @Assert(c.toHex(), "0f")
    }

    @TestCase
    public func testSub(): Unit {
        let a = BigNum.fromHex("14")
        let b = BigNum.fromHex("0a")
        let c = a.sub(b)
        @Assert(c.toHex(), "0a")
    }

    @TestCase
    public func testSubNegativeResult(): Unit {
        let a = BigNum.fromHex("0a")
        let b = BigNum.fromHex("14")
        let c = a.sub(b)
        @Assert(c.toHex(), "-0a")
    }

    @TestCase
    public func testMul(): Unit {
        let a = BigNum.fromHex("06")
        let b = BigNum.fromHex("07")
        let c = a.mul(b)
        @Assert(c.toHex(), "2a")
    }

    @TestCase
    public func testMulLarge(): Unit {
        let a = BigNum.fromHex("100")
        let b = BigNum.fromHex("100")
        let c = a.mul(b)
        @Assert(c.toHex(), "010000")
    }

    @TestCase
    public func testDivMod(): Unit {
        let a = BigNum.fromHex("1e")
        let b = BigNum.fromHex("05")
        let (q, r) = a.divMod(b)
        @Assert(q.toHex(), "06")
        @Assert(r.toHex(), "0")
    }

    @TestCase
    public func testDivModNonZeroRemainder(): Unit {
        let a = BigNum.fromHex("14")
        let b = BigNum.fromHex("06")
        let (q, r) = a.divMod(b)
        @Assert(q.toHex(), "03")
        @Assert(r.toHex(), "02")
    }

    @TestCase
    public func testDivModByZero(): Unit {
        try {
            let a = BigNum.one()
            let z = BigNum.zero()
            _ = a.divMod(z)
            @Fail("divide by zero should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "DIVIDE_BY_ZERO")
        }
    }

    @TestCase
    public func testMod(): Unit {
        let a = BigNum.fromHex("14")
        let m = BigNum.fromHex("06")
        let r = a.mod(m)
        @Assert(r.toHex(), "02")
    }

    @TestCase
    public func testModByZero(): Unit {
        try {
            let a = BigNum.one()
            let z = BigNum.zero()
            _ = a.mod(z)
            @Fail("mod by zero should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "DIVIDE_BY_ZERO")
        }
    }

    // ========== Exponentiation ==========

    @TestCase
    public func testExp(): Unit {
        let a = BigNum.fromHex("03")
        let e = BigNum.fromHex("04")
        let r = a.exp(e)
        @Assert(r.toHex(), "51")
    }

    @TestCase
    public func testExpByZero(): Unit {
        let a = BigNum.fromHex("05")
        let e = BigNum.zero()
        let r = a.exp(e)
        @Assert(r.toHex(), "01")
    }

    @TestCase
    public func testExpNegativeExponent(): Unit {
        try {
            let a = BigNum.fromHex("02")
            let e = BigNum.fromHex("-01")
            _ = a.exp(e)
            @Fail("negative exponent should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testModExp(): Unit {
        let a = BigNum.fromHex("03")
        let e = BigNum.fromHex("04")
        let m = BigNum.fromHex("07")
        let r = a.modExp(e, m)
        // 3^4 = 81, 81 mod 7 = 4
        @Assert(r.toHex(), "04")
    }

    @TestCase
    public func testModExpModZero(): Unit {
        try {
            let a = BigNum.one()
            let e = BigNum.one()
            let z = BigNum.zero()
            _ = a.modExp(e, z)
            @Fail("modExp with zero modulus should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "DIVIDE_BY_ZERO")
        }
    }

    // ========== ModInverse ==========

    @TestCase
    public func testModInverse(): Unit {
        let a = BigNum.fromHex("03")
        let m = BigNum.fromHex("0a")
        let inv = a.modInverse(m)
        // 3 * 7 = 21 ≡ 1 mod 10
        @Assert(inv.toHex(), "07")
    }

    @TestCase
    public func testModInverseNonExistent(): Unit {
        try {
            let a = BigNum.fromHex("02")
            let m = BigNum.fromHex("04")
            _ = a.modInverse(m)
            @Fail("should throw when inverse does not exist")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "NO_MOD_INVERSE")
        }
    }

    // ========== Shifts ==========

    @TestCase
    public func testLshift(): Unit {
        let a = BigNum.one()
        let r = a.lshift(3)
        @Assert(r.toHex(), "08")
    }

    @TestCase
    public func testLshiftZero(): Unit {
        let a = BigNum.one()
        let r = a.lshift(0)
        @Assert(r.toHex(), "01")
    }

    @TestCase
    public func testLshiftNegative(): Unit {
        try {
            let a = BigNum.one()
            _ = a.lshift(-1)
            @Fail("negative shift should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testRshift(): Unit {
        let a = BigNum.fromHex("10")
        let r = a.rshift(2)
        @Assert(r.toHex(), "04")
    }

    @TestCase
    public func testRshiftZero(): Unit {
        let a = BigNum.fromHex("10")
        let r = a.rshift(0)
        @Assert(r.toHex(), "10")
    }

    @TestCase
    public func testRshiftNegative(): Unit {
        try {
            let a = BigNum.one()
            _ = a.rshift(-1)
            @Fail("negative shift should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    // ========== Comparison ==========

    @TestCase
    public func testCmpEqual(): Unit {
        let a = BigNum.fromHex("0a")
        let b = BigNum.fromHex("0a")
        @Assert(a.cmp(b), 0)
        @Assert(a == b, true)
    }

    @TestCase
    public func testCmpLess(): Unit {
        let a = BigNum.fromHex("05")
        let b = BigNum.fromHex("0a")
        @Assert(a.cmp(b), -1)
        @Assert(a != b, true)
    }

    @TestCase
    public func testCmpGreater(): Unit {
        let a = BigNum.fromHex("0a")
        let b = BigNum.fromHex("05")
        @Assert(a.cmp(b), 1)
    }

    @TestCase
    public func testCmpNegative(): Unit {
        let a = BigNum.fromHex("-05")
        let b = BigNum.fromHex("01")
        @Assert(a.cmp(b), -1)
    }

    // ========== Conversion ==========

    @TestCase
    public func testToBytesBE(): Unit {
        let bn = BigNum.fromHex("1234")
        let bytes = bn.toBytesBE()
        let expected: Array<Byte> = [0x12, 0x34]
        @Assert(bytes, expected)
    }

    @TestCase
    public func testToBytesBEPadded(): Unit {
        let bn = BigNum.fromHex("34")
        let bytes = bn.toBytesBE(paddedLen: 4)
        @Assert(bytes.size, 4)
        @Assert(bytes[0], 0)
        @Assert(bytes[1], 0)
        @Assert(bytes[2], 0)
        @Assert(bytes[3], 0x34)
    }

    @TestCase
    public func testToBytesBEPaddedTooSmall(): Unit {
        try {
            let bn = BigNum.fromHex("1234")
            _ = bn.toBytesBE(paddedLen: 1)
            @Fail("should throw when paddedLen too small")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    @TestCase
    public func testToHex(): Unit {
        let bn = BigNum.fromHex("deadbeef")
        @Assert(bn.toHex(), "deadbeef")
    }

    @TestCase
    public func testToHexZero(): Unit {
        let bn = BigNum.zero()
        @Assert(bn.toHex(), "0")
    }

    // ========== GCD ==========

    @TestCase
    public func testGcd(): Unit {
        let a = BigNum.fromHex("0c")
        let b = BigNum.fromHex("08")
        let g = BigNum.gcd(a, b)
        @Assert(g.toHex(), "04")
    }

    @TestCase
    public func testGcdCoprime(): Unit {
        let a = BigNum.fromHex("09")
        let b = BigNum.fromHex("10")
        let g = BigNum.gcd(a, b)
        @Assert(g.toHex(), "01")
    }

    @TestCase
    public func testGcdWithZero(): Unit {
        let a = BigNum.zero()
        let b = BigNum.fromHex("05")
        let g = BigNum.gcd(a, b)
        @Assert(g.toHex(), "05")
    }

    // ========== lims/sign properties ==========

    @TestCase
    public func testSignProperties(): Unit {
        @Assert(BigNum.fromHex("05").sign, 1)
        @Assert(BigNum.zero().sign, 0)
        @Assert(BigNum.fromHex("-05").sign, -1)
    }

    @TestCase
    public func testLimbsNotEmptyOnPositive(): Unit {
        let bn = BigNum.fromHex("1234")
        @Assert(bn.limbs.size > 0, true)
    }

    @TestCase
    public func testLimbsEmptyOnZero(): Unit {
        let bn = BigNum.zero()
        @Assert(bn.limbs.size, 0)
    }
}
