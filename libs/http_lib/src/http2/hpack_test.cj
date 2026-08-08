package http_lib.http2

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.HttpHeaders

/**
 * HPACK 头压缩测试（RFC 7541）。
 *
 * === 测试大纲：HPACK 边界 ===
 * 以下测试场景应添加以获得完整的边界覆盖：
 *   - 大头部表：动态表有 4096+ 条目时的编码/解码
 *   - 哈夫曼编码边界情况：全 ASCII、高字节值、空字符串
 * - 动态表大小变更：流中 SETTINGS_HEADER_TABLE_SIZE 增大/减小
 * - 最大头部列表大小：SETTINGS_MAX_HEADER_LIST_SIZE 强制执行
 * - 整数编码边界：2^7-1、2^14-1、2^21-1、2^28-1
 * - 带/不带 Huffman 编码的字符串字面量长度边界
 * - 表条目淘汰：验证表满时的 LRU 淘汰
 * - 同一块中的重复头部名称（RFC 7541 §2.3.2）
 * - 在奇数边界分割的 HPACK CONTINUATION 片段
 * - 零长度的头部值和名称
 * - 极长（>64KB）的头部值
 * - 跨流表状态保持
 * - 解码无效/禁止的位模式
 */
@Test
public class HPACKTest {

    @TestCase
    public func testEncodeDecodeRoundtrip(): Unit {
        let encoder = HPACK()
        let decoder = HPACK()

        let headers = HttpHeaders()
        headers.set(":method", "GET")
        headers.set(":path", "/")
        headers.set(":scheme", "https")
        headers.set(":authority", "example.com")
        headers.set("user-agent", "test-agent")
        headers.set("accept", "*/*")

        let encoded = encoder.encode(headers)
        assertTrue(encoded.size > 0, message: "Encoded headers should not be empty")

        let decoded = decoder.decode(encoded)
        assertTrue(decoded.size > 0, message: "Decoded headers should not be empty")
    }

    @TestCase
    public func testStaticTableLookup(): Unit {
        let encoder = HPACK()
        let decoder = HPACK()

        let headers = HttpHeaders()
        // ":method: GET" 位于静态表索引 2
        headers.set(":method", "GET")
        // ":path: /" 位于静态表索引 4
        headers.set(":path", "/")

        let encoded = encoder.encode(headers)
        let decoded = decoder.decode(encoded)

        match (decoded.get(":method")) {
            case Some(v) => assertTrue(v == "GET", message: "Method should be GET")
            case None => assertTrue(false, message: "Method should be present")
        }
        match (decoded.get(":path")) {
            case Some(v) => assertTrue(v == "/", message: "Path should be /")
            case None => assertTrue(false, message: "Path should be present")
        }
    }

    @TestCase
    public func testStaticTableStatus(): Unit {
        let encoder = HPACK()
        let decoder = HPACK()

        let headers = HttpHeaders()
        // ":status: 200" 位于静态表索引 8
        headers.set(":status", "200")

        let encoded = encoder.encode(headers)
        let decoded = decoder.decode(encoded)

        match (decoded.get(":status")) {
            case Some(v) => assertTrue(v == "200", message: "Status should be 200")
            case None => assertTrue(false, message: "Status should be present")
        }
    }

    @TestCase
    public func testDynamicTableGrowth(): Unit {
        let encoder = HPACK()
        let decoder = HPACK()

        // 添加自定义头部以触发动态表插入
        let headers = HttpHeaders()
        headers.set("x-custom-1", "value1")
        headers.set("x-custom-2", "value2")
        headers.set("x-custom-3", "value3")

        let encoded = encoder.encode(headers)
        let decoded = decoder.decode(encoded)

        // 第二次编码应受益于动态表
        let encoded2 = encoder.encode(headers)
        let decoded2 = decoder.decode(encoded2)

        match (decoded2.get("x-custom-1")) {
            case Some(v) => assertTrue(v == "value1", message: "x-custom-1 should be value1 after dynamic table roundtrip")
            case None => assertTrue(false, message: "x-custom-1 should be present")
        }
    }

    @TestCase
    public func testEmptyHeaders(): Unit {
        let encoder = HPACK()
        let headers = HttpHeaders()
        let encoded = encoder.encode(headers)
        assertTrue(encoded.size == 0, message: "Empty headers should encode to empty bytes")
    }

    @TestCase
    public func testDecodeEmptyData(): Unit {
        let decoder = HPACK()
        let decoded = decoder.decode([])
        assertTrue(decoded.isEmpty(), message: "Decoding empty data should give empty headers")
    }

    @TestCase
    public func testHuffmanEncoding(): Unit {
        // 测试 Huffman 编码/解码对 ASCII 文本正常工作
        let encoder = HPACK()
        let decoder = HPACK()

        // 足够长以触发 Huffman 编码的头部值（>20 字节）
        let headers = HttpHeaders()
        headers.set("user-agent", "http_lib_test_agent/1.0.0")

        let encoded = encoder.encode(headers)
        let decoded = decoder.decode(encoded)

        match (decoded.get("user-agent")) {
            case Some(v) => assertTrue(v == "http_lib_test_agent/1.0.0", message: "User-Agent should round-trip")
            case None => assertTrue(false, message: "User-Agent should be present")
        }
    }

    @TestCase
    public func testLargeHeaderBlock(): Unit {
        let encoder = HPACK()
        let decoder = HPACK()

        let headers = HttpHeaders()
        // 生成大量头部以测试动态表淘汰
        var i: Int64 = 0
        while (i < 50) {
            headers.set("x-header-${i}", "value-${i}-with-some-extra-data-to-increase-size")
            i += 1
        }

        let encoded = encoder.encode(headers)
        let decoded = decoder.decode(encoded)
        assertTrue(decoded.size > 0, message: "Should decode large header block")
    }

    @TestCase
    public func testSetMaxTableSize(): Unit {
        let encoder = HPACK(2048)  // 从 2KB 表开始
        let headers = HttpHeaders()
        headers.set("x-test", "value")

        let _ = encoder.encode(headers)

        // 减小表大小——应触发淘汰
        encoder.setMaxTableSize(1024)
        // 不应抛出异常
        assertTrue(true, message: "Table resize should succeed")
    }

    @TestCase
    public func testSetMaxHeaderListSize(): Unit {
        let decoder = HPACK()

        // 设置一个非常小的头部列表限制（100 字节，每个头部计名称 + 值 + 32 开销）
        decoder.setMaxHeaderListSize(100)

        // 编码超出限制的头部
        let encoder = HPACK()
        let headers = HttpHeaders()
        // 每个头部：name.size + value.size + 32 开销
        // "x-a"(3) + "v1"(2) + 32 = 每个头部 37 字节
        // 3 个头部 = 111 字节 > 100 限制
        headers.set("x-a", "v1")
        headers.set("x-b", "v2")
        headers.set("x-c", "v3")

        let encoded = encoder.encode(headers)

        // 这应抛出 ENHANCE_YOUR_CALM (0xb)
        var threw = false
        try {
            let _ = decoder.decode(encoded)
        } catch (e: Http2Exception) {
            threw = (e.errorCode == Http2ErrorCode.ENHANCE_YOUR_CALM)
        } catch (_: Exception) {
        }
        assertTrue(threw, message: "Should throw ENHANCE_YOUR_CALM when header list size exceeded")
    }
}
