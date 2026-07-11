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
public class CJMSProducerTest {
    @TestCase
    public func testSendTextMessage(): Unit {
        let factory = ActiveMQConnectionFactory(TestUtils.getBrokerURL())
        var text = "foo"
        let destination = ActiveMQQueue("testCJMSProducerSend")

        try (context = factory.createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            let producer = context.createProducer()
            producer.send(destination, text)
        }

        try (connection = factory.createConnection()) {
            connection.start()
            try (session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
                try (consumer = session.createConsumer(destination)) {
                    let message = consumer.receive(Duration.millisecond * 1000)
                    if (let Some(message) <- message) {
                        if (let Some(textMessage) <- (message as TextMessage)) {
                            @Assert(textMessage.text == Some(text))
                        }
                    }
                }
            }
        }
    }

    @TestCase
    public func testSendBytesMessage(): Unit {
        let factory = ActiveMQConnectionFactory(TestUtils.getBrokerURL())

        let destination = ActiveMQQueue("testCJMSProducerSend")
        var s = "foo"

        try (context = factory.createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            let producer = context.createProducer()
            producer.send(destination, s.toArray())
        }

        try (connection = factory.createConnection()) {
            let session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let consumer = session.createConsumer(destination)

            connection.start()
            let message = consumer.receive(Duration.millisecond * 1000)
            if (let Some(message) <- message) {
                if (let Some(bytesMessage) <- (message as BytesMessage)) {
                    var array = Array<Byte>(s.size, repeat: 0)
                    bytesMessage.readBytes(array)
                    @Assert(String.fromUtf8(array), s)
                }
            }
        }
    }

    @TestCase
    public func testSendObjectMessage(): Unit {
        let factory = ActiveMQConnectionFactory(TestUtils.getBrokerURL())
        let destination = ActiveMQQueue("testCJMSProducerSend")

        try (context = factory.createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            let producer = context.createProducer()

            var p: Serializable<Any> = Person("jack", 18)
            producer.send(destination, p)
        }

        try (connection = factory.createConnection()) {
            let session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let consumer = session.createConsumer(destination)

            connection.start()
            let message = consumer.receive(Duration.millisecond * 1000)
            if (let Some(message) <- message) {
                if (let Some(objectMessage) <- (message as ObjectMessage)) {
                    if (let Some(dm) <- objectMessage.object) {
                        @Assert(Person.deserialize(dm) is Person)
                    } else {
                        @Assert(false)
                    }
                }
            }
        }
    }

    @TestCase
    public func testReplyTo(): Unit {
        let factory = ActiveMQConnectionFactory(TestUtils.getBrokerURL())

        let destination = ActiveMQQueue("testCJMSProducerSend")
        let replyTo = ActiveMQQueue("testReplyTo")

        var context = factory.createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)
        var producer = context.createProducer()
        producer.setCJMSReplyTo(replyTo)
        producer.setCJMSCorrelationID("correlationId")
        producer.setCJMSType("groupA")
        producer.setDisableMessageTimestamp(true)
        producer.setTimeToLive(100000)

        var map: HashMap<String, Any> = HashMap<String, Any>()
        map.add("foo", "bar")
        producer.send(destination, map)

        try (connection = factory.createConnection()) {
            let session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let consumer = session.createConsumer(destination)

            connection.start()
            let message = consumer.receive(Duration.millisecond * 1000)
            if (let Some(message) <- message) {
                if (let Some(mapMessage) <- (message as MapMessage)) {
                    if (let Some(queue) <- (mapMessage.getCJMSReplyTo().getOrThrow() as Queue)) {
                        @Assert(queue.getQueueName(), replyTo.name)
                    } else {
                        @Assert(false)
                    }
                    @Assert(producer.getCJMSCorrelationID(), Some("correlationId"))
                    @Assert(producer.getCJMSType(), Some("groupA"))
                    @Assert(mapMessage.getString("foo"), "bar")
                }
            }
        } finally {
            context.close()
        }
    }

    @TestCase
    public func testSetGetProperty(): Unit {
        let factory = ActiveMQConnectionFactory(TestUtils.getBrokerURL())

        let destination = ActiveMQQueue("testCJMSProducerSend")

        try (context = factory.createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            let producer = context.createProducer()

            producer.setProperty("boolProperty", true)
            producer.setProperty("byteProperty", UInt8(3))
            producer.setProperty("int16Property", Int16(16))
            producer.setProperty("int32Property", Int32(32))
            producer.setProperty("int64Property", Int64(64))
            producer.setProperty("stringProperty", "true")
            producer.setProperty("float32Property", Float32(3.2))
            producer.setProperty("float64Property", Float64(6.4))

            @Assert(producer.propertyExists("float64Property"))
            @Assert(producer.propertyExists("int16Property"))

            @Assert(producer.getBoolProperty("boolProperty"), true)
            @Assert(producer.getByteProperty("byteProperty"), UInt8(3))
            @Assert(producer.getInt16Property("int16Property"), Int16(16))
            @Assert(producer.getInt16Property("byteProperty"), Int16(3))
            @Assert(producer.getInt32Property("int32Property"), Int32(32))
            @Assert(producer.getInt64Property("int64Property"), Int64(64))
            @Assert(producer.getInt64Property("byteProperty"), Int64(3))
            @Assert(producer.getStringProperty("stringProperty"), "true")
            @Assert(producer.getBoolProperty("stringProperty"), true)
            @Assert(producer.getFloat32Property("float32Property"), Float32(3.2))
            @Assert(producer.getFloat64Property("float64Property"), Float64(6.4))
            @Assert(producer.getFloat64Property("float32Property"), Float64(Float32(3.2)))
            @Assert(producer.getStringProperty("float32Property"), Float32(3.2).toString())

            producer.send(destination, "TEST")
        }

        try (connection = factory.createConnection()) {
            let session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let consumer = session.createConsumer(destination)

            connection.start()
            let message = consumer.receive(Duration.millisecond * 1000)
            if (let Some(message) <- message) {
                @Assert(message.getBoolProperty("boolProperty"), true)
                @Assert(message.getByteProperty("byteProperty"), UInt8(3))
                @Assert(message.getInt16Property("int16Property"), Int16(16))
                @Assert(message.getInt16Property("byteProperty"), Int16(3))
                @Assert(message.getInt32Property("int32Property"), Int32(32))
                @Assert(message.getInt64Property("int64Property"), Int64(64))
                @Assert(message.getInt64Property("byteProperty"), Int64(3))
                @Assert(message.getStringProperty("stringProperty"), "true")
                @Assert(message.getBoolProperty("stringProperty"), true)
                @Assert(message.getFloat32Property("float32Property"), Float32(3.2))
                @Assert(message.getFloat64Property("float64Property"), Float64(6.4))
                @Assert(message.getFloat64Property("float32Property"), Float64(Float32(3.2)))
                @Assert(message.getStringProperty("float32Property"), Float32(3.2).toString())
            }
        }
    }
}
