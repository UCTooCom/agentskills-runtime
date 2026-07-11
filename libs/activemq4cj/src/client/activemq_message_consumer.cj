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
package activemq4cj.client

public open class ActiveMQMessageConsumer <: ActiveMQDispatcher & MessageConsumer {
    private static let logger = LoggerFactory.getLogger("ActiveMQMessageConsumer")

    private let info: ConsumerInfo
    private let isConsumerInfoSentToBroker: AtomicBool = AtomicBool(false)
    let session: ActiveMQSession
    private var failureErrorVal: ?TransportException = None

    private var optimizedAckTimer: ?Timer = None
    private var optimizeAcknowledgeVal: Bool = false
    private var optimizeAcknowledgeTimeOutVal: Int64 = 0
    private var optimizedAckScheduledAckIntervalVal: Int64 = 0
    private var optimizeAckTimestamp: DateTime = DateTime.now()
    private var failoverRedeliveryWaitPeriodVal: Duration = Duration.Zero
    private var nonBlockingRedeliveryVal: Bool = false
    private var consumerExpiryCheckEnabledVal: Bool = true
    var transactedIndividualAck: Bool = false
    private var selector: ?String
    protected var synchronizationRegistered: AtomicBool = AtomicBool(false)

    private var redeliveryPolicy: RedeliveryPolicy
    private var clearDeliveredListVal: Bool = false
    private let deliveryingAcknowledgements: AtomicBool = AtomicBool(false)
    let inProgressClearRequiredFlag = AtomicInt64(0)

    private let unconsumedMessages: MessageDispatchChannel
    //已经投递出去，还未确认的消息
    protected let deliveredMessages: LinkedList<MessageDispatch> = LinkedList<MessageDispatch>()
    let deliveredMessagesMutex: Mutex = Mutex()
    // 跟踪事务中的重复投递，以便验证事务的完整性
    private var previouslyDeliveredMessages: ?PreviouslyDeliveredMap = None
    private var deliveredCounter: Int64 = 0
    private var additionalWindowSize: Int64 = 0
    private var ackCounter = 0
    private var pendingAck: ?MessageAck = None
    private var lastDeliveredSequenceIdVal: Int64 = -1

    private var messageListenerVal: ?MessageListener
    private var messageTransformerVal: ?MessageTransformer
    private var threadPoolexecutor: ?ThreadPool = None

    private let started: AtomicBool = AtomicBool(false)

    public init(session: ActiveMQSession, consumerId: ConsumerId, destination: ActiveMQDestination, name: ?String,
        selector: ?String, prefetch: Int32, maximumPendingMessageCount: Int32, noLocal: Bool, browser: Bool,
        dispatchAsync: Bool, messageListener: ?MessageListener) {
        //验证ActiveMQDestination的合法性
        if (destination.name.isNone()) {
            throw InvalidDestinationException("The destination object was not given a physical name")
        } else if (destination.isTemporary()) {
            if (let Some(connectionId) <- session.connection.connectionInfo.connectionId) {
                if (let Some(value) <- connectionId.value) {
                    if (let Some(name) <- destination.name) {
                        if (name.indexOf(value).isNone()) {
                            throw InvalidDestinationException(
                                "Cannot use a Temporary destination from another Connection")
                        }
                    }
                }
            }

            if (session.connection.isDeleted(destination)) {
                throw InvalidDestinationException("Cannot use a Temporary destination that has been deleted")
            }

            if (prefetch < 0) {
                throw CJMSException("Cannot have a prefetch size less than zero")
            }
        }
        this.session = session
        if (session.connection.messagePrioritySupported) {
            this.unconsumedMessages = SimplePriorityMessageDispatchChannel()
        } else {
            this.unconsumedMessages = FifoMessageDispatchChannel()
        }

        this.redeliveryPolicy = RedeliveryPolicy()
        if (let Some(redeliveryPolicyMap) <- session.connection.redeliveryPolicyMap) {
            if (let Some(redeliveryPolicy) <- redeliveryPolicyMap.getEntryFor(destination)) {
                this.redeliveryPolicy = redeliveryPolicy
            }
        }

        this.info = ConsumerInfo()
        this.info.consumerId = consumerId
        this.info.exclusive = session.connection.exclusiveConsumer
        this.info.clientId = session.connection.getClientID()
        this.info.destination = destination
        this.info.prefetchSize = prefetch
        this.info.maximumPendingMessageLimit = maximumPendingMessageCount
        this.info.subscriptionName = name
        this.info.selector = None
        this.info.noLocal = noLocal
        this.info.browser = browser
        this.info.dispatchAsync = dispatchAsync
        this.info.retroactive = session.connection.useRetroactiveConsumer
        this.selector = selector

        this.messageTransformerVal = session.transformer
        this.messageListenerVal = messageListener
        //dispatchAsync,exclusive,maximumPendingMessageLimit,noLocal,prefetchSize,priority,retroactive,selector
        //这些参数可通过Consumer Options设置
        if (let Some(options) <- destination.options) {
            var consumerOptions = TypeConversionSupport.convertMap<String>(
                IntrospectionSupport.extractProperties<?String>(options, "consumer."))
            IntrospectionSupport.setProperties(this.info, consumerOptions)
            if (!consumerOptions.isEmpty()) {
                throw CJMSException(
                    "There are ${consumerOptions.size} consumer options that couldn't be set on the consumer, Check the options are spelled correctly"
                )
            }
        }

        if (let Some(selector) <- this.selector) {
            this.info.selector = this.selector
        } else {
            this.selector = this.info.selector
        }

        this.optimizeAcknowledgeVal = session.connection.optimizeAcknowledge && session.isAutoAcknowledge() &&
            !this.info.browser

        if (this.optimizeAcknowledgeVal) {
            this.optimizeAcknowledgeTimeOutVal = session.connection.optimizeAcknowledgeTimeOut
            this.optimizedAckScheduledAckIntervalVal = session.connection.optimizedAckScheduledAckInterval
        }

        this.info.optimizedAcknowledge = this.optimizeAcknowledgeVal
        this.failoverRedeliveryWaitPeriodVal = session.connection.consumerFailoverRedeliveryWaitPeriod
        this.nonBlockingRedeliveryVal = session.connection.nonBlockingRedelivery
        this.transactedIndividualAck = session.connection.transactedIndividualAck || this.nonBlockingRedeliveryVal || session
            .connection
            .messagePrioritySupported
        this.consumerExpiryCheckEnabledVal = session.connection.consumerExpiryCheckEnabled
    }

