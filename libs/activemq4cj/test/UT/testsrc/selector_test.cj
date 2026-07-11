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
public class SelectorTest {
    private var connection: ?ActiveMQConnection = None

    @BeforeAll
    protected func beforeAll(): Unit {
        connection = TestUtils.createConnection() as ActiveMQConnection
    }

    @TestCase
    public func testJMSPropertySelectors(): Unit {
        try (session = connection.getOrThrow().createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)) {
            let queue = session.createQueue("testJMSPropertySelectors")

            var message: CJMSMessage = ActiveMQMessage()
            message.setCJMSType("selector-test");
            message.setCJMSMessageID("id:test:1:1:1:1")

            try (producer = session.createProducer(queue)) {
                var message: CJMSMessage = ActiveMQMessage()
                message.setCJMSType("selector-test");
                message.setCJMSMessageID("id:test:1:1:1:1")
                producer.send(message)

                try (consumer = session.createConsumer(queue, "JMSType = 'selector-test'")) {
                    var message = consumer.receive(Duration.second)
                    if (let Some(msg) <- message) {
                        @Assert(msg.getCJMSType(), "selector-test")
                    }
                }

                message = ActiveMQMessage()
                message.setCJMSMessageID("id:test:1:1:1:1")
                producer.send(message)

                try (consumer = session.createConsumer(queue, "JMSMessageID = 'id:not-test:1:1:1:1'")) {
                    var message = consumer.receive(Duration.second)
                    @Assert(message.isNone())
                }

                try (consumer = session.createConsumer(queue, "JMSMessageID = 'id:test:1:1:1:1'")) {
                    var message = consumer.receive(Duration.second)
                    if (let Some(msg) <- message) {
                        @Assert(msg.getCJMSMessageID(), "id:test:1:1:1:1")
                    }
                }
            }
        }
    }

    @TestCase
    public func testDurableConsumerSelectorChange(): Unit {
        //测试MessageSelector
        try (connection = TestUtils.createConnection()) {
            connection.setClientID("test")
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE);
            var destination = session.createTopic("testDurableConsumerSelectorChange")
            var producer = session.createProducer(destination)
            producer.deliveryMode = DeliveryMode.PERSISTENT
            var consumer = session.createDurableConsumer(destination, "test", "color='red'", false)

            // Send the messages
            var message = session.createTextMessage("1st")
            message.setStringProperty("color", "red")
            producer.send(message)

            var m: ?CJMSMessage = consumer.receive(Duration.millisecond * 1000)
            @Assert(m.isSome())
            if (let Some(message) <- m) {
                if (let Some(textMessage) <- (message as TextMessage)) {
                    @Assert("1st", textMessage.text)
                }
            }
            // Change the subscription.
            consumer.close()
            consumer = session.createDurableConsumer(destination, "test", "color='blue'", false)

            message = session.createTextMessage("2nd")
            message.setStringProperty("color", "red")
            producer.send(message)
            message = session.createTextMessage("3rd")
            message.setStringProperty("color", "blue")
            producer.send(message)

            // Selector should skip the 2nd message.
            m = consumer.receive(Duration.millisecond * 1000)
            @Assert(m.isSome())
            if (let Some(message) <- m) {
                if (let Some(textMessage) <- (message as TextMessage)) {
                    @Assert("3rd", textMessage.text)
                }
            }
            @Assert(consumer.receiveNoWait().isNone())
        }
    }

    @AfterAll
    public func afterAll() {
        if (let Some(connection) <- connection) {
            connection.close()
        }
    }
}
