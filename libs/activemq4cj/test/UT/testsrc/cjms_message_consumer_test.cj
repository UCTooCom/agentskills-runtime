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
package activemq_client_unit_test

@Test
public class CJMSMessageConsumerTest {
    @TestCase
    public func testSyncReceiveWithExpirationChecks(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testSyncReceiveWithExpirationChecks")
            var consumer = session.createConsumer(destination)
            var producer = session.createProducer(destination)
            producer.timeToLive = 2

            producer.send(session.createTextMessage("test"))

            // 让消息全部过期
            sleep(Duration.millisecond * 4)

            @Assert(consumer.receive(Duration.millisecond * 1000).isNone())
        }
    }

    @TestCase
    public func testSyncReceiveWithIgnoreExpirationChecks(): Unit {
        try (connection = TestUtils.createConnection()) {
            if (let Some(connection) <- (connection as ActiveMQConnection)) {
                connection.consumerExpiryCheckEnabled = false
            }
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testSyncReceiveWithIgnoreExpirationChecks")
            var consumer = session.createConsumer(destination)
            var producer = session.createProducer(destination)
            producer.timeToLive = 2000

            producer.send(session.createTextMessage("test"))

            // 允许消息过期
            sleep(Duration.millisecond * 4000)

            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())
        }
    }

    @TestCase
    public func testAsyncReceiveWithoutExpirationChecks(): Unit {
        var counter: SyncCounter = SyncCounter(1)

        try (connection = TestUtils.createConnection()) {
            if (let Some(connection) <- (connection as ActiveMQConnection)) {
                connection.consumerExpiryCheckEnabled = false
            }
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testAsyncReceiveWithoutExpirationChecks")
            var consumer = session.createConsumer(destination)
            consumer.messageListener = AnonymousMessageListener(counter)

            var producer = session.createProducer(destination)
            producer.timeToLive = 2000

            producer.send(session.createTextMessage("test"))

            // 允许消息过期
            sleep(Duration.millisecond * 4000)
            counter.waitUntilZero(timeout: Duration.second * 5)
            @Assert(counter.count == 0)
        }
    }

    @TestCase
    public func testCloseWhileReceiveIsBlocked(): Unit {
        //阻塞获取Message时关闭Consumer, 返回None
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testCloseWhileReceiveIsBlocked")
            let consumer = session.createConsumer(destination)

            spawn {
                =>
                sleep(Duration.second * 2)
                consumer.close()
            }

            @Assert(consumer.receive().isNone())
        }
    }

    @TestCase
    public func testRoundRobinDispatch(): Unit {
        //测试非独占的情况下，消息会分别调度给两个消费者
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testRoundRobinDispatch")

            var consumer1 = session.createConsumer(destination)
            var consumer2 = session.createConsumer(destination)

            var producer = session.createProducer(destination)
            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))

            @Assert(consumer1.receive(Duration.second * 1).isSome())
            @Assert(consumer2.receive(Duration.second * 1).isSome())

            @Assert(consumer1.receiveNoWait().isNone())
            @Assert(consumer2.receiveNoWait().isNone())
        }
    }

    @TestCase
    public func testDispatchExclusive(): Unit {
        //测试独占的情况下，只有一个消费者可以接收到消息
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testDispatchExclusive?consumer.exclusive=true")

            var consumer1 = session.createConsumer(destination)
            var consumer2 = session.createConsumer(destination)

            var producer = session.createProducer(destination)
            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            producer.send(session.createTextMessage("3nd"))

            var msg: ?CJMSMessage = consumer1.receive(Duration.second * 1)
            if (let Some(msg) <- msg) {
                for (i in 0..2) {
                    @Assert(consumer1.receive(Duration.second * 1).isSome())
                }
            } else {
                for (i in 0..3) {
                    @Assert(consumer2.receive(Duration.second * 1).isSome())
                }
            }

            @Assert(consumer1.receiveNoWait().isNone())
            @Assert(consumer2.receiveNoWait().isNone())
        }
    }

    @TestCase
    public func testCreateConsumer(): Unit {
        //测试异步创建consumer
        var done = SyncCounter(1)

        try (connection = TestUtils.createConnection()) {
            let publisherSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let consumerSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let topic = publisherSession.createTopic("Test.Topic")

            let consumer = consumerSession.createConsumer(topic)
            consumer.messageListener = AsynchronuslyMessageListener(consumerSession, done, topic)

            let producer = publisherSession.createProducer(topic)
            connection.start()

            producer.send(publisherSession.createTextMessage("test"))
            done.waitUntilZero(timeout: Duration.second * 5)
            @Assert(done.count == 0)
        }
    }

    @TestCase
    public func testMessageListenerWithConsumerCanBeStopped(): Unit {
        var array: Array<Byte> = [ActiveMQDestination.QUEUE_TYPE, ActiveMQDestination.TOPIC_TYPE,
            ActiveMQDestination.TEMP_QUEUE_TYPE, ActiveMQDestination.TEMP_TOPIC_TYPE]
        for (destinationType in array) {
            let counter: AtomicInt64 = AtomicInt64(0)
            let done1: SyncCounter = SyncCounter(1)
            let done2: SyncCounter = SyncCounter(1)

            try (connection = TestUtils.createConnection()) {
                connection.start()
                let session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

                var destination: Destination
                match (destinationType) {
                    case 1 => destination = session.createQueue("testMessageListenerWithConsumerCanBeStopped")
                    case 2 => destination = session.createTopic("testMessageListenerWithConsumerCanBeStopped")
                    case 5 => destination = session.createTemporaryQueue()
                    case 6 => destination = session.createTemporaryTopic()
                    case _ => throw Exception()
                }

                var consumer: MessageConsumer = session.createConsumer(destination)
                consumer.messageListener = StoppedMessageListener(counter, done1, done2)

                // 测试消费者调度正常运行
                sendMessages(session, destination, 1)
                done1.waitUntilZero(timeout: Duration.second * 1)
                @Assert(1, counter.load())

                // 停止消费者
                if (let Some(consumer) <- (consumer as ActiveMQMessageConsumer)) {
                    consumer.stop()
                }

                // 发送消息，这时消息没有被投递给消费者
                sendMessages(session, destination, 1)
                done2.waitUntilZero(timeout: Duration.millisecond * 500)
                @Assert(1, counter.load())

                // 启动消费者，消息现在被投递给消费者
                if (let Some(consumer) <- (consumer as ActiveMQMessageConsumer)) {
                    consumer.start()
                }
                done2.waitUntilZero(timeout: Duration.millisecond * 500)
                @Assert(2, counter.load())
            }
        }
    }

    private func sendMessages(session: Session, destination: Destination, count: Int64): Unit {
        var producer = session.createProducer(destination)
        for (i in 0..count) {
            producer.send(session.createTextMessage(i.toString()))
        }
        producer.close()
    }

    @TestCase
    public func testMessageListenerWithConsumerCanBeStoppedConcurently(): Unit {
        var counter = AtomicInt64(0)
        var closeDone = SyncCounter(1)

        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var destination = session.createQueue("testMessageListenerWithConsumerCanBeStoppedConcurently")
            TestUtils.purgeQueue(connection, destination)

            sendMessages(session, destination, 2000)

            var consumer = session.createConsumer(destination)
            var threadPool = ThreadPoolFactory.createThreadPool(1, 100, 100, Duration.second * 5)
            consumer.messageListener = StoppedConcurentlyMessageListener(counter, closeDone, consumer, threadPool)
            closeDone.waitUntilZero(timeout: Duration.second * 20)
            @Assert(closeDone.count == 0)
        }
    }

    @TestCase
    public func testMutiReceiveWithPrefetch1(): Unit {
        //测试prefetchSize设置为1
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.prefetchPolicy.setAll(1)
            connection.start()

            var array: Array<Byte> = [ActiveMQDestination.QUEUE_TYPE, ActiveMQDestination.TOPIC_TYPE,
                ActiveMQDestination.TEMP_QUEUE_TYPE, ActiveMQDestination.TEMP_TOPIC_TYPE]
            var ackModeArray: Array<AcknowledgeMode> = [AcknowledgeMode.AUTO_ACKNOWLEDGE,
                AcknowledgeMode.DUPS_OK_ACKNOWLEDGE, AcknowledgeMode.CLIENT_ACKNOWLEDGE]
            //测试目的地类型是Topic,Queue,TempQueue,TempTopic和确认模式分别为AUTO_ACKNOWLEDGE，DUPS_OK_ACKNOWLEDGE，CLIENT_ACKNOWLEDGE的多种情况
            for (destinationType in array) {
                for (ackMode in ackModeArray) {
                    var session = connection.createSession(false, ackMode)
                    var destination: Destination
                    match (destinationType) {
                        case 1 => destination = session.createQueue("testMutiReceiveWithPrefetch1")
                        case 2 => destination = session.createTopic("testMutiReceiveWithPrefetch1")
                        case 5 => destination = session.createTemporaryQueue()
                        case 6 => destination = session.createTemporaryTopic()
                        case _ => throw Exception()
                    }
                    var consumer = session.createConsumer(destination)

                    // Send the messages
                    sendMessages(session, destination, 4)

                    // Make sure 4 messages were delivered.
                    var message: ?CJMSMessage = None
                    for (i in 0..4) {
                        message = consumer.receive()
                        @Assert(message.isSome())
                    }
                    @Assert(consumer.receiveNoWait().isNone())
                    if (let Some(message) <- message) {
                        message.acknowledge()
                    }
                    consumer.close()
                    session.close()
                }
            }
        }
    }

    @TestCase
    public func testSendReceiveBytesMessage(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testSendReceiveBytesMessage")
            var producer = session.createProducer(destination)
            var consumer = session.createConsumer(destination)

            var bytesMessage = session.createBytesMessage()
            bytesMessage.writeBool(true)
            bytesMessage.writeBool(false)
            producer.send(bytesMessage)

            var msg: ?CJMSMessage = consumer.receive(Duration.millisecond * 1000)
            if (let Some(msg) <- msg) {
                if (let Some(bytesMessage) <- (msg as BytesMessage)) {
                    @Assert(true, bytesMessage.readBool())
                    @Assert(false, bytesMessage.readBool())
                }
            }
            @Assert(consumer.receiveNoWait().isNone())
        }
    }

    @TestCase
    public func testSetMessageListenerAfterStart(): Unit {
        let counter: AtomicInt64 = AtomicInt64(0)
        let done: SyncCounter = SyncCounter(1)

        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testSetMessageListenerAfterStart")
            var consumer = session.createConsumer(destination)

            sendMessages(session, destination, 4)

            consumer.messageListener = AfterMessageListener(counter, done)

            done.waitUntilZero(timeout: Duration.millisecond * 1000)
            @Assert(done.count == 0)
            @Assert(counter.load() == 4)
        }
    }

    @TestCase
    public func testPassMessageListenerIntoCreateConsumer(): Unit {
        let counter: AtomicInt64 = AtomicInt64(0)
        let done: SyncCounter = SyncCounter(1)

        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testPassMessageListenerIntoCreateConsumer")
            var consumer = session.createConsumer(destination)
            consumer.messageListener = AfterMessageListener(counter, done)

            sendMessages(session, destination, 4)

            done.waitUntilZero(timeout: Duration.millisecond * 1000)
            @Assert(done.count == 0)
            @Assert(counter.load() == 4)
        }
    }

    @TestCase
    public func testMessageListenerOnMessageCloseUnackedWithPrefetch1StayInQueue(): Unit {
        var array: Array<Byte> = [ActiveMQDestination.QUEUE_TYPE]
        var ackModeArray: Array<AcknowledgeMode> = [AcknowledgeMode.AUTO_ACKNOWLEDGE, AcknowledgeMode.CLIENT_ACKNOWLEDGE]
        for (destinationType in array) {
            for (ackMode in ackModeArray) {
                let counter: AtomicInt64 = AtomicInt64(0)
                let sendDone: SyncCounter = SyncCounter(1)
                let got2Done: SyncCounter = SyncCounter(1)
                try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
                    connection.prefetchPolicy.setAll(1)
                    connection.optimizedMessageDispatch = false
                    connection.start()

                    var session = connection.createSession(false, ackMode)
                    var destination: Destination
                    match (destinationType) {
                        case 1 => destination = session.createQueue("test.prefetch1")
                        case 2 => destination = session.createTopic("test.prefetch1")
                        case 5 => destination = session.createTemporaryQueue()
                        case 6 => destination = session.createTemporaryTopic()
                        case _ => throw Exception()
                    }

                    TestUtils.purgeQueue(connection, destination)

                    var consumer = session.createConsumer(destination)

                    consumer.messageListener = UnackedMessageListener(counter, sendDone, got2Done, connection)

                    sendMessages(session, destination, 4)
                    sendDone.dec()

                    got2Done.waitUntilZero(timeout: Duration.millisecond * 10000)
                    @Assert(got2Done.count == 0)

                    try (destConnection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
                        destConnection.prefetchPolicy.setAll(1)
                        destConnection.start()

                        // Pickup the remaining messages.
                        let done2 = SyncCounter(1)
                        session = destConnection.createSession(false, ackMode)
                        consumer = session.createConsumer(destination)
                        consumer.messageListener = UnackedMessageListener2(counter, done2)

                        done2.waitUntilZero(timeout: Duration.millisecond * 1000)
                        @Assert(done2.count == 0)
                        @Assert(counter.load() == 4)
                    }
                }
            }
        }
    }

    @TestCase
    public func testMessageListenerWithConsumerWithPrefetch1(): Unit {
        let counter: AtomicInt64 = AtomicInt64(0)
        let done: SyncCounter = SyncCounter(1)

        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.prefetchPolicy.setAll(1)
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testMessageListenerWithConsumerWithPrefetch1")
            var consumer = session.createConsumer(destination)
            consumer.messageListener = AfterMessageListener(counter, done)

            sendMessages(session, destination, 4)

            done.waitUntilZero(timeout: Duration.millisecond * 1000)
            @Assert(done.count == 0)
            @Assert(counter.load() == 4)
        }
    }

    @TestCase
    public func testUnackedWithPrefetch1StayInQueue() {
        var ackModeArray: Array<AcknowledgeMode> = [AcknowledgeMode.AUTO_ACKNOWLEDGE,
            AcknowledgeMode.DUPS_OK_ACKNOWLEDGE, AcknowledgeMode.CLIENT_ACKNOWLEDGE]
        for (ackMode in ackModeArray) {
            var destination = ActiveMQQueue("testUnackedWithPrefetch1StayInQueue_${DateTime.now()}")

            try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
                connection.prefetchPolicy.setAll(1)
                connection.start()

                var session = connection.createSession(false, ackMode)
                var consumer = session.createConsumer(destination)

                sendMessages(session, destination, 4)

                // 仅接收前两条消息
                var message: ?CJMSMessage = None
                for (i in 0..2) {
                    message = consumer.receive(Duration.millisecond * 1000)
                    @Assert(message.isSome())
                }
                if (let Some(msg) <- message) {
                    msg.acknowledge()
                }
            }

            try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
                connection.prefetchPolicy.setAll(1)
                connection.start()

                var session = connection.createSession(false, ackMode)
                var consumer = session.createConsumer(destination)

                var message: ?CJMSMessage = None
                for (i in 0..2) {
                    message = consumer.receive(Duration.millisecond * 1000)
                    @Assert(message.isSome())
                }
                if (let Some(msg) <- message) {
                    msg.acknowledge()
                }
                @Assert(consumer.receiveNoWait().isNone())
            }
        }
    }

    @TestCase
    public func testPrefetch1MessageNotDispatched(): Unit {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.prefetchPolicy.setAll(1)
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testPrefetch1MessageNotDispatched")

            //Clean up residual messages in the queue
            TestUtils.purgeQueue(connection, destination)

            session = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var consumer = session.createConsumer(destination)

            sendMessages(session, destination, 2)
            session.commit()

            try (connection2 = TestUtils.createConnection()) {
                connection2.start()
                var session2 = connection2.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
                var consumer2 = session2.createConsumer(destination)

                var message1: ?CJMSMessage = consumer.receive(Duration.millisecond * 1000)
                @Assert(message1.isSome())

                var message2 = consumer2.receive(Duration.millisecond * 5000)
                @Assert(message2.isSome())

                session2.commit()
            }

            @Assert(consumer.receiveNoWait().isNone())
        }
    }

    @TestCase
    public func testDontStart(): Unit {
        //测试Connection不执行start方法，Consumer收不到消息
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testDontStart")
            var consumer = session.createConsumer(destination)

            sendMessages(session, destination, 1)

            @Assert(consumer.receive(Duration.millisecond * 1000).isNone())
        }
    }

    @TestCase
    public func testStartAfterSend(): Unit {
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testStartAfterSend")
            var consumer = session.createConsumer(destination)

            sendMessages(session, destination, 1)

            connection.start()

            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())
            @Assert(consumer.receiveNoWait().isNone())
        }
    }

    @TestCase
    public func testReceiveMessageWithConsumer(): Unit {
        var array: Array<Byte> = [ActiveMQDestination.QUEUE_TYPE, ActiveMQDestination.TOPIC_TYPE,
            ActiveMQDestination.TEMP_QUEUE_TYPE, ActiveMQDestination.TEMP_TOPIC_TYPE]
        for (destinationType in array) {
            try (connection = TestUtils.createConnection()) {
                connection.start()
                var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
                var destination: Destination
                match (destinationType) {
                    case 1 => destination = session.createQueue("testReceiveMessageWithConsumer")
                    case 2 => destination = session.createTopic("testReceiveMessageWithConsumer")
                    case 5 => destination = session.createTemporaryQueue()
                    case 6 => destination = session.createTemporaryTopic()
                    case _ => throw Exception()
                }
                var consumer = session.createConsumer(destination)

                sendMessages(session, destination, 1)

                // 确保只收到一条消息
                var msg: ?CJMSMessage = consumer.receive(Duration.millisecond * 1000)
                @Assert(msg.isSome())

                if (let Some(msg) <- msg) {
                    if (let Some(textMessage) <- (msg as TextMessage)) {
                        @Assert("0", textMessage.text)
                    }
                }
                @Assert(consumer.receiveNoWait().isNone())
            }
        }
    }

    @TestCase
    public func testDupsOkConsumer(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.DUPS_OK_ACKNOWLEDGE)
            var destination = session.createQueue("testDupsOkConsumer")
            var consumer = session.createConsumer(destination)

            sendMessages(session, destination, 4)

            for (i in 0..4) {
                var msg = consumer.receive(Duration.millisecond * 1000)
                @Assert(msg.isSome())
            }
            @Assert(consumer.receive(Duration.millisecond * 500).isNone())

            // 关闭消费者，这时候应该没有剩余的消息
            consumer.close()

            consumer = session.createConsumer(destination)
            @Assert(consumer.receive(Duration.millisecond * 500).isNone())
        }
    }

    @TestCase
    public func testRedispatchOfUncommittedTx(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var destination = session.createQueue("testRedispatchOfUncommittedTx")

            TestUtils.purgeQueue(connection, destination)

            sendMessages(session, destination, 2)
            session.commit()

            var consumer = session.createConsumer(destination)
            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())
            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())

            // 事务未提交，创建另一组消费者
            var redispatchSession = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var redispatchConsumer = redispatchSession.createConsumer(destination)

            // 没有提交事务就关闭session，这时消息应该被重新转发到redispatchConsumer
            session.close()

            var msg: ?CJMSMessage = redispatchConsumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                @Assert(msg.getCJMSRedelivered())
                @Assert(2 == msg.getInt64Property("JMSXDeliveryCount"))
            }

            msg = redispatchConsumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                @Assert(msg.getCJMSRedelivered())
                @Assert(2 == msg.getInt64Property("JMSXDeliveryCount"))
            }
            redispatchSession.commit()

            @Assert(redispatchConsumer.receive(Duration.millisecond*500).isNone())
            redispatchSession.close()
        }
    }

    @TestCase
    public func testRedispatchOfRolledbackTx(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var destination = session.createQueue("testRedispatchOfRolledbackTx")

            TestUtils.purgeQueue(connection, destination)

            sendMessages(session, destination, 2)
            session.commit()

            var consumer = session.createConsumer(destination)
            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())
            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())

            // 事务未提交，创建另一组消费者
            var redispatchSession = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var redispatchConsumer = redispatchSession.createConsumer(destination)

            session.rollback()
            session.close()

            var msg = redispatchConsumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                @Assert(msg.getCJMSRedelivered())
                @Assert(2 == msg.getInt64Property("JMSXDeliveryCount"))
            }

            msg = redispatchConsumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                @Assert(msg.getCJMSRedelivered())
                @Assert(2 == msg.getInt64Property("JMSXDeliveryCount"))
            }
            redispatchSession.commit()

            @Assert(redispatchConsumer.receive(Duration.millisecond*500).isNone())
            redispatchSession.close()
        }
    }

    @TestCase
    public func testExceptionOnClientAckAfterConsumerClose(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var destination = session.createQueue("testExceptionOnClientAckAfterConsumerClose")

            sendMessages(session, destination, 1)

            var consumer = session.createConsumer(destination)
            var message = consumer.receive(Duration.millisecond * 1000)
            @Assert(message.isSome())
            consumer.close()

            try {
                if (let Some(message) <- message) {
                    message.acknowledge()
                }
                throw CJMSException("Expect exception on ack after close - consumer gone so message available again")
            } catch (expected: CJMSException) {}

            var redispatchSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var redispatchConsumer = redispatchSession.createConsumer(destination)
            var msg = redispatchConsumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())

            redispatchSession.close()
        }
    }

    @TestCase
    public func testAckOfExpired(): Unit {
        var borkerURL = TestUtils.getBrokerURL()
        if (borkerURL.indexOf("?").isSome()) {
            borkerURL += "&jms.sendAcksAsync=false"
        } else {
            borkerURL += "?jms.sendAcksAsync=false"
        }

        var factory = ActiveMQConnectionFactory(borkerURL)
        try (connection = (factory.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.prefetchPolicy.setAll(4)
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createTopic("testAckOfExpired")

            var consumer = session.createConsumer(destination)

            var sendSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var producer = sendSession.createProducer(destination)
            producer.timeToLive = 500
            let count = 4
            for (i in 0..count) {
                var message: TextMessage = sendSession.createTextMessage(i.toString())
                producer.send(message)
            }

            // 让第一批消息过期
            sleep(Duration.millisecond * 1000)

            producer.timeToLive = 0
            for (i in 0..count) {
                var message: TextMessage = sendSession.createTextMessage("no expiry${i}")
                producer.send(message)
            }

            for (i in 0..count) {
                var msg: ?CJMSMessage = consumer.receive()
                @Assert(msg.isSome())
                if (let Some(textMessage) <- (msg as TextMessage)) {
                    if (let Some(text) <- textMessage.text) {
                        @Assert(text.contains("no expiry"))
                    } else {
                        @Assert(false)
                    }
                }
                session.acknowledge()
            }
        }
    }

    @TestCase
    public func testSetListenerFromListener() {
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var dest = session.createQueue("testSetListenerFromListener${DateTime.now()}")
            let consumer = session.createConsumer(dest)

            let latch = SyncCounter(2)
            let first: AtomicBool = AtomicBool(true)
            let results: LinkedList<Any> = LinkedList<Any>()

            consumer.messageListener = ListenerMessageListener(first, latch, consumer, results)

            connection.start()
            var producer = session.createProducer(dest)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT
            producer.send(session.createTextMessage("first"))
            producer.send(session.createTextMessage("second"))

            latch.waitUntilZero(timeout: Duration.second * 5)
            @Assert(latch.count == 0)
            @Assert(2, results.size)

            if (let Some(first) <- results.removeFirst()) {
                if (let Some(textMessage) <- (first as TextMessage)) {
                    @Assert(textMessage.text == Some("first"))
                }
            }

            if (let Some(last) <- results.removeLast()) {
                if (let Some(textMessage) <- (last as TextMessage)) {
                    @Assert(textMessage.text == Some("second"))
                }
            }
        }
    }

    @TestCase
    public func testNewConsumerSetListenerFromListener(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var dest = session.createQueue("testNewConsumerSetListenerFromListener")
            TestUtils.purgeQueue(connection, dest)

            let latch = SyncCounter(2)
            let first: AtomicBool = AtomicBool(true)
            let results: LinkedList<Any> = LinkedList<Any>()

            let consumer = session.createConsumer(dest)
            consumer.messageListener = NewListenerMessageListener(first, latch, session, results, dest)

            var producer = session.createProducer(dest)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT
            producer.send(session.createTextMessage("first"))
            producer.send(session.createTextMessage("second"))

            latch.waitUntilZero(timeout: Duration.second * 5)
            @Assert(latch.count == 0)
            @Assert(2, results.size)

            if (let Some(first) <- results.removeFirst()) {
                if (let Some(textMessage) <- (first as TextMessage)) {
                    @Assert(textMessage.text, Some("first"))
                }
            }

            if (let Some(last) <- results.removeLast()) {
                if (let Some(textMessage) <- (last as TextMessage)) {
                    @Assert(textMessage.text, Some("second"))
                }
            }
        }
    }

    @TestCase
    public func testAckedMessageAreConsumed(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            let queue = session.createQueue("testAckedMessageAreConsumed")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("Hello"))

            //消费消息
            var consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                msg.acknowledge()
            }

            session.close()
            session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)

            consumer = session.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 500)
            @Assert(msg.isNone())

            session.close()
        }
    }

    @TestCase
    public func testLastMessageAcked(): Unit {
        //测试手动确认
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var queue = session.createQueue("testLastMessageAcked")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("Hello"))
            producer.send(session.createTextMessage("Hello2"))
            producer.send(session.createTextMessage("Hello3"))

            // 消费消息
            var consumer = session.createConsumer(queue)
            var msg: ?CJMSMessage = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                msg.acknowledge()
            }

            // 重置session
            session.close()
            session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)

            // 尝试消费消息
            consumer = session.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 500)
            @Assert(msg.isNone())

            session.close()
        }
    }

    @TestCase
    public func testUnAckedMessageAreNotConsumedOnSessionClose(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var queue = session.createQueue("testUnAckedMessageAreNotConsumedOnSessionClose")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("Hello"))

            // 接收消息
            var consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            // 不确认消息

            // 重置session，未确认的消息将被重发
            session.close()
            session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)

            // 再次消费消息
            consumer = session.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 2000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                msg.acknowledge()
            }

            session.close()
        }
    }

    @TestCase
    public func testAckedMessageAreConsumedWithClientAck(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var queue = session.createQueue("testAckedMessageAreConsumedWithClientAck")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("Hello"))

            // 消费消息
            var consumer = session.createConsumer(queue)
            consumer.messageListener = ClientAckMessageListener(false)

            sleep(Duration.millisecond * 10000)

            session.close()

            session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)

            // 尝试消费消息
            consumer = session.createConsumer(queue)
            var msg: ?CJMSMessage = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isNone())

            session.close()
        }
    }

    @TestCase
    public func testAutoAckedMessageAreConsumed(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = session.createQueue("testAutoAckedMessageAreConsumed")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("Hello"))

            // 消费消息
            var consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())

            session.close()
            session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            // 尝试再次消费消息
            consumer = session.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isNone())

            session.close()
        }
    }

    @TestCase
    public func testAutoAckedMessageAreConsumedWithMessageListener(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = session.createQueue("testAutoAckedMessageAreConsumedWithMessageListener")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("Hello"))

            // 消费消息
            var consumer = session.createConsumer(queue)
            consumer.messageListener = AutoAckMessageListener()

            sleep(Duration.millisecond * 10000)
            session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            // 尝试再次消费，以确保消息得到确认
            consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isNone())

            session.close()
        }
    }

    @TestCase
    public func testConsumerReceiveBeforeMessageDispatched(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            let session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let queue = session.createQueue("testConsumerReceiveBeforeMessageDispatched")
            spawn {
                sleep(Duration.second * 10)
                let producer = session.createProducer(queue)
                producer.send(session.createTextMessage("Hello"))
            }

            let consumer = session.createConsumer(queue)
            let msg = consumer.receive(Duration.second * 60)
            @Assert(msg.isSome())
            session.close()
        }
    }

    @TestCase
    public func testConsumerReceivePrefetchZeroRedeliveryZero(): Unit {
        let queue = ActiveMQQueue("test.prefetch.zero")

        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            var producer = session.createProducer(queue)
            var textMessage = session.createTextMessage("test Message")
            producer.send(textMessage)
            session.close()

            session = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.second * 2)
            @Assert(msg.isSome())
            session.rollback()
            session.close()
        }

        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.prefetchPolicy.queuePrefetch = 0
            if (let Some(redeliveryPolicy) <- connection.getRedeliveryPolicy()) {
                redeliveryPolicy.maximumRedeliveries = 0
            }
            connection.start()

            var session = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.second * 2)
            @Assert(msg.isNone())
        }
    }

    @TestCase
    public func testFailoverToAnotherExclusiveConsumerCreatedFirst(): Unit {
        //测试独占消费故障切换
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("test.exclusive.0?consumer.exclusive=true")
            var fallbackQueue = session.createQueue("test.exclusive.0")

            var consumer1 = session.createConsumer(destination)
            var consumer2 = session.createConsumer(destination)
            var consumer3 = session.createConsumer(fallbackQueue)

            var producer = session.createProducer(destination)
            producer.send(session.createTextMessage("testMessage"))

            @Assert(consumer1.receive(Duration.millisecond * 1000).isSome())
            @Assert(consumer2.receive(Duration.millisecond * 1000).isNone())
            @Assert(consumer3.receive(Duration.millisecond * 1000).isNone())

            consumer1.close()

            producer.send(session.createTextMessage("2ndTestMessage"))

            @Assert(consumer2.receive(Duration.millisecond * 1000).isSome())
            @Assert(consumer3.receive(Duration.millisecond * 1000).isNone())
        }
    }

    @TestCase
    public func testFailoverToAnotherExclusiveConsumerCreatedAfter(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var exclusiveSession1 = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var exclusiveSession2 = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var fallbackSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var senderSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            var exclusiveQueue = ActiveMQQueue("test.exclusive.1?consumer.exclusive=true")
            var exclusiveConsumer1 = exclusiveSession1.createConsumer(exclusiveQueue)

            var fallbackQueue = ActiveMQQueue("test.exclusive.1")
            var fallbackConsumer = fallbackSession.createConsumer(fallbackQueue)

            var exclusiveConsumer2 = exclusiveSession2.createConsumer(exclusiveQueue)

            var senderQueue = ActiveMQQueue("test.exclusive.1")

            var producer = senderSession.createProducer(senderQueue)

            var msg = senderSession.createTextMessage("test")
            producer.send(msg)
            sleep(Duration.millisecond * 100)

            @Assert(exclusiveConsumer1.receive(Duration.millisecond * 100).isSome())
            @Assert(exclusiveConsumer2.receive(Duration.millisecond * 100).isNone())
            @Assert(fallbackConsumer.receive(Duration.millisecond * 100).isNone())

            exclusiveConsumer1.close()

            producer.send(msg)
            producer.send(msg)

            @Assert(exclusiveConsumer2.receive(Duration.millisecond * 1000).isSome())
            @Assert(fallbackConsumer.receive(Duration.millisecond * 100).isNone())
        }
    }

    @TestCase
    public func testFailoverToNonExclusiveConsumer(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var exclusiveSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var fallbackSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var senderSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            var exclusiveQueue = ActiveMQQueue("test.exclusive.2?consumer.exclusive=true")
            var exclusiveConsumer = exclusiveSession.createConsumer(exclusiveQueue)

            var fallbackQueue = ActiveMQQueue("test.exclusive.2")
            var fallbackConsumer = fallbackSession.createConsumer(fallbackQueue)

            var senderQueue = ActiveMQQueue("test.exclusive.2")

            var producer = senderSession.createProducer(senderQueue)

            var msg = senderSession.createTextMessage("test")
            producer.send(msg)
            sleep(Duration.millisecond * 100)

            @Assert(exclusiveConsumer.receive(Duration.millisecond * 100).isSome())
            @Assert(fallbackConsumer.receive(Duration.millisecond * 100).isNone())

            exclusiveConsumer.close()

            producer.send(msg)

            @Assert(fallbackConsumer.receive(Duration.millisecond * 100).isSome())
        }
    }

    @TestCase
    public func testFallbackToExclusiveConsumer(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var exclusiveSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var fallbackSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var senderSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            var exclusiveQueue = ActiveMQQueue("test.exclusive.3?consumer.exclusive=true")
            var exclusiveConsumer = exclusiveSession.createConsumer(exclusiveQueue)

            var fallbackQueue = ActiveMQQueue("test.exclusive.3")
            var fallbackConsumer = fallbackSession.createConsumer(fallbackQueue)

            var senderQueue = ActiveMQQueue("test.exclusive.3")

            var producer = senderSession.createProducer(senderQueue)

            var msg = senderSession.createTextMessage("test")
            producer.send(msg)
            sleep(Duration.millisecond * 100)

            @Assert(exclusiveConsumer.receive(Duration.millisecond * 100).isSome())
            @Assert(fallbackConsumer.receive(Duration.millisecond * 100).isNone())

            exclusiveConsumer.close()

            producer.send(msg)

            @Assert(fallbackConsumer.receive(Duration.millisecond * 100).isSome())

            exclusiveConsumer = exclusiveSession.createConsumer(exclusiveQueue)

            producer.send(msg)
            @Assert(exclusiveConsumer.receive(Duration.millisecond * 100).isSome())
            @Assert(fallbackConsumer.receive(Duration.millisecond * 100).isNone())
        }
    }

    @TestCase
    public func testRedeliverNewSession(): Unit {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.setClientID("testRedeliverNewSession")
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var destination = session.createTopic("testDurableTopic")
            //第一次持久订阅需要在消息发送前，否则收不到之前的消息，区别于离线在上线还能收到历史消息
            var consumer = session.createDurableConsumer(destination, "DurableSub")
            var producer = session.createProducer(destination)
            var text = "TEST${DateTime.now()}"
            var sendMessage = session.createTextMessage(text)
            producer.send(sendMessage)

            //接收但不确认
            var unackMessage = consumer.receive(Duration.millisecond * 1000)
            @Assert(unackMessage.isSome())
            var unackId: ?String = None
            if (let Some(message) <- unackMessage) {
                unackId = message.getCJMSMessageID()
                if (let Some(textMsg) <- (message as TextMessage)) {
                    @Assert(textMsg.text, Some(text))
                }
                @Assert(message.getCJMSRedelivered(), false)
                @Assert(message.getInt32Property("JMSXDeliveryCount"), 1)
            }

            consumer.close()
            session.close()

            session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            consumer = session.createDurableConsumer(destination, "DurableSub")
            var ackMessage = consumer.receive(Duration.millisecond * 1000)
            @Assert(ackMessage.isSome())
            if (let Some(ackMessage) <- ackMessage) {
                ackMessage.acknowledge()
                var ackId = ackMessage.getCJMSMessageID()
                if (let Some(textMsg) <- (ackMessage as TextMessage)) {
                    @Assert(textMsg.text, Some(text))
                }
                @Assert(ackMessage.getCJMSRedelivered(), true)
                @Assert(ackMessage.getInt32Property("JMSXDeliveryCount"), 2)
                @Assert(unackId, ackId)
            }

            consumer.close()
            session.close()

            session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            consumer = session.createDurableConsumer(destination, "DurableSub")
            @Assert(consumer.receive(Duration.millisecond * 1000).isNone())
            //取消订阅
            consumer.close()
            connection.unsubscribe("DurableSub")
        }
    }

    @TestCase
    public func testSendWhileClosed(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.setClientID("testSendWhileClosed")
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var topic = session.createTopic("testDurableTopic.1")
            var producer = session.createProducer(topic)

            var consumerSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var consumer = session.createDurableConsumer(topic, "sendReceive")
            sleep(Duration.millisecond * 1000)
            consumer.close()

            var message: TextMessage = session.createTextMessage("test")
            message.setStringProperty("test", "test")
            message.setCJMSType("test")
            producer.send(message)

            consumer = session.createDurableConsumer(topic, "sendReceive")
            var msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())

            if (let Some(msg) <- msg) {
                @Assert(msg.getStringProperty("test"), "test")
                @Assert(msg.getCJMSType(), "test")
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, Some("test"))
                }
            }
        }
    }
}

