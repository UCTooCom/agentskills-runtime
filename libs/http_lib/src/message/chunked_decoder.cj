package http_lib.message

import std.collection.ArrayList
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, ProtocolException}

/**
 * 分块传输编码器。
 *
 * 以分块格式解码数据：
 *   <chunk-size-hex>\r\n
 *   <chunk-data>\r\n
 *   ...
 *   0\r\n
 *   [trailer]\r\n
 *   \r\n
 *
 * 尾部字段（RFC 7230 Section 4.4）：在最后的 0 大小分块之后，
 * 发送方可以包含尾部字段。这些字段被解析并
 * 作为 HttpHeaders 返回。
 */

/**
 * 分块解码结果，包含解码后的主体
 * 以及在最后分块后发现的所有尾部头。
 */
public class ChunkedDecodeResult {
    public let data: Array<UInt8>
    public let trailers: HttpHeaders

    public init(data!: Array<UInt8>, trailers!: HttpHeaders = HttpHeaders()) {
        this.data = data
        this.trailers = trailers
    }
}

/**
 * 最大允许的分块大小（64 MB）。
 * 防止超大分块声明导致的内存耗尽 DoS 攻击。
 */
private let MAX_CHUNK_SIZE: Int64 = 64 * 1024 * 1024

/**
 * 每个分块的最大允许分块扩展开销（16 KB）。
 * 防止大量微小分块加巨型扩展导致的 CPU 耗尽。
 * 防止扩展字段滥用。
 */
private let MAX_CHUNK_EXTENSION_OVERHEAD: Int64 = 16 * 1024

/**
 * 最大 Trailer 段大小 (8 KB)。
 * 防止畸形输入导致无限循环。
 */
private let MAX_TRAILER_SIZE: Int64 = 8 * 1024

public class ChunkedDecoder {

    /**
     * 将完整的分块编码主体解码为原始字节。
     * 输入应为紧接在 

 之后的主体（不含头）。
     * 输入中的尾部字段会被静默消费但不返回。
     * 使用 decodeWithTrailers() 捕获尾部字段。
     */
    public static func decode(data: Array<UInt8>): Array<UInt8> {
        let result = decodeWithTrailers(data)
        result.data
    }

