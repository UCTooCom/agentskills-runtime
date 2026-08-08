package quic_cj.ack

import quic_cj.wire.{Frame, AckFrame, ConnectionCloseFrame, ApplicationCloseFrame, FRAME_TYPE_ACK, FRAME_TYPE_ACK_ECN, FRAME_TYPE_CONNECTION_CLOSE, FRAME_TYPE_APPLICATION_CLOSE}

/// 如果帧类型是触发 ACK 的类型，返回 true。
public func isFrameTypeAckEliciting(typeByte: UInt8): Bool {
    typeByte != FRAME_TYPE_ACK && typeByte != FRAME_TYPE_ACK_ECN &&
    typeByte != FRAME_TYPE_CONNECTION_CLOSE && typeByte != FRAME_TYPE_APPLICATION_CLOSE
}

/// 如果给定帧是触发 ACK 的帧，返回 true。
public func isFrameAckEliciting(frame: Frame): Bool {
    !(frame is AckFrame || frame is ConnectionCloseFrame || frame is ApplicationCloseFrame)
}

/// 如果至少有一个帧是触发 ACK 的，返回 true。
public func hasAckElicitingFrames(frames: Array<Frame>): Bool {
    var i: Int64 = 0
    while (i < frames.size) {
        if (isFrameAckEliciting(frames[i])) { return true }
        i += 1
    }
    false
}
