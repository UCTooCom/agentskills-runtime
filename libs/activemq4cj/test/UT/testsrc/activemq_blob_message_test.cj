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
public class ActiveMQBlobMessageTest {
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
        if (let Some(command) <- (expected as Command)) {
            connection.getOrThrow().syncSendPacket(command)
        }
        let format = format.getOrThrow()
        let dataOut: ByteBuffer = ByteBuffer.allocate(8192)
        format.marshal(expected, dataOut)
        let actual = format.unmarshal(dataOut)
        @Assert(actual == expected)
        @Assert((actual != expected) == false)
    }

    public func createObject(): ActiveMQBlobMessage {
        let blobMessage = ActiveMQBlobMessage()
        blobMessage.remoteBlobUrl = "remoteBlobUrl"
        blobMessage.mimeType = ActiveMQBlobMessage.BINARY_MIME_TYPE
        blobMessage.deletedByBroker = false
        blobMessage.replyTo = ActiveMQTempQueue("tempqueue:1")
        blobMessage.destination = destination
        blobMessage.producerId = createProducerId()
        blobMessage.messageId = createMessageId()
        blobMessage.expiration = 1
        blobMessage.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        blobMessage.correlationId = "correlationId:1"
        blobMessage.persistent = true
        blobMessage.redeliveryCounter = 1
        blobMessage.messageType = "type:1"
        blobMessage.priority = 10
        blobMessage.groupID = "groupID:1"
        blobMessage.userID = "userID:1"
        blobMessage.groupSequence = 1
        blobMessage.brokerInTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        blobMessage.brokerOutTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        blobMessage.jmsXGroupFirstForConsumer = true
        blobMessage.brokerPath = Array<BrokerId>(2, {index: Int64 => BrokerId("broker:1")})
        return blobMessage
    }

    public func createMessageId(): MessageId {
        let messageId = MessageId()
        let producerId = ProducerId()
        producerId.connectionId = "connection:1"
        producerId.sessionId = 1
        producerId.value = 1
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
