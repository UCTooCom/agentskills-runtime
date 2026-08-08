package quic_cj.wire

import quic_cj.protocol.MAX_PACKET_BUFFER_SIZE

/// PacketBuffer 是用于包 I/O 的引用计数字节缓冲区。
public class PacketBuffer {
    public var data: Array<Byte> = []
    internal var refCount: Int64 = 1

    public init(capacity: Int64) {
        this.data = Array<Byte>(capacity, repeat: 0)
    }

    /// 增加 refCount 以支持共享使用（例如合并包）。
    public func split(): Unit {
        refCount += 1
    }

    /// 减少 refCount 但不回收。
    public func decrement(): Unit {
        refCount -= 1
        if (refCount < 0) {
            refCount = 0
        }
    }

    /// 将 refCount 设置为 1，以便从池中重用。
    public func resetRefCount(): Unit {
        refCount = 1
    }

    /// 如果 refCount 达到 0，将缓冲区放回池中。
    public func maybeRelease(): Unit {
        if (refCount == 0) {
            putBack()
        }
    }

    /// 将缓冲区释放回池中。
    public func release(): Unit {
        decrement()
        putBack()
    }

    public func len(): Int64 { data.size }
    public func cap(): Int64 { data.size }
    public func getRefCount(): Int64 { refCount }

    private func putBack(): Unit {
        let c = data.size
        if (c == MAX_PACKET_BUFFER_SIZE) {
            bufferPoolPut(this)
        } else if (c == 20 * 1024) {
            largeBufferPoolPut(this)
        }
    }
}

// ── 包缓冲池 ──

private let NORMAL_POOL_SIZE: Int64 = 64
private let LARGE_POOL_SIZE: Int64 = 16

private var normalPool: Array<PacketBuffer> = Array<PacketBuffer>(NORMAL_POOL_SIZE, repeat: PacketBuffer(MAX_PACKET_BUFFER_SIZE))
private var normalHead: Int64 = 0
private var normalCount: Int64 = 0

private var largePool: Array<PacketBuffer> = Array<PacketBuffer>(LARGE_POOL_SIZE, repeat: PacketBuffer(20 * 1024))
private var largeHead: Int64 = 0
private var largeCount: Int64 = 0

/// 获取适用于普通包大小的包缓冲区。
public func getPacketBuffer(): PacketBuffer {
    if (normalCount > 0) {
        normalCount -= 1
        let idx = (normalHead - normalCount - 1 + NORMAL_POOL_SIZE) % NORMAL_POOL_SIZE
        let buf = normalPool[idx]
        buf.data = []
        buf.resetRefCount()
        normalPool[idx] = PacketBuffer(MAX_PACKET_BUFFER_SIZE)
        buf
    } else {
        let buf = PacketBuffer(MAX_PACKET_BUFFER_SIZE)
        buf.resetRefCount()
        buf.data = []
        buf
    }
}

/// 获取适用于巨型报文的包缓冲区。
public func getLargePacketBuffer(): PacketBuffer {
    if (largeCount > 0) {
        largeCount -= 1
        let idx = (largeHead - largeCount - 1 + LARGE_POOL_SIZE) % LARGE_POOL_SIZE
        let buf = largePool[idx]
        buf.data = []
        buf.resetRefCount()
        largePool[idx] = PacketBuffer(20 * 1024)
        buf
    } else {
        let buf = PacketBuffer(20 * 1024)
        buf.resetRefCount()
        buf.data = []
        buf
    }
}

private func bufferPoolPut(buf: PacketBuffer): Unit {
    if (normalCount < NORMAL_POOL_SIZE) {
        normalPool[normalHead] = buf
        normalHead = (normalHead + 1) % NORMAL_POOL_SIZE
        normalCount += 1
    }
}

private func largeBufferPoolPut(buf: PacketBuffer): Unit {
    if (largeCount < LARGE_POOL_SIZE) {
        largePool[largeHead] = buf
        largeHead = (largeHead + 1) % LARGE_POOL_SIZE
        largeCount += 1
    }
}

/// StreamFrame 缓冲池：用于 StreamFrame 数据数组的简单池。
private let STREAM_BUF_POOL_SIZE: Int64 = 128
private var streamBufPool: Array<Array<Byte>> = Array<Array<Byte>>(STREAM_BUF_POOL_SIZE, repeat: [])
private var streamBufHead: Int64 = 0
private var streamBufCount: Int64 = 0

public func getStreamBuf(capacity: Int64): Array<Byte> {
    if (streamBufCount > 0) {
        streamBufCount -= 1
        let idx = (streamBufHead - streamBufCount - 1 + STREAM_BUF_POOL_SIZE) % STREAM_BUF_POOL_SIZE
        let buf = streamBufPool[idx]
        streamBufPool[idx] = []
        buf
    } else {
        Array<Byte>(capacity, repeat: 0)
    }
}

public func putStreamBuf(buf: Array<Byte>): Unit {
    if (streamBufCount < STREAM_BUF_POOL_SIZE) {
        streamBufPool[streamBufHead] = buf
        streamBufHead = (streamBufHead + 1) % STREAM_BUF_POOL_SIZE
        streamBufCount += 1
    }
}