    /**
     * 将完整的分块编码主体解码为原始字节。 including
     * 在最后 0 大小分块之后发现的所有尾部字段。
     */
    public static func decodeWithTrailers(data: Array<UInt8>): ChunkedDecodeResult {
        // 预分配结果缓冲区（数据大小通常接近主体大小）
        let estSize = if (data.size > 64) { data.size - 32 } else { data.size }
        let result = ArrayList<UInt8>(estSize)
        let trailers = HttpHeaders()
        var pos: Int64 = 0
        let len = data.size

        while (pos < len) {
            // 查找分块大小行末尾的 

            let lineEnd = findCrlfAt(data, pos, len)
            if (lineEnd < 0) {
                throw ProtocolException("incomplete chunk size line")
            }

            // 检查分块扩展（分号）
            let semicolon = findByteAt(data, pos, lineEnd, b';')
            let sizeEnd = if (semicolon >= 0) { semicolon } else { lineEnd }

            // 检查分块扩展开销（防止 CPU DoS）
            if (semicolon >= 0) {
                let extensionLen = lineEnd - semicolon
                if (extensionLen > MAX_CHUNK_EXTENSION_OVERHEAD) {
                    throw ProtocolException("chunk extension too large (${extensionLen} bytes)")
                }
            }

            // 解析十六进制分块大小
            let chunkSize = parseHexSize(data, pos, sizeEnd)

            // 验证分块大小（防止内存耗尽 DoS）
            if (chunkSize > MAX_CHUNK_SIZE) {
                throw ProtocolException("chunk size ${chunkSize} exceeds maximum ${MAX_CHUNK_SIZE}")
            }

            pos = lineEnd + 2  // 跳过 \r\n

            // 最后一个分块（大小为 0）
            if (chunkSize == 0) {
                // 解析尾部字段直到空行
                while (pos + 1 < len) {
                    let trailerEnd = findCrlfAt(data, pos, len)
                    if (trailerEnd < 0) { break }
                    if (trailerEnd == pos) {
                        // 空行 = 尾部字段结束
                        pos = trailerEnd + 2
                        break
                    }
                    // 解析尾部字段：Name: Value
                    let colonIdx = findByteAt(data, pos, trailerEnd, b':')
                    if (colonIdx >= 0) {
                        let nameStart = pos
                        var nameEnd = colonIdx
                        while (nameEnd > nameStart && (data[nameEnd - 1] == b' ' || data[nameEnd - 1] == b'\t')) { nameEnd -= 1 }
                        var valueStart = colonIdx + 1
                        while (valueStart < trailerEnd && (data[valueStart] == b' ' || data[valueStart] == b'\t')) { valueStart += 1 }
                        var valueEnd = trailerEnd
                        while (valueEnd > valueStart && (data[valueEnd - 1] == b' ' || data[valueEnd - 1] == b'\t')) { valueEnd -= 1 }
                        let tName = String.fromUtf8(data[nameStart..nameEnd])
                        let tValue = if (valueStart < valueEnd) { String.fromUtf8(data[valueStart..valueEnd]) } else { "" }
                        if (tName.size > 0) {
                            trailers.add(tName, tValue)
                        }
                    }
                    pos = trailerEnd + 2
                }
                break
            }

            // 读取分块数据
            if (pos + chunkSize + 2 > len) {
                throw ProtocolException("incomplete chunk data")
            }

            var ci: Int64 = 0
            while (ci < chunkSize) {
                result.add(data[pos + ci])
                ci++
            }
            pos += chunkSize

            // 验证尾部 

            if (pos + 1 >= len || data[pos] != b'\r' || data[pos + 1] != b'\n') {
                throw ProtocolException("invalid chunk terminator")
            }
            pos += 2
        }

        ChunkedDecodeResult(data: result.toArray(), trailers: trailers)
    }

    /**
     * 从套接字读取并解码流式分块主体。
     * 读取分块直到最后的空分块。
     */
    public static func readStreaming(
        reader: (Array<UInt8>) -> Int64,
        prefetched!: Array<UInt8> = [],
        scratchSize!: Int64 = 4096
    ): Array<UInt8> {
        let result = ArrayList<UInt8>()
        let tempBuf = Array<UInt8>(scratchSize, repeat: 0)
        let pendingBuf = ByteBuffer(prefetched)

        while (true) {
            let pending = pendingBuf.getArray()
            let pendingLen = pendingBuf.getLimit()

            // 尝试从待处理数据中解析分块大小
            let chunkSize = tryParseChunkSize(pending, pendingLen)

            match (chunkSize) {
                case Some(cs) =>
                    if (cs == 0) {
                        // 完成 —— 跳过尾部字段
                        return result.toArray()
                    }

                    // 需要读取分块数据
                    let needed = cs + 2  // 数据 + \r\n
                    var dataStart: Int64 = -1

                    // 查找分块大小行的结束位置
                    var i: Int64 = 0
                    while (i + 1 < pendingLen) {
                        if (pending[i] == b'\r' && pending[i + 1] == b'\n') {
                            dataStart = i + 2
                            break
                        }
                        i++
                    }

                    if (dataStart < 0) {
                        throw ProtocolException("invalid chunked encoding")
                    }

                    let available = pendingLen - dataStart
                    if (available >= needed) {
                        // 待处理数据中有完整的分块
                        var ci: Int64 = 0
                        while (ci < cs) {
                            result.add(pending[dataStart + ci])
                            ci++
                        }
                        // 将剩余数据紧凑到缓冲区前端（无需新分配）
                        let remaining = pendingLen - dataStart - needed
                        if (remaining > 0) {
                            var ri: Int64 = 0
                            while (ri < remaining) {
                                pending[ri] = pending[dataStart + needed + ri]
                                ri++
                            }
                        }
                        pendingBuf.clear()
                        if (remaining > 0) { pendingBuf.advanceWrite(remaining) }
                    } else {
                        // 需要读取更多
                        let n = reader(tempBuf)
                        if (n <= 0) {
                            throw ProtocolException("connection closed during chunked read")
                        }
                        pendingBuf.write(tempBuf, 0, n)
                    }

                case None =>
                    // 需要更多数据才能解析分块大小
                    let n = reader(tempBuf)
                    if (n <= 0) {
                        throw ProtocolException("connection closed during chunked read")
                    }
                    pendingBuf.write(tempBuf, 0, n)
            }
        }
        result.toArray()
    }

