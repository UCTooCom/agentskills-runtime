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
public class RedeliveryPolicyTest {
    @TestCase
    public func testGetNextWithExponentialBackoff(): Unit {
        let policy = RedeliveryPolicy()
        policy.initialRedeliveryDelay = 0
        policy.redeliveryDelay = 500
        policy.backOffMultiplier = Float64(2)
        policy.useExponentialBackOff = true

        var delay = policy.getNextRedeliveryDelay(0)
        @Assert(500, delay)
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(500*2, delay)
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(500*4, delay)

        policy.useExponentialBackOff = false
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(500, delay)
    }

    @TestCase
    public func testGetNextWithExponentialBackoff_RedeliveryDelayIsIgnoredIfInitialRedeliveryDelayAboveZero(): Unit {
        let policy = RedeliveryPolicy()
        policy.initialRedeliveryDelay = 42
        policy.redeliveryDelay = -100 // This is ignored in actual usage since initial > 0
        policy.backOffMultiplier = Float64(2)
        policy.useExponentialBackOff = true

        // Invoke in the order employed when actually used by redelivery code paths
        var delay = policy.initialRedeliveryDelay
        @Assert(42, delay)
        // Notice how the setRedeliveryDelay(-100) doesn't affect the calculation if initial > 0
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(42*2, delay)
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(42*4, delay)

        // If the initial delay is 0, when given back to the policy via getNextRedeliveryDelay(), we get -100
        @Assert(-100, policy.getNextRedeliveryDelay(0))
        // .. but when invoked with anything else, the backoff multiplier is used
        @Assert(123 * 2, policy.getNextRedeliveryDelay(123))

        // If exponential backoff is disabled, the setRedeliveryDelay(-100) is used.
        policy.useExponentialBackOff = false
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(-100, delay)
    }

    @TestCase
    public func testGetNextWithInitialDelay(): Unit {
        let policy = RedeliveryPolicy()
        policy.initialRedeliveryDelay = 500

        var delay = policy.getNextRedeliveryDelay(500)
        @Assert(1000, delay)
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(1000, delay)
        delay = policy.getNextRedeliveryDelay(delay)
        @Assert(1000, delay)
    }

    @TestCase
    public func testExponentialRedeliveryPolicyDelaysDeliveryOnRollback(): Unit {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 0
            policy.redeliveryDelay = 500
            policy.backOffMultiplier = Float64(2)
            policy.useExponentialBackOff = true

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testExponentialRedeliveryPolicyDelaysDeliveryOnRollback")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)
            while (consumer.receive(Duration.millisecond * 1000).isSome()) {
            }
            session.commit()

            // Send the messages
            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            session.rollback()

            var msg: ?CJMSMessage = consumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())

