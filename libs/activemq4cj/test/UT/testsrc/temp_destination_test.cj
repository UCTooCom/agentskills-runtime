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
public class TempDestinationTest {
    @TestCase
    public func TestTempDestOnlyConsumedByLocalConn(): Unit {
        try (connection = TestUtils.createConnection(), otherConnection = TestUtils.createConnection()) {
            connection.start()
            var tempSession = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            var queue = tempSession.createTemporaryQueue()
            var producer = tempSession.createProducer(queue)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT
            var message = tempSession.createTextMessage("First")
            producer.send(message)

            var otherSession = otherConnection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var otherQueue = otherSession.createTemporaryQueue()
            var consumer = otherSession.createConsumer(otherQueue)
            var msg = consumer.receive(Duration.millisecond * 3000)
            @Assert(msg.isNone())

            try {
                consumer = otherSession.createConsumer(queue)
                @Assert(false)
            } catch (e: InvalidDestinationException) {
            }

            consumer = tempSession.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 3000)
            @Assert(msg.isSome())
        }
    }

    @TestCase
    public func TestTempQueueHoldsMessagesWithConsumers(): Unit {
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = session.createTemporaryQueue()
            var consumer = session.createConsumer(queue)
            connection.start()

            var producer = session.createProducer(queue)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT
            var message = session.createTextMessage("Hello")
            producer.send(message)

            var message2 = consumer.receive(Duration.millisecond * 1000)
            @Assert(message2.isSome())
            @Assert(message2.getOrThrow() is TextMessage)
            @Assert(message.text, (message2.getOrThrow() as TextMessage).getOrThrow().text)
        }
    }

    @TestCase
    public func testTempQueueHoldsMessagesWithoutConsumers(): Unit {
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = session.createTemporaryQueue()
            var producer = session.createProducer(queue)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT
            var message = session.createTextMessage("Hello")
            producer.send(message)

            connection.start()
            var consumer = session.createConsumer(queue)
            var message2 = consumer.receive(Duration.millisecond * 3000)
            @Assert(message2.isSome())
            @Assert(message2.getOrThrow() is TextMessage)
            @Assert(message.text, (message2.getOrThrow() as TextMessage).getOrThrow().text)
        }
    }

    @TestCase
    public func testTmpQueueWorksUnderLoad(): Unit {
        var count = 500
        var dataSize = 1024

        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = session.createTemporaryQueue()

            TestUtils.purgeQueue(connection, queue)

            var producer = session.createProducer(queue)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT

            var data = Array<Byte>(dataSize, repeat: 0)
            for (i in 0..count) {
                var message = session.createBytesMessage()
                message.writeBytes(data)
                message.setInt64Property("c", i)
                producer.send(message)
            }

            connection.start()
            var consumer = session.createConsumer(queue)
            for (i in 0..count) {
                var message2 = consumer.receive(Duration.millisecond * 2000)
                @Assert(message2.isSome())
                @Assert(i, message2.getOrThrow().getInt64Property("c"))
            }
        }
    }

    @TestCase
    public func testPublishFailsForClosedConnection(): Unit {
        try (connection = TestUtils.createConnection(), tempConnection = TestUtils.createConnection()) {
            var tempSession = tempConnection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = tempSession.createTemporaryQueue()

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            connection.start()
            tempConnection.start()

            var advisoryConsumer = session.createConsumer(
                ActiveMQTopic("ActiveMQ.Advisory.TempQueue,ActiveMQ.Advisory.TempTopic"))
            advisoryConsumer.messageListener = AdvisoryMessageListener()

            var producer = session.createProducer(queue)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT
            var message = session.createTextMessage("First")
            producer.send(message)
            sleep(Duration.millisecond * 1000)

            tempConnection.close()
            sleep(Duration.millisecond * 1000)

            try {
                message = session.createTextMessage("Hello")
                producer.send(message)
                @Assert(false)
            } catch (e: CJMSException) {
            }
        }
    }

    @TestCase
    public func testPublishFailsForDestroyedTempDestination(): Unit {
        try (connection = TestUtils.createConnection(), tempConnection = TestUtils.createConnection()) {
            var tempSession = tempConnection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = tempSession.createTemporaryQueue()

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            connection.start()

            var advisoryConsumer = session.createConsumer(AdvisorySupport.TEMP_DESTINATION_COMPOSITE_ADVISORY_TOPIC)
            advisoryConsumer.messageListener = AdvisoryMessageListener()

            var producer = session.createProducer(queue)
            producer.deliveryMode = DeliveryMode.NON_PERSISTENT
            var message = session.createTextMessage("First")
            producer.send(message)
            sleep(Duration.millisecond * 1000)

            queue.delete()
            sleep(Duration.millisecond * 1000)

            try {
                message = session.createTextMessage("Hello")
                producer.send(message)
                @Assert(false)
            } catch (e: CJMSException) {
            }
        }
    }

    @TestCase
    public func TestConsumeAfterPublishFailsForDestroyedTempDestination() {
        let msgQueueName: String = "Test.RequestReply.MsgQueue"
        try (consumerConnection = (TestUtils.createConnection() as ActiveMQConnection).getOrThrow()) {
            var consumerSession = consumerConnection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var consumerDestination = consumerSession.createQueue(msgQueueName)

            consumerConnection.start()
            TestUtils.purgeQueue(consumerConnection, consumerDestination)

            consumerConnection.deleteDestination(consumerDestination)
            var consumer = consumerSession.createConsumer(consumerDestination)

            var advisoryConsumer = consumerSession.createConsumer(
                AdvisorySupport.TEMP_DESTINATION_COMPOSITE_ADVISORY_TOPIC)

            for (i in 0..25) {
                var producerConnection = TestUtils.createConnection()
                var producerSession = producerConnection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
                var producerDestination = producerSession.createQueue(msgQueueName)
                var producer = producerSession.createProducer(producerDestination)
                var replyDestination = producerSession.createTemporaryQueue()

                producerConnection.start()

                var sendMsg = producerSession.createTextMessage("Consumer check.")
                sendMsg.setCJMSReplyTo(replyDestination)

                producer.send(sendMsg)

                var receiveMsg = consumer.receive(Duration.millisecond * 1000)
                var replyProducer = consumerSession.createProducer(
                    receiveMsg.getOrThrow().getCJMSReplyTo().getOrThrow())
                replyProducer.deliveryMode = DeliveryMode.NON_PERSISTENT

                producerConnection.close()

                sleep(Duration.millisecond * 1000)

                try {
                    var replyMsg = consumerSession.createTextMessage("Reply check.")
                    replyProducer.send(replyMsg)
                    @Assert(false)
                } catch (e: CJMSException) {
                }
            }
        }
    }

    @TestCase
    public func testDeleteDestinationWithSubscribersFails(): Unit {
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var queue = session.createTemporaryQueue()

            connection.start()

            session.createConsumer(queue)

            try {
                queue.delete()
                @Assert(false)
            } catch (e: CJMSException) {
            }
        }
    }

    @TestCase
    public func testCloseConnectionWithTempQueues(): Unit {
        var listTempQueues = LinkedList<TemporaryQueue>()
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            connection.start()

            for (i in 0..25) {
                listTempQueues.addLast(session.createTemporaryQueue())
            }
        }
    }
}

class AdvisoryMessageListener <: MessageListener {
    public func onMessage(message: CJMSMessage): Unit {
    }
}
