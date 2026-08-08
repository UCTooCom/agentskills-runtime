/**
 * QPACK 头部压缩单元测试（RFC 9204）。
 *
 * 覆盖：
 * - QPACK 编码/解码往返
 * - 编码器流同步
 * - 空头部、单头部、多头部编码
 * - 空数据解码
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, ProtocolException}

// ======== QPACK 编码/解码集成测试 ========

@Test
public class QpackIntegrationTest {

    @TestCase
    public func testQpackEncoderDecoderRoundtrip(): Unit {
        let encoder = QpackEncoder(maxTableCapacity: 4096)
        let decoder = QpackDecoder(maxTableCapacity: 4096)

        let originalHeaders = HttpHeaders()
        originalHeaders.set("content-type", "application/json")
        originalHeaders.set("cache-control", "no-cache")

        let encoded = encoder.encode(originalHeaders)
        let decoded = decoder.decode(encoded)

        let ct = decoded.get("content-type")
        match (ct) {
            case Some(v) => assertTrue(v == "application/json",
                message: "Content-Type should survive QPACK roundtrip")
            case None => assertTrue(false, message: "Content-Type should be present after decode")
        }
    }

    @TestCase
    public func testQpackEncoderStreamSync(): Unit {
        let encoder = QpackEncoder(maxTableCapacity: 4096)
        let decoder = QpackDecoder(maxTableCapacity: 4096)

        let headers = HttpHeaders()
        headers.set("x-custom-header", "custom-value")

        let encoded = encoder.encode(headers)
        let streamData = encoder.getEncoderStreamData()

        if (streamData.size > 0) {
            decoder.processEncoderStream(streamData)
        }

        let decoded = decoder.decode(encoded)
        let custom = decoded.get("x-custom-header")
        match (custom) {
            case Some(v) => assertTrue(v == "custom-value",
                message: "Custom header should survive QPACK roundtrip")
            case None => assertTrue(false, message: "Custom header should be present")
        }
    }
}

// ======== QPACK 编码/解码边缘测试 ========

@Test
public class QpackEdgeTest {

    @TestCase
    public func testEncodeEmptyHeaders(): Unit {
        let encoder = QpackEncoder()
        let headers = HttpHeaders()
        let encoded = encoder.encode(headers)
        assertTrue(encoded.size > 0, message: "Empty headers should still produce valid encoding")
    }

    @TestCase
    public func testEncodeSingleHeader(): Unit {
        let encoder = QpackEncoder()
        let headers = HttpHeaders()
        headers.set("content-type", "application/json")
        let encoded = encoder.encode(headers)
        assertTrue(encoded.size > 0, message: "Single header should be encoded")
    }

    @TestCase
    public func testEncodeMultipleHeaders(): Unit {
        let encoder = QpackEncoder()
        let headers = HttpHeaders()
        headers.set("content-type", "text/plain")
        headers.set("content-length", "42")
        headers.set("host", "example.com")
        headers.set("accept", "*/*")
        let encoded = encoder.encode(headers)
        assertTrue(encoded.size > 0, message: "Multiple headers should be encoded")
    }

    @TestCase
    public func testDecodeEmptyProducesEmpty(): Unit {
        let decoder = QpackDecoder()
        let decoded = decoder.decode([])
        assertTrue(decoded.size == 0, message: "Empty input should produce empty output")
    }
}


// ======== QPACK 编码帧构建测试 ========

@Test
public class QpackFrameBuilderTest {

    @TestCase
    public func testBuildHeaderAck(): Unit {
        let frame = buildHeaderAck(0u64)
        assertTrue(frame.size > 0, message: "Header ACK frame should not be empty")
        // 验证可以多次构造不同 streamId
        let frame5 = buildHeaderAck(5u64)
        assertTrue(frame5.size > 0, message: "Header ACK frame (stream 5) should not be empty")
    }

    @TestCase
    public func testBuildInsertCountIncrementFrame(): Unit {
        let frame = buildInsertCountIncrementFrame(1u64)
        assertTrue(frame.size > 0, message: "Insert Count Increment frame should not be empty")
        let frame0 = buildInsertCountIncrementFrame(0u64)
        assertTrue(frame0.size > 0, message: "Insert Count Increment (0) frame should not be empty")
    }

