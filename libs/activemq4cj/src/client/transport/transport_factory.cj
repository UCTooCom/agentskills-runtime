package activemq4cj.client.transport

public abstract class TransportFactory {
    private static let TRANSPORT_FACTORYS: ConcurrentHashMap<String, TransportFactory> = ConcurrentHashMap<String, TransportFactory>(
    )

    private static func findTransportFactory(location: URL): TransportFactory {
        if (let Some(tf) <- TRANSPORT_FACTORYS.get(location.scheme)) {
            return tf
        }
        var tf: TransportFactory = match (location.scheme) {
            case "failover" => FailoverTransportFactory()
            case _ => TcpTransportFactory()
        }

        TRANSPORT_FACTORYS.put(location.scheme, tf)
        return tf
    }

    public static func connect(location: URL): Transport {
        let tf: TransportFactory = findTransportFactory(location)
        return tf.doConnect(location)
    }

    protected open func doConnect(location: URL): Transport {
        var options = IntrospectionSupport.extractProperties<?String>(URLSupport.parseQuery(location), "wireFormat.")
        if (!options.contains("Host")) {
            options.add("Host", location.hostName)
        }
        //线程池参数同样允许在brokerURL上配置
        let threadPoolConfig: ThreadPoolConfig = parseThreadPoolConfig(location.queryForm)
        let wf: WireFormat = createWireFormat(options)
        let transport: Transport = createTransport(location, wf, threadPoolConfig)
        let rc: Transport = configure(transport, wf)
        return rc
    }

    protected static func compositeConnect(location: URL): Transport {
        let tf: TransportFactory = findTransportFactory(location)
        return tf.doCompositeConnect(location)
    }

    protected func doCompositeConnect(location: URL): Transport {
        let options: HashMap<String, ?String> = URLSupport.parseQuery(location)

        let threadPoolConfig: ThreadPoolConfig = parseThreadPoolConfig(location.queryForm)
        let wf: WireFormat = createWireFormat(IntrospectionSupport.extractProperties<?String>(options, "wireFormat."))
        let transport: Transport = createTransport(location, wf, threadPoolConfig)
        let rc: Transport = compositeConfigure(transport, wf)
        IntrospectionSupport.setProperties(transport, TypeConversionSupport.convertMap<String>(options))
        return rc
    }

    private func configure(transport: Transport, wf: WireFormat): Transport {
        var rc = compositeConfigure(transport, wf)
        return ResponseCorrelator(rc)
    }

    private func parseThreadPoolConfig(form: Form): ThreadPoolConfig {
        //线程池参数
        let threadPoolConfig: ThreadPoolConfig = ThreadPoolConfig()
        if (let Some(threadPoolName) <- form.get("threadPoolName")) {
            threadPoolConfig.name = threadPoolName
        } else {
            threadPoolConfig.name = "ActiveMQClient"
        }
        if (let Some(queueSize) <- form.get("queueSize")) {
            threadPoolConfig.queueSize = Int64.parse(queueSize)
        } else {
            threadPoolConfig.queueSize = 4096
        }
        if (let Some(maxThreads) <- form.get("maxThreads")) {
            threadPoolConfig.maxThreads = Int64.parse(maxThreads)
        } else {
            threadPoolConfig.maxThreads = 64
        }
        if (let Some(minThreads) <- form.get("minThreads")) {
            threadPoolConfig.minThreads = Int64.parse(minThreads)
        }
        if (let Some(threadIdleTimeout) <- form.get("threadIdleTimeout")) {
            threadPoolConfig.threadIdleTimeout = Duration.minute * Int64.parse(threadIdleTimeout)
        }
        return threadPoolConfig
    }

    protected func createWireFormat(options: HashMap<String, ?String>): WireFormat {
        let factory: WireFormatFactory = createWireFormatFactory(options)
        let format: WireFormat = factory.createWireFormat()
        return format
    }

    protected func createWireFormatFactory(options: HashMap<String, ?String>): WireFormatFactory {
        let wff: OpenWireFormatFactory = OpenWireFormatFactory()
        //由于反射尚不支持enum类型，所以所有的option类型的变量手动设置
        if (let Some(host) <- options.remove("host")) {
            wff.host = host
        }
        if (let Some(providerName) <- options.remove("providerName")) {
            wff.providerName = providerName
        }
        if (let Some(platformDetails) <- options.remove("platformDetails")) {
            wff.platformDetails = platformDetails
        }
        if (let Some(providerVersion) <- options.remove("providerVersion")) {
            wff.providerVersion = providerVersion
        }
        //设置参数
        IntrospectionSupport.setProperties(wff, TypeConversionSupport.convertMap<String>(options))
        return wff
    }

    protected open func createTransport(location: URL, wf: WireFormat, threadPoolConfig: ThreadPoolConfig): Transport {
        throw ActiveMQException("createTransport() method not implemented!")
    }

    protected open func compositeConfigure(transport: Transport, wf: WireFormat): Transport {
        throw ActiveMQException("configure() method not implemented!")
    }
}
