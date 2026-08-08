package quic_cj.stream

import quic_cj.protocol.{StreamId, StreamType, EncryptionLevel, Perspective}
import quic_cj.flow.{StreamFlowController, ConnectionFlowController}
import quic_cj.wire.{Frame, StreamFrame, CryptoFrame, ResetStreamFrame, StopSendingFrame}
import quic_cj.util.{FINAL_SIZE_ERROR, FLOW_CONTROL_ERROR, STREAM_STATE_ERROR}

/// StreamState 表示 QUIC 流的生命周期状态（RFC 9000 §3）。
public enum StreamState {
    | Idle
    | Open
    | HalfClosedLocal
    | HalfClosedRemote
    | Closed
    | ResetSent
    | ResetReceived
}

/// SendStream 处理流的出站数据。
public class SendStream {
    private var data: Array<Byte> = []
    private var offset: Int64 = 0
    private var finSent: Bool = false
    private var maxStreamData: Int64 = 262144
    private var resetSent: Bool = false
    private var stopSendingReceived: Bool = false
    private var stopSendingErrorCode: UInt64 = 0u64

    public func write(data: Array<Byte>): Int64 {
        if (finSent || resetSent) { return 0 }
        // 检查流控
        let available = maxStreamData - offset
        if (available <= 0) { return 0 }
        let writeLen = if (data.size > available) { available } else { data.size }
        this.data = appendBytes(this.data, data[..writeLen])
        offset += writeLen
        writeLen
    }

    public func close(): Unit { finSent = true }
    
    public func reset(): Unit { resetSent = true }
    
    public func getDataForSending(maxLen: Int64): Array<Byte> {
        if (data.size > maxLen) { data[..maxLen] } else { data }
    }
    
    public func dataSent(n: Int64): Unit {
        if (n >= data.size) { data = [] } else { data = data[n..] }
    }
    
    public func isFinSent(): Bool { finSent }
    public func isResetSent(): Bool { resetSent }
    public func getOffset(): Int64 { offset }
    
    /// 更新流发送窗口（MAX_STREAM_DATA 帧处理）。
    public func updateSendWindow(newMax: Int64): Unit {
        if (newMax > maxStreamData) { maxStreamData = newMax }
    }

    /// 处理对端的 STOP_SENDING 帧（RFC 9000 §3.5）。
    public func handleStopSendingFrame(frame: StopSendingFrame): Unit {
        stopSendingReceived = true
        stopSendingErrorCode = frame.errorCode
        // 对端停止读取，应重置发送流
        if (!finSent && !resetSent) {
            resetSent = true
            data = []
        }
    }

    /// 获取对端 STOP_SENDING 中携带的错误码。
    public func getStopSendingErrorCode(): UInt64 { stopSendingErrorCode }
    /// 检查是否收到对端的 STOP_SENDING。
    public func isStopSendingReceived(): Bool { stopSendingReceived }
}

/// ReceiveStream 处理流的入站数据。
public class ReceiveStream {
    private var data: Array<Byte> = []
    private var offset: Int64 = 0
    private var finReceived: Bool = false
    private var resetReceived: Bool = false
    private var finalSize: Int64 = -1
    private var maxStreamData: Int64 = 0
    private var resetErrorCode: UInt64 = 0u64

    public func handleStreamFrame(frame: StreamFrame): Unit {
        if (resetReceived) { return }
        let frameStart = frame.getOffset()
        let frameEnd = frameStart + frame.getData().size
        // 检查 final size 一致性（如果已设置 finalSize）
        if (finalSize >= 0 && frameEnd > finalSize) {
            return  // final size 违规，应通知上层
        }
        // 更新数据
        if (frameStart == offset) {
            data = appendBytes(data, frame.getData())
            offset = frameEnd
        }
        if (frame.getFin()) {
            finReceived = true
            finalSize = frameEnd
        }
    }
    
