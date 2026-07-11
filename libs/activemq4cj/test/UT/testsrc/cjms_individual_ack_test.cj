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
public class CJMSIndividualAckTest {
    @TestCase
    public func testAckedMessageAreConsumed(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.INDIVIDUAL_ACKNOWLEDGE)

            var queue = session.createQueue("test.ack.individual.0")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("Hello"))

            // 消费消息
            var consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                msg.acknowledge()
            }

            // 重置session
            session.close()
            session = connection.createSession(false, AcknowledgeMode.INDIVIDUAL_ACKNOWLEDGE)

            // 再次消费消息
            consumer = session.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isNone())

            session.close()
        }
    }

    @TestCase
    public func testLastMessageAcked(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.INDIVIDUAL_ACKNOWLEDGE)

            var queue = session.createQueue("test.ack.individual.1")

            // 清空之前测试残留的消息
            var consumer = session.createConsumer(queue)
            while (consumer.receive(Duration.millisecond * 1000).isSome()) {
            }
            session.acknowledge()

            var producer = session.createProducer(queue)

            var msg1 = session.createTextMessage("msg1")
            var msg2 = session.createTextMessage("msg2")
            var msg3 = session.createTextMessage("msg3")
            producer.send(msg1)
            producer.send(msg2)
            producer.send(msg3)

            var msg = consumer.receive(Duration.millisecond * 1000)
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
            session = connection.createSession(false, AcknowledgeMode.INDIVIDUAL_ACKNOWLEDGE)

            // 尝试再次消费消息
            consumer = session.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(msg1.text, textMsg.text)
                } else {
                    @Assert(false)
                }
            }

            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(msg2.text, textMsg.text)
                } else {
                    @Assert(false)
                }
            }
            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isNone())
            session.close()
        }
    }

    @TestCase
    public func testUnAckedMessageAreNotConsumedOnSessionClose(): Unit {
        try (connection = TestUtils.createConnection()) {
            connection.start()

            var session = connection.createSession(false, AcknowledgeMode.INDIVIDUAL_ACKNOWLEDGE)
            var queue = session.createQueue("test.ack.individual.2")
            var producer = session.createProducer(queue)
            producer.send(session.createTextMessage("hello"))

            var consumer = session.createConsumer(queue)
            var msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            //不确认消息

            session.close()
            session = connection.createSession(false, AcknowledgeMode.INDIVIDUAL_ACKNOWLEDGE)

            consumer = session.createConsumer(queue)
            msg = consumer.receive(Duration.millisecond * 1000)
            @Assert(msg.isSome())
            if (let Some(msg) <- msg) {
                msg.acknowledge()
            }
        }
    }
}
