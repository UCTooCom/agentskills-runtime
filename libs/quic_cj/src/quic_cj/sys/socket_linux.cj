package quic_cj.sys
import quic_cj.protocol.ECN
import std.net.IPAddress

// ── 苍颉 FFI：Linux POSIX 套接字声明 ──
// 使用 'foreign func' 进行 FFI，使用 CPointer<Byte> 保证兼容性
// 使用来自 jinguissl_core.crypto.utils 的 acquireArrayRawData

@When[os == "Linux"]
foreign func socket(domain: Int64, socketType: Int64, protocol: Int64): Int64

@When[os == "Linux"]
foreign func bind(sockfd: Int64, addr: CPointer<Byte>, addrlen: Int64): Int64

@When[os == "Linux"]
foreign func sendto(sockfd: Int64, buf: CPointer<Byte>, len: Int64, flags: Int64,
    destAddr: CPointer<Byte>, addrLen: Int64): Int64

@When[os == "Linux"]
foreign func recvfrom(sockfd: Int64, buf: CPointer<Byte>, len: Int64, flags: Int64,
    srcAddr: CPointer<Byte>, addrLen: CPointer<Byte>): Int64

@When[os == "Linux"]
foreign func setsockopt(sockfd: Int64, level: Int64, optname: Int64,
    optval: CPointer<Byte>, optlen: Int64): Int64

@When[os == "Linux"]
foreign func sendmsg(sockfd: Int64, msg: CPointer<Byte>, flags: Int64): Int64

@When[os == "Linux"]
foreign func recvmsg(sockfd: Int64, msg: CPointer<Byte>, flags: Int64): Int64

@When[os == "Linux"]
foreign func close(sockfd: Int64): Int64


/// 构建 IPv4 sockaddr/// 构建用于绑定的 IPv4 sockaddr_in 结构体（16 字节）。
private func buildSockaddrIn(host: String, port: Int64): Array<Byte> {
    var addr = Array<Byte>(16, repeat: 0u8)
    addr[0] = 0x02u8; addr[1] = 0x00u8  // AF_INET = 2（小端序）
    addr[2] = UInt8((port >> 8) & 0xff)  // sin_port（大端序）
    addr[3] = UInt8(port & 0xff)
    // sin_addr = INADDR_ANY（0.0.0.0）
    // sin_zero = 8 字节填充（已为零）
    addr
}

/// 使用 POSIX FFI 套接字在 Linux 上实现 RawConn。
public class LinuxRawConn <: RawConn {
    private var fd: Int64 = -1
    private var caps: ConnCapabilities = ConnCapabilities()
    private var localHost: String = ""
    private var localPort: Int64 = 0

    public init(host: String, port: Int64) {
        this.localHost = host
        this.localPort = port
        let fd = createUdpSocket(host, port)
        if (fd >= 0) {
            this.fd = fd
            let isDF = setSocketOptions(fd)
            caps.df = isDF
            caps.ecn = true
            // GSO 可用性取决于内核版本（>= 5.0）
            // 我们假设它受支持；运行时错误处理回退
            caps.gso = true
        }
    }
    public func readPacket(): ReceivedPacket {
        let data = readPacketFromFd(fd)
        if (data.size == 0) { return ReceivedPacket() }
        let pkt = ReceivedPacket()
        pkt.data = data
        pkt.remoteAddr = localHost + ":" + Int64(localPort).toString()
        pkt
    }

    public func writePacket(data: Array<Byte>, addr: String, ecn: ECN): Int64 {
        writePacketToFd(fd, data, addr.toArray())
    }

    public func localAddr(): IPAddress { IPAddress.parse(localHost) }
    public func setReadDeadline(deadlineMs: Int64): Unit {}
    @When[os == "Linux"]
    public func close(): Unit {
        if (fd >= 0) {
            unsafe { let _ = close(fd) }
            fd = -1
        }
    }
    @When[os != "Linux"]
    public func close(): Unit {
        fd = -1
    }
    public func capabilities(): ConnCapabilities { caps }
    public func injectFd(fd: Int64): Unit {
        this.fd = fd
        caps.ecn = true
        caps.df = true
        caps.gso = true
    }
}

