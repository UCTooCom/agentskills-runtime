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
package activemq4cj.client.command

public class WireFormatInfo <: BaseCommand & MarshallAware {
    private let MAGIC = CommandTypes.MAGIC.toArray()
    private static let MAX_PROPERTY_SIZE: Int32 = 1024 * 4

    private var marshalledPropertiesVal: ?Array<Byte> = None

    private var magicVal: Array<Byte> = MAGIC
    private var versionVal: Int32 = Int32(CommandTypes.PROTOCOL_VERSION)
    private var propertiesVal: ?HashMap<String, Any> = None
    private let mtx: ReentrantMutex = ReentrantMutex()

    public func getDataStructureType(): Byte {
        return CommandTypes.WIREFORMAT_INFO
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processWireFormat(this)
    }

    public mut prop magic: Array<Byte> {
        get() {
            return this.magicVal
        }
        set(value) {
            this.magicVal = value
        }
    }

    public mut prop version: Int32 {
        get() {
            return this.versionVal
        }
        set(value) {
            this.versionVal = value
        }
    }

    public mut prop properties: ?HashMap<String, Any> {
        get() {
            return this.propertiesVal
        }
        set(value) {
            this.propertiesVal = value
        }
    }

    public mut prop marshalledProperties: ?Array<Byte> {
        get() {
            return this.marshalledPropertiesVal
        }
        set(value) {
            this.marshalledPropertiesVal = value
        }
    }

    public func getProperty(name: String): ?Any {
        if (let Some(properties) <- properties) {
            return properties.get(name)
        } else {
            if (let Some(marshalledProperties) <- this.marshalledProperties) {
                this.properties = MarshallingSupport.unmarshalPrimitiveMap(ByteBuffer.wrap(marshalledProperties),
                    MAX_PROPERTY_SIZE)
                return getProperty(name)
            }
        }
        return None
    }

    public func clearProperties(): Unit {
        this.properties = None
        this.marshalledProperties = None
    }

    public func setProperty(name: String, value: Any) {
        lazyCreateProperties()
        if (let Some(properties) <- properties) {
            return properties.add(name, value)
        }
    }

    protected func lazyCreateProperties() {
        if (properties.isNone()) {
            synchronized(mtx) {
                if (let Some(marshalledProperties) <- this.marshalledProperties) {
                    properties = MarshallingSupport.unmarshalPrimitiveMap(ByteBuffer.wrap(marshalledProperties),
                        MAX_PROPERTY_SIZE)
                    this.marshalledProperties = None
                } else {
                    properties = HashMap<String, Any>()
                }
            }
        }
    }

    public func isValid(): Bool {
        return magic.size > 0 && magic == MAGIC
    }

    public func isCacheEnabled(): Bool {
        let value = getProperty("CacheEnabled")
        if (let Some(cacheEnabled) <- value) {
            if (let Some(cacheEnabled) <- (cacheEnabled as Bool)) {
                return cacheEnabled == true
            }
        }
        return false
    }

    public func setCacheEnabled(cacheEnabled: Bool): Unit {
        setProperty("CacheEnabled", cacheEnabled)
    }

    public func isStackTraceEnabled(): Bool {
        let value = getProperty("StackTraceEnabled")
        if (let Some(stackTraceEnabled) <- value) {
            if (let Some(stackTraceEnabled) <- (stackTraceEnabled as Bool)) {
                return stackTraceEnabled == true
            }
        }
        return false
    }

    public func setStackTraceEnabled(stackTraceEnabled: Bool) {
        setProperty("StackTraceEnabled", stackTraceEnabled)
    }

    public func isTcpNoDelayEnabled(): Bool {
        let value = getProperty("TcpNoDelayEnabled")
        if (let Some(tcpNoDelayEnabled) <- value) {
            if (let Some(tcpNoDelayEnabled) <- (tcpNoDelayEnabled as Bool)) {
                return tcpNoDelayEnabled == true
            }
        }
        return false
    }

    public func setTcpNoDelayEnabled(tcpNoDelayEnabled: Bool): Unit {
        setProperty("TcpNoDelayEnabled", tcpNoDelayEnabled)
    }

    public func isSizePrefixDisabled(): Bool {
        let value = getProperty("SizePrefixDisabled")
        if (let Some(sizePrefixDisabled) <- value) {
            if (let Some(sizePrefixDisabled) <- (sizePrefixDisabled as Bool)) {
                return sizePrefixDisabled == true
            }
        }
        return false
    }

    public func setSizePrefixDisabled(prefixPacketSize: Bool): Unit {
        setProperty("SizePrefixDisabled", prefixPacketSize)
    }

    public func isTightEncodingEnabled(): Bool {
        let value = getProperty("TightEncodingEnabled")
        if (let Some(tightEncodingEnabled) <- value) {
            if (let Some(tightEncodingEnabled) <- (tightEncodingEnabled as Bool)) {
                return tightEncodingEnabled == true
            }
        }
        return false
    }

