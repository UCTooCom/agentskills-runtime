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

public class ActiveMQSession <: ActiveMQDispatcher & Session {
    private static let logger = LoggerFactory.getLogger("ActiveMQSession")

    private let sessionInfo: SessionInfo

    protected var acknowledgementMode: AcknowledgeMode
    protected let connection: ActiveMQConnection

    private let producers: ConcurrentHashMap<ProducerId, ActiveMQMessageProducer> = ConcurrentHashMap<ProducerId, ActiveMQMessageProducer>(
    )
    protected let consumers: ConcurrentHashMap<ConsumerId, ActiveMQMessageConsumer> = ConcurrentHashMap<ConsumerId, ActiveMQMessageConsumer>(
    )
    private let sendMutex = Mutex()

    private var started: AtomicBool = AtomicBool(false)
    private var closed: Bool = false
    private var asyncDispatchVal: Bool = false
    private var sessionAsyncDispatchVal: Bool = false

    private let producerIdGenerator = Int64SequenceGenerator()
    private let consumerIdGenerator = Int64SequenceGenerator()
    private let deliveryIdGenerator: Int64SequenceGenerator = Int64SequenceGenerator()
    private var executorVal: ?ActiveMQSessionExecutor = None

    private var messageListenerVal: ?MessageListener = None
    private var transformerVal: ?MessageTransformer = None
    private var transactionContextVal: ?TransactionContext
    private var lastDeliveredSequenceIdVal: Int64 = -2
    private let interuptedClear: AtomicBool = AtomicBool(false)

    public init(connection: ActiveMQConnection, sessionId: Int64, acknowledgeMode: AcknowledgeMode, asyncDispatch: Bool,
        sessionAsyncDispatch: Bool) {
        this.connection = connection
        this.acknowledgementMode = acknowledgeMode
        this.asyncDispatchVal = asyncDispatch
        this.sessionAsyncDispatchVal = sessionAsyncDispatch
        this.transactionContextVal = TransactionContext(connection)

        //初始化sessionInfo,然后发送
        if (let Some(connectionId) <- connection.connectionInfo.connectionId) {
            this.sessionInfo = SessionInfo(connectionId, sessionId)
            connection.asyncSendPacket(sessionInfo)
            connection.addSession(this)
        } else {
            throw ActiveMQException("Connection not available")
        }

        if (connection.isStarted()) {
            start()
        }
    }

    protected func configureMessage(message: ActiveMQMessage) {
        checkClosed()
        message.connection = connection
    }

    protected func checkClosed(): Unit {
        if (closed) {
            throw CJMSIllegalStateException("The Session is closed")
        }
    }

    public override func createProducer(destination: Destination): MessageProducer {
        checkClosed()
        return ActiveMQMessageProducer(this, getNextProducerId(), ActiveMQDestination.transform(destination),
            connection.sendTimeout)
    }

    protected func addProducer(producer: ActiveMQMessageProducer) {
        if (let Some(producerId) <- producer.producerId) {
            connection.addProducer(producerId, producer)
            this.producers.put(producerId, producer)
        }
    }

    protected func removeProducer(producer: ActiveMQMessageProducer) {
        if (let Some(producerId) <- producer.producerId) {
            connection.removeProducer(producerId)
            producers.remove(producerId)
        }
    }

    protected func addConsumer(consumer: ActiveMQMessageConsumer) {
        if (let Some(consumerId) <- consumer.consumerId) {
            consumers.add(consumerId, consumer)
        }

        if (let Some(consumerId) <- consumer.consumerId) {
            this.connection.addDispatcher(consumerId, this)
        }

        consumer.ensureConsumerInfoSent();

        if (this.connection.isStarted()) {
            consumer.start()
        }
    }

    protected func removeConsumer(consumer: ActiveMQMessageConsumer) {
        if (let Some(consumerId) <- consumer.consumerId) {
            this.connection.removeDispatcher(consumerId)
            this.consumers.remove(consumerId)
        }

        this.connection.removeDispatcher(consumer)
    }

    public func syncSendPacket(command: Command): Response {
        return this.connection.syncSendPacket(command)
    }

    public func asyncSendPacket(command: Command): Unit {
        this.connection.asyncSendPacket(command)
    }

    protected func getNextProducerId(): ProducerId {
        return ProducerId(sessionInfo.sessionId, producerIdGenerator.getNextSequenceId())
    }

    private func getNextConsumerId(): ConsumerId {
        return ConsumerId(sessionInfo.sessionId, consumerIdGenerator.getNextSequenceId())
    }

