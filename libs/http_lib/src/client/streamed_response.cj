package http_lib.client
/**
 * HTTP 流式响应读取器。
 * 支持分块传输、逐行读取和 SSE（服务器推送事件）解析。
 */

import std.collection.ArrayList
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpStatus, HttpVersion, ProtocolException}
import http_lib.connection.Connection
import http_lib.utils.findHeaderEnd

/**
 * 流式 HTTP 响应，允许增量读取响应体。
 *
 * 与完全缓冲的 HttpResponse 不同，StreamedHttpResponse
 * 在解析完响应头后立即返回，底层连接保持打开状态
 * 供调用方通过 read() / readLine() 增量读取。
 *
 * 使用场景：
 *   - SSE（Server-Sent Events）客户端逐行读取事件
 *   - 大文件流式下载，避免完整缓冲到内存
 *   - 逐块处理响应数据的场景
 *
 * 注意：使用完毕后必须调用 close() 释放底层连接。
 */
public class StreamedHttpResponse {
    public let version: HttpVersion
    public let status: HttpStatus
    public let headers: HttpHeaders

    private var conn: Connection
    private var isChunked: Bool
    private var contentLength: Int64
    private var remainingContentLength: Int64
    private var closed: Bool = false

    // 内部读取缓冲区（累积未消费的原始字节）
    private var rawBuf: ByteBuffer
    // 内部解码缓冲区（分块解码后的数据）
    private var decodedBuf: ByteBuffer

    // 分块解码状态
    private var chunkRemaining: Int64 = 0
    private var chunkFinished: Bool = false

    // 缓冲区偏移量，用于 readLine
    private var readPos: Int64 = 0

    public init(
        conn!: Connection,
        version!: HttpVersion,
        status!: HttpStatus,
        headers!: HttpHeaders,
        prefetchedData!: Array<UInt8>
    ) {
        this.conn = conn
        this.version = version
        this.status = status
        this.headers = headers

        // 判断是否使用分块传输编码
        let transferEncoding = headers.get("transfer-encoding")
        this.isChunked = match (transferEncoding) {
            case Some(te) => containsIgnoreCaseChunked(te)
            case None => false
        }

        // 解析 Content-Length
        let cl = headers.get("content-length")
        this.contentLength = match (cl) {
            case Some(v) => parseContentLengthInt64(v)
            case None => -1
        }
        this.remainingContentLength = this.contentLength

        this.rawBuf = ByteBuffer(capacity: prefetchedData.size + 4096)
        if (prefetchedData.size > 0) {
            rawBuf.write(prefetchedData)
        }
        this.decodedBuf = ByteBuffer(capacity: 4096)
    }

    /**
     * 从响应体读取数据到 buf 中。
     * 返回实际读取的字节数，读取完毕或连接关闭时返回 0。
     * 透明地处理分块传输编码和 Content-Length 帧格式。
     */
    public func read(buf: Array<UInt8>): Int64 {
        if (closed || chunkFinished) { return 0 }

        if (isChunked) {
            return readChunked(buf)
        } else if (remainingContentLength >= 0) {
            return readContentLength(buf)
        } else {
            return readUntilClose(buf)
        }
    }

