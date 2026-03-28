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
protected import std.net.{UnixDatagramSocket, SocketAddress}
import std.sync.AtomicUInt64

protected class UnixDatagramOutputStream <: OutputStream & Resource {
    private static let SERIAL = AtomicUInt64(0)

    private static func newSocket(path!: String = '/tmp/${SERIAL.fetchAdd(1)}', sendTimeout!: ?Duration,
        bufSize!: ?Int64) {
        let sock = UnixDatagramSocket(bindAt: path)
        sock.bind()
        sock.sendTimeout = sendTimeout
        if (let Some(s) <- bufSize && s > 0) {
            sock.sendBufferSize = s
        }
        sock
    }
    public UnixDatagramOutputStream(private let sock: UnixDatagramSocket, private let addr: UnixSocketAddress) {}

    public init(path: String, sendTimeout!: ?Duration = None<Duration>, bufSize!: ?Int64 = None<Int64>) {
        this(newSocket(path: path, sendTimeout: sendTimeout, bufSize: bufSize), UnixSocketAddress(path))
    }
    public func write(buffer: Array<Byte>): Unit {
        sock.sendTo(addr, buffer)
    }
    public func flush(): Unit {}
    public func isClosed(): Bool {
        sock.isClosed()
    }
    public func close(): Unit {
        sock.close()
    }
}
