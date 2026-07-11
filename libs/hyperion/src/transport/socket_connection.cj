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
 * Socket连接的封装
 *
 * @author yangfuping
 */
public open class SocketConnection <: Connection {
    protected static let logger = LoggerFactory.getLogger("transport")

    private let id: Int64

    private static let idGenerator = AtomicInt64(0)

    private let socket: StreamingSocket

    private var readTimeout: ?Duration = None

    private var asyncWrite: Bool = true

    private let remoteAddress: SocketAddress

    private let localAddress: SocketAddress

    private let listeners = LinkedList<ConnectionLister>()

    private let writeLock = Mutex()

    private let readCompletionHandler = AtomicOptionReference<ReadCompletionHandler>()

    private let writeEventLoop = AtomicOptionReference<WriteEventLoopHandler>()

    private var closed = false

    protected var invalidated = false

    private let expirableDelegate = ExpirableItem()

    public init(socket: StreamingSocket) {
        this.id = idGenerator.fetchAdd(1)
        this.socket = socket
        // 避免Socket被对方关闭后，调用hashcode和equals比较连接出错
        this.remoteAddress = socket.remoteAddress
        this.localAddress = socket.localAddress
    }

    public func config(options: TcpSocketOptions): Unit {
        if (let Some(readTimeout) <- options.readTimeout) {
            this.readTimeout = readTimeout
        }

        if (let Some(idleTimeout) <- options.idleTimeout) {
            this.idleTimeout = idleTimeout
        }

        this.asyncWrite = options.asyncWrite
        if (asyncWrite) {
            let created = WriteEventLoopHandler(this, options)
            writeEventLoop.compareAndSwap(None, created)
        }
    }

    public mut prop idleTimeout: ?Duration {
        get() {
            return expirableDelegate.idleTimeout
        }
        set(value) {
            expirableDelegate.idleTimeout = value
        }
    }

    public func isAsyncWrite(): Bool {
        return this.asyncWrite
    }

    public func cancelExpireTime(): Unit {
        expirableDelegate.cancelExpireTime()
    }

    public func setExpireTimeIfAbsent(): Unit {
        expirableDelegate.setExpireTimeIfAbsent()
    }

    public func setExpireTime(): Unit {
        expirableDelegate.setExpireTime()
    }

    public func isExpired(): Bool {
        return expirableDelegate.isExpired()
    }

    public func addListener(listener: ConnectionLister): Unit {
        checkOpen()
        listeners.addLast(listener)
    }

    public func getReadCompletionHandler(): ?ReadCompletionHandler {
        return readCompletionHandler.load()
    }

    private func createOrLoadReadCompletionHandler(): ReadCompletionHandler {
        if (let Some(handler) <- readCompletionHandler.load()) {
            return handler
        }

        var handler = ReadCompletionHandler()
        if (readCompletionHandler.compareAndSwap(None, handler)) {
            return handler
        } else {
            return readCompletionHandler
                .load()
                .getOrThrow({
                    => return TransportException("Failure to obtain ReadCompletionHandler")
                })
        }
    }

    public func addReadCompletionListener(completionListener: ReadCompletionListener): Unit {
        createOrLoadReadCompletionHandler().addListener(completionListener)
    }

    public func removeReadCompletionHandler() {
        if (let Some(handler) <- readCompletionHandler.load()) {
            readCompletionHandler.compareAndSwap(handler, None)
        }
    }