    private func setMessageListener() {
        checkClosed()
        if (info.prefetchSize == 0) {
            throw CJMSException(
                "Illegal prefetch size of zero. This setting is not supported for asynchronous consumers please set a value of at least 1"
            )
        }
        //尚未投递的消息重新分发给MessageListener
        if (let Some(messageListener) <- this.messageListenerVal) {
            var wasRunning = this.session.isRunning()
            if (wasRunning) {
                this.session.stop()
            }
            this.session.redispatch(unconsumedMessages)
            if (wasRunning) {
                this.session.start()
            }
        }
    }

    public open func dispatch(messageDispatch: MessageDispatch): Unit {
        clearMessagesInProgress()
        clearDeliveredMessages()
        synchronized(unconsumedMessages.getMutex()) {
            if (!unconsumedMessages.isClosed()) {
                if (this.info.browser || messageDispatch.deliverySequenceId != 0 ||
                    !session.connection.isDuplicate(this, messageDispatch.message)) {
                    //没有设置MessageListener或者unconsumedMessages已经停止, 把消息入队到unconsumedMessages
                    if (this.messageListener.isNone() || !unconsumedMessages.isRunning()) {
                        messageDispatch.deliverySequenceId = -1
                        if (messageDispatch.message.isNone()) {
                            //让browser结束
                            unconsumedMessages.enqueue(messageDispatch)
                        } else {
                            if (!consumeExpiredMessage(messageDispatch)) {
                                unconsumedMessages.enqueue(messageDispatch)
                            } else {
                                beforeMessageIsConsumed(messageDispatch)
                                afterMessageIsConsumed(messageDispatch, true)
                            }
                        }
                    } else if (let Some(messageListener) <- this.messageListener) {
                        //发送到MessageListener
                        if (redeliveryExceeded(messageDispatch)) {
                            //发送到DLQ
                            poisonAck(
                                messageDispatch,
                                "Dispatch[${messageDispatch.redeliveryCounter}] to ${consumerId} exceeds redelivery policy limit: ${redeliveryPolicy.maximumRedeliveries}"
                            )
                            return
                        }

                        var message: ?ActiveMQMessage = createActiveMQMessage(messageDispatch)
                        beforeMessageIsConsumed(messageDispatch)
                        try {
                            if (let Some(message) <- message) {
                                var expired = consumerExpiryCheckEnabled && message.isExpired()
                                if (!expired) {
                                    messageListener.onMessage(message)
                                }
                                afterMessageIsConsumed(messageDispatch, expired)
                            }
                        } catch (e: Exception) {
                            logger.error("${consumerId} Exception while processing message: ${messageDispatch.message}",
                                e)
                            messageDispatch.rollbackCause = e
                            if (isAutoAcknowledgeBatch() || isAutoAcknowledgeEach() || session.isIndividualAcknowledge()) {
                                //重新投递或者进入死信队列
                                rollback()
                            } else {
                                afterMessageIsConsumed(messageDispatch, false)
                            }
                        }
                    }
                } else {
                    //处理重复的投递
                    var consumerWithPendingTransaction: ?ConsumerId = redeliveryPendingInCompetingTransaction(
                        messageDispatch)
                    if (redeliveryExpectedInCurrentTransaction(messageDispatch, true)) {
                        logger.debug("${consumerId} tracking transacted redelivery ${messageDispatch.message}")
                        if (transactedIndividualAck) {
                            immediateIndividualTransactedAck(messageDispatch)
                        } else {
                            session.sendAck(MessageAck(messageDispatch, MessageAck.DELIVERED_ACK_TYPE, 1))
                        }
                    } else if (consumerWithPendingTransaction.isSome()) {
                        logger.warn(
                            "${consumerId} delivering duplicate ${messageDispatch.message}, pending transaction completion on ${consumerWithPendingTransaction} will rollback"
                        )
                        if (let Some(message) <- messageDispatch.message) {
                            session.connection.rollbackDuplicate(this, message)
                        }
                        dispatch(messageDispatch)
                    } else {
                        logger.warn(
                            "${consumerId} suppressing duplicate delivery on connection, poison acking: ${messageDispatch}"
                        )
                        poisonAck(messageDispatch,
                            "Suppressing duplicate delivery on connection, consumer ${consumerId}")
                    }
                }
            }
        }
    }

    private func enqueue(messageDispatch: MessageDispatch): Unit {
        messageDispatch.deliverySequenceId = -1
        if (!consumeExpiredMessage(messageDispatch)) {
            unconsumedMessages.enqueue(messageDispatch)
        } else {
            beforeMessageIsConsumed(messageDispatch)
            afterMessageIsConsumed(messageDispatch, true)
        }
    }

