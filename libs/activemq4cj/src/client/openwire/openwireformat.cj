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
package activemq4cj.client.openwire

public class OpenWireFormat <: WireFormat & Equatable<OpenWireFormat> & Hashable & ToString {
    public static let DEFAULT_LEGACY_VERSION: Int32 = Int32(CommandTypes.PROTOCOL_LEGACY_STORE_VERSION)
    //注册多个版本的MarshallerFactory
    private static let marshallerFactoryRegistry: HashMap<Int32, OpenWireMarshallerFactory> = HashMap<Int32, OpenWireMarshallerFactory>(
    )

    static init() {
        marshallerFactoryRegistry.add(12, MarshallerFactory())
    }

    public static let NULL_TYPE: Byte = CommandTypes.NULL
    //默认的缓存数量
    private static let MARSHAL_CACHE_SIZE: Int32 = Int32(Int16.Max / 2)

    private let context: OpenWireContext

    private var preferedWireFormatInfo: ?WireFormatInfo = None

    public init() {
        this(OpenWireContext.DEFAULT_WIRE_VERSION)
    }

    public init(version: Int32) {
        if (let Some(factory) <- marshallerFactoryRegistry.get(version)) {
            this.context = OpenWireContext(version, factory.createMarshallerMap())
        } else {
            throw ActiveMQException("This version is not supported: ${version}")
        }
    }

    /**
     * wireformatInfo协商
     */
    public func renegotiateWireFormat(info: WireFormatInfo) {
        if (let Some(preferedWireFormatInfo) <- preferedWireFormatInfo) {
            //协商版本号
            this.context.version = getMin(info.version, preferedWireFormatInfo.version)
            info.version = this.context.version
            if (let Some(factory) <- marshallerFactoryRegistry.get(this.context.version)) {
                this.context.dataMarshallers = factory.createMarshallerMap()
            } else {
                throw ActiveMQException("This version is not supported: ${this.context.version}")
            }

            this.context.maxFrameSize = getMin(preferedWireFormatInfo.getMaxFrameSize(), info.getMaxFrameSize())
            info.setMaxFrameSize(this.context.maxFrameSize)

            this.context.stackTraceEnabled = info.isStackTraceEnabled() && preferedWireFormatInfo.isStackTraceEnabled()
            info.setStackTraceEnabled(this.context.stackTraceEnabled)

            this.context.tcpNoDelayEnabled = info.isTcpNoDelayEnabled() && preferedWireFormatInfo.isTcpNoDelayEnabled()
            info.setTcpNoDelayEnabled(this.context.tcpNoDelayEnabled)

            this.context.cacheEnabled = info.isCacheEnabled() && preferedWireFormatInfo.isCacheEnabled()
            info.setCacheEnabled(this.context.cacheEnabled)

            this.context.tightEncodingEnabled = info.isTightEncodingEnabled() &&
                    preferedWireFormatInfo.isTightEncodingEnabled()
            info.setTightEncodingEnabled(this.context.tightEncodingEnabled)

            this.context.sizePrefixDisabled = info.isSizePrefixDisabled() &&
                    preferedWireFormatInfo.isSizePrefixDisabled()
            info.setSizePrefixDisabled(this.context.sizePrefixDisabled)

            if (this.context.cacheEnabled) {
                var size: Int32 = min(preferedWireFormatInfo.getCacheSize(), info.getCacheSize())
                info.setCacheSize(size)

                if (size == 0) {
                    size = MARSHAL_CACHE_SIZE
                }

                //初始化缓存
                this.context.enableCache(size)
            }
            return
        }
        throw CJMSIllegalStateException("Wireformat cannot be renegotiated.")
    }

    public func setPreferedWireFormatInfo(info: WireFormatInfo): Unit {
        this.preferedWireFormatInfo = info
    }

    public func getPreferedWireFormatInfo(): ?WireFormatInfo {
        return this.preferedWireFormatInfo
    }

    public operator override func ==(other: OpenWireFormat): Bool {
        if (this.context != other.context) {
            return false
        }
        return true
    }

    public operator override func !=(other: OpenWireFormat): Bool {
        if (this.context != other.context) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        return this.context.hashCode()
    }