    /**
     * 从分块主体的尾部字段段解析尾部字段。
     * 输入应从第一个尾部字段行开始（"0
" 之后）。
     * 返回尾部字段和消费的字节数。
     */
    public static func parseTrailers(data: Array<UInt8>, start: Int64, end: Int64): (HttpHeaders, Int64) {
        let trailers = HttpHeaders()
        var pos = start
        while (pos + 1 < end) {
            if (data[pos] == b'\r' && data[pos + 1] == b'\n') {
                // 空行 = 尾部字段结束
                return (trailers, pos + 2 - start)
            }
            let lineEnd = findCrlfAt(data, pos, end)
            if (lineEnd < 0) { break }
            if (lineEnd == pos) { pos += 2; break }

            let colonIdx = findByteAt(data, pos, lineEnd, b':')
            if (colonIdx >= 0) {
                var nameEnd = colonIdx
                while (nameEnd > pos && (data[nameEnd - 1] == b' ' || data[nameEnd - 1] == b'\t')) { nameEnd -= 1 }
                var valueStart = colonIdx + 1
                while (valueStart < lineEnd && (data[valueStart] == b' ' || data[valueStart] == b'\t')) { valueStart += 1 }
                var valueEnd = lineEnd
                while (valueEnd > valueStart && (data[valueEnd - 1] == b' ' || data[valueEnd - 1] == b'\t')) { valueEnd -= 1 }
                let name = String.fromUtf8(data[pos..nameEnd])
                let value = if (valueStart < valueEnd) { String.fromUtf8(data[valueStart..valueEnd]) } else { "" }
                if (name.size > 0) { trailers.add(name, value) }
            }
            pos = lineEnd + 2
        }
        (trailers, pos - start)
    }

