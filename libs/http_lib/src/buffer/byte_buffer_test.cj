package http_lib.buffer

import http_lib.core.{assertTrue, assertFalse}

@Test
public class ByteBufferTest {

    @TestCase
    public func testCreateEmpty(): Unit {
        let buf = ByteBuffer(capacity: 0)
        assertTrue(buf.getLimit() == 0)
    }

    @TestCase
    public func testWriteAndRead(): Unit {
        let buf = ByteBuffer(capacity: 16)
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        buf.write(data)
        assertTrue(buf.getLimit() == 5)
    }

    @TestCase
    public func testWriteExceedingCapacity(): Unit {
        let buf = ByteBuffer(capacity: 4)
        let data = Array<UInt8>(8, repeat: 0x01)
        buf.write(data)
        assertTrue(buf.getLimit() == 8)
    }

    @TestCase
    public func testToString(): Unit {
        let buf = ByteBuffer(capacity: 5)
        let data = unsafe { "Hello".rawData() }
        buf.write(data)
        let str = buf.toString()
        assertTrue(str == "Hello")
    }

    @TestCase
    public func testFromOwned(): Unit {
        let data = Array<UInt8>(3, repeat: 0x01)
        let buf = ByteBuffer.fromOwned(data)
        assertTrue(buf.getLimit() == 3)
    }

    @TestCase
    public func testFromOwnedEmpty(): Unit {
        let data: Array<UInt8> = []
        let buf = ByteBuffer.fromOwned(data)
        assertTrue(buf.getLimit() == 0)
    }

    @TestCase
    public func testWriteMultipleTimes(): Unit {
        let buf = ByteBuffer(capacity: 10)
        buf.write(Array<UInt8>(3, repeat: 0x01))
        buf.write(Array<UInt8>(2, repeat: 0x02))
        assertTrue(buf.getLimit() == 5)
    }

    @TestCase
    public func testWriteSliceFromSource(): Unit {
        let buf = ByteBuffer(capacity: 10)
        let data = Array<UInt8>(6, repeat: 0x01)
        buf.write(data, 1, 3)
        assertTrue(buf.getLimit() == 3)
    }

    @TestCase
    public func testWriteByte(): Unit {
        let buf = ByteBuffer(capacity: 4)
        buf.writeByte(b'H')
        buf.writeByte(b'i')
        assertTrue(buf.getLimit() == 2)
        assertTrue(buf.toString() == "Hi")
    }

    @TestCase
    public func testWriteString(): Unit {
        let buf = ByteBuffer(capacity: 32)
        buf.writeString("Hello, World!")
        assertTrue(buf.getLimit() == 13)
        assertTrue(buf.toString() == "Hello, World!")
    }

    @TestCase
    public func testReadByte(): Unit {
        // readByte 从当前位置读取；当缓冲区从数据创建时，
        // 由于 position 起始等于 limit，readByte 返回 None
        let buf = ByteBuffer()
        assertTrue(buf.readByte().isNone(), message: "Empty buffer should return None")
    }

    @TestCase
    public func testGetPosition(): Unit {
        let buf = ByteBuffer(capacity: 16)
        assertTrue(buf.getPosition() == 0)
        let data: Array<UInt8> = [65, 66, 67]
        buf.write(data)
        // 写入后，position 移动到已写入数据的末尾
        assertTrue(buf.getPosition() == 3)
    }

    @TestCase
    public func testRemaining(): Unit {
        let buf = ByteBuffer(capacity: 16)
        assertTrue(buf.remaining() == 0)
        let data: Array<UInt8> = [65, 66, 67, 68, 69]
        buf.write(data)
        // remaining = limit - position = 5 - 5 = 0（write 将 position 设置为 limit）
        assertTrue(buf.remaining() == 0)
        // clear 后，remaining 应为 0（position=0，limit=0）
        buf.clear()
        assertTrue(buf.remaining() == 0)
    }

    @TestCase
    public func testClear(): Unit {
        let buf = ByteBuffer(capacity: 16)
        buf.write([b'A', b'B', b'C'])
        assertTrue(buf.getLimit() == 3)
        buf.clear()
        assertTrue(buf.getPosition() == 0)
        assertTrue(buf.getLimit() == 0)
        assertTrue(buf.remaining() == 0)
        // clear 后应可复用
        buf.write([b'X'])
        assertTrue(buf.getLimit() == 1)
        assertTrue(buf.toString() == "X")
    }

    @TestCase
    public func testGetArray(): Unit {
        let buf = ByteBuffer(capacity: 16)
        buf.write([b'H', b'i'])
        let arr = buf.getArray()
        assertTrue(arr.size >= 16)
        // getArray 返回内部缓冲区，可能有额外容量
        assertTrue(arr[0] == b'H')
        assertTrue(arr[1] == b'i')
    }

    @TestCase
    public func testToArray(): Unit {
        let buf = ByteBuffer(capacity: 16)
        buf.write([b'H', b'e', b'l', b'l', b'o'])
        let arr = buf.toArray()
        assertTrue(arr.size == 5)
        assertTrue(arr[0] == b'H')
        assertTrue(arr[4] == b'o')
    }

    @TestCase
    public func testToArrayEmpty(): Unit {
        let buf = ByteBuffer()
        let arr = buf.toArray()
        assertTrue(arr.size == 0)
    }

    @TestCase
    public func testReserveWritable(): Unit {
        let buf = ByteBuffer(capacity: 4)
        let pos = buf.reserveWritable(10)
        assertTrue(pos == 0)
        // 容量应已增长到足以容纳 10 字节
        buf.write([b'A', b'B', b'C', b'D', b'E'])
        assertTrue(buf.getLimit() == 5)
    }

    @TestCase
    public func testAdvanceWrite(): Unit {
        let buf = ByteBuffer(capacity: 16)
        buf.write([b'A', b'B', b'C'])
        // 直接前移 position 而不写入
        buf.advanceWrite(3)
        assertTrue(buf.getPosition() == 6)
        assertTrue(buf.getLimit() == 6)
        buf.write([b'!'])
        assertTrue(buf.getPosition() == 7)
        assertTrue(buf.getLimit() == 7)
    }
}
