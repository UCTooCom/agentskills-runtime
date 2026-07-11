package activemq4cj.client.transport

public open class TcpTransportFactory <: TransportFactory {
    public override func createTransport(location: URL, wf: WireFormat, threadPoolConfig: ThreadPoolConfig): Transport {
        return TcpTransport(wf, location, threadPoolConfig)
    }

    protected override func compositeConfigure(transport: Transport, wf: WireFormat): Transport {
        var rc: Transport = transport
        if (let Some(openWireFormat) <- (wf as OpenWireFormat)) {
            rc = InactivityMonitor(rc, openWireFormat)
            rc = WireFormatNegotiator(rc, openWireFormat)
        }
        return rc
    }
}