    public override func createQueue(queueName: String): Queue {
        checkClosed()
        if (queueName.startsWith(ActiveMQDestination.TEMP_DESTINATION_NAME_PREFIX)) {
            return ActiveMQTempQueue(queueName)
        }
        return ActiveMQQueue(queueName)
    }

    public override func createTopic(topicName: String): Topic {
        checkClosed()
        if (topicName.startsWith(ActiveMQDestination.TEMP_DESTINATION_NAME_PREFIX)) {
            return ActiveMQTempTopic(topicName)
        }
        return ActiveMQTopic(topicName)
    }

    public override func createConsumer(destination: Destination): MessageConsumer {
        return createConsumer(destination, None, None)
    }

    public override func createConsumer(destination: Destination, messageSelector: ?String): MessageConsumer {
        return createConsumer(destination, messageSelector, false, None)
    }

    public func createConsumer(destination: Destination, messageListener: ?MessageListener): MessageConsumer {
        return createConsumer(destination, None, false, messageListener)
    }

    public func createConsumer(destination: Destination, messageSelector: ?String, messageListener: ?MessageListener): MessageConsumer {
        return createConsumer(destination, messageSelector, false, messageListener)
    }

    public override func createConsumer(destination: Destination, messageSelector: ?String, noLocal: Bool): MessageConsumer {
        return createConsumer(destination, messageSelector, noLocal, None)
    }

    public func createConsumer(destination: Destination, messageSelector: ?String, noLocal: Bool,
        messageListener: ?MessageListener): MessageConsumer {
        checkClosed()
        let rc = ActiveMQMessageConsumer(this, getNextConsumerId(), ActiveMQDestination.transform(destination), None,
            messageSelector, this.connection.prefetchPolicy.queuePrefetch,
            this.connection.prefetchPolicy.maximumPendingMessageLimit, false, false, false, messageListener)
        //addConsumer操作应早于ConsumerInfo的发送，否则会出现MessageConsumer接收不到Connection dispatch的消息
        this.addConsumer(rc)
        return rc
    }

    public override func createSharedConsumer(destination: Topic, name: ?String): MessageConsumer {
        throw UnsupportedException("createSharedConsumer(Topic, name) is not supported")
    }

    public override func createSharedConsumer(destination: Topic, name: ?String, selector: ?String): MessageConsumer {
        throw UnsupportedException("createSharedConsumer(Topic, name, messageSelector)")
    }

    /**
     * 创建持久订阅
     */
    public override func createDurableConsumer(topic: Topic, name: String): MessageConsumer {
        checkClosed()
        return createDurableConsumer(topic, name, None, false)
    }

    public override func createDurableConsumer(topic: Topic, name: String, messageSelector: ?String): MessageConsumer {
        checkClosed()
        return createDurableConsumer(topic, name, messageSelector, false)
    }

    public override func createDurableConsumer(topic: Topic, name: String, messageSelector: ?String, noLocal: Bool): MessageConsumer {
        checkClosed()
        //持久订阅需要给定唯一的clientID，检查是否设置了clientID
        connection.checkClientIDWasManuallySpecified()

        //消息预取策略
        let prefetchPolicy: ActiveMQPrefetchPolicy = this.connection.prefetchPolicy
        let prefetch: Int32
        if (this.acknowledgementMode == AcknowledgeMode.AUTO_ACKNOWLEDGE && connection.optimizedMessageDispatch) {
            prefetch = prefetchPolicy.optimizeDurableTopicPrefetch
        } else {
            prefetch = prefetchPolicy.durableTopicPrefetch
        }

        let maxPrendingLimit: Int32 = prefetchPolicy.maximumPendingMessageLimit

        let rc = ActiveMQMessageConsumer(this, getNextConsumerId(), ActiveMQDestination.transform(topic), name,
            messageSelector, prefetch, maxPrendingLimit, noLocal, false, true, None)
        this.addConsumer(rc)
        return rc
    }

    public override func createSharedDurableConsumer(destination: Topic, name: String): MessageConsumer {
        throw UnsupportedException("createSharedDurableConsumer(Topic, name) is not supported")
    }

    public override func createSharedDurableConsumer(topic: Topic, name: String, selector: ?String): MessageConsumer {
        throw UnsupportedException("createSharedDurableConsumer(Topic, name, messageSelector) is not supported")
    }

    public func isTransacted(): Bool {
        return this.acknowledgementMode == AcknowledgeMode.SESSION_TRANSACTED
    }

    public func isAutoAcknowledge(): Bool {
        return this.acknowledgementMode == AcknowledgeMode.AUTO_ACKNOWLEDGE
    }

