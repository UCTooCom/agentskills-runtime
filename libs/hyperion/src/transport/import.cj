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

package hyperion.transport

internal import std.collection.ArrayList
internal import std.collection.LinkedList
internal import std.collection.HashMap
internal import std.collection.concurrent.ConcurrentHashMap
internal import std.collection.concurrent.LinkedBlockingQueue
internal import std.math.MathExtension
internal import std.io.InputStream
internal import std.io.IOException
internal import std.io.OutputStream
internal import std.net.IPAddress
internal import std.net.IPSocketAddress
internal import std.net.SocketAddress
internal import std.net.SocketException
internal import std.net.SocketTimeoutException
internal import std.net.StreamingSocket
internal import std.net.TcpSocket
internal import std.sync.AtomicBool
internal import std.sync.AtomicInt64
internal import std.sync.AtomicOptionReference
internal import std.sync.Monitor
internal import std.sync.Mutex
internal import std.time.DateTime
internal import stdx.net.tls.TlsClientConfig
internal import stdx.net.tls.TlsException
internal import stdx.net.tls.TlsSocket
internal import hyperion.buffer.ArrayByteBuffer
internal import hyperion.buffer.ArrayByteBufferAllocator
internal import hyperion.buffer.ByteBuffer
internal import hyperion.buffer.ByteBufferAllocator
internal import hyperion.buffer.PooledArrayByteBufferAllocator
internal import hyperion.logadapter.CauseEmbedded
internal import hyperion.objectpool.Expirable
internal import hyperion.objectpool.ExpirableItem
internal import hyperion.logadapter.Logger
internal import hyperion.logadapter.LoggerFactory
internal import hyperion.logadapter.LogLevel
internal import hyperion.objectpool.GenericObjectPool
internal import hyperion.objectpool.NonExclusiveObjectPool
internal import hyperion.objectpool.ObjectPool
internal import hyperion.objectpool.PoolConfig
internal import hyperion.objectpool.PoolException
internal import hyperion.objectpool.PooledObject
internal import hyperion.objectpool.PooledObjectFactory
internal import hyperion.threadpool.Runnable
internal import hyperion.threadpool.ThreadPool