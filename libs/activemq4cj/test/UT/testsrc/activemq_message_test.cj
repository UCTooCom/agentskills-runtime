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
public class ActiveMQMessageTest {
    private var connection: ?ActiveMQConnection = None
    private var format: ?WireFormat = None

    private let destination = ActiveMQQueue("cangjie_test_queue")

    private var readOnlyMessage = false

    private let cjmsMessageID = "ID:TEST-ID:0:0:0:1"
    private var cjmsCorrelationID = "testcorrelationid"
    private var cjmsDestination = ActiveMQTopic("test.topic")
    private var cjmsReplyTo = ActiveMQTempTopic("test.replyto.topic:001")
    private var cjmsDeliveryMode = DeliveryMode.PERSISTENT
    private var cjmsRedelivered = true
    private var cjmsType = "test type"
    private var cjmsExpiration = 100000
    private var cjmsPriority: Int32 = 5
    private var cjmsTimestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
    private var consumerIDs: Array<Int64> = Array<Int64>(3, {e: Int64 => e})

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

    public func createObject(): ActiveMQMessage {
        let message = ActiveMQMessage()
        message.content = "hello,cangjie".toArray()
        message.replyTo = ActiveMQTempQueue("tempqueue:1")
        message.destination = destination
        message.producerId = createProducerId()
        message.messageId = createMessageId()
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
        var msg = ActiveMQMessage()
        @Assert(msg.getDataStructureType(), CommandTypes.ACTIVEMQ_MESSAGE)
    }

    @TestCase
    public func testHashCode(): Unit {
        var msg = ActiveMQMessage()
        msg.setCJMSMessageID(this.cjmsMessageID)
        @Assert(msg.getCJMSMessageID().getOrThrow().hashCode() == cjmsMessageID.hashCode())
    }

    @TestCase
    public func testSetReadonly(): Unit {
        var msg = ActiveMQMessage()
        msg.readOnlyProperties = true
        var test = false
        try {
            msg.setInt32Property("test", 1)
        } catch (me: MessageNotWriteableException) {
            test = true
        } catch (e: CJMSException) {
            test = false
        }
        @Assert(test)
    }

    @TestCase
    public func testSetToForeignCJMSID() {
        var msg = ActiveMQMessage()
        msg.setCJMSMessageID("ID:EMS-SERVER.8B443C380083:429")
    }

    @TestCase
    public func testEqualsObject() {
        var msg1 = ActiveMQMessage()
        var msg2 = ActiveMQMessage()
        msg1.setCJMSMessageID(this.cjmsMessageID)
        @Assert(msg1 != msg2)
        msg2.setCJMSMessageID(this.cjmsMessageID)
        @Assert(msg1 == msg2)
    }

    @TestCase
    public func testShallowCopy(): Unit {
        var msg1 = ActiveMQMessage()
        msg1.setCJMSMessageID(this.cjmsMessageID)
        var msg2 = msg1.copy()
        @Assert(!refEq(msg1, msg2) && msg1 == msg2)
    }

    @TestCase
    public func testCopy() {
        this.cjmsCorrelationID = "testcorrelationid"
        this.cjmsDestination = ActiveMQTopic("test.topic")
        this.cjmsReplyTo = ActiveMQTempTopic("test.replyto.topic:001")
        this.cjmsDeliveryMode = DeliveryMode.PERSISTENT
        this.cjmsRedelivered = true
        this.cjmsType = "test type"
        this.cjmsExpiration = 100000
        this.cjmsPriority = 5
        this.cjmsTimestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        this.readOnlyMessage = false

        var msg1: ActiveMQMessage = ActiveMQMessage()
        msg1.setCJMSMessageID(this.cjmsMessageID)
        msg1.setCJMSCorrelationID(this.cjmsCorrelationID)
        msg1.setCJMSDestination(this.cjmsDestination)
        msg1.setCJMSReplyTo(this.cjmsReplyTo)
        msg1.setCJMSDeliveryMode(this.cjmsDeliveryMode)
        msg1.setCJMSRedelivered(this.cjmsRedelivered)
        msg1.setCJMSType(this.cjmsType)
        msg1.setCJMSExpiration(this.cjmsExpiration)
        msg1.setCJMSPriority(this.cjmsPriority)
        msg1.setCJMSTimestamp(this.cjmsTimestamp)
        msg1.readOnlyProperties = true
        var msg2 = (msg1.copy() as ActiveMQMessage).getOrThrow()
        @Assert(msg1.getCJMSMessageID(), msg2.getCJMSMessageID())
        @Assert(msg1.getCJMSCorrelationID() == msg2.getCJMSCorrelationID())
        @Assert(ActiveMQDestination.transform(msg1.getCJMSDestination().getOrThrow()) == ActiveMQDestination.transform(msg2.getCJMSDestination().getOrThrow()))
        @Assert(ActiveMQDestination.transform(msg1.getCJMSReplyTo().getOrThrow()) == ActiveMQDestination.transform(msg2.getCJMSReplyTo().getOrThrow()))
        @Assert(msg1.getCJMSDeliveryMode() == msg2.getCJMSDeliveryMode())
        @Assert(msg1.getCJMSRedelivered() == msg2.getCJMSRedelivered())
        @Assert(msg1.getCJMSType() == msg2.getCJMSType())
        @Assert(msg1.getCJMSExpiration() == msg2.getCJMSExpiration())
        @Assert(msg1.getCJMSPriority() == msg2.getCJMSPriority())
        @Assert(msg1.getCJMSTimestamp() == msg2.getCJMSTimestamp())
    }

