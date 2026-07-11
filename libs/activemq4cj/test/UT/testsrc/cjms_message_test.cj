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
public class CJMSMessageTest {
    private var connection: ?ActiveMQConnection = None
    private let counter: AtomicInt64 = AtomicInt64(0)

    @BeforeAll
    protected func beforeAll(): Unit {
        connection = TestUtils.getConnection() as ActiveMQConnection
    }

    @TestCase
    public func testTextMessage(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        let textMessage = session.createTextMessage()
        textMessage.text = "hello, Cangjie"
        producer.send(textMessage)

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(textMessage) <- (message as TextMessage)) {
                @Assert("hello, Cangjie", textMessage.text)
            }
        }
    }

    @TestCase
    public func testBytesMessage(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        let b: Array<Byte> = [1, 2, 3, 3, 2, 1]

        let bytesMessage = session.createBytesMessage()
        bytesMessage.writeBool(false)
        bytesMessage.writeByte(8)
        bytesMessage.writeInt16(16)
        bytesMessage.writeUInt16(UInt16(17))
        bytesMessage.writeChar(r'A')
        bytesMessage.writeInt32(32)
        bytesMessage.writeUInt32(UInt32(33))
        bytesMessage.writeInt64(64)
        bytesMessage.writeUInt64(UInt64(65))
        bytesMessage.writeFloat32(3.2)
        bytesMessage.writeFloat64(6.4)
        bytesMessage.writeString("Cangjie")
        bytesMessage.writeBytes(b)
        producer.send(bytesMessage)

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(bytesMessage) <- (message as BytesMessage)) {
                @Assert(false, bytesMessage.readBool())
                @Assert(8, bytesMessage.readByte())
                @Assert(16, bytesMessage.readInt16())
                @Assert(UInt16(17), bytesMessage.readUInt16())
                @Assert(r'A', bytesMessage.readChar())
                @Assert(32, bytesMessage.readInt32())
                @Assert(UInt32(33), bytesMessage.readUInt32())
                @Assert(64, bytesMessage.readInt64())
                @Assert(UInt64(65), bytesMessage.readUInt64())
                @Assert(3.2, bytesMessage.readFloat32())
                @Assert(6.4, bytesMessage.readFloat64())
                @Assert("Cangjie", bytesMessage.readString())
                let c = Array<Byte>(b.size, repeat: 0)
                bytesMessage.readBytes(c)
                @Assert(b, c)
            }
        }
    }

    @TestCase
    public func testBytesMessageBodyLength(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        let bytesMessage = session.createBytesMessage()
        bytesMessage.writeInt32(32)
        bytesMessage.writeInt32(32)
        bytesMessage.writeInt32(32)
        bytesMessage.writeInt32(32)

        producer.send(bytesMessage)

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(bytesMessage) <- (message as BytesMessage)) {
                @Assert(16, bytesMessage.getBodyLength())
            }
        }
    }

    @TestCase
    public func testBlobMessage(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        if (let Some(session) <- (session as ActiveMQSession)) {
            let blobMessage = session.createBlobMessage()
            if (let Some(message) <- (blobMessage as ActiveMQBlobMessage)) {
                message.remoteBlobUrl = "http://foo.bar.com"
            }
            producer.send(blobMessage)
        }

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(blobMessage) <- (message as BlobMessage)) {
                let url = blobMessage.getURL()
                @Assert(url.isSome())
                if (let Some(url) <- url) {
                    @Assert("http://foo.bar.com", url.toString())
                }
            }
        }
    }

    @TestCase
    public func testObjectMessage(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        let objectMessage = session.createObjectMessage()
        let p1 = Person("jack", 21)
        objectMessage.object = p1.serialize()

        producer.send(objectMessage)

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(objectMessage) <- (message as ObjectMessage)) {
                let dm = objectMessage.object
                @Assert(dm.isSome())
                if (let Some(dm) <- dm) {
                    let p2 = Person.deserialize(dm)
                    @Assert(p1, p2)
                }
            }
        }
    }

    @TestCase
    public func testStreamMessage(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        let b: Array<Byte> = [1, 2, 3, 3, 2, 1]

        let streamMessage = session.createStreamMessage()
        streamMessage.writeBool(false)
        streamMessage.writeByte(8)
        streamMessage.writeInt16(16)
        streamMessage.writeUInt16(UInt16(17))
        streamMessage.writeChar(r'A')
        streamMessage.writeInt32(32)
        streamMessage.writeUInt32(UInt32(33))
        streamMessage.writeInt64(64)
        streamMessage.writeUInt64(UInt64(65))
        streamMessage.writeFloat32(3.2)
        streamMessage.writeFloat64(6.4)
        streamMessage.writeString("Cangjie")
        streamMessage.writeBytes(b)
        producer.send(streamMessage)

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(streamMessage) <- (message as StreamMessage)) {
                @Assert(false, streamMessage.readBool())
                @Assert(8, streamMessage.readByte())
                @Assert(16, streamMessage.readInt16())
                @Assert(UInt16(17), streamMessage.readUInt16())
                @Assert(r'A', streamMessage.readChar())
                @Assert(32, streamMessage.readInt32())
                @Assert(UInt32(33), streamMessage.readUInt32())
                @Assert(64, streamMessage.readInt64())
                @Assert(UInt64(65), streamMessage.readUInt64())
                @Assert(3.2, streamMessage.readFloat32())
                @Assert(6.4, streamMessage.readFloat64())
                @Assert("Cangjie", streamMessage.readString())
                let c = Array<Byte>(b.size, repeat: 0)
                streamMessage.readBytes(c)
                @Assert(b, c)
            }
        }
    }

    @TestCase
    public func testMapMessage(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        let b: Array<Byte> = [1, 2, 3, 3, 2, 1]

        let mapMessage = session.createMapMessage()
        mapMessage.setBool("flag", true)
        mapMessage.setByte("byte", 12)
        mapMessage.setInt8("i8", 8)
        mapMessage.setInt16("i16", Int16(16))
        mapMessage.setUInt16("u16", UInt16(17))
        mapMessage.setChar("char", r'汉')
        mapMessage.setInt32("i32", 32)
        mapMessage.setUInt32("u32", UInt32(33))
        mapMessage.setInt64("i64", 64)
        mapMessage.setUInt64("u64", UInt64(65))
        mapMessage.setFloat32("f32", 3.2)
        mapMessage.setFloat64("f64", 6.4)
        mapMessage.setString("s", "Cangjie")
        mapMessage.setBytes("bytes", b)
        producer.send(mapMessage)

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(mapMessage) <- (message as MapMessage)) {
                @Assert(true, mapMessage.getBool("flag"))
                @Assert(12, mapMessage.getByte("byte"))
                @Assert(8, mapMessage.getInt8("i8"))
                @Assert(16, mapMessage.getInt16("i16"))
                @Assert(UInt16(17), mapMessage.getUInt16("u16"))
                @Assert(r'汉', mapMessage.getChar("char"))
                @Assert(32, mapMessage.getInt32("i32"))
                @Assert(33, mapMessage.getUInt32("u32"))
                @Assert(64, mapMessage.getInt64("i64"))
                @Assert(65, mapMessage.getUInt64("u64"))
                @Assert(3.2, mapMessage.getFloat32("f32"))
                @Assert(6.4, mapMessage.getFloat64("f64"))
                @Assert("Cangjie", mapMessage.getString("s"))
                @Assert(Some(b), mapMessage.getBytes("bytes"))
            }
        }
    }

    @TestCase
    public func testMessageProperties(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let destination = createDestination(session)

        let consumer = session.createConsumer(destination)
        let producer = session.createProducer(destination)

        let b: Array<Byte> = [1, 2, 3, 3, 2, 1]

        let cjmsMessage = session.createMessage()
        cjmsMessage.setBoolProperty("b", false)
        cjmsMessage.setByteProperty("byte", 9)
        cjmsMessage.setInt16Property("i16", 16)
        cjmsMessage.setInt32Property("i32", 32)
        cjmsMessage.setInt64Property("i64", 64)
        cjmsMessage.setFloat32Property("f32", 3.2)
        cjmsMessage.setFloat64Property("f64", 6.4)
        cjmsMessage.setStringProperty("s", "luobo")
        producer.send(cjmsMessage)

        let message = consumer.receive()
        @Assert(message.isSome())

        if (let Some(message) <- message) {
            if (let Some(msg) <- (message as CJMSMessage)) {
                @Assert(false, msg.getBoolProperty("b"))
                @Assert(9, msg.getByteProperty("byte"))
                @Assert(16, msg.getInt16Property("i16"))
                @Assert(32, msg.getInt32Property("i32"))
                @Assert(64, msg.getInt64Property("i64"))
                @Assert(3.2, msg.getFloat32Property("f32"))
                @Assert(6.4, msg.getFloat64Property("f64"))
                @Assert("luobo", msg.getStringProperty("s"))
                @Assert("false", msg.getStringProperty("b"))
                @Assert("9", msg.getStringProperty("byte"))
                @Assert("16", msg.getStringProperty("i16"))
                @Assert("32", msg.getStringProperty("i32"))
                @Assert("64", msg.getStringProperty("i64"))
                @Assert(Float32(3.2).toString(), msg.getStringProperty("f32"))
                @Assert(Float64(6.4).toString(), msg.getStringProperty("f64"))
            }
        }
    }

    @TestCase
    public func testMessageHeaders(): Unit {
        let connection = connection.getOrThrow()
        connection.start()
        let session = connection.createSession()
        let cjmsMessage = session.createMessage()

        cjmsMessage.setCJMSCorrelationID("1")
        @Assert(Some("1"), cjmsMessage.getCJMSCorrelationID())

        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        cjmsMessage.setCJMSTimestamp(timestamp)
        @Assert(timestamp, timestamp)

        let destination = ActiveMQDestination.transform(createDestination(session))
        cjmsMessage.setCJMSReplyTo(destination)
        let replyTo = cjmsMessage.getCJMSReplyTo()
        @Assert(replyTo.isSome())
        if (let Some(replyToVal) <- replyTo) {
            @Assert(Option<ActiveMQDestination>.Some(destination), ActiveMQDestination.transform(replyToVal))
        }

        cjmsMessage.setCJMSDeliveryMode(DeliveryMode.PERSISTENT)
        @Assert(DeliveryMode.PERSISTENT.value(), cjmsMessage.getCJMSDeliveryMode().value())

        cjmsMessage.setCJMSPriority(7)
        @Assert(7, cjmsMessage.getCJMSPriority())

        cjmsMessage.setCJMSType("PRO")
        @Assert(Some("PRO"), cjmsMessage.getCJMSType())
    }

    private func createDestination(session: Session): Destination {
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        return session.createQueue("TEST.${timestamp}.${counter.fetchAdd(1)}")
    }
}