    @TestCase
    public func testBuildStreamCancellationFrame(): Unit {
        let frame = buildStreamCancellationFrame(0u64)
        assertTrue(frame.size > 0, message: "Stream Cancellation frame should not be empty")
    }

    @TestCase
    public func testDecodeEncoderStreamEmpty(): Unit {
        // 空数据不应抛出异常
        try {
            decodeEncoderStream([])
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "decodeEncoderStream with empty data should not throw")
        }
    }
}

// ======== QPACK 动态表测试 ========

@Test
public class QpackDynamicTableTest {

    @TestCase
    public func testTableDefaultState(): Unit {
        let table = QpackDynamicTable()
        assertTrue(table.getMaxCapacity() == 0, message: "Default max capacity should be 0")
        assertTrue(table.getSize() == 0, message: "Default size should be 0")
        assertTrue(table.getNumEntries() == 0, message: "Default number of entries should be 0")
        assertTrue(table.getInsertCount() == 0, message: "Default insert count should be 0")
    }

    @TestCase
    public func testTableSetCapacity(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        assertTrue(table.getMaxCapacity() == 4096, message: "Max capacity should be updated to 4096")
    }

    @TestCase
    public func testTableInsert(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        let idx = table.insert("content-type", "text/html")
        assertTrue(idx >= 0, message: "Insert should return a valid index")
        assertTrue(table.getNumEntries() == 1, message: "Should have 1 entry after insert")
        assertTrue(table.getInsertCount() == 1, message: "Insert count should be 1")
    }

    @TestCase
    public func testTableInsertMultiple(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        table.insert("content-type", "text/html")
        table.insert("cache-control", "no-cache")
        assertTrue(table.getNumEntries() == 2, message: "Should have 2 entries after 2 inserts")
        assertTrue(table.getInsertCount() == 2, message: "Insert count should be 2")
    }

    @TestCase
    public func testTableInsertGetByAbsoluteIndex(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        table.insert("content-type", "text/html")
        table.insert("cache-control", "no-cache")
        let entry0 = table.getByAbsoluteIndex(0)
        match (entry0) {
            case Some(e) => assertTrue(e.name == "content-type" && e.value == "text/html",
                message: "Entry 0 should be content-type: text/html")
            case None => assertTrue(false, message: "Entry 0 should exist")
        }
        let entry1 = table.getByAbsoluteIndex(1)
        match (entry1) {
            case Some(e) => assertTrue(e.name == "cache-control" && e.value == "no-cache",
                message: "Entry 1 should be cache-control: no-cache")
            case None => assertTrue(false, message: "Entry 1 should exist")
        }
    }

    @TestCase
    public func testTableGetByAbsoluteIndexInvalid(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        table.insert("content-type", "text/html")
        let entryNeg = table.getByAbsoluteIndex(-1)
        match (entryNeg) {
            case Some(_) => assertTrue(false, message: "Negative index should return None")
            case None => assertTrue(true)
        }
        let entryOut = table.getByAbsoluteIndex(100)
        match (entryOut) {
            case Some(_) => assertTrue(false, message: "Out-of-range index should return None")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testTableFindEntry(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        table.insert("content-type", "text/html")
        table.insert("cache-control", "no-cache")
        let (idx, isStatic) = table.findEntry("content-type", "text/html")
        assertTrue(idx >= 0, message: "Should find existing entry")
        let (idxNotFound, _) = table.findEntry("x-custom", "value")
        assertTrue(idxNotFound == -1, message: "Non-existent entry should return -1")
    }

    @TestCase
    public func testTableClear(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        table.insert("content-type", "text/html")
        assertTrue(table.getNumEntries() > 0, message: "Should have entries before clear")
        table.clear()
        assertTrue(table.getNumEntries() == 0, message: "Should have 0 entries after clear")
        assertTrue(table.getSize() == 0, message: "Size should be 0 after clear")
    }

    @TestCase
    public func testTableGetByRelativeIndex(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        table.insert("content-type", "text/html")
        table.insert("cache-control", "no-cache")
        // base = getInsertCount() = 2
        // relativeIndex 0 => absolute = base - 1 - 0 = 1 (cache-control)
        let entry = table.getByRelativeIndex(0, table.getInsertCount())
        match (entry) {
            case Some(e) => assertTrue(e.name == "cache-control",
                message: "Relative index 0 with base=insertCount should be the newest entry")
            case None => assertTrue(false, message: "Relative index 0 should resolve")
        }
    }

    @TestCase
    public func testTableDuplicate(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        let idx = table.insert("content-type", "text/html")
        let dupIdx = table.duplicate(idx)
        assertTrue(dupIdx > idx, message: "Duplicated entry should have a new index")
        assertTrue(table.getNumEntries() == 2, message: "After duplicate should have 2 entries")
    }

    @TestCase
    public func testTableDuplicateInvalid(): Unit {
        let table = QpackDynamicTable()
        table.setCapacity(4096)
        table.insert("content-type", "text/html")
        try {
            let _ = table.duplicate(100)
            assertTrue(false, message: "Duplicate of non-existent entry should throw")
        } catch (e: ProtocolException) {
            assertTrue(true)
        }
    }
}

// ======== QPACK 编码器/解码器配置测试 ========

@Test
public class QpackEncoderDecoderConfigTest {

    @TestCase
    public func testEncoderDefaults(): Unit {
        let encoder = QpackEncoder()
        assertTrue(encoder.getMaxTableCapacity() == QPACK_MAX_TABLE_CAPACITY_DEFAULT,
            message: "Default encoder max table capacity should match constant")
        assertTrue(encoder.getBlockedStreams() == QPACK_BLOCKED_STREAMS_DEFAULT,
            message: "Default encoder blocked streams should match constant")
    }

    @TestCase
    public func testDecoderDefaults(): Unit {
        let decoder = QpackDecoder()
        assertTrue(decoder.getMaxTableCapacity() == QPACK_MAX_TABLE_CAPACITY_DEFAULT,
            message: "Default decoder max table capacity should match constant")
        assertTrue(decoder.getKnownInsertCount() == 0,
            message: "Default decoder known insert count should be 0")
    }

    @TestCase
    public func testEncoderWithCustomCapacity(): Unit {
        let encoder = QpackEncoder(maxTableCapacity: 8192, blockedStreams: 50)
        assertTrue(encoder.getMaxTableCapacity() == 8192,
            message: "Custom encoder max table capacity should be 8192")
        assertTrue(encoder.getBlockedStreams() == 50,
            message: "Custom encoder blocked streams should be 50")
    }

    @TestCase
    public func testDecoderWithCustomCapacity(): Unit {
        let decoder = QpackDecoder(maxTableCapacity: 8192)
        assertTrue(decoder.getMaxTableCapacity() == 8192,
            message: "Custom decoder max table capacity should be 8192")
    }

    @TestCase
    public func testDecoderProcessEncoderStreamThenEncodeDecode(): Unit {
        let encoder = QpackEncoder(maxTableCapacity: 4096)
        let decoder = QpackDecoder(maxTableCapacity: 4096)
        let headers = HttpHeaders()
        headers.set("custom-key", "custom-value")
        let encoded = encoder.encode(headers)
        let streamData = encoder.getEncoderStreamData()
        if (streamData.size > 0) {
            decoder.processEncoderStream(streamData)
        }
        let decoded = decoder.decode(encoded)
        let val = decoded.get("custom-key")
        match (val) {
            case Some(v) => assertTrue(v == "custom-value")
            case None => assertTrue(false, message: "Roundtrip with processEncoderStream should work")
        }
    }

    @TestCase
    public func testDecoderProcessDecoderInstructionEmpty(): Unit {
        let encoder = QpackEncoder()
        try {
            encoder.processDecoderInstruction([])
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "processDecoderInstruction with empty data should not throw")
        }
    }
}

// ======== QPACK 编码器流追踪测试 ========

@Test
public class QpackEncoderStreamTrackingTest {

    @TestCase
    public func testInitialPendingAckStreamEmpty(): Unit {
        let encoder = QpackEncoder()
        assertTrue(encoder.getPendingAckStreamCount() == 0,
            message: "New encoder should have 0 pending ACK streams")
        assertTrue(!encoder.hasPendingAckStream(0u64),
            message: "No streams should be registered initially")
    }

