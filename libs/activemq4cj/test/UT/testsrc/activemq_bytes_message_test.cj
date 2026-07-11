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
public class ActiveMQBytesMessageTest {
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

    public func createObject(): ActiveMQBytesMessage {
        let bytesMessage = ActiveMQBytesMessage()
        bytesMessage.writeString("hello,cangjie")
        bytesMessage.writeFloat32(3.33)
        bytesMessage.writeInt32(666)
        bytesMessage.replyTo = ActiveMQTempQueue("tempqueue:1")
        bytesMessage.destination = destination
        bytesMessage.producerId = createProducerId()
        bytesMessage.messageId = createMessageId()
        bytesMessage.expiration = 1
        bytesMessage.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        bytesMessage.correlationId = "correlationId:1"
        bytesMessage.persistent = true
        bytesMessage.redeliveryCounter = 1
        bytesMessage.messageType = "type:1"
        bytesMessage.priority = 10
        bytesMessage.groupID = "groupID:1"
        bytesMessage.userID = "userID:1"
        bytesMessage.groupSequence = 1
        bytesMessage.brokerInTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        bytesMessage.brokerOutTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        bytesMessage.jmsXGroupFirstForConsumer = true
        bytesMessage.brokerPath = Array<BrokerId>(2, {index: Int64 => BrokerId("broker:1")})
        return bytesMessage
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
    public func testGetDataStructureType(): Unit {
        var msg = ActiveMQBytesMessage()
        @Assert(msg.getDataStructureType(), CommandTypes.ACTIVEMQ_BYTES_MESSAGE)
    }

    @TestCase
    public func testGetBodyLength(): Unit {
        let msg = ActiveMQBytesMessage()

        let len = 10
        for (i in 0..len) {
            msg.writeInt64(5)
        }

        msg.reset()
        @Assert(msg.getBodyLength(), len * 8)
    }

    @TestCase
    public func testReadBoolean(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeBool(true)
        msg.reset()
        @Assert(msg.readBool(), true)
    }

    @TestCase
    public func testReadByte(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeByte(UInt8(2))
        msg.reset()
        @Assert(msg.readByte(), 2)
    }

    @TestCase
    public func testReadInt8(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeInt8(Int8(-2))
        msg.reset()
        @Assert(msg.readInt8(), -2)
    }

    @TestCase
    public func testReadInt16(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeInt16(Int16(-3000))
        msg.reset()
        @Assert(msg.readInt16(), -3000)
    }

    @TestCase
    public func testReadUInt16(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeUInt16(UInt16(3000))
        msg.reset()
        @Assert(msg.readInt16(), 3000)
    }

    @TestCase
    public func testReadChar(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeChar(r'A')
        msg.reset()
        @Assert(msg.readChar(), r'A')
    }

    @TestCase
    public func testReadInt32(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeInt32(-32000)
        msg.reset()
        @Assert(msg.readInt32(), -32000)
    }

    @TestCase
    public func testReadUInt32(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeUInt32(32000)
        msg.reset()
        @Assert(msg.readUInt32(), 32000)
    }

    @TestCase
    public func testReadInt64(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeInt64(-64000)
        msg.reset()
        @Assert(msg.readInt64(), -64000)
    }

    @TestCase
    public func testReadUInt64(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeUInt64(64000)
        msg.reset()
        @Assert(msg.readUInt64(), 64000)
    }

    @TestCase
    public func testReadFloat32(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeFloat32(3.3)
        msg.reset()
        @Assert(msg.readFloat32(), 3.3)
    }

    @TestCase
    public func testReadFloat64(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeFloat64(6.3)
        msg.reset()
        @Assert(msg.readFloat64(), 6.3)
    }

    @TestCase
    public func testReadString(): Unit {
        let msg = ActiveMQBytesMessage()

        msg.writeString("this is a test")
        msg.reset()
        @Assert(msg.readString(), "this is a test")
    }

    @TestCase
    public func testReadBytes(): Unit {
        let msg = ActiveMQBytesMessage()

        let array = Array<Byte>(50, {index: Int64 => UInt8(index)})
        msg.writeBytes(array)
        msg.reset()

        var test = Array<Byte>(array.size, repeat: 0)
        msg.readBytes(test)
        @Assert(test, array)
    }

    @TestCase
    public func testClearBody(): Unit {
        let msg = ActiveMQBytesMessage()
        try {
            msg.writeInt32(1)
            msg.clearBody()
            @Assert(msg.readOnlyBody, false)
            msg.writeInt32(1)
            msg.readInt32()
        } catch (mnwe: MessageNotReadableException) {
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testClearProperties(): Unit {
        var bytesMessage = ActiveMQBytesMessage()
        bytesMessage.setInt32Property("one", 1)

        bytesMessage.onSend()

        @Assert(1, bytesMessage.getInt32Property("one"))
        @Assert(bytesMessage.readOnlyProperties)

        try {
            bytesMessage.setInt32Property("two", 2)
            @Assert(false)
        } catch (expected: MessageNotWriteableException) {
            @Assert(true)
        }

        bytesMessage.clearProperties()
        @Assert(bytesMessage.propertyExists("one"),false)
        @Assert(bytesMessage.readOnlyProperties,false)

        bytesMessage.setInt32Property("two", 2)
        @Assert(2, bytesMessage.getInt32Property("two"))
    }

    @TestCase
    public func testReset(): Unit {
        var message: ActiveMQBytesMessage = ActiveMQBytesMessage()
        try {
            message.writeFloat64(24.5)
            message.writeInt64(311)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }
        message.reset()
        try {
            @Assert(message.readOnlyBody)
            @Assert(message.readFloat64(), 24.5)
            @Assert(message.readInt64(), 311)
        } catch (mnre: MessageNotReadableException) {
            @Assert(false)
        }
        try {
            message.writeInt32(33)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }
    }

    @TestCase
    public func testReadOnlyBody(): Unit {
        var message: ActiveMQBytesMessage = ActiveMQBytesMessage()
        try {
            message.writeBool(true)
            message.writeByte(UInt8(1))
            message.writeByte(UInt8(1))
            message.writeBytes(Array<Byte>(1, repeat: 0))
            message.writeBytes(Array<Byte>(2, repeat: 0))
            message.writeChar(r'a')
            message.writeFloat64(1.5)
            message.writeFloat32(Float32(1.5))
            message.writeInt32(1)
            message.writeInt64(1)
            message.writeString("string")
            message.writeInt16(Int16(1))
            message.writeInt16(Int16(1))
            message.writeUTF("utfstring")
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }

        message.reset()

        try {
            message.readBool()
            message.readByte()
            message.readByte()
            message.readBytes(Array<Byte>(1, repeat: 0))
            message.readBytes(Array<Byte>(2, repeat: 0))
            message.readChar()
            message.readFloat64()
            message.readFloat32()
            message.readInt32()
            message.readInt64()
            message.readString()
            message.readInt16()
            message.readUInt16()
            message.readUTF()
        } catch (mnwe: MessageNotReadableException) {
            @Assert(false)
        }

        try {
            message.writeBool(true)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeByte(UInt8(1))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeBytes(Array<Byte>(1, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeBytes(Array<Byte>(2, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeChar(r'a')
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeFloat64(1.5)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeFloat32(Float32(1.5))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeInt32(1)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeInt64(1)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeInt16(Int16(1))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }

        try {
            message.writeUTF("utfstring")
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(true)
        }
    }

    @TestCase
    public func testWriteOnlyBody(): Unit {
        var message: ActiveMQBytesMessage = ActiveMQBytesMessage()
        message.clearBody()
        try {
            message.writeBool(true)
            message.writeByte(UInt8(1))
            message.writeByte(UInt8(1))
            message.writeBytes(Array<Byte>(1, repeat: 0))
            message.writeBytes(Array<Byte>(2, repeat: 0))
            message.writeChar(r'a')
            message.writeFloat64(1.5)
            message.writeFloat32(Float32(1.5))
            message.writeInt32(1)
            message.writeInt64(1)
            message.writeString("stringobj")
            message.writeInt16(Int16(1))
            message.writeInt16(Int16(1))
            message.writeUTF("utfstring")
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }
        try {
            message.readBool()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }

        try {
            message.readByte()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readInt8()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readBytes(Array<Byte>(1, repeat: 0))
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readBytes(Array<Byte>(2, repeat: 0))
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readChar()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readFloat64()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readFloat32()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readInt32()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readInt64()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readUTF()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readInt16()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readUInt16()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }

        try {
            message.readUTF()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
        }
    }
}
