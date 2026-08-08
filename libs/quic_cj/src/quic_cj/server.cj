package quic_cj

/// 在指定地址创建 QUIC 监听器（便捷包装）。
public func listenAddr(addr: String, config: Config): Option<Listener> {
    let transport = Transport(addr.trimAsciiStart().trimAsciiEnd(), config)
    transport.listen()
}

/// 用默认配置创建 QUIC 监听器。
public func listen(addr: String): Option<Listener> {
    listenAddr(addr.trimAscii(), Config())
}

/// 用指定配置创建 QUIC 监听器。
public func listen(addr: String, config: Config): Option<Listener> {
    listenAddr(addr.trimAscii(), config)
}
