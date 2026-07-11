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

public class ActiveMQMessageProducer <: ActiveMQMessageProducerSupport & Resource {
    private let info: ProducerInfo
    protected let closed: AtomicBool = AtomicBool(false)

    private var messageSequenceVal: Int64SequenceGenerator
    private var startTime: Int64 = 0
    private var transformerVal: ?MessageTransformer = None
    private var producerWindow: ?Usage = None

    public init(session: ActiveMQSession, poducerId: ProducerId, destination: ?ActiveMQDestination, sendTimeout: Int32) {
        super(session, sendTimeout)

        this.info = ProducerInfo(poducerId)
        if (let Some(destination) <- destination) {
            info.destination = destination
            if (let Some(options) <- destination.options) {
                //设置destination上携带的producer参数到ProducerInfo
                var producerOptions = TypeConversionSupport.convertMap<String>(
                    IntrospectionSupport.extractProperties<?String>(options, "producer."))
                IntrospectionSupport.setProperties(this.info, producerOptions)
                if (producerOptions.size > 0) {
                    throw CJMSException(
                        "There are ${producerOptions.size} producer options that couldn't be set on the producer. Check the options are spelled correctly. This producer cannot be started."
                    )
                }
            }
        }

        info.windowSize = session.connection.producerWindowSize
        this.messageSequenceVal = Int64SequenceGenerator()

        //开启流量控制
        if (session.connection.protocolVersion >= 3 && this.info.windowSize > 0) {
            var producerWindow = Usage("Producer Window: ${poducerId}")
            producerWindow.limit = Int64(this.info.windowSize)
            producerWindow.start()
            this.producerWindow = producerWindow
        }

        try {
            //将创建的MessageProducer保存到session
            this.session.addProducer(this)
            //发送ProducerInfo命令
            this.session.syncSendPacket(this.info)
        } catch (e: CJMSException) {
            session.removeProducer(this)
            throw e
        }

        this.transformer = session.transformer
    }

    public override func send(destination: Destination, message: CJMSMessage, deliveryMode: DeliveryMode,
        priority: Int32, timeToLive: Int64): Unit {
        this.send(destination, message, deliveryMode, priority, timeToLive, None)
    }

    public override func send(message: CJMSMessage, completionListener: CompletionListener): Unit {
        throw UnsupportedException("send(Message, CompletionListener) is not supported")
    }

    public override func send(
        message: CJMSMessage,
        deliveryMode: DeliveryMode,
        priority: Int32,
        timeToLive: Int64,
        completionListener: CompletionListener
    ): Unit {
        throw UnsupportedException(
            "send(Message, deliveryMode, priority, timetoLive, CompletionListener) is not supported")
    }

    public override func send(destination: Destination, message: CJMSMessage, completionListener: CompletionListener): Unit {
        throw UnsupportedException("send(Destination, Message, CompletionListener) is not supported")
    }

    /**
     * 异步发送消息到目标Destination,指定delivery mode, priority, time to live
     */
    public override func send(
        destination: Destination,
        message: CJMSMessage,
        deliveryMode: DeliveryMode,
        priority: Int32,
        timeToLive: Int64,
        completionListener: CompletionListener
    ): Unit {
        throw UnsupportedException(
            "send(Destination, Message, deliveryMode, priority, timetoLive, CompletionListener) is not supported")
    }

    public func send(message: CJMSMessage, onComplete: AsyncCallback): Unit {
        this.send(this.destination, message, this.deliveryMode, this.priority, this.timeToLive, onComplete)
    }

    public func send(destination: Destination, message: CJMSMessage, onComplete: AsyncCallback): Unit {
        this.send(destination, message, this.deliveryMode, this.priority, this.timeToLive, onComplete)
    }

    public func send(message: CJMSMessage, deliveryMode: DeliveryMode, priority: Int32, timeToLive: Int64,
        onComplete: AsyncCallback): Unit {
        this.send(this.destination, message, deliveryMode, priority, timeToLive, onComplete)
    }

    public func send(destination: Destination, message: CJMSMessage, deliveryMode: DeliveryMode, priority: Int32,
        timeToLive: Int64, onComplete: ?AsyncCallback): Unit {
        this.send(destination, message, deliveryMode, priority, timeToLive, disableMessageID, disableMessageTimestamp,
            onComplete)
    }

    public func send(destination: Destination, message: CJMSMessage, deliveryMode: DeliveryMode, priority: Int32,
        timeToLive: Int64, disableMessageID: Bool, disableMessageTimestamp: Bool, onComplete: ?AsyncCallback): Unit {
        checkClosed()
        let dest: ActiveMQDestination
        if (let Some(destination) <- info.destination) {
            dest = destination
        } else {
            dest = ActiveMQDestination.transform(destination)
        }

        var msg: CJMSMessage = message
        // 消息通过MessageTransformer转换
        if (let Some(transformer) <- transformer) {
            msg = transformer.producerTransform(session, this, message)
        }

        //流量控制
        if (let Some(producerWindow) <- producerWindow) {
            producerWindow.waitForSpace()
        }

        this
            .session
            .send(this, dest, message, deliveryMode, priority, timeToLive, disableMessageID, disableMessageTimestamp,
                producerWindow, sendTimeout, onComplete)
    }

    public prop destination: Destination {
        get() {
            checkClosed()
            if (let Some(destination) <- this.info.destination) {
                return destination
            }
            throw IllegalStateException("Destination not available")
        }
    }

    protected prop producerInfo: ProducerInfo {
        get() {
            return this.info
        }
    }

    public prop producerId: ?ProducerId {
        get() {
            if (let Some(producerId) <- this.info.producerId) {
                return producerId.copy()
            }
            return None
        }
    }

    protected mut prop messageSequence: Int64 {
        get() {
            return this.messageSequenceVal.getNextSequenceId()
        }
        set(value) {
            this.messageSequenceVal.setSequence(value)
        }
    }

    public override func checkClosed() {
        if (isClosed()) {
            throw IllegalStateException("The producer is closed")
        }
    }

    public override func isClosed(): Bool {
        return this.closed.load()
    }

    public override func close(): Unit {
        if (!closed.load()) {
            dispose()
            this.session.asyncSendPacket(this.info.createRemoveInfo())
        }
    }

    protected func dispose(): Unit {
        if (closed.compareAndSwap(false, true)) {
            if (let Some(producerWindow) <- producerWindow) {
                producerWindow.stop()
            }
            session.removeProducer(this)
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

    public func onProducerAck(pa: ProducerAck): Unit {
        if (let Some(producerWindow) <- this.producerWindow) {
            producerWindow.decreaseUsage(Int64(pa.size))
        }
    }
}
