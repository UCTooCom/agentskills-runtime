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
public class MessageDispatchNotificationTest {
    private var connection: ?ActiveMQConnection = None
    private var format: ?WireFormat = None

    private var messageId: ?MessageId = None

    private let destination = ActiveMQTopic("cangjie_test_topic")

    @BeforeAll
    protected func beforeAll(): Unit {
        connection = TestUtils.getConnection() as ActiveMQConnection
        format = TestUtils.getWireFormat()
    }

    @TestCase
    public func testMarshallAndUnmarshallIsTheSame() {
        //先发送一个message,并使用该message的MessageId,否则Broker在通过messageId找不到message的情况下会抛出异常
        let connection = connection.getOrThrow()
        let session = connection.createSession()
        let producer = session.createProducer(destination)
        let message = session.createTextMessage("text")
        producer.send(message)
        if (let Some(message) <- (message as ActiveMQTextMessage)) {
            this.messageId = message.messageId
        }
        let expected = createObject()
        if (let Some(command) <- (expected as Command)) {
            connection.syncSendPacket(command)
        }
        let format = format.getOrThrow()
        let dataOut: ByteBuffer = ByteBuffer.allocate(8192)
        format.marshal(expected, dataOut)
        let actual = format.unmarshal(dataOut)
        @Assert(actual == expected)
        @Assert((actual != expected) == false)
    }

    public func createObject(): MessageDispatchNotification {
        let messageDispatchNotification = MessageDispatchNotification()
        messageDispatchNotification.consumerId = createConsumerId()
        messageDispatchNotification.messageId = this.messageId
        messageDispatchNotification.destination = destination
        messageDispatchNotification.deliverySequenceId = 1
        return messageDispatchNotification
    }

    public func createConsumerId(): ?ConsumerId {
        let session = connection.getOrThrow().createSession()
        let consumer = session.createConsumer(destination)
        if (let Some(consumer) <- (consumer as ActiveMQMessageConsumer)) {
            return consumer.consumerId
        }
        return None
    }
}
