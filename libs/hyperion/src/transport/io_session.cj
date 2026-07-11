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

/**
 * 会话接口，支持写消息
 *
 * @author yangfuping
 */
public interface Session <: Resource {
    prop connection: Connection

    prop filterChain: IoFilterChain

    func getBufferAllocator(): ByteBufferAllocator

    func getAttribute(name: String): ?Any

    func getAttribute(name: String, defaultValue: Any): Any

    func setAttribute(name: String, value: Any): Unit

    /**
     * 写消息
     *
     * @throws TransportException
     */
    func writeMessage(message: Any): Unit

    /**
     * 写消息并刷新缓冲区
     *
     * @throws TransportException
     */
    func writeAndFlushMessage(message: Any): Unit

    /**
     * 写消息
     *
     * @throws TransportException
     */
    func writeMessage(message: Any, writePromise: WriteBeforePromise): Unit

    /**
     * 写消息并刷新缓冲区
     *
     * @throws TransportException
     */
    func writeAndFlushMessage(message: Any, writePromise: WriteBeforePromise): Unit

    func flush(): Unit

    func isClosed(): Bool

    func close(): Unit
}

/**
 * 会话接口，支持写消息，也支持读取消息
 *
 * @author yangfuping
 */
public interface IoSession <: Session {

    /**
     * 判断消ByteBuffer是否包含完整的消息报文
     */
    func messageCompleted(buffer: ByteBuffer, status: MessageCompletedStatus): Unit

    /**
     * 读消息
     *
     * @throws TransportException
     */
    func onMessageRead(buffer: ByteBuffer): LinkedList<Any>

    /**
     * 读消息
     *
     * @throws TransportException
     */
    func onMessageRead(buffer: ByteBuffer, readCompletion: ReadCompletion): LinkedList<Any>

    /**
     * 处理在连接上读原始数据的异常
     *
     */
    func onConnectionReadException(ex: Exception): Unit
}


/**
 * 默认的Session实现
 * 
 * @author yangfuping
 */
public open class DefaultSession <: Session {
    private let connectionVal: Connection

    private let filterChainVal: IoFilterChain

    private let attributes = AtomicOptionReference<ConcurrentHashMap<String, Any>>()

    private let closed = AtomicBool(false)

    private static let emptyArray = Array<Byte>()

    public init(connection: Connection, filterChain: IoFilterChain) {
        this.connectionVal = connection
        this.filterChainVal = filterChain
    }

    public prop connection: Connection {
        get() {
            return connectionVal
        }
    }

    public prop filterChain: IoFilterChain {
        get() {
            return filterChainVal
        }
    }

    public func getBufferAllocator(): ByteBufferAllocator {
        return filterChainVal.getBufferAllocator()
    }

    public open func getAttribute(name: String): ?Any {
        if (let Some(attributes) <- attributes.load()) {
            return attributes.get(name)
        }
        return None
    }

    public open func getAttribute(name: String, defaultValue: Any): Any {
        if (let Some(attributes) <- attributes.load()) {
            if (let Some(attributeValue) <- attributes.get(name)) {
                return attributeValue
            }
        }
        return defaultValue
    }

    public open func setAttribute(name: String, value: Any): Unit {
        checkStatus()
        if (let Some(map) <- attributes.load()) {
            map.add(name, value)
        } else {
            let map = ConcurrentHashMap<String, Any>()
            if (attributes.compareAndSwap(None, map)) {
                map.add(name, value)
            } else {
                if (let Some(map) <- attributes.load()) {
                    map.add(name, value)
                }
            }
        }
    }

    /**
     * 写出消息
     *
     * @throws TransportException
     */
    public open func writeMessage(message: Any): Unit {
        let context = IoFilterContext()
        writeMessage(message, context)
    }

    /**
     * 写出消息
     *
     * @throws TransportException
     */
    private func writeMessage(message: Any, context: IoFilterContext): Unit {
        checkStatus()
        let bufferList = filterChainVal.outbound(context, this, message)
        try {
            if (bufferList.size == 1) {
                if (let Some(node) <- bufferList.firstNode) {
                    writeOnConn(node.value, promise: context.getWritePromise())
                } else {
                    throw TransportException("Empty outbound messages")
                }
            } else {
                gatheringWriteOnConn(bufferList, promise: context.getWritePromise())
            }
        } catch (socketEx: SocketException) {
            throw TransportException("Failure to write messages out", socketEx)
        }
    }