class AnonymousMessageListener <: MessageListener {
    private let countdown: SyncCounter

    public init(countdown: SyncCounter) {
        this.countdown = countdown
    }

    public func onMessage(message: CJMSMessage) {
        countdown.dec()
    }
}

class AsynchronuslyMessageListener <: MessageListener {
    private let session: Session
    private let countdown: SyncCounter
    private let topic: Topic

    public init(session: Session, countdown: SyncCounter, topic: Topic) {
        this.session = session
        this.countdown = countdown
        this.topic = topic
    }

    public func onMessage(message: CJMSMessage) {
        session.createConsumer(topic)
        session.createProducer(topic)
        countdown.dec()
    }
}

class StoppedMessageListener <: MessageListener {
    private let counter: AtomicInt64
    private let done1: SyncCounter
    private let done2: SyncCounter

    public init(counter: AtomicInt64, done1: SyncCounter, done2: SyncCounter) {
        this.counter = counter
        this.done1 = done1
        this.done2 = done2
    }

    public func onMessage(message: CJMSMessage) {
        counter.fetchAdd(1)
        if (counter.load() == 1) {
            done1.dec()
        }
        if (counter.load() == 2) {
            done2.dec()
        }
    }
}

class StoppedConcurentlyMessageListener <: MessageListener {
    private let counter: AtomicInt64
    private let closeDone: SyncCounter
    private let consumer: MessageConsumer
    private let threadPool: ThreadPool

