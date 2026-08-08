package jinguissl_core.tests

import jinguissl_core.crypto.utils.{bytesToUInt32BE, bytesToUInt32LE, uInt32ToBytesBE, uInt32ToBytesLE, constantTimeEquals, secureCopy, secureCopyInto, secureZero, csprngIsAvailable, csprngBytes, randomSeed}
import jinguissl_core.crypto.error.CryptoException

@Test
public class CoreUtilsTestSuite {

    // ========== bytesToUInt32BE / LE ==========

    @TestCase
    public func testBytesToUInt32BE(): Unit {
        let bytes: Array<Byte> = [0x12, 0x34, 0x56, 0x78]
        @Assert(bytesToUInt32BE(bytes), UInt32(0x12345678))
    }

    @TestCase
    public func testBytesToUInt32BEWithOffset(): Unit {
        let bytes: Array<Byte> = [0x00, 0x00, 0x12, 0x34, 0x56, 0x78]
        @Assert(bytesToUInt32BE(bytes, offset: 2), UInt32(0x12345678))
    }

    @TestCase
    public func testBytesToUInt32BEShort(): Unit {
        try {
            _ = bytesToUInt32BE([1, 2, 3])
            @Fail("short input should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    @TestCase
    public func testBytesToUInt32LE(): Unit {
        let bytes: Array<Byte> = [0x78, 0x56, 0x34, 0x12]
        @Assert(bytesToUInt32LE(bytes), UInt32(0x12345678))
    }

    @TestCase
    public func testBytesToUInt32LEWithOffset(): Unit {
        let bytes: Array<Byte> = [0x00, 0x00, 0x78, 0x56, 0x34, 0x12]
        @Assert(bytesToUInt32LE(bytes, offset: 2), UInt32(0x12345678))
    }

    @TestCase
    public func testBytesToUInt32LEShort(): Unit {
        try {
            _ = bytesToUInt32LE([1, 2, 3])
            @Fail("short input should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    // ========== uInt32ToBytesBE / LE ==========

    @TestCase
    public func testUInt32ToBytesBE(): Unit {
        let expected: Array<Byte> = [0x12, 0x34, 0x56, 0x78]
        @Assert(uInt32ToBytesBE(UInt32(0x12345678)), expected)
    }

    @TestCase
    public func testUInt32ToBytesBEZero(): Unit {
        let expected: Array<Byte> = [0x00, 0x00, 0x00, 0x00]
        @Assert(uInt32ToBytesBE(0), expected)
    }

    @TestCase
    public func testUInt32ToBytesLE(): Unit {
        let expected: Array<Byte> = [0x78, 0x56, 0x34, 0x12]
        @Assert(uInt32ToBytesLE(UInt32(0x12345678)), expected)
    }

    @TestCase
    public func testUInt32RoundTrip(): Unit {
        let values: Array<UInt32> = [0, 1, 0xFF, 0x12345678, 0xFFFFFFFF]
        for (v in values) {
            let be = uInt32ToBytesBE(v)
            let le = uInt32ToBytesLE(v)
            @Assert(bytesToUInt32BE(be), v)
            @Assert(bytesToUInt32LE(le), v)
        }
    }

    // ========== constantTimeEquals ==========

    @TestCase
    public func testConstantTimeEqualsEqual(): Unit {
        let a: Array<Byte> = [1, 2, 3, 4]
        let b: Array<Byte> = [1, 2, 3, 4]
        @Assert(constantTimeEquals(a, b), true)
    }

    @TestCase
    public func testConstantTimeEqualsNotEqual(): Unit {
        let a: Array<Byte> = [1, 2, 3, 4]
        let b: Array<Byte> = [1, 2, 3, 5]
        @Assert(constantTimeEquals(a, b), false)
    }

    @TestCase
    public func testConstantTimeEqualsDifferentLength(): Unit {
        let a: Array<Byte> = [1, 2, 3]
        let b: Array<Byte> = [1, 2, 3, 4]
        @Assert(constantTimeEquals(a, b), false)
    }

    @TestCase
    public func testConstantTimeEqualsBothEmpty(): Unit {
        @Assert(constantTimeEquals([], []), true)
    }

    @TestCase
    public func testConstantTimeEqualsSingleByte(): Unit {
        @Assert(constantTimeEquals([0], [0]), true)
        @Assert(constantTimeEquals([0], [1]), false)
    }

    // ========== secureCopy / secureCopyInto ==========

    @TestCase
    public func testSecureCopy(): Unit {
        let src: Array<Byte> = [1, 2, 3]
        let dst = secureCopy(src)
        @Assert(dst == src, true)
        // mutations should not affect original
        dst[0] = 99
        @Assert(src[0], 1)
    }

    @TestCase
    public func testSecureCopyEmpty(): Unit {
        let dst = secureCopy([])
        @Assert(dst.size, 0)
    }

    @TestCase
    public func testSecureCopyInto(): Unit {
        let src: Array<Byte> = [1, 2, 3]
        let dst: Array<Byte> = [0, 0, 0, 0, 0]
        secureCopyInto(src, dst)
        let expected: Array<Byte> = [1, 2, 3, 0, 0]
        @Assert(dst, expected)
    }

    @TestCase
    public func testSecureCopyIntoWithOffset(): Unit {
        let src: Array<Byte> = [1, 2]
        let dst: Array<Byte> = [0, 0, 0, 0]
        secureCopyInto(src, dst, dstOffset: 2)
        let expected: Array<Byte> = [0, 0, 1, 2]
        @Assert(dst, expected)
    }

    @TestCase
    public func testSecureCopyIntoDestinationTooSmall(): Unit {
        try {
            secureCopyInto([1, 2, 3], [0, 0])
            @Fail("should throw when destination too small")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    @TestCase
    public func testSecureCopyIntoNegativeOffset(): Unit {
        try {
            secureCopyInto([1], [0, 0], dstOffset: -1)
            @Fail("should throw on negative offset")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    // ========== secureZero ==========

    @TestCase
    public func testSecureZero(): Unit {
        let arr: Array<Byte> = [1, 2, 3, 4]
        secureZero(arr)
        for (b in arr) {
            @Assert(b, 0)
        }
    }

    @TestCase
    public func testSecureZeroEmpty(): Unit {
        let arr: Array<Byte> = []
        secureZero(arr)  // should not throw
    }

    // ========== CSPRNG ==========

    @TestCase
    public func testCsprngBytes(): Unit {
        if (csprngIsAvailable()) {
            let out = csprngBytes(16)
            @Assert(out.size, 16)
        }
    }

    @TestCase
    public func testCsprngBytesDefaultSize(): Unit {
        if (csprngIsAvailable()) {
            let out = csprngBytes()
            @Assert(out.size, 32)
        }
    }

    @TestCase
    public func testCsprngBytesZeroRejected(): Unit {
        try {
            _ = csprngBytes(0)
            @Fail("csprngBytes(0) should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testCsprngBytesNegativeRejected(): Unit {
        try {
            _ = csprngBytes(-1)
            @Fail("csprngBytes(-1) should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testRandomSeed(): Unit {
        if (csprngIsAvailable()) {
            let seed = randomSeed(size: 16)
            @Assert(seed.size, 16)
        }
    }

    @TestCase
    public func testRandomSeedDefaultSize(): Unit {
        if (csprngIsAvailable()) {
            let seed = randomSeed()
            @Assert(seed.size, 32)
        }
    }

    @TestCase
    public func testCsprngIsAvailableReturnsBool(): Unit {
        let available = csprngIsAvailable()
        @Assert(available == true || available == false, true)
    }
}
