package http_lib.buffer

import std.collection.{ArrayDeque, HashMap}
import std.sync.Mutex
import std.overflow.*

/**
 * 可增长的字节缓冲区，用于读写二进制数据.
 *
 * 内部使用预分配的 Array<UInt8> 作为存储，通过 position（当前读写位置）
 * 和 limit（有效数据末尾）两个游标管理缓冲区的读写状态。
 * 支持自动扩容、原地写入和高效读取。
 *
 * ByteBuffer 不是线程安全的；多线程共享需外部同步。
 */
public class ByteBuffer {
    private var data: Array<UInt8>
    private var position: Int64 = 0
    private var limit: Int64 = 0

    public init() {
        this(capacity: 4096)
    }

    public init(capacity!: Int64) {
        let cap = if (capacity > 0) { capacity } else { 0 }
        this.data = Array<UInt8>(cap, repeat: 0)
    }

    public init(data: Array<UInt8>) {
        this.data = data.clone()
        this.position = data.size
        this.limit = data.size
    }

    public static func fromOwned(data: Array<UInt8>): ByteBuffer {
        let buf = ByteBuffer(capacity: 0)
        buf.data = data
        buf.position = data.size
        buf.limit = data.size
        buf
    }

    public func write(bytes: Array<UInt8>): Unit {
        if (bytes.size == 0) { return }
        ensureWritable(bytes.size)
        bytes.copyTo(data, 0, position, bytes.size)
        position += bytes.size
        limit = position
    }

    public func write(bytes: Array<UInt8>, offset: Int64, length: Int64): Unit {
        if (length == 0) { return }
        ensureWritable(length)
        bytes.copyTo(data, offset, position, length)
        position += length
        limit = position
    }

    public func writeByte(b: UInt8): Unit {
        ensureWritable(1)
        data[position] = b
        position++
        limit = position
    }

    public func writeString(s: String): Unit {
        let bytes = unsafe { s.rawData() }
        write(bytes)
    }

    public func readByte(): Option<UInt8> {
        if (position >= limit) { return None }
        let b = data[position]
        position++
        Some(b)
    }

    public func getPosition(): Int64 { position }
    public func getLimit(): Int64 { limit }
    public func remaining(): Int64 { limit - position }

    public func clear(): Unit {
        position = 0
        limit = 0
    }

    public func toString(): String {
        String.fromUtf8(data[0..limit])
    }

    public func getArray(): Array<UInt8> { data }

    public func toArray(): Array<UInt8> {
        if (limit == 0) { return [] }
        let result = Array<UInt8>(limit, repeat: 0)
        data.copyTo(result, 0, 0, limit)
        result
    }

    public func reserveWritable(length: Int64): Int64 {
        if (length < 0) {
            throw Exception("ByteBuffer reserveWritable length out of bounds")
        }
        ensureWritable(length)
        position
    }

    public func advanceWrite(length: Int64): Unit {
        if (length < 0 || position + length > data.size) {
            throw Exception("ByteBuffer advanceWrite length out of bounds")
        }
        position += length
        limit = position
    }

    private func ensureWritable(length: Int64): Unit {
        // 溢出检查：position + length 不能超过 Int64 最大值
        if (length < 0 || position > Int64(0x7fffffffffffffff) - length) {
            throw Exception("ByteBuffer 容量溢出")
        }
        ensureCapacity(position + length)
    }

    private func ensureCapacity(minCapacity: Int64): Unit {
        if (minCapacity <= data.size) { return }
        // 简化版扩容策略：直接 2x 扩容，移除滑动逻辑。
        // 滑动逻辑在顺序写入场景下无法发挥作用反而增加复杂度。
        var newCap = data.size.wrappingMul(2)
        if (newCap < minCapacity) { newCap = minCapacity }
        if (newCap < 256) { newCap = 256 }
        let newData = Array<UInt8>(newCap, repeat: 0)
        data.copyTo(newData, 0, 0, limit)
        data = newData
    }
}

/**
 * 线程安全的 ByteBuffer 实例复用池。
 *
 * 通过回收缓冲区而非分配新缓冲区来减少 GC 压力。
 * 缓冲区按默认容量（4096、8192、16384）分组池化。
 *
 * 适用于高并发 HTTP 解析场景，可显著减少内存分配次数。
 *
 * 用法：
 *   let buf = ByteBufferPool.acquire(4096)
 * // ... 使用 buf ...
 *   ByteBufferPool.release(buf)
 */
public class ByteBufferPool {
    private static var pools: HashMap<Int64, ArrayDeque<ByteBuffer>> = HashMap<Int64, ArrayDeque<ByteBuffer>>()
    private static var mu: Mutex = Mutex()
    private static let MAX_POOL_SIZE: Int64 = 64  // 每个大小类别的最大缓冲区数

    /**
     * 获取至少具有给定容量的 ByteBuffer。
     * 从池中返回回收的缓冲区，如果池为空则返回新的缓冲区。
     */
    public static func acquire(capacity!: Int64 = 4096): ByteBuffer {
        // 向上取整到最近的池大小
        var cap = 4096
        while (cap < capacity) { cap = cap.wrappingMul(2) }
        synchronized(mu) {
            match (pools.get(cap)) {
                case Some(queue) =>
                    if (queue.size > 0) {
                        match (queue.removeFirst()) {
                            case Some(buf) =>
                                buf.clear()
                                return buf
                            case None => ()
                        }
                    }
                case None => ()
            }
        }
        ByteBuffer(capacity: cap)
    }

    /**
     * 将 ByteBuffer 释放回池中以供重用。
     */
    public static func release(buf: ByteBuffer): Unit {
        buf.clear()
        synchronized(mu) {
            let cap = buf.getArray().size
            match (pools.get(cap)) {
                case Some(queue) =>
                    if (queue.size < MAX_POOL_SIZE) {
                        queue.addLast(buf)
                    }
                case None =>
                    let queue = ArrayDeque<ByteBuffer>()
                    queue.addLast(buf)
                    pools[cap] = queue
            }
        }
    }
}
