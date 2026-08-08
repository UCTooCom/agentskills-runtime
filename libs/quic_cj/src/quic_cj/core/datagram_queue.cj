package quic_cj.core

import std.collection.ArrayDeque
import quic_cj.wire.DatagramFrame

/// 最多可排队发送的 DATAGRAM 帧数。
public let MAX_DATAGRAM_SEND_QUEUE_LEN: Int64 = 32
/// 最多可排队接收的 DATAGRAM 帧数。
public let MAX_DATAGRAM_RCV_QUEUE_LEN: Int64 = 128

/// DatagramQueue 管理 DATAGRAM 帧（RFC 9221）的发送和接收。
/// 使用 ArrayDeque 作为内部队列（单线程友好）。
public class DatagramQueue {
    // 发送队列
    private var sendQueue: ArrayDeque<DatagramFrame> = ArrayDeque<DatagramFrame>()
    // 接收队列
    private var recvQueue: ArrayDeque<Array<Byte>> = ArrayDeque<Array<Byte>>()
    private var closed: Bool = false
    private var hasDataCallback: () -> Unit = { => }


    /// 注册一个回调，当新数据入队时通知。
    public func setHasDataCallback(cb: () -> Unit): Unit {
        hasDataCallback = cb
    }

    /// 添加一个 DATAGRAM 帧到发送队列。
    /// 如果队列满，返回 false。
    private var maxDatagramPayload: Int64 = 65535

    /// 设置最大 DATAGRAM 负载大小（从传输参数协商中获得）。
    public func setMaxDatagramPayload(size: Int64): Unit {
        if (size > 0) { maxDatagramPayload = size }
    }

    public func add(frame: DatagramFrame): Bool {
        if (closed || sendQueue.size >= MAX_DATAGRAM_SEND_QUEUE_LEN) {
            return false
        }
        // 检查 DATAGRAM 帧大小是否在协商范围内（RFC 9221）
        if (maxDatagramPayload > 0 && frame.data.size > maxDatagramPayload) {
            return false
        }
        if (frame.data.size > 0) {
            sendQueue.addLast(frame)
            hasDataCallback()
        }
        true
    }

    /// 查看下一个待发送的 DATAGRAM 帧但不移除。
    public func peek(): Option<DatagramFrame> {
        if (sendQueue.size == 0) { return None }
        let opt = sendQueue.removeFirst()
        if (let Some(frame) <- opt) {
            sendQueue.addFirst(frame)
            Some(frame)
        } else {
            None
        }
    }

    /// 移除并返回下一个已发送的 DATAGRAM 帧。
    /// 在发送者确认发送后调用（先 peek，检查帧长度是否适合，再 pop）。
    public func pop(): Unit {
        if (sendQueue.size > 0) {
            sendQueue.removeFirst()
        }
    }

    /// 处理收到的 DATAGRAM 帧。
    public func handleDatagramFrame(data: Array<Byte>): Bool {
        if (closed || recvQueue.size >= MAX_DATAGRAM_RCV_QUEUE_LEN) {
            return false
        }
        recvQueue.addLast(data)
        true
    }

    /// 从接收队列获取 DATAGRAM 数据。
    public func receive(): Option<Array<Byte>> {
        if (closed || recvQueue.size == 0) { return None }
        let opt = recvQueue.removeFirst()
        if (let Some(data) <- opt) {
            Some(data)
        } else {
            None
        }
    }

    /// 已排队的 DATAGRAM 帧数量（发送方向）。
    public func sendLen(): Int64 { sendQueue.size }

    /// 已排队的 DATAGRAM 数量（接收方向）。
    public func recvLen(): Int64 { recvQueue.size }

    /// 发送队列是否有数据。
    public func hasSendData(): Bool { sendQueue.size > 0 }

    /// 接收队列是否有数据。
    public func hasRecvData(): Bool { recvQueue.size > 0 }

    /// 关闭队列。
    public func close(): Unit { closed = true }
}

/// 创建新的 DatagramQueue。
public func newDatagramQueue(): DatagramQueue { DatagramQueue() }