    /// 处理对端的 RESET_STREAM 帧（RFC 9000 §3.2, §19.4）。
    public func handleResetStreamFrame(frame: ResetStreamFrame): Unit {
        // 校验 finalSize 与已接收数据的一致性
        if (frame.finalSize < 0) { return }
        if (finalSize >= 0 && frame.finalSize != finalSize) {
            // final size 不一致：FINAL_SIZE_ERROR（RFC 9000 §19.4）
            return
        }
        // 如果已接收数据超过 finalSize，违反协议
        if (offset > frame.finalSize) {
            return  // FINAL_SIZE_ERROR
        }
        finalSize = frame.finalSize
        resetErrorCode = frame.errorCode
        finReceived = true
        resetReceived = true
    }

    /// 获取对端 RESET_STREAM 中携带的错误码。
    public func getResetErrorCode(): UInt64 { resetErrorCode }
    
    public func read(): Array<Byte> {
        let d = data; data = []; d
    }
    
    public func isFinReceived(): Bool { finReceived }
    public func isResetReceived(): Bool { resetReceived }
    public func getOffset(): Int64 { offset }
    public func getFinalSize(): Int64 { finalSize }
    
    /// 更新流接收窗口。
    public func updateRecvWindow(newMax: Int64): Unit {
        if (newMax > maxStreamData) { maxStreamData = newMax }
    }
}

/// Stream 表示 QUIC 双向或单向流。
public class Stream {
    private var streamId: StreamId = 0
    private var state: StreamState = StreamState.Idle
    private var streamType: StreamType = StreamType.Bidi
    private var perspective: Perspective = Perspective.Client
    private var sendStream: SendStream = SendStream()
    private var receiveStream: ReceiveStream = ReceiveStream()
    private var flowController: StreamFlowController = StreamFlowController(0)

    public init(streamId: StreamId, streamType: StreamType, perspective: Perspective) {
        this.streamId = streamId
        this.streamType = streamType
        this.perspective = perspective
        this.flowController = StreamFlowController(streamId)
    }

    public func getStreamId(): StreamId { streamId }
    public func getState(): StreamState { state }
    public func getSendStream(): SendStream { sendStream }
    public func getReceiveStream(): ReceiveStream { receiveStream }
    public func getFlowController(): StreamFlowController { flowController }

    /// 便捷方法：向流写入数据。委托给 SendStream。
    public func write(data: Array<Byte>): Int64 { sendStream.write(data) }

    /// 便捷方法：从流读取数据。委托给 ReceiveStream。
    public func read(): Array<Byte> { receiveStream.read() }

    /// 便捷方法：关闭流的发送方向。委托给 SendStream。
    public func close(): Unit { sendStream.close() }

    /// 检查流的发送方向是否已关闭。
    public func isFinSent(): Bool { sendStream.isFinSent() }

    /// 检查是否已收到 FIN 标志。
    public func isFinReceived(): Bool { receiveStream.isFinReceived() }

    /// 获取流中未读取的数据量。
    public func getOffset(): Int64 { sendStream.getOffset() }

    /// 重置流的发送方向。
    public func resetStream(): Unit { sendStream.reset() }

    /// 检查是否已收到 RESET_STREAM。
    public func isResetReceived(): Bool { receiveStream.isResetReceived() }
}

/// CryptoStream 是用于 TLS 1.3 握手的专用流（流 ID 0）。
public class CryptoStream {
    private var stream: Stream = Stream(0, StreamType.Bidi, Perspective.Client)
    private var cryptoData: Array<Byte> = []

    public init(perspective: Perspective) {
        this.stream = Stream(0, StreamType.Bidi, perspective)
    }

    public func writeCryptoData(data: Array<Byte>): Unit { cryptoData = data }
    public func readCryptoData(): Array<Byte> {
        let d = cryptoData; cryptoData = []; d
    }
    public func getUnderlyingStream(): Stream { stream }
}

// ── 辅助函数 ──

internal func appendBytes(existing: Array<Byte>, more: Array<Byte>): Array<Byte> {
    let n = existing.size
    let m = more.size
    if (m == 0) { return existing }
    var out = Array<Byte>(n + m, repeat: 0u8)
    var i: Int64 = 0
    while (i < n) { out[i] = existing[i]; i += 1 }
    i = 0
    while (i < m) { out[n + i] = more[i]; i += 1 }
    out
}


/// Stream 表示 QUIC 双向或单向流。