    @TestCase
    public func testGetAndSetCJMSMessageID() {
        var msg = ActiveMQMessage()
        msg.setCJMSMessageID(this.cjmsMessageID)
        @Assert(msg.getCJMSMessageID().getOrThrow(), this.cjmsMessageID)
    }

    @TestCase
    public func testGetAndSetCJMSTimestamp() {
        var msg = ActiveMQMessage()
        msg.setCJMSTimestamp(this.cjmsTimestamp)
        @Assert(msg.getCJMSTimestamp() == this.cjmsTimestamp)
    }

    @TestCase
    public func testGetAndSetCJMSReplyTo() {
        var msg = ActiveMQMessage()
        msg.setCJMSReplyTo(this.cjmsReplyTo)
        @Assert(ActiveMQDestination.transform(msg.getCJMSReplyTo().getOrThrow()) == this.cjmsReplyTo)
    }

    @TestCase
    public func testGetAndSetCJMSDestination() {
        var msg = ActiveMQMessage()
        msg.setCJMSDestination(this.cjmsDestination)
        @Assert(ActiveMQDestination.transform(msg.getCJMSDestination().getOrThrow()) == this.cjmsDestination)
    }

    @TestCase
    public func testGetAndSetCJMSDeliveryMode() {
        var msg = ActiveMQMessage()
        msg.setCJMSDeliveryMode(this.cjmsDeliveryMode)
        @Assert(msg.getCJMSDeliveryMode() == this.cjmsDeliveryMode)
    }

    @TestCase
    public func testGetAndSetCJMSRedelivered() {
        var msg = ActiveMQMessage()
        msg.setCJMSRedelivered(this.cjmsRedelivered)
        @Assert(msg.getCJMSRedelivered() == this.cjmsRedelivered)
    }

    @TestCase
    public func testGetAndSetCJMSType() {
        var msg = ActiveMQMessage()
        msg.setCJMSType(this.cjmsType)
        @Assert(msg.getCJMSType().getOrThrow() == this.cjmsType)
    }

    @TestCase
    public func testGetAndSetJMSExpiration() {
        var msg = ActiveMQMessage()
        msg.setCJMSExpiration(this.cjmsExpiration)
        @Assert(msg.getCJMSExpiration() == this.cjmsExpiration)
    }

    @TestCase
    public func testGetAndSetCJMSPriority() {
        var msg = ActiveMQMessage()
        msg.setCJMSPriority(this.cjmsPriority)
        @Assert(msg.getCJMSPriority() == this.cjmsPriority)

        msg.setCJMSPriority(-90)
        @Assert(0, msg.getCJMSPriority())

        msg.setCJMSPriority(90)
        @Assert(9, msg.getCJMSPriority())
    }

    @TestCase
    public func testClearProperties() {
        var msg = ActiveMQMessage()
        msg.setStringProperty("test", "test")
        msg.content = Array<Byte>(1, repeat: 0)
        msg.setCJMSMessageID(this.cjmsMessageID)
        msg.clearProperties()
        try {
            msg.getStringProperty("test")
            @Assert(false)
        } catch (e: Exception) {
            @Assert(true)
        }
        @Assert(msg.getCJMSMessageID().isSome())
        @Assert(msg.content.isSome())
    }

