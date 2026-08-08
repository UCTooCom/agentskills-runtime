/**
 * Mock QUIC 传输层单元测试。
 *
 * 覆盖：
 * - MockQuicStream 读写、关闭、流类型
 * - MockQuicConnection 流管理、接受、关闭
 * - QuicStreamType 操作符（==、!=）
 * - Http3StreamType 常量存在性
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse}

// ======== Mock QUIC 流测试 ========

@Test
public class MockQuicStreamTest {

    @TestCase
    public func testMockStreamReadWrite(): Unit {
        let stream = MockQuicStream(data: [0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
        let buf = Array<UInt8>(5, repeat: 0)
        let n = stream.read(buf)
        assertTrue(n == 5, message: "Should read 5 bytes")
        assertTrue(buf[0] == 0x48 && buf[1] == 0x65 && buf[2] == 0x6C)
        let written = stream.write([0x57, 0x6F, 0x72, 0x6C, 0x64])
        assertTrue(written == 5)
        let data = stream.getWrittenData()
        assertTrue(data.size == 5)
        assertTrue(data[0] == 0x57) // 'W'
    }

    @TestCase
    public func testMockStreamClose(): Unit {
        let stream = MockQuicStream()
        assertFalse(stream.isClosed())
        stream.close()
        assertTrue(stream.isClosed())
    }

    @TestCase
    public func testMockStreamReadAfterClose(): Unit {
        let stream = MockQuicStream(data: [0x01, 0x02])
        stream.closeRead()
        let buf = Array<UInt8>(10, repeat: 0)
        let n = stream.read(buf)
        assertTrue(n == 0, message: "Read after close should return 0")
    }

    @TestCase
    public func testMockStreamWriteAfterClose(): Unit {
        let stream = MockQuicStream()
        stream.closeWrite()
        let n = stream.write([0x01])
        assertTrue(n == 0, message: "Write after close should return 0")
    }

    @TestCase
    public func testMockStreamAddReadData(): Unit {
        let stream = MockQuicStream(data: [0x01])
        stream.addReadData([0x02, 0x03])
        let buf = Array<UInt8>(3, repeat: 0)
        let n = stream.read(buf)
        assertTrue(n == 3, message: "Should read all 3 bytes")
        assertTrue(buf[0] == 0x01 && buf[1] == 0x02 && buf[2] == 0x03)
    }

    @TestCase
    public func testMockStreamStreamType(): Unit {
        let bidir = MockQuicStream(streamType: QuicStreamType.BIDIRECTIONAL)
        assertTrue(bidir.getStreamType() == QuicStreamType.BIDIRECTIONAL)
        let unidir = MockQuicStream(streamType: QuicStreamType.UNIDIRECTIONAL)
        assertTrue(unidir.getStreamType() == QuicStreamType.UNIDIRECTIONAL)
    }

    @TestCase
    public func testMockStreamNoDataReturnsEOF(): Unit {
        let stream = MockQuicStream()
        let buf = Array<UInt8>(10, repeat: 0)
        let n = stream.read(buf)
        assertTrue(n == 0, message: "No data should return 0")
    }


    @TestCase
    public func testMockStreamFlush(): Unit {
        let stream = MockQuicStream()
        try {
            stream.flush()
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "flush should not throw")
        }
    }

    @TestCase
    public func testMockStreamGetWrittenString(): Unit {
        let stream = MockQuicStream()
        stream.write([0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
        let str = stream.getWrittenString()
        assertTrue(str == "Hello", message: "Written string should be 'Hello'")
    }

    @TestCase
    public func testMockStreamGetAllWrittenData(): Unit {
        let stream = MockQuicStream()
        stream.write([0x01, 0x02])
        let allData = stream.getAllWrittenData()
        assertTrue(allData.size == 2, message: "Should have 2 bytes written")
        assertTrue(allData[0] == 0x01, message: "First byte should be 0x01")
    }

    @TestCase
    public func testMockStreamGetReadIndex(): Unit {
        let stream = MockQuicStream(data: [0x41, 0x42, 0x43]) // "ABC"
        assertTrue(stream.getReadIndex() == 0, message: "Read index should start at 0")
        let buf = Array<UInt8>(2, repeat: 0)
        let _ = stream.read(buf)
        assertTrue(stream.getReadIndex() == 2, message: "Read index should be 2 after reading 2 bytes")
    }
}

// ======== Mock QUIC 连接测试 ========

@Test
public class MockQuicConnectionTest {

    @TestCase
    public func testMockConnectionOpenStream(): Unit {
        let conn = MockQuicConnection(serverMode: false)
        let stream = conn.openStream()
        match (stream) {
            case Some(s) =>
                assertTrue(s.getStreamType() == QuicStreamType.BIDIRECTIONAL)
                assertTrue(conn.getOutgoingBidirStreams().size == 1)
            case None => assertTrue(false, message: "Should create stream")
        }
    }

    @TestCase
    public func testMockConnectionOpenUnidirectionalStream(): Unit {
        let conn = MockQuicConnection()
        let stream = conn.openUnidirectionalStream()
        match (stream) {
            case Some(s) =>
                assertTrue(s.getStreamType() == QuicStreamType.UNIDIRECTIONAL)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testMockConnectionAcceptStream(): Unit {
        let conn = MockQuicConnection(serverMode: true)
        let incoming = MockQuicStream(streamId: 0)
        conn.addIncomingBidirStream(incoming)
        let accepted = conn.acceptStream()
        match (accepted) {
            case Some(s) => assertTrue(s.getStreamId() == 0)
            case None => assertTrue(false, message: "Should accept stream")
        }
    }

    @TestCase
    public func testMockConnectionClose(): Unit {
        let conn = MockQuicConnection()
        assertFalse(conn.isClosed())
        conn.close()
        assertTrue(conn.isClosed())
    }

    @TestCase
    public func testMockConnectionCloseWithError(): Unit {
        let conn = MockQuicConnection()
        conn.closeWithError(QuicErrorCode.QUIC_INTERNAL_ERROR, "test error")
        assertTrue(conn.isClosed())
    }

    @TestCase
    public func testMockConnectionMultipleStreams(): Unit {
        let conn = MockQuicConnection(serverMode: true)
        conn.addIncomingBidirStream(MockQuicStream(streamId: 0))
        conn.addIncomingBidirStream(MockQuicStream(streamId: 4))
        conn.addIncomingBidirStream(MockQuicStream(streamId: 8))

        let s1 = conn.acceptStream()
        let s2 = conn.acceptStream()
        let s3 = conn.acceptStream()
        let s4 = conn.acceptStream()
        match (s1) {
            case Some(s) => assertTrue(s.getStreamId() == 0)
            case None => assertTrue(false)
        }
        match (s4) {
            case Some(_) => assertTrue(false, message: "Should not have 4th stream")
            case None => assertTrue(true)
        }
    }


    @TestCase
    public func testMockConnectionAddIncomingUnidirStream(): Unit {
        let conn = MockQuicConnection(serverMode: true)
        let stream = MockQuicStream(streamId: 0, streamType: QuicStreamType.UNIDIRECTIONAL)
        conn.addIncomingUnidirStream(stream)
        let accepted = conn.acceptUnidirectionalStream()
        match (accepted) {
            case Some(s) => assertTrue(s.getStreamId() == 0, message: "Should accept the added stream")
            case None => assertTrue(false, message: "Should accept a unidirectional stream")
        }
    }

    @TestCase
    public func testMockConnectionAcceptUnidirectionalStreamEmpty(): Unit {
        let conn = MockQuicConnection(serverMode: true)
        let accepted = conn.acceptUnidirectionalStream()
        match (accepted) {
            case Some(_) => assertTrue(false, message: "Should not accept when no streams")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testMockConnectionGetOutgoingUnidirStreams(): Unit {
        let conn = MockQuicConnection()
        let before = conn.getOutgoingUnidirStreams()
        assertTrue(before.size == 0, message: "Initially should have 0 outgoing unidirectional streams")
        let stream = conn.openUnidirectionalStream()
        match (stream) {
            case Some(s) => assertTrue(conn.getOutgoingUnidirStreams().size == 1)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testMockConnectionGetRemoteAddr(): Unit {
        let conn = MockQuicConnection()
        assertTrue(conn.getRemoteAddr() == "", message: "Default remote addr should be empty")
        conn.setRemoteAddr("192.168.1.1:443")
        assertTrue(conn.getRemoteAddr() == "192.168.1.1:443", message: "Remote addr should be updated")
    }

    @TestCase
    public func testMockConnectionSetReadTimeout(): Unit {
        let conn = MockQuicConnection()
        try {
            conn.setReadTimeout(Duration.second / 10)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setReadTimeout should not throw")
        }
    }

    @TestCase
    public func testMockConnectionGetLastError(): Unit {
        let conn = MockQuicConnection()
        conn.closeWithError(QuicErrorCode.QUIC_INTERNAL_ERROR, "test error")
        let (code, msg) = conn.getLastError()
        assertTrue(code == Some(QuicErrorCode.QUIC_INTERNAL_ERROR),
            message: "Error code should match")
        assertTrue(msg.contains("test error"), message: "Error message should match")
    }
}

// ======== QuicStreamType 操作符测试 ========

@Test
public class QuicStreamTypeOperatorTest {

    @TestCase
    public func testBidirectionalEqualsItself(): Unit {
        assertTrue(QuicStreamType.BIDIRECTIONAL == QuicStreamType.BIDIRECTIONAL)
    }

    @TestCase
    public func testUnidirectionalEqualsItself(): Unit {
        assertTrue(QuicStreamType.UNIDIRECTIONAL == QuicStreamType.UNIDIRECTIONAL)
    }

    @TestCase
    public func testBidirectionalNotEqualsUnidirectional(): Unit {
        assertTrue(QuicStreamType.BIDIRECTIONAL != QuicStreamType.UNIDIRECTIONAL)
    }

    @TestCase
    public func testUnidirectionalNotEqualsBidirectional(): Unit {
        assertTrue(QuicStreamType.UNIDIRECTIONAL != QuicStreamType.BIDIRECTIONAL)
    }

    @TestCase
    public func testNotEqualsConsistentWithEquals(): Unit {
        assertTrue((QuicStreamType.BIDIRECTIONAL == QuicStreamType.UNIDIRECTIONAL) == false)
    }
}

// ======== QuicStreamType 扩展测试 ========

@Test
public class QuicStreamTypeExtendedTest {

    @TestCase
    public func testEqualitySame(): Unit {
        assertTrue(QuicStreamType.BIDIRECTIONAL == QuicStreamType.BIDIRECTIONAL)
        assertTrue(QuicStreamType.UNIDIRECTIONAL == QuicStreamType.UNIDIRECTIONAL)
    }

    @TestCase
    public func testEqualityDifferent(): Unit {
        assertTrue(!(QuicStreamType.BIDIRECTIONAL == QuicStreamType.UNIDIRECTIONAL))
    }

    @TestCase
    public func testInequalityDifferent(): Unit {
        assertTrue(QuicStreamType.BIDIRECTIONAL != QuicStreamType.UNIDIRECTIONAL)
    }

    @TestCase
    public func testInequalitySame(): Unit {
        assertTrue(!(QuicStreamType.BIDIRECTIONAL != QuicStreamType.BIDIRECTIONAL))
    }
}

// ======== Http3StreamType 测试 ========

@Test
public class Http3StreamTypeTest {

    @TestCase
    public func testStreamTypeConstantsExist(): Unit {
        let control = Http3StreamType.CONTROL_STREAM
        let push = Http3StreamType.PUSH_STREAM
        let encoder = Http3StreamType.QPACK_ENCODER_STREAM
        let decoder = Http3StreamType.QPACK_DECODER_STREAM
        assertTrue(true)
    }
}
