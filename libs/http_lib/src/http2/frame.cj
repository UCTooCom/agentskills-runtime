package http_lib.http2

import std.collection.ArrayList
import std.binary.*
import http_lib.core.ProtocolException
import std.unicode.*
import std.unicode.*

/**
 * HTTP/2 帧头和负载编解码（RFC 9113 §4）。
 *
 * 帧格式（9 字节头部）：
 *   [0..2]  长度（24 位大端序）
 *   [3]     类型（8 位）
 *   [4]     标志位（8 位）
 *   [5..8]  R + 流标识符（31 位大端序）
 */

public class Http2FrameHeader {
    public let payloadLength: Int64
    public let frameType: Http2FrameType
    public let flags: UInt8
    public let streamId: UInt32
    public let isKnown: Bool

    public init(payloadLength: Int64, frameType: Http2FrameType, flags!: UInt8 = 0, streamId!: UInt32 = 0, isKnown!: Bool = true) {
        this.payloadLength = payloadLength
        this.frameType = frameType
        this.flags = flags
        this.streamId = streamId
        this.isKnown = isKnown
    }

    /**
     * 编码帧头为 9 字节。
     */
    public func toBytes(): Array<UInt8> {
        let header = Array<UInt8>(9, repeat: 0)
        // 长度（24 位大端序）
        let len = UInt32(payloadLength)
        header[0] = UInt8((len >> 16) & 0xff)
        header[1] = UInt8((len >> 8) & 0xff)
        header[2] = UInt8(len & 0xff)
        // 类型
        header[3] = frameType.toUInt8()
        // 标志位
        header[4] = flags
        // 流 ID（31 位大端序，最高位保留）
        let sid = streamId
        header[5] = UInt8((sid >> 24) & 0x7f)
        header[6] = UInt8((sid >> 16) & 0xff)
        header[7] = UInt8((sid >> 8) & 0xff)
        header[8] = UInt8(sid & 0xff)
        header
    }

    /**
     * 从 9 字节解码帧头部。
     * 根据 RFC 9113 第 4.1 节，未知帧类型不被拒绝；
     * 而是标记为 isKnown=false，调用者应跳过它们。
     */
    public static func parse(data: Array<UInt8>, offset!: Int64 = 0): Http2FrameHeader {
    /**
     * 从 9 字节解码 HTTP/2 帧头部（RFC 9113 §4.1）。
     * 未知帧类型标记为 isKnown=false，调用者应跳过它们。
     */
        if (data.size - offset < 9) {
            throw ProtocolException("HTTP/2 帧头长度不足")
        }
        let payloadLength = Int64((UInt32(data[offset]) << 16) |
            (UInt32(data[offset + 1]) << 8) |
            UInt32(data[offset + 2]))
        let typeByte = data[offset + 3]
        let (frameType, isKnown) = match (Http2FrameType.fromUInt8(typeByte)) {
            case Some(ft) => (ft, true)
            case None => (Http2FrameType.DATA, false)  // DATA 帧作为未知类型的占位符
        }
        let flags = data[offset + 4]
        let streamId = (UInt32(data[offset + 5] & 0x7f) << 24) |
            (UInt32(data[offset + 6]) << 16) |
            (UInt32(data[offset + 7]) << 8) |
            UInt32(data[offset + 8])
        Http2FrameHeader(payloadLength, frameType, flags: flags, streamId: streamId, isKnown: isKnown)
    }
}

/**
 * 编码完整 HTTP/2 帧（9 字节头部 + 负载）。
 * 将 Http2FrameHeader 和负载字节拼接为完整的线缆格式帧。
 */
/**
 * 编码完整 HTTP/2 帧 (header + payload).
 */
public func encodeFrame(header: Http2FrameHeader, payload: Array<UInt8>): Array<UInt8> {
    let headerBytes = header.toBytes()
    let total = headerBytes.size + payload.size
    let result = Array<UInt8>(total, repeat: 0)
    headerBytes.copyTo(result, 0, 0, headerBytes.size)
    if (payload.size > 0) {
        payload.copyTo(result, 0, headerBytes.size, payload.size)
    }
/**
 * 编码 SETTINGS 帧负载。
 * 每个设置项编码为 6 字节：标识符(16位大端序) + 值(32位大端序)。
 */
    result
}

