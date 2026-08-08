package http_lib.server
/**
 * WebSocket 帧编解码（RFC 6455 §5）。
 * 支持文本、二进制、关闭、Ping/Pong 和 Continuation 帧类型。
 */

import std.collection.ArrayList
import http_lib.connection.secureRandom

/**
 * WebSocket 操作码定义（RFC 6455 §11.8）。
 */
public enum WebSocketOpcode {
    | Continuation
    | Text
    | Binary
    | Close
    | Ping
    | Pong

    public func toUInt8(): UInt8 {
        match (this) {
            case Continuation => 0x00u8
            case Text => 0x01u8
            case Binary => 0x02u8
            case Close => 0x08u8
            case Ping => 0x09u8
            case Pong => 0x0Au8
        }
    }

    public static func fromUInt8(value: UInt8): ?WebSocketOpcode {
        match (value) {
            case 0x00 => Some(WebSocketOpcode.Continuation)
            case 0x01 => Some(WebSocketOpcode.Text)
            case 0x02 => Some(WebSocketOpcode.Binary)
            case 0x08 => Some(WebSocketOpcode.Close)
            case 0x09 => Some(WebSocketOpcode.Ping)
            case 0x0A => Some(WebSocketOpcode.Pong)
            case _ => None
        }
    }

    public operator func ==(that: WebSocketOpcode): Bool {
        match ((this, that)) {
            case (Continuation, Continuation) => true
            case (Text, Text) => true
            case (Binary, Binary) => true
            case (Close, Close) => true
            case (Ping, Ping) => true
            case (Pong, Pong) => true
            case _ => false
        }
    }

    public operator func !=(that: WebSocketOpcode): Bool {
        !(this == that)
    }
}

/**
 * WebSocket 帧编解码（RFC 6455）。
 *
 * 帧格式：
 *   0                   1                   2                   3
 *   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *   +-+-+-+-+-------+-+-------------+-------------------------------+
 *   |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 *   |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 *   |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 *   | |1|2|3|       |K|             |                               |
 *   +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 *   |     Extended payload length continued, if payload len == 127  |
 *   + - - - - - - - - - - - - - - - +-------------------------------+
 *   |                               |Masking-key, if MASK set to 1  |
 *   +-------------------------------+-------------------------------+
 *   | Masking-key (continued)       |          Payload Data         |
 *   +-------------------------------- - - - - - - - - - - - - - - - +
 *   :                     Payload Data continued ...                :
 *   + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 *   |                     Payload Data (continued)                  |
 *   +---------------------------------------------------------------+
 */
public class WebSocketFrame {
    public let fin: Bool
    public let rsv1: Bool
    public let rsv2: Bool
    public let rsv3: Bool
    public let opcode: WebSocketOpcode
    public let masked: Bool
    public let payloadLength: Int64
    public let maskKey: Array<UInt8>
    public let payloadData: Array<UInt8>

    public init(
        fin!: Bool = true,
        rsv1!: Bool = false,
        rsv2!: Bool = false,
        rsv3!: Bool = false,
        opcode!: WebSocketOpcode = WebSocketOpcode.Text,
        masked!: Bool = false,
        payloadLength!: Int64 = 0,
        maskKey!: Array<UInt8> = [],
        payloadData!: Array<UInt8> = []
    ) {
        this.fin = fin
        this.rsv1 = rsv1
        this.rsv2 = rsv2
        this.rsv3 = rsv3
        this.opcode = opcode
        this.masked = masked
        this.payloadLength = payloadLength
        this.maskKey = maskKey
        this.payloadData = payloadData
    }
}

/**
 * 从原始字节解析 WebSocket 帧。
 * 返回解析后的帧，或在无效数据时抛出异常。
 *
 * @param data  从帧头开始的原始字节
 * @return 解析后的 WebSocketFrame
 * @throws Exception 帧无效或不完整时抛出
 */
