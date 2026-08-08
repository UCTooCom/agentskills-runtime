package quic_cj.core

import channel_cj.Chan
import quic_cj.protocol.ECN
import quic_cj.wire.PacketBuffer
import quic_cj.sys.RawConn

/// SendQueueEntry 保存包缓冲区及其元数据。
internal class SendQueueEntry {
    public var buf: PacketBuffer = PacketBuffer(0)
    public var gsoSize: UInt16 = 0u16
    public var ecn: ECN = ECN.Unsupported

    public init(buf: PacketBuffer, gsoSize: UInt16, ecn: ECN) {
        this.buf = buf
        this.gsoSize = gsoSize
        this.ecn = ecn
    }
}

/// SendQueue 是连接与传输层之间的包发送缓冲区。
/// 使用有界通道进行缓冲，支持批量刷新到套接字。
/// 容量为 8（与 quic-go 相同），后进先刷新。
public class SendQueue {
    private var queue: Chan<SendQueueEntry>
    private var capacity: Int64 = 8
    private var closed: Bool = false

    public init() {
        queue = Chan<SendQueueEntry>(capacity)
    }

    /// 向队列添加一个包。如果队列满则返回 false（调用者应稍后重试）。
    public func send(buf: PacketBuffer, gsoSize: UInt16, ecn: ECN): Bool {
        let entry = SendQueueEntry(buf, gsoSize, ecn)
        return queue.trySend(entry)
    }

    /// 如果队列已满（容量为 8），返回 true。
    public func wouldBlock(): Bool {
        queue.len() >= capacity
    }

    /// 返回当前队列中的包数。
    public func len(): Int64 { queue.len() }

    /// 将队列中的所有包写入提供的 RawConn。
    /// 返回已发送的字节数。
    public func flush(conn: RawConn, addr: String): Int64 {
        var totalSent: Int64 = 0
        while (true) {
            let r = queue.tryRecv()
            if (let Some(entry) <- r) {
                let n = conn.writePacket(entry.buf.data, addr, entry.ecn)
                entry.buf.release()
                if (n > 0) { totalSent += n }
            } else {
                break
            }
        }
        totalSent
    }

    /// 当队列有空位时，通过 trySend 检查可用性。
    /// 返回 true 表示有空间。
    public func available(): Bool {
        queue.len() < capacity
    }

    /// 绕过包队列直接发送探测包。
    public func sendProbe(data: Array<Byte>, conn: RawConn, addr: String): Int64 {
        conn.writePacket(data, addr, ECN.Unsupported)
    }

    /// 关闭发送队列。清空缓冲区。
    public func close(): Unit {
        if (!closed) {
            closed = true
            // 排空队列
            while (true) {
                let r = queue.tryRecv()
                if (let Some(entry) <- r) {
                    entry.buf.release()
                } else {
                    break
                }
            }
        }
    }

    public func isClosed(): Bool { closed }
}

/// 创建新的 SendQueue。
public func newSendQueue(): SendQueue { SendQueue() }