    /**
     * Stream based marshaling
     */
    public func marshal(command: DataStructure, dataOut: ByteBuffer): Unit {
        if (context.cacheEnabled) {
            context.cacheManager.runMarshallCacheEvictionSweep()
        }

        let buffer = ByteBuffer.allocate(8192, expandSupport: true)
        let dsm = getDataStreamMarshaller(command.getDataStructureType())
        if (this.context.tightEncodingEnabled) {
            let commandByteBuffer = ByteBuffer.allocate(8192, expandSupport: true)
            let bs = BoolStream()
            //Tight Encoding
            dsm.tightMarshal(command, commandByteBuffer, bs)
            commandByteBuffer.flip()
            buffer.putByte(command.getDataStructureType())
            bs.marshal(buffer)
            MarshallingSupport.putByteArray(commandByteBuffer.toArray(), buffer)
        } else {
            dsm.looseMarshal(command, buffer)
        }
        buffer.flip()
        let content = buffer.toArray()
        let size = content.size
        if (this.context.maxFrameSizeEnabled && size > this.context.maxFrameSize) {
            throw TransportException("Frame size of ${size} larger than max allowed ${this.context.maxFrameSize}")
        }
        //sizePrefixDisabled被禁用，添加size前缀
        if (!this.context.sizePrefixDisabled) {
            dataOut.putInt32(Int32(size))
        }
        MarshallingSupport.putByteArray(content, dataOut)
        dataOut.flip()
    }

    /**
     * 数据包解码
     */
    public func unmarshal(dataIn: ByteBuffer): DataStructure {
        if (!this.context.sizePrefixDisabled) {
            //读取四字节长度
            let size = dataIn.getInt32()
            if (this.context.maxFrameSizeEnabled && Int64(size) > this.context.maxFrameSize) {
                throw TransportException("Frame size of ${size} larger than max allowed ${this.context.maxFrameSize}")
            }
        }
        //读取命令类型，调用对应的命令编解码器进行编解码
        let commandType = dataIn.getByte()
        let dsm = getDataStreamMarshaller(commandType)
        let data: DataStructure = dsm.createObject()

        if (this.context.tightEncodingEnabled) {
            let bs: BoolStream = BoolStream()
            bs.unmarshal(dataIn)
            dsm.tightUnmarshal(data, dataIn, bs)
        } else {
            dsm.looseUnmarshal(data, dataIn)
        }
        return data
    }

    public func setMaxFrameSize(maxFrameSize: Int64): Unit {
        this.context.maxFrameSize = maxFrameSize
    }

    public func setMaxFrameSizeEnabled(maxFrameSizeEnabled: Bool): Unit {
        this.context.maxFrameSizeEnabled = maxFrameSizeEnabled
    }

    public func getDataStreamMarshaller(commandType: UInt8): DataStreamMarshaller {
        return this.context.getDataStreamMarshaller(commandType)
    }

    /**
     * 是否包含完整的消息报文
     *
     * @param buffer
     * @param status
     */
    public func messageCompleted(buffer: ByteBuffer, status: MessageCompletedStatus): Unit {
        let orginalPos = buffer.position()
        let orginalLim = buffer.limit()
        try {
            buffer.flip()
            if (buffer.limit() < 4) {
                return
            }
            if (!this.context.sizePrefixDisabled) {
                let size = Int64(buffer.getInt32())
                if (buffer.position() + size <= buffer.limit()) {
                    status.completed = true
                }

                if (size != -1) {
                    status.messageSize = size + 4
                }
            }
        } finally {
            buffer.position(orginalPos)
            buffer.limit(orginalLim)
        }
    }

    private func getMin(value1: Int32, value2: Int32): Int32 {
        if (value1 < value2 && value1 > 0 || value2 <= 0) {
            return value1
        }
        return value2
    }

    private func getMin(value1: Int64, value2: Int64): Int64 {
        if (value1 < value2 && value1 > 0 || value2 <= 0) {
            return value1
        }
        return value2
    }

    public override func toString(): String {
        return "OpenWireFormat{context: ${this.context}}"
    }
}