public func parseWebSocketFrame(data: Array<UInt8>): WebSocketFrame {
    if (data.size < 2) {
        throw Exception("WebSocket frame too short: need at least 2 bytes")
    }

    let b0 = data[0]
    let b1 = data[1]

    let fin = (b0 & 0x80) != 0
    let rsv1 = (b0 & 0x40) != 0
    let rsv2 = (b0 & 0x20) != 0
    let rsv3 = (b0 & 0x10) != 0
    let opcodeVal = b0 & 0x0f

    let masked = (b1 & 0x80) != 0
    var payloadLen = Int64(b1 & 0x7f)

    var offset: Int64 = 2

    // 扩展负载长度
    if (payloadLen == 126) {
        if (data.size < offset + 2) {
            throw Exception("WebSocket frame too short for extended payload length (16-bit)")
        }
        payloadLen = (Int64(data[offset]) << 8) | Int64(data[offset + 1])
        offset += 2
    } else if (payloadLen == 127) {
        if (data.size < offset + 8) {
            throw Exception("WebSocket frame too short for extended payload length (64-bit)")
        }
        // 64 位长度（我们仅支持到 Int64 最大值）
        var len: Int64 = 0
        var i: Int64 = 0
        while (i < 8) {
            len = (len << 8) | Int64(data[offset + i])
            i++
        }
        payloadLen = len
        offset += 8
    }

    // 掩码键
    var maskKey: Array<UInt8> = []
    if (masked) {
        if (data.size < offset + 4) {
            throw Exception("WebSocket frame too short for mask key")
        }
        maskKey = [data[offset], data[offset + 1], data[offset + 2], data[offset + 3]]
        offset += 4
    }

    // 负载数据
    if (payloadLen > 0) {
        if (data.size < offset + payloadLen) {
            throw Exception("WebSocket frame too short for payload data")
        }
    }

    var payloadData: Array<UInt8> = []
    if (payloadLen > 0) {
        payloadData = Array<UInt8>(payloadLen, repeat: 0)
        if (masked) {
            let mk0 = maskKey[0]
            let mk1 = maskKey[1]
            let mk2 = maskKey[2]
            let mk3 = maskKey[3]
            let alignedEnd = payloadLen - (payloadLen % 4)
            var i: Int64 = 0
            while (i < alignedEnd) {
                payloadData[i] = data[offset + i] ^ mk0
                payloadData[i + 1] = data[offset + i + 1] ^ mk1
                payloadData[i + 2] = data[offset + i + 2] ^ mk2
                payloadData[i + 3] = data[offset + i + 3] ^ mk3
                i += 4
            }
            let k0 = maskKey[0]
            let k1 = maskKey[1]
            let k2 = maskKey[2]
            let k3 = maskKey[3]
            while (i < payloadLen) {
                payloadData[i] = data[offset + i] ^ k0
                i++
                if (i >= payloadLen) { break }
                payloadData[i] = data[offset + i] ^ k1
                i++
                if (i >= payloadLen) { break }
                payloadData[i] = data[offset + i] ^ k2
                i++
                if (i >= payloadLen) { break }
                payloadData[i] = data[offset + i] ^ k3
                i++
            }
        } else {
            data.copyTo(payloadData, offset, 0, payloadLen)
        }
    }

    // 将操作码值映射到枚举
    let opcode = match (opcodeVal) {
        case 0x00 => WebSocketOpcode.Continuation
        case 0x01 => WebSocketOpcode.Text
        case 0x02 => WebSocketOpcode.Binary
        case 0x08 => WebSocketOpcode.Close
        case 0x09 => WebSocketOpcode.Ping
        case 0x0a => WebSocketOpcode.Pong
        case _ => throw Exception("Unknown WebSocket opcode: 0x${opcodeVal.toString()}")
    }

    // RFC 6455 §5.5：控制帧不得分片（FIN 必须为 1）
    if ((opcode == WebSocketOpcode.Close || opcode == WebSocketOpcode.Ping || opcode == WebSocketOpcode.Pong) && !fin) {
        throw Exception("WebSocket control frames must not be fragmented")
    }

    WebSocketFrame(
        fin: fin, rsv1: rsv1, rsv2: rsv2, rsv3: rsv3,
        opcode: opcode, masked: masked,
        payloadLength: payloadLen,
        maskKey: maskKey, payloadData: payloadData
    )
}

/**
 * 根据 RFC 6455 有线协议规则验证收到的 WebSocket 帧。
 * 从网络解析帧后调用此函数（不适用于本地生成的帧）。
 *
 * 强制检查项：
 * - RSV 位必须为 0，除非已协商扩展（§5.2）
 * - 客户端到服务器帧必须加掩码（§5.1）
 * - 控制帧有效载荷不得超过 125 字节（§5.5）
 *
 * 如果帧有效则返回 true，否则抛出异常。
 */
