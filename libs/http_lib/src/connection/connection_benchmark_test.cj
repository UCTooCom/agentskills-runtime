package http_lib.connection

/**
 * 连接层 (TLS/ALPN/安全随机数) 性能基准测试。
 */
@Test public class ConnectionBench {
    @Bench
    public func tlsConfigDefaultOperations(): Unit {
        let cfg = TlsConfig.default()
        let _ = cfg.supportsH2()
        let _ = cfg.supportsHttp1()
        let _ = cfg.negotiateProtocol(["h2", "http/1.1"])
        let _ = cfg.copy()
    }

    @Bench
    public func tlsNegotiateProtocol(): Unit {
        let cfg = TlsConfig.default()
        let _ = cfg.negotiateProtocol(["h2", "http/1.1"])
    }

    @Bench
    public func alpnParseClientHello(): Unit {
        let data = Array<Byte>(50, repeat: 0)
        let _ = extractAlpnFromClientHello(data)
    }

    @Bench
    public func benchSecureRandom32(): Unit {
        let _ = secureRandom32()
    }
}
