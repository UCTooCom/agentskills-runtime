package quic_cj

/// 建立到指定地址的 QUIC 连接。
public func dialAddr(addr: String, config: Config): Option<Conn> {
    let cleanAddr = addr.trimAscii()
    let transport = Transport(":0", config)
    transport.dial(cleanAddr)
}

/// 用默认配置建立 QUIC 连接。
public func dial(addr: String): Option<Conn> {
    dialAddr(addr.trimAscii(), Config())
}

/// 用指定配置建立到指定主机和端口的 QUIC 连接。
public func dial(host: String, port: UInt16, config: Config): Option<Conn> {
    dialAddr(host.trimAscii() + ":" + Int64(port).toString(), config)
}