    public func realWrite(buffer: Array<Byte>): Unit {
        checkOpen()
        try {
            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Real write buffer[${0}..${buffer.size}] by ${this}")
            }

            socket.write(buffer)
        } catch (ex: SocketException | SocketTimeoutException | IOException) {
            close(markInvalid: true)
            logger.log(
                LogLevel.ERROR,
                "Failure to write message",
                ex
            )
            throw TransportException("Failure to write message", ex)
        }
    }

    public func realWrite(buffers: Array<Array<Byte>>): Unit {
        checkOpen()
        try {
            for (buffer in buffers) {
                if (logger.isTraceEnabled()) {
                    logger.log(LogLevel.TRACE, "Real write buffer[${0}..${buffer.size}] by ${this}")
                }
                socket.write(buffer)
            }
        } catch (ex: SocketException | SocketTimeoutException | IOException) {
            close(markInvalid: true)
            logger.log(
                LogLevel.ERROR,
                "Failure to write message",
                ex
            )
            throw TransportException("Failure to write message", ex)
        }
    }

    public func realWrite(buffer: Array<Byte>, promise: WriteBeforePromise): Unit {
        checkOpen()
        try {
            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Real write buffer[${0}..${buffer.size}] by ${this}")
            }

            promise.beforeWrite()
            socket.write(buffer)
        } catch (ex: SocketException | SocketTimeoutException | IOException) {
            close(markInvalid: true)
            logger.log(
                LogLevel.ERROR,
                "Failure to write message",
                ex
            )
            throw TransportException("Failure to write message", ex)
        }
    }

    public func realWrite(buffers: Array<Array<Byte>>, promise: WriteBeforePromise): Unit {
        checkOpen()
        try {
            promise.beforeWrite()
            for (buffer in buffers) {
                if (logger.isTraceEnabled()) {
                    logger.log(LogLevel.TRACE, "Real write buffer[${0}..${buffer.size}] by ${this}")
                }
                socket.write(buffer)
            }
        } catch (ex: SocketException | SocketTimeoutException | IOException) {
            close(markInvalid: true)
            logger.log(
                LogLevel.ERROR,
                "Failure to write message",
                ex
            )
            throw TransportException("Failure to write message", ex)
        }
    }

    private func doSyncWrite(buffer: Array<Byte>) {
        synchronized(writeLock) {
            realWrite(buffer)
        }
    }

    private func doSyncWrite(buffers: Array<Array<Byte>>) {
        synchronized(writeLock) {
            realWrite(buffers)
        }
    }

    private func doSyncWrite(buffer: Array<Byte>, promise: WriteBeforePromise) {
        synchronized(writeLock) {
            realWrite(buffer, promise)
        }
    }

    private func doSyncWrite(buffers: Array<Array<Byte>>, promise: WriteBeforePromise) {
        synchronized(writeLock) {
            realWrite(buffers, promise)
        }
    }

    private func doAsyncWrite(writeEvent: WriteEvent) {
        if (let Some(writeEventLoop) <- writeEventLoop.load()) {
            writeEventLoop.offerWriteEvent(writeEvent)
        } else {
            throw TransportException("Async write messsage failure, WriteEventLoopHandler is not initialized")
        }
    }

    public func write(buffer: Array<Byte>): Unit {
        checkOpen()

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Write buffer[${0}..${buffer.size}] by ${this}")
        }

        if (asyncWrite) {
            doAsyncWrite(WriteEvent(buffer, promise: None))
        } else {
            doSyncWrite(buffer)
        }
    }

    public func write(buffer: Array<Byte>, startPos: Int64, length: Int64): Unit {
        checkOpen()

        if (startPos < 0) {
            throw IllegalArgumentException("Wrong start position: ${startPos}")
        }

        if (length < 0) {
            throw IllegalArgumentException("Wrong length: ${length}")
        }

        if (startPos + length > buffer.size) {
            throw IllegalArgumentException(
                "Index out of range: ${startPos + length},  start position: ${startPos}, length: ${length}, array size: ${buffer.size}"
            )
        }

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Write buffer[${startPos}..${startPos + length}] by ${this}")
        }

        let slice = buffer[startPos..startPos + length]
        if (asyncWrite) {
            doAsyncWrite(WriteEvent(slice, promise: None))
        } else {
            doSyncWrite(buffer)
        }
    }

    public func write(buffer: Array<Byte>, promise: WriteBeforePromise): Unit {
        checkOpen()

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Write buffer[${0}..${buffer.size}] by ${this}")
        }

        if (asyncWrite) {
            doAsyncWrite(WriteEvent(buffer, promise: promise))
        } else {
            doSyncWrite(buffer, promise)
        }
    }

    public func write(buffer: Array<Byte>, startPos: Int64, length: Int64, promise: WriteBeforePromise): Unit {
        checkOpen()

        if (startPos < 0) {
            throw IllegalArgumentException("Wrong start position: ${startPos}")
        }

        if (length < 0) {
            throw IllegalArgumentException("Wrong length: ${length}")
        }

        if (startPos + length > buffer.size) {
            throw IllegalArgumentException(
                "Index out of range: ${startPos + length},  start position: ${startPos}, length: ${length}, array size: ${buffer.size}"
            )
        }

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Write buffer[${startPos}..${startPos + length}] by ${this}")
        }

        let slice = buffer[startPos..startPos + length]
        if (asyncWrite) {
            doAsyncWrite(WriteEvent(slice, promise: promise))
        } else {
            doSyncWrite(buffer, promise)
        }
    }

    public func gatheringWrite(gatheredBuffers: Array<Array<Byte>>): Unit {
        if (asyncWrite) {
            let writeItem = WriteEvent(gatheredBuffers, promise: None)
            doAsyncWrite(writeItem)
        } else {
            doSyncWrite(gatheredBuffers)
        }
    }

    public func gatheringWrite(gatheredBuffers: Array<Array<Byte>>, promise: WriteBeforePromise): Unit {
        if (asyncWrite) {
            let writeItem = WriteEvent(gatheredBuffers, promise: promise)
            doAsyncWrite(writeItem)
        } else {
            doSyncWrite(gatheredBuffers, promise)
        }
    }

    public func write(buffer: ByteBuffer, promise: WriteBeforePromise): Unit {
        write(buffer.toArray(), promise)
    }

    public func write(buffer: ByteBuffer): Unit {
        write(buffer.toArray())
    }

    public func gatheringWrite(gatheredBuffers: Array<ByteBuffer>): Unit {
        let complex = Array<Array<Byte>>(gatheredBuffers.size, repeat: Array<Byte>())
        for (i in 0..gatheredBuffers.size) {
            complex[i] = gatheredBuffers[i].toArray()
        }
        if (asyncWrite) {
            let writeItem = WriteEvent(complex, promise: None)
            doAsyncWrite(writeItem)
        } else {
            doSyncWrite(complex)
        }
    }

    public func gatheringWrite(gatheredBuffers: Array<ByteBuffer>, promise: WriteBeforePromise): Unit {
        let complex = Array<Array<Byte>>(gatheredBuffers.size, repeat: Array<Byte>())
        for (i in 0..gatheredBuffers.size) {
            complex[i] = gatheredBuffers[i].toArray()
        }

        if (asyncWrite) {
            let writeItem = WriteEvent(complex, promise: promise)
            doAsyncWrite(writeItem)
        } else {
            doSyncWrite(complex, promise)
        }
    }

    public func read(buffer: Array<Byte>): Int64 {
        checkOpen()

        try {
            // 仅读取一次
            let count = socket.read(buffer)

            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Read ${count} bytes by ${this}")
            }

            if (count == 0 || count == -1) {
                throw IOException("EOF encounted, read ${count} bytes")
            }

            return count
        } catch (ex: SocketException | IOException) {
            if (!isClosed()) {
                close(markInvalid: true)
                logger.log(
                    LogLevel.ERROR,
                    "Failure to read message on connection ${this}",
                    ex
                )
            } else {
                if (logger.isDebugEnabled()) {
                    logger.log(LogLevel.DEBUG, "Connection already closed: ${this}", ex)
                }
            }

            throw TransportException("Failure to read message on connection ${this}", ex)
        } catch (ex: SocketTimeoutException) {
            // 未读到数据，保留连接
            if (logger.isDebugEnabled()) {
                logger.log(
                    LogLevel.DEBUG,
                    "SocketTimeoutException occured while read messsage on connection ${this}",
                    ex
                )
            }

            // 抛出原始的SocketTimeoutException
            throw ex
        }
    }

    public func read(buffer: Array<Byte>, startPos: Int64, length: Int64): Int64 {
        checkOpen()

        if (startPos < 0) {
            throw IllegalArgumentException("Wrong start position: ${startPos}")
        }

        if (length < 0) {
            throw IllegalArgumentException("Wrong length: ${length}")
        }

        if (startPos + length > buffer.size) {
            throw IllegalArgumentException(
                "Index out of range: ${startPos + length},  start position: ${startPos}, length: ${length}, array size: ${buffer.size}"
            )
        }

        try {
            // 仅读取一次
            let slice = buffer[startPos..startPos + length]
            let count = socket.read(slice)

            if (logger.isTraceEnabled()) {
                logger.log(
                    LogLevel.TRACE,
                    "Read ${count} bytes fill into buffer[${startPos}..${startPos + length}] by ${this}"
                )
            }

            if (count == -1) {
                throw IOException("EOF encounted")
            }

            return count
        } catch (ex: SocketException | IOException) {
            if (!isClosed()) {
                close(markInvalid: true)
                logger.log(
                    LogLevel.ERROR,
                    "Failure to read message on connection ${this}",
                    ex
                )
            } else {
                if (logger.isDebugEnabled()) {
                    logger.log(LogLevel.DEBUG, "Connection already closed: ${this}", ex)
                }
            }

            throw TransportException("Failure to read message on connection ${this}", ex)
        } catch (ex: SocketTimeoutException) {
            // 未读到数据，保留连接
            if (logger.isDebugEnabled()) {
                logger.log(
                    LogLevel.DEBUG,
                    "SocketTimeoutException occured while read messsage on connection ${this}",
                    ex
                )
            }

            // 抛出原始的SocketTimeoutException
            throw ex
        }
    }

    public func readFully(buffer: Array<Byte>): Int64 {
        readFully(buffer, 0, buffer.size)
    }

    public func readFully(buffer: Array<Byte>, startPos: Int64, length: Int64): Int64 {
        checkOpen()

        if (startPos < 0) {
            throw IllegalArgumentException("Wrong start position: ${startPos}")
        }

        if (length < 0) {
            throw IllegalArgumentException("Wrong length: ${length}")
        }

        if (startPos + length > buffer.size) {
            throw IllegalArgumentException(
                "Index out of range: ${startPos + length},  start position: ${startPos}, length: ${length}, array size: ${buffer.size}"
            )
        }

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Trying to fully fill buffer[${startPos}..${startPos + length}]")
        }

        var totalRedCount = 0
        var endPos = startPos + length
        try {
            // 循环多次，直到读取到需要的数据
            while (totalRedCount < length) {
                let slice = buffer[(startPos + totalRedCount)..endPos]
                let readCount = socket.read(slice)

                if (readCount == -1) {
                    throw IOException("EOF encounted")
                }
                totalRedCount = totalRedCount + readCount
            }

            if (logger.isTraceEnabled()) {
                logger.log(
                    LogLevel.TRACE,
                    "Fully filled buffer[${startPos}..${startPos + length}], read ${totalRedCount} bytes"
                )
            }

            return totalRedCount
        } catch (ex: SocketException | SocketTimeoutException | IOException) {
            if (!isClosed()) {
                close(markInvalid: true)
                logger.log(
                    LogLevel.ERROR,
                    "Could not fill buffer[${startPos}..${startPos + length}] use connection ${this}, buffer size: ${buffer.size}",
                    ex
                )
            } else {
                if (logger.isDebugEnabled()) {
                    logger.log(LogLevel.DEBUG, "Connection already closed: ${this}", ex)
                }
            }

            throw TransportException(
                "Could not fill buffer[${startPos}..${startPos + length}] use connection ${this}, buffer size: ${buffer.size}",
                ex
            )
        }
    }

    public func read(buffer: ByteBuffer): Int64 {
        let count = read(buffer.toArray())
        buffer.position(buffer.position() + count)
        return count
    }

    public func readFully(buffer: ByteBuffer): Int64 {
        let count = readFully(buffer.toArray())
        buffer.position(buffer.position() + count)
        return count
    }

    public func flush(): Unit {
        checkOpen()
        try {
            socket.flush()
        } catch (ioEx: IOException) {
            close(markInvalid: true)
            throw ioEx
        }
    }

    public func checkOpen(): Unit {
        if (closed) {
            throw TransportException("Connection ${this} closed")
        }

        if (socket.isClosed()) {
            close(markInvalid: true)
            throw TransportException("Connection ${this} closed")
        }
    }

    public func markInvalid(): Unit {
        this.invalidated = true
    }

    public func isInvalid(): Bool {
        return this.invalidated
    }

    public func setTimeoutInfinite(): Unit {
        if (!closed && !socket.isClosed()) {
            socket.readTimeout = None
        }
    }

    public func rollbackTimeout(): Unit {
        if (let Some(readTimeout) <- this.readTimeout) {
            if (!closed && !socket.isClosed()) {
                socket.readTimeout = readTimeout
            }
        }
    }

    public func isClosed(): Bool {
        return closed
    }

    public open func close(): Unit {
        internalClose()
    }

    public open func close(markInvalid!: Bool): Unit {
        if (markInvalid) {
            this.markInvalid()
        }

        internalClose()
    }

    protected open func internalClose() {
        try {
            if (!closed) {
                closed = true
                if (logger.isDebugEnabled()) {
                    logger.debug("Close ${this}")
                }

                socket.close()

                if (!listeners.isEmpty()) {
                    for (listener in listeners) {
                        listener.onClose()
                    }
                }
            }
        } catch (ex: Exception) {
            // ignore
        }
    }

    public open func toString() {
        return "SocketConnection[id: ${id}, socket: ${socket}]"
    }

    public open func simpleName() {
        if (let Some(localAddress) <- (localAddress as IPSocketAddress)) {
            if (let Some(remoteAddress) <- (remoteAddress as IPSocketAddress)) {
                return "L${localAddress.port}-R${remoteAddress.port}"
            }
        }
        return "L${localAddress}-R${remoteAddress}"
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        var hashCode = 57 * id
        hashCode = hashCode + remoteAddress.hashCode()
        hashCode = hashCode + localAddress.hashCode()
        return hashCode
    }

    public operator override func ==(other: Connection): Bool {
        if (let Some(otherConn) <- (other as SocketConnection)) {
            if (id != otherConn.id) {
                return false
            }

            if (remoteAddress != otherConn.remoteAddress) {
                return false
            }

            if (localAddress != otherConn.localAddress) {
                return false
            }

            return true
        }

        return false
    }

    public operator override func !=(other: Connection): Bool {
        if (let Some(otherConn) <- (other as SocketConnection)) {
            if (id != otherConn.id) {
                return false
            }

            if (remoteAddress != otherConn.remoteAddress) {
                return true
            }

            if (localAddress != otherConn.localAddress) {
                return true
            }

            return false
        }

        return true
    }

    /**
     * 配置TcpSocket相关属性
     *
     * @param socket TcpSocket
     * @param socketOptions TcpSocketOptions
     */
    public static func configSocketOptions(socket: TcpSocket, socketOptions: TcpSocketOptions) {
        if (let Some(receiveBufferSize) <- socketOptions.receiveBufferSize) {
            if (receiveBufferSize > 0) {
                socket.receiveBufferSize = receiveBufferSize
            }
        }

        if (let Some(sendBufferSize) <- socketOptions.sendBufferSize) {
            if (sendBufferSize > 0) {
                socket.sendBufferSize = sendBufferSize
            }
        }

        if (let Some(readTimeout) <- socketOptions.readTimeout) {
            socket.readTimeout = readTimeout
        }

        if (let Some(writeTimeout) <- socketOptions.writeTimeout) {
            socket.writeTimeout = writeTimeout
        }

        if (let Some(noDelay) <- socketOptions.noDelay) {
            socket.noDelay = noDelay
        }

        if (let Some(linger) <- socketOptions.linger) {
            socket.linger = linger
        }
    }
}
