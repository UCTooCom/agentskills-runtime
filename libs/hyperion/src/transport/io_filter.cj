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
 * 记录IO处理过程中的异常和编解码结果
 *
 * @author yangfuping
 */
public class IoFilterContext {
    private var exception: ?Exception = None

    /**
     * 记录IoFilter处理的结果消息，通常一个IoFilter只产生一个结果消息，但是允许IoFilter产生多个结果消息， 例如LengthBasedFrameCodec。
     */
    private var outMessages: LinkedList<Any> = LinkedList<Any>()

    private var readCompletion: ?ReadCompletion = None

    private var writePromise: ?WriteBeforePromise = None

    public func exceptionCaught(exception: Exception) {
        this.exception = exception
    }

    public func isExceptionCaughted(): Bool {
        return this.exception.isSome()
    }

    public func getException(): ?Exception {
        return this.exception
    }

    public func clearException(): Unit {
        this.exception = None
    }

    public func setReadCompletion(readCompletion: ReadCompletion): Unit {
        this.readCompletion = readCompletion
    }

    public func getReadCompletion(): ?ReadCompletion {
        return this.readCompletion
    }

    public func setWritePromise(writePromise: WriteBeforePromise): Unit {
        this.writePromise = writePromise
    }

    public func getWritePromise(): ?WriteBeforePromise {
        return this.writePromise
    }

    public func offerMessage(out: Any) {
        this.outMessages.addLast(out)
    }

    public func clearAndOfferMessage(out: Any) {
        this.outMessages.clear()
        this.outMessages.addLast(out)
    }

    public func takeMessage(): ?Any {
        return outMessages.removeFirst()
    }

    public func takeAllMessages(): LinkedList<Any> {
        let result = LinkedList<Any>()
        for (message in outMessages) {
            result.addLast(message)
        }
        return result
    }

    public func getMessage(): ?Any {
        if (let Some(node) <- outMessages.firstNode) {
            return node.value
        }

        return None
    }

    public func getAllMessages(): LinkedList<Any> {
        return this.outMessages
    }

    public func clearMessages() {
        this.outMessages.clear()
    }
}

/**
 * 入栈出栈消息加工
 *
 * @author yangfuping
 */
public interface IoFilter <: ToString {

    /**
     * 处理入栈消息
     *
     * @throws TransportException
     */
    func inboundMessage(context: IoFilterContext, session: Session): Unit

    /**
     *  处理出栈消息
     *
     * @throws TransportException
     */
    func outboundMessage(context: IoFilterContext, session: Session): Unit
}

/**
 *  只处理单个入栈消息、单个出栈消息的IoFilter
 *
 * @author yangfuping
 */
public abstract open class SingularMessageIoFilter <: IoFilter {

    // 是否跳过异常
    private let skipOnException: Bool

    public init() {
        this.skipOnException = true
    }

    public init(skipOnException!: Bool) {
        this.skipOnException = skipOnException
    }

    /**
     * 处理入栈消息
     *
     * @throws TransportException
     */
    public func inboundMessage(context: IoFilterContext, session: Session): Unit {
        if (skipOnException && context.isExceptionCaughted()) {
            return
        }

        if (let Some(ex) <- context.getException()) {
            context.clearException()
            processInboundException(context, session, ex)
            return
        }

        // 调用context.getAllMessages，减少List的创建
        let inMessages = context.getAllMessages()
        if (!inMessages.isEmpty()) {
            try {
                checkInboundMessage(context, session, inMessages)
            } catch (ex: Exception) {
                processInboundException(context, session, ex)
                return
            }

            if (let Some(node) <- inMessages.firstNode) {
                let inMessage = node.value
                context.clearMessages()
                try {
                    processInboundMessage(context, session, inMessage)
                } catch (ex: Exception) {
                    processInboundException(context, session, ex)
                }
                return
            }
        }

        let ex = TransportException("Empty inbound messages")
        processInboundException(context, session, ex)
        return
    }

    /**
     * 检查入栈消息
     */
    protected open func checkInboundMessage(context: IoFilterContext, session: Session, inMessages: LinkedList<Any>): Unit {
    }

    /**
     * 处理入栈消息
     *
     */
    public open func processInboundMessage(context: IoFilterContext, session: Session, inMessage: Any): Unit

    /**
     * 处理入栈异常
     *
     */
    public open func processInboundException(context: IoFilterContext, session: Session, ex: Exception): Unit

