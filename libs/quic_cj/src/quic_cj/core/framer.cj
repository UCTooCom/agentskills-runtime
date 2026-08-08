package quic_cj.core

import quic_cj.protocol.{PacketNumber, EncryptionLevel, StreamId, INVALID_BYTE_COUNT}
import quic_cj.wire.{Frame, AckFrame, CryptoFrame, StreamFrame, PingFrame, appendFrame, PathResponseFrame, DataBlockedFrame, FRAME_TYPE_PING, FRAME_TYPE_CRYPTO, FRAME_TYPE_PATH_RESPONSE, FRAME_TYPE_RESET_STREAM, FRAME_TYPE_STOP_SENDING, FRAME_TYPE_MAX_DATA, FRAME_TYPE_MAX_STREAM_DATA, FRAME_TYPE_MAX_STREAMS_BIDI, FRAME_TYPE_MAX_STREAMS_UNI, FRAME_TYPE_HANDSHAKE_DONE, FRAME_TYPE_CONNECTION_CLOSE, FRAME_TYPE_DATA_BLOCKED, FRAME_TYPE_STREAM_DATA_BLOCKED, FRAME_TYPE_STREAMS_BLOCKED_BIDI, FRAME_TYPE_STREAMS_BLOCKED_UNI}

public let MAX_PATH_RESPONSES: Int64 = 256
public let MAX_CONTROL_FRAMES: Int64 = 16 * 1024

/// Framer 管理待发送帧的队列，按优先级排序。
/// 优先级顺序（从高到低）：ACK > PATH_RESPONSE > CRYPTO > 连接控制 > 流控制 > STREAM
public class Framer {
    private var cryptoData: Array<Byte> = []
    private var cryptoOffset: Int64 = 0
    private var pendingAck: AckFrame = AckFrame()
    private var hasPendingAck: Bool = false
    private var pathResponses: Array<PathResponseFrame> = []
    private var controlFrames: Array<Frame> = []
    private var lastBlockedOffset: Int64 = INVALID_BYTE_COUNT

    public func hasData(): Bool {
        hasPendingAck || cryptoData.size > 0 || pathResponses.size > 0 || controlFrames.size > 0
    }

    public func queueCryptoData(data: Array<Byte>): Unit {
        cryptoData = appendBytesToByte(cryptoData, data)
    }

    public func queueCryptoFrame(frame: CryptoFrame): Unit {
        cryptoData = appendBytesToByte(cryptoData, frame.data)
    }

    public func setAckFrame(ack: AckFrame): Unit {
        hasPendingAck = true
        pendingAck = ack
    }

    public func queueFrame(frame: Frame): Unit {
        let ft = frame.frameType()
        // PATH_RESPONSE 有自己的有限队列（每包一个）
        if (ft == FRAME_TYPE_PATH_RESPONSE) {
            match (frame as PathResponseFrame) {
                case Some(prf) =>
                    if (pathResponses.size < MAX_PATH_RESPONSES) {
                        pathResponses = appendPathResponse(pathResponses, prf)
                    }
                case None => ()
            }
            return
        }
        // 其他控制帧进入通用队列
        if (controlFrames.size < MAX_CONTROL_FRAMES) {
            controlFrames = appendFrameToArray(controlFrames, frame)
        }
    }

    /// 通知连接级流量控制被阻塞。
    public func setBlocked(offset: Int64): Unit {
        if (offset != lastBlockedOffset) {
            lastBlockedOffset = offset
        }
    }

    /// 如果连接被阻塞，获取 DATA_BLOCKED 帧。
    public func getBlockedFrame(): Option<Frame> {
        if (lastBlockedOffset != INVALID_BYTE_COUNT) {
            let db = DataBlockedFrame()
            db.maxData = lastBlockedOffset
            lastBlockedOffset = INVALID_BYTE_COUNT
            return Some(db)
        }
        None
    }

