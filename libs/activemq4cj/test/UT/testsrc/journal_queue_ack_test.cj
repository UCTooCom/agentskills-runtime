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
public class JournalQueueAckTest {
    private var connection: ?ActiveMQConnection = None
    private var format: ?WireFormat = None

    private let destination = ActiveMQQueue("cangjie_test_queue")

    @BeforeAll
    protected func beforeAll(): Unit {
        connection = TestUtils.getConnection() as ActiveMQConnection
        format = TestUtils.getWireFormat()
    }

    @TestCase
    public func testMarshallAndUnmarshallIsTheSame() {
        let expected = createObject()
        if (let Some(baseCommand) <- (expected as BaseCommand)) {
            connection.getOrThrow().syncSendPacket(baseCommand)
        }
        let format = format.getOrThrow()
        let dataOut: ByteBuffer = ByteBuffer.allocate(8192)
        format.marshal(expected, dataOut)
        let actual = format.unmarshal(dataOut)
        @Assert(actual == expected)
        @Assert((actual != expected) == false)
    }

    public func createObject(): JournalQueueAck {
        let journalQueueAck = JournalQueueAck()
        journalQueueAck.destination = destination
        journalQueueAck.messageAck = createMessageAck()
        return journalQueueAck
    }

    public func createMessageAck(): MessageAck {
        return MessageAck(createMessageDispatch(), MessageAck.STANDARD_ACK_TYPE, 1)
    }

    public func createMessageDispatch(): MessageDispatch {
        let messageDispatch = MessageDispatch()
        let session = connection.getOrThrow().createSession()
        let consumer = session.createConsumer(destination)
        if (let Some(consumer) <- (consumer as ActiveMQMessageConsumer)) {
            messageDispatch.consumerId = consumer.consumerId
        }
        messageDispatch.destination = destination
        messageDispatch.message = createMessage()
        messageDispatch.redeliveryCounter = 1
        return messageDispatch
    }

    public func createMessage(): ActiveMQMessage {
        let message = ActiveMQMessage()
        message.content = "hello,cangjie".toArray()
        message.replyTo = ActiveMQTempQueue("tempqueue:1")
        message.destination = destination
        message.producerId = createProducerId()
        message.messageId = createMessageId()
        message.deliveryTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        message.expiration = 1
        message.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        message.correlationId = "correlationId:1"
        message.persistent = true
        message.redeliveryCounter = 1
        message.messageType = "type:1"
        message.priority = 10
        message.groupID = "groupID:1"
        message.userID = "userID:1"
        message.groupSequence = 1
        message.brokerInTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        message.brokerOutTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        message.jmsXGroupFirstForConsumer = true
        message.brokerPath = Array<BrokerId>(2, {index: Int64 => BrokerId("broker:1")})
        return message
    }

    public func createMessageId(): MessageId {
        let messageId = MessageId()
        let producerId = createProducerId()
        messageId.textView = "text:1"
        messageId.producerId = producerId
        messageId.producerSequenceId = 1
        messageId.brokerSequenceId = 1
        return messageId
    }

    public func createProducerId(): ?ProducerId {
        let session = connection.getOrThrow().createSession()
        if (let Some(producer) <- (session.createProducer(destination) as ActiveMQMessageProducer)) {
            return producer.producerId
        }
        return None
    }
}
