package activemq4cj.client.api

/**
 * openwire协议上下文，记录协商后的openwire选项和对应版本的Marshaller
 */
public class OpenWireContext <: Equatable<OpenWireContext> & Hashable & ToString {
    public static let DEFAULT_WIRE_VERSION: Int32 = Int32(CommandTypes.PROTOCOL_VERSION)
    public static let DEFAULT_MAX_FRAME_SIZE: Int64 = Int64.Max

    private var versionVal: Int32 = 0
    private var stackTraceEnabledVal: Bool = false
    private var tcpNoDelayEnabledVal: Bool = false
    private var cacheEnabledVal: Bool = false
    private var tightEncodingEnabledVal: Bool = false
    private var sizePrefixDisabledVal: Bool = false
    private var maxFrameSizeEnabledVal: Bool = true
    private var maxFrameSizeVal: Int64 = DEFAULT_MAX_FRAME_SIZE

    private var dataMarshallersVal: Array<DataStreamMarshaller>

    private var cacheManagerVal: AtomicOptionReference<CacheManager> = AtomicOptionReference<CacheManager>()

    public init(dataStreamMarshaller: Array<DataStreamMarshaller>) {
        this.versionVal = DEFAULT_WIRE_VERSION
        this.dataMarshallersVal = dataStreamMarshaller
    }

    public init(version: Int32, dataStreamMarshaller: Array<DataStreamMarshaller>) {
        this.versionVal = version
        this.dataMarshallersVal = dataStreamMarshaller
    }

    public func getDataStreamMarshaller(commandType: UInt8): DataStreamMarshaller {
        let dsm = dataMarshallers[Int64(commandType & 0xFF)]
        dsm.openWireContext = this
        return dsm
    }

    protected func enableCache(cacheSize: Int32) {
        cacheManagerVal.compareAndSwap(None, CacheManager(Int64(cacheSize)))
    }

    public mut prop dataMarshallers: Array<DataStreamMarshaller> {
        get() {
            return this.dataMarshallersVal
        }
        set(value) {
            this.dataMarshallersVal = value
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

    public mut prop stackTraceEnabled: Bool {
        get() {
            return this.stackTraceEnabledVal
        }
        set(value) {
            this.stackTraceEnabledVal = value
        }
    }

    public mut prop tcpNoDelayEnabled: Bool {
        get() {
            return this.tcpNoDelayEnabledVal
        }
        set(value) {
            this.tcpNoDelayEnabledVal = value
        }
    }

    public mut prop cacheEnabled: Bool {
        get() {
            return this.cacheEnabledVal
        }
        set(value) {
            this.cacheEnabledVal = value
        }
    }

    public mut prop tightEncodingEnabled: Bool {
        get() {
            return this.tightEncodingEnabledVal
        }
        set(value) {
            this.tightEncodingEnabledVal = value
        }
    }

    public mut prop sizePrefixDisabled: Bool {
        get() {
            return this.sizePrefixDisabledVal
        }
        set(value) {
            this.sizePrefixDisabledVal = value
        }
    }

    public mut prop maxFrameSizeEnabled: Bool {
        get() {
            return this.maxFrameSizeEnabledVal
        }
        set(value) {
            this.maxFrameSizeEnabledVal = value
        }
    }

    public mut prop maxFrameSize: Int64 {
        get() {
            return this.maxFrameSizeVal
        }
        set(value) {
            this.maxFrameSizeVal = value
        }
    }

    public prop cacheManager: CacheManager {
        get() {
            if (let Some(cacheManager) <- cacheManagerVal.load()) {
                return cacheManager
            }
            throw ActiveMQException("Cache not available")
        }
    }

    public operator func ==(other: OpenWireContext): Bool {
        if (stackTraceEnabled != other.stackTraceEnabled) {
            return false
        }
        if (cacheEnabled != other.cacheEnabled) {
            return false
        }
        if (version != other.version) {
            return false
        }
        if (tightEncodingEnabled != other.tightEncodingEnabled) {
            return false
        }
        if (sizePrefixDisabled != other.sizePrefixDisabled) {
            return false
        }
        if (maxFrameSizeEnabled != other.maxFrameSizeEnabled) {
            return false
        }
        return true
    }

    public operator func !=(other: OpenWireContext): Bool {
        if (stackTraceEnabled != other.stackTraceEnabled) {
            return true
        }
        if (cacheEnabled != other.cacheEnabled) {
            return true
        }
        if (version != other.version) {
            return true
        }
        if (tightEncodingEnabled != other.tightEncodingEnabled) {
            return true
        }
        if (sizePrefixDisabled != other.sizePrefixDisabled) {
            return true
        }
        if (maxFrameSizeEnabled != other.maxFrameSizeEnabled) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        hashCode += prime * version.hashCode()
        hashCode += prime * cacheEnabled.hashCode()
        hashCode += prime * stackTraceEnabled.hashCode()
        hashCode += prime * tightEncodingEnabled.hashCode()
        hashCode += prime * sizePrefixDisabled.hashCode()
        hashCode += prime * maxFrameSizeEnabled.hashCode()
        return hashCode
    }

    public override func toString(): String {
        return "OpenWireContext{version= ${versionVal}, cacheEnabled= ${cacheEnabledVal}, stackTraceEnabled= ${stackTraceEnabledVal}, tightEncodingEnabled= ${tightEncodingEnabledVal} , sizePrefixDisabled= ${sizePrefixDisabledVal}, maxFrameSize= ${maxFrameSizeVal}, maxFrameSizeEnabled= ${maxFrameSizeEnabled}}"
    }
}
