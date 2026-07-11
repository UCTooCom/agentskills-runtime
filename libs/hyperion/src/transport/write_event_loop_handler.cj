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
 * 写事件
 * 
 * @author yangfuping
 */
public struct WriteEvent {
    let single: ?Array<Byte>
    let complex: ?Array<Array<Byte>>
    let promise: ?WriteBeforePromise

    public init(single: Array<Byte>, promise!: ?WriteBeforePromise) {
        this.single = single
        this.complex = None
        this.promise = promise
    }

    public init(complex: ?Array<Array<Byte>>, promise!: ?WriteBeforePromise) {
        this.single = None
        this.complex = complex
        this.promise = promise
    }
}

/**
 * 循环写消息的Handler
 * 
 * @author yangfuping
 */
public class WriteEventLoopHandler {
    protected static let logger = LoggerFactory.getLogger("transport")

    private let writeThread = AtomicOptionReference<WriteThread>()

    private let connection: SocketConnection

    private let writeQueue: LinkedBlockingQueue<WriteEvent>

    private let writeBuffer: ByteBuffer

    private var writeThreadIdleTimeout: Duration = Duration.second * 60

    public init(connection: SocketConnection, options: TcpSocketOptions) {
        this.connection = connection
        this.writeQueue = LinkedBlockingQueue<WriteEvent>(options.writeQueueSize)
        this.writeBuffer = ByteBuffer.allocate(options.writeBufferSize, expandSupport: false)
        if (options.writeThreadIdleTimeout > Duration.Zero) {
            this.writeThreadIdleTimeout = writeThreadIdleTimeout
        }
    }

    public func offerWriteEvent(writeEvent: WriteEvent) {
        writeQueue.add(writeEvent)
        ensureWriteThread()
    }

    private func ensureWriteThread(): Unit {
        if (writeThread.load().isNone()) {
            let connectionName = connection.toString()
            let writeThead = WriteThread(connectionName, this)
            if (writeThread.compareAndSwap(None, writeThead)) {
                if (logger.isDebugEnabled()) {
                    logger.debug("Create write thread for ${connectionName}")
                }

                spawn {
                    Thread.currentThread.name = "WriteLoop-${connection.simpleName()}"
                    writeThead.run()
                }
            }
        }

        return
    }

    /**
     * 循环写消息
     */
    public func writeEventLoop() {
        try {
            while (true) {
                while (let Some(writeEvent) <- writeQueue.tryRemove()) {
                    if (let Some(promise) <- writeEvent.promise) {
                        promise.beforeWrite()
                    }

                    if (let Some(single) <- writeEvent.single) {
                        writeMessage(single)
                    } else if (let Some(complex) <- writeEvent.complex) {
                        for (single in complex) {
                            writeMessage(single)
                        }
                    }
                }

                flushWriteBuffer()

                if (let Some(writeEvent) <- pollWriteEvent()) {
                    if (let Some(promise) <- writeEvent.promise) {
                        promise.beforeWrite()
                    }

                    if (let Some(single) <- writeEvent.single) {
                        writeMessage(single)
                    } else if (let Some(complex) <- writeEvent.complex) {
                        for (single in complex) {
                            writeMessage(single)
                        }
                    }
                }
            }
        } catch (ex: Exception) {
            logger.log(LogLevel.ERROR, "Failure to process message on connection ${connection}", ex)
        }
    }

    /**
     * 写到WriteBuffer，如果WriteBuffer已满，则刷出
     */
    private func writeMessage(message: Array<Byte>) {
        if (message.size > writeBuffer.capacity()) {
            if (writeBuffer.position() > 0) {
                // 先写出WriteBuffer中的内容
                connection.realWrite(writeBuffer.flip().toArray())
                writeBuffer.clear()
            }

            connection.realWrite(message)
            connection.flush()
            return
        }

        if (!writeBuffer.hasRemaining()) {
            // WriteBuffer已经满了，刷出WirteBuffer的内容
            connection.realWrite(writeBuffer.flip().toArray())
            writeBuffer.clear()
            connection.flush()
        }

        if (writeBuffer.remaining() >= message.size) {
            writeBuffer.put(message)
        } else {
            let remaining = writeBuffer.remaining()
            writeBuffer.put(message, 0, remaining)
            connection.realWrite(writeBuffer.flip().toArray())
            writeBuffer.clear()
            connection.flush()
            // 将剩下部分放入WriteBuffer
            writeBuffer.put(message, remaining, message.size - remaining)
        }
    }

    /**
     * 刷出WriteBuffer
     */
    private func flushWriteBuffer() {
        if (writeBuffer.position() > 0) {
            // 先写出WriteBuffer中的内容
            connection.realWrite(writeBuffer.flip().toArray())
            writeBuffer.clear()
            connection.flush()
        }
    }

    private func pollWriteEvent(): ?WriteEvent {
        let endTime = DateTime.now().toUnixTimeStamp().toMilliseconds() + writeThreadIdleTimeout.toMilliseconds()
        var remainingTime = writeThreadIdleTimeout.toMilliseconds()
        while (remainingTime > 0) {
            // BlockingQueue.dequeue(Duration) 可能存在队列不为空也阻塞Duration超时时间的情况
            if (let Some(writeEvent) <- writeQueue.remove(Duration.millisecond * 100)) {
                return writeEvent
            }

            remainingTime = endTime - DateTime.now().toUnixTimeStamp().toMilliseconds()
        }

        return None
    }

    public func closeWriteThread(closedThread: WriteThread): Bool {
        var stoped = false
        if (writeThread.compareAndSwap(closedThread, None)) {
            stoped = true
        }

        if (!connection.isClosed()) {
            if (let Some(head) <- writeQueue.peek()) {
                ensureWriteThread()
            }
        }

        return stoped
    }
}

public class WriteThread <: Runnable {
    protected static let logger = LoggerFactory.getLogger("transport")

    private let connectionName: String

    private let handler: WriteEventLoopHandler

    public init(connectionName: String, handler: WriteEventLoopHandler) {
        this.connectionName = connectionName
        this.handler = handler
    }

    public func run() {
        handler.writeEventLoop()

        if (handler.closeWriteThread(this)) {
            let threadName = Thread.currentThread.name
            if (logger.isDebugEnabled()) {
                logger.debug("Close write thread for ${connectionName}")
            }
        }
    }
}
