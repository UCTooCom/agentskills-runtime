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
public class ActiveMQMapMessageTest {
    private var connection: ?ActiveMQConnection = None
    private var format: ?WireFormat = None

    private let destination = ActiveMQQueue("cangjie_test_queue")
    private let name: String = "testName"

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

    public func createObject(): ActiveMQMapMessage {
        let mapMessage = ActiveMQMapMessage()
        mapMessage.setString("name", "wuzixu")
        mapMessage.setString("country", "wu")
        mapMessage.replyTo = ActiveMQTempQueue("tempqueue:1")
        mapMessage.destination = destination
        mapMessage.producerId = createProducerId()
        mapMessage.messageId = createMessageId()
        mapMessage.expiration = 1
        mapMessage.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        mapMessage.correlationId = "correlationId:1"
        mapMessage.persistent = true
        mapMessage.redeliveryCounter = 1
        mapMessage.messageType = "type:1"
        mapMessage.priority = 10
        mapMessage.groupID = "groupID:1"
        mapMessage.userID = "userID:1"
        mapMessage.groupSequence = 1
        mapMessage.brokerInTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        mapMessage.brokerOutTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        mapMessage.jmsXGroupFirstForConsumer = true
        mapMessage.brokerPath = Array<BrokerId>(2, {index: Int64 => BrokerId("broker:1")})
        return mapMessage
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
    public func testBytesConversion(): Unit {
        var msg = ActiveMQMapMessage()

        msg.setBool("bool", true)
        msg.setByte("byte", UInt8(1))
        msg.setBytes("bytes", Array<Byte>(1, repeat: 0))
        msg.setChar("char", r'a')
        msg.setFloat64("float64", 1.5)
        msg.setFloat32("float", Float32(1.5))
        msg.setInt32("int", Int32(1))
        msg.setInt64("int64", Int64(1))
        msg.setObject("object", "stringObj")
        msg.setInt16("int16", Int16(1))
        msg.setString("string", "string")

        var sb = StringBuilder(1024 * 1024)
        for (i in 0..1024 * 1024) {
            sb.append(Rune(UInt32(r'a') + UInt32(i % 26)))
        }
        var bigString = sb.toString()

        msg.setString("bigString", bigString)

        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()

        @Assert(msg.getBool("bool"), true)
        @Assert(msg.getByte("byte"), UInt8(1))
        @Assert(msg.getBytes("bytes").getOrThrow().size, 1)
        @Assert(msg.getChar("char"), r'a')
        @Assert(msg.getFloat64("float64"), 1.5)
        @Assert(msg.getFloat32("float"), Float32(1.5))
        @Assert(msg.getInt32("int"), 1)
        @Assert(msg.getInt64("int64"), 1)
        @Assert(msg.getObject("object") as String, Some("stringObj"))
        @Assert(msg.getInt16("int16"), 1)
        @Assert(msg.getString("string"), "string")
        @Assert(msg.getString("bigString"), bigString)
    }

    @TestCase
    public func testGetBoolean(): Unit {
        var msg = ActiveMQMapMessage()
        msg.setBool(name, true)
        msg.readOnlyBody = true
        @Assert(msg.getBool(name))
        msg.clearBody()
        msg.setString(name, "true")

        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()

        @Assert(msg.getBool(name))
    }

    @TestCase
    public func testGetByte() {
        var msg = ActiveMQMapMessage()
        msg.setByte(this.name, UInt8(1))
        msg.setString("stringToByte", "2")
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getByte(this.name) == UInt8(1))
        @Assert(msg.getByte("stringToByte") == UInt8(2))
    }

