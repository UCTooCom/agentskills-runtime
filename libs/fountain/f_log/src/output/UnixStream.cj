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
protected import std.net.{UnixSocket, SocketAddress, UnixSocketAddress}

protected class UnixOutputStream <: OutputStream & Resource {
    private static func newSocket(addr: UnixSocketAddress, writeTimeout: ?Duration) {
        let sock = UnixSocket(addr)
        sock.connect()
        sock.writeTimeout = writeTimeout
        sock
    }
    public UnixOutputStream(private let sock: UnixSocket, private let addr: UnixSocketAddress) {}
    public init(addr: UnixSocketAddress, writeTimeout!: ?Duration = None<Duration>) {
        this(newSocket(addr, writeTimeout), addr)
    }
    public init(path: String, writeTimeout!: ?Duration = None<Duration>) {
        this(UnixSocketAddress(path), writeTimeout: writeTimeout)
    }
    public func write(buffer: Array<Byte>): Unit {
        sock.write(buffer)
    }
    public func flush(): Unit {
        sock.flush()
    }
    public func isClosed(): Bool {
        sock.isClosed()
    }
    public func close(): Unit {
        sock.close()
    }
}