/**
 * SETTINGS 帧负载编码。
 * 每个设置项为：标识符(16位) + 值(32位) = 6 字节。
 */
public func encodeSettings(settings: Array<(Http2SettingsId, UInt32)>): Array<UInt8> {
    let payloadLen = settings.size * 6
    let payload = Array<UInt8>(payloadLen, repeat: 0)
    var offset: Int64 = 0
    for ((id, value) in settings) {
        let idVal = id.toUInt16()
        payload[offset] = UInt8((idVal >> 8) & 0xff)
        payload[offset + 1] = UInt8(idVal & 0xff)
        payload[offset + 2] = UInt8((value >> 24) & 0xff)
/**
 * 解码 SETTINGS 帧负载。
 * 按 6 字节一组解析设置项，未知设置项按 RFC 要求静默忽略。
 */
        payload[offset + 3] = UInt8((value >> 16) & 0xff)
        payload[offset + 4] = UInt8((value >> 8) & 0xff)
        payload[offset + 5] = UInt8(value & 0xff)
        offset += 6
    }
    payload
}

/**
 * 解码 SETTINGS 帧负载。
 */
public func decodeSettings(payload: Array<UInt8>): Array<(Http2SettingsId, UInt32)> {
    let settings = ArrayList<(Http2SettingsId, UInt32)>()
    if (payload.size % 6 != 0) {
        throw ProtocolException("SETTINGS payload length not multiple of 6")
    }
    var offset: Int64 = 0
    while (offset < payload.size) {
        let idVal = (UInt16(payload[offset]) << 8) | UInt16(payload[offset + 1])
        let value = (UInt32(payload[offset + 2]) << 24) |
            (UInt32(payload[offset + 3]) << 16) |
            (UInt32(payload[offset + 4]) << 8) |
/**
 * 编码 GOAWAY 帧负载。
 * 8 字节固定头 + 可选调试数据：last-stream-id(31bit) + error-code(32bit) + debug-data。
 */
            UInt32(payload[offset + 5])
        match (Http2SettingsId.fromUInt16(idVal)) {
            case Some(sid) => settings.add((sid, value))
            case None => ()  // 按照 RFC 忽略未知设置项
        }
        offset += 6
    }
    settings.toArray()
}

/**
 * 编码 GOAWAY 帧负载： last-stream-id(31bit) + error-code(32bit) + debug-data.
 */
public func encodeGoaway(lastStreamId: UInt32, errorCode: Http2ErrorCode, debugData!: Array<UInt8> = []): Array<UInt8> {
    let payloadLen: Int64 = 8 + debugData.size
    let payload = Array<UInt8>(payloadLen, repeat: 0)
    payload[0] = UInt8((lastStreamId >> 24) & 0x7f)
    payload[1] = UInt8((lastStreamId >> 16) & 0xff)
/**
 * 编码 RST_STREAM 帧负载。
 * 4 字节错误码（32位大端序）。
 */
    payload[2] = UInt8((lastStreamId >> 8) & 0xff)
    payload[3] = UInt8(lastStreamId & 0xff)
    let ec = errorCode.toUInt32()
    payload[4] = UInt8((ec >> 24) & 0xff)
    payload[5] = UInt8((ec >> 16) & 0xff)
    payload[6] = UInt8((ec >> 8) & 0xff)
/**
 * 解码 RST_STREAM 帧负载为错误码。
 */
    payload[7] = UInt8(ec & 0xff)
    if (debugData.size > 0) {
        var i: Int64 = 0
        while (i < debugData.size) { payload[8 + i] = debugData[i]; i++ }
    }
    payload
}

/**
 * 编码 WINDOW_UPDATE 帧负载。
 * 4 字节窗口增量（31位大端序，最高位保留）。
 */
/**
 * 编码 RST_STREAM负载: error-code(32bit)。使用 std.binary 大端序。
 */
public func encodeRstStream(errorCode: Http2ErrorCode): Array<UInt8> {
    let ec = errorCode.toUInt32()
    let payload = Array<UInt8>(4, repeat: 0)
/**
 * 解码 WINDOW_UPDATE 帧负载。
 * 检查窗口增量为 0（RFC 9113 §6.9 要求必须 > 0）。
 */
    ec.writeBigEndian(payload)
    payload
}

/**
 * 解码 RST_STREAM 负载为错误码。使用 std.binary 大端序。
 */
