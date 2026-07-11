/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */

package hyperion.transport.server

internal import std.io.IOException
internal import std.net.IPSocketAddress
internal import std.net.ServerSocket
internal import std.net.SocketAddress
internal import std.net.SocketException
internal import std.net.SocketTimeoutException
internal import std.net.TcpServerSocket
internal import std.net.TcpSocket
internal import hyperion.logadapter.Logger
internal import hyperion.logadapter.LoggerFactory
internal import hyperion.logadapter.LogLevel
internal import hyperion.buffer.ArrayByteBufferAllocator
internal import hyperion.buffer.PooledArrayByteBufferAllocator
internal import hyperion.threadpool.ThreadPool
internal import hyperion.threadpool.Runnable
internal import hyperion.transport.AbstractEndPoint
internal import hyperion.transport.ConnectionInitializer
internal import hyperion.transport.DefaultIoSession
internal import hyperion.transport.IoFilterChain
internal import hyperion.transport.SimpleInboudOutboundEventLoopHandler
internal import hyperion.transport.StickyReadInboudOutboundHandler
internal import hyperion.transport.SocketConnection
internal import hyperion.transport.TcpSocketOptions