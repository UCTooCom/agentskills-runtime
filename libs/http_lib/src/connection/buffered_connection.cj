package http_lib.connection

import std.collection.ArrayList
import std.time.DateTime

/**
 * 缓冲连接包装器（内部写入缓冲区）
 * 合并小写入以减少系统调用，提高吞吐量。
 *

 *
 * 小写入（头部、短主体）在缓冲区中累积，
 * 在显式 flush() 或缓冲区达到容量时
 * 刷新到底层连接。close() 自动刷新。
 *
 * 用法：
 *   let raw = TcpConnection.connect("localhost", 8080)
 *   let conn = BufferedConnection(raw, bufferSize: 8192)
 *   conn.write(headers)
 *   conn.write(smallBody)
 *   conn.flush()  // 发送累积的数据
 */
public class BufferedConnection <: AbstractConnection {
    private let inner: Connection
    private var writeBuf: Array<UInt8>
    private var writePos: Int64 = 0

    public init(inner: Connection, bufferSize!: Int64 = 8192) {
        this.inner = inner
        this.writeBuf = Array<UInt8>(bufferSize, repeat: 0)
        this.connected = inner.isConnected()
        this.lastActivity = inner.lastActivityAt()
        this.connectedTime = inner.connectedAt()
    }

    public func isReadable(timeout: ?Duration): Bool { inner.isReadable(timeout) }
    public func isWritable(timeout: ?Duration): Bool { inner.isWritable(timeout) }

    public func read(buf: Array<UInt8>): Int64 {
        flush()
        let n = inner.read(buf)
        updateActivity()
        n
    }

    public func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        flush()
        let n = inner.read(buf, offset, length)
        updateActivity()
        n
    }

    /**
     * 缓冲一次写入。如果数据大于剩余缓冲区
     * 容量，先刷新现有缓冲区数据，然后写入大数据
     * 如果超出缓冲区大小则直接写入。
     */
    public func write(data: Array<UInt8>): Unit {
        updateActivity()
        if (data.size == 0) { return }
        let remaining = writeBuf.size - writePos
        if (data.size <= remaining) {
            var i: Int64 = 0
            while (i < data.size) { writeBuf[writePos + i] = data[i]; i += 1 }
            writePos += data.size
        } else if (data.size >= writeBuf.size) {
            flush()
            inner.write(data)
        } else {
            flush()
            var i: Int64 = 0
            while (i < data.size) { writeBuf[i] = data[i]; i += 1 }
            writePos = data.size
        }
    }

    public func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit {
        updateActivity()
        if (length <= 0) { return }
        if (offset == 0 && length == data.size) { write(data); return }
        let temp = Array<UInt8>(length, repeat: 0)
        var i: Int64 = 0
        while (i < length) { temp[i] = data[offset + i]; i += 1 }
        write(temp)
    }

    /**
     * 将缓冲的写入刷新到底层连接。
     */
    public func flush(): Unit {
        if (writePos > 0) {
            inner.write(writeBuf[0..writePos])
            writePos = 0
        }
        inner.flush()
    }

    public func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit {
        flush()
        if (buffers.size == 1) { inner.write(buffers[0]) }
        else { let combined = concatBuffers(buffers); if (combined.size > 0) { inner.write(combined) } }
    }

    /**
     * Close 刷新待写入数据并关闭底层连接。
     */
    public func close(): Unit {
        try { flush() } catch (_: Exception) {}
        inner.close()
        connected = false
    }

    public func isClosed(): Bool { !connected }
}