    public func isClientAcknowledge(): Bool {
        return this.acknowledgementMode == AcknowledgeMode.CLIENT_ACKNOWLEDGE
    }

    public func isIndividualAcknowledge() {
        return acknowledgementMode == AcknowledgeMode.INDIVIDUAL_ACKNOWLEDGE
    }

    public func isDupsOkAcknowledge(): Bool {
        return this.acknowledgementMode == AcknowledgeMode.DUPS_OK_ACKNOWLEDGE
    }

    public override func createBytesMessage(): BytesMessage {
        let message = ActiveMQBytesMessage()
        configureMessage(message)
        return message
    }

    public override func createMapMessage(): MapMessage {
        let message = ActiveMQMapMessage()
        configureMessage(message)
        return message
    }

    public override func createMessage(): CJMSMessage {
        let message = ActiveMQMessage()
        configureMessage(message)
        return message
    }

    public override func createObjectMessage(): ObjectMessage {
        let message = ActiveMQObjectMessage()
        configureMessage(message)
        return message
    }

    public override func createStreamMessage(): StreamMessage {
        let message = ActiveMQStreamMessage()
        configureMessage(message)
        return message
    }

    public override func createTextMessage(): TextMessage {
        let message = ActiveMQTextMessage()
        configureMessage(message)
        return message
    }

    public func createBlobMessage(): BlobMessage {
        let message = ActiveMQBlobMessage()
        configureMessage(message)
        return message
    }

    public override func createBytesMessage(body: Array<Byte>): BytesMessage {
        let message = ActiveMQBytesMessage()
        message.writeBytes(body)
        configureMessage(message)
        return message
    }

    public override func createObjectMessage(value: Serializable<Any>): ObjectMessage {
        let message = ActiveMQObjectMessage()
        message.object = value.serialize()
        configureMessage(message)
        return message
    }

    public override func createTextMessage(text: String): TextMessage {
        let message = ActiveMQTextMessage()
        message.text = text
        configureMessage(message)
        return message
    }

    /**
     * 指示是否处于事务模式
     */
    public func getTransacted(): Bool {
        checkClosed()
        return isTransacted()
    }

    public func getAcknowledgeMode(): AcknowledgeMode {
        checkClosed()
        return this.acknowledgementMode
    }

    /**
     * 事务提交
     */
    public override func commit(): Unit {
        checkClosed()
        if (acknowledgementMode != AcknowledgeMode.SESSION_TRANSACTED) {
            throw CJMSIllegalStateException("Not a transacted session")
        }

        if (let Some(transactionContext) <- this.transactionContext) {
            if (logger.isDebugEnabled()) {
                logger.log(LogLevel.DEBUG,
                    "${this.sessionInfo.sessionId} Transaction commit: ${transactionContext.transactionId}")
            }

            transactionContext.commit()
        }
    }

    /**
     * 事务回滚
     */
    public override func rollback(): Unit {
        checkClosed()
        if (acknowledgementMode != AcknowledgeMode.SESSION_TRANSACTED) {
            throw CJMSIllegalStateException("Not a transacted session")
        }

        if (let Some(transactionContext) <- this.transactionContext) {
            if (logger.isDebugEnabled()) {
                logger.log(LogLevel.DEBUG,
                    "${this.sessionInfo.sessionId} Transaction rollback: ${transactionContext.transactionId}")
            }

            transactionContext.rollback()
        }
    }

    public override func recover() {
        for ((consumerId, consumer) in consumers) {
            consumer.rollback()
        }
    }

