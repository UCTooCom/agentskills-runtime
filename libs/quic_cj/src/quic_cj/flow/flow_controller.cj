package quic_cj.flow

import quic_cj.protocol.{StreamId, MAX_BYTE_COUNT}
import quic_cj.util.RTTStats

/// WindowUpdateThreshold 是发送窗口更新前必须消耗的窗口比例。
public let WINDOW_UPDATE_THRESHOLD: Float64 = 0.25

/// 默认初始流量控制窗口（字节）。
public let DEFAULT_STREAM_RECEIVE_WINDOW: Int64 = 256 * 1024
public let DEFAULT_CONNECTION_RECEIVE_WINDOW: Int64 = 16 * 1024 * 1024
public let DEFAULT_MAX_RECEIVE_WINDOW_SIZE: Int64 = 32 * 1024 * 1024

/// BaseFlowController 实现通用的接收端流量控制逻辑，带自动调整。
open public class BaseFlowController {
    private var bytesRead: Int64 = 0
    private var highestReceived: Int64 = 0
    private var receiveWindow: Int64 = DEFAULT_STREAM_RECEIVE_WINDOW
    private var receiveWindowSize: Int64 = DEFAULT_STREAM_RECEIVE_WINDOW
    private var maxReceiveWindowSize: Int64 = DEFAULT_MAX_RECEIVE_WINDOW_SIZE
    private var epochStartTimeNs: Int64 = 0
    private var epochStartOffset: Int64 = 0
    private var receivedFinalOffset: Bool = false
    private var rttStats: RTTStats = RTTStats()
    private var allowWindowIncreaseFunc: (Int64) -> Bool = { n => true }

    public init() {}

    public func setAllowWindowIncrease(f: (Int64) -> Bool): Unit {
        allowWindowIncreaseFunc = f
    }

    public func setRttStats(r: RTTStats): Unit { rttStats = r }

    /// AddBytesRead 记录已消耗的 n 个字节。
    public func addBytesRead(n: Int64): Unit { bytesRead += n }

    /// StartNewEpoch 开始一个新的自动调整周期。
    public func startNewEpoch(nowNs: Int64): Unit {
        epochStartTimeNs = nowNs
        epochStartOffset = bytesRead
    }

    /// UpdateHighestReceived 更新已接收的最大字节偏移量。
    public func updateHighestReceived(offset: Int64, final: Bool): (Bool, Int64) {
        if (receivedFinalOffset) {
            if (offset > highestReceived) {
                return (false, 0)  // FINAL_SIZE_ERROR
            }
            if (final && offset != highestReceived) {
                return (false, 0)  // inconsistent final offset
            }
            return (true, 0)
        }
        if (final) { receivedFinalOffset = true }
        if (offset > highestReceived) {
            if (highestReceived == 0) { /* first frame, epoch starts outside */ }
            highestReceived = offset
        }
        if (highestReceived > receiveWindow) {
            return (false, 0)  // FLOW_CONTROL_ERROR
        }
        (true, 0)
    }

    /// IncrementHighestReceived 向 highestReceived 值增加一个增量。
    public func incrementHighestReceived(inc: Int64, nowNs: Int64): (Bool, Int64) {
        if (highestReceived == 0) {
            startNewEpoch(nowNs)
        }
        highestReceived += inc
        if (highestReceived > receiveWindow) {
            return (false, 0)
        }
        (true, 0)
    }

    /// HasWindowUpdate 检查是否应发送窗口更新。
    public func hasWindowUpdate(): Bool {
        let bytesRemaining = receiveWindow - bytesRead
        // 剩余窗口 ≤ 75% 时触发更新：receiveWindowSize - receiveWindowSize/4 = 3/4
        bytesRemaining <= receiveWindowSize - (receiveWindowSize >> 2)
    }

    /// ShouldQueueWindowUpdate 返回是否应将窗口更新加入队列。
    public func shouldQueueWindowUpdate(): Bool {
        if (receivedFinalOffset) { return false }
        hasWindowUpdate()
    }