    @TestCase
    public func testPropertyExists() {
        var msg = ActiveMQMessage()
        msg.setStringProperty("test", "test")
        @Assert(msg.propertyExists("test"))

        msg.setInt32Property("JMSXDeliveryCount", 1)
        @Assert(msg.propertyExists("JMSXDeliveryCount"))
    }

    @TestCase
    public func testGetBoolProperty() {
        var msg = ActiveMQMessage()
        var name = "boolProperty"
        msg.setBoolProperty(name, true)
        @Assert(msg.getBoolProperty(name))
    }

    @TestCase
    public func testGetByteProperty() {
        var msg = ActiveMQMessage()
        var name = "byteProperty"
        msg.setByteProperty(name, UInt8(1))
        @Assert(msg.getByteProperty(name) == 1)
    }

    @TestCase
    public func testGetInt16Property() {
        var msg = ActiveMQMessage()
        var name = "i16Property"
        msg.setInt16Property(name, Int16(1))
        @Assert(msg.getInt32Property(name) == 1)
    }

    @TestCase
    public func testGetInt32Property() {
        var msg = ActiveMQMessage()
        var name = "int32Property"
        msg.setInt32Property(name, 1)
        @Assert(msg.getInt32Property(name) == 1)
    }

    @TestCase
    public func testGetInt64Property() {
        var msg = ActiveMQMessage()
        var name = "int64Property"
        msg.setInt64Property(name, 1)
        @Assert(msg.getInt64Property(name) == 1)
    }

    @TestCase
    public func testGetFloat32Property() {
        var msg = ActiveMQMessage()
        var name = "float32Property"
        msg.setFloat32Property(name, Float32(1.3))
        @Assert(msg.getFloat32Property(name) == Float32(1.3))
    }

    @TestCase
    public func testGetFloat64Property() {
        var msg = ActiveMQMessage()
        var name = "float64Property"
        msg.setFloat64Property(name, Float64(1.3))
        @Assert(msg.getFloat64Property(name) == Float64(1.3))
    }

    @TestCase
    public func testGetStringProperty() {
        var msg = ActiveMQMessage()
        var name = "stringProperty"
        msg.setStringProperty(name, name)
        @Assert(msg.getStringProperty(name) == name)
    }

    @TestCase
    public func testGetObjectProperty() {
        var msg = ActiveMQMessage()
        var name = "float32Property"
        msg.setFloat32Property(name, Float32(1.3))
        @Assert(msg.getObjectProperty(name) is Float32)
        @Assert((msg.getObjectProperty(name) as Float32).getOrThrow() == Float32(1.3))
    }

    @TestCase
    public func testSetJMSDeliveryModeProperty() {
        var message = ActiveMQMessage()
        var propertyName = "JMSDeliveryMode"

        message.setObjectProperty(propertyName, true)
        @Assert(message.persistent)
        message.setObjectProperty(propertyName, false)
        @Assert(message.persistent, false)
        message.setBoolProperty(propertyName, true)
        @Assert(message.persistent)
        message.setBoolProperty(propertyName, false)
        @Assert(message.persistent, false)

        message.setObjectProperty(propertyName, Int32(2))
        @Assert(message.persistent)
        message.setObjectProperty(propertyName, Int32(1))
        @Assert(message.persistent, false)
        message.setInt32Property(propertyName, Int32(2))
        @Assert(message.persistent)
        message.setInt32Property(propertyName, Int32(1))
        @Assert(message.persistent, false)

        message.setObjectProperty(propertyName, "PERSISTENT")
        @Assert(message.persistent)
        message.setObjectProperty(propertyName, "NON_PERSISTENT")
        @Assert(message.persistent, false)
        message.setStringProperty(propertyName, "PERSISTENT")
        @Assert(message.persistent)
        message.setStringProperty(propertyName, "NON_PERSISTENT")
        @Assert(message.persistent, false)
    }

    @TestCase
    public func testGetPropertyNames() {
        var message = ActiveMQMessage()
        var name1 = "floatProperty"
        message.setFloat32Property(name1, Float32(1.3))
        var name2 = "JMSXDeliveryCount"
        message.setInt32Property(name2, Int32(1))
        var name3 = "JMSRedelivered"
        message.setBoolProperty(name3, false)
        var found1 = false
        var found2 = false
        var found3 = false
        if (let Some(list) <- message.getPropertyNames()) {
            for (property in list) {
                if (property == name1) {
                    found1 = true
                }
                if (property == name2) {
                    found2 = true
                }
                if (property == name3) {
                    found3 = true
                }
            }
        }

        @Assert(found1)

        @Assert(found2, false)
        @Assert(found3, false)
    }

