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
package f_net

internal import std.collection.concurrent.{ArrayBlockingQueue, ConcurrentHashMap}
internal import std.net.{TcpSocket, TcpServerSocket, SocketAddress}
internal import std.process.Process
internal import std.sync.AtomicBool
internal import f_concurrent.{RateLimiter, UnlimitedRateLimiter}
internal import f_exception.UnreachableException
internal import f_log.impl.LoggerFactory

public func initTcpServer(port!: UInt16) {
    TcpServerSocket(bindAt: port)
}
/**
 * 返回的TcpServerSocket不要调用bind()
 */
public func initTcpServer(new: () -> TcpServerSocket) {
    new()
}

public func initTcpClient(host!: String, port!: UInt16) {
    TcpSocket(host, port)
}
/**
 * 返回的TcpSocket不要调用connect()
 */
public func initTcpClient(new: () -> TcpSocket) {
    new()
}
