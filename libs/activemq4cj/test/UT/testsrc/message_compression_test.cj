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
public class MessageCompressionTest {
    private let brokerURL = TestUtils.getBrokerURL()
    private let queue = ActiveMQQueue("TEST.MESSAGE.COMPRESSION")

    private static let TEXT = """
    The quick red fox jumped over the lazy brown dog.
    The quick red fox jumped over the lazy brown dog. The quick red fox jumped over the lazy brown dog.
    The quick red fox jumped over the lazy brown dog. The quick red fox jumped over the lazy brown dog.
    The quick red fox jumped over the lazy brown dog. The quick red fox jumped over the lazy brown dog.
    The quick red fox jumped over the lazy brown dog. The quick red fox jumped over the lazy brown dog.
    The quick red fox jumped over the lazy brown dog. The quick red fox jumped over the lazy brown dog.
    The quick red fox jumped over the lazy brown dog. The quick red fox jumped over the lazy brown dog.
    The quick red fox jumped over the lazy brown dog. The quick red fox jumped over the lazy brown dog.
"""
    @TestCase
    public func testTextMessageCompression() {
        var factory = ActiveMQConnectionFactory(brokerURL)
        factory.useCompression = true
        sendTestMessage(factory, TEXT)
        var message = receiveTextMessage(factory).getOrThrow()
        var compressedSize = message.content.getOrThrow().size

        factory = ActiveMQConnectionFactory(brokerURL)
        factory.useCompression = false
        sendTestMessage(factory, TEXT)
        message = receiveTextMessage(factory).getOrThrow()
        var unCompressedSize = message.content.getOrThrow().size

        @Assert(compressedSize < unCompressedSize)
    }

    @TestCase
    public func testBytesMessageCompression() {
        var factory = ActiveMQConnectionFactory(brokerURL)
        factory.useCompression = true
        sendTestBytesMessage(factory, TEXT)
        var message = receiveTestBytesMessage(factory).getOrThrow()
        var compressedSize = message.content.getOrThrow().size
        var bytes = Array<Byte>(TEXT.size, repeat: 0)
        message.readBytes(bytes)

        var rcvString = String.fromUtf8(bytes)
        @Assert(rcvString, TEXT)
        @Assert(message.compressed)

        factory = ActiveMQConnectionFactory(brokerURL)
        factory.useCompression = false
        sendTestBytesMessage(factory, TEXT)
        message = receiveTestBytesMessage(factory).getOrThrow()
        var unCompressedSize = message.content.getOrThrow().size

        @Assert(compressedSize < unCompressedSize)
    }

    private func sendTestMessage(factory: ActiveMQConnectionFactory, message: String) {
        try (connection = factory.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var producer: MessageProducer = session.createProducer(queue)
            producer.send(session.createTextMessage(message))
        }
    }

    private func receiveTextMessage(factory: ActiveMQConnectionFactory): ?ActiveMQTextMessage {
        var msg: ?CJMSMessage = None
        try (connection = factory.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var consumer = session.createConsumer(queue)
            msg = consumer.receive()
        }
        if (msg.isNone()) {
            return None
        }

        return msg.getOrThrow() as ActiveMQTextMessage
    }

    private func sendTestBytesMessage(factory: ActiveMQConnectionFactory, message: String) {
        try (connection = factory.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var producer: MessageProducer = session.createProducer(queue)
            var bytesMessage = session.createBytesMessage(message.toArray())
            producer.send(bytesMessage)
        }
    }

    private func receiveTestBytesMessage(factory: ActiveMQConnectionFactory): ?ActiveMQBytesMessage {
        var msg: ?CJMSMessage = None
        try (connection = factory.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var consumer = session.createConsumer(queue)
            msg = consumer.receive()
        }

        if (msg.isNone()) {
            return None
        }
        return msg.getOrThrow() as ActiveMQBytesMessage
    }
}
