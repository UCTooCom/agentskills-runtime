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

package echo_client

internal import std.collection.LinkedList
internal import std.collection.concurrent.LinkedBlockingQueue
internal import std.sync.AtomicInt32
internal import hyperion.buffer.ByteBuffer
internal import hyperion.transport.LengthBasedFrameCodec
internal import hyperion.transport.LengthBasedFrameEncoder
internal import hyperion.transport.LengthBasedFrameDecoder
internal import hyperion.transport.ProtocolCodecFilter
internal import hyperion.transport.ByteAndStringCodec
internal import hyperion.transport.Session
internal import hyperion.transport.IoFilter
internal import hyperion.transport.IoFilterContext
internal import hyperion.transport.ClientEndpointConfig
internal import hyperion.transport.ClientTcpEndpoint
internal import hyperion.transport.SingularMessageIoFilter
internal import hyperion.threadpool.ThreadPoolConfig
internal import hyperion.threadpool.ThreadPoolFactory
internal import hyperion.threadpool.ThreadPool