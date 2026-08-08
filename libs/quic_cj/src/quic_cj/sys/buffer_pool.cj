package quic_cj.sys

import quic_cj.protocol.MAX_PACKET_BUFFER_SIZE

/// UdpBufferPool 是用于 UDP 接收缓冲区的简单池。
/// 这减少高吞吐量包接收期间的分配。
public class UdpBufferPool {
    private let POOL_SIZE: Int64 = 64
    private var pool: Array<Array<Byte>> = Array<Array<Byte>>(POOL_SIZE, repeat: [])
    private var head: Int64 = 0
    private var count: Int64 = 0

    /// 从池中获取缓冲区，或分配一个新的。
    public func get(): Array<Byte> {
        if (count > 0) {
            count -= 1
            let idx = (head - count - 1 + POOL_SIZE) % POOL_SIZE
            let buf = pool[idx]
            pool[idx] = []
            buf
        } else {
            Array<Byte>(MAX_PACKET_BUFFER_SIZE, repeat: 0)
        }
    }

    /// 将缓冲区归还给池。
    public func put(buf: Array<Byte>): Unit {
        if (count < POOL_SIZE) {
            pool[head] = buf
            head = (head + 1) % POOL_SIZE
            count += 1
        }
    }

    /// 返回池中当前的缓冲区数量。
    public func len(): Int64 { count }
}

/// 默认的共享缓冲池实例。
private var globalPool = UdpBufferPool()

/// 返回用于 UDP 接收的缓冲区。
public func getUdpBuffer(): Array<Byte> {
    globalPool.get()
}

/// 将缓冲区归还到共享 UDP 缓冲池。
public func putUdpBuffer(buf: Array<Byte>): Unit {
    globalPool.put(buf)
}