    /// 获取所有待处理帧，按优先级排序。
    /// 注意：返回所有帧；packet_packer 强制执行大小限制。
    /// 获取所有待处理帧，按优先级排序（预计算总数 + 一次分配）。
    public func getFrames(): Array<Frame> {
        // 预计算总帧数
        let count = (if (hasPendingAck) { 1 } else { 0 })
                  + (if (pathResponses.size > 0) { 1 } else { 0 })
                  + (if (cryptoData.size > 0) { 1 } else { 0 })
                  + controlFrames.size
        if (count == 0) { return Array<Frame>(0, repeat: Frame()) }

        // 一次分配
        var result = Array<Frame>(count, repeat: Frame())
        var idx: Int64 = 0

        // 1. ACK——最高优先级
        if (hasPendingAck) {
            result[idx] = pendingAck; idx += 1
            hasPendingAck = false
        }

        // 2. PATH_RESPONSE——每包最多一个
        if (pathResponses.size > 0) {
            result[idx] = pathResponses[0]; idx += 1
            pathResponses = pathResponses[1..]
        }

        // 3. CRYPTO 帧
        if (cryptoData.size > 0) {
            let cf = CryptoFrame()
            cf.offset = cryptoOffset
            cf.data = cryptoData
            cryptoData = []
            cryptoOffset += cf.data.size
            result[idx] = cf; idx += 1
        }

        // 4. 控制帧（连接级和流级，FIFO）
        var i: Int64 = 0
        while (i < controlFrames.size) {
            result[idx] = controlFrames[i]; idx += 1
            i += 1
        }
        controlFrames = []
        result
    }


    /// 近似待处理帧总数。
    public func frameCount(): Int64 {
        var n: Int64 = 0
        if (hasPendingAck) { n += 1 }
        if (pathResponses.size > 0) { n += 1 }
        if (cryptoData.size > 0) { n += 1 }
        n + controlFrames.size
    }

    /// 处理 0-RTT 拒绝：清空与 0-RTT 相关的控制帧。
    public func handle0RttRejection(): Unit {
        var kept: Array<Frame> = []
        var i: Int64 = 0
        while (i < controlFrames.size) {
            let ft = controlFrames[i].frameType()
            if (ft != FRAME_TYPE_MAX_DATA && ft != FRAME_TYPE_MAX_STREAM_DATA
                && ft != FRAME_TYPE_MAX_STREAMS_BIDI && ft != FRAME_TYPE_MAX_STREAMS_UNI
                && ft != FRAME_TYPE_DATA_BLOCKED && ft != FRAME_TYPE_STREAM_DATA_BLOCKED
                && ft != FRAME_TYPE_STREAMS_BLOCKED_BIDI && ft != FRAME_TYPE_STREAMS_BLOCKED_UNI) {
                kept = appendFrameToArray(kept, controlFrames[i])
            }
            i += 1
        }
        controlFrames = kept
    }

    /// 根据 MTU 和加密级别开销计算最大负载长度。
    public func maxPayloadLen(mtu: Int64, encLevel: EncryptionLevel): Int64 {
        let overhead: Int64 = match (encLevel) {
            case EncryptionLevel.Initial => 45
            case EncryptionLevel.Handshake => 25
            case EncryptionLevel.OneRTT => 25
            case _ => 25
        }
        // 确保最小初始包大小（RFC 9000）
        if ((match (encLevel) { case EncryptionLevel.Initial => true; case _ => false })) {
            return max(mtu - overhead, 1200)
        }
        mtu - overhead
    }
}

internal func appendFrameToArray(arr: Array<Frame>, frame: Frame): Array<Frame> {
    let n = arr.size
    let out = Array<Frame>(n + 1, repeat: Frame())
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = frame
    out
}

internal func appendPathResponse(arr: Array<PathResponseFrame>, prf: PathResponseFrame): Array<PathResponseFrame> {
    let n = arr.size
    let out = Array<PathResponseFrame>(n + 1, repeat: PathResponseFrame())
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = prf
    out
}

internal func appendBytesToByte(existing: Array<Byte>, more: Array<Byte>): Array<Byte> {
    let n = existing.size
    let m = more.size
    let out = Array<Byte>(n + m, repeat: 0u8)
    var i: Int64 = 0
    while (i < n) { out[i] = existing[i]; i += 1 }
    i = 0
    while (i < m) { out[n + i] = more[i]; i += 1 }
    out
}
