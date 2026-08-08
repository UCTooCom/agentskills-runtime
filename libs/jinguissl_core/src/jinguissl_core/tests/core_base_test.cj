package jinguissl_core.tests

import jinguissl_core.crypto.base as corebase
import jinguissl_core.crypto.error.CryptoException

@Test
public class CoreBaseTestSuite {

    // ========== Endian enum ==========

    @TestCase
    public func testEndianValues(): Unit {
        @Assert(corebase.Endian.Big.toString(), "BIG")
        @Assert(corebase.Endian.Little.toString(), "LITTLE")
        @Assert(corebase.Endian.Big != corebase.Endian.Little, true)
        @Assert(corebase.Endian.Big.ordinalValue(), 0)
        @Assert(corebase.Endian.Little.ordinalValue(), 1)
    }

    @TestCase
    public func testEndianEquality(): Unit {
        @Assert(corebase.Endian.Big == corebase.Endian.Big, true)
        @Assert(corebase.Endian.Little == corebase.Endian.Little, true)
        @Assert(corebase.Endian.Big == corebase.Endian.Little, false)
    }

    // ========== SecureBytes basic lifecycle ==========

    @TestCase
    public func testSecureBytesFromArray(): Unit {
        let input: Array<Byte> = [10, 20, 30]
        let sb = corebase.SecureBytes(input)
        @Assert(sb.size, 3)
        @Assert(sb.isDestroyed, false)
        @Assert(sb.bytes(), input)
    }

    @TestCase
    public func testSecureBytesIndependentCopy(): Unit {
        let input: Array<Byte> = [1, 2, 3]
        let sb = corebase.SecureBytes(input)
        input[0] = 99
        // sb should still have original values since it made a clone
        let retrieved = sb.bytes()
        @Assert(retrieved[0], UInt8(1))
    }

    @TestCase
    public func testSecureBytesWithSize(): Unit {
        let sb = corebase.SecureBytes.withSize(5)
        @Assert(sb.size, 5)
        let retrieved = sb.bytes()
        @Assert(retrieved.size, 5)
        // all zeros
        for (b in retrieved) {
            @Assert(b, 0)
        }
    }

    @TestCase
    public func testSecureBytesWithSizeZero(): Unit {
        let sb = corebase.SecureBytes.withSize(0)
        @Assert(sb.size, 0)
        @Assert(sb.bytes().size, 0)
    }

    @TestCase
    public func testSecureBytesWithSizeNegative(): Unit {
        try {
            _ = corebase.SecureBytes.withSize(-1)
            @Fail("should reject negative size")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testSecureBytesClear(): Unit {
        let sb = corebase.SecureBytes([1, 2, 3, 4])
        sb.clear()
        let retrieved = sb.bytes()
        for (b in retrieved) {
            @Assert(b, 0)
        }
    }

    @TestCase
    public func testSecureBytesDestroy(): Unit {
        let sb = corebase.SecureBytes([1, 2, 3])
        sb.destroy()
        @Assert(sb.isDestroyed, true)

        try {
            _ = sb.bytes()
            @Fail("should reject access after destroy")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testSecureBytesDoubleDestroy(): Unit {
        let sb = corebase.SecureBytes([1, 2, 3])
        sb.destroy()
        sb.destroy()  // should not throw
        @Assert(sb.isDestroyed, true)
    }

    @TestCase
    public func testSecureBytesSetAt(): Unit {
        let sb = corebase.SecureBytes([1, 2, 3])
        sb.setAt(1, 99)
        let retrieved = sb.bytes()
        @Assert(retrieved[0], 1)
        @Assert(retrieved[1], 99)
        @Assert(retrieved[2], 3)
    }

    @TestCase
    public func testSecureBytesSetAtOutOfBounds(): Unit {
        let sb = corebase.SecureBytes([1, 2, 3])
        try {
            sb.setAt(5, 99)
            @Fail("should reject out-of-bounds setAt")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    @TestCase
    public func testSecureBytesSetAtNegativeIndex(): Unit {
        let sb = corebase.SecureBytes([1, 2, 3])
        try {
            sb.setAt(-1, 99)
            @Fail("should reject negative index")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    // ========== ByteBuffer tests ==========

    @TestCase
    public func testByteBufferEmpty(): Unit {
        let buf = corebase.ByteBuffer()
        @Assert(buf.size, 0)
        @Assert(buf.toArray().size, 0)
    }

    @TestCase
    public func testByteBufferWithInitialBytes(): Unit {
        let buf = corebase.ByteBuffer([1, 2, 3])
        @Assert(buf.size, 3)
        let expected: Array<Byte> = [1, 2, 3]
        @Assert(buf.toArray(), expected)
    }

    @TestCase
    public func testByteBufferAppendSingle(): Unit {
        let buf = corebase.ByteBuffer()
        buf.append(UInt8(42))
        @Assert(buf.size, 1)
        @Assert(buf.toArray()[0], 42)
    }

    @TestCase
    public func testByteBufferAppendArray(): Unit {
        let buf = corebase.ByteBuffer()
        buf.append([1, 2, 3])
        @Assert(buf.size, 3)
        buf.append([4, 5])
        @Assert(buf.size, 5)
        let expected: Array<Byte> = [1, 2, 3, 4, 5]
        @Assert(buf.toArray(), expected)
    }

    @TestCase
    public func testByteBufferAppendEmpty(): Unit {
        let buf = corebase.ByteBuffer([1, 2])
        buf.append([])
        @Assert(buf.size, 2)
    }

    @TestCase
    public func testByteBufferClear(): Unit {
        let buf = corebase.ByteBuffer([1, 2, 3])
        buf.clear()
        @Assert(buf.size, 0)
    }

    @TestCase
    public func testByteBufferMultipleClears(): Unit {
        let buf = corebase.ByteBuffer([1, 2])
        buf.clear()
        buf.clear()
        buf.append([10, 20])
        @Assert(buf.size, 2)
        let expected: Array<Byte> = [10, 20]
        @Assert(buf.toArray(), expected)
    }
}