    /**
     * 写出单个ByteBuffer
     */
    private func writeOnConn(message: Any, promise!: ?WriteBeforePromise = None) {
        if (let Some(buffer) <- (message as ByteBuffer)) {
            if (let Some(writePromise) <- promise) {
                connectionVal.write(buffer.toArray(), writePromise)
            } else {
                connectionVal.write(buffer.toArray())
            }
        } else {
            if (let Some(toString) <- (message as ToString)) {
                throw TransportException("Only ByteBuffer is accept as final outbound message, ${toString}")
            } else {
                throw TransportException("Only ByteBuffer is accept as final outbound message")
            }
        }
    }

    /**
     * 写出多个ByteBuffer
     */
    private func gatheringWriteOnConn(messages: LinkedList<Any>, promise!: ?WriteBeforePromise = None) {
        let results = Array<Array<Byte>>(messages.size, repeat: emptyArray)
        var index = 0
        for (message in messages) {
            if (let Some(buffer) <- (message as ByteBuffer)) {
                results[index] = buffer.toArray()
                index++
            } else {
                if (let Some(toString) <- (message as ToString)) {
                    throw TransportException("Only ByteBuffer is accept as final outbound message, ${toString}")
                } else {
                    throw TransportException("Only ByteBuffer is accept as final outbound message")
                }
            }
        }

        if (let Some(writePromise) <- promise) {
            connectionVal.gatheringWrite(results, writePromise)
        } else {
            connectionVal.gatheringWrite(results)
        }
    }

    /**
     * 写出消息并刷新缓冲区
     *
     * @throws TransportException
     */
    public open func writeAndFlushMessage(message: Any): Unit {
        checkStatus()
        writeMessage(message)
        flush()
    }

    public func writeMessage(message: Any, writePromise: WriteBeforePromise): Unit {
        let context = IoFilterContext()
        context.setWritePromise(writePromise)
        writeMessage(message, context)
    }

    /**
     * 写出消息并刷新缓冲区
     *
     * @throws TransportException
     */
    public open func writeAndFlushMessage(message: Any, writePromise: WriteBeforePromise): Unit {
        checkStatus()
        writeMessage(message, writePromise)
        flush()
    }

    public open func flush(): Unit {
        if (!connection.isAsyncWrite()) {
            connection.flush()
        }
    }

    protected open func checkStatus() {
        if (closed.load()) {
            throw TransportException("Session is closed")
        }
    }

    public open func isClosed(): Bool {
        return closed.load()
    }

    protected open func internelClose() {
        connection.close()
    }

    public open func close(): Unit {
        if (closed.compareAndSwap(false, true)) {
            internelClose()
        }
    }
}

/**
 * 默认的IoSession实现
 * 
 * @author yangfuping
 */
public open class DefaultIoSession <: DefaultSession & IoSession {
    private let messages = LinkedBlockingQueue<Any>()

    public init(connection: Connection, filterChain: IoFilterChain) {
        super(connection, filterChain)
    }

    public open func messageCompleted(buffer: ByteBuffer, status: MessageCompletedStatus) {
        checkStatus()
        filterChain.messageCompleted(buffer, status)
    }

    public open func onMessageRead(buffer: ByteBuffer): LinkedList<Any> {
        checkStatus()
        let context = IoFilterContext()
        return filterChain.inbound(context, this, buffer)
    }

    public open func onMessageRead(buffer: ByteBuffer, readCompletion: ReadCompletion): LinkedList<Any> {
        let context = IoFilterContext()
        context.setReadCompletion(readCompletion)
        return filterChain.inbound(context, this, buffer)
    }

    /**
     * 处理在连接上读原始数据的异常
     *
     */
    public open func onConnectionReadException(ex: Exception): Unit {
        filterChain.onConnectionReadException(this, ex)
    }

    public open func takeMessage(): ?Any {
        return messages.tryRemove()
    }

    public open func takeMessage(timeout: Duration): ?Any {
        return messages.remove(timeout)
    }
}