    /**
     * 从响应体读取一行数据（以 \n 结尾）。
     * 适用于 SSE 逐行解析场景。
     * 返回读取的行（不含尾部 \r\n）。
     * 若无更多数据可读，返回空字符串。
     */
    public func readLine(): String {
        if (closed) { return "" }

        // 首先从已解码缓冲区查找换行符
        while (true) {
            let decodedData = decodedBuf.getArray()
            let decodedLen = decodedBuf.getLimit()

            // 在已解码数据中查找换行符
            var i = readPos
            while (i < decodedLen) {
                if (decodedData[i] == b'\n') {
                    let lineLen = i - readPos
                    // 去掉尾部 \r
                    let effectiveLen = if (lineLen > 0 && decodedData[i - 1] == b'\r') { lineLen - 1 } else { lineLen }
                    let lineBytes = Array<UInt8>(effectiveLen, repeat: 0)
                    var j: Int64 = 0
                    while (j < effectiveLen) {
                        lineBytes[j] = decodedData[readPos + j]
                        j++
                    }
                    readPos = i + 1
                    return String.fromUtf8(lineBytes)
                }
                i++
            }

            // 保留剩余未消费数据作为前缀
            let remaining = decodedLen - readPos
            if (remaining > 0) {
                var ri: Int64 = 0
                while (ri < remaining) {
                    decodedData[ri] = decodedData[readPos + ri]
                    ri++
                }
                decodedBuf.clear()
                decodedBuf.advanceWrite(remaining)
                readPos = 0
            } else {
                decodedBuf.clear()
                readPos = 0
            }

            // 读取更多原始数据
            let scratch = Array<UInt8>(4096, repeat: 0)
            let n = read(scratch)
            if (n <= 0) {
                // 没有更多数据，返回已缓冲内容
                if (remaining > 0) {
                    let lineBytes = Array<UInt8>(remaining, repeat: 0)
                    var j: Int64 = 0
                    while (j < remaining) {
                        lineBytes[j] = decodedData[j]
                        j++
                    }
                    decodedBuf.clear()
                    readPos = 0
                    return String.fromUtf8(lineBytes)
                }
                return ""
            }

            // 追加到解码缓冲区
           decodedBuf.write(scratch, 0, n)
       }
        // 不可达：编译器需要所有路径都有返回值
        ""
    }

    /**
     * 关闭底层连接并释放资源。
     */
    public func close(): Unit {
        if (!closed) {
            closed = true
            try { conn.close() } catch (_: Exception) {}
        }
    }

    /**
     * 检查底层连接是否仍可用于读取。
     */
    public func isClosed(): Bool {
        closed || chunkFinished ||
        (remainingContentLength == 0 && remainingContentLength >= 0)
    }

    // ---- 内部读取方法 ----

    /**
     * 从分块编码的响应体中读取解码后的数据。
     */
    private func readChunked(buf: Array<UInt8>): Int64 {
        if (chunkFinished) { return 0 }

        // 首先消耗已缓冲的原始数据
        if (rawBuf.getLimit() > 0) {
            let rawData = rawBuf.getArray()
            let rawLen = rawBuf.getLimit()
            var consumed: Int64 = 0
            var written: Int64 = 0

            while (consumed < rawLen && written < buf.size && !chunkFinished) {
                if (chunkRemaining == 0) {
                    // 解析下一个分块大小
                    var ci = consumed
                    // 找到 \r\n
                    while (ci + 1 < rawLen) {
                        if (rawData[ci] == b'\r' && rawData[ci + 1] == b'\n') {
                            let lineEnd = ci
                            ci += 2
                            // 解析十六进制分块大小
                            let semicolon = findByteInArray(rawData, consumed, lineEnd, b';')
                            let sizeEnd = if (semicolon >= 0) { semicolon } else { lineEnd }
                            chunkRemaining = parseHexSize(rawData, consumed, sizeEnd)
                            consumed = ci
                            if (chunkRemaining == 0) {
                                // 最后一个空分块
                                chunkFinished = true
                                rawBuf.clear()
                                return written
                            }
                            break
                        }
                        ci++
                    }
                    if (chunkRemaining == 0 && !chunkFinished) {
                        // 不完整的分块大小行 —— 需要更多数据
                        break
                    }
                }

                if (chunkRemaining > 0) {
                    // 检查是否有 \r\n 尾部
                    if (consumed + chunkRemaining + 2 <= rawLen) {
                        let toWrite = if (chunkRemaining < buf.size - written) { chunkRemaining } else { buf.size - written }
                        var di: Int64 = 0
                        while (di < toWrite) {
                            buf[written + di] = rawData[consumed + di]
                            di++
                        }
                        written += toWrite
                        consumed += toWrite
                        chunkRemaining -= toWrite

                        if (chunkRemaining == 0) {
                            // 跳过 \r\n
                            consumed += 2
                        }
                    } else {
                        // 不完整的分块数据
                        break
                    }
                }
            }

            // 清理已消费的数据
            if (consumed > 0) {
                let remaining = rawLen - consumed
                if (remaining > 0) {
                    var ri: Int64 = 0
                    while (ri < remaining) {
                        rawData[ri] = rawData[consumed + ri]
                        ri++
                    }
                }
                rawBuf.clear()
                if (remaining > 0) {
                    rawBuf.advanceWrite(remaining)
                }
            }

            if (written > 0) { return written }
        }

        if (chunkFinished) { return 0 }

        // 需要更多原始数据
        let scratch = Array<UInt8>(4096, repeat: 0)
        let n = conn.read(scratch)
        if (n <= 0) {
            chunkFinished = true
            return 0
        }
        rawBuf.write(scratch, 0, n)
        // 递归调用，立即处理新数据
        return readChunked(buf)
    }