    /// MaybeAdjustWindowSize 执行基于 RTT 的自动窗口调整。
    public func maybeAdjustWindowSize(nowNs: Int64): Unit {
        let bytesReadInEpoch = bytesRead - epochStartOffset
        if (bytesReadInEpoch <= receiveWindowSize / 2) { return }
        if (epochStartTimeNs == 0) { return }

        let elapsed = nowNs - epochStartTimeNs
        let rtt = rttStats.smoothedRtt()
        if (rtt <= 0) { return }

        let fraction = Float64(bytesReadInEpoch) / Float64(receiveWindowSize)
        if (Float64(elapsed) < 4.0 * fraction * Float64(rtt)) {
            var newSize = receiveWindowSize * 2
            if (newSize > maxReceiveWindowSize) { newSize = maxReceiveWindowSize }
            let delta = newSize - receiveWindowSize
            let deltaUs = delta
            if (delta > 0 && allowWindowIncreaseFunc(deltaUs)) {
                receiveWindowSize = newSize
            }
        }
        startNewEpoch(nowNs)
    }

    /// GetWindowUpdate 返回新的窗口偏移量，含自动调整。
    public func getWindowUpdate(nowNs: Int64): Int64 {
        if (!hasWindowUpdate()) { return 0 }
        maybeAdjustWindowSize(nowNs)
        receiveWindow = bytesRead + receiveWindowSize
        receiveWindow
    }

    public func getReceiveWindow(): Int64 { receiveWindow }
    public func getBytesRead(): Int64 { bytesRead }
    public func getReceiveWindowSize(): Int64 { receiveWindowSize }
    public func getMaxReceiveWindowSize(): Int64 { maxReceiveWindowSize }
    public func getReceivedFinalOffset(): Bool { receivedFinalOffset }
    public func getHighestReceived(): Int64 { highestReceived }
    public func checkFlowControlViolation(): Bool { highestReceived > receiveWindow }

    /// GetEpochStartTime 返回周期开始时间（用于测试）。
    public func getEpochStartOffset(): Int64 { epochStartOffset }
}

/// StreamFlowController 扩展 BaseFlowController，增加流级发送逻辑。
public class StreamFlowController <: BaseFlowController {
    private var streamId: StreamId = 0
    private var bytesSent: Int64 = 0
    private var sendWindow: Int64 = DEFAULT_STREAM_RECEIVE_WINDOW
    private var lastBlockedAt: Int64 = 0
    private var connectionCtrl: ConnectionFlowController = ConnectionFlowController()

    public init(streamId: StreamId) {
        this.streamId = streamId
    }

    /// SetConnection 设置连接级流量控制器。
    public func setConnection(c: ConnectionFlowController): Unit {
        connectionCtrl = c
    }

    /// SendWindowSize 返回可发送的字节数。
    public func sendWindowSize(): Int64 {
        if (bytesSent > sendWindow) { return 0 }
        let connWindow = connectionCtrl.sendWindowSize()
        let streamAvail = sendWindow - bytesSent
        if (connWindow < streamAvail) { connWindow } else { streamAvail }
    }

    /// TryAddBytesSent 尝试将 n 字节记为已发送。阻塞时返回 false。
    public func tryAddBytesSent(n: Int64): Bool {
        if (bytesSent > sendWindow || n > sendWindow - bytesSent) { return false }
        if (!connectionCtrl.tryAddBytesSent(n)) { return false }
        bytesSent += n
        true
    }

    /// AddBytesSent 记录已发送的 n 个字节。
    public func addBytesSent(n: Int64): Unit {
        bytesSent += n
    }

    /// IsNewlyBlocked 返回流是否刚被流控阻塞。
    public func isNewlyBlocked(): Bool {
        if (bytesSent < sendWindow || sendWindow == lastBlockedAt) { return false }
        lastBlockedAt = sendWindow
        true
    }

