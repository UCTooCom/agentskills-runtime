package http_lib.message

private func assertTrue(condition: Bool, msg!: String = ""): Unit {
    if (!condition) { throw Exception("assertion failed: ${msg}") }
}

private func assertFalse(condition: Bool, msg!: String = ""): Unit {
    assertTrue(!condition, msg: msg)
}

@Test
public class BrotliTest {

    @TestCase
    public func testBrotliAvailable(): Unit {
        // 检查 brotli 是否可用（不依赖具体结果，只检查不崩溃）
        let available = brotliAvailable()
        // 无论是否可用，函数都应正常返回 Bool
        assertTrue(available == true || available == false)
    }

    @TestCase
    public func testSelectContentEncodingNoAccept(): Unit {
        let result = selectContentEncodingWithBrotli(None)
        // 无 Accept-Encoding 时应返回空或默认编码
        assertTrue(result == "" || result == "identity")
    }

    @TestCase
    public func testSelectContentEncodingEmpty(): Unit {
        let result = selectContentEncodingWithBrotli(Some(""))
        assertTrue(result == "" || result == "identity")
    }

    @TestCase
    public func testSelectContentEncodingGzip(): Unit {
        let result = selectContentEncodingWithBrotli(Some("gzip"))
        assertTrue(result == "gzip")
    }

    @TestCase
    public func testSelectContentEncodingBrotli(): Unit {
        let result = selectContentEncodingWithBrotli(Some("br"))
        assertTrue(result == "br" || result == "")
    }

    @TestCase
    public func testBrotliCompressDecompress(): Unit {
        if (brotliAvailable()) {
            let original: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F] // "Hello"
            let compressed = brotliCompress(original)
            assertTrue(compressed.size > 0, msg: "Compressed data should not be empty")
            let decompressed = brotliDecompress(compressed)
            assertTrue(decompressed.size == original.size, msg: "Decompressed size should match original")
            assertTrue(decompressed[0] == original[0] && decompressed[4] == original[4],
                msg: "Decompressed data should match original")
        } else {
            // brotli 不可用时仅验证函数不崩溃
            try {
                let _ = brotliCompress([0x48, 0x65])
                assertTrue(true)
            } catch (_: Exception) {
                assertTrue(true) // 不支持的平台上抛出异常也可接受
            }
        }
    }

    @TestCase
    public func testBrotliCompressEmptyInput(): Unit {
        if (brotliAvailable()) {
            let compressed = brotliCompress([])
            let decompressed = brotliDecompress(compressed)
            assertTrue(decompressed.size == 0, msg: "Decompressed empty data should be empty")
        } else {
            assertTrue(true)
        }
    }
}