    protected func send(producer: ActiveMQMessageProducer, destination: ActiveMQDestination, message: CJMSMessage,
        deliveryMode: DeliveryMode, priority: Int32, timeToLive: Int64, disableMessageID: Bool,
        disableMessageTimestamp: Bool, producerWindow: ?Usage, sendTimeout: Int32, onComplete: ?AsyncCallback): Unit {
        checkClosed()
        if (destination.isTemporary() && this.connection.isDeleted(destination)) {
            throw InvalidDestinationException("Cannot publish to a deleted Destination: ${destination}")
        }

        synchronized(sendMutex) {
            //本地事务
            doStartTransaction()
            var txid: ?TransactionId = None
            if (let Some(transactionContext) <- transactionContext) {
                if (transactionContext.rollbackOnly) {
                    throw IllegalStateException("Transaction marked rollback only")
                }
                txid = transactionContext.transactionId
            }

            // 设置过期时间
            //过期时间是当前时间戳加上timeToLive
            var timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
            var expiration: Int64 = 0
            if (timeToLive > 0) {
                expiration = timestamp + timeToLive
            }
            message.setCJMSExpiration(expiration)

            message.setCJMSDeliveryTime(timestamp)
            //检查是否禁用时间戳
            if (!disableMessageTimestamp && !producer.disableMessageTimestamp) {
                message.setCJMSTimestamp(timestamp)
            }
            message.setCJMSPriority(priority)
            message.setCJMSRedelivered(false)
            message.setCJMSDeliveryMode(deliveryMode)

            var msg: Message = ActiveMQMessageTransformation.transformMessage(message, connection)
            msg.destination = destination

            msg.messageId = MessageId(producer.producerId, producer.messageSequence)
            msg.producerId = producer.producerId
            msg.brokerPath = None
            msg.transactionId = txid

            if (connection.copyMessageOnSend) {
                msg = msg.copy()
            }

            msg.connection = connection

            //消息设置为只读
            if (let Some(msg) <- (msg as ActiveMQMessage)) {
                msg.onSend()
            }

            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "${sessionInfo.sessionId} seding msg: ${msg}")
            }