public func decodeRstStream(payload: Array<UInt8>): Http2ErrorCode {
    if (payload.size < 4) {
        throw ProtocolException("RST_STREAM payload too short")
/**
 * 编码 PING 帧负载。
 * 必须恰好 8 字节的不透明数据（RFC 9113 §6.7）。
 */
    }
    let ec = UInt32.readBigEndian(payload[..4])
    Http2ErrorCode.fromUInt32(ec)
}

/**
 * 编码 WINDOW_UPDATE 帧负载。使用 std.binary 大端序。
 */
public func encodeWindowUpdate(windowSizeIncrement: UInt32): Array<UInt8> {
    let payload = Array<UInt8>(4, repeat: 0)
    let wsi = windowSizeIncrement & 0x7fffffff
    wsi.writeBigEndian(payload)
    payload
}
/**
 * 构建带 ACK 标志的 SETTINGS 帧（空负载）。
 * 用于确认接收到的 SETTINGS 帧（RFC 9113 §6.5.3）。
 */

/**
 * 解码 WINDOW_UPDATE 负载。使用 std.binary 大端序。
 */
/**
 * 构建 PING 帧。
 * ACK 标志仅在响应对端 PING 时设置（RFC 9113 §6.7）。
 */
public func decodeWindowUpdate(payload: Array<UInt8>): UInt32 {
    if (payload.size < 4) {
        throw ProtocolException("WINDOW_UPDATE payload too short")
    }
    let wsi = UInt32.readBigEndian(payload[..4])
    if (wsi == 0) {
/**
 * 构建 GOAWAY 帧。
 * 用于优雅关闭连接，通告对端已处理的最后一个流 ID 和错误码。
 */
        throw ProtocolException("WINDOW_UPDATE increment must be > 0")
    }
    wsi
}

/**
 * 构建 RST_STREAM 帧。
 * 用于终止异常的流，携带错误码说明原因。
 */
/**
 * 编码 PING 负载 (8 bytes of opaque data).
 */
public func encodePing(data: Array<UInt8>): Array<UInt8> {
    if (data.size != 8) {
/**
 * 构建连接级 WINDOW_UPDATE 帧。
 * 用于补充连接流量控制窗口（streamId = 0）。
 */
        throw ProtocolException("PING payload must be exactly 8 bytes")
    }
    data.clone()
}

/**
 * 构建流级 WINDOW_UPDATE 帧。
 * 用于补充指定流的流量控制窗口。
 */
// ---- 帧标志位常量 ----

public let FLAG_ACK: UInt8 = 0x1
public let FLAG_END_STREAM: UInt8 = 0x1
public let FLAG_END_HEADERS: UInt8 = 0x4
public let FLAG_PADDED: UInt8 = 0x8
public let FLAG_PRIORITY: UInt8 = 0x20
/**
 * 编码 PRIORITY 帧负载。
 * 5 字节：流依赖(31bit) + 排他位(1bit) + 权重(8bit)。
 */

// ---- 便捷帧构建器 ----

/**
 * 构建带 ACK 标志的 SETTINGS 帧 flag (empty payload).
 */
public func buildSettingsAckFrame(): Array<UInt8> {
    let header = Http2FrameHeader(0, Http2FrameType.SETTINGS, flags: FLAG_ACK, streamId: 0)
    encodeFrame(header, [])
}

/**
 * 解码 PRIORITY 帧负载。
 * 解析流依赖关系、排他位和权重。
 */
/**
 * Build a PING 帧.
 */
public func buildPingFrame(opaqueData: Array<UInt8>, ack!: Bool = false): Array<UInt8> {
    let flags = if (ack) { FLAG_ACK } else { UInt8(0) }
    let header = Http2FrameHeader(8, Http2FrameType.PING, flags: flags, streamId: 0)
    encodeFrame(header, opaqueData)
}

/**
 * 构建 GOAWAY 帧.
 */
/**
 * 构建 PRIORITY 帧。
 * 用于更改流的优先级和依赖关系（RFC 9113 §6.3，已弃用）。
 */
public func buildGoawayFrame(lastStreamId: UInt32, errorCode: Http2ErrorCode): Array<UInt8> {
    let payload = encodeGoaway(lastStreamId, errorCode)
    let header = Http2FrameHeader(payload.size, Http2FrameType.GOAWAY, streamId: 0)
    encodeFrame(header, payload)
}

