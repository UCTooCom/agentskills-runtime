package quic_cj.wire

import quic_cj.protocol.{MAX_CONN_ID_LEN}

// ── 传输参数 ID（RFC 9000 §18） ──

public let TP_ORIGINAL_DESTINATION_CONNECTION_ID: Int64 = 0x00
public let TP_MAX_IDLE_TIMEOUT: Int64 = 0x01
public let TP_STATELESS_RESET_TOKEN: Int64 = 0x02
public let TP_MAX_UDP_PAYLOAD_SIZE: Int64 = 0x03
public let TP_INITIAL_MAX_DATA: Int64 = 0x04
public let TP_INITIAL_MAX_STREAM_DATA_BIDI_LOCAL: Int64 = 0x05
public let TP_INITIAL_MAX_STREAM_DATA_BIDI_REMOTE: Int64 = 0x06
public let TP_INITIAL_MAX_STREAM_DATA_UNI: Int64 = 0x07
public let TP_INITIAL_MAX_STREAMS_BIDI: Int64 = 0x08
public let TP_INITIAL_MAX_STREAMS_UNI: Int64 = 0x09
public let TP_ACK_DELAY_EXPONENT: Int64 = 0x0a
public let TP_MAX_ACK_DELAY: Int64 = 0x0b
public let TP_DISABLE_ACTIVE_MIGRATION: Int64 = 0x0c
public let TP_PREFERRED_ADDRESS: Int64 = 0x0d
public let TP_ACTIVE_CONNECTION_ID_LIMIT: Int64 = 0x0e
public let TP_INITIAL_SOURCE_CONNECTION_ID: Int64 = 0x0f
public let TP_RETRY_SOURCE_CONNECTION_ID: Int64 = 0x10
public let TP_MAX_DATAGRAM_FRAME_SIZE: Int64 = 0x20
public let TP_MAX_EARLY_DATA_SIZE: Int64 = 0x42

/// 默认传输参数值
public let DEFAULT_MAX_UDP_PAYLOAD_SIZE: Int64 = 65527
public let DEFAULT_ACTIVE_CONNECTION_ID_LIMIT: Int64 = 2

/// 保存所有 QUIC 传输参数（RFC 9000 §18）。
public class TransportParameters {
    public var originalDestConnId: Array<Byte> = []
    public var initialSrcConnId: Array<Byte> = []
    public var retrySrcConnId: Array<Byte> = []
    public var statelessResetToken: Array<Byte> = []
    public var preferredAddressData: Array<Byte> = []

    public var initialMaxData: Int64 = 0
    public var initialMaxStreamDataBidiLocal: Int64 = 0
    public var initialMaxStreamDataBidiRemote: Int64 = 0
    public var initialMaxStreamDataUni: Int64 = 0
    public var initialMaxStreamsBidi: Int64 = 0
    public var initialMaxStreamsUni: Int64 = 0

    public var maxIdleTimeoutMs: Int64 = 30000
    public var maxUdpPayloadSize: Int64 = DEFAULT_MAX_UDP_PAYLOAD_SIZE
    public var ackDelayExponent: Int64 = 3
    public var maxAckDelayMs: Int64 = 25
    public var activeConnectionIdLimit: Int64 = DEFAULT_ACTIVE_CONNECTION_ID_LIMIT
    public var disableActiveMigration: Bool = false
    public var maxDatagramFrameSize: Int64 = 0
    public var maxEarlyDataSize: Int64 = 0
}

