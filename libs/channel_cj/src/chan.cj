package channel_cj

import std.sync.Mutex
import std.sync.Condition
import std.collection.ArrayDeque

/**
 * 内部辅助类：封装一个待发送的值，当接收者取走值时通知阻塞的发送者
 */
class PendingSend<T> {
    let value: T
    var taken: Bool = false

    public init(value: T) {
        this.value = value
    }
}

/**
 * Chan 是一个受 Go 语言 channel 启发的并发队列，支持：
 *   - 无缓冲（同步握手）和有缓冲（容量 > 0）两种模式
 *   - 阻塞发送 / 接收
 *   - 非阻塞 trySend / tryRecv
 *   - 关闭通道并耗尽剩余数据
 *   - forEach 遍历
 *
 * 线程安全性通过单个 Mutex 保证；阻塞的发送者和接收者使用 Condition
 * 实现等待/唤醒，不存在忙等。
 *
 * 不变约束：
 *  - 同一时刻最多只有 sendQueue 和 recvWaiterCount 中的一个大于 0
 *  - 有缓冲通道：buf.size > 0 时 sendQueue 为空
 *  - 有缓冲通道：buf.size < capacity 时 recvWaiterCount == 0
 */
public class Chan<T> {
    /* ─── 缓冲区（仅在 capacity > 0 时有意义） ─── */
    let capacity: Int64
    var buf = ArrayDeque<T>()

    /* ─── 待发送队列（来自阻塞发送者的值） ─── */
    var sendQueue = ArrayDeque<PendingSend<T>>()
    var sendWaiterCount: Int64 = 0
    var recvWaiterCount: Int64 = 0

    /* ─── 通道状态 ─── */
    var closed: Bool = false

    /* ─── 同步原语 ─── */
    let mutex = Mutex()
    var sendCond: Condition
    var recvCond: Condition

    /* ─── 构造函数 ─── */

    public init() {
        this.capacity = 0
        synchronized(mutex) {
            this.sendCond = mutex.condition()
            this.recvCond = mutex.condition()
        }
    }

    public init(capacity: Int64) {
        this.capacity = if (capacity < 0) { 0 } else { capacity }
        synchronized(mutex) {
            this.sendCond = mutex.condition()
            this.recvCond = mutex.condition()
        }
    }

    /* ─── 辅助方法 ─── */
    func dequeuePending(): PendingSend<T> {
        return sendQueue.removeFirst().getOrThrow()
    }

    func dequeueBufValue(): T {
        return buf.removeFirst().getOrThrow()
    }

    /* ─── 公开 API ─── */

    /**
     * 发送一个值，阻塞直到可交付。
     * 对于无缓冲通道，阻塞直到有接收者就绪。
     * 对于有缓冲通道，仅在缓冲区满时阻塞。
     * @throws Exception 如果通道已关闭。
     */
    public func send(value: T): Unit {
        synchronized(mutex) {
            if (closed) {
                throw Exception("send on closed channel")
            }

            /* 1. 有缓冲通道优先——入队缓冲区（避免 PendingSend 分配） */
            if (capacity > 0 && buf.size < capacity) {
                buf.addLast(value)
                recvCond.notify()
                return
            }

            /* 2. 如果有接收者等待，直接握手交付 */
            if (recvWaiterCount > 0) {
                let ps = PendingSend(value)
                sendQueue.addLast(ps)
                recvCond.notify()
                return
            }

            /* 3. 阻塞——调用者等待接收者取走值或通道关闭 */
            let ps = PendingSend(value)
            sendQueue.addLast(ps)
            sendWaiterCount++

            sendCond.waitUntil {=> closed || ps.taken}

            sendWaiterCount--
            if (closed && !ps.taken) {
                throw Exception("send on closed channel")
            }
        }
    }