    public func setTightEncodingEnabled(tightEncodingEnabled: Bool): Unit {
        setProperty("TightEncodingEnabled", tightEncodingEnabled)
    }

    public func getHost(): ?String {
        let value = getProperty("Host")
        if (let Some(host) <- value) {
            if (let Some(host) <- (host as String)) {
                return host
            }
        }
        return None
    }

    public func setHost(hostname: String): Unit {
        setProperty("Host", hostname)
    }

    public func getMaxInactivityDuration(): Int64 {
        let value = getProperty("MaxInactivityDuration")
        if (let Some(maxInactivityDuration) <- value) {
            if (let Some(maxInactivityDuration) <- (maxInactivityDuration as Int64)) {
                return maxInactivityDuration
            }
            return 0
        }
        return 0
    }

    public func setMaxInactivityDuration(maxInactivityDuration: Int64) {
        setProperty("MaxInactivityDuration", maxInactivityDuration)
    }

    public func getMaxInactivityDurationInitalDelay(): Int64 {
        let value = getProperty("MaxInactivityDurationInitalDelay")
        if (let Some(maxInactivityDurationInitalDelay) <- value) {
            if (let Some(maxInactivityDurationInitalDelay) <- (maxInactivityDurationInitalDelay as Int64)) {
                return maxInactivityDurationInitalDelay
            }
            return 0
        }
        return 0
    }

    public func setMaxInactivityDurationInitalDelay(maxInactivityDurationInitalDelay: Int64): Unit {
        setProperty("MaxInactivityDurationInitalDelay", maxInactivityDurationInitalDelay)
    }

    public func getMaxFrameSize(): Int64 {
        let value = getProperty("MaxFrameSize")
        if (let Some(maxFrameSize) <- value) {
            if (let Some(maxFrameSize) <- (maxFrameSize as Int64)) {
                return maxFrameSize
            }
            return 0
        }
        return 0
    }

    public func setMaxFrameSize(maxFrameSize: Int64): Unit {
        setProperty("MaxFrameSize", maxFrameSize)
    }

    public func getCacheSize(): Int32 {
        let value = getProperty("CacheSize")
        if (let Some(cacheSize) <- value) {
            if (let Some(cacheSize) <- (cacheSize as Int32)) {
                return cacheSize
            }
            return 0
        }
        return 0
    }

    public func setCacheSize(cacheSize: Int32): Unit {
        setProperty("CacheSize", cacheSize)
    }

    public func getProviderName(): ?String {
        let value = getProperty("ProviderName")
        if (let Some(providerName) <- value) {
            if (let Some(providerName) <- (providerName as String)) {
                return providerName
            }
            return None
        }
        return None
    }

    public func setProviderName(providerName: ?String) {
        setProperty("ProviderName", providerName)
    }

    public func getProviderVersion(): ?String {
        let value = getProperty("ProviderVersion")
        if (let Some(providerVersion) <- value) {
            if (let Some(providerVersion) <- (providerVersion as String)) {
                return providerVersion
            }
            return None
        }
        return None
    }

    public func setProviderVersion(providerVersion: ?String): Unit {
        setProperty("ProviderVersion", providerVersion)
    }

    public func getPlatformDetails(): ?String {
        let value = getProperty("PlatformDetails")
        if (let Some(platformDetails) <- value) {
            if (let Some(platformDetails) <- (platformDetails as String)) {
                return platformDetails
            }
            return None
        }
        return None
    }

    public func setPlatformDetails(platformDetails: ?String): Unit {
        setProperty("PlatformDetails", platformDetails)
    }

    public func isMaxFrameSizeEnabled(): Bool {
        let value = getProperty("MaxFrameSizeEnabled")
        if (let Some(maxFrameSizeEnabled) <- value) {
            if (let Some(maxFrameSizeEnabled) <- (maxFrameSizeEnabled as Bool)) {
                return maxFrameSizeEnabled == true
            }
            return false
        }
        return false
    }

    public func setMaxFrameSizeEnabled(maxFrameSizeEnabled: Bool): Unit {
        setProperty("MaxFrameSizeEnabled", maxFrameSizeEnabled)
    }

    public override func toString(): String {
        return "WireFormatInfo: {version= ${versionVal}, magic= ${String.fromUtf8(magicVal)}}"
    }

    public func beforeMarshall(): Unit {
        // Need to marshal the properties.
        if (marshalledProperties.isNone() && properties.isSome()) {
            if (let Some(properties) <- properties) {
                let byteBuffer = ByteBuffer.allocate(8192, expandSupport: true)
                MarshallingSupport.marshalPrimitiveMap(properties, byteBuffer)
                byteBuffer.flip()
                marshalledProperties = byteBuffer.toArray()
            }
        }
    }

    public override func afterMarshall(): Unit {
    }

    public override func beforeUnmarshall(): Unit {
    }

    public override func afterUnmarshall(): Unit {
    }
}