/// 将传输参数序列化到字节缓冲区。
public func marshalTransportParameters(params: TransportParameters): Array<Byte> {
    var buf: Array<Byte> = []

    if (params.originalDestConnId.size > 0) {
        buf = appendTransportParameter(buf, TP_ORIGINAL_DESTINATION_CONNECTION_ID, params.originalDestConnId)
    }
    buf = appendTransportParameterVarint(buf, TP_MAX_IDLE_TIMEOUT, params.maxIdleTimeoutMs)
    if (params.statelessResetToken.size > 0) {
        buf = appendTransportParameter(buf, TP_STATELESS_RESET_TOKEN, params.statelessResetToken)
    }
    buf = appendTransportParameterVarint(buf, TP_MAX_UDP_PAYLOAD_SIZE, params.maxUdpPayloadSize)
    buf = appendTransportParameterVarint(buf, TP_INITIAL_MAX_DATA, params.initialMaxData)
    buf = appendTransportParameterVarint(buf, TP_INITIAL_MAX_STREAM_DATA_BIDI_LOCAL, params.initialMaxStreamDataBidiLocal)
    buf = appendTransportParameterVarint(buf, TP_INITIAL_MAX_STREAM_DATA_BIDI_REMOTE, params.initialMaxStreamDataBidiRemote)
    buf = appendTransportParameterVarint(buf, TP_INITIAL_MAX_STREAM_DATA_UNI, params.initialMaxStreamDataUni)
    buf = appendTransportParameterVarint(buf, TP_INITIAL_MAX_STREAMS_BIDI, params.initialMaxStreamsBidi)
    buf = appendTransportParameterVarint(buf, TP_INITIAL_MAX_STREAMS_UNI, params.initialMaxStreamsUni)
    buf = appendTransportParameterVarint(buf, TP_ACK_DELAY_EXPONENT, params.ackDelayExponent)
    buf = appendTransportParameterVarint(buf, TP_MAX_ACK_DELAY, params.maxAckDelayMs)
    if (params.disableActiveMigration) {
        buf = appendTransportParameter(buf, TP_DISABLE_ACTIVE_MIGRATION, [])
    }
    buf = appendTransportParameterVarint(buf, TP_ACTIVE_CONNECTION_ID_LIMIT, params.activeConnectionIdLimit)
    if (params.initialSrcConnId.size > 0) {
        buf = appendTransportParameter(buf, TP_INITIAL_SOURCE_CONNECTION_ID, params.initialSrcConnId)
    }
    if (params.retrySrcConnId.size > 0) {
        buf = appendTransportParameter(buf, TP_RETRY_SOURCE_CONNECTION_ID, params.retrySrcConnId)
    }
    if (params.preferredAddressData.size > 0) {
        buf = appendTransportParameter(buf, TP_PREFERRED_ADDRESS, params.preferredAddressData)
    }
   if (params.maxDatagramFrameSize > 0) {
       buf = appendTransportParameterVarint(buf, TP_MAX_DATAGRAM_FRAME_SIZE, params.maxDatagramFrameSize)
   }
    if (params.maxEarlyDataSize > 0) {
        buf = appendTransportParameterVarint(buf, TP_MAX_EARLY_DATA_SIZE, params.maxEarlyDataSize)
    }
   buf
}

/// 辅助：追加带有不透明值的传输参数。
private func appendTransportParameter(buf: Array<Byte>, id: Int64, value: Array<Byte>): Array<Byte> {
    var out = appendVarint(buf, id)
    out = appendVarint(out, value.size)
    out = appendBytes(out, value)
    out
}

/// 辅助：追加带有 varint 值的传输参数。
private func appendTransportParameterVarint(buf: Array<Byte>, id: Int64, value: Int64): Array<Byte> {
    if (value == 0) { return buf } // 跳过零值
    let encoded = appendVarint([], value)
    appendTransportParameter(buf, id, encoded)
}

/// PreferredAddress 保存服务端建议的替代地址（RFC 9000 §18.2）。
public class PreferredAddress {
    public var ipv4Addr: Array<Byte> = [0u8, 0u8, 0u8, 0u8]
    public var ipv4Port: Int64 = 0
    public var ipv6Addr: Array<Byte> = []
    public var ipv6Port: Int64 = 0
    public var connId: Array<Byte> = []
    public var statelessResetToken: Array<Byte> = Array<Byte>(16, repeat: 0u8)

    public init() {}
    public init(ipv4: Array<Byte>, port: Int64, connId: Array<Byte>, resetToken: Array<Byte>) {
        if (ipv4.size == 4) { this.ipv4Addr = ipv4 }
        this.ipv4Port = port
        this.connId = connId
        if (resetToken.size == 16) { this.statelessResetToken = resetToken }
    }
}

/// 从 PreferredAddress 构建预序列化的 preferred_address 传输参数数据。
public func makePreferredAddressData(addr: PreferredAddress): Array<Byte> {
    var buf: Array<Byte> = []
    // IPv4 地址 (4 字节) + 端口 (2 字节)
    buf = appendBytes(buf, addr.ipv4Addr)
    buf = appendByte(buf, UInt8((addr.ipv4Port >> 8) & 0xff))
    buf = appendByte(buf, UInt8(addr.ipv4Port & 0xff))
    // IPv6 地址 (16 字节) + 端口 (2 字节)
    if (addr.ipv6Addr.size >= 16) {
        buf = appendBytes(buf, addr.ipv6Addr[..16])
    } else {
        buf = appendBytes(buf, Array<Byte>(16, repeat: 0u8))
    }
    buf = appendByte(buf, UInt8((addr.ipv6Port >> 8) & 0xff))
    buf = appendByte(buf, UInt8(addr.ipv6Port & 0xff))
    // 连接 ID 长度 + 连接 ID
    buf = appendByte(buf, UInt8(addr.connId.size))
    buf = appendBytes(buf, addr.connId)
    // Stateless Reset Token
    buf = appendBytes(buf, addr.statelessResetToken)
    buf
}