/**
 * 构建 RST_STREAM.
 */
public func buildRstStreamFrame(streamId: UInt32, errorCode: Http2ErrorCode): Array<UInt8> {
    let payload = encodeRstStream(errorCode)
    let header = Http2FrameHeader(4, Http2FrameType.RST_STREAM, streamId: streamId)
/**
 * 去除帧负载中的填充字节（RFC 9113 §6.1）。
 * PADDED 标志位指示负载第一个字节为填充长度，
 * 末尾相应数量的字节为填充数据（全零）。
 */
    encodeFrame(header, payload)
}

/**
 * 构建 WINDOW_UPDATE 帧 for connection-level (streamId=0).
 */
public func buildConnectionWindowUpdate(windowSizeIncrement: UInt32): Array<UInt8> {
    let payload = encodeWindowUpdate(windowSizeIncrement)
    let header = Http2FrameHeader(4, Http2FrameType.WINDOW_UPDATE, streamId: 0)
    encodeFrame(header, payload)
}

/**
 * 构建 WINDOW_UPDATE 帧 for a specific stream.
 */
public func buildStreamWindowUpdate(streamId: UInt32, windowSizeIncrement: UInt32): Array<UInt8> {
    let payload = encodeWindowUpdate(windowSizeIncrement)
    let header = Http2FrameHeader(4, Http2FrameType.WINDOW_UPDATE, streamId: streamId)
    encodeFrame(header, payload)
}

/**
 * 编码 PRIORITY 帧有效载荷（5 字节）。
 * RFC 9113 §6.3：E（1 位）+ 流依赖（31 位）+ 权重（8 位）。
 */
public func encodePriority(streamDep: UInt32, exclusive: Bool, weight: UInt8): Array<UInt8> {
    let payload = Array<UInt8>(5, repeat: 0)
    let dep = if (exclusive) { streamDep | 0x80000000u32 } else { streamDep & 0x7fffffffu32 }
    payload[0] = UInt8((dep >> 24) & 0xff)
    payload[1] = UInt8((dep >> 16) & 0xff)
/**
 * 编码 ORIGIN 帧负载（RFC 8336）。
 * 每个源编码为 2 字节长度前缀 + ASCII 字符串。
 */
    payload[2] = UInt8((dep >> 8) & 0xff)
    payload[3] = UInt8(dep & 0xff)
    payload[4] = weight - 1  // RFC: 权重为 1-256，发送时减 1
    payload
}

/**
 * 将 PRIORITY 帧有效载荷解码为 (streamDep, exclusive, weight)。
 * 权重返回为 1-256（线格式 + 1）。
 */
public func decodePriority(payload: Array<UInt8>): (UInt32, Bool, UInt8) {
    if (payload.size < 5) {
        throw Http2Exception(Http2ErrorCode.FRAME_SIZE_ERROR,
            "PRIORITY 帧载荷过短: ${payload.size}")
    }
    let dep = (UInt32(payload[0]) << 24) | (UInt32(payload[1]) << 16) |
              (UInt32(payload[2]) << 8) | UInt32(payload[3])
    let exclusive = (dep & 0x80000000u32) != 0u32
    let streamDep = dep & 0x7fffffffu32
    let weight = payload[4] + 1  // 转换回 1-256
    (streamDep, exclusive, weight)
}

/**
 * 构建一个完整的 PRIORITY 帧。
/**
 * 解码 ORIGIN 帧负载。
 */
 */
public func buildPriorityFrame(streamId: UInt32, streamDep: UInt32, exclusive!: Bool = false, weight!: UInt8 = 16): Array<UInt8> {
    let payload = encodePriority(streamDep, exclusive, weight)
    let header = Http2FrameHeader(5, Http2FrameType.PRIORITY, streamId: streamId)
    encodeFrame(header, payload)
}

/**
 * 根据 RFC 9113 §6.1 和 §6.2 去除帧填充。
 * 对于 DATA 帧：如果设置了 PADDED 标志，第一个字节是填充长度，
 * 并且最后 padLength 个字节是填充。
 * 对于 HEADERS 帧：如果设置了 PADDED 标志，第一个字节是填充长度，
 * 并且（如果设置了 PRIORITY 标志）接下来 5 字节是 E + 流依赖 + 权重，
 * 则最后 padLength 个字节是填充。
 *
 * 返回去除填充后的有效载荷。
 */