    /**
     * 接收一个值，阻塞直到有值可用。
     * 通道关闭且数据耗尽时返回 None。
     */
    public func recv(): Option<T> {
        synchronized(mutex) {
            /* 1. 优先从阻塞发送者获取值
             *
             * 对于无缓冲通道，直接握手（接收者获取发送者的值）。
             * 对于缓冲区满的有缓冲通道，保持 FIFO：取出缓冲区最旧的值，
             * 将发送者的值放到缓冲区尾部。 */
            if (sendQueue.size > 0) {
                let ps = dequeuePending()
                if (capacity == 0 || buf.size == 0) {
                    /* 无缓冲或缓冲区已空 */
                    ps.taken = true
                    sendCond.notifyAll()
                    return Option<T>.Some(ps.value)
                }
                /* 有缓冲且有数据：交换——接收者取缓冲区头部，
                 * 发送者的值成为缓冲区尾部 */
                let head = dequeueBufValue()
                buf.addLast(ps.value)
                ps.taken = true
                sendCond.notifyAll()
                return Option<T>.Some(head)
            }

            /* 2. 从缓冲区取值 */
            if (buf.size > 0) {
                let v = dequeueBufValue()
                sendCond.notifyAll()
                return Option<T>.Some(v)
            }

            /* 3. 通道已关闭且无数据 → 表示数据结束 */
            if (closed) {
                return Option<T>.None
            }

            /* 4. 阻塞——等待发送者或关闭 */
            recvWaiterCount++
            recvCond.waitUntil {=> closed || sendQueue.size > 0 || buf.size > 0}
            recvWaiterCount--

            if (sendQueue.size > 0) {
                let ps = dequeuePending()
                if (capacity == 0 || buf.size == 0) {
                    ps.taken = true
                    sendCond.notifyAll()
                    return Option<T>.Some(ps.value)
                }
                let head = dequeueBufValue()
                buf.addLast(ps.value)
                ps.taken = true
                sendCond.notifyAll()
                return Option<T>.Some(head)
            }

            if (buf.size > 0) {
                let v = dequeueBufValue()
                sendCond.notifyAll()
                return Option<T>.Some(v)
            }

            return Option<T>.None
        }
    }

    /**
     * 非阻塞发送。
     * @return true 如果发送成功，false 否则。
     */
    public func trySend(value: T): Bool {
        synchronized(mutex) {
            if (closed) {
                return false
            }

            if (recvWaiterCount > 0) {
                let ps = PendingSend(value)
                sendQueue.addLast(ps)
                recvCond.notify()
                return true
            }

            if (capacity > 0 && buf.size < capacity) {
                buf.addLast(value)
                recvCond.notify()
                return true
            }

            return false
        }
    }

    /**
     * 非阻塞接收。
     * @return 如果数据立即可用则返回 Some(value)，否则返回 None。
     */
    public func tryRecv(): Option<T> {
        synchronized(mutex) {
            if (sendQueue.size > 0) {
                let ps = dequeuePending()
                if (capacity == 0 || buf.size == 0) {
                    ps.taken = true
                    sendCond.notifyAll()
                    return Option<T>.Some(ps.value)
                }
                let head = dequeueBufValue()
                buf.addLast(ps.value)
                ps.taken = true
                sendCond.notifyAll()
                return Option<T>.Some(head)
            }

            if (buf.size > 0) {
                let v = dequeueBufValue()
                sendCond.notifyAll()
                return Option<T>.Some(v)
            }

            return Option<T>.None
        }
    }

    /**
     * 关闭通道。
     * 已关闭通道上的发送者会收到异常。
     * 接收者耗尽剩余数据后返回 None。
     * @throws Exception 如果通道已经关闭。
     */
    public func close(): Unit {
        synchronized(mutex) {
            if (closed) {
                throw Exception("close of closed channel")
            }
            closed = true

            /* 丢弃待发送队列中的值——这些值永远不会被投递。
             * 阻塞的发送者看到 closed && !ps.taken 后抛出异常 */
            while (sendQueue.size > 0) {
                sendQueue.removeFirst()
            }

            recvCond.notifyAll()
            sendCond.notifyAll()
        }
    }

    /**
     * 当前缓冲区中的元素数量。
     * （无缓冲通道始终返回 0。）
     */
    public func len(): Int64 {
        synchronized(mutex) {
            return buf.size
        }
    }

    /** 缓冲区的最大容量（无缓冲通道为 0）。 */
    public func cap(): Int64 {
        return capacity
    }

    /** 返回通道是否已关闭。 */
    public func isClosed(): Bool {
        synchronized(mutex) {
            return closed
        }
    }

    /**
     * 遍历通道中的值，直到通道关闭且数据耗尽。
     * @param action 每个接收到的值的回调函数。
     */
    public func forEach(action: (T) -> Unit): Unit {
        while (true) {
            let r = recv()
            if (let Some(v) <- r) {
                action(v)
            } else {
                break
            }
        }
    }
}
