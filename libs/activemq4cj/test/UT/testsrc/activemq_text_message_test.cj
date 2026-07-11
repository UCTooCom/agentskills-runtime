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
public class ActiveMQTextMessageTest {
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

    public func createObject(): ActiveMQTextMessage {
        let textMessage = ActiveMQTextMessage()
        textMessage.text = "cangjie"
        textMessage.replyTo = ActiveMQTempQueue("tempqueue:1")
        textMessage.destination = destination
        textMessage.producerId = createProducerId()
        textMessage.messageId = createMessageId()
        textMessage.expiration = 1
        textMessage.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        textMessage.correlationId = "correlationId:1"
        textMessage.persistent = true
        textMessage.redeliveryCounter = 1
        textMessage.messageType = "type:1"
        textMessage.priority = 10
        textMessage.groupID = "groupID:1"
        textMessage.userID = "userID:1"
        textMessage.groupSequence = 1
        textMessage.brokerInTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        textMessage.brokerOutTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        textMessage.jmsXGroupFirstForConsumer = true
        textMessage.brokerPath = Array<BrokerId>(2, {index: Int64 => BrokerId("broker:1")})
        return textMessage
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

    @TestCase
    public func testGetDataStructureType() {
        var msg = ActiveMQTextMessage()
        @Assert(msg.getDataStructureType(), CommandTypes.ACTIVEMQ_TEXT_MESSAGE)
    }

    @TestCase
    public func testShallowCopy() {
        var msg = ActiveMQTextMessage()
        var string = "str"
        msg.text = string
        var copy = msg.copy()
        @Assert(msg.text == (copy as ActiveMQTextMessage).getOrThrow().text)
    }

    @TestCase
    public func testSetText() {
        var msg = ActiveMQTextMessage()
        var str = "testText"
        try {
            msg.text = str
            @Assert(msg.text, Some(str))
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testGetBytes() {
        var msg = ActiveMQTextMessage()
        var str = "testText"
        msg.text = str
        msg.beforeMarshall()

        var bytes = msg.content.getOrThrow()
        msg = ActiveMQTextMessage()
        msg.content = bytes

        @Assert(msg.text, Some(str))
    }

    @TestCase
    public func testClearBody() {
        var textMessage = ActiveMQTextMessage()
        textMessage.text = "String"
        textMessage.clearBody()
        @Assert(textMessage.readOnlyBody, false)
        @Assert(textMessage.text.isNone())
        try {
            textMessage.text = "String"
            var body = textMessage.text
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        } catch (mnre: MessageNotReadableException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadOnlyBody() {
        var textMessage = ActiveMQTextMessage()
        textMessage.text = "test"
        textMessage.readOnlyBody = true
        try {
            var text = textMessage.text
        } catch (e: MessageNotReadableException) {
            @Assert(false)
        }
        try {
            textMessage.text = "test"
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
    }

    @TestCase
    public func testWriteOnlyBody() {
        var textMessage = ActiveMQTextMessage()
        textMessage.readOnlyBody = false
        try {
            textMessage.text = "test"
            var text = textMessage.text
        } catch (e: MessageNotReadableException) {
            @Assert(false)
        }
        textMessage.readOnlyBody = true
        try {
            var text = textMessage.text
            textMessage.text = "test"
            @Assert(false)
        } catch (e: MessageNotReadableException) {
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
    }

    @TestCase
    public func testShortText() {
        var shortText = "Content"
        var shortMessage = ActiveMQTextMessage()
        setContent(shortMessage, shortText)

        @Assert(shortMessage.text == Some(shortText))

        var longText = "Very very very very veeeeeeery loooooooooooooooooooooooooooooooooong text"
        var longExpectedText = "Very very very very veeeeeeery looooooooooooo...ooooong text"
        var longMessage = ActiveMQTextMessage()
        setContent(longMessage, longText)

        @Assert(longMessage.text == Some(longText))
    }

    private func setContent(message: ActiveMQTextMessage, text: String): Unit {
        var byteBuffer = ByteBuffer.allocate(1024)
        MarshallingSupport.writeUTF8(text, byteBuffer)
        byteBuffer.flip()
        message.content = byteBuffer.toArray()
    }
}