public func stripPadding(frameType: Http2FrameType, flags: UInt8, payload: Array<UInt8>): Array<UInt8> {
/**
 * 构建 ORIGIN 帧（RFC 8336）。
 * 用于通告服务器可用的替代源。
 */
    if ((flags & FLAG_PADDED) == 0 || payload.size == 0) {
        return payload
    }
    let padLength = Int64(payload[0])
    // 根据 RFC 9113 第 6.1 节：填充长度必须小于有效载荷长度
    if (padLength >= payload.size) {
/**
 * 编码 ALTSVC 帧负载（RFC 7838）。
 * 格式：2字节源长度 + 源字符串 + 备选服务字段值。
 */
        throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
            "Invalid padding: pad length (${padLength}) >= payload size (${payload.size})")
    }
    var dataStart: Int64 = 1
    if (frameType == Http2FrameType.HEADERS && (flags & FLAG_PRIORITY) != 0) {
        dataStart = 6  // 1（填充长度）+ 5（优先级字段）
    }
    let dataEnd = payload.size - padLength
    if (dataEnd <= dataStart) {
        throw Http2Exception(Http2ErrorCode.PROTOCOL_ERROR,
            "Invalid padding: data end (${dataEnd}) <= data start (${dataStart})")
    }
    let resultLen = dataEnd - dataStart
    let result = Array<UInt8>(resultLen, repeat: 0)
    var i: Int64 = 0
    while (i < resultLen) {
        result[i] = payload[dataStart + i]
        i++
    }
    result
}


/**
/**
 * 解码 ALTSVC 帧负载。
 */
 * 编码 ORIGIN 帧有效载荷（RFC 8336）。
 * 包含一个 origin 条目列表，每个条目前面有一个 16 位长度。
 * 格式：[orig_len(16)][origin_bytes]...
 */
public func encodeOriginPayload(origins: Array<String>): Array<UInt8> {
    var totalSize: Int64 = 0
    for (o in origins) {
        totalSize += 2 + o.size
    }
    let payload = Array<UInt8>(totalSize, repeat: 0)
    var offset: Int64 = 0
    for (o in origins) {
        let originBytes = unsafe { o.rawData() }
        let len = UInt16(originBytes.size)
        payload[offset] = UInt8((len >> 8) & 0xff)
        payload[offset + 1] = UInt8(len & 0xff)
        offset += 2
        if (originBytes.size > 0) {
            var i: Int64 = 0
            while (i < originBytes.size) {
                payload[offset + i] = originBytes[i]
/**
 * 构建 ALTSVC 帧（RFC 7838）。
 * 用于通告替代服务（如 HTTP/3 端点）。
 */
                i += 1
            }
            offset += originBytes.size
        }
    }
    payload
/**
 * 编码 PRIORITY_UPDATE 帧负载（RFC 9218）。
 * 格式：4字节目标流ID + 优先级字段值字符串。
 */
}

/**
 * 解码 ORIGIN 帧有效载荷（RFC 8336）。
 * 返回 origin 字符串列表。
 */
public func decodeOriginPayload(payload: Array<UInt8>): Array<String> {
    let origins = ArrayList<String>()
    var offset: Int64 = 0
    while (offset + 2 <= payload.size) {
        let len = (UInt16(payload[offset]) << 8) | UInt16(payload[offset + 1])
        offset += 2
        if (offset + Int64(len) > payload.size) {
            throw ProtocolException("ORIGIN payload truncated")
        }
        let originBytes = payload[offset..offset + Int64(len)]
        let origin = String.fromUtf8(originBytes)
        origins.add(origin)
/**
 * 解码 PRIORITY_UPDATE 帧负载。
 */
        offset += Int64(len)
    }
    origins.toArray()
}

/**
 * 构建完整的 ORIGIN 帧（RFC 8336）。
 * ORIGIN 帧始终是连接级（streamId=0）。
 */
public func buildOriginFrame(origins: Array<String>): Array<UInt8> {
    let payload = encodeOriginPayload(origins)
    let header = Http2FrameHeader(payload.size, Http2FrameType.ORIGIN, streamId: 0)
    encodeFrame(header, payload)
/**
 * 构建 PRIORITY_UPDATE 帧（RFC 9218）。
 * 用于声明流的优先级，替代已弃用的 PRIORITY 帧。
 */
}

