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
package activemq4cj.client.transport.codec

public class ByteToActiveMQCommandDecoder <: TypedProtocolDecoder<ByteBuffer, DataStructure> {
    private let wireFormat: WireFormat

    public init(wireFormat: WireFormat) {
        this.wireFormat = wireFormat
    }

    public func doDecode(session: Session, inMessage: ByteBuffer): ProtocolCodecResult<DataStructure> {
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Decoding message: ${inMessage}")
        }
        let out = ProtocolCodecResult<DataStructure>()
        if (inMessage.remaining() > 1) {
            let activeMQCommand = decodeActiveMQCommand(inMessage)
            out.offer(activeMQCommand)

            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Decoding result: ${activeMQCommand}")
            }
        } else {
            throw ProtocolCodecException("Failure to decode ActiveMQCommand, not enough data available")
        }
        return out
    }

    private func decodeActiveMQCommand(inMessage: ByteBuffer): DataStructure {
        return wireFormat.unmarshal(inMessage)
    }

    public override func toString() {
        return "ByteToActiveMQMessageDecoder"
    }
}

public class ActiveMQCommandToByteEncoder <: TypedProtocolEncoder<Command, ByteBuffer> {
    private let wireFormat: WireFormat

    public init(wireFormat: WireFormat) {
        this.wireFormat = wireFormat
    }

    public func doEncode(session: Session, outMessage: Command): ProtocolCodecResult<ByteBuffer> {
        let out = ProtocolCodecResult<ByteBuffer>()
        let buffer = ByteBuffer.allocate(8192, expandSupport: true)
        wireFormat.marshal(outMessage, buffer)
        out.offer(buffer)
        return out
    }

    public override func toString() {
        return "ActiveMQCommandToByteEncoder"
    }
}

public class ActiveMQCodec <: ProtocolCodecFilter {
    public init(encoder: ActiveMQCommandToByteEncoder, decoder: ByteToActiveMQCommandDecoder) {
        super(encoder, decoder)
    }
}
