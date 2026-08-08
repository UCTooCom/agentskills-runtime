/**
 * MockConnection 内存模拟连接单元测试。
 *
 * 覆盖：
 * - 基本读写生命周期
 * - 多块 feedData 与 getWrittenBytes
 * - 连接状态与可复用性
 * - 模拟关闭
 * - 工具函数（buildRawGetRequest、buildRawPostRequest）
 */
package http_lib.connection
import std.time.DateTime

import http_lib.core.{assertTrue, assertFalse}
import std.collection.ArrayList

@Test
public class MockConnectionTest {

    @TestCase
    public func testWriteAndGetWritten(): Unit {
        let mc = MockConnection([])
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        mc.write(data)
        let written = mc.getWrittenBytes()
        assertTrue(written.size == 5, message: "should have 5 written bytes")
        assertTrue(written[0] == b'H', message: "first byte should be H")
        assertTrue(written[4] == b'o', message: "last byte should be o")
    }

    @TestCase
    public func testWriteGetString(): Unit {
        let mc = MockConnection([])
        mc.write(unsafe { "Hello".rawData() })
        assertTrue(mc.getWrittenString() == "Hello", message: "getWrittenString should return 'Hello'")
    }

    @TestCase
    public func testWriteCount(): Unit {
        let mc = MockConnection([])
        let a: Array<UInt8> = [b'A']
        let b: Array<UInt8> = [b'B']
        let c: Array<UInt8> = [b'C']
        mc.write(a)
        mc.write(b)
        mc.write(c)
        assertTrue(mc.getWriteCount() == 3, message: "should count 3 writes")
        let written = mc.getWrittenString()
        assertTrue(written == "ABC", message: "should concatenate writes to 'ABC'")
    }

    @TestCase
    public func testReadFromInitialData(): Unit {
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let mc = MockConnection(data)
        let buf = Array<UInt8>(5, repeat: 0u8)
        let n = mc.read(buf)
        assertTrue(n == 5, message: "should read 5 bytes")
        assertTrue(buf[0] == b'H', message: "first byte should be H")
    }

    @TestCase
    public func testReadEmpty(): Unit {
        let mc = MockConnection([])
        let buf = Array<UInt8>(10, repeat: 0u8)
        let n = mc.read(buf)
        assertTrue(n == 0, message: "should read 0 bytes from empty mock")
    }

    @TestCase
    public func testFeedDataAndRead(): Unit {
        let mc = MockConnection([])
        let xyz: Array<UInt8> = [b'X', b'Y', b'Z']
        mc.feedData(xyz)
        let buf = Array<UInt8>(3, repeat: 0u8)
        let n = mc.read(buf)
        assertTrue(n == 3, message: "should read 3 fed bytes")
        assertTrue(buf[0] == b'X', message: "first fed byte should be X")
        assertTrue(buf[2] == b'Z', message: "last fed byte should be Z")
    }

    @TestCase
    public func testFeedDataMultipleChunks(): Unit {
        let mc = MockConnection([])
        let ab: Array<UInt8> = [b'A', b'B']
        let cd: Array<UInt8> = [b'C', b'D']
        mc.feedData(ab)
        mc.feedData(cd)
        let buf = Array<UInt8>(4, repeat: 0u8)
        let n = mc.read(buf)
        assertTrue(n == 4, message: "should read all fed data")
        assertTrue(buf[0] == b'A', message: "first byte should be A")
        assertTrue(buf[3] == b'D', message: "last byte should be D")
    }

    @TestCase
    public func testSimulateCloseStopsRead(): Unit {
        let d: Array<UInt8> = [b'A']
        let mc = MockConnection(d)
        mc.simulateClose()
    let buf = Array<UInt8>(1, repeat: 0u8)
    let n = mc.read(buf)
    assertTrue(n == -1, message: "after simulateClose, read should return -1")
    assertFalse(mc.isConnected(), message: "should not be connected after simulateClose")
    }

    @TestCase
    public func testCloseState(): Unit {
        let mc = MockConnection([])
        assertTrue(mc.isConnected(), message: "new mock should be connected")
        mc.close()
        assertFalse(mc.isConnected(), message: "after close, isConnected should be false")
    }

    @TestCase
    public func testCanReuseTransport(): Unit {
        let mc = MockConnection([])
        assertTrue(mc.canReuseTransport(), message: "new mock should be reusable")
        mc.simulateClose()
        assertFalse(mc.canReuseTransport(), message: "after close should not be reusable")
    }

    @TestCase
    public func testBuildRawGetRequest(): Unit {
        let bytes = buildRawGetRequest("/test")
        let str = String.fromUtf8(bytes)
        assertTrue(str.startsWith("GET /test HTTP/1.1"), message: "should start with GET line")
        assertTrue(str.contains("Host: localhost"), message: "should contain Host header")
        assertTrue(str.contains("HTTP/1.1"), message: "should contain HTTP version")
    }

    @TestCase
    public func testBuildRawPostRequest(): Unit {
        let body: Array<UInt8> = [b'h', b'i']
        let bytes = buildRawPostRequest("/post", body)
        let str = String.fromUtf8(bytes)
        assertTrue(str.startsWith("POST /post HTTP/1.1"), message: "should start with POST line")
        assertTrue(str.contains("Content-Length: 2"), message: "should contain Content-Length")
    }