    /**
     * 增量流式分块解码器。
     *
     * 输入到达的数据，返回（已解码部分, 剩余字节）。
     * 当更多数据到达时反复调用。当解码输出
     * 被完全接收（发现尾部空行）时，remaining 将为空数组，
     * 调用方应停止输入。
     *
     * 用法：
     *   let (decoded, remainder) = ChunkedDecoder.feed(currentData, accumulated)
     * // decoded = 此调用新解码的字节
     * // remainder = 尚未消耗的字节（下次作为 `accumulated` 传回）
     *
     * @param currentData  刚从线缆到达的新鲜字节
     * @param accumulated  上次调用未消费的字节（首次调用时传 []）
     * @return (解码输出, 供下次调用的剩余字节)
     */
    public static func feed(currentData: Array<UInt8>, accumulated: Array<UInt8>): (Array<UInt8>, Array<UInt8>) {
        // 使用 ByteBuffer 持有累积数据，避免 O(n²) 数组合并
        let buf = ByteBuffer(accumulated)
        buf.write(currentData)

        let merged = buf.getArray()
        let len = buf.getLimit()

        let decoded = ArrayList<UInt8>()
        var pos: Int64 = 0

        while (pos < len) {
            // 查找分块大小行
            let lineEnd = findCrlfAt(merged, pos, len)
            if (lineEnd < 0) {
                // 不完整的大小行 —— 需要更多数据
                // 将剩余字节紧凑到缓冲区前端
                buf.clear()
                if (pos < len) {
                    let remaining = len - pos
                    var ri: Int64 = 0
                    while (ri < remaining) { merged[ri] = merged[pos + ri]; ri++ }
                    buf.advanceWrite(remaining)
                }
                return (decoded.toArray(), if (buf.getLimit() > 0) { buf.toArray() } else { [] })
            }

            let semicolon = findByteAt(merged, pos, lineEnd, b';')
            let sizeEnd = if (semicolon >= 0) { semicolon } else { lineEnd }
            let chunkSize = parseHexSize(merged, pos, sizeEnd)
            pos = lineEnd + 2  // 跳过 \r\n

            if (chunkSize == 0) {
                // 最后一个分块 —— 消费尾部字段直到空 

                let trailerStart = pos
                while (pos + 1 < len) {
                    // 防止畸形输入导致无限循环
                    if (pos - trailerStart > MAX_TRAILER_SIZE) {
                        throw ProtocolException("Trailer 段过大")
                    }
                    let trailerEnd = findCrlfAt(merged, pos, len)
                    if (trailerEnd < 0) {
                        // 不完整的尾部字段 —— 需要更多数据
                        buf.clear()
                        if (pos < len) {
                            let remaining = len - pos
                            var ri: Int64 = 0
                            while (ri < remaining) { merged[ri] = merged[pos + ri]; ri++ }
                            buf.advanceWrite(remaining)
                        }
                        return (decoded.toArray(), buf.toArray())
                    }
                    if (trailerEnd == pos) {
                        // 空行 = 尾部字段结束
                        pos = trailerEnd + 2
                        break
                    }
                    pos = trailerEnd + 2
                }
                // 完成 —— 所有数据已消费
                buf.clear()
                return (decoded.toArray(), [])
            }

            // 需要分块数据：chunkSize 字节 + 尾部 

            let needed = chunkSize + 2
            if (pos + needed > len) {
                // 不完整的分块数据 —— 需要更多
                buf.clear()
                if (pos < len) {
                    let remaining = len - pos
                    var ri: Int64 = 0
                    while (ri < remaining) { merged[ri] = merged[pos + ri]; ri++ }
                    buf.advanceWrite(remaining)
                }
                return (decoded.toArray(), buf.toArray())
            }

            var di: Int64 = 0
            while (di < chunkSize) { decoded.add(merged[pos + di]); di++ }
            pos += needed
        }

        buf.clear()
        (decoded.toArray(), [])
    }

    // ---- 内部辅助函数 ----

    private static func tryParseChunkSize(data: Array<UInt8>, len: Int64): Option<Int64> {
        if (len == 0) { return None }
        // 检查是否有完整的分块大小行
        var i: Int64 = 0
        while (i + 1 < len) {
            if (data[i] == b'\r' && data[i + 1] == b'\n') {
                // 找到大小行末尾
                let semicolon = findByteAt(data, 0, i, b';')
                let sizeEnd = if (semicolon >= 0) { semicolon } else { i }
                let size = parseHexSize(data, 0, sizeEnd)
                return Some(size)
            }
            i++
        }
        None  // 需要更多数据
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
            else { throw ProtocolException("invalid hex digit in chunk size") }
            // 乘法前检查溢出 (max hex digits for safe Int64: 14)
            if (value > 0x07ffffffffffffff) {
                throw ProtocolException("chunk size too large (overflow)")
            }
            value = value * 16 + digit
            if (value < 0) {
                throw ProtocolException("chunk size too large (overflow)")
            }
            i++
        }
        value
    }

    private static func findCrlfAt(data: Array<UInt8>, start: Int64, end: Int64): Int64 {
        var i = start
        while (i + 1 < end) {
            if (data[i] == b'\r' && data[i + 1] == b'\n') { return i }
            i++
        }
        -1
    }

    private static func findByteAt(data: Array<UInt8>, start: Int64, end: Int64, target: UInt8): Int64 {
        var i = start
        while (i < end) {
            if (data[i] == target) { return i }
            i++
        }
        -1
    }
}