    /**
     * 从 Content-Length 帧格式的响应体中读取数据。
     */
    private func readContentLength(buf: Array<UInt8>): Int64 {
        if (remainingContentLength <= 0) { return 0 }

        // 优先消费 rawBuf 中的预取数据
        var written: Int64 = 0
        let rawAvailable = rawBuf.getLimit()
        if (rawAvailable > 0) {
            let rawData = rawBuf.getArray()
            let room = if (remainingContentLength < buf.size) { remainingContentLength } else { buf.size }
            let consume = if (room < rawAvailable) { room } else { rawAvailable }
            var i: Int64 = 0
            while (i < consume) {
                buf[i] = rawData[i]
                i += 1
            }
            written = consume
            rawBuf.clear()
            if (rawAvailable > consume) {
                rawBuf.write(rawData, consume, rawAvailable - consume)
            }
            remainingContentLength -= consume
            // 如果缓冲中有更多空间且连接还有数据，继续读取
            if (consume < room) {
                let moreN = try { conn.read(buf, consume, room - consume) } catch (_: Exception) { 0 }
                if (moreN > 0) {
                    remainingContentLength -= moreN
                    written += moreN
                }
            }
            return written
        }

        let toRead = if (remainingContentLength < buf.size) { remainingContentLength } else { buf.size }
        let n = try { conn.read(buf, 0, toRead) } catch (_: Exception) { 0 }
        if (n > 0) {
            remainingContentLength -= n
        }
        n
    }

    /**
     * 读取直到连接关闭（无 Content-Length 和 Transfer-Encoding 时使用）。
     */
    private func readUntilClose(buf: Array<UInt8>): Int64 {
        try {
            conn.read(buf)
        } catch (_: Exception) {
            0
        }
    }

    // ---- 辅助函数 ----

    private static func containsIgnoreCaseChunked(value: String): Bool {
        let lower = toLowerStr(value)
        lower.contains("chunked")
    }

    private static func toLowerStr(s: String): String {
        let runes = s.toRuneArray()
        var i: Int64 = 0
        while (i < runes.size) {
            if (runes[i] >= r'A' && runes[i] <= r'Z') {
                runes[i] = Rune(UInt32(runes[i]) + 32)
            }
            i++
        }
        String(runes)
    }

    private static func findByteInArray(data: Array<UInt8>, start: Int64, end: Int64, target: UInt8): Int64 {
        var i = start
        while (i < end) {
            if (data[i] == target) { return i }
            i++
        }
        -1
    }

    private static func parseHexSize(data: Array<UInt8>, start: Int64, end: Int64): Int64 {
        if (start >= end) { return 0 }
        var value: Int64 = 0
        var i = start
        while (i < end) {
            let b = data[i]
            var digit: Int64 = -1
            if (b >= b'0' && b <= b'9') { digit = Int64(b - b'0') }
            else if (b >= b'A' && b <= b'F') { digit = Int64(b - b'A') + 10 }
            else if (b >= b'a' && b <= b'f') { digit = Int64(b - b'a') + 10 }
            else { throw ProtocolException("分块大小中存在无效的十六进制数字") }
            if (value > 0x07ffffffffffffff) {
                throw ProtocolException("分块大小过大（溢出）")
            }
            value = value * 16 + digit
            if (value < 0) {
                throw ProtocolException("分块大小过大（溢出）")
            }
            i++
        }
        value
    }

    private static func parseContentLengthInt64(s: String): Int64 {
        let bytes = s.toArray()
        var result: Int64 = 0
        for (b in bytes) {
            if (b >= b'0' && b <= b'9') {
                result = result * 10 + Int64(b - b'0')
            } else {
                break
            }
        }
        result
    }
}