/**
 * 编码 ALTSVC 帧有效载荷（RFC 7838）。
 * 格式：[origin_len(16)][origin...][alt-svc-field-value...]
 */
public func encodeAltSvcPayload(origin: String, altSvcFieldValue: Array<UInt8>): Array<UInt8> {
    let originBytes = unsafe { origin.rawData() }
    let payloadSize: Int64 = 2 + originBytes.size + altSvcFieldValue.size
    let payload = Array<UInt8>(payloadSize, repeat: 0)
    let len = UInt16(originBytes.size)
    payload[0] = UInt8((len >> 8) & 0xff)
    payload[1] = UInt8(len & 0xff)
    if (originBytes.size > 0) {
        var i: Int64 = 0
        while (i < originBytes.size) {
            payload[2 + i] = originBytes[i]
            i += 1
        }
    }
    if (altSvcFieldValue.size > 0) {
        var i: Int64 = 0
        while (i < altSvcFieldValue.size) {
            payload[2 + originBytes.size + i] = altSvcFieldValue[i]
            i += 1
        }
    }
    payload
}

/**
 * 解码 ALTSVC 帧有效载荷（RFC 7838）。
 * 返回 (origin, altSvcFieldValue)。
 */
public func decodeAltSvcPayload(payload: Array<UInt8>): (String, Array<UInt8>) {
    if (payload.size < 2) {
        throw ProtocolException("ALTSVC payload too short")
    }
    let originLen = (UInt16(payload[0]) << 8) | UInt16(payload[1])
    var offset: Int64 = 2
    let origin = if (originLen > 0) {
        if (offset + Int64(originLen) > payload.size) {
            throw ProtocolException("ALTSVC payload truncated")
        }
        let originBytes = payload[offset..offset + Int64(originLen)]
        offset += Int64(originLen)
        String.fromUtf8(originBytes)
    } else {
        ""
    }
    let fieldValue = payload[offset..payload.size]
    (origin, fieldValue)
}

/**
 * 构建完整的 ALTSVC 帧（RFC 7838）。
 * streamId 为 0 表示连接级，非 0 表示特定流（此时 origin 应为空）。
 */
public func buildAltSvcFrame(origin: String, altSvcFieldValue: Array<UInt8>, streamId!: UInt32 = 0): Array<UInt8> {
    let payload = encodeAltSvcPayload(origin, altSvcFieldValue)
    let header = Http2FrameHeader(payload.size, Http2FrameType.ALTSVC, streamId: streamId)
    encodeFrame(header, payload)
}

/**
 * 编码 PRIORITY_UPDATE 帧有效载荷（RFC 9218）。
 * 格式：[prioritized_stream_id(31)][priority_field_value...]
 */
public func encodePriorityUpdatePayload(prioritizedStreamId: UInt32, priorityFieldValue: Array<UInt8>): Array<UInt8> {
    let payloadSize: Int64 = 4 + priorityFieldValue.size
    let payload = Array<UInt8>(payloadSize, repeat: 0)
    let sid = prioritizedStreamId & 0x7fffffffu32
    payload[0] = UInt8((sid >> 24) & 0x7f)
    payload[1] = UInt8((sid >> 16) & 0xff)
    payload[2] = UInt8((sid >> 8) & 0xff)
    payload[3] = UInt8(sid & 0xff)
    if (priorityFieldValue.size > 0) {
        var i: Int64 = 0
        while (i < priorityFieldValue.size) {
            payload[4 + i] = priorityFieldValue[i]
            i += 1
        }
    }
    payload
}

/**
 * 解码 PRIORITY_UPDATE 帧有效载荷（RFC 9218）。
 * 返回 (prioritizedStreamId, priorityFieldValue)。
 */
public func decodePriorityUpdatePayload(payload: Array<UInt8>): (UInt32, Array<UInt8>) {
    if (payload.size < 4) {
        throw ProtocolException("PRIORITY_UPDATE payload too short")
    }
    let sid = (UInt32(payload[0] & 0x7f) << 24) |
              (UInt32(payload[1]) << 16) |
              (UInt32(payload[2]) << 8) |
              UInt32(payload[3])
    let fieldValue = payload[4..payload.size]
    (sid, fieldValue)
}

