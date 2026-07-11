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
public class CJMSQueueBrowserTest {
    @TestCase
    public func testBrowsingExpiration() {
        try (browserConnection = TestUtils.createConnection()) {
            browserConnection.start()

            let messageToSend = 50
            let queue: Queue = ActiveMQQueue("BROWSER_TEST")
            sendMessages(browserConnection, messageToSend, queue)

            var session = browserConnection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

            var browser = session.createBrowser(queue)
            var browsed = browse(browser)
            //验证browse数量为发送数量
            @Assert(messageToSend, browsed)
            //让消息全部过期
            sleep(Duration.millisecond * 5000)
            browser = session.createBrowser(queue)
            browsed = browse(browser)
            @Assert(0, browsed)
        }
    }

    private func sendMessages(connection: Connection, count: Int64, dest: Destination): Unit {
        var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
        var producer = session.createProducer(dest)
        producer.timeToLive = 5000
        for (i in 0..count) {
            producer.send(session.createTextMessage(i.toString()))
        }
        producer.close()
        session.close()
    }

    private func browse(browser: QueueBrowser): Int64 {
        let iterator = browser.iterator()

        var browsed = 0
        while (let Some(message) <- iterator.next()) {
            browsed++
        }
        browser.close()
        return browsed
    }

    @TestCase
    public func testReceiveBrowseReceive() {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            let session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let queue = session.createQueue("testReceiveBrowseReceive")

            TestUtils.purgeQueue(connection, queue)

            let producer = session.createProducer(queue)
            var messages = [session.createTextMessage("first"), session.createTextMessage("second"),
                session.createTextMessage("third")]
            for (msg in messages) {
                producer.send(msg)
            }
            //先消费一条消息
            var consumer = session.createConsumer(queue)
            var msg1 = consumer.receive(Duration.second)
            @Assert(msg1.isSome())
            if (let Some(msg) <- msg1) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, messages[0].text)
                }
            }
            //查看队列中剩余的消息
            var browser = session.createBrowser(queue)
            let iterator = browser.iterator()
            if (let Some(msg) <- iterator.next()) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, messages[1].text)
                }
            }

            if (let Some(msg) <- iterator.next()) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, messages[2].text)
                }
            }
            //继续消费消息
            var msg2 = consumer.receive(Duration.second)
            @Assert(msg2.isSome())
            if (let Some(msg) <- msg2) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, messages[1].text)
                }
            }

            var msg3 = consumer.receive(Duration.second)
            @Assert(msg3.isSome())
            if (let Some(msg) <- msg3) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, messages[2].text)
                }
            }
        }
    }

    @TestCase
    public func testBatchSendBrowseReceive() {
        try (connection = TestUtils.createConnection()) {
            connection.start()
            let session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let queue = session.createQueue("testBatchSendBrowseReceive${DateTime.now()}")
            let producer = session.createProducer(queue)

            var messagesCount = 10
            var messages = Array<TextMessage>(10, {index: Int64 => session.createTextMessage(index.toString())})
            for (msg in messages) {
                producer.send(msg)
            }
            //查看队列中的消息
            var browser = session.createBrowser(queue)
            let iterator = browser.iterator()
            for (i in 0..messagesCount) {
                if (let Some(msg) <- iterator.next()) {
                    if (let Some(textMsg) <- (msg as TextMessage)) {
                        @Assert(textMsg.text, messages[i].text)
                    }
                }
            }

            //消费消息
            var consumer = session.createConsumer(queue)
            for (i in 0..messagesCount) {
                var msg = consumer.receive(Duration.second)
                @Assert(msg.isSome())
                if (let Some(msg) <- msg) {
                    if (let Some(textMsg) <- (msg as TextMessage)) {
                        @Assert(textMsg.text, messages[i].text)
                    }
                }
            }
        }
    }

    @TestCase
    public func testLargeNumberOfMessages(): Unit {
        try (connection = TestUtils.createConnection()) {
            if (let Some(activemqConnection) <- (connection as ActiveMQConnection)) {
                activemqConnection.optimizeAcknowledge = true
            }

            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = session.createQueue("testLargeNumberOfMessages?consumer.prefetchSize=1000")
            connection.start()

            TestUtils.purgeQueue(connection, destination)

            var producer = session.createProducer(destination)

            var numberOfMessages = 2000
            for (i in 0..numberOfMessages) {
                producer.send(session.createTextMessage("Message: ${i}"))
            }

            var browser = session.createBrowser(destination)
            var numberBrowsed = browse(browser)

            @Assert(numberOfMessages, numberBrowsed)
            browser.close()
            producer.close()
        }
    }

    @TestCase
    public func testQueueBrowserWith2Consumers(): Unit {
        try (connection = TestUtils.createConnection()) {
            if (let Some(activemqConnection) <- (connection as ActiveMQConnection)) {
                activemqConnection.alwaysSessionAsync = false
            }

            let numMessages: Int64 = 100

            var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testQueueBrowserWith2Consumers")
            var destinationPrefetch10 = ActiveMQQueue("testQueueBrowserWith2Consumers?consumer.prefetchSize=10")
            var destinationPrefetch1 = ActiveMQQueue("testQueueBrowserWith2Consumers?consumer.prefetchSize=1")
            connection.start()

            TestUtils.purgeQueue(connection, destination)
            TestUtils.purgeQueue(connection, destinationPrefetch10)

            try (connection2 = TestUtils.createConnection()) {
                connection2.start()

                var session2 = connection2.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)

                var producer = session.createProducer(destination)
                var consumer = session.createConsumer(destinationPrefetch10)

                for (i in 0..numMessages) {
                    producer.send(session.createTextMessage("Message: ${i}"))
                }

                var browser = session2.createBrowser(destinationPrefetch1)

                var iterator = browser.iterator()

                var messages = ArrayList<?CJMSMessage>()
                for (i in 0..numMessages) {
                    var m1 = consumer.receive(Duration.millisecond * 5000)
                    @Assert(m1.isSome())
                    messages.add(m1)
                }

                var j = 0
                for (i in 0..numMessages) {
                    var m1 = messages[i]
                    var m2 = iterator.next()
                    @Assert(m2.isSome())
                    @Assert(m1.getOrThrow().getCJMSMessageID(), m2.getOrThrow().getCJMSMessageID())
                    j++
                }

                @Assert(j > 50)
                @Assert( consumer.receiveNoWait().isNone())
            }
        }
    }

    @TestCase
    public func testBrowseClose(): Unit {
        try (connection = TestUtils.createConnection()) {
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            var destination = ActiveMQQueue("testBrowseClose")

            connection.start()

            var outbound = [
                session.createTextMessage("First Message"),
                session.createTextMessage("Second Message"),
                session.createTextMessage("Third Message")
            ]

            var consumer = session.createConsumer(destination)
            // 清空以前残留的消息
            while (consumer.receive(Duration.millisecond * 1000).isSome()) {
            }

            var producer = session.createProducer(destination)
            producer.send(outbound[0])
            producer.send(outbound[1])
            producer.send(outbound[2])

            var browser = session.createBrowser(destination)
            var iterator = browser.iterator()

            @Assert(outbound[0].getCJMSMessageID(), iterator.next().getOrThrow().getCJMSMessageID())
            @Assert(outbound[1].getCJMSMessageID(), iterator.next().getOrThrow().getCJMSMessageID())

            browser.close()

            var message: ?CJMSMessage = consumer.receive(Duration.millisecond * 1000)
            if (let Some(msg) <- message) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, outbound[0].text)
                }
            }

            message = consumer.receive(Duration.millisecond * 1000)
            if (let Some(msg) <- message) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, outbound[1].text)
                }
            }

            message = consumer.receive(Duration.millisecond * 1000)
            if (let Some(msg) <- message) {
                if (let Some(textMsg) <- (msg as TextMessage)) {
                    @Assert(textMsg.text, outbound[2].text)
                }
            }

            consumer.close()
            producer.close()
        }
    }
}
