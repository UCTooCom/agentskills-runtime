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
 * 事件处理器
 *
 * 读报文完成后，将读任务交给其他线程，继续解码报文和消息处理
 * 因线程切换较频繁影响读报文效率，建议使用ReadEventLoopHandler
 * 
 * @see ReadEventLoopHandler
 * @deprecated
 * @author yangfuping
 */
public abstract class EventLoopHandler <: Runnable {
    protected static let logger = LoggerFactory.getLogger("transport")

    private let threadPoolVal: ThreadPool

    private let sessionVal: IoSession

    private var attachmentVal: ?ByteBuffer = None

    private let allocator: ByteBufferAllocator

    private var sliceExceedBuffer = true

    /**
     * 能处理的最大消息长度，默认64M
     */
    private var maxMessageSizeInBytes: Int64 = 64 * 1024 * 1024

    public init(threadPool: ThreadPool, allocator: ByteBufferAllocator, session: IoSession) {
        this.threadPoolVal = threadPool
        this.allocator = allocator
        this.sessionVal = session
    }

    public prop threadPool: ThreadPool {
        get() {
            return threadPoolVal
        }
    }

    public prop session: IoSession {
        get() {
            return sessionVal
        }
    }

    public mut prop attachment: ?ByteBuffer {
        get() {
            return attachmentVal
        }
        set(value) {
            this.attachmentVal = value
        }
    }

    public func setSliceExceedBuffer(sliceFromExceedBuffer: Bool) {
        this.sliceExceedBuffer = sliceFromExceedBuffer
    }

    public func setMaxMessageSizeInBytes(maxMessageSizeInBytes: Int64) {
        if (maxMessageSizeInBytes > 0) {
            this.maxMessageSizeInBytes = maxMessageSizeInBytes
        }
    }

    public func run() {
        try {
            doEventLoopProcess(session.connection)
        } catch (ex: Exception) {
            logger.log(LogLevel.ERROR, "Failure to process message on connection ${session.connection}", ex)
        }
    }

    /**
     * 读取消息
     */
    private func doEventLoopProcess(connection: Connection) {
        var byteBuffer = getBuffer()
        let status = MessageCompletedStatus()
        var readCount = 0
        var soTimeoutTimes = 0
        var readCompletion: ?ReadCompletion = None
        while (readCount != -1) {
            try {
                byteBuffer = checkMessageComplete(byteBuffer, status)
                if (status.completed) {
                    /*
                     * 读完报文之后的回调，用于执行需要和读报文的顺序保持一致的操作。
                     * 例如： Redis的响应报文和发送的Redis命令的顺序需要保持一致。
                     */
                    if (let Some(completionHandler) <- connection.getReadCompletionHandler()) {
                        readCompletion = completionHandler.readCompletion()
                    }

                    // 放入线程池，读取和处理下一条消息
                    threadPool.addTask(this)
                    break
                }

                if (let Some(messageSize) <- status.messageSize) {
                    // 已经知道需要读取报文的长度，限制读取报文的长度
                    if (byteBuffer.remainingCapacity() > messageSize - byteBuffer.position()) {
                        byteBuffer.limit(messageSize)
                    } else {
                        byteBuffer = expandAndLimitBuffer(byteBuffer, messageSize)
                    }

                    // 阻塞读取到需要的数据
                    readCount = connection.readFully(byteBuffer)
                } else {
                    if (!byteBuffer.hasRemaining()) {
                        // 扩展容量
                        byteBuffer = expandBuffer(byteBuffer)
                    }

                    // 尝试读取一些数据
                    readCount = connection.read(byteBuffer)
                }

                // 取消超时时间
                connection.cancelExpireTime()
            } catch (ex: SocketTimeoutException) {
                if (logger.isDebugEnabled()) {
                    logger.log(LogLevel.DEBUG, ex.message, ex)
                }

                if (!(byteBuffer.position() > 0)) {
                    // 未读取到报文，放入线程池排队
                    threadPool.addTask(this)

                    if (connection.isExpired()) {
                        // 连接空闲超时
                        logger.log(LogLevel.WARN, "Close idle timeout Connection ${connection}")
                        connection.close(markInvalid: true)
                        return
                    }

                    connection.setExpireTimeIfAbsent()

                    // 结束当前任务
                    return
                } else {
                    soTimeoutTimes++
                    if (soTimeoutTimes > 3) {
                        logger.log(LogLevel.WARN, "Cloud not read data from ${connection}, close it")
                        connection.close(markInvalid: true)
                        return
                    }

                    // 读取到部分报文，再次尝试读取剩余报文
                    continue
                }
            } catch (ex: Exception) {
                if (!connection.isClosed()) {
                    logger.log(LogLevel.ERROR, "Connection closed: ${connection}", ex)
                    connection.close(markInvalid: true)
                } else {
                    if (logger.isDebugEnabled()) {
                        logger.log(LogLevel.DEBUG, "Connection already closed: ${connection}", ex)
                    }
                }

                onConnectionReadException(ex)
                return
            }
        }

        byteBuffer.flip()

        try {
            if (let Some(readCompletion) <- readCompletion) {
                let results = session.onMessageRead(byteBuffer, readCompletion)
                if (!results.isEmpty()) {
                    processMessage(results)
                }
            } else {
                let results = session.onMessageRead(byteBuffer)
                if (!results.isEmpty()) {
                    processMessage(results)
                }
            }
        } catch (ex: Exception) {
            logger.log(LogLevel.ERROR, "Failure to process inbound message on ${connection}", ex)
        } finally {
            byteBuffer.release()
        }
    }

    private func getBuffer(): ByteBuffer {
        let byteBuffer: ByteBuffer
        if (let Some(attach) <- attachment) {
            byteBuffer = attach
            attachment = None<ByteBuffer>
        } else {
            byteBuffer = allocator.allocate()
        }

        return byteBuffer
    }

