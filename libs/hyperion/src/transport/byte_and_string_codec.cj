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
 * 将String转换为ByteBuffer
 *
 * @author yangfuping
 */
public class StringToByteMessageEncoder <: TypedMarshallerEncoder<String> {
    public func doEncode(context: IoFilterContext, session: Session, outMessage: String): Unit {
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Encoding message: ${outMessage}")
        }

        let data = outMessage.toArray()
        let byteBuffer = ByteBuffer.wrap(data)

        context.offerMessage(byteBuffer)

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Encoding result: ${byteBuffer}")
        }
    }

    public override func toString() {
        return "StringToByteMessageEncoder"
    }
}

/**
 * 将ByteBuffer转换为String
 *
 * @author yangfuping
 */
public class ByteToStringMessageDecoder <: TypedUnmarsahllerDecoder<ByteBuffer> {
    public func doDecode(context: IoFilterContext, session: Session, inMessage: ByteBuffer): Unit {
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Decoding message: ${inMessage}")
        }

        let buffer = inMessage.toArray()

        let result = String.fromUtf8(buffer)

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Decoding result: ${result}")
        }

        context.offerMessage(result)
    }

    public override func toString() {
        return "ByteToStringMessageDecoder"
    }
}

/**
 *
 * @author yangfuping
 */
public class ByteAndStringCodec <: ProtocolCodecFilter {
    public init() {
        super(StringToByteMessageEncoder(), ByteToStringMessageDecoder())
    }
}