// ── FFI 集成：不安全套接字包装函数 ──
// 这些必须从不安全上下文或不安全函数中调用。
// 它们在 @When[os == "Linux"] 后面，确保只在 Linux 上编译。

// ── FFI 包装函数 ──
// 使用 acquireArrayRawData 进行数组到 CPointer 的转换。
// 直接使用原始 POSIX 常量值（例如 AF_INET=2，SOCK_DGRAM=2）
// 避免文件级常量与 @When[os == "Linux"] 的可见性问题。

@When[os == "Linux"]
public func linuxCreateUdpSocket(port: Int64): Int64 {
    let addr = buildSockaddrIn("0.0.0.0", port)
    unsafe {
        let fd = socket(2, 2, 0)  // AF_INET=2，SOCK_DGRAM=2
        if (fd < 0) { -1 } else {
            var raw = acquireArrayRawData<Byte>(addr)
            let result = bind(fd, raw.pointer, 16)
            releaseArrayRawData<Byte>(raw)
            if (result < 0) { close(fd); -1 } else { fd }
        }
    }
}

@When[os == "Linux"]
public func linuxSetSocketOptions(fd: Int64): Bool {
    unsafe {
        let v: Array<Byte> = [0x00u8, 0x00u8, 0x00u8, 0x00u8]
        var raw = acquireArrayRawData<Byte>(v)
        let _ = setsockopt(fd, 1, 8, raw.pointer, 4)    // SOL_SOCKET=1，SO_RCVBUF=8
        let _ = setsockopt(fd, 1, 7, raw.pointer, 4)    // SO_SNDBUF=7
        let _ = setsockopt(fd, 0, 10, raw.pointer, 4)   // SOL_IP=0，IP_MTU_DISCOVER=10
        let _ = setsockopt(fd, 0, 13, raw.pointer, 4)   // IP_RECVTOS=13
        releaseArrayRawData<Byte>(raw)
        true
    }
}

@When[os == "Linux"]
public func linuxWriteToFd(fd: Int64, data: Array<Byte>, addr: Array<Byte>): Int64 {
    unsafe {
        var dRaw = acquireArrayRawData<Byte>(data)
        var aRaw = acquireArrayRawData<Byte>(addr)
        let n = sendto(fd, dRaw.pointer, data.size, 0, aRaw.pointer, addr.size)
        releaseArrayRawData<Byte>(dRaw)
        releaseArrayRawData<Byte>(aRaw)
        n
    }
}

@When[os == "Linux"]
public func linuxReadFromFd(fd: Int64, buf: Array<Byte>): Int64 {
    unsafe {
        var bRaw = acquireArrayRawData<Byte>(buf)
        let addrLen: Array<Byte> = [0x10u8, 0u8, 0u8, 0u8]
        var alRaw = acquireArrayRawData<Byte>(addrLen)
        let dummy: Array<Byte> = [0u8]
        var dmRaw = acquireArrayRawData<Byte>(dummy)
        let n = recvfrom(fd, bRaw.pointer, buf.size, 0, dmRaw.pointer, alRaw.pointer)
        releaseArrayRawData<Byte>(bRaw)
        releaseArrayRawData<Byte>(alRaw)
        releaseArrayRawData<Byte>(dmRaw)
        n
    }
}

// ── LinuxRawConn FFI 集成 ──
// 允许在构造后设置文件描述符（由 newRawConn 覆盖使用）

@When[os == "Linux"]
public func newRawConn(host: String, port: Int64): RawConn {
    let fd = linuxCreateUdpSocket(port)
    if (fd < 0) { return StubRawConn(host, port) }
    let conn = LinuxRawConn(host, port)
    conn.injectFd(fd)
    conn
}
