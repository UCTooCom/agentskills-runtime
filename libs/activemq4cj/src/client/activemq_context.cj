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

public class ActiveMQContext <: CJMSContext {
    private static let DEFAULT_AUTO_START: Bool = true

    private let activemqConnection: ActiveMQConnection
    private let connectionCounter: AtomicInt64
    protected var activemqSession: ?ActiveMQSession = None

    private var autoStartVal: Bool = DEFAULT_AUTO_START
    private let acknowledgeMode: AcknowledgeMode

    private var closed: Bool = false
    private let started: AtomicBool = AtomicBool(false)
    private var activemqMessageProducer: ?ActiveMQMessageProducer = None

    public init(activemqConnection: ActiveMQConnection) {
        this.activemqConnection = activemqConnection
        this.acknowledgeMode = AcknowledgeMode.AUTO_ACKNOWLEDGE
        this.connectionCounter = AtomicInt64(1)
    }

    public init(activemqConnection: ActiveMQConnection, sessionMode: AcknowledgeMode) {
        this.activemqConnection = activemqConnection
        this.acknowledgeMode = sessionMode
        this.connectionCounter = AtomicInt64(1)
    }

    public init(activemqConnection: ActiveMQConnection, sessionMode: AcknowledgeMode, connectionCounter: AtomicInt64) {
        this.activemqConnection = activemqConnection
        this.acknowledgeMode = sessionMode
        this.connectionCounter = connectionCounter
    }

    public func createContext(sessionMode: AcknowledgeMode): CJMSContext {
        if (this.connectionCounter.load() == 0) {
            throw CJMSException("Context already closed")
        }
        connectionCounter.fetchAdd(1)
        return ActiveMQContext(activemqConnection, sessionMode, connectionCounter)
    }

    public func createProducer(): CJMSProducer {
        return ActiveMQProducer(this, getCreatedActiveMQMessageProducer())
    }

