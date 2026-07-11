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
public class ActiveMQStreamMessageTest {
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

    public func createObject(): ActiveMQStreamMessage {
        let streamMessage = ActiveMQStreamMessage()
        streamMessage.writeString("hello,cangjie")
        streamMessage.writeFloat32(3.33)
        streamMessage.writeInt32(666)
        streamMessage.replyTo = ActiveMQTempQueue("tempqueue:1")
        streamMessage.destination = destination
        streamMessage.producerId = createProducerId()
        streamMessage.messageId = createMessageId()
        streamMessage.deliveryTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        streamMessage.expiration = 1
        streamMessage.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        streamMessage.correlationId = "correlationId:1"
        streamMessage.persistent = true
        streamMessage.redeliveryCounter = 1
        streamMessage.messageType = "type:1"
        streamMessage.priority = 10
        streamMessage.groupID = "groupID:1"
        streamMessage.userID = "userID:1"
        streamMessage.groupSequence = 1
        streamMessage.brokerInTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        streamMessage.brokerOutTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        streamMessage.jmsXGroupFirstForConsumer = true
        streamMessage.brokerPath = Array<BrokerId>(2, {index: Int64 => BrokerId("broker:1")})
        return streamMessage
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
        var msg = ActiveMQStreamMessage()
        @Assert(msg.getDataStructureType(), CommandTypes.ACTIVEMQ_STREAM_MESSAGE)
    }

