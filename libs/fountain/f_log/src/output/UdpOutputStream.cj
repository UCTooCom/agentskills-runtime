/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_log.output

protected import std.io.OutputStream
protected import std.net.{UdpSocket, IPSocketAddress, SocketAddress}

protected class UdpOutputStream <: OutputStream & Resource {
    public UdpOutputStream(private let udp: UdpSocket, private let addr: IPSocketAddress) {}
    public init(addr: String, port: UInt16, sendTimeout!: ?Duration = None<Duration>) {
        let sockAddr = IPSocketAddress(addr, port)
        let sock = UdpSocket(bindAt: 0)
        sock.sendTimeout = sendTimeout
        sock.bind()
        this.udp = sock
        this.addr = sockAddr
    }
    public init(addr: String, sendTimeout!: ?Duration = None<Duration>) {
        let sockAddr = IPSocketAddress.parse(addr)
        let sock = UdpSocket(bindAt: 0)
        sock.sendTimeout = sendTimeout
        sock.bind()
        this.udp = sock
        this.addr = sockAddr
    }
    public func write(buffer: Array<Byte>): Unit {
        udp.sendTo(addr, buffer)
    }
    public func flush(): Unit {}
    public func isClosed(): Bool {
        udp.isClosed()
    }
    public func close(): Unit {
        udp.close()
    }
}