    @TestCase
    public func testRegisterEncodedStream(): Unit {
        let encoder = QpackEncoder()
        encoder.registerEncodedStream(1u64)
        assertTrue(encoder.getPendingAckStreamCount() == 1,
            message: "After registering stream 1, count should be 1")
        assertTrue(encoder.hasPendingAckStream(1u64),
            message: "Stream 1 should be pending ACK")
    }

    @TestCase
    public func testRegisterMultipleStreams(): Unit {
        let encoder = QpackEncoder()
        encoder.registerEncodedStream(1u64)
        encoder.registerEncodedStream(3u64)
        encoder.registerEncodedStream(5u64)
        assertTrue(encoder.getPendingAckStreamCount() == 3,
            message: "After 3 registrations, count should be 3")
        assertTrue(encoder.hasPendingAckStream(1u64),
            message: "Stream 1 should be pending ACK")
        assertTrue(encoder.hasPendingAckStream(3u64),
            message: "Stream 3 should be pending ACK")
        assertTrue(encoder.hasPendingAckStream(5u64),
            message: "Stream 5 should be pending ACK")
    }

    @TestCase
    public func testHeaderAckRemovesStream(): Unit {
        let encoder = QpackEncoder()
        encoder.registerEncodedStream(5u64)
        assertTrue(encoder.getPendingAckStreamCount() == 1,
            message: "Stream 5 should be registered")

        // 构建 Header Ack 指令（0x80 | streamId varint）
        let ackData = buildHeaderAck(5u64)
        encoder.processDecoderInstruction(ackData)

        assertTrue(encoder.getPendingAckStreamCount() == 0,
            message: "After Header Ack, pending count should be 0")
        assertTrue(!encoder.hasPendingAckStream(5u64),
            message: "After Header Ack, stream 5 should not be pending")
    }

    @TestCase
    public func testStreamCancellationRemovesStream(): Unit {
        let encoder = QpackEncoder()
        encoder.registerEncodedStream(7u64)
        assertTrue(encoder.getPendingAckStreamCount() == 1,
            message: "Stream 7 should be registered")

        // 构建 Stream Cancellation 指令（0x40 | streamId varint）
        let cancelData = buildStreamCancellationFrame(7u64)
        encoder.processDecoderInstruction(cancelData)

        assertTrue(encoder.getPendingAckStreamCount() == 0,
            message: "After Stream Cancellation, pending count should be 0")
        assertTrue(!encoder.hasPendingAckStream(7u64),
            message: "After Stream Cancellation, stream 7 should not be pending")
    }

    @TestCase
    public func testHeaderAckOnlyRemovesSpecifiedStream(): Unit {
        let encoder = QpackEncoder()
        encoder.registerEncodedStream(1u64)
        encoder.registerEncodedStream(3u64)
        encoder.registerEncodedStream(5u64)

        // ACK stream 3
        let ackData = buildHeaderAck(3u64)
        encoder.processDecoderInstruction(ackData)

        assertTrue(encoder.getPendingAckStreamCount() == 2,
            message: "After ACKing stream 3, count should be 2")
        assertTrue(encoder.hasPendingAckStream(1u64),
            message: "Stream 1 should still be pending")
        assertTrue(!encoder.hasPendingAckStream(3u64),
            message: "Stream 3 should not be pending")
        assertTrue(encoder.hasPendingAckStream(5u64),
            message: "Stream 5 should still be pending")
    }

    @TestCase
    public func testStreamCancellationNonExistentIsSafe(): Unit {
        let encoder = QpackEncoder()
        // Cancelling a stream that was never registered should be safe
        let cancelData = buildStreamCancellationFrame(99u64)
        try {
            encoder.processDecoderInstruction(cancelData)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "Cancelling a non-existent stream should not throw")
        }
    }

    @TestCase
    public func testGetPendingAckStreamIds(): Unit {
        let encoder = QpackEncoder()
        encoder.registerEncodedStream(1u64)
        encoder.registerEncodedStream(3u64)
        let ids = encoder.getPendingAckStreamIds()
        assertTrue(ids.size == 2, message: "Should have 2 pending stream IDs")
    }
}