            //异步发送，异步发送会返回producerAck，通过producerAck对生产者进行流量控制
            if (onComplete.isNone() && sendTimeout <= 0 && !msg.responseRequired && !connection.alwaysSyncSend && (!msg
                .persistent || connection.useAsyncSend || txid.isSome())) {
                this.connection.asyncSendPacket(msg)
                if (let Some(producerWindow) <- producerWindow) {
                    producerWindow.increaseUsage(msg.getSize())
                }
            } else {
                if (let Some(onComplete) <- onComplete) {
                    this.connection.syncSendPacket(msg, onComplete)
                } else if (sendTimeout >= 0) {
                    this.connection.syncSendPacket(msg, Duration.millisecond * Int64(sendTimeout))
                }
            }
        }
    }

    public override func createBrowser(queue: Queue): QueueBrowser {
        checkClosed()
        return this.createBrowser(queue, None)
    }

    public override func createBrowser(queue: Queue, messageSelector: ?String): QueueBrowser {
        checkClosed()
        return ActiveMQQueueBrowser(this, getNextConsumerId(), ActiveMQMessageTransformation.transformDestination(queue),
            messageSelector, asyncDispatch)
    }

    public override func createTemporaryQueue(): TemporaryQueue {
        checkClosed()
        let temporaryDestination = connection.createTempDestination(false)
        if (let Some(temporaryQueue) <- (temporaryDestination as TemporaryQueue)) {
            return temporaryQueue
        }
        throw ActiveMQException("Failed to create TemporaryQueue")
    }

    public override func createTemporaryTopic(): TemporaryTopic {
        checkClosed()
        let temporaryDestination = connection.createTempDestination(true)
        if (let Some(temporaryTopic) <- (temporaryDestination as TemporaryTopic)) {
            return temporaryTopic
        }
        throw ActiveMQException("Failed to create TemporaryQueue")
    }

    protected func isInUse(destination: ActiveMQTempDestination): Bool {
        for ((consumerId, consumer) in consumers) {
            if (consumer.isInUse(destination)) {
                return true
            }
        }
        return false
    }

    /**
     * 取消订阅
     */
    public override func unsubscribe(name: String): Unit {
        checkClosed()
        this.connection.unsubscribe(name)
    }

    public func redispatch(unconsumedMessages: MessageDispatchChannel) {
        var c: LinkedList<MessageDispatch> = unconsumedMessages.removeAll()
        c.reverse()
        for (md in c) {
            this.executor.executeFirst(md)
        }
    }

    public func checkMessageListener(): Unit {
        if (messageListener.isSome()) {
            throw IllegalStateException("Cannot synchronously receive a message when a MessageListener is set")
        }

        for ((consumerId, consumer) in consumers) {
            if (consumer.messageListener.isSome()) {
                throw IllegalStateException("Cannot synchronously receive a message when a MessageListener is set")
            }
        }
    }

    public override func acknowledge(): Unit {
        for ((consumerId, consumer) in consumers) {
            consumer.acknowledge()
        }
    }

    protected func sendAck(ack: MessageAck): Unit {
        sendAck(ack, false)
    }

    protected func sendAck(ack: MessageAck, lazy: Bool): Unit {
        if (lazy || connection.sendAcksAsync || getTransacted()) {
            asyncSendPacket(ack)
        } else {
            syncSendPacket(ack)
        }
    }

    protected func start(): Unit {
        if (started.compareAndSwap(false, true)) {
            for ((consumerId, consumer) in consumers) {
                consumer.start()
            }

            this.executor.start()
        }
    }

    protected func stop(): Unit {
        if (started.compareAndSwap(true, false)) {
            //停止消费者
            for ((consumerId, consumer) in consumers) {
                consumer.stop()
            }

            //停止消息调度
            this.executor.stop()
        }
    }

    protected func clearMessagesWhenInterupted(transportInteruptedProcess: AtomicInt64): Unit {
        this.executor.clearMessages()

        if (interuptedClear.compareAndSwap(false, true)) {
            for ((consumerId, consumer) in consumers) {
                consumer.inProgressClearRequired()
                transportInteruptedProcess.fetchAdd(1)
                Timer.after(
                    Duration.Zero,
                    {
                        =>
                        consumer.clearMessagesInProgress()
                        return Duration.Zero
                    }
                )
            }
            interuptedClear.store(false)
        }
    }

    protected func setOptimizeAcknowledge(value: Bool): Unit {
        for ((consumerId, consumer) in consumers) {
            consumer.optimizeAcknowledge = value
        }
    }

    public override func dispatch(md: MessageDispatch): Unit {
        executor.execute(md)
    }

    protected func doStartTransaction() {
        checkClosed()
        if (acknowledgementMode == AcknowledgeMode.SESSION_TRANSACTED) {
            if (let Some(transactionContext) <- transactionContext) {
                transactionContext.begin()
            } else {
                throw CJMSException("TransactionContext not available")
            }
        }
    }

    public func isRunning(): Bool {
        return started.load()
    }

    public override func isClosed(): Bool {
        return this.closed
    }

    public override func close(): Unit {
        dispose()
        if (this.closed) {
            let removeInfo = this.sessionInfo.createRemoveInfo()
            removeInfo.lastDeliveredSequenceId = lastDeliveredSequenceId
            asyncSendPacket(removeInfo)
        }
    }

    protected func dispose() {
        if (!closed) {
            try {
                this.executor.close()

                for ((consumerId, consumer) in consumers) {
                    consumer.dispose()
                    consumer.failureError = connection.firstFailureException
                    this.lastDeliveredSequenceIdVal = max(lastDeliveredSequenceId, consumer.lastDeliveredSequenceId)
                }

                // 关闭所有的生产者
                for ((producerId, producer) in producers) {
                    producer.dispose()
                }

                if (let Some(transactionContext) <- transactionContext) {
                    if (transactionContext.isInTransaction()) {
                        rollback()
                    }
                }
            } finally {
                this.connection.removeSession(this)
                closed = true
                this.transactionContext = None
            }
        }
    }

    protected prop executor: ActiveMQSessionExecutor {
        get() {
            let executor: ActiveMQSessionExecutor

            if (let Some(sessionExecutor) <- this.executorVal) {
                executor = sessionExecutor
            } else {
                executor = ActiveMQSessionExecutor(this)
                this.executorVal = executor
            }
            return executor
        }
    }

    public func getNextDeliveryId(): Int64 {
        return deliveryIdGenerator.getNextSequenceId()
    }

    public prop lastDeliveredSequenceId: Int64 {
        get() {
            return this.lastDeliveredSequenceIdVal
        }
    }

    public mut prop asyncDispatch: Bool {
        get() {
            return this.asyncDispatchVal
        }
        set(value) {
            this.asyncDispatchVal = value
        }
    }

    public mut prop sessionAsyncDispatch: Bool {
        get() {
            return this.sessionAsyncDispatchVal
        }
        set(value) {
            this.sessionAsyncDispatchVal = value
        }
    }

    public mut prop messageListener: ?MessageListener {
        get() {
            return this.messageListenerVal
        }
        set(value) {
            this.messageListenerVal = value
        }
    }

    public mut prop transformer: ?MessageTransformer {
        get() {
            return this.transformerVal
        }
        set(value) {
            this.transformerVal = value
        }
    }

    public mut prop transactionContext: ?TransactionContext {
        get() {
            return this.transactionContextVal
        }
        set(value) {
            this.transactionContextVal = value
        }
    }

    public operator func ==(other: ActiveMQDispatcher): Bool {
        if (!(other is ActiveMQSession)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQSession)) {
            if (this.sessionInfo != other.sessionInfo) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: ActiveMQDispatcher): Bool {
        if (!(other is ActiveMQSession)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQSession)) {
            if (this.sessionInfo != other.sessionInfo) {
                return true
            }
        }
        return true
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        return this.sessionInfo.hashCode()
    }
}
