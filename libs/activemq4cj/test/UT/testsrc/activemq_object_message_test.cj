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
public class ActiveMQObjectMessageTest {
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

    public func createObject(): ActiveMQObjectMessage {
        let obejctMessage = ActiveMQObjectMessage()
        obejctMessage.object = Person("name", 18).serialize()
        obejctMessage.replyTo = ActiveMQTempQueue("tempqueue:1")
        obejctMessage.destination = destination
        obejctMessage.producerId = createProducerId()
        obejctMessage.messageId = createMessageId()
        obejctMessage.expiration = 1
        obejctMessage.timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        obejctMessage.correlationId = "correlationId:1"
        obejctMessage.persistent = true
        obejctMessage.arrival = 10
        obejctMessage.redeliveryCounter = 1
        obejctMessage.messageType = "type:1"
        obejctMessage.priority = 10
        obejctMessage.groupID = "groupID:1"
        obejctMessage.userID = "userID:1"
        obejctMessage.groupSequence = 1
        obejctMessage.brokerInTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        obejctMessage.brokerOutTime = DateTime.now().toUnixTimeStamp().toMilliseconds()
        obejctMessage.jmsXGroupFirstForConsumer = true
        obejctMessage.brokerPath = Array<BrokerId>(2, {index: Int64 => BrokerId("broker:1")})
        return obejctMessage
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
    public func testSetObject(): Unit {
        var msg = ActiveMQObjectMessage()
        var str = "testText"
        msg.object = str.serialize()

        msg = (msg.copy() as ActiveMQObjectMessage).getOrThrow()
        @Assert(String.deserialize(msg.object.getOrThrow()), str)
    }

    @TestCase
    public func testClearBody() {
        var objectMessage = ActiveMQObjectMessage()
        try {
            objectMessage.object = "String".serialize()
            objectMessage.clearBody()
            @Assert(objectMessage.readOnlyBody, false)
            @Assert(objectMessage.object.isNone())
            objectMessage.object = "String".serialize()
        } catch (mnwe: MessageNotWriteableException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testReadOnlyBody() {
        var msg = ActiveMQObjectMessage()
        msg.object = "test".serialize()
        msg.readOnlyBody = true
        try {
            var dm = msg.object
        } catch (e: MessageNotReadableException) {
            @Assert(false)
        }
        try {
            msg.object = "test".serialize()
            @Assert(false)
        } catch (e: MessageNotWriteableException) {
        }
    }

    @TestCase
    public func testWriteOnlyBody() {
        var msg = ActiveMQObjectMessage()
        msg.readOnlyBody = false
        try {
            msg.object = "test".serialize()
            var dm = msg.object
        } catch (e: MessageNotReadableException) {
            @Assert(false)
        }

        msg.readOnlyBody = true
        try {
            var dm = msg.object
            msg.object = "test".serialize()
            @Assert(false)
        } catch (e: MessageNotReadableException) {
            @Assert(false)
        } catch (mnwe: MessageNotWriteableException) {
        }
    }
}

public class Person <: Serializable<Any> & Equatable<Person> & ToString {
    public let name: String
    public let age: Int64

    public init(name: String, age: Int64) {
        this.name = name
        this.age = age
    }

    public func serialize(): DataModel {
        return DataModelStruct().add(field<String>("name", name)).add(field<Int64>("age", age))
    }

    public static func deserialize(dm: DataModel): Person {
        let dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        let result = Person(String.deserialize(dms.get("name")), Int64.deserialize(dms.get("age")))
        return result
    }

    public operator func ==(other: Person): Bool {
        if (this.name != other.name) {
            return false
        }
        if (this.age != other.age) {
            return false
        }
        return true
    }

    public operator func !=(other: Person): Bool {
        if (this.name != other.name) {
            return true
        }
        if (this.age != other.age) {
            return true
        }
        return false
    }

    public func toString(): String {
        return "name: ${name}, age: ${age}"
    }
}