    public init(counter: AtomicInt64, closeDone: SyncCounter, consumer: MessageConsumer, threadPool: ThreadPool) {
        this.counter = counter
        this.closeDone = closeDone
        this.consumer = consumer
        this.threadPool = threadPool
    }

    public func onMessage(message: CJMSMessage) {
        threadPool.addTask(AckAndClose(counter, closeDone, consumer, message))
    }
}

class AckAndClose <: Runnable {
    private let counter: AtomicInt64
    private let closeDone: SyncCounter
    private let consumer: MessageConsumer
    private let message: CJMSMessage

    public init(counter: AtomicInt64, closeDone: SyncCounter, consumer: MessageConsumer, message: CJMSMessage) {
        this.counter = counter
        this.closeDone = closeDone
        this.consumer = consumer
        this.message = message
    }

    public func run(): Unit {
        var count = counter.fetchAdd(1)
        if (count == 590) {
            // close in a separate thread is ok by jms
            consumer.close()
            closeDone.dec()
        }
        if (count != 0 && count % 200 == 0) {
            // ensure there are some outstanding messages
            // ack every 200
            message.acknowledge()
        }
    }
}

class AfterMessageListener <: MessageListener {
    private let counter: AtomicInt64
    private let closeDone: SyncCounter

    public init(counter: AtomicInt64, closeDone: SyncCounter) {
        this.counter = counter
        this.closeDone = closeDone
    }