    @TestCase
    public func testReadBool() {
        var msg = ActiveMQStreamMessage()
        try {
            msg.writeBool(true)
            msg.reset()
            @Assert(msg.readBool())
            msg.reset()
            @Assert(msg.readString() == "true")
            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadByte() {
        var msg = ActiveMQStreamMessage()
        try {
            var test = UInt8(4)
            msg.writeByte(test)
            msg.reset()
            @Assert(msg.readByte() == 4)
            msg.reset()
            @Assert(msg.readInt8() == 4)
            msg.reset()
            @Assert(msg.readInt16() == 4)
            msg.reset()
            @Assert(msg.readUInt16() == 4)
            msg.reset()
            @Assert(msg.readInt32() == 4)
            msg.reset()
            @Assert(msg.readUInt32() == 4)
            msg.reset()
            @Assert(msg.readInt64() == 4)
            msg.reset()
            @Assert(msg.readUInt64() == 4)
            msg.reset()
            @Assert(msg.readString() == test.toString())
            msg.reset()
            try {
                msg.readBool()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadInt8() {
        var msg = ActiveMQStreamMessage()

        var test = Int8(4)
        msg.writeInt8(test)
        msg.reset()

        @Assert(msg.readByte() == 4)
        msg.reset()
        @Assert(msg.readInt8() == 4)
        msg.reset()
        @Assert(msg.readInt16() == 4)
        msg.reset()
        @Assert(msg.readUInt16() == 4)
        msg.reset()
        @Assert(msg.readInt32() == 4)
        msg.reset()
        @Assert(msg.readUInt32() == 4)
        msg.reset()
        @Assert(msg.readInt64() == 4)
        msg.reset()
        @Assert(msg.readUInt64() == 4)
        msg.reset()
        @Assert(msg.readString() == test.toString())
    }

    @TestCase
    public func testReadInt16() {
        var msg = ActiveMQStreamMessage()
        try {
            var test = Int16(4)
            msg.writeInt16(test)
            msg.reset()
            @Assert(msg.readInt16() == 4)
            msg.reset()
            @Assert(msg.readUInt16() == 4)
            msg.reset()
            @Assert(msg.readInt32() == 4)
            msg.reset()
            @Assert(msg.readUInt32() == 4)
            msg.reset()
            @Assert(msg.readInt64() == 4)
            msg.reset()
            @Assert(msg.readUInt64() == 4)
            msg.reset()
            @Assert(msg.readString() == test.toString())
            msg.reset()
            try {
                msg.readBool()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadUInt16() {
        var msg = ActiveMQStreamMessage()
        var test = UInt16(4)
        msg.writeUInt16(test)
        msg.reset()
        @Assert(msg.readUInt16() == UInt16(4))
        msg.reset()
        @Assert(msg.readInt16() == 4)
        msg.reset()
        @Assert(msg.readInt32() == 4)
        msg.reset()
        @Assert(msg.readUInt32() == 4)
        msg.reset()
        @Assert(msg.readInt64() == 4)
        msg.reset()
        @Assert(msg.readUInt64() == 4)
        msg.reset()
        @Assert(msg.readString() == test.toString())
    }

    @TestCase
    public func testReadChar() {
        var msg = ActiveMQStreamMessage()
        try {
            var test = r'z'
            msg.writeChar(test)
            msg.reset()
            @Assert(msg.readChar() == test)
            msg.reset()
            @Assert(msg.readString() == test.toString())
            msg.reset()
            try {
                msg.readBool()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (cjmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadInt32() {
        var msg = ActiveMQStreamMessage()
        try {
            var test = Int32(4)
            msg.writeInt32(test)
            msg.reset()
            @Assert(msg.readInt32() == test)
            msg.reset()
            @Assert(msg.readUInt32() == UInt32(4))
            msg.reset()
            @Assert(msg.readInt64() == 4)
            msg.reset()
            @Assert(msg.readUInt64() == 4)
            msg.reset()
            @Assert(msg.readString() == test.toString())
            msg.reset()
            try {
                msg.readBool()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadUInt32() {
        var msg = ActiveMQStreamMessage()
        var test = UInt32(4)
        msg.writeUInt32(test)
        msg.reset()
        @Assert(msg.readInt32() == Int32(4))
        msg.reset()
        @Assert(msg.readUInt32() == UInt32(4))
        msg.reset()
        @Assert(msg.readInt64() == 4)
        msg.reset()
        @Assert(msg.readUInt64() == 4)
        msg.reset()
        @Assert(msg.readString() == test.toString())
    }

    @TestCase
    public func testReadInt64() {
        var msg = ActiveMQStreamMessage()
        try {
            var test: Int64 = 4
            msg.writeInt64(test)
            msg.reset()
            @Assert(msg.readInt64() == test)
            msg.reset()
            @Assert(msg.readUInt64() == UInt64(4))
            msg.reset()
            @Assert(msg.readString() == test.toString())
            msg.reset()

            try {
                msg.readBool()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg = ActiveMQStreamMessage()
            msg.writeObject(1)

            msg.reset()
            @Assert(Some(1), msg.readObject() as Int64)
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadUInt64() {
        var msg = ActiveMQStreamMessage()

        var test: UInt64 = 4
        msg.writeUInt64(test)
        msg.reset()
        @Assert(msg.readInt64() == Int64(4))
        msg.reset()
        @Assert(msg.readUInt64() == UInt64(4))
        msg.reset()
        @Assert(msg.readString() == test.toString())
    }

    @TestCase
    public func testReadFloat32() {
        var msg = ActiveMQStreamMessage()
        try {
            var test = Float32(4.4)
            msg.writeFloat32(test)
            msg.reset()
            @Assert(msg.readFloat32() == test)
            msg.reset()
            @Assert(msg.readFloat32() == test)
            msg.reset()
            @Assert(msg.readString() == test.toString())
            msg.reset()
            try {
                msg.readBool()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readInt32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readInt64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadFloat64() {
        var msg = ActiveMQStreamMessage()
        try {
            var test: Float64 = 4.4
            msg.writeFloat64(test)
            msg.reset()
            @Assert(msg.readFloat64() == test)
            msg.reset()
            @Assert(msg.readString() == test.toString())
            msg.reset()
            try {
                msg.readBool()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readInt32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readInt64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
            msg.reset()
            try {
                msg.readBytes(Array<Byte>(1, repeat: 0))
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadString(): Unit {
        var msg = ActiveMQStreamMessage()
        try {
            var testByte: Byte = 2
            msg.writeString(testByte.toString())
            msg.reset()
            @Assert(msg.readByte() == testByte)
            msg.clearBody()
            var testInt16: Int16 = 3
            msg.writeString(testInt16.toString())
            msg.reset()
            @Assert(msg.readInt16() == testInt16)
            msg.clearBody()
            var testInt32 = Int32(4)
            msg.writeString(testInt32.toString())
            msg.reset()
            @Assert(msg.readInt32() == testInt32)
            msg.clearBody()
            var testInt64 = 6
            msg.writeString(testInt64.toString())
            msg.reset()
            @Assert(msg.readInt64() == testInt64)
            msg.clearBody()
            var testFloat32 = Float32(6.6)
            msg.writeString(testFloat32.toString())
            msg.reset()
            @Assert(msg.readFloat32() == testFloat32)
            msg.clearBody()
            var testFloat64 = Float64(7.7)
            msg.writeString(testFloat64.toString())
            msg.reset()
            @Assert(msg.readFloat64() == testFloat64)
            msg.clearBody()
            msg.writeString("true")
            msg.reset()
            @Assert(msg.readBool())
            msg.clearBody()
            msg.writeString("a")
            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (e: MessageFormatException) {
            }
            msg.clearBody()
            msg.writeString("777")
            msg.reset()
            try {
                msg.readBytes(Array<Byte>(3, repeat: 0))
                @Assert(false)
            } catch (e: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadBigString() {
        var msg = ActiveMQStreamMessage()
        try {
            var sb = StringBuilder(1024 * 1024)
            for (i in 0..1024 * 1024) {
                sb.append(Rune(UInt32(r'a') + UInt32(i % 26)))
            }
            var bigString = sb.toString()

            msg.writeString(bigString)
            msg.reset()
            @Assert(bigString, msg.readString())
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadBytes() {
        var msg = ActiveMQStreamMessage()
        try {
            var test = Array<Byte>(50, repeat: 0)
            for (i in 0..test.size) {
                test[i] = UInt8(i)
            }
            msg.writeBytes(test)
            msg.reset()

            var valid = Array<Byte>(test.size, repeat: 0)
            msg.readBytes(valid)
            for (i in 0..valid.size) {
                @Assert(valid[i] == test[i])
            }

            msg.reset()
            try {
                msg.readByte()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt8()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readUInt16()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readUInt32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readInt64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readUInt64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat32()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readFloat64()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readChar()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }

            msg.reset()
            try {
                msg.readString()
                @Assert(false)
            } catch (mfe: MessageFormatException) {
            }
        } catch (jmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadObject() {
        var msg = ActiveMQStreamMessage()
        try {
            var testByte = UInt8(2)
            msg.writeByte(testByte)
            msg.reset()
            @Assert(msg.readObject() as Byte == Some(testByte))
            msg.clearBody()

            var testInt16: Int16 = 3
            msg.writeInt16(testInt16)
            msg.reset()
            @Assert(msg.readObject() as Int16 == Some(testInt16))
            msg.clearBody()

            var testInt32: Int32 = 4
            msg.writeInt32(testInt32)
            msg.reset()
            @Assert(msg.readObject() as Int32 == Some(testInt32) )
            msg.clearBody()

            var testInt64 = 6
            msg.writeInt64(testInt64)
            msg.reset()
            @Assert(msg.readObject() as Int64 == Some(testInt64))
            msg.clearBody()

            var testFloat32: Float32 = Float32(6.6)
            msg.writeFloat32(testFloat32)
            msg.reset()
            @Assert(msg.readObject() as Float32 == Some(testFloat32))
            msg.clearBody()

            var testFloat64 = Float64(7.7)
            msg.writeFloat64(testFloat64)
            msg.reset()
            @Assert(msg.readObject() as Float64 == Some(testFloat64))
            msg.clearBody()

            var testChar: Rune = r'z'
            msg.writeChar(testChar)
            msg.reset()
            @Assert(msg.readObject() as Rune == Some(testChar))
            msg.clearBody()

            var data = Array<Byte>(50, repeat: 0)
            for (i in 0..data.size) {
                data[i] = UInt8(i)
            }

            msg.writeBytes(data)
            msg.reset()

            var valid: Array<Byte> = (msg.readObject() as Array<Byte>).getOrThrow()
            @Assert(valid.size, data.size)
            for (i in 0..valid.size) {
                @Assert(valid[i] == data[i])
            }

            msg.clearBody()
            msg.writeBool(true)
            msg.reset()
            @Assert(msg.readObject() as Bool, Some(true))
        } catch (cjmsEx: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testClearBody() {
        var streamMessage = ActiveMQStreamMessage()
        try {
            streamMessage.writeObject(2)
            streamMessage.clearBody()
            @Assert(streamMessage.readOnlyBody, false)
            streamMessage.writeObject(2)
            streamMessage.readObject()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReset() {
        var streamMessage = ActiveMQStreamMessage()
        try {
            streamMessage.writeFloat64(24.5)
            streamMessage.writeInt64(311)
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }
        streamMessage.reset()
        try {
            @Assert(streamMessage.readOnlyBody)
            @Assert(streamMessage.readFloat64(), 24.5)
            @Assert(streamMessage.readInt64(), 311)
        } catch (mnre: MessageNotReadableException) {
            @Assert(false)
        }
        try {
            streamMessage.writeInt32(Int32(33))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
    }

    @TestCase
    public func testReadOnlyBody() {
        var message = ActiveMQStreamMessage()
        try {
            message.writeBool(true)
            message.writeByte(UInt8(1))
            message.writeBytes(Array<Byte>(1, repeat: 0))
            message.writeBytes(Array<Byte>(2, repeat: 0))
            message.writeChar(r'a')
            message.writeFloat64(1.5)
            message.writeFloat32(Float32(1.5))
            message.writeInt32(Int32(1))
            message.writeInt64(1)
            message.writeObject("stringobj")
            message.writeInt16(Int16(1))
            message.writeString("string")
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }
        message.reset()
        try {
            message.readBool()
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
            message.readString()
        } catch (mnwe: MessageNotReadableException) {
            @Assert(false)
        }
        try {
            message.writeBool(true)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeByte(UInt8(1))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeBytes(Array<Byte>(1, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeBytes(Array<Byte>(2, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeChar(r'a')
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeFloat64(1.5)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeFloat32(Float32(1.5))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeInt32(1)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeInt64(1)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeObject("stringobj")
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeInt16(Int16(1))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            message.writeString("string")
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
    }

    @TestCase
    public func testWriteOnlyBody() {
        var message = ActiveMQStreamMessage()
        message.clearBody()
        try {
            message.writeBool(true)
            message.writeByte(UInt8(1))
            message.writeBytes(Array<Byte>(1, repeat: 0))
            message.writeBytes(Array<Byte>(2, repeat: 0))
            message.writeChar(r'a')
            message.writeFloat64(1.5)
            message.writeFloat32(Float32(1.5))
            message.writeInt32(Int32(1))
            message.writeInt64(1)
            message.writeObject("stringobj")
            message.writeInt16(Int16(1))
            message.writeString("string")
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
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readBytes(Array<Byte>(1, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readBytes(Array<Byte>(2, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readChar()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readFloat64()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readFloat32()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readInt32()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readInt64()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readString()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readInt16()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
        try {
            message.readString()
            @Assert(false)
        } catch (mnwe: MessageNotReadableException) {
        }
    }

    @TestCase
    public func testWriteObject() {
        try {
            var message = ActiveMQStreamMessage()
            message.clearBody()
            message.writeObject("test")
            message.writeObject(r'a')
            message.writeObject(false)
            message.writeObject(UInt8(2))
            message.writeObject(Int16(2))
            message.writeObject(Int32(2))
            message.writeObject(2)
            message.writeObject(Float32(2.0))
            message.writeObject(Float64(2.0))
        } catch (e: Exception) {
            @Assert(false)
        }
        try {
            var message = ActiveMQStreamMessage()
            message.clearBody()
            message.writeObject(Object())
            @Assert(false)
        } catch (e: MessageFormatException) {
        } catch (e: Exception) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadEmptyBufferFromStream() {
        var message = ActiveMQStreamMessage()
        message.clearBody()

        let BYTE_LIST: Array<Byte> = [1, 2, 4]

        var readList = Array<Byte>(BYTE_LIST.size - 1, repeat: 0)
        var emptyList: Array<Byte> = []

        message.writeBytes(emptyList)
        message.reset()

        try {
            message.readBytes(readList)
            @Assert(false)
        } catch (e: MessageEOFException) {
            @Assert(true)
        }
    }
}