/// 从字节解析 PreferredAddress。
public func parsePreferredAddress(data: Array<Byte>): Option<PreferredAddress> {
    let addr = PreferredAddress()
    if (data.size < 18) { return None }
    var off: Int64 = 0
    addr.ipv4Addr = data[off..off+4]; off += 4
    addr.ipv4Port = (Int64(data[off]) << 8) | Int64(data[off+1]); off += 2
    if (off + 16 > data.size) { return None }
    addr.ipv6Addr = data[off..off+16]; off += 16
    if (off + 2 > data.size) { return None }
    addr.ipv6Port = (Int64(data[off]) << 8) | Int64(data[off+1]); off += 2
    if (off >= data.size) { return None }
    let cidLen = Int64(data[off]); off += 1
    if (off + cidLen > data.size) { return None }
    addr.connId = data[off..off+cidLen]; off += cidLen
    let remaining = data.size - off
    if (remaining >= 16) {
        addr.statelessResetToken = data[off..off+16]
    }
    Some(addr)
}

/// 从字节反序列化传输参数。
/// 返回 parameters。
public func parseTransportParameters(data: Array<Byte>): Option<TransportParameters> {
    let params = TransportParameters()
    var remaining = data
    while (remaining.size > 0) {
        let (id, n1) = readVarint(remaining)
        if (n1 == 0) { return None }
        remaining = remaining[n1..]
        if (remaining.size < 1) { return None }
        let (valLen, n2) = readVarint(remaining)
        if (n2 == 0) { return None }
        remaining = remaining[n2..]
        if (valLen > remaining.size) { return None }
        let value = remaining[..valLen]
        remaining = remaining[valLen..]

        if (id == TP_ORIGINAL_DESTINATION_CONNECTION_ID) {
            params.originalDestConnId = value
        } else if (id == TP_INITIAL_SOURCE_CONNECTION_ID) {
            params.initialSrcConnId = value
        } else if (id == TP_RETRY_SOURCE_CONNECTION_ID) {
            params.retrySrcConnId = value
        } else if (id == TP_STATELESS_RESET_TOKEN && valLen == 16) {
            params.statelessResetToken = value
        } else if (id == TP_MAX_IDLE_TIMEOUT) {
            let (v, _) = readVarint(value)
            params.maxIdleTimeoutMs = v
        } else if (id == TP_MAX_UDP_PAYLOAD_SIZE) {
            let (v, _) = readVarint(value)
            if (v >= 1200) { params.maxUdpPayloadSize = v }
        } else if (id == TP_INITIAL_MAX_DATA) {
            let (v, _) = readVarint(value)
            params.initialMaxData = v
        } else if (id == TP_INITIAL_MAX_STREAM_DATA_BIDI_LOCAL) {
            let (v, _) = readVarint(value)
            params.initialMaxStreamDataBidiLocal = v
        } else if (id == TP_INITIAL_MAX_STREAM_DATA_BIDI_REMOTE) {
            let (v, _) = readVarint(value)
            params.initialMaxStreamDataBidiRemote = v
        } else if (id == TP_INITIAL_MAX_STREAM_DATA_UNI) {
            let (v, _) = readVarint(value)
            params.initialMaxStreamDataUni = v
        } else if (id == TP_INITIAL_MAX_STREAMS_BIDI) {
            let (v, _) = readVarint(value)
            params.initialMaxStreamsBidi = v
        } else if (id == TP_INITIAL_MAX_STREAMS_UNI) {
            let (v, _) = readVarint(value)
            params.initialMaxStreamsUni = v
        } else if (id == TP_ACK_DELAY_EXPONENT) {
            let (v, _) = readVarint(value)
            if (v <= 20) { params.ackDelayExponent = v }
        } else if (id == TP_MAX_ACK_DELAY) {
            let (v, _) = readVarint(value)
            params.maxAckDelayMs = v
        } else if (id == TP_DISABLE_ACTIVE_MIGRATION) {
            params.disableActiveMigration = true
        } else if (id == TP_ACTIVE_CONNECTION_ID_LIMIT) {
            let (v, _) = readVarint(value)
            if (v >= 2) { params.activeConnectionIdLimit = v }
        } else if (id == TP_PREFERRED_ADDRESS) {
            params.preferredAddressData = value
       } else if (id == TP_MAX_DATAGRAM_FRAME_SIZE) {
           let (v, _) = readVarint(value)
           params.maxDatagramFrameSize = v
        } else if (id == TP_MAX_EARLY_DATA_SIZE) {
            let (v, _) = readVarint(value)
            params.maxEarlyDataSize = v
       }
       // 根据 RFC 9000，未知参数被跳过
    }
    Some(params)
}