    @TestCase
    public func testSetObjectProperty() {
        var msg = ActiveMQMessage()
        var name = "property"

        try {
            msg.setObjectProperty(name, "string")
            msg.setObjectProperty(name, UInt8(1))
            msg.setObjectProperty(name, Int16(1))
            msg.setObjectProperty(name, Int32(1))
            msg.setObjectProperty(name, Int64(1))
            msg.setObjectProperty(name, Float32(1.1))
            msg.setObjectProperty(name, Float64(1.1))
            msg.setObjectProperty(name, true)
            msg.setObjectProperty(name, None<Any>)
        } catch (e: MessageFormatException) {
            @Assert(false)
        }

        try {
            msg.setObjectProperty(name, Array<Byte>(5, repeat: 0))
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.setObjectProperty(name, Object())
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    @TestCase
    public func testConvertProperties() {
        var msg = ActiveMQMessage()

        msg.setProperty("stringProperty", "string")
        msg.setProperty("byteProperty", UInt8(1))
        msg.setProperty("int16Property", Int16(1))
        msg.setProperty("int32Property", Int32(1))
        msg.setProperty("int64Property", Int64(1))
        msg.setProperty("float32Property", Float32(1.1))
        msg.setProperty("float64Property", Float64(1.1))
        msg.setProperty("boolProperty", true)
        msg.setProperty("nullProperty", None<Any>)

        msg.beforeMarshall()

        var properties: HashMap<String, Any> = msg.properties.getOrThrow()
        @Assert(properties.get("stringProperty").getOrThrow() as String, Some("string"))
        @Assert(properties.get("byteProperty").getOrThrow() as Byte, Some(UInt8(1)))
        @Assert(properties.get("int16Property").getOrThrow() as Int16, Some(Int16(1)))
        @Assert(properties.get("int32Property").getOrThrow() as Int32, Some(Int32(1)))
        @Assert(properties.get("int64Property").getOrThrow() as Int64, Some(Int64(1)))
        @Assert(properties.get("float32Property").getOrThrow() as Float32, Some(Float32(1.1)))
        @Assert(properties.get("float64Property").getOrThrow() as Float64, Some(Float64(1.1)))
        @Assert(properties.get("boolProperty").getOrThrow() as Bool, Some(true))
        @Assert((properties.get("nullProperty").getOrThrow() as Option<Any>).getOrThrow().isNone())
    }

    @TestCase
    public func testSetNoneProperty() {
        var msg = ActiveMQMessage()
        var name = "cheese"
        msg.setStringProperty(name, "Cheddar")
        @Assert(Some("Cheddar"), msg.getStringProperty(name))

        msg.setProperty(name, None<Any>)

        try {
            msg.getStringProperty(name)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    @TestCase
    public func testSetEmptyPropertyName() {
        var msg = ActiveMQMessage()

        try {
            msg.setStringProperty("", "Cheese")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
        }
    }

    @TestCase
    public func testGetAndSetJMSXDeliveryCount() {
        var msg = ActiveMQMessage()
        msg.setInt32Property("JMSXDeliveryCount", 1)
        var count = msg.getInt32Property("JMSXDeliveryCount")
        @Assert(count == 1)
    }

    @TestCase
    public func testClearBody() {
        var message = ActiveMQBytesMessage()
        message.clearBody()
        @Assert(message.readOnlyBody, false)
        @Assert(message.content.isNone())
    }

    @TestCase
    public func testBooleanPropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.setBoolProperty(propertyName, true)

        @Assert(msg.getObjectProperty(propertyName) as Bool, Some(true))
        @Assert(msg.getBoolProperty(propertyName))
        @Assert(msg.getStringProperty(propertyName), "true")

        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt16Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    @TestCase
    public func testBytePropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.setByteProperty(propertyName, UInt8(1))

        @Assert(msg.getObjectProperty(propertyName) as Byte, 1)
        @Assert(msg.getByteProperty(propertyName), 1)
        @Assert(msg.getInt16Property(propertyName), 1)
        @Assert(msg.getInt32Property(propertyName), 1)
        @Assert(msg.getInt64Property(propertyName), 1)
        @Assert(msg.getStringProperty(propertyName), "1")

        try {
            msg.getBoolProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    @TestCase
    public func testInt16PropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.setInt16Property(propertyName, Int16(1))

        @Assert(msg.getObjectProperty(propertyName) as Int16, 1)
        @Assert(msg.getInt16Property(propertyName), 1)
        @Assert(msg.getInt32Property(propertyName), 1)
        @Assert(msg.getInt64Property(propertyName), 1)
        @Assert(msg.getStringProperty(propertyName), "1")

        try {
            msg.getBoolProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    public func testInt32PropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.setInt32Property(propertyName, 1)

        @Assert(msg.getObjectProperty(propertyName) as Int32, 1)
        @Assert(msg.getInt32Property(propertyName), 1)
        @Assert(msg.getInt64Property(propertyName), 1)
        @Assert(msg.getStringProperty(propertyName), "1")

        try {
            msg.getBoolProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt16Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    public func testLongPropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.setInt64Property(propertyName, 1)

        @Assert(msg.getObjectProperty(propertyName) as Int64, 1)
        @Assert(msg.getInt64Property(propertyName), 1)
        @Assert(msg.getStringProperty(propertyName), "1")
        try {
            msg.getBoolProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt16Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    public func testFloat32PropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.setFloat32Property(propertyName, Float32(1.5))
        @Assert(msg.getObjectProperty(propertyName) as Float32, Some(Float32(1.5)))
        @Assert(msg.getFloat32Property(propertyName), 1.5)
        @Assert(msg.getFloat64Property(propertyName), 1.5)
        @Assert(msg.getStringProperty(propertyName), "1.5")
        try {
            msg.getBoolProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt16Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    public func testFLoat64PropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.setFloat64Property(propertyName, 1.5)
        @Assert(msg.getObjectProperty(propertyName) as Float64, Some(Float64(1.5)))
        @Assert(msg.getFloat64Property(propertyName), 1.5)
        @Assert(msg.getStringProperty(propertyName), "1.5")
        try {
            msg.getBoolProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt16Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    public func testStringPropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        var stringValue = "true"
        msg.setStringProperty(propertyName, stringValue)
        @Assert(msg.getStringProperty(propertyName), stringValue)
        @Assert(msg.getObjectProperty(propertyName) as String, Some(stringValue))
        @Assert(msg.getBoolProperty(propertyName), true)

        stringValue = "1"
        msg.setStringProperty(propertyName, stringValue)
        @Assert(msg.getByteProperty(propertyName), 1)
        @Assert(msg.getInt16Property(propertyName), 1)
        @Assert(msg.getInt32Property(propertyName), 1)
        @Assert(msg.getInt64Property(propertyName), 1)

        stringValue = "1.5"
        msg.setStringProperty(propertyName, stringValue)
        @Assert(msg.getFloat32Property(propertyName), 1.5)
        @Assert(msg.getFloat64Property(propertyName), 1.5)

        stringValue = "bad"
        msg.setStringProperty(propertyName, stringValue)
        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt16Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        @Assert(msg.getBoolProperty(propertyName))
    }

    public func testObjectPropertyConversion() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        var obj = Object()
        try {
            msg.setProperty(propertyName, obj)
        } catch (e: Exception) {
        }

        try {
            msg.getStringProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getBoolProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getByteProperty(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt16Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getInt64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat32Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }

        try {
            msg.getFloat64Property(propertyName)
            @Assert(false)
        } catch (e: MessageFormatException) {
        }
    }

    public func testReadOnlyProperties() {
        var msg = ActiveMQMessage()
        var propertyName = "property"
        msg.readOnlyProperties = true

        try {
            msg.setObjectProperty(propertyName, Object())
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setStringProperty(propertyName, "test")
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setBoolProperty(propertyName, true)
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setByteProperty(propertyName, UInt8(1))
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setInt16Property(propertyName, Int16(1))
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setInt32Property(propertyName, Int32(1))
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setInt64Property(propertyName, Int64(1))
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setFloat32Property(propertyName, Float32(1.5))
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }

        try {
            msg.setFloat64Property(propertyName, Float64(1.5))
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }
    }

    public func testIsExpired() {
        var msg = ActiveMQMessage()
        var timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        msg.setCJMSExpiration(timestamp - 1)
        @Assert(msg.isExpired())
        msg.setCJMSExpiration(timestamp + 10000)
        @Assert(msg.isExpired(), false)
    }
}