    /**
     *  处理出栈消息
     *
     * @throws TransportException
     */
    public func outboundMessage(context: IoFilterContext, session: Session): Unit {
        if (skipOnException && context.isExceptionCaughted()) {
            return
        }

        if (let Some(ex) <- context.getException()) {
            context.clearException()
            processOutboundException(context, session, ex)
            return
        }

        // 调用context.getAllMessages，减少List的创建
        let outMessages = context.getAllMessages()
        if (!outMessages.isEmpty()) {
            try {
                checkOutboundMessage(context, session, outMessages)
            } catch (ex: Exception) {
                processOutboundException(context, session, ex)
                return
            }

            if (let Some(node) <- outMessages.firstNode) {
                let outMessage = node.value
                context.clearMessages()

                try {
                    processOutboundMessage(context, session, outMessage)
                } catch (ex: Exception) {
                    processOutboundException(context, session, ex)
                }
                return
            }
        }

        let ex = TransportException("Empty outbound messages")
        processOutboundException(context, session, ex)
        return
    }

    /**
     * 检查出栈消息
     */
    protected open func checkOutboundMessage(context: IoFilterContext, session: Session, outMessages: LinkedList<Any>): Unit {
    }

    /**
     * 处理出栈消息
     *
     */
    public open func processOutboundMessage(context: IoFilterContext, session: Session, outMessage: Any): Unit

    /**
     * 处理出栈异常
     *
     */
    public open func processOutboundException(context: IoFilterContext, session: Session, ex: Exception): Unit
}

/**
 * 处理消息的IoFilter链表
 *
 * @author yangfuping
 */
public class IoFilterChain <: MessageCompletedHandler {

    /**
     * 消息处理器列表
     */
    private let filters = LinkedList<IoFilter>()

    private let reverseFilters = LinkedList<IoFilter>()

    private var delegate: ?MessageCompletedHandler = None

    private var bufferAllocator: ByteBufferAllocator = ArrayByteBufferAllocator(8192, false)

    public func addFilter(filter: IoFilter) {
        filters.addLast(filter)
        reverseFilters.addFirst(filter)
    }

    public func clearFilters() {
        filters.clear()
        reverseFilters.clear()
    }

    public func setBufferAllocator(bufferAllocator: ByteBufferAllocator): Unit {
        this.bufferAllocator = bufferAllocator
    }

    public func getBufferAllocator(): ByteBufferAllocator {
        return this.bufferAllocator
    }

    public func setMessageCompletedHandler(messageCompletedListener: MessageCompletedHandler) {
        this.delegate = messageCompletedListener
    }

    public func messageCompleted(buffer: ByteBuffer, status: MessageCompletedStatus) {
        if (let Some(handler) <- delegate) {
            handler.messageCompleted(buffer, status)
        } else {
            throw TransportException("MessageCompletedHandler is required")
        }
    }

    /**
     * 处理入栈消息
     *
     * @throws TransportException
     */
    public func inbound(context: IoFilterContext, session: Session, message: Any): LinkedList<Any> {
        context.offerMessage(message)
        return inbound(context, session)
    }

    /**
     * 处理在连接上读原始数据的异常
     *
     * 因入栈消息为异步通知，需要使用专有方法处理
     *
     * @throws TransportException
     */
    public func onConnectionReadException(session: Session, exception: Exception): LinkedList<Any> {
        let context = IoFilterContext()
        context.exceptionCaught(exception)
        return inbound(context, session)
    }

    private func inbound(context: IoFilterContext, session: Session) {
        var index = 0
        let size = filters.size

        for (handler in filters) {
            try {
                handler.inboundMessage(context, session)
            } catch (ex: Exception) {
                context.exceptionCaught(ex)
            }
        }

        if (context.isExceptionCaughted()) {
            if (let Some(exception) <- context.getException()) {
                if (let Some(transEx) <- (exception as TransportException)) {
                    throw transEx
                }

                throw TransportException("Failure to process inbound messages", exception)
            }
        }

        // 返回LinkedList<Any>，避免处理?Any
        return context.getAllMessages()
    }

    /**
     *  处理出栈消息
     *
     * @throws TransportException
     */
    public func outbound(context: IoFilterContext, session: Session, message: Any): LinkedList<Any> {
        context.offerMessage(message)
        // 倒序方式处理
        for (handler in reverseFilters) {
            try {
                handler.outboundMessage(context, session)
            } catch (ex: Exception) {
                context.exceptionCaught(ex)
            }
        }

        if (context.isExceptionCaughted()) {
            if (let Some(exception) <- context.getException()) {
                if (let Some(transEx) <- (exception as TransportException)) {
                    throw transEx
                }

                throw TransportException("Failure to process outbound messages", exception)
            }
        }

        // 调用getAllMessages方法，而不是getMessage方法，原因为一些IoFilter(例如LengthBasedFrameCodec)会放多个ByteBuffer消息
        let writeMessages = context.getAllMessages()
        if (writeMessages.isEmpty()) {
            throw TransportException("Empty outbound messages")
        }

        return writeMessages
    }
}
