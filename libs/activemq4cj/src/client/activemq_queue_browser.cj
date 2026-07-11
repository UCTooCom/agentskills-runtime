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

public class ActiveMQQueueBrowser <: Iterator<CJMSMessage> & QueueBrowser {
    private let session: ActiveMQSession
    private let destination: ActiveMQDestination
    private let consumerId: ConsumerId
    private let selector: ?String

    private var consumer: ?ActiveMQMessageConsumer = None
    private var closed: Bool = false
    private var mutex: Mutex = Mutex()
    private let condition: Condition = synchronized(mutex) {
        mutex.condition()
    }
    private let dispatchAsync: Bool
    protected var browseDone: Bool = false

    protected init(session: ActiveMQSession, consumerId: ConsumerId, destination: ActiveMQDestination,
        selector: ?String, dispatchAsync: Bool) {
        if (destination.name.isNone()) {
            throw InvalidDestinationException("The destination object was not given a physical name")
        }

        this.session = session
        this.consumerId = consumerId
        this.destination = destination
        this.selector = selector
        this.dispatchAsync = dispatchAsync
        this.consumer = createConsumer()
    }

    private func createConsumer(): ActiveMQMessageConsumer {
        browseDone = false

        var prefetchPolicy: ActiveMQPrefetchPolicy = session.connection.prefetchPolicy
        // 创建用于浏览消息的消费者
        let browseConsumer = BrowsingMessageConsumer(this, session, consumerId, destination, None, selector,
            prefetchPolicy.queueBrowserPrefetch, prefetchPolicy.maximumPendingMessageLimit, false, true, dispatchAsync)

        //加入消息调度
        session.addConsumer(browseConsumer)
        return browseConsumer
    }

    private func destroyConsumer(): Unit {
        if (let Some(consumer) <- this.consumer) {
            if (session.getTransacted()) {
                if (let Some(transactionContext) <- session.transactionContext) {
                    if (transactionContext.isInLocalTransaction()) {
                        session.commit()
                    }
                }
            }
            consumer.close()
            this.consumer = None
        }
    }

    /**
     * 通过迭代来浏览消息
     */
    public override func next(): Option<CJMSMessage> {
        while (true) {
            synchronized(mutex) {
                if (let Some(consumer) <- consumer) {
                    try {
                        var answer = consumer.receiveNoWait()
                        if (answer.isSome()) {
                            return answer
                        }
                    } catch (ex: CJMSException) {
                        return None
                    }
                } else {
                    return None
                }
            }

            // 当dispatch方法接收到message为None的MessageDispatch，browseDone置为true，next返回None
            if (browseDone || !session.isRunning()) {
                destroyConsumer()
                return None
            }

            waitForMessage()
        }
        return None
    }

    /**
     * 通过发送MessagePull来继续获取消息
     */
    private func waitForMessage(): Unit {
        if (let Some(consumer) <- consumer) {
            try {
                consumer.sendPullCommand(Duration.millisecond * -1)
                synchronized(mutex) {
                    condition.wait(timeout: Duration.millisecond * 2000)
                }
            } catch (ex: CJMSException) {
            }
        }
    }

    public override func isClosed(): Bool {
        return closed
    }

    public override func close(): Unit {
        browseDone = true
        destroyConsumer()
        closed = true
    }

    protected func notifyMessageAvailable(): Unit {
        synchronized(mutex) {
            condition.notifyAll()
        }
    }

    public prop queue: Queue {
        get() {
            if (let Some(queue) <- (destination as Queue)) {
                return queue
            }
            throw InvalidDestinationException("The destination is not a Queue")
        }
    }

    public prop messageSelector: ?String {
        get() {
            return this.selector
        }
    }
}

public class BrowsingMessageConsumer <: ActiveMQMessageConsumer {
    private let parent: ActiveMQQueueBrowser

    public init(parent: ActiveMQQueueBrowser, session: ActiveMQSession, id: ConsumerId,
        destination: ActiveMQDestination, name: ?String, selector: ?String, prefetch: Int32,
        maxPendingMessageCount: Int32, noLocal: Bool, browser: Bool, dispatchAsync: Bool) {
        super(session, id, destination, name, selector, prefetch, maxPendingMessageCount, noLocal, browser,
            dispatchAsync, None)
        this.parent = parent
    }

    /**
     * 重写dispatch方法，当message为None时设置browseDone为true，此时next方法退出，消息浏览结束
     */
    public override func dispatch(md: MessageDispatch): Unit {
        if (md.message.isNone()) {
            parent.browseDone = true
        } else {
            super.dispatch(md)
        }

        parent.notifyMessageAvailable()
    }
}