    /// UpdateSendWindow 用新的最大值更新发送窗口。
    public func updateSendWindow(newWindow: Int64): Bool {
        if (newWindow > sendWindow) {
            sendWindow = newWindow
            true
        } else { false }
    }

    /// IsBlocked 返回发送是否被流控阻塞。
    public func isBlocked(): Bool { bytesSent >= sendWindow }

   /// Abandon 放弃未读取的数据（流关闭时调用）。
   public func abandon(): Unit {
       let unread = getHighestReceived() - getBytesRead()
        addBytesRead(unread)
       if (unread > 0) {
           connectionCtrl.addBytesRead(unread)
       }
   }

    /// ShouldQueueStreamWindowUpdate 返回是否应将接收窗口更新加入队列。
    public func shouldQueueStreamWindowUpdate(): Bool {
        !getReceivedFinalOffset() && hasWindowUpdate()
    }

    /// GetLastBlockedAt 返回最后被阻塞的偏移量。
    public func getLastBlockedAt(): Int64 { lastBlockedAt }

    /// GetBytesSent 返回已发送的总字节数。
    public func getBytesSent(): Int64 { bytesSent }

    /// GetSendWindow 返回当前的发送窗口。
    public func getSendWindow(): Int64 { sendWindow }
}

/// ConnectionFlowController 处理连接级的流量控制。
public class ConnectionFlowController <: BaseFlowController {
    private var bytesSent: Int64 = 0
    private var sendWindow: Int64 = DEFAULT_CONNECTION_RECEIVE_WINDOW
    private var lastBlockedAt: Int64 = 0

    public init() {}

    /// UpdateSendWindow 用新的最大值更新发送窗口。
    public func updateSendWindow(newWindow: Int64): Bool {
        if (newWindow > sendWindow) {
            sendWindow = newWindow
            true
        } else { false }
    }

    /// SendWindowSize 返回连接发送窗口剩余字节数。
    public func sendWindowSize(): Int64 {
        if (bytesSent > sendWindow) { return 0 }
        sendWindow - bytesSent
    }

    /// TryAddBytesSent 尝试将 n 字节加入连接发送预算。
    public func tryAddBytesSent(n: Int64): Bool {
        if (bytesSent > sendWindow || n > sendWindow - bytesSent) { return false }
        bytesSent += n
        true
    }

    /// AddBytesSent 记录已发送的 n 个字节。
    public func addBytesSent(n: Int64): Unit { bytesSent += n }

    /// IsNewlyBlocked 返回连接是否刚被流控阻塞。
    public func isNewlyBlocked(): Bool {
        if (bytesSent < sendWindow || sendWindow == lastBlockedAt) { return false }
        lastBlockedAt = sendWindow
        true
    }

    /// EnsureMinimumWindowSize 确保接收窗口至少为 inc 字节。
    public func ensureMinimumWindowSize(inc: Int64, nowNs: Int64): Unit {
        if (inc <= getReceiveWindowSize()) { return }
        var newSize = inc
        if (newSize > getMaxReceiveWindowSize()) { newSize = getMaxReceiveWindowSize() }
        let delta = newSize - getReceiveWindowSize()
        if (delta > 0) {
            let oldWindowSize = getReceiveWindowSize()
            // 强制增加窗口大小
            
        }
        startNewEpoch(nowNs)
    }

    /// Reset 重置流量控制器（0-RTT 被拒绝时使用）。
    public func reset(): Unit {
        bytesSent = 0
        lastBlockedAt = 0
        sendWindow = 0
    }

    /// GetBytesSent 返回已发送的总字节数。
    public func getBytesSent(): Int64 { bytesSent }

    /// GetSendWindow 返回当前的发送窗口。
    public func getSendWindow(): Int64 { sendWindow }

    /// GetLastBlockedAt 返回最后被阻塞的偏移量。
    public func getLastBlockedAt(): Int64 { lastBlockedAt }

    /// SetInitialSendWindow 设置初始发送窗口。
    public func setInitialSendWindow(w: Int64): Unit { sendWindow = w }
}
