package http_lib.connection
/**
 * 内存模拟连接（测试用）。
 * 在内存中提供 Connection 接口实现，不涉及真实网络 I/O。
 * 支持读写缓冲区和模拟断开/超时行为。
 */

import std.collection.ArrayList
import std.time.DateTime

/**
 * 内存模拟连接（用于单元测试） server/client I/O logic.
 *
 * 模拟双向字节流 where:
 *   - read() 从内部读取缓冲区消费数据（服务器接收客户端数据）
 *   - write() 追加到内部写入缓冲区（服务器发送响应）
 *
 * This enables testing all 请求解析, response serialization, Keep-Alive
 * handling, and 连接管理 WITHOUT real TCP sockets.
 *
 * ResponseRecorder 测试响应记录器，捕获
 * 写入数据，并由模拟连接提供读取数据。
 */
public class MockConnection <: Connection {
    // 可读取的数据块列表（模拟对端发送的数据）
    private var readChunks: ArrayList<Array<UInt8>>
    private var readPos: Int64 = 0
    private var totalReadable: Int64 = 0
    // 已写入的数据（捕获发送到客户端的数据）
    private var writtenData: ArrayList<Array<UInt8>>
    // 连接状态
    private var isOpen: Bool = true
    private var isReusable: Bool = true
    private var connTime: DateTime = DateTime.now()
    private var lastActive: DateTime = DateTime.now()
    // 超时模拟
    private var readTimeoutVal: Duration = Duration.second * 30
    private var writeTimeoutVal: Duration = Duration.second * 30
    // 模拟连接关闭（数据消耗完毕后读取返回 0）
    private var closeAfterRead: Bool = false

    public init(readData: Array<UInt8>) {
        this.readChunks = ArrayList<Array<UInt8>>()
        if (readData.size > 0) {
            this.readChunks.add(readData)
            this.totalReadable = readData.size
        }
        this.writtenData = ArrayList<Array<UInt8>>()
    }

    /**
     * 提供额外数据以供读取（模拟更多数据到达线路）。
     */
    public func feedData(data: Array<UInt8>): Unit {
        readChunks.add(data)
        totalReadable += data.size
    }

    /**
     * 获取写入此连接的所有数据。
     */
    public func getWrittenBytes(): Array<UInt8> {
        var total: Int64 = 0
        for (chunk in writtenData) { total += chunk.size }
        let result = Array<UInt8>(total, repeat: 0)
        var offset: Int64 = 0
        for (chunk in writtenData) {
            var i: Int64 = 0
            while (i < chunk.size) { result[offset + i] = chunk[i]; i += 1 }
            offset += chunk.size
        }
        result
    }

    /**
     * 以字符串形式获取写入的数据。
     */
    public func getWrittenString(): String {
        let bytes = getWrittenBytes()
        if (bytes.size == 0) { return "" }
        unsafe { String.withRawData(bytes) }
    }

    /**
     * 获取写入调用次数。
     */
    public func getWriteCount(): Int64 { writtenData.size }

    /**
     * 模拟连接关闭。
     */
    public func simulateClose(): Unit {
        isOpen = false
        closeAfterRead = true
    }

    // ---- 连接接口 ----

    public func isConnected(): Bool { isOpen }

    public func canReuseTransport(): Bool { isOpen && isReusable && !closeAfterRead }

    public func isReadable(timeout: ?Duration): Bool { isOpen && !closeAfterRead }

    public func isWritable(timeout: ?Duration): Bool { isOpen }

    public func read(buf: Array<UInt8>): Int64 {
        return read(buf, 0, buf.size)
    }

    public func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        updateActivity()
        if (!isOpen) { return -1 }
        if (closeAfterRead) {
            isOpen = false
            return 0
        }
        let available = totalReadable - readPos
        if (available <= 0) { return 0 }
        let toRead = if (available < length) { available } else { length }

        // 从数据块列表中逐块拷贝
        var remaining = toRead
        var bufOff = offset
        var chunkIdx: Int64 = 0
        var skipBytes = readPos
        // 跳过已读取的数据块
        while (chunkIdx < readChunks.size && skipBytes >= readChunks[chunkIdx].size) {
            skipBytes -= readChunks[chunkIdx].size
            chunkIdx += 1
        }
        // 从当前数据块开始拷贝
        while (chunkIdx < readChunks.size && remaining > 0) {
            let chunk = readChunks[chunkIdx]
            let chunkOff = skipBytes
            let chunkAvail = chunk.size - chunkOff
            let copyLen = if (chunkAvail < remaining) { chunkAvail } else { remaining }
            var i: Int64 = 0
            while (i < copyLen) { buf[bufOff + i] = chunk[chunkOff + i]; i += 1 }
            bufOff += copyLen
            remaining -= copyLen
            skipBytes = 0
            chunkIdx += 1
        }
        readPos += toRead
        toRead
    }

    public func write(data: Array<UInt8>): Unit {
        updateActivity()
        if (!isOpen) { return }
        writtenData.add(data.clone())
    }

    public func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit {
        updateActivity()
        if (!isOpen) { return }
        let chunk = Array<UInt8>(length, repeat: 0)
        var i: Int64 = 0
        while (i < length) { chunk[i] = data[offset + i]; i += 1 }
        writtenData.add(chunk)
    }

    public func flush(): Unit { /* 内存模拟无操作 */ }

    public func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit {
        if (buffers.size == 1) { write(buffers[0]) }
        else { let combined = concatBuffers(buffers); if (combined.size > 0) { write(combined) } }
    }

    public func close(): Unit { isOpen = false }

    public func isClosed(): Bool { !isOpen }

    public func localAddress(): String { "127.0.0.1:0" }

    public func remoteAddress(): String { "127.0.0.1:0" }

    public func connectedAt(): DateTime { connTime }

    public func lastActivityAt(): DateTime { lastActive }

    public func updateActivity(): Unit { lastActive = DateTime.now() }

    public func setReadTimeout(timeout: Duration): Unit { readTimeoutVal = timeout }

    public func setWriteTimeout(timeout: Duration): Unit { writeTimeoutVal = timeout }

    public func setTimeout(timeout: Duration): Unit {
        readTimeoutVal = timeout
        writeTimeoutVal = timeout
    }

    public func connectionState(): ?ConnectionState { None }
}

/**
 * 构建一个最小 HTTP/1.1 GET 请求字节。
 * "GET <path> HTTP/1.1\r\nHost: localhost\r\n\r\n"
 */
public func buildRawGetRequest(path: String): Array<UInt8> {
    let request = "GET ${path} HTTP/1.1\r\nHost: localhost\r\n\r\n"
    unsafe { request.rawData() }
}

/**
 * 构建一个带 Content-Length 和主体的最小 HTTP/1.1 POST 请求。
 */
public func buildRawPostRequest(path: String, body: Array<UInt8>): Array<UInt8> {
    let header = "POST ${path} HTTP/1.1\r\nHost: localhost\r\nContent-Length: ${body.size}\r\n\r\n"
    let headerBytes = unsafe { header.rawData() }
    let total = headerBytes.size + body.size
    let result = Array<UInt8>(total, repeat: 0)
    var i: Int64 = 0
    while (i < headerBytes.size) { result[i] = headerBytes[i]; i += 1 }
    while (i < total) { result[i] = body[i - headerBytes.size]; i += 1 }
    result
}