/**
 * 构建完整的 PRIORITY_UPDATE 帧（RFC 9218）。
 * streamId 为 0 表示连接级，非 0 表示特定流。
 */
public func buildPriorityUpdateFrame(streamId: UInt32, prioritizedStreamId: UInt32, priorityFieldValue: Array<UInt8>): Array<UInt8> {
    let payload = encodePriorityUpdatePayload(prioritizedStreamId, priorityFieldValue)
    let header = Http2FrameHeader(payload.size, Http2FrameType.PRIORITY_UPDATE, streamId: streamId)
    encodeFrame(header, payload)
}
/**
 * 解析 RFC 9218 优先级字段值，提取紧急度（urgency）和增量标志（incremental）。
 *
 * 优先级字段值格式（结构化字段）：
 *   priority = u [ "=" urgency ] *("," [ parameter ] )
 *   urgency  = "0".."7"
 *   parameter = token ["=" value]
 *
 * 示例: "u=4", "u=0, i", "u=3", "i", ""（空 = 默认值）
 *
 * @param fieldValue PRIORITY_UPDATE 帧的优先数字段值（UTF-8 字节）
 * @return (urgency, incremental) 紧急度（0-7，默认3）和增量标志
 */
public func parsePriorityFieldValue(fieldValue: Array<UInt8>): (UInt8, Bool) {
    if (fieldValue.size == 0) {
        return (3u8, false)  // RFC 9218 默认值
    }

    let s = String.fromUtf8(fieldValue)
    let runes = s.toRuneArray()

    var urgency: UInt8 = 3u8
    var incremental: Bool = false
    var i: Int64 = 0

    while (i < runes.size) {
        // 跳过空白
        while (i < runes.size && (runes[i] == r' ' || runes[i] == r'\t')) { i += 1 }
        if (i >= runes.size) { break }

        if (runes[i] == r'u' || runes[i] == r'U') {
            i += 1
            // 跳过空白
            while (i < runes.size && (runes[i] == r' ' || runes[i] == r'\t')) { i += 1 }
            if (i < runes.size && runes[i] == r'=') {
                i += 1
                // 跳过空白
                while (i < runes.size && (runes[i] == r' ' || runes[i] == r'\t')) { i += 1 }
                if (i < runes.size && runes[i] >= r'0' && runes[i] <= r'7') {
                    urgency = UInt8(UInt32(runes[i]) - UInt32(r'0'))
                    i += 1
                }
            }
        } else if (runes[i] == r'i' || runes[i] == r'I') {
            // 检查后面是否没有 '='，表示这是一个标志（不是 i=something）
            let nextNonSpace = findNextNonSpace(runes, i + 1)
            if (nextNonSpace >= runes.size || runes[nextNonSpace] != r'=') {
                incremental = true
            }
            i += 1
        } else if (runes[i] == r',') {
            i += 1
        } else {
            i += 1  // 跳过无法识别的标记
        }

        // 跳到下一个逗号
        while (i < runes.size && runes[i] != r',') { i += 1 }
        if (i < runes.size) { i += 1 }  // 跳过逗号
    }

    (urgency, incremental)
}

/**
 * 查找数组中从 start 位置开始的下一个非空白字符索引。
 */
private func findNextNonSpace(runes: Array<Rune>, start: Int64): Int64 {
    var i = start
    while (i < runes.size && (runes[i] == r' ' || runes[i] == r'\t')) { i += 1 }
    i
}

/**
 * 将 RFC 9218 紧急度（0-7）转换为 RFC 7540 权重（1-256）。
 *
 * 映射关系（指数衰减，紧急度 3 映射到默认权重 16）：
 *   0→128  1→64  2→32  3→16  4→8  5→4  6→2  7→1
 *
 * @param urgency RFC 9218 紧急度（0-7）
 * @return RFC 7540 权重（1-256）
 */
public func urgencyToWeight(urgency: UInt8): UInt8 {
    if (urgency >= 7u8) { return 1u8 }
    if (urgency <= 3u8) {
        return UInt8(16u32 << UInt32(3u32 - UInt32(urgency)))
    }
    return UInt8(16u32 >> UInt32(UInt32(urgency) - 3u32))
}