    public func onMessage(message: CJMSMessage) {
        counter.fetchAdd(1)
        if (counter.load() == 4) {
            closeDone.dec()
        }
    }
}

class UnackedMessageListener <: MessageListener {
    private let counter: AtomicInt64
    private let sendDone: SyncCounter
    private let got2Done: SyncCounter
    private let connection: Connection

    public init(counter: AtomicInt64, sendDone: SyncCounter, got2Done: SyncCounter, connection: Connection) {
        this.counter = counter
        this.sendDone = sendDone
        this.got2Done = got2Done
        this.connection = connection
    }

    public func onMessage(message: CJMSMessage): Unit {
        if (let Some(textMessage) <- (message as TextMessage)) {
            @Assert(Some(counter.load().toString()) == textMessage.text)
            counter.fetchAdd(1)
            if (counter.load() == 2) {
                sendDone.waitUntilZero()
                connection.close()
                got2Done.dec()
            }
            textMessage.acknowledge()
        }
    }
}

class UnackedMessageListener2 <: MessageListener {
    private let counter: AtomicInt64
    private let done: SyncCounter

    public init(counter: AtomicInt64, done: SyncCounter) {
        this.counter = counter
        this.done = done
    }

    public func onMessage(message: CJMSMessage): Unit {
        if (let Some(textMessage) <- (message as TextMessage)) {
            counter.fetchAdd(1)
            textMessage.acknowledge()
            if (counter.load() == 4) {
                done.dec()
            }
        }
    }
}