    @TestCase
    public func testWriteAfterCloseIsNoOp(): Unit {
        let mc = MockConnection([])
        mc.close()
        let d: Array<UInt8> = [b'A']
        mc.write(d)
        let written = mc.getWrittenBytes()
        assertTrue(written.size == 0, message: "write after close should be no-op")
    }

    @TestCase
    public func testReadWithOffset(): Unit {
    let data: Array<UInt8> = [b'A', b'B', b'C', b'D', b'E']
    let mc = MockConnection(data)
    let buf = Array<UInt8>(5, repeat: 0u8)
    let n = mc.read(buf, 1, 3)
    assertTrue(n == 3, message: "should read 3 bytes with offset")
        assertTrue(buf[1] == b'A', message: "offset position should have first byte")
    }

    @TestCase
    public func testIsReadable(): Unit {
        let d: Array<UInt8> = [b'A']
        let mc = MockConnection(d)
        assertTrue(mc.isReadable(None), message: "mock with data should be readable")
        mc.simulateClose()
        assertFalse(mc.isReadable(None), message: "after close should not be readable")
    }

    @TestCase
    public func testIsWritable(): Unit {
        let mc = MockConnection([])
        assertTrue(mc.isWritable(None), message: "new mock should be writable")
        mc.close()
        assertFalse(mc.isWritable(None), message: "after close should not be writable")
    }

    @TestCase
    public func testMultipleReadCalls(): Unit {
        let data: Array<UInt8> = [b'A', b'B', b'C', b'D', b'E']
        let mc = MockConnection(data)
        let b1 = Array<UInt8>(2, repeat: 0u8)
        mc.read(b1)
        assertTrue(b1[0] == b'A', message: "first read should get AB")
        assertTrue(b1[1] == b'B', message: "first read should get AB")
        let b2 = Array<UInt8>(3, repeat: 0u8)
        mc.read(b2)
        assertTrue(b2[0] == b'C', message: "second read should get CDE")
        assertTrue(b2[1] == b'D', message: "second read should get CDE")
        assertTrue(b2[2] == b'E', message: "second read should get CDE")
    }

    @TestCase
    public func testLocalAndRemoteAddress(): Unit {
        let mc = MockConnection([])
        assertTrue(mc.localAddress() == "127.0.0.1:0", message: "local address should be localhost")
        assertTrue(mc.remoteAddress() == "127.0.0.1:0", message: "remote address should be localhost")
    }
}


// ======== MockConnection 时间/状态/配置测试 ========

@Test
public class MockConnectionConfigTest {

    @TestCase
    public func testIsClosed(): Unit {
        let mc = MockConnection([])
        assertFalse(mc.isClosed(), message: "New connection should not be closed")
        mc.close()
        assertTrue(mc.isClosed(), message: "After close, isClosed should return true")
    }

    @TestCase
    public func testConnectedAt(): Unit {
        let mc = MockConnection([])
        let connTime = mc.connectedAt()
        assertTrue(connTime <= DateTime.now(), message: "Connection time should be in the past")
    }

    @TestCase
    public func testLastActivityAt(): Unit {
        let mc = MockConnection([])
        let actTime = mc.lastActivityAt()
        assertTrue(actTime <= DateTime.now(), message: "Last activity time should be in the past")
    }

    @TestCase
    public func testUpdateActivity(): Unit {
        let mc = MockConnection([])
        mc.updateActivity()
        assertTrue(true, message: "updateActivity should not throw")
    }

    @TestCase
    public func testConnectionState(): Unit {
        let mc = MockConnection([])
        let state = mc.connectionState()
        match (state) {
            case Some(_) => assertTrue(true)
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testFlush(): Unit {
        let mc = MockConnection([])
        try {
            mc.flush()
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "flush should not throw")
        }
    }

    @TestCase
    public func testSetReadTimeout(): Unit {
        let mc = MockConnection([])
        try {
            mc.setReadTimeout(Duration.second)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setReadTimeout should not throw")
        }
    }

    @TestCase
    public func testSetWriteTimeout(): Unit {
        let mc = MockConnection([])
        try {
            mc.setWriteTimeout(Duration.second)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setWriteTimeout should not throw")
        }
    }

    @TestCase
    public func testWriteBuffersSingle(): Unit {
        let mc = MockConnection([])
        let buffers = ArrayList<Array<UInt8>>()
        buffers.add([b'H', b'i'])
        mc.writeBuffers(buffers)
        let written = mc.getWrittenBytes()
        assertTrue(written.size == 2, message: "Should write 2 bytes")
        assertTrue(written[0] == b'H', message: "First byte should be H")
    }

    @TestCase
    public func testWriteBuffersMultiple(): Unit {
        let mc = MockConnection([])
        let buffers = ArrayList<Array<UInt8>>()
        buffers.add([b'H', b'e'])
        buffers.add([b'l', b'l', b'o'])
        mc.writeBuffers(buffers)
        let written = mc.getWrittenBytes()
        assertTrue(written.size == 5, message: "Should produce 5 bytes total: He + llo")
    }
}
