package http_lib.message

import http_lib.core.{assertTrue, assertFalse, ProtocolException}

@Test
public class CompressionTest {

    @TestCase
    public func testDecompressEmpty(): Unit {
        let data: Array<UInt8> = []
        let result = Compression.decompress(data, "gzip")
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testDecompressIdentity(): Unit {
        let data: Array<UInt8> = [b'h', b'e', b'l', b'l', b'o']
        let result = Compression.decompress(data, "identity")
        // Identity 按原样返回数据
        assertTrue(result[0] == b'h')
        assertTrue(result[4] == b'o')
    }

    @TestCase
    public func testDecompressUnknownEncoding(): Unit {
        let data: Array<UInt8> = [b't', b'e', b's', b't']
        let result = Compression.decompress(data, "br")  // 压缩模块不支持 brotli
        // 对于未知编码应返回不变的数据
        assertTrue(result.size == 4)
    }

    @TestCase
    public func testDecompressGzip(): Unit {
        // 测试空数据（无操作）
        let data: Array<UInt8> = []
        let result = Compression.decompressGzip(data)
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testDecompressDeflate(): Unit {
        let data: Array<UInt8> = []
        let result = Compression.decompressDeflate(data)
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testCompressGzipEmpty(): Unit {
        let data: Array<UInt8> = []
        let result = Compression.compressGzip(data)
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testCompressDeflateEmpty(): Unit {
        let data: Array<UInt8> = []
        let result = Compression.compressDeflate(data)
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testCompressGzip(): Unit {
        let data = Array<UInt8>(100, repeat: 0x41)
        let result = Compression.compressGzip(data)
        // 压缩后数据应更小或相同大小
        assertTrue(result.size > 0)
    }

    @TestCase
    public func testCompressDeflate(): Unit {
        let data = Array<UInt8>(100, repeat: 0x41)
        let result = Compression.compressDeflate(data)
        assertTrue(result.size > 0)
    }

    @TestCase
    public func testDecompressWithGzipHeader(): Unit {
        let data: Array<UInt8> = [b'x']
        // 测试 "x-gzip" 与 "gzip" 同等对待
        let threw = try {
            let result = Compression.decompress(data, "x-gzip")
            false
        } catch (_: ProtocolException) {
            true
        }
        assertTrue(threw, message: "x-gzip should attempt gzip decompression and fail on invalid data")
    }

    @TestCase
    public func testCompressGzipLevel(): Unit {
        let data = Array<UInt8>(50, repeat: 0x42)
        let result = Compression.compressGzip(data, level: 9)
        assertTrue(result.size > 0)
    }

    @TestCase
    public func testCompressDeflateLevel(): Unit {
        let data = Array<UInt8>(50, repeat: 0x42)
        let result = Compression.compressDeflate(data, level: 9)
        assertTrue(result.size > 0)
    }
}

// ---- Transfer-Encoding gzip 测试 ----
public class TransferEncodingGzipTest {
    public func testCompressTransferGzip(): Unit {
        let data = unsafe { "hello world hello world hello world".rawData() }
        let compressed = Compression.compressTransfer(data, "gzip")
        assertTrue(compressed.size > 0, message: "gzip 传输压缩应非空")
    }

    public func testDecompressTransferGzip(): Unit {
        let data = unsafe { "test data for transfer encoding".rawData() }
        let compressed = Compression.compressTransfer(data, "gzip")
        let decompressed = Compression.decompressTransfer(compressed, "gzip")
        assertTrue(decompressed == data, message: "gzip 传输编码往返应正确")
    }

    public func testCompressTransferUnknownEncoding(): Unit {
        let data = unsafe { "test".rawData() }
        let result = Compression.compressTransfer(data, "unknown")
        assertTrue(result == data, message: "未知传输编码应返回原数据")
    }

    public func testDecompressTransferUnknownEncoding(): Unit {
        let data = unsafe { "test".rawData() }
        let result = Compression.decompressTransfer(data, "unknown")
        assertTrue(result == data, message: "未知传输编码解压应返回原数据")
    }
}