    public func createConsumer(destination: Destination): CJMSConsumer {
        checkContextState()
        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return ActiveMQConsumer(this, session.createConsumer(destination))
        }
        throw CJMSException("Session not available")
    }

    public func createConsumer(destination: Destination, selector: String): CJMSConsumer {
        checkContextState()
        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return ActiveMQConsumer(this, session.createConsumer(destination, selector))
        }
        throw CJMSException("Session not available")
    }

    public func createConsumer(destination: Destination, selector: ?String, noLocal: Bool): CJMSConsumer {
        checkContextState()
        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return ActiveMQConsumer(this, session.createConsumer(destination, selector, noLocal))
        }
        throw CJMSException("Session not available")
    }

    public func createDurableConsumer(topic: Topic, subscriptionName: String): CJMSConsumer {
        checkContextState()
        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return ActiveMQConsumer(this, session.createDurableConsumer(topic, subscriptionName))
        }
        throw CJMSException("Session not available")
    }

    public func createDurableConsumer(topic: Topic, subscriptionName: String, selector: ?String): CJMSConsumer {
        checkContextState()
        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return ActiveMQConsumer(this, session.createDurableConsumer(topic, subscriptionName, selector))
        }
        throw CJMSException("Session not available")
    }

    public func createDurableConsumer(topic: Topic, subscriptionName: String, selector: ?String, noLocal: Bool): CJMSConsumer {
        checkContextState()
        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return ActiveMQConsumer(this, session.createDurableConsumer(topic, subscriptionName, selector, noLocal))
        }
        throw CJMSException("Session not available")
    }

    public func createSharedConsumer(topic: Topic, subscriptionName: String): CJMSConsumer {
        throw UnsupportedException("createSharedConsumer(topic, sharedSubscriptionName) is not supported")
    }

    public func createSharedConsumer(topic: Topic, subscriptionName: String, selector: String): CJMSConsumer {
        throw UnsupportedException(
            "createSharedConsumer(topic, sharedSubscriptionName, messageSelector) is not supported")
    }

    public func createSharedDurableConsumer(topic: Topic, subscriptionName: String): CJMSConsumer {
        throw UnsupportedException("createSharedDurableConsumer(topic, name) is not supported")
    }

    public func createSharedDurableConsumer(topic: Topic, subscriptionName: String, selector: String): CJMSConsumer {
        throw UnsupportedException("createDurableConsumer(topic, name, messageSelector) is not supported")
    }

    public func createQueue(queueName: String): Queue {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createQueue(queueName)
        }
        throw CJMSException("Session not available")
    }

    public func createTopic(topicName: String): Topic {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createTopic(topicName)
        }
        throw CJMSException("Session not available")
    }

    public func unsubscribe(name: String): Unit {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.unsubscribe(name)
        }
        throw CJMSException("Session not available")
    }

    public func createBrowser(queue: Queue): QueueBrowser {
        checkContextState()

        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return session.createBrowser(queue)
        }
        throw CJMSException("Session not available")
    }

    public func createBrowser(queue: Queue, selector: String): QueueBrowser {
        checkContextState()

        if (autoStart) {
            start()
        }

        if (let Some(session) <- this.activemqSession) {
            return session.createBrowser(queue, selector)
        }
        throw CJMSException("Session not available")
    }

    public func createTemporaryQueue(): TemporaryQueue {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createTemporaryQueue()
        }
        throw CJMSException("Session not available")
    }

    public func createTemporaryTopic(): TemporaryTopic {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createTemporaryTopic()
        }
        throw CJMSException("Session not available")
    }

    public func createMessage(): CJMSMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createMessage()
        }
        throw CJMSException("Session not available")
    }

    public func createTextMessage(): TextMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createTextMessage()
        }
        throw CJMSException("Session not available")
    }

    public func createTextMessage(text: String): TextMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createTextMessage(text)
        }
        throw CJMSException("Session not available")
    }

    public func createMapMessage(): MapMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createMapMessage()
        }
        throw CJMSException("Session not available")
    }

    public func createObjectMessage(): ObjectMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createObjectMessage()
        }
        throw CJMSException("Session not available")
    }

    public func createObjectMessage(object: Serializable<Any>): ObjectMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createObjectMessage(object)
        }
        throw CJMSException("Session not available")
    }

    public func createBytesMessage(): BytesMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createBytesMessage()
        }
        throw CJMSException("Session not available")
    }

    public func createBytesMessage(body: Array<Byte>): BytesMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createBytesMessage(body)
        }
        throw CJMSException("Session not available")
    }

    public func createStreamMessage(): StreamMessage {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.createStreamMessage()
        }
        throw CJMSException("Session not available")
    }

    public override func isClosed(): Bool {
        return closed
    }

    public func close(): Unit {
        if (let Some(producer) <- this.activemqMessageProducer) {
            producer.close()
        }
        if (let Some(session) <- this.activemqSession) {
            session.close()
        }
        if (connectionCounter.fetchSub(1) == 1) {
            closed = true
            this.activemqConnection.close()
        }
    }

    public func recover(): Unit {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            session.recover()
        }
    }

    public func acknowledge(): Unit {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            session.acknowledge()
        }
    }

    public func commit(): Unit {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.commit()
        }
    }

    public func rollback(): Unit {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.rollback()
        }
    }

    public mut prop exceptionListener: ?ExceptionListener {
        get() {
            return this.activemqConnection.exceptionListener
        }
        set(value) {
            this.activemqConnection.exceptionListener = value
        }
    }

    public func getTransacted(): Bool {
        checkContextState()
        if (let Some(session) <- this.activemqSession) {
            return session.getTransacted()
        }
        return false
    }

    public func getAcknowledgementMode(): AcknowledgeMode {
        return this.acknowledgeMode
    }

    public mut prop autoStart: Bool {
        get() {
            return this.autoStartVal
        }
        set(value) {
            this.autoStartVal = value
        }
    }

    public mut prop clientID: ?String {
        get() {
            return this.activemqConnection.getClientID()
        }
        set(value) {
            if (let Some(value) <- value) {
                this.activemqConnection.setClientID(value)
            }
        }
    }

    public func getMetaData(): ConnectionMetaData {
        return this.activemqConnection.getMetaData()
    }

    public func start(): Unit {
        checkContextState()
        if (started.compareAndSwap(false, true)) {
            this.activemqConnection.start()
        }
    }

    public func stop(): Unit {
        checkContextState()
        if (started.compareAndSwap(true, false)) {
            this.activemqConnection.stop()
        }
    }

    protected func checkContextState(): Unit {
        if (activemqSession.isNone()) {
            if (closed) {
                throw IllegalStateException("Context is closed")
            }
            this.activemqSession = activemqConnection.createSession(
                AcknowledgeMode.SESSION_TRANSACTED == acknowledgeMode, acknowledgeMode) as ActiveMQSession
        }
    }

    private func getCreatedActiveMQMessageProducer(): ActiveMQMessageProducer {
        checkContextState()
        var messageProducer: ActiveMQMessageProducer

        if (let Some(activemqMessageProducer) <- this.activemqMessageProducer) {
            messageProducer = activemqMessageProducer
        } else {
            if (let Some(activemqSession) <- activemqSession) {
                messageProducer = ActiveMQMessageProducer(activemqSession, activemqSession.getNextProducerId(), None,
                    activemqConnection.sendTimeout)
                this.activemqMessageProducer = messageProducer
            } else {
                throw CJMSException("Session not available")
            }
        }

        return messageProducer
    }
}