class ListenerMessageListener <: MessageListener {
    private let first: AtomicBool
    private let latch: SyncCounter
    private let consumer: MessageConsumer
    private let results: LinkedList<Any>

    public init(first: AtomicBool, latch: SyncCounter, consumer: MessageConsumer, results: LinkedList<Any>) {
        this.first = first
        this.latch = latch
        this.consumer = consumer
        this.results = results
    }

    public func onMessage(message: CJMSMessage) {
        if (first.compareAndSwap(true, false)) {
            try {
                consumer.messageListener = this
                results.addLast(message)
            } catch (e: CJMSException) {
                results.addLast(e)
            }
        } else {
            results.addLast(message)
        }
        latch.dec()
    }
}

class NewListenerMessageListener <: MessageListener {
    private let first: AtomicBool
    private let latch: SyncCounter
    private let session: Session
    private let results: LinkedList<Any>
    private let dest: Destination

    public init(first: AtomicBool, latch: SyncCounter, session: Session, results: LinkedList<Any>, dest: Destination) {
        this.first = first
        this.latch = latch
        this.session = session
        this.results = results
        this.dest = dest
    }

    public func onMessage(message: CJMSMessage) {
        if (first.compareAndSwap(true, false)) {
            try {
                var anotherConsumer = session.createConsumer(dest)
                anotherConsumer.messageListener = this
                results.addLast(message)
            } catch (e: CJMSException) {
                results.addLast(e)
            }
        } else {
            results.addLast(message)
        }
        latch.dec()
    }
}

class ClientAckMessageListener <: MessageListener {
    private let dontAck: Bool

    public init(dontAck: Bool) {
        this.dontAck = dontAck
    }

    public func onMessage(message: CJMSMessage): Unit {
        if (!dontAck) {
            message.acknowledge()
        }
    }
}

class AutoAckMessageListener <: MessageListener {
    public func onMessage(message: CJMSMessage): Unit {
    }
}
