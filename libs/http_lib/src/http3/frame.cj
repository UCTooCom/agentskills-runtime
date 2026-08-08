/**
 * HTTP/3 帧编码类型定义（RFC 9114 §7）。
 *
 * HTTP/3 帧在 QUIC 流上传输，使用以下格式：
 *   Type (QUIC varint) + Length (QUIC varint) + Frame Payload
 *
 * 与 HTTP/2 的不同之处：
 * - 帧头为变长（QUIC varint 编码），而非固定 9 字节
 * - 不支持 PRIORITY 帧（使用别处定义的优先级信号）
 * - 不支持 CONTINUATION 帧（QUIC 流不产生帧边界问题）
 * - 不支持 PING 帧（延迟信号在 QUIC 层面提供）
 * - 不支持 WINDOW_UPDATE 帧（QUIC 提供流控）
 * - 新增 CANCEL_PUSH、MAX_PUSH_ID 帧
 * - 无 PRIORITY_UPDATE 帧（使用 HTTP 优先级信号）
 * - 无 ORIGIN/ALTSVC 帧（这些工作在[替代协议]的 QUIC 之上）
 *
 * HTTP/3 帧类型（RFC 9114 §7.2）：
 *   0x00  DATA               — 请求/响应体数据
 *   0x01  HEADERS            — 头部块（QPACK 编码）
 *   0x03  CANCEL_PUSH        — 取消已承诺的推送流
 *   0x04  SETTINGS           — 连接级参数协商
 *   0x05  PUSH_PROMISE       — 服务端推送承诺
 *   0x07  GOAWAY             — 服务器关闭信号
 *   0x0D  MAX_PUSH_ID        — 客户端限制推送流 ID
 *
 * 注意：HTTP/3 需要底层 QUIC 传输层。当前项目不包含 QUIC 实现，
 * 本文件仅定义了 H3 帧的编解码接口。
 */
package http_lib.http3
import std.collection.ArrayList
import http_lib.http2.{encodeQuicVarint, decodeQuicVarint}
import http_lib.core.ProtocolException

/**
 * HTTP/3 帧头（变长类型 + 变长长度）。
 */
public class Http3FrameHeader {
    public let frameType: Http3FrameType
    public let payloadLength: Int64

    public init(frameType: Http3FrameType, payloadLength: Int64) {
        this.frameType = frameType
        this.payloadLength = payloadLength
    }
}

/**
 * 编码 HTTP/3 帧（type-varint + length-varint + payload）。
 */
public func encodeH3Frame(frameType: Http3FrameType, payload: Array<UInt8>): Array<UInt8> {
    let typeEncoded = encodeQuicVarint(UInt64(frameType.toUInt8()))
    let lenEncoded = encodeQuicVarint(UInt64(payload.size))
    let totalSize = typeEncoded.size + lenEncoded.size + payload.size
    var result = Array<UInt8>(totalSize, repeat: 0u8)
    var offset: Int64 = 0
    if (typeEncoded.size > 0) {
        typeEncoded.copyTo(result, 0, offset, typeEncoded.size)
        offset += typeEncoded.size
    }
    if (lenEncoded.size > 0) {
        lenEncoded.copyTo(result, 0, offset, lenEncoded.size)
        offset += lenEncoded.size
    }
    if (payload.size > 0) {
        payload.copyTo(result, 0, offset, payload.size)
    }
    result
}

/**
 * 解码 HTTP/3 帧头。
 * 返回（帧类型, 载荷长度, 帧头总字节数）。
 */
public func decodeH3FrameHeader(data: Array<UInt8>): (Http3FrameHeader, Int64) {
    var offset: Int64 = 0
    let (typeVal, typeLen) = decodeQuicVarint(data, offset)
    offset += typeLen
    if (offset >= data.size) {
        throw ProtocolException("H3 frame: missing length")
    }
    let (lenVal, lenLen) = decodeQuicVarint(data, offset)
    offset += lenLen
    let frameType = Http3FrameType.fromUInt8(UInt8(typeVal))
    (Http3FrameHeader(frameType, Int64(lenVal)), offset)
}

/**
 * 构建 SETTINGS 帧。
 */
