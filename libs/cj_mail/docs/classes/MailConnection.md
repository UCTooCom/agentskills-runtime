protected class MailConnection
==============================

```cangjie
    // 连接socks5
    let tcpSocket = TcpSocket("localhost", 1080)
    tcpSocket.writeTimeout = Duration.second * 10 
    tcpSocket.readTimeout = Duration.second * 10 
    tcpSocket.connect()
    // 使用socks5连接到"smtp.gmail.com"
    let sSocket = Socks5Socket(tcpSocket, "smtp.gmail.com", 443)
    sSocket.connect()
    // 建立连接
    var config = TlsClientConfig()
    config.domain = "smtp.gmail.com"
    let tlsSocket = TlsSocket.client(sSocket,clientConfig:config)
    tlsSocket.handshake()
    // 启动SMTP/IMAP/POP
    Smtp(tlsSocket)
```
