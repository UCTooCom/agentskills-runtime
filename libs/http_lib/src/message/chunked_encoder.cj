package http_lib.message

import std.collection.ArrayList
import http_lib.buffer.ByteBuffer
import http_lib.core.HttpHeaders
import http_lib.connection.Connection
import http_lib.utils.toHex64
import http_lib.utils.HEX_CHARS_UPPER

// 预分配常量，避免重复分配
private let CRLF_BYTES: Array<UInt8> = [b'\r', b'\n']
private let ZERO_CRLF: Array<UInt8> = unsafe { "0\r\n".rawData() }

/**
 * 分块传输编码写入器（HTTP/1.1 服务端响应）。
 *
 * 按 RFC 7230 Section 4.1 以分块格式写入数据：
 *   <chunk-size-hex>\r\n
 *   <chunk-data>\r\n
 *   ...
 *   0\r\n
 *   [trailers]\r\n
 *
 * 用法（流式）：
 *   let writer = ChunkedWriter(conn)
 *   writer.writeChunk(data1)
 *   writer.writeChunk(data2)
 *   writer.finish()
 *
 * 用法（预缓冲）：
 *   let bytes = ChunkedWriter.encodeChunked(bodyBytes)
 * 遵循 RFC 7230 4.1 节的分块传输编码格式。
 */
public class ChunkedWriter {
    private var conn: ?Connection = None

    /**
     * 创建绑定到连接的分块写入器，用于流式输出。
     */
    public init(conn: Connection) {
        this.conn = Some(conn)
    }

    /**
     * 创建用于离线编码的分块写入器。
     */
    public init() {}

    /**
     * 向连接写入一个数据分块。
     */
    public func writeChunk(data: Array<UInt8>): Unit {
        match (conn) {
            case Some(c) =>
                writeChunkHeaderFast(c, data.size)
                if (data.size > 0) {
                    c.write(data)
                }
                c.write(CRLF_BYTES)
            case None => ()
        }
    }

    /**
     * 写入最后的空分块和可选的尾部字段。
     */
    public func finish(trailers!: ?HttpHeaders): Unit {
        match (conn) {
            case Some(c) =>
                c.write(ZERO_CRLF)
                match (trailers) {
                    case Some(th) =>
                        let trailerBytes = th.toBytes()
                        if (trailerBytes.size > 0) {
                            c.write(trailerBytes)
                        }
                    case None => ()
                }
                c.write(CRLF_BYTES)
            case None => ()
        }
    }

    /**
     * 写入分块头："<hex-size>\r\n"
     * 
     * 直接十六进制编码到字节数组并写入连接，避免 toHex64 的字符串分配。
     */
    private func writeChunkHeaderFast(conn: Connection, size: Int64): Unit {
        if (size == 0) {
            conn.write(ZERO_CRLF)
            return
        }
        var v = UInt64(size)
        var tmp = v
        var digits: Int64 = 0
        while (tmp > 0) { digits += 1; tmp = tmp >> 4 }
        let bufSize = digits + 2
        var idx = digits - 1
        // 预分配正确大小的数组并直接写入连接，避免 write(data,offset,length) 的逐字节拷贝
        let buf = Array<UInt8>(bufSize, repeat: 0)
        while (v > 0) {
            buf[idx] = HEX_CHARS_UPPER[Int64(v & 0x0f)]
            idx -= 1
            v = v >> 4
        }
        buf[digits] = b'\r'
        buf[digits + 1] = b'\n'
        conn.write(buf)
    }

    // ---- 静态辅助函数 ----

    /**
     * 将数据编码为完整的分块主体（用于预缓冲场景）。
     */
    public static func encodeChunked(data: Array<UInt8>): Array<UInt8> {
        if (data.size == 0) {
            return chunkTerminator()
        }
        // Direct hex conversion to bytes, avoiding toHex64 string allocation
        let hexBytes = bytesFromSize(data.size)
        let term = chunkTerminator()
        let totalSize = hexBytes.size + 4 + data.size + term.size
        var result = Array<UInt8>(totalSize, repeat: 0u8)
        var pos: Int64 = 0
        hexBytes.copyTo(result, 0, pos, hexBytes.size)
        pos += hexBytes.size
        result[pos] = b'\r'; pos += 1
        result[pos] = b'\n'; pos += 1
        data.copyTo(result, 0, pos, data.size)
        pos += data.size
        result[pos] = b'\r'; pos += 1
        result[pos] = b'\n'; pos += 1
        term.copyTo(result, 0, pos, term.size)
        result
    }

    /**
     * 构建分块终止符："0

"
     */
    private static func bytesFromSize(size: Int64): Array<UInt8> {
        // Direct hex encoding of size without string allocation
        var v = UInt64(size)
        if (v == 0) { return [b'0'] }
        var tmp = v
        var digits: Int64 = 0
        while (tmp > 0) { digits += 1; tmp = tmp >> 4 }
        let buf = Array<UInt8>(digits, repeat: 0)
        var idx = digits - 1
        while (v > 0) {
            buf[idx] = HEX_CHARS_UPPER[Int64(v & 0x0f)]
            idx -= 1
            v = v >> 4
        }
        buf
    }

    public static func chunkTerminator(): Array<UInt8> {
        [b'0', b'\r', b'\n', b'\r', b'\n']
    }


}