public func validateWireFrame(frame: WebSocketFrame): Bool {
    // RFC 6455 §5.2：RSV 位为扩展保留
    if (frame.rsv1 || frame.rsv2 || frame.rsv3) {
        throw Exception("WebSocket RSV bits must be 0 (no extensions negotiated)")
    }
    // RFC 6455 §5.1：客户端到服务器帧必须加掩码
    if (!frame.masked) {
        throw Exception("WebSocket client frame must be masked")
    }
    // RFC 6455 §5.5：控制帧有效载荷限制
    if ((frame.opcode == WebSocketOpcode.Close || frame.opcode == WebSocketOpcode.Ping || frame.opcode == WebSocketOpcode.Pong) &&
        frame.payloadLength > 125) {
        throw Exception("WebSocket control frame payload must not exceed 125 bytes")
    }
    true
}

/**
 * 将 WebSocket 帧编码为原始字节以进行发送。
 *
 * @param opcode    帧操作码
 * @param payload   有效载荷数据字节
 * @param isMasked  有效载荷是否应加掩码（客户端→服务器帧必须加掩码）
 * @return 可供传输的已编码帧字节
 */
public func encodeWebSocketFrame(opcode: WebSocketOpcode, payload: Array<UInt8>, isMasked: Bool, rsv1 !: Bool = false): Array<UInt8> {
    // 计算帧大小
    let payloadLen = payload.size
    var frameSize: Int64 = 2  // 最小头部长度

    if (payloadLen >= 126 && payloadLen <= 65535) {
        frameSize += 2  // 16 位扩展长度
    } else if (payloadLen > 65535) {
        frameSize += 8  // 64 位扩展长度
    }

    if (isMasked) {
        frameSize += 4  // 掩码密钥
    }
    frameSize += payloadLen

    let frame = Array<UInt8>(frameSize, repeat: 0)
    var offset: Int64 = 0

    // 第一个字节：FIN (1) + 操作码
    let opcodeVal = opcode.toUInt8()
        var b0: UInt8 = 0x80 | opcodeVal  // FIN 位 + 操作码
    if (rsv1) { b0 = b0 | 0x40 }  // RSV1 位（Per-Message Deflate）
    frame[offset] = b0
    offset++

    // 第二个字节：MASK + 负载长度
    if (isMasked) {
        frame[offset] = 0x80
    }
    if (payloadLen < 126) {
        frame[offset] = frame[offset] | UInt8(payloadLen)
        offset++
    } else if (payloadLen <= 65535) {
        frame[offset] = frame[offset] | 126
        offset++
        frame[offset] = UInt8((payloadLen >> 8) & 0xff)
        offset++
        frame[offset] = UInt8(payloadLen & 0xff)
        offset++
    } else {
        frame[offset] = frame[offset] | 127
        offset++
        // 64 位长度
        var i: Int64 = 56
        while (i >= 0) {
            frame[offset] = UInt8((payloadLen >> i) & 0xff)
            offset++
            i -= 8
        }
    }

    // 掩码键 + 掩码负载
    if (isMasked) {
        // 根据 RFC 6455 第 5.3 节使用加密随机掩码密钥
        // "掩码密钥必须从强熵源派生"
        let maskKey = secureRandom(4)
        frame[offset] = maskKey[0]; offset++
        frame[offset] = maskKey[1]; offset++
        frame[offset] = maskKey[2]; offset++
        frame[offset] = maskKey[3]; offset++

        let mk0 = maskKey[0]
        let mk1 = maskKey[1]
        let mk2 = maskKey[2]
        let mk3 = maskKey[3]
        let alignedEnd = payloadLen - (payloadLen % 4)
        var i: Int64 = 0
        while (i < alignedEnd) {
            frame[offset + i] = payload[i] ^ mk0
            frame[offset + i + 1] = payload[i + 1] ^ mk1
            frame[offset + i + 2] = payload[i + 2] ^ mk2
            frame[offset + i + 3] = payload[i + 3] ^ mk3
            i += 4
        }
        while (i < payloadLen) {
            frame[offset + i] = payload[i] ^ maskKey[i % 4]
            i++
        }
    } else {
        // 直接复制负载
        payload.copyTo(frame, 0, offset, payloadLen)
    }

    frame
}
