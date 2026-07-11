/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */

package hyperion.transport

/**
 * 封装为带长度的报文
 *
 * @author yangfuping
 */
public class LengthBasedFrameEncoder <: TypedMarshallerEncoder<ByteBuffer> {
    private let lengthFieldSizeVal: Int64

    private let includesLengthFieldSize: Bool

    /**
     * 检查记录报文长度的字节数，支持1字节、2字节、4字节四种长度
     */
    static func checkFrameLength(lengthFieldSize: Int64) {
        match (lengthFieldSize) {
            case 1 | 2 | 4 => return
            case _ => throw IllegalArgumentException(
                "unsupported lengthFieldSize: ${lengthFieldSize} (expected: 1, 2, or 4)");
        }
    }

    public init(lengthFieldSize: Int64) {
        this(lengthFieldSize, false)
    }

    public prop lengthFieldSize: Int64 {
        get() {
            return lengthFieldSizeVal
        }
    }

    public init(lengthFieldSize: Int64, includesLengthFieldSize: Bool) {
        checkFrameLength(lengthFieldSize)
        this.lengthFieldSizeVal = lengthFieldSize
        this.includesLengthFieldSize = includesLengthFieldSize
    }

    public func doEncode(context: IoFilterContext, session: Session, inMessage: ByteBuffer): Unit {
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Encoding message: ${inMessage}")
        }

        var size = inMessage.limit()
        if (includesLengthFieldSize) {
            size += lengthFieldSizeVal
        }

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Write FrameLength: ${size}")
        }

        let lengthFrameBuffer = ByteBuffer.allocate(lengthFieldSizeVal)
        match (lengthFieldSizeVal) {
            case 1 =>
                if (size > Int64(UInt8.Max)) {
                    throw ProtocolCodecException(
                        "Message size ${size} is overflow, max size should not large than ${UInt8.Max}");
                }
                lengthFrameBuffer.putByte(UInt8(size))
            case 2 =>
                if (size > Int64(UInt16.Max)) {
                    throw ProtocolCodecException(
                        "Message size ${size} is overflow, max size should not large than ${UInt16.Max}");
                }
                lengthFrameBuffer.putUInt16(UInt16(size))
            case 4 =>
                lengthFrameBuffer.putUInt32(UInt32(size))
                if (size > Int64(UInt32.Max)) {
                    throw ProtocolCodecException(
                        "Message size ${size} is overflow, max size should not large than ${UInt32.Max}");
                }
            case _ => throw ProtocolCodecException(
                "Unsupported lengthFieldSize: ${lengthFieldSizeVal} (expected: 1, 2, or 4)");
        }

        // 先添加记录长度的ByteBuffer
        lengthFrameBuffer.flip()
        context.offerMessage(lengthFrameBuffer)
        // 原有的ByteBuffer
        context.offerMessage(inMessage)

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Encoding result: ${lengthFrameBuffer} and ${inMessage}")
        }
    }

    public override func toString() {
        return "LengthBasedFrameEncoder[lengthFiledSize=${lengthFieldSizeVal}, includesLengthFieldSize=${includesLengthFieldSize}]"
    }
}

/**
 * 拆解带长度的报文
 *
 * @author yangfuping
 */
public class LengthBasedFrameDecoder <: TypedUnmarsahllerDecoder<ByteBuffer> & MessageCompletedHandler {
    private let lengthFieldSizeVal: Int64

    private let includesLengthFieldSize: Bool

    public init(lengthFieldSize: Int64) {
        this(lengthFieldSize, false)
    }

    public init(lengthFieldSize: Int64, includesLengthFieldSize: Bool) {
        LengthBasedFrameEncoder.checkFrameLength(lengthFieldSize)
        this.lengthFieldSizeVal = lengthFieldSize
        this.includesLengthFieldSize = includesLengthFieldSize
    }

    public prop lengthFieldSize: Int64 {
        get() {
            return lengthFieldSizeVal
        }
    }

    public func messageCompleted(buffer: ByteBuffer, status: MessageCompletedStatus) {
        if (buffer.position() <= lengthFieldSizeVal) {
            status.completed = false
            return
        }

        var messageSize = status.messageSize
        var frameLength = 0
        if (let Some(size) <- messageSize) {
            frameLength = size
        } else {
            frameLength = Int64(getFrameLength(buffer))
            status.messageSize = Int64(frameLength)
        }

        if (buffer.position() >= frameLength) {
            status.completed = true
        }
    }

    private func getFrameLength(buffer: ByteBuffer): Int64 {
        var frameLength = 0
        match (lengthFieldSizeVal) {
            case 1 => frameLength = Int64(buffer.getByte(0))
            case 2 => frameLength = Int64(buffer.getUInt16(0))
            case 4 => frameLength = Int64(buffer.getUInt32(0))
            case _ => throw ProtocolCodecException(
                "Unsupported lengthFieldSize: ${lengthFieldSizeVal} (expected: 1, 2, or 4)");
        }

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "FrameLength: ${frameLength}")
        }

        if (!includesLengthFieldSize) {
            frameLength = frameLength + lengthFieldSizeVal
        }

        return frameLength
    }

    public func doDecode(context: IoFilterContext, session: Session, inMessage: ByteBuffer) {
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Decoding message: ${inMessage}")
        }

        var frameLength = getFrameLength(inMessage)
        if (inMessage.limit() < frameLength) {
            throw ProtocolCodecException("Message's size ${inMessage.position()} is less than expected ${frameLength}");
        }

        // 丢弃超出部分
        inMessage.limit(inMessage.position() + frameLength)
        inMessage.position(inMessage.position() + lengthFieldSizeVal)

        context.offerMessage(inMessage)

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Decoding result: ${inMessage}")
        }
    }

    public override func toString() {
        return "LengthBasedFrameDecoder[lengthFiledSize=${lengthFieldSizeVal}, includesLengthFieldSize=${includesLengthFieldSize}]"
    }
}

/**
 *
 * @author yangfuping
 */
public class LengthBasedFrameCodec <: ProtocolCodecFilter {
    public init(encoder: LengthBasedFrameEncoder, decoder: LengthBasedFrameDecoder) {
        super(encoder, decoder)

        if (encoder.lengthFieldSize != decoder.lengthFieldSize) {
            throw IllegalArgumentException(
                "The length field of LengthBasedFrameEncoder and LengthBasedFrameDecoder not the same,  encoder lengthFieldSize: ${encoder.lengthFieldSize}, decoder lengthFieldSize: ${decoder.lengthFieldSize}"
            )
        }
    }
}