    private func redeliveryExpectedInCurrentTransaction(md: MessageDispatch, markReceipt: Bool): Bool {
        if (session.isTransacted()) {
            synchronized(deliveredMessagesMutex) {
                if (let Some(previouslyDeliveredMessages) <- previouslyDeliveredMessages) {
                    if (let Some(message) <- md.message) {
                        if (let Some(messageId) <- message.messageId) {
                            var entry: ?PreviouslyDelivered = previouslyDeliveredMessages.get(messageId)
                            if (let Some(entry) <- entry) {
                                if (markReceipt) {
                                    entry.redelivered = true
                                }
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    /**
     * timeout==-1,阻塞直到获取到消息
     * timeout==0，非阻塞获取，尝试获取后直接返回
     * timeout>0,阻塞最多不会超过超时时间
     */
    private func dequeue(timeout: Duration): ?MessageDispatch {
        var deadline: Int64 = 0
        if (timeout > Duration.Zero) {
            deadline = DateTime.now().toUnixTimeStamp().toMilliseconds() + timeout.toMilliseconds()
        }
        var overtime = timeout
        while (true) {
            var md = unconsumedMessages.dequeue(overtime)
            if (let Some(md) <- md) {
                if (md.message.isNone()) {
                    return None
                } else if (consumeExpiredMessage(md)) {
                    //过期消息
                    logger.debug("${consumerId} received expired message: ${md}")
                    beforeMessageIsConsumed(md)
                    afterMessageIsConsumed(md, true)

                    if (timeout > Duration.Zero) {
                        overtime = Duration.millisecond * max(
                            deadline - DateTime.now().toUnixTimeStamp().toMilliseconds(), 0)
                    }
                    sendPullCommand(overtime)
                } else if (redeliveryExceeded(md)) {
                    //发送poisonAck
                    logger.debug("${consumerId} received with excessive redelivered: ${md}")
                    poisonAck(
                        md,
                        "Dispatch[${md.redeliveryCounter}] to ${consumerId} exceeds redelivery policy limit: ${redeliveryPolicy.maximumRedeliveries}"
                    )

                    if (timeout > Duration.Zero) {
                        overtime = Duration.millisecond * max(
                            deadline - DateTime.now().toUnixTimeStamp().toMilliseconds(), 0)
                    }
                    sendPullCommand(overtime)
                } else {
                    return md
                }
            } else {
                if (overtime > Duration.Zero && !unconsumedMessages.isClosed()) {
                    overtime = Duration.millisecond * max(deadline - DateTime.now().toUnixTimeStamp().toMilliseconds(),
                        0)
                } else {
                    if (let Some(failureError) <- failureError) {
                        throw CJMSException(failureError.message)
                    } else {
                        return None
                    }
                }
            }
        }
        return None
    }

    /**
     * 检查消息是否过期
     */
    private func consumeExpiredMessage(md: MessageDispatch): Bool {
        if (consumerExpiryCheckEnabled) {
            if (let Some(message) <- md.message) {
                return message.isExpired()
            }
        }
        return false
    }

    private func poisonAck(md: MessageDispatch, cause: String): Unit {
        var poisonAck = MessageAck(md, MessageAck.POISON_ACK_TYPE, 1)
        if (let Some(message) <- md.message) {
            poisonAck.firstMessageId = message.messageId
        }
        poisonAck.poisonCause = Throwable(cause)
        session.sendAck(poisonAck)
    }

    private func redeliveryExceeded(md: MessageDispatch): Bool {
        if (session.getTransacted() && redeliveryPolicy.preDispatchCheck && redeliveryPolicy.maximumRedeliveries != RedeliveryPolicy
            .NO_MAXIMUM_REDELIVERIES && md.redeliveryCounter > redeliveryPolicy.maximumRedeliveries) {
            if (let Some(message) <- md.message) {
                return message.getProperty("redeliveryDelay").isNone()
            }
        }
        return false
    }

    public func receive(): ?CJMSMessage {
        checkClosed()
        this.session.checkMessageListener()
        sendPullCommand(Duration.millisecond * 0)

        let md = dequeue(Duration.second * -1)
        if (let Some(md) <- md) {
            beforeMessageIsConsumed(md)
            afterMessageIsConsumed(md, false)
            if (let Some(message) <- createActiveMQMessage(md)) {
                return message
            }
        }
        return None
    }

    public func receive(timeout: Duration): ?CJMSMessage {
        checkClosed()
        this.session.checkMessageListener()
        if (timeout == Duration.Zero) {
            return this.receive()
        }

        sendPullCommand(timeout)
        if (timeout > Duration.Zero) {
            var md: ?MessageDispatch
            if (info.prefetchSize == 0) {
                md = dequeue(Duration.millisecond * -1) // We let the broker let us know when we timeout.
            } else {
                md = dequeue(timeout)
            }

            if (let Some(md) <- md) {
                beforeMessageIsConsumed(md)
                afterMessageIsConsumed(md, false)
                if (let Some(message) <- createActiveMQMessage(md)) {
                    return message
                }
            }
        }
        return None
    }

    public func receiveNoWait(): ?CJMSMessage {
        checkClosed()
        this.session.checkMessageListener()
        sendPullCommand(Duration.millisecond * -1)

        var md: ?MessageDispatch
        if (info.prefetchSize == 0) {
            md = dequeue(Duration.millisecond * -1) // We let the broker let us know when we timeout.
        } else {
            md = dequeue(Duration.Zero)
        }

        if (let Some(md) <- md) {
            beforeMessageIsConsumed(md)
            afterMessageIsConsumed(md, false)
            if (let Some(message) <- createActiveMQMessage(md)) {
                return message
            }
        }

        return None
    }

    func deliverAcks(): Unit {
        var ack: ?MessageAck = None

        if (deliveryingAcknowledgements.compareAndSwap(false, true)) {
            synchronized(deliveredMessagesMutex) {
                if (isAutoAcknowledgeEach()) {
                    ack = makeAckForAllDeliveredMessages(MessageAck.STANDARD_ACK_TYPE)
                    if (ack.isSome()) {
                        deliveredMessages.clear()
                        ackCounter = 0
                    } else {
                        ack = pendingAck
                        pendingAck = None
                    }
                } else {
                    if (let Some(pendingAck) <- this.pendingAck) {
                        if (pendingAck.isStandardAck()) {
                            ack = pendingAck
                            this.pendingAck = None
                        }
                    }
                }
            }
            if (let Some(ack) <- ack) {
                try {
                    session.sendAck(ack, true)
                } catch (e: CJMSException) {
                    logger.error("${consumerId} failed to deliver acknowledgements", e)
                } finally {
                    deliveryingAcknowledgements.store(false)
                }
            } else {
                deliveryingAcknowledgements.store(false)
            }
        }
    }

    private func createActiveMQMessage(md: MessageDispatch): ?ActiveMQMessage {
        if (let Some(message) <- md.message) {
            if (let Some(msg) <- (message.copy() as ActiveMQMessage)) {
                var m: ActiveMQMessage = msg
                // 消息通过MessageTransformer进行转换
                if (let Some(messageTransformer) <- messageTransformer) {
                    var transformerMessage: CJMSMessage = messageTransformer.consumerTransform(session, this, msg)
                    m = ActiveMQMessageTransformation.transformMessage(transformerMessage, session.connection)
                }
                if (session.isClientAcknowledge()) {
                    //给消息设置手动确认回调
                    m.acknowledgeCallback = ClientAcknowledgeCallback(this)
                } else if (session.isIndividualAcknowledge()) {
                    m.acknowledgeCallback = IndividualAcknowledgeCallback(this, md)
                }
                return m
            }
        }
        return None
    }

    protected func sendPullCommand(timeout: Duration) {
        clearDeliveredMessages()
        //当预取数量为0且队列为空时向Broker发送MessagePull获取消息
        if (info.prefetchSize == 0 && unconsumedMessages.isEmpty()) {
            var messagePull: MessagePull = MessagePull()
            messagePull.consumerId = info.consumerId
            messagePull.destination = info.destination
            messagePull.timeout = timeout.toMilliseconds()
            session.asyncSendPacket(messagePull)
        }
    }

    private func beforeMessageIsConsumed(md: MessageDispatch) {
        md.deliverySequenceId = session.getNextDeliveryId()
        if (let Some(message) <- md.message) {
            if (let Some(messageId) <- message.messageId) {
                this.lastDeliveredSequenceIdVal = messageId.brokerSequenceId
            }
        }

        if (!isAutoAcknowledgeBatch()) {
            synchronized(deliveredMessagesMutex) {
                deliveredMessages.addFirst(md)
            }
            if (session.getTransacted()) {
                if (transactedIndividualAck) {
                    immediateIndividualTransactedAck(md)
                } else {
                    ackLater(md, MessageAck.DELIVERED_ACK_TYPE)
                }
            }
        }
    }

    private func immediateIndividualTransactedAck(md: MessageDispatch): Unit {
        registerSync()
        var ack = MessageAck(md, MessageAck.INDIVIDUAL_ACK_TYPE, 1)
        if (let Some(transactionContext) <- session.transactionContext) {
            if (let Some(txId) <- transactionContext.transactionId) {
                ack.transactionId = txId
            }
        }
        session.sendAck(ack)
    }

    private func afterMessageIsConsumed(md: MessageDispatch, messageExpired: Bool) {
        if (unconsumedMessages.isClosed()) {
            return
        }
        if (messageExpired) {
            //消息过期的处理
            acknowledge(md, MessageAck.EXPIRED_ACK_TYPE)
        } else {
            if (session.getTransacted()) {
            // do nothing
            } else if (isAutoAcknowledgeEach()) {
                if (deliveryingAcknowledgements.compareAndSwap(false, true)) {
                    synchronized(deliveredMessagesMutex) {
                        if (!deliveredMessages.isEmpty()) {
                            if (optimizeAcknowledge) {
                                ackCounter++
                                if (Float64(ackCounter + deliveredCounter) >= Float64(info.prefetchSize) * 0.65 || (optimizeAcknowledgeTimeOut >
                                    0 && DateTime.now() - optimizeAckTimestamp > optimizeAcknowledgeTimeOut * Duration
                                    .millisecond)) {
                                    var ack: ?MessageAck = makeAckForAllDeliveredMessages(MessageAck.STANDARD_ACK_TYPE)
                                    if (let Some(ack) <- ack) {
                                        deliveredMessages.clear()
                                        ackCounter = 0
                                        session.sendAck(ack)
                                        optimizeAckTimestamp = DateTime.now()
                                    }

                                    if (deliveredCounter > 0) {
                                        if (let Some(pendingAck) <- pendingAck) {
                                            session.sendAck(pendingAck)
                                            this.pendingAck = None
                                            deliveredCounter = 0
                                        }
                                    }
                                }
                            } else {
                                var ack = makeAckForAllDeliveredMessages(MessageAck.STANDARD_ACK_TYPE)
                                if (let Some(ack) <- ack) {
                                    deliveredMessages.clear()
                                    session.sendAck(ack)
                                }
                            }
                        }
                    }
                    deliveryingAcknowledgements.store(false)
                }
            } else if (isAutoAcknowledgeBatch()) {
                ackLater(md, MessageAck.STANDARD_ACK_TYPE)
            } else if (session.isClientAcknowledge() || session.isIndividualAcknowledge()) {
                var messageUnackedByConsumer: Bool = false
                synchronized(deliveredMessagesMutex) {
                    messageUnackedByConsumer = Collections.contains<MessageDispatch>(deliveredMessages, md)
                }
                if (messageUnackedByConsumer) {
                    ackLater(md, MessageAck.DELIVERED_ACK_TYPE)
                }
            } else {
                throw IllegalStateException("Invalid session state.")
            }
        }
    }

    private func makeAckForAllDeliveredMessages(ackType: Byte): ?MessageAck {
        synchronized(deliveredMessagesMutex) {
            if (deliveredMessages.isEmpty()) {
                return None
            }

            var md: ?MessageDispatch = deliveredMessages.first
            if (let Some(md) <- md) {
                var ack: MessageAck = MessageAck(md, ackType, Int32(deliveredMessages.size))
                if (let Some(last) <- deliveredMessages.last) {
                    if (let Some(message) <- last.message) {
                        ack.firstMessageId = message.messageId
                    }
                }
                return ack
            }
            return None
        }
    }

    private func ackLater(md: MessageDispatch, ackType: Byte): Unit {
        if (session.getTransacted()) {
            registerSync()
        }

        deliveredCounter++

        synchronized(deliveredMessagesMutex) {
            var oldPendingAck: ?MessageAck = pendingAck

            var newPendingAck = MessageAck(md, ackType, Int32(deliveredCounter))
            if (let Some(transactionContext) <- session.transactionContext) {
                newPendingAck.transactionId = transactionContext.transactionId
            }
            pendingAck = newPendingAck

            if (let Some(oldPendingAck) <- oldPendingAck) {
                if (newPendingAck.ackType == oldPendingAck.ackType) {
                    newPendingAck.firstMessageId = oldPendingAck.firstMessageId
                } else {
                    if (!oldPendingAck.isDeliveredAck()) {
                        logger.debug("Sending old pending ack ${oldPendingAck}, new pending: ${newPendingAck}")
                        session.sendAck(oldPendingAck)
                    } else {
                        logger.debug("dropping old pending ack ${oldPendingAck}, new pending: ${pendingAck}")
                    }
                }
            } else {
                newPendingAck.firstMessageId = newPendingAck.lastMessageId
            }

            if (0.5 * Float64(info.prefetchSize) <= Float64(deliveredCounter + ackCounter - additionalWindowSize)) {
                logger.debug("ackLater: sending: ${pendingAck}")
                session.sendAck(newPendingAck)
                pendingAck = None
                deliveredCounter = 0
                additionalWindowSize = 0
            }
        }
    }

    private func registerSync(): Unit {
        session.doStartTransaction()
        if (synchronizationRegistered.compareAndSwap(false, true)) {
            if (let Some(transactionContext) <- session.transactionContext) {
                transactionContext.addSynchronization(MessageConsumerSynchronization(this))
            }
        }
    }

    public func acknowledge(): Unit {
        clearDeliveredMessages()
        waitForRedeliveries()

        synchronized(deliveredMessagesMutex) {
            var ack: ?MessageAck = makeAckForAllDeliveredMessages(MessageAck.STANDARD_ACK_TYPE)
            if (let Some(ack) <- ack) {
                if (session.getTransacted()) {
                    rollbackOnFailedRecoveryRedelivery()
                    session.doStartTransaction()
                    if (let Some(transactionContext) <- session.transactionContext) {
                        ack.transactionId = transactionContext.transactionId
                    }
                }

                pendingAck = None
                session.sendAck(ack)

                deliveredCounter = max(0, deliveredCounter - deliveredMessages.size)
                additionalWindowSize = max(0, additionalWindowSize - deliveredMessages.size)
            }

            if (!session.getTransacted()) {
                deliveredMessages.clear()
            }
        }
    }

    func waitForRedeliveries(): Unit {
        if (failoverRedeliveryWaitPeriod > Duration.Zero && previouslyDeliveredMessages.isSome()) {
            var now = DateTime.now()

            var numberNotReplayed: Int64
            do {
                numberNotReplayed = 0
                synchronized(deliveredMessagesMutex) {
                    if (let Some(previouslyDeliveredMessages) <- previouslyDeliveredMessages) {
                        for (previouslyDelivered in previouslyDeliveredMessages.messages) {
                            if (!previouslyDelivered.redelivered) {
                                numberNotReplayed++
                            }
                        }
                    }
                }
                if (numberNotReplayed > 0) {
                    if (let Some(previouslyDeliveredMessages) <- previouslyDeliveredMessages) {
                        logger.info(
                            "waiting for redelivery of ${numberNotReplayed} in transaction: ${consumerId}, to consumer: ${previouslyDeliveredMessages.transactionId}"
                        )
                    }

                    if (Duration.millisecond * 500 > failoverRedeliveryWaitPeriod / 4) {
                        sleep(Duration.millisecond * 500)
                    } else {
                        sleep(failoverRedeliveryWaitPeriod / 4)
                    }
                }
            } while (numberNotReplayed > 0 && DateTime.now() - now > failoverRedeliveryWaitPeriod)
        }
    }

    func rollbackOnFailedRecoveryRedelivery(): Unit {
        if (let Some(previouslyDeliveredMessages) <- previouslyDeliveredMessages) {
            var numberNotReplayed = 0
            for (previouslyDelivered in previouslyDeliveredMessages.messages) {
                if (!previouslyDelivered.redelivered) {
                    numberNotReplayed++
                    if (let Some(message) <- previouslyDelivered.message) {
                        logger.debug(
                            "previously delivered message has not been replayed in transaction: ${previouslyDeliveredMessages.transactionId}, messageId: ${message.messageId}"
                        )
                    }
                }
            }

            if (numberNotReplayed > 0) {
                var message = "rolling back transaction (${previouslyDeliveredMessages.transactionId}) post failover recovery. ${numberNotReplayed} previously delivered message(s) not replayed to consumer: ${consumerId}"
                logger.warn(message)
                throw TransactionRolledBackException(message)
            }
        }
    }

    func acknowledge(md: MessageDispatch) {
        acknowledge(md, MessageAck.INDIVIDUAL_ACK_TYPE)
    }

    func acknowledge(md: MessageDispatch, ackType: Byte): Unit {
        var ack = MessageAck(md, ackType, 1)
        if (ack.isExpiredAck()) {
            ack.firstMessageId = ack.lastMessageId
        }
        session.sendAck(ack)

        synchronized(deliveredMessagesMutex) {
            deliveredMessages.removeIf({e: MessageDispatch => e == md})
        }
    }

    public func commit() {
        synchronized(deliveredMessagesMutex) {
            deliveredMessages.clear()
            clearPreviouslyDelivered()
        }
    }

    public func rollback(): Unit {
        clearDeliveredMessages()
        synchronized(unconsumedMessages.getMutex()) {
            if (optimizeAcknowledge) {
                if (!this.info.browser) {
                    synchronized(deliveredMessagesMutex) {
                        var i = 0
                        while (i < deliveredMessages.size && i < ackCounter) {
                            var md = deliveredMessages.removeLast()
                            if (let Some(md) <- md) {
                                if (let Some(message) <- md.message) {
                                    session.connection.rollbackDuplicate(this, message)
                                }
                            }
                            i++
                        }
                    }
                }
            }
            synchronized(deliveredMessagesMutex) {
                rollbackPreviouslyDeliveredAndNotRedelivered()
                if (deliveredMessages.isEmpty()) {
                    return
                }

                var lastMd: ?MessageDispatch = deliveredMessages.first
                var firstMsgId: ?MessageId = None
                if (let Some(firstMd) <- deliveredMessages.last) {
                    if (let Some(message) <- firstMd.message) {
                        firstMsgId = message.messageId
                    }
                }

                for (md in deliveredMessages) {
                    if (let Some(message) <- md.message) {
                        message.onMessageRolledBack()
                        session.connection.rollbackDuplicate(this, message)
                    }
                }

                if (let Some(lastMd) <- lastMd) {
                    if (let Some(lastMessage) <- lastMd.message) {
                        if (redeliveryPolicy.maximumRedeliveries != RedeliveryPolicy.NO_MAXIMUM_REDELIVERIES &&
                            lastMessage.redeliveryCounter > redeliveryPolicy.maximumRedeliveries) {
                            //发送到DLQ
                            var ack: MessageAck = MessageAck(lastMd, MessageAck.POISON_ACK_TYPE,
                                Int32(deliveredMessages.size))
                            ack.firstMessageId = firstMsgId
                            ack.poisonCause = Throwable(
                                "Delivery[${lastMessage.redeliveryCounter}] exceeds redelivery policy limit: ${redeliveryPolicy.maximumRedeliveries}, cause: ${lastMd.rollbackCause}"
                            )
                            session.sendAck(ack, true)

                            // 调整窗口大小
                            additionalWindowSize = max(0, additionalWindowSize - deliveredMessages.size)

                            deliveredCounter -= deliveredMessages.size
                            deliveredMessages.clear()
                        } else {
                            //重发
                            var currentRedeliveryCount = lastMessage.redeliveryCounter
                            var redeliveryDelay = redeliveryPolicy.initialRedeliveryDelay
                            for (i in 0..currentRedeliveryCount - 1) {
                                redeliveryDelay = redeliveryPolicy.getNextRedeliveryDelay(redeliveryDelay)
                            }

                            logger.debug(
                                "Redelivery delay calculated for redelivery count ${currentRedeliveryCount}: ${redeliveryDelay}, for messageId '${lastMessage.messageId}'"
                            )

                            if (currentRedeliveryCount > 0) {
                                var ack: MessageAck = MessageAck(lastMd, MessageAck.REDELIVERED_ACK_TYPE,
                                    Int32(deliveredMessages.size))
                                ack.firstMessageId = firstMsgId
                                session.sendAck(ack, true)
                            }

                            let pendingSessionRedelivery: LinkedList<MessageDispatch> = LinkedList<MessageDispatch>(
                                deliveredMessages)

                            captureDeliveredMessagesForDuplicateSuppressionWithRequireRedelivery(false)

                            deliveredCounter -= deliveredMessages.size
                            deliveredMessages.clear()

                            if (!unconsumedMessages.isClosed()) {
                                if (nonBlockingRedelivery) {
                                    pendingSessionRedelivery.reverse()

                                    Timer.after(
                                        Duration.millisecond * redeliveryDelay,
                                        {
                                            =>
                                            try {
                                                if (!unconsumedMessages.isClosed()) {
                                                    for (dispatch in pendingSessionRedelivery) {
                                                        session.dispatch(dispatch)
                                                    }
                                                }
                                            } catch (e: Exception) {
                                                session.connection.onAsyncException(e)
                                            }
                                            return Option<Duration>.None
                                        }
                                    )
                                } else {
                                    unconsumedMessages.stop()

                                    let redispatchWork = {
                                        => try {
                                            if (!unconsumedMessages.isClosed()) {
                                                synchronized(unconsumedMessages.getMutex()) {
                                                    for (md in pendingSessionRedelivery) {
                                                        unconsumedMessages.enqueueFirst(md)
                                                    }

                                                    if (let Some(messageListener) <- messageListener) {
                                                        session.redispatch(unconsumedMessages)
                                                    }
                                                }
                                                if (started.load()) {
                                                    start()
                                                }
                                            }
                                        } catch (e: CJMSException) {
                                            session.connection.onAsyncException(e)
                                        }
                                    }

                                    if (redeliveryDelay > 0 && !unconsumedMessages.isClosed()) {
                                        Timer.after(
                                            Duration.millisecond * redeliveryDelay,
                                            {
                                                =>
                                                redispatchWork()
                                                return Option<Duration>.None
                                            }
                                        )
                                    } else {
                                        redispatchWork()
                                    }
                                }
                            } else {
                                for (md in pendingSessionRedelivery) {
                                    if (let Some(message) <- md.message) {
                                        session.connection.rollbackDuplicate(this, message)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func rollbackPreviouslyDeliveredAndNotRedelivered(): Unit {
        if (let Some(previouslyDeliveredMessages) <- previouslyDeliveredMessages) {
            for (previouslyDelivered in previouslyDeliveredMessages.messages) {
                if (!previouslyDelivered.redelivered) {
                    if (let Some(message) <- previouslyDelivered.message) {
                        logger.trace("rollback non redelivered: ${message.messageId}")
                        removeFromDeliveredMessages(message.messageId)
                    }
                }
            }
            clearPreviouslyDelivered()
        }
    }

    private func removeFromDeliveredMessages(key: ?MessageId): Unit {
        var toDelete = LinkedList<MessageDispatch>()
        for (md in deliveredMessages) {
            if (let Some(message) <- md.message) {
                if (key == message.messageId) {
                    session.connection.rollbackDuplicate(this, message)
                    toDelete.addLast(md)
                }
            }
        }
        for (del in toDelete) {
            deliveredMessages.removeIf({e: MessageDispatch => refEq(e, del)})
        }
    }

    private func clearPreviouslyDelivered(): Unit {
        if (let Some(previouslyDeliveredMessages) <- previouslyDeliveredMessages) {
            previouslyDeliveredMessages.clear()
            this.previouslyDeliveredMessages = None
        }
    }

    private func redeliveryPendingInCompetingTransaction(md: MessageDispatch): ?ConsumerId {
        for (activeMQSession in session.connection.sessions) {
            for ((consumerId, consumer) in activeMQSession.consumers) {
                if (consumer.redeliveryExpectedInCurrentTransaction(md, false)) {
                    return consumer.consumerId
                }
            }
        }
        return None
    }

    func clearDeliveredMessages(): Unit {
        if (clearDeliveredListVal) {
            synchronized(deliveredMessagesMutex) {
                if (clearDeliveredListVal) {
                    if (!deliveredMessages.isEmpty()) {
                        if (session.isTransacted()) {
                            captureDeliveredMessagesForDuplicateSuppressionWithRequireRedelivery(true)
                        } else {
                            if (session.isClientAcknowledge()) {
                                logger.debug(
                                    "${consumerId} rolling back delivered list (${deliveredMessages.size}) on transport interrupt"
                                )

                                // 允许重新投递
                                if (!this.info.browser) {
                                    for (md in deliveredMessages) {
                                        if (let Some(messsage) <- md.message) {
                                            this.session.connection.rollbackDuplicate(this, messsage)
                                        }
                                    }
                                }
                            }
                            logger.debug(
                                "${consumerId} clearing delivered list (${deliveredMessages.size}) on transport interrupt"
                            )
                            deliveredMessages.clear()
                            pendingAck = None
                        }
                    }
                }
                clearDeliveredListVal = false
            }
        }
    }

    private func captureDeliveredMessagesForDuplicateSuppressionWithRequireRedelivery(requireRedelivery: Bool): Unit {
        var previouslyDeliveredMessages: PreviouslyDeliveredMap
        if (let Some(deliveredMap) <- this.previouslyDeliveredMessages) {
            previouslyDeliveredMessages = deliveredMap
        } else {
            if (let Some(transactionContext) <- session.transactionContext) {
                previouslyDeliveredMessages = PreviouslyDeliveredMap(transactionContext.transactionId)
                this.previouslyDeliveredMessages = previouslyDeliveredMessages
            } else {
                throw CJMSException("TransactionContext not available")
            }
        }
        for (delivered in deliveredMessages) {
            if (let Some(message) <- delivered.message) {
                if (let Some(messageId) <- message.messageId) {
                    previouslyDeliveredMessages.put(messageId, PreviouslyDelivered(delivered, !requireRedelivery))
                }
            }
        }
        logger.trace(
            "${consumerId} tracking existing transacted ${previouslyDeliveredMessages.transactionId} delivered list(${deliveredMessages.size})"
        )
    }

    func inProgressClearRequired(): Unit {
        inProgressClearRequiredFlag.fetchAdd(1)

        clearDeliveredListVal = true
        // 在故障转移后/期间处理事务，强制回滚
        if (let Some(transactionContext) <- session.transactionContext) {
            if (!deliveredMessages.isEmpty() && transactionContext.isInTransaction()) {
                transactionContext.rollbackOnly = true
            }
        }
    }

    func clearMessagesInProgress(): Unit {
        if (inProgressClearRequiredFlag.load() > 0) {
            synchronized(unconsumedMessages.getMutex()) {
                if (inProgressClearRequiredFlag.load() > 0) {
                    logger.debug(
                        "${consumerId} clearing unconsumed list (${unconsumedMessages.size}) on transport interrupt")
                    // 确保未消费的消息可以被发送给其它的消费者
                    var list: LinkedList<MessageDispatch> = unconsumedMessages.removeAll();
                    if (!this.info.browser) {
                        for (old in list) {
                            if (let Some(message) <- old.message) {
                                session.connection.rollbackDuplicate(this, message)
                            }
                        }
                    }
                    session.connection.transportInterruptionProcessingComplete()
                    inProgressClearRequiredFlag.store(0)

                    unconsumedMessages.getCondition().notifyAll()
                }
            }
            clearDeliveredMessages()
        }
    }

    public func iterate(): Bool {
        if (let Some(listener) <- this.messageListener) {
            var md: ?MessageDispatch = unconsumedMessages.dequeueNoWait()
            if (let Some(md) <- md) {
                dispatch(md)
                return true
            }
        }
        return false
    }

    private func isAutoAcknowledgeEach(): Bool {
        if (session.isAutoAcknowledge()) {
            return true
        }

        if (session.isDupsOkAcknowledge()) {
            if (let Some(destination) <- info.destination) {
                return destination.isQueue()
            }
        }

        return false
    }

    private func isAutoAcknowledgeBatch(): Bool {
        if (session.isDupsOkAcknowledge()) {
            if (let Some(destination) <- info.destination) {
                return !destination.isQueue()
            }
        }
        return false
    }

    public func start(): Unit {
        if (unconsumedMessages.isClosed()) {
            return
        }
        started.store(true)
        unconsumedMessages.start()
        session.executor.wakeup()
    }

    protected func ensureConsumerInfoSent(): Unit {
        if (isConsumerInfoSentToBroker.compareAndSwap(false, true)) {
            this.session.syncSendPacket(this.info)
        }
    }

    public func stop(): Unit {
        if (started.compareAndSwap(true, false)) {
            unconsumedMessages.stop()
        }
    }

    protected func checkClosed() {
        if (unconsumedMessages.isClosed()) {
            throw IllegalStateException("The Consumer is closed")
        }
    }

    public override func isClosed(): Bool {
        return unconsumedMessages.isClosed()
    }

    public func close() {
        dispose()
        let removeInfo = this.info.createRemoveInfo()
        removeInfo.lastDeliveredSequenceId = lastDeliveredSequenceId
        this.session.asyncSendPacket(removeInfo)
    }

    protected func dispose(): Unit {
        if (!unconsumedMessages.isClosed()) {
            if (!session.getTransacted()) {
                deliverAcks()
                if (isAutoAcknowledgeBatch()) {
                    acknowledge()
                }
            }

            if (let Some(timer) <- optimizedAckTimer) {
                timer.cancel()
            }

            if (session.isClientAcknowledge() || session.isIndividualAcknowledge()) {
                if (!this.info.browser) {
                    // rollback duplicates that aren't acknowledged
                    var tmp: LinkedList<MessageDispatch>
                    synchronized(this.deliveredMessagesMutex) {
                        tmp = LinkedList<MessageDispatch>(this.deliveredMessages)
                    }
                    for (old in tmp) {
                        if (let Some(message) <- old.message) {
                            this.session.connection.rollbackDuplicate(this, message)
                        }
                    }
                    tmp.clear()
                }
            }
            if (!session.isTransacted()) {
                synchronized(deliveredMessagesMutex) {
                    deliveredMessages.clear()
                }
            }

            unconsumedMessages.close()
            this.session.removeConsumer(this)
        }
    }

    public func isInUse(destination: ActiveMQTempDestination): Bool {
        return this.info.destination == Some(destination)
    }

    public prop lastDeliveredSequenceId: Int64 {
        get() {
            return this.lastDeliveredSequenceIdVal
        }
    }

    public mut prop messageListener: ?MessageListener {
        get() {
            return this.messageListenerVal
        }
        set(value) {
            this.messageListenerVal = value
            setMessageListener()
        }
    }

    public prop messageSelector: ?String {
        get() {
            return this.selector
        }
    }

    public prop consumerId: ?ConsumerId {
        get() {
            return this.info.consumerId
        }
    }

    public mut prop messageTransformer: ?MessageTransformer {
        get() {
            return this.messageTransformerVal
        }
        set(value) {
            this.messageTransformerVal = value
        }
    }

    public mut prop optimizeAcknowledge: Bool {
        get() {
            return this.optimizeAcknowledgeVal
        }
        set(value) {
            this.optimizeAcknowledge = value
        }
    }

    public mut prop optimizeAcknowledgeTimeOut: Int64 {
        get() {
            return this.optimizeAcknowledgeTimeOutVal
        }
        set(value) {
            this.optimizeAcknowledgeTimeOutVal = value
        }
    }

    public mut prop optimizedAckScheduledAckInterval: Int64 {
        get() {
            return this.optimizedAckScheduledAckIntervalVal
        }
        set(value) {
            this.optimizedAckScheduledAckIntervalVal = value
            //重新执行定时器
            if (let Some(timer) <- this.optimizedAckTimer) {
                timer.cancel()
            }
            if (this.optimizeAcknowledge && this.optimizedAckScheduledAckInterval > 0) {
                this.optimizedAckTimer = Timer.repeat(Duration.millisecond * value, Duration.millisecond * value,
                    {
                        => try {
                            if (optimizeAcknowledge && !unconsumedMessages.isClosed()) {
                                logger.info(
                                    "Consumer:${consumerId} is performing scheduled delivery of outstanding optimized Acks"
                                )
                                deliverAcks()
                            }
                        } catch (e: Exception) {
                            logger.debug("Optimized Ack Task caught exception during ack", e);
                        }
                    })
            }
        }
    }

    public mut prop failoverRedeliveryWaitPeriod: Duration {
        get() {
            return this.failoverRedeliveryWaitPeriodVal
        }
        set(value) {
            this.failoverRedeliveryWaitPeriodVal = value
        }
    }

    public mut prop nonBlockingRedelivery: Bool {
        get() {
            return this.nonBlockingRedeliveryVal
        }
        set(value) {
            this.nonBlockingRedeliveryVal = value
        }
    }

    public mut prop consumerExpiryCheckEnabled: Bool {
        get() {
            return this.consumerExpiryCheckEnabledVal
        }
        set(value) {
            this.consumerExpiryCheckEnabledVal = value
        }
    }

    public mut prop failureError: ?TransportException {
        get() {
            return this.failureErrorVal
        }
        set(value) {
            this.failureErrorVal = value
        }
    }

    public mut prop clearDeliveredList: Bool {
        get() {
            return this.clearDeliveredListVal
        }
        set(value) {
            this.clearDeliveredListVal = value
        }
    }

    public operator func ==(other: ActiveMQDispatcher): Bool {
        if (!(other is ActiveMQMessageConsumer)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQMessageConsumer)) {
            if (this.info != other.info) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: ActiveMQDispatcher): Bool {
        if (!(other is ActiveMQMessageConsumer)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQMessageConsumer)) {
            if (this.info != other.info) {
                return true
            }
        }
        return true
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        return this.info.hashCode()
    }
}

class PreviouslyDelivered {
    private var messageVal: ?Message
    private var redeliveredVal: Bool = false

    public init(messageDispatch: MessageDispatch) {
        this.messageVal = messageDispatch.message
    }

    public init(messageDispatch: MessageDispatch, redelivered: Bool) {
        this.messageVal = messageDispatch.message
        this.redeliveredVal = redelivered
    }

    public mut prop redelivered: Bool {
        get() {
            return this.redeliveredVal
        }
        set(value) {
            this.redeliveredVal = value
        }
    }

    public prop message: ?Message {
        get() {
            return this.messageVal
        }
    }
}

class PreviouslyDeliveredMap {
    private var transactionIdVal: ?TransactionId
    private var map: HashMap<MessageId, PreviouslyDelivered> = HashMap<MessageId, PreviouslyDelivered>()

    public init(transactionId: ?TransactionId) {
        this.transactionIdVal = transactionId
    }

    public func put(key: MessageId, value: PreviouslyDelivered): Unit {
        this.map.add(key, value)
    }

    public func get(key: MessageId): ?PreviouslyDelivered {
        return this.map.get(key)
    }

    public func clear(): Unit {
        this.map.clear()
    }

    public prop messages: Collection<PreviouslyDelivered> {
        get() {
            return this.map.values()
        }
    }

    public mut prop transactionId: ?TransactionId {
        get() {
            return this.transactionIdVal
        }
        set(value) {
            this.transactionIdVal = value
        }
    }
}

class MessageConsumerSynchronization <: Synchronization {
    private let messageConsumer: ActiveMQMessageConsumer

    public init(messageConsumer: ActiveMQMessageConsumer) {
        this.messageConsumer = messageConsumer
    }

    public override func beforeEnd(): Unit {
        if (messageConsumer.transactedIndividualAck) {
            messageConsumer.clearDeliveredMessages()
            messageConsumer.waitForRedeliveries()
            synchronized(messageConsumer.deliveredMessagesMutex) {
                messageConsumer.rollbackOnFailedRecoveryRedelivery()
            }
        } else {
            messageConsumer.acknowledge()
        }
        messageConsumer.synchronizationRegistered.store(false)
    }

    public override func afterCommit(): Unit {
        messageConsumer.commit()
        messageConsumer.synchronizationRegistered.store(false)
    }

    public override func afterRollback(): Unit {
        messageConsumer.rollback()
        messageConsumer.synchronizationRegistered.store(false)
    }
}

class ClientAcknowledgeCallback <: Callback {
    private let messageConsumer: ActiveMQMessageConsumer

    public init(messageConsumer: ActiveMQMessageConsumer) {
        this.messageConsumer = messageConsumer
    }

    public override func execute(): Unit {
        messageConsumer.checkClosed()
        messageConsumer.session.checkClosed()
        messageConsumer.session.acknowledge()
    }
}

class IndividualAcknowledgeCallback <: Callback {
    private let messageConsumer: ActiveMQMessageConsumer
    private let md: MessageDispatch

    public init(messageConsumer: ActiveMQMessageConsumer, md: MessageDispatch) {
        this.messageConsumer = messageConsumer
        this.md = md
    }

    public override func execute(): Unit {
        messageConsumer.checkClosed()
        messageConsumer.session.checkClosed()
        messageConsumer.acknowledge(md)
    }
}

class DeliverAcksTask <: Runnable {
    private let messageConsumer: ActiveMQMessageConsumer

    public init(messageConsumer: ActiveMQMessageConsumer) {
        this.messageConsumer = messageConsumer
    }

    public override func run(): Unit {
        messageConsumer.deliverAcks()
    }
}
