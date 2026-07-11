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
 * 编码器
 *
 * @author yangfuping
 */
public interface ProtocolEncoder <: ToString {
    func supportEncode(message: Any): Bool

    /**
     * 编码
     *
     */
    func encode(context: IoFilterContext, session: Session, outMessage: Any): Unit
}

/**
 * 解码器
 *
 *
 * @author yangfuping
 */
public interface ProtocolDecoder <: ToString {
    func supportDecode(message: Any): Bool

    /**
     * 解码
     *
     */
    func decode(context: IoFilterContext, session: Session, inMessage: Any): Unit
}

/**
 * 编解码结果记录
 *
 * @author yangfuping
 */
public open class ProtocolCodecResult<T> {
    protected let messages = LinkedList<T>()

    public func offer(message: T): Unit {
        messages.addLast(message)
    }

    public func getMessages(): LinkedList<T> {
        return messages
    }

    public func takeMessages(): ?T {
        return messages.removeFirst()
    }
}

/**
 * 编解码异常
 *
 * @author yangfuping
 */
public open class ProtocolCodecException <: TransportException {
    public init() {
    }

    public init(message: String) {
        super(message)
    }

    public init(message: String, cause: Exception) {
        super(message, cause)
    }
}

/**
 * 带泛型支持的编码器
 *
 * @author yangfuping
 */
public abstract class TypedProtocolEncoder<MARSHALLER, UNMARSHALLER> <: ProtocolEncoder {
    protected static let logger = LoggerFactory.getLogger("transport")

    public open override func supportEncode(message: Any): Bool {
        if (let Some(message) <- toEncodeMessage(message)) {
            return true
        }

        return false
    }

    public open func toEncodeMessage(outMessage: Any): ?MARSHALLER {
        return outMessage as MARSHALLER
    }

    /**
     * 编码
     *
     */
    public open override func encode(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        if (context.isExceptionCaughted()) {
            return
        }

        if (let Some(message) <- toEncodeMessage(outMessage)) {
            let codecResult = doEncode(session, message)

            for (mesage in codecResult.getMessages()) {
                context.offerMessage(mesage)
            }
        } else {
            let exception = ProtocolCodecException("Could not convert to EncodeMessage by ${toString()}")
            context.exceptionCaught(exception)
        }
    }

    public open func doEncode(session: Session, outMessage: MARSHALLER): ProtocolCodecResult<UNMARSHALLER>
}

/**
 * 带泛型支持的解码器
 *
 * @author yangfuping
 */
public abstract class TypedProtocolDecoder<UNMARSHALLER, MARSHALLER> <: ProtocolDecoder {
    protected static let logger = LoggerFactory.getLogger("transport")

    public open override func supportDecode(message: Any): Bool {
        if (let Some(message) <- toDecodeMessage(message)) {
            return true
        }

        return false
    }

    public open func toDecodeMessage(outMessage: Any): ?UNMARSHALLER {
        return outMessage as UNMARSHALLER
    }

    /**
     * 编码
     *
     */
    public open func decode(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        if (context.isExceptionCaughted()) {
            return
        }

        if (let Some(message) <- toDecodeMessage(outMessage)) {
            let codecResult = doDecode(session, message)

            for (mesage in codecResult.getMessages()) {
                context.offerMessage(mesage)
            }
        } else {
            let exception = ProtocolCodecException("Could not convert to decodeMessage by ${toString()}")
            context.exceptionCaught(exception)
        }
    }

    public open func doDecode(session: Session, outMessage: UNMARSHALLER): ProtocolCodecResult<MARSHALLER>
}

/**
 * 带泛型支持的编码器
 *
 * @author yangfuping
 */
public abstract class TypedMarshallerEncoder<MARSHALLER> <: ProtocolEncoder {
    protected static let logger = LoggerFactory.getLogger("transport")

    public open override func supportEncode(message: Any): Bool {
        if (let Some(message) <- toEncodeMessage(message)) {
            return true
        }

        return false
    }

    public open func toEncodeMessage(outMessage: Any): ?MARSHALLER {
        return outMessage as MARSHALLER
    }

    /**
     * 编码
     *
     */
    public open override func encode(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        if (context.isExceptionCaughted()) {
            return
        }

        if (let Some(message) <- toEncodeMessage(outMessage)) {
            doEncode(context, session, message)
        } else {
            let exception = ProtocolCodecException("Could not convert to EncodeMessage by ${toString()}")
            context.exceptionCaught(exception)
        }
    }

    public open func doEncode(context: IoFilterContext, session: Session, outMessage: MARSHALLER): Unit
}

/**
 * 带泛型支持的解码器
 *
 * @author yangfuping
 */
public abstract class TypedUnmarsahllerDecoder<UNMARSHALLER> <: ProtocolDecoder {
    protected static let logger = LoggerFactory.getLogger("transport")

    public open override func supportDecode(message: Any): Bool {
        if (let Some(message) <- toDecodeMessage(message)) {
            return true
        }

        return false
    }

    public open func toDecodeMessage(outMessage: Any): ?UNMARSHALLER {
        return outMessage as UNMARSHALLER
    }

    /**
     * 编码
     *
     */
    public open func decode(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        if (context.isExceptionCaughted()) {
            return
        }

        if (let Some(message) <- toDecodeMessage(outMessage)) {
            doDecode(context, session, message)
        } else {
            let exception = ProtocolCodecException("Could not convert to decodeMessage by ${toString()}")
            context.exceptionCaught(exception)
        }
    }

    public open func doDecode(context: IoFilterContext, session: Session, outMessage: UNMARSHALLER): Unit
}

/**
 * 编解码处理器
 *
 *
 * @author yangfuping
 */
public open class ProtocolCodecFilter <: SingularMessageIoFilter {
    private let encoder: ProtocolEncoder

    private let decoder: ProtocolDecoder

    public init(encoder: ProtocolEncoder, decoder: ProtocolDecoder) {
        this.encoder = encoder
        this.decoder = decoder
    }

    public func getEncoder(): ProtocolEncoder {
        return encoder
    }

    public func getDecoder(): ProtocolDecoder {
        return decoder
    }

    /**
     * 处理入栈消息
     */
    public open func processInboundMessage(context: IoFilterContext, session: Session, inMessage: Any): Unit {
        try {
            decoder.decode(context, session, inMessage)
        } catch (ex: Exception) {
            context.exceptionCaught(ex)
        }
    }

    public open func processInboundException(context: IoFilterContext, session: Session, ex: Exception): Unit {
        context.exceptionCaught(ex)
    }

    /**
     *  处理出栈消息
     */
    public open func processOutboundMessage(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        try {
            encoder.encode(context, session, outMessage)
        } catch (ex: Exception) {
            context.exceptionCaught(ex)
        }
    }

    public open func processOutboundException(context: IoFilterContext, session: Session, ex: Exception): Unit {
        context.exceptionCaught(ex)
    }

    public override func toString() {
        return "ProtocolCodecFilter [encoder: ${encoder.toString()}, decoder: ${decoder.toString()}]"
    }
}