    @TestCase
    public func testGetInt8() {
        var msg = ActiveMQMapMessage()
        msg.setInt8(this.name, Int8(1))
        msg.setByte("u8Toi8", UInt8(1))
        msg.setString("stringToInt8", "2")
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getInt8(this.name) == Int8(1))
        @Assert(msg.getInt8("u8Toi8") == Int8(1))
        @Assert(msg.getInt8("stringToInt8") == Int8(2))
    }

    @TestCase
    public func testGetInt16() {
        var msg = ActiveMQMapMessage()
        msg.setInt16(this.name, Int16(1))
        msg.setByte("byteToInt16", UInt8(1))
        msg.setString("stringToInt16", "1")
        msg.setInt8("i8Toi16", Int8(1))
        msg.setUInt16("u16Toi16", UInt16(1))
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getInt16(this.name) == Int16(1))
        @Assert(msg.getInt16("byteToInt16") == Int16(1))
        @Assert(msg.getInt16("stringToInt16") == Int16(1))
        @Assert(msg.getInt16("i8Toi16") == Int16(1))
        @Assert(msg.getInt16("u16Toi16") == Int16(1))
    }

    @TestCase
    public func testGetUInt16() {
        var msg = ActiveMQMapMessage()
        msg.setUInt16(this.name, UInt16(1))
        msg.setByte("byteToUInt16", UInt8(1))
        msg.setString("stringToUInt16", "1")
        msg.setInt8("i8Tou16", Int8(1))
        msg.setInt16("i16Tou16", Int16(1))
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getUInt16(this.name) == UInt16(1))
        @Assert(msg.getUInt16("byteToUInt16") == UInt16(1))
        @Assert(msg.getUInt16("stringToUInt16") == UInt16(1))
        @Assert(msg.getUInt16("i8Tou16") == UInt16(1))
        @Assert(msg.getUInt16("i16Tou16") == UInt16(1))
    }

    @TestCase
    public func testGetRune() {
        var msg = ActiveMQMapMessage()
        msg.setChar(this.name, r'a')
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getChar(this.name) == r'a')
    }

    @TestCase
    public func testGetInt32() {
        var msg = ActiveMQMapMessage()
        msg.setInt32(this.name, Int32(1))
        msg.setByte("byteToInt32", UInt8(1))
        msg.setString("stringToInt32", "1")
        msg.setInt8("i8Toi32", Int8(1))
        msg.setUInt16("u16Toi32", UInt16(1))
        msg.setInt16("i16Toi32", Int16(1))
        msg.setUInt32("u32Toi32", UInt32(1))
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getInt32(this.name) == Int32(1))
        @Assert(msg.getInt32("byteToInt32") == Int32(1))
        @Assert(msg.getInt32("stringToInt32") == Int32(1))
        @Assert(msg.getInt32("i8Toi32") == Int32(1))
        @Assert(msg.getInt32("u16Toi32") == Int32(1))
        @Assert(msg.getInt32("i16Toi32") == Int32(1))
        @Assert(msg.getInt32("u32Toi32") == Int32(1))
    }

    @TestCase
    public func testGetUInt32() {
        var msg = ActiveMQMapMessage()
        msg.setUInt32(this.name, UInt32(1))
        msg.setByte("byteToUInt32", UInt8(1))
        msg.setString("stringToUInt32", "1")
        msg.setInt8("i8Tou32", Int8(1))
        msg.setUInt16("u16Tou32", UInt16(1))
        msg.setInt16("i16Tou32", Int16(1))
        msg.setInt32("i32Tou32", Int32(1))
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getUInt32(this.name) == UInt32(1))
        @Assert(msg.getUInt32("byteToUInt32") == UInt32(1))
        @Assert(msg.getUInt32("stringToUInt32") == UInt32(1))
        @Assert(msg.getUInt32("i8Tou32") == UInt32(1))
        @Assert(msg.getUInt32("u16Tou32") == UInt32(1))
        @Assert(msg.getUInt32("i16Tou32") == UInt32(1))
        @Assert(msg.getUInt32("i32Tou32") == UInt32(1))
    }

    @TestCase
    public func testGetInt64() {
        var msg = ActiveMQMapMessage()
        msg.setInt64(this.name, Int64(1))
        msg.setByte("byteToInt64", UInt8(1))
        msg.setString("stringToInt64", "1")
        msg.setInt8("i8Toi64", Int8(1))
        msg.setUInt16("u16Toi64", UInt16(1))
        msg.setInt16("i16Toi64", Int16(1))
        msg.setInt32("i32Toi64", Int32(1))
        msg.setUInt32("u32Toi64", UInt32(1))
        msg.setUInt64("u64Toi64", UInt64(1))
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getInt64(this.name) == Int64(1))
        @Assert(msg.getInt64("byteToInt64") == Int64(1))
        @Assert(msg.getInt64("stringToInt64") == Int64(1))
        @Assert(msg.getInt64("i8Toi64") == Int64(1))
        @Assert(msg.getInt64("u16Toi64") == Int64(1))
        @Assert(msg.getInt64("i16Toi64") == Int64(1))
        @Assert(msg.getInt64("i32Toi64") == Int64(1))
        @Assert(msg.getInt64("u32Toi64") == Int64(1))
        @Assert(msg.getInt64("u64Toi64") == Int64(1))
    }

    @TestCase
    public func testGetUInt64() {
        var msg = ActiveMQMapMessage()
        msg.setUInt64(this.name, UInt64(1))
        msg.setByte("byteToUInt64", UInt8(1))
        msg.setString("stringToUInt64", "1")
        msg.setInt8("i8Tou64", Int8(1))
        msg.setUInt16("u16Tou64", UInt16(1))
        msg.setInt16("i16Tou64", Int16(1))
        msg.setInt32("i32Tou64", Int32(1))
        msg.setUInt32("u32Tou64", UInt32(1))
        msg.setInt64("i64Tou64", Int64(1))
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getUInt64(this.name) == UInt64(1))
        @Assert(msg.getUInt64("byteToUInt64") == UInt64(1))
        @Assert(msg.getUInt64("stringToUInt64") == UInt64(1))
        @Assert(msg.getUInt64("i8Tou64") == UInt64(1))
        @Assert(msg.getUInt64("u16Tou64") == UInt64(1))
        @Assert(msg.getUInt64("i16Tou64") == UInt64(1))
        @Assert(msg.getUInt64("i32Tou64") == UInt64(1))
        @Assert(msg.getUInt64("u32Tou64") == UInt64(1))
        @Assert(msg.getUInt64("i64Tou64") == UInt64(1))
    }

    @TestCase
    public func testGetFloat32() {
        var msg = ActiveMQMapMessage()
        msg.setFloat32(this.name, Float32(1.5))
        msg.setString("string", "1.5")
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getFloat32(this.name) == Float32(1.5))
        @Assert(msg.getFloat32("string") == Float32.parse("1.5"))
    }

    @TestCase
    public func testGetFloat64() {
        var msg = ActiveMQMapMessage()
        msg.setFloat64(this.name, Float64(1.5))
        msg.setFloat32("f32", Float32(1.5))
        msg.setString("string", "1.5")
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getFloat64(this.name) == Float64(1.5))
        @Assert(msg.getFloat64("string") == Float64.parse("1.5"))
        @Assert(msg.getFloat64("f32") == Float64(1.5))
    }

    @TestCase
    public func testGetFloat64WithMaxValue() {
        var msg = ActiveMQMapMessage()
        msg.setFloat64(this.name, Float64.Max)
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(Float64.Max, msg.getFloat64(this.name))
    }

    @TestCase
    public func testGetString() {
        var msg = ActiveMQMapMessage()
        var str = "test"
        msg.setString(this.name, str)
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()
        @Assert(msg.getString(this.name), str)
    }

    @TestCase
    public func testGetBytes() {
        var msg = ActiveMQMapMessage()
        var bytes1 = Array<Byte>(3, repeat: 0)
        var bytes2 = Array<Byte>(2, repeat: 0)

        msg.setBytes(this.name, bytes1)
        msg.setBytes("${this.name}2", bytes2)
        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()

        @Assert(msg.getBytes(this.name), Some(bytes1))
        @Assert(msg.getBytes("${this.name}2").getOrThrow().size, bytes2.size)
    }

    @TestCase
    public func testGetBytesWithNoneValue() {
        var msg = ActiveMQMapMessage()
        @Assert(msg.getBytes(this.name).isNone())
    }

    @TestCase
    public func testGetObject() {
        var msg = ActiveMQMapMessage()
        var boolValue = true
        var byteValue = UInt8(1)
        var bytesValue = Array<Byte>(3, repeat: 0)
        var charValue = r'a'
        var float64Value = Float64(1.5)
        var float32Value = Float32(1.5)
        var int32Value = Int32(1)
        var int64Value = Int64(1)
        var int16Value = Int16(1)
        var stringValue = "string"

        try {
            msg.setObject("bool", boolValue)
            msg.setObject("byte", byteValue)
            msg.setObject("bytes", bytesValue)
            msg.setObject("char", charValue)
            msg.setObject("float64", float64Value)
            msg.setObject("float32", float32Value)
            msg.setObject("int32", int32Value)
            msg.setObject("int64", int64Value)
            msg.setObject("int16", int16Value)
            msg.setObject("string", stringValue)
        } catch (mfe: MessageFormatException) {
            mfe.printStackTrace()
            @Assert(false)
        }

        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()

        @Assert(msg.getObject("bool") is Bool)
        @Assert(msg.getBool("bool"), boolValue)
        @Assert(msg.getObject("byte") is Byte)
        @Assert(msg.getByte("byte"), byteValue)
        @Assert(msg.getObject("bytes") is Array<Byte>)
        @Assert(msg.getBytes("bytes").getOrThrow().size, bytesValue.size)
        @Assert(msg.getObject("char") is Rune)
        @Assert(msg.getChar("char"), charValue)
        @Assert(msg.getObject("float64") is Float64)
        @Assert(msg.getFloat64("float64"), float64Value)
        @Assert(msg.getObject("float32") is Float32)
        @Assert(msg.getFloat32("float32"), float32Value)
        @Assert(msg.getObject("int32") is Int32)
        @Assert(msg.getInt32("int32"), int32Value)
        @Assert(msg.getObject("int64") is Int64)
        @Assert(msg.getInt64("int64"), int64Value)
        @Assert(msg.getObject("int16") is Int16)
        @Assert(msg.getInt16("int16"), int16Value)
        @Assert(msg.getObject("string") is String)
        @Assert(msg.getString("string"), stringValue)

        msg.clearBody()
        try {
            msg.setObject("object", Object())
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    @TestCase
    public func testGetMapNames() {
        var msg = ActiveMQMapMessage()
        msg.setBool("bool", true)
        msg.setByte("byte", UInt8(1))
        msg.setBytes("bytes1", Array<Byte>(1, repeat: 0))
        msg.setBytes("bytes2", Array<Byte>(2, repeat: 0))
        msg.setChar("char", r'a')
        msg.setFloat64("float64", 1.5)
        msg.setFloat32("float32", Float32(1.5))
        msg.setInt32("int32", 1)
        msg.setInt64("int64", 1)
        msg.setObject("object", "stringObj")
        msg.setInt16("int16", Int16(1))
        msg.setString("string", "string")

        msg = (msg.copy() as ActiveMQMapMessage).getOrThrow()

        var mapNamesList = msg.getMapNames()
        @Assert(mapNamesList.isSome())
        if (let Some(mapNamesList) <- mapNamesList) {
            var arr = mapNamesList.toArray()

            @Assert(arr.size, 12)
            @Assert(arr.contains("bool"))
            @Assert(arr.contains("byte"))
            @Assert(arr.contains("bytes1"))
            @Assert(arr.contains("bytes2"))
            @Assert(arr.contains("char"))
            @Assert(arr.contains("float64"))
            @Assert(arr.contains("float32"))
            @Assert(arr.contains("int32"))
            @Assert(arr.contains("int64"))
            @Assert(arr.contains("object"))
            @Assert(arr.contains("int16"))
            @Assert(arr.contains("string"))
        }
    }

    @TestCase
    public func testItemExists() {
        var mapMessage = ActiveMQMapMessage()

        mapMessage.setString("exists", "test")

        mapMessage = (mapMessage.copy() as ActiveMQMapMessage).getOrThrow()

        @Assert(mapMessage.itemExists("exists"))
        @Assert(mapMessage.itemExists("doesntExist"), false)
    }

    @TestCase
    public func testClearBody() {
        var mapMessage = ActiveMQMapMessage()
        mapMessage.setString("String", "String")
        mapMessage.clearBody()
        @Assert(mapMessage.readOnlyBody, false)

        mapMessage.onSend()
        mapMessage.content = mapMessage.content
        @Assert(mapMessage.getString("String").isNone())
        mapMessage.clearBody()
        mapMessage.setString("String", "String")

        mapMessage = (mapMessage.copy() as ActiveMQMapMessage).getOrThrow()

        mapMessage.getString("String")
    }

    @TestCase
    public func testReadOnlyBody() {
        var msg = ActiveMQMapMessage()
        msg.setBool("bool", true)
        msg.setByte("byte", UInt8(1))
        msg.setBytes("bytes", Array<Byte>(1, repeat: 0))
        msg.setBytes("bytes2", Array<Byte>(2, repeat: 0))
        msg.setChar("char", r'a')
        msg.setFloat64("float64", 1.5)
        msg.setFloat32("float32", Float32(1.5))
        msg.setInt32("int", 1)
        msg.setInt64("int64", 1)
        msg.setObject("object", "stringObj")
        msg.setInt16("int16", Int16(1))
        msg.setString("string", "string")

        msg.readOnlyBody = true

        try {
            msg.getBool("bool")
            msg.getByte("byte")
            msg.getBytes("bytes")
            msg.getChar("char")
            msg.getFloat64("float64")
            msg.getFloat32("float32")
            msg.getInt32("int32")
            msg.getInt64("int64")
            msg.getObject("object")
            msg.getInt16("int16")
            msg.getString("string")
        } catch (mnre: MessageNotReadableException) {
            @Assert(false)
        }
        try {
            msg.setBool("bool", true)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setByte("byte", UInt8(1))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setBytes("bytes", Array<Byte>(1, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setBytes("bytes2", Array<Byte>(2, repeat: 0))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setChar("char", r'a')
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setFloat64("float64", 1.5)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setFloat32("float32", Float32(1.5))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setInt32("int32", 1)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setInt64("int64", 1)
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setObject("object", "stringObj")
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setInt16("int16", Int16(1))
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
        try {
            msg.setString("string", "string")
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
    }

    @TestCase
    public func testWriteOnlyBody() {
        var msg = ActiveMQMapMessage()
        msg.readOnlyBody = false

        msg.setBool("bool", true)
        msg.setByte("byte", UInt8(1))
        msg.setBytes("bytes", Array<Byte>(1, repeat: 0))
        msg.setBytes("bytes2", Array<Byte>(2, repeat: 0))
        msg.setChar("char", r'a')
        msg.setFloat64("float64", 1.5)
        msg.setFloat32("float32", Float32(1.5))
        msg.setInt32("int32", 1)
        msg.setInt64("int64", 1)
        msg.setObject("object", "stringObj")
        msg.setInt16("int16", Int16(1))
        msg.setString("string", "string")

        msg.readOnlyBody = true

        msg.getBool("bool")
        msg.getByte("byte")
        msg.getBytes("bytes")
        msg.getChar("char")
        msg.getFloat64("float64")
        msg.getFloat32("float32")
        msg.getInt32("int32")
        msg.getInt64("int64")
        msg.getObject("object")
        msg.getInt16("int16")
        msg.getString("string")
    }
}