            m = consumer.receive(Duration.millisecond * 700).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            msg = consumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())
            msg = consumer.receive(Duration.millisecond * 500)
            @Assert(msg.isNone())
            m = consumer.receive(Duration.millisecond * 700).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
        }
    }

    @TestCase
    public func testExponentialRedeliveryPolicyCombinedWithNonBlockingRedelivery() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 0
            policy.redeliveryDelay = 100
            policy.backOffMultiplier = Float64(2)
            policy.useExponentialBackOff = true
            policy.maximumRedeliveries = 4

            var delay = policy.initialRedeliveryDelay
            @Assert(0, delay)
            delay = policy.getNextRedeliveryDelay(delay)
            @Assert(100, delay)
            delay = policy.getNextRedeliveryDelay(delay)
            @Assert(200, delay)
            delay = policy.getNextRedeliveryDelay(delay)
            @Assert(400, delay)

            connection.nonBlockingRedelivery = true

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testExponentialRedeliveryPolicyCombinedWithNonBlockingRedelivery")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)

            var count = 10
            for (i in 0..count) {
                producer.send(session.createTextMessage("#${i}"))
            }
            session.commit()

            var receiveCount = 0

            for (i in 0..(count * 5 + 1)) {
                var m = consumer.receive(Duration.millisecond * 1600)

                if (let Some(m) <- m) {
                    if (m is TextMessage) {
                        receiveCount++
                    }
                }
                session.rollback()
            }

            @Assert(count * 5, receiveCount)
        }
    }

    @TestCase
    public func testNormalRedeliveryPolicyDelaysDeliveryOnRollback() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 0
            policy.redeliveryDelay = 500

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testNormalRedeliveryPolicyDelaysDeliveryOnRollback")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)
            while (consumer.receive(Duration.millisecond * 1000).isSome()) {
            }
            session.commit()

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())

            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            session.rollback()

            var msg = consumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())

            m = consumer.receive(Duration.millisecond * 700).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            msg = consumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())
            m = consumer.receive(Duration.millisecond * 700).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert("1st", m.getOrThrow().text)
        }
    }

    @TestCase
    public func testDLQHandling(): Unit {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 100
            policy.useExponentialBackOff = false
            policy.maximumRedeliveries = 2

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE);
            var destination = ActiveMQQueue("test.DLQHandling")
            var dlq = ActiveMQQueue("DLQ.test.DLQHandling")
            TestUtils.purgeQueue(connection, dlq)

            var producer = session.createProducer(destination)
            var consumer = session.createConsumer(destination)
            var dlqConsumer = session.createConsumer(ActiveMQQueue("DLQ.test.DLQHandling"))

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()

            m = dlqConsumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            var cause = m.getOrThrow().getStringProperty(ActiveMQMessage.DLQ_DELIVERY_FAILURE_CAUSE_PROPERTY)
            @Assert(cause.contains("redelivery policy"))
            @Assert(cause.contains("[3]"))

            session.commit()
        }
    }

    @TestCase
    public func testInfiniteMaximumNumberOfRedeliveries() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 100
            policy.useExponentialBackOff = false
            policy.maximumRedeliveries = -1

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testInfiniteMaximumNumberOfRedeliveries")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.commit()

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()
        }
    }

    @TestCase
    public func testMaximumRedeliveryDelay(): Unit {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 10
            policy.useExponentialBackOff = true
            policy.maximumRedeliveries = -1
            policy.redeliveryDelay = 50
            policy.maximumRedeliveryDelay = 1000
            policy.backOffMultiplier = Float64(2)
            policy.useExponentialBackOff = true

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testMaximumRedeliveryDelay")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = None

            for (i in 0..10) {
                m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
                @Assert(m.isSome())
                @Assert(Some("1st"), m.getOrThrow().text)
                session.rollback()
            }

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.commit()

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()

            @Assert(policy.getNextRedeliveryDelay(Int64(Int32.Max)) == 1000)
        }
    }

    @TestCase
    public func testZeroMaximumNumberOfRedeliveries(): Unit {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 100
            policy.useExponentialBackOff = false
            policy.maximumRedeliveries = 0

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testZeroMaximumNumberOfRedeliveries")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()
        }
    }

    @TestCase
    public func testRepeatedRedeliveryReceiveNoCommit(): Unit {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.start()
            var dlqSession = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var destination = ActiveMQQueue("test.RepeatedRedeliveryReceiveNoCommit")
            var producer = dlqSession.createProducer(destination)

            producer.send(dlqSession.createTextMessage("1st"))

            dlqSession.commit()
            var dlqConsumer = dlqSession.createConsumer(ActiveMQQueue("DLQ.test.RepeatedRedeliveryReceiveNoCommit"))

            let maxRedeliveries = 4
            for (i in 0..maxRedeliveries + 1) {
                try (queueConnection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
                    var policy = queueConnection.getRedeliveryPolicy().getOrThrow()
                    policy.initialRedeliveryDelay = 0
                    policy.useExponentialBackOff = false
                    policy.maximumRedeliveries = Int32(maxRedeliveries)

                    queueConnection.start()
                    var session = queueConnection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
                    var consumer = session.createConsumer(destination)

                    var m = consumer.receive(Duration.millisecond * 4000)
                    if (i <= maxRedeliveries) {
                        var msg = m.getOrThrow() as ActiveMQTextMessage
                        @Assert(Some("1st"), msg.getOrThrow().text)
                        @Assert(i, Int64(msg.getOrThrow().redeliveryCounter))
                    } else {
                        @Assert(m.isNone())
                    }
                }
            }

            var m = dlqConsumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            var cause = m.getOrThrow().getStringProperty(ActiveMQMessage.DLQ_DELIVERY_FAILURE_CAUSE_PROPERTY)
            @Assert(cause.contains("redelivery policy"))
            @Assert(cause.contains("Delivery[5]"))

            dlqSession.commit()
        }
    }

    @TestCase
    public func testRepeatedRedeliveryOnMessageNoCommit() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            connection.start()

            var dlqSession = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)
            var destination = ActiveMQQueue("test.RepeatedRedeliveryOnMessageNoCommit")
            var producer = dlqSession.createProducer(destination)

            producer.send(dlqSession.createTextMessage("1st"))

            dlqSession.commit()
            var dlqConsumer = dlqSession.createConsumer(ActiveMQQueue("DLQ.test.RepeatedRedeliveryOnMessageNoCommit"))

            var maxRedeliveries = 4
            let receivedCount: AtomicInt64 = AtomicInt64(0)

            for (i in 0..maxRedeliveries + 2) {
                try (queueConnection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
                    var policy = queueConnection.getRedeliveryPolicy().getOrThrow()
                    policy.initialRedeliveryDelay = 0
                    policy.useExponentialBackOff = false
                    policy.maximumRedeliveries = Int32(maxRedeliveries)

                    queueConnection.start()
                    let session = queueConnection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED);
                    var consumer = session.createConsumer(destination)
                    let done = SyncCounter(1)

                    consumer.messageListener = NoCommitMessageListener(receivedCount, done)

                    if (i <= maxRedeliveries) {
                        done.waitUntilZero(timeout: Duration.second * 5)
                        @Assert(done.count == 0)
                    } else {
                        done.waitUntilZero(timeout: Duration.second * 1)
                        @Assert(done.count > 0)
                    }
                }
            }

            var m: ?TextMessage = dlqConsumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            var cause = m.getOrThrow().getStringProperty(ActiveMQMessage.DLQ_DELIVERY_FAILURE_CAUSE_PROPERTY)
            @Assert(cause.contains("redelivery policy"))
            @Assert(cause.contains("[5]"))

            dlqSession.commit()
        }
    }

    @TestCase
    public func testInitialRedeliveryDelayZero() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 0
            policy.useExponentialBackOff = false
            policy.maximumRedeliveries = 1

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testInitialRedeliveryDelayZero")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)

            m = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()
        }
    }

    @TestCase
    public func testInitialRedeliveryDelayOne() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 1000
            policy.useExponentialBackOff = false
            policy.maximumRedeliveries = 1

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testInitialRedeliveryDelayOne")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            var msg: ?CJMSMessage = consumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)

            m = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()
        }
    }

    @TestCase
    public func testRedeliveryDelayOne() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var policy = connection.getRedeliveryPolicy().getOrThrow()
            policy.initialRedeliveryDelay = 0
            policy.redeliveryDelay = 1000
            policy.useExponentialBackOff = false
            policy.maximumRedeliveries = 2

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("TEST.REDELIVERYDELAYONE")
            var producer = session.createProducer(destination)

            var consumer = session.createConsumer(destination)

            producer.send(session.createTextMessage("1st"))
            producer.send(session.createTextMessage("2nd"))
            session.commit()

            var m: ?TextMessage = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            session.rollback()

            m = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            session.rollback()

            var msg: ?CJMSMessage = consumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())

            m = consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)

            m = consumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()
        }
    }

    @TestCase
    public func testRedeliveryPolicyPerDestination() {
        try (connection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var queuePolicy = RedeliveryPolicy()
            queuePolicy.initialRedeliveryDelay = 0
            queuePolicy.redeliveryDelay = 1000
            queuePolicy.useExponentialBackOff = false
            queuePolicy.maximumRedeliveries = 2

            var topicPolicy = RedeliveryPolicy()
            topicPolicy.initialRedeliveryDelay = 0
            topicPolicy.redeliveryDelay = 1000
            topicPolicy.useExponentialBackOff = false
            topicPolicy.maximumRedeliveries = 3

            var map = connection.redeliveryPolicyMap.getOrThrow()
            map.put(ActiveMQTopic(">"), DestinationMapEntry<RedeliveryPolicy>(topicPolicy))
            map.put(ActiveMQQueue(">"), DestinationMapEntry<RedeliveryPolicy>(queuePolicy))

            connection.start()
            var session = connection.createSession(true, AcknowledgeMode.AUTO_ACKNOWLEDGE);
            var queue = ActiveMQQueue("TEST.PREDESTINATION")
            var topic = ActiveMQTopic("TEST.PREDESTINATION")

            var queueProducer = session.createProducer(queue)
            var topicProducer = session.createProducer(topic)

            var queueConsumer = session.createConsumer(queue)
            var topicConsumer = session.createConsumer(topic)

            queueProducer.send(queue, session.createTextMessage("1st"))
            queueProducer.send(queue, session.createTextMessage("2nd"))
            topicProducer.send(topic, session.createTextMessage("1st"))
            topicProducer.send(topic, session.createTextMessage("2nd"))

            session.commit()

            var m: ?TextMessage = queueConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            m = topicConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)

            m = queueConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            m = topicConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.rollback()

            m = queueConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            m = topicConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            session.rollback()

            var msg: ?CJMSMessage = queueConsumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())
            msg = topicConsumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())

            m = queueConsumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            m = topicConsumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)

            m = queueConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            m = topicConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.rollback()

            m = queueConsumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)
            m = topicConsumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)

            m = queueConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            m = topicConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.rollback()

            msg = queueConsumer.receive(Duration.millisecond * 2000)
            @Assert(msg.isNone())
            m = topicConsumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("1st"), m.getOrThrow().text)

            msg = queueConsumer.receive(Duration.millisecond * 100)
            @Assert(msg.isNone())
            m = topicConsumer.receive(Duration.millisecond * 100).getOrThrow() as TextMessage
            @Assert(m.isSome())
            @Assert(Some("2nd"), m.getOrThrow().text)
            session.commit()
        }
    }
}

class NoCommitMessageListener <: MessageListener {
    private let counter: AtomicInt64
    private let done: SyncCounter

    public init(counter: AtomicInt64, done: SyncCounter) {
        this.counter = counter
        this.done = done
    }

    public func onMessage(message: CJMSMessage): Unit {
        try {
            var m = message as ActiveMQTextMessage
            @Assert(Some("1st"), m.getOrThrow().text)
            @Assert(counter.load(), Int64(m.getOrThrow().redeliveryCounter))
            counter.fetchAdd(1)
            done.dec()
        } catch (ignored: Exception) {
            ignored.printStackTrace()
        }
    }
}