public func buildH3SettingsFrame(settings: Array<(Http3SettingsId, UInt64)>): Array<UInt8> {
    // 第一遍：计算总负载大小
    var payloadSize: Int64 = 0
    for ((id, value) in settings) {
        let idEnc = encodeQuicVarint(UInt64(id.toUInt16()))
        payloadSize += idEnc.size
        let valEnc = encodeQuicVarint(value)
        payloadSize += valEnc.size
    }
    let payload = Array<UInt8>(payloadSize, repeat: 0)
    var offset: Int64 = 0
    for ((id, value) in settings) {
        let idEnc = encodeQuicVarint(UInt64(id.toUInt16()))
        idEnc.copyTo(payload, 0, offset, idEnc.size)
        offset += idEnc.size
        let valEnc = encodeQuicVarint(value)
        valEnc.copyTo(payload, 0, offset, valEnc.size)
        offset += valEnc.size
    }
    encodeH3Frame(Http3FrameType.SETTINGS, payload)
}

/**
 * 构建 GOAWAY 帧。
 */
public func buildH3GoawayFrame(lastStreamId: UInt64): Array<UInt8> {
    let payload = encodeQuicVarint(lastStreamId)
    encodeH3Frame(Http3FrameType.GOAWAY, payload)
}

/**
 * 构建 MAX_PUSH_ID 帧。
 */
public func buildH3MaxPushIdFrame(maxPushId: UInt64): Array<UInt8> {
    let payload = encodeQuicVarint(maxPushId)
    encodeH3Frame(Http3FrameType.MAX_PUSH_ID, payload)
}

/**
 * 构建 CANCEL_PUSH 帧（RFC 9114 §7.2.3）。
 *
 * 客户端或服务器发送 CANCEL_PUSH 帧以取消已承诺的推送流。
 * 帧载荷为推送流 ID（QUIC varint 编码）。
 *
 * @param pushId 要取消的推送流 ID
 * @return 编码后的 CANCEL_PUSH 帧字节
 */
public func buildH3CancelPushFrame(pushId: UInt64): Array<UInt8> {
    let payload = encodeQuicVarint(pushId)
    encodeH3Frame(Http3FrameType.CANCEL_PUSH, payload)
}

/**
 * 构建 PUSH_PROMISE 帧（RFC 9114 §7.2.4）。
 *
 * 服务器在请求流上发送 PUSH_PROMISE 帧以承诺即将推送的响应。
 * 帧载荷包含：Push ID（QUIC varint）+ 请求头部（QPACK 编码）。
 *
 * @param pushId 用于推送的流 ID
 * @param encodedHeaders QPACK 编码的请求头部字节
 * @return 编码后的 PUSH_PROMISE 帧字节
 */
public func buildH3PushPromiseFrame(pushId: UInt64, encodedHeaders: Array<UInt8>): Array<UInt8> {
    let pushIdEnc = encodeQuicVarint(pushId)
    let totalSize = pushIdEnc.size + encodedHeaders.size
    let payload = Array<UInt8>(totalSize, repeat: 0)
    pushIdEnc.copyTo(payload, 0, 0, pushIdEnc.size)
    if (encodedHeaders.size > 0) {
        encodedHeaders.copyTo(payload, 0, pushIdEnc.size, encodedHeaders.size)
    }
    encodeH3Frame(Http3FrameType.PUSH_PROMISE, payload)
}

/**
 * 解码 CANCEL_PUSH 帧载荷，提取推送流 ID。
 *
 * @param payload CANCEL_PUSH 帧的载荷数据
 * @return 被取消的推送流 ID
 */
public func decodeH3CancelPushPayload(payload: Array<UInt8>): UInt64 {
    if (payload.size == 0) {
        throw ProtocolException("CANCEL_PUSH 帧载荷为空")
    }
    let (pushId, _) = decodeQuicVarint(payload, 0)
    pushId
}

/**
 * 解码 PUSH_PROMISE 帧载荷，提取 Push ID 和 QPACK 编码的请求头。
 *
 * @param payload PUSH_PROMISE 帧的载荷数据
 * @return (推送流 ID, QPACK 编码的请求头部字节)
 */
public func decodeH3PushPromisePayload(payload: Array<UInt8>): (UInt64, Array<UInt8>) {
    if (payload.size == 0) {
        throw ProtocolException("PUSH_PROMISE 帧载荷为空")
    }
    let (pushId, idLen) = decodeQuicVarint(payload, 0)
    if (idLen >= payload.size) {
        return (pushId, [])
    }
    let headersBytes = payload[idLen..]
    (pushId, headersBytes)
}