    /**
     * 检查报文是否已经读取完整
     */
    private func checkMessageComplete(byteBuffer: ByteBuffer, status: MessageCompletedStatus): ByteBuffer {
        var resultBuffer = byteBuffer
        if (byteBuffer.position() == 0) {
            status.completed = false
            return resultBuffer
        }

        session.messageCompleted(byteBuffer, status)

        if (let Some(messageSize) <- status.messageSize) {
            // 处理超出读取的部分
            if (byteBuffer.position() >= messageSize + 1) {
                if (sliceExceedBuffer) {
                    // 将当前消息的报文通过slice方式分割出来
                    resultBuffer = sliceAndAttachBuffer(messageSize, byteBuffer)
                } else {
                    // 将超出部分已经拷贝到attachment中
                    copyToAttachBuffer(messageSize, byteBuffer)
                }

                // 限制读取数据的长度为消息报文的长度, 不需要扩展
                resultBuffer.limit(messageSize)
            }
        }

        return resultBuffer
    }

    /**
     * 分割出读取到的完整的消息报文，并将剩余部分设置到attachment中
     */
    private func sliceAndAttachBuffer(messageSize: Int64, byteBuffer: ByteBuffer): ByteBuffer {
        // 将已经读取的报文分割出来
        let slice = byteBuffer.slice(index: 0, length: messageSize)
        slice.position(messageSize)

        // 跳过已经读取到的报文
        byteBuffer.skip(messageSize)
        this.attachment = byteBuffer
        return slice
    }

    /**
     * 将多余部分已经拷贝到attachment中
     */
    private func copyToAttachBuffer(messageSize: Int64, byteBuffer: ByteBuffer): Unit {
        let exceeding = byteBuffer.position() - messageSize
        if (exceeding <= 0) {
            return
        }

        let remaingBuffer = allocator.allocate(exceeding)
        // 切割byteBuffer的position-exceeding..position区间，放入到remaingBuffer中
        remaingBuffer.put(byteBuffer.toArray(index: byteBuffer.position() - exceeding, length: exceeding))
        this.attachment = remaingBuffer
    }

    /**
     * 扩展ByteBuffer
     *
     * @throws TransportException
     */
    private func expandBuffer(byteBuffer: ByteBuffer): ByteBuffer {
        if (byteBuffer.limit() > maxMessageSizeInBytes) {
            throw TransportException(
                "Too large message size: ${byteBuffer.limit()}, exceeding maxMessageSizeInBytes: ${maxMessageSizeInBytes}"
            )
        }

        if (byteBuffer.expandSupport) {
            var expandSize = byteBuffer.limit() << 1
            if (expandSize > maxMessageSizeInBytes) {
                expandSize = maxMessageSizeInBytes
            }

            byteBuffer.expandAndLimit(expandSize)
            return byteBuffer
        } else {
            var expandSize = byteBuffer.limit() << 1
            if (expandSize > maxMessageSizeInBytes) {
                expandSize = maxMessageSizeInBytes
            }

            let expandBuffer = allocator.allocate(expandSize)
            expandBuffer.put(byteBuffer.flip().toArray())
            if (logger.isTraceEnabled()) {
                logger.trace("Expand ${byteBuffer} to ${expandBuffer}")
            }

            // 释放扩容之前的ByteBuffer
            byteBuffer.release()
            return expandBuffer
        }
    }

    /**
     * 扩展ByteBuffer, 并限制limit为messageSize
     *
     * @throws TransportException
     */
    private func expandAndLimitBuffer(byteBuffer: ByteBuffer, messageSize: Int64): ByteBuffer {
        if (messageSize > maxMessageSizeInBytes) {
            throw TransportException(
                "Too large message size: ${maxMessageSizeInBytes}, exceeding maxMessageSizeInBytes: ${maxMessageSizeInBytes}"
            )
        }

        if (byteBuffer.expandSupport) {
            byteBuffer.expandAndLimit(messageSize)
            return byteBuffer
        } else {
            let expandBuffer = allocator.allocate(messageSize)
            expandBuffer.put(byteBuffer.flip().toArray())
            if (logger.isTraceEnabled()) {
                logger.trace("ExpandAndLimitBuffer ${byteBuffer} to ${expandBuffer}, messageSize: ${messageSize}")
            }

            expandBuffer.limit(messageSize)
            // 释放扩容之前的ByteBuffer
            byteBuffer.release()
            return expandBuffer
        }
    }

    public func onConnectionReadException(ex: Exception): Unit

    public func processMessage(messages: LinkedList<Any>): Unit
}

/**
 * 只处理入栈消息
 *
 * @author yangfuping
 */
public class SimpleInboudEventLoopHandler <: EventLoopHandler {
    public init(threadPool: ThreadPool, allocator: ByteBufferAllocator, session: IoSession) {
        super(threadPool, allocator, session)
    }

    public func onConnectionReadException(ex: Exception): Unit {
        session.onConnectionReadException(ex)
    }

    public func processMessage(messages: LinkedList<Any>): Unit {
        // do nothing
    }
}

/**
 * 处理入栈消息，并将处理结果出栈
 *
 * @author yangfuping
 */
public open class SimpleInboudOutboundEventLoopHandler <: EventLoopHandler {
    public init(threadPool: ThreadPool, allocator: ByteBufferAllocator, session: IoSession) {
        super(threadPool, allocator, session)
    }

    public func onConnectionReadException(ex: Exception): Unit {
        // do nothing
    }

    public func processMessage(messages: LinkedList<Any>): Unit {
        for (message in messages) {
            session.writeMessage(message)
        }

        session.flush()
    }
}
