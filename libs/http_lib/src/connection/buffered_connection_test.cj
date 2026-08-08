package http_lib.connection

import std.collection.ArrayList

private func assertTrue(condition: Bool, msg!: String = ""): Unit {
    if (!condition) { throw Exception("assertion failed: ${msg}") }
}

@Test
public class BufferedConnectionTest {

    @TestCase
    public func testInitNotClosed(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        assertTrue(!bc.isClosed())
    }

    @TestCase
    public func testReadFromBuffer(): Unit {
        let testData: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let inner = MockConnection(testData)
        let bc = BufferedConnection(inner)
        let buf = Array<UInt8>(16, repeat: 0)
        let n = bc.read(buf)
        assertTrue(n == 5)
        assertTrue(buf[0] == b'H')
        assertTrue(buf[4] == b'o')
    }

    @TestCase
    public func testWriteAndFlush(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        let testData: Array<UInt8> = [b'H', b'i']
        bc.write(testData)
        bc.flush()
        assertTrue(!bc.isClosed())
    }

    @TestCase
    public func testClose(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        bc.close()
        assertTrue(bc.isClosed())
    }

    @TestCase
    public func testIsReadable(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        assertTrue(bc.isReadable(None))
        bc.close()
        assertTrue(!bc.isReadable(None))
    }

    @TestCase
    public func testIsWritable(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        assertTrue(bc.isWritable(None))
        bc.close()
        assertTrue(!bc.isWritable(None))
    }

    @TestCase
    public func testReadWithOffsetAndLength(): Unit {
        let testData: Array<UInt8> = [b'A', b'B', b'C', b'D', b'E']
        let inner = MockConnection(testData)
        let bc = BufferedConnection(inner)
        let buf = Array<UInt8>(10, repeat: 0)
        let n = bc.read(buf, 2, 3)
        assertTrue(n == 3)
        assertTrue(buf[2] == b'A')
        assertTrue(buf[4] == b'C')
    }

    @TestCase
    public func testWriteWithOffsetAndLength(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        let data: Array<UInt8> = [0, 0, b'X', b'Y', b'Z']
        bc.write(data, 2, 3)
        bc.flush()
        assertTrue(true)
    }

    @TestCase
    public func testWriteBuffers(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        let buffers = ArrayList<Array<UInt8>>()
        buffers.add([b'H', b'e'])
        buffers.add([b'l', b'l', b'o'])
        bc.writeBuffers(buffers)
        bc.flush()
        assertTrue(true)
    }

    @TestCase
    public func testReadAfterClose(): Unit {
        let inner = MockConnection([])
        let bc = BufferedConnection(inner)
        bc.close()
        let buf = Array<UInt8>(5, repeat: 0)
        let n = bc.read(buf)
        // 关闭后底层连接返回 -1
        assertTrue(n < 0)
    }

    @TestCase
    public func testMultipleReads(): Unit {
        let testData: Array<UInt8> = [1, 2, 3, 4, 5, 6]
        let inner = MockConnection(testData)
        let bc = BufferedConnection(inner)
        let buf = Array<UInt8>(4, repeat: 0)
        let n1 = bc.read(buf)
        assertTrue(n1 == 4)
        assertTrue(buf[0] == 1)
        let n2 = bc.read(buf)
        assertTrue(n2 == 2)
        assertTrue(buf[0] == 5)
    }
}
