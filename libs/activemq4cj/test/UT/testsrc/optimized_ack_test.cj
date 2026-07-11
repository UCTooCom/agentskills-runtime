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
public class OptimizedAckTest {
    private func createConnection(): Connection {
        var brokerURL = TestUtils.getBrokerURL()
        if (brokerURL.indexOf("?").isSome()) {
            brokerURL += "&jms.optimizeAcknowledge=true"
        } else {
            brokerURL += "?jms.optimizeAcknowledge=true"
        }

        var connectionFactory = ActiveMQConnectionFactory(brokerURL)
        var conn = connectionFactory.createConnection()
        if (let Some(activemqConn) <- (conn as ActiveMQConnection)) {
            activemqConn.optimizeAcknowledge = true
            activemqConn.optimizeAcknowledgeTimeOut = 0

            var prefetchPolicy = ActiveMQPrefetchPolicy()
            prefetchPolicy.setAll(10)
            activemqConn.prefetchPolicy = prefetchPolicy
        }
        return conn
    }

    @TestCase
    public func testOptimizedAckWithExpiredMsgs(): Unit {
        var connection = createConnection()
        var session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)
        var destination = session.createQueue("testOptimizedAckWithExpiredMsgs")
        var consumer = session.createConsumer(destination)
        var producer = session.createProducer(destination)
        producer.deliveryMode = DeliveryMode.NON_PERSISTENT

        var message: TextMessage

        // 生产很快过期的消息
        for (i in 0..45) {
            message = session.createTextMessage()
            producer.send(
                message,
                DeliveryMode.NON_PERSISTENT,
                Int32(4),
                200
            )
        }

        // 生产不会过期的消息
        for (i in 0..60) {
            message = session.createTextMessage()
            producer.send(
                message,
                DeliveryMode.NON_PERSISTENT,
                Int32(4),
                60000
            )
        }

        sleep(Duration.millisecond * 1000) // 让45条消息过期

        var counter: AtomicInt64 = AtomicInt64(0)
        consumer.messageListener = OptimizedAckMessageListener(counter)
        connection.start()

        for (i in 0..60) {
            if (counter.load() == 60) {
                break
            }
            sleep(Duration.millisecond * 1000)
        }

        @Assert(60, counter.load())

        // 清理
        producer.close()
        consumer.close()
        session.close()
        connection.close()
    }

    @TestCase
    public func testOptimizedAckWithExpiredMsgsSync() {
        var connection = createConnection()
        var session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)
        var destination = session.createQueue("testOptimizedAckWithExpiredMsgsSync")
        var consumer = session.createConsumer(destination)
        var producer = session.createProducer(destination)
        producer.deliveryMode = DeliveryMode.NON_PERSISTENT

        var message: TextMessage

        // 生产很快过期的消息
        for (i in 0..45) {
            message = session.createTextMessage()
            producer.send(
                message,
                DeliveryMode.NON_PERSISTENT,
                Int32(4),
                200
            )
        }

        for (i in 0..60) {
            message = session.createTextMessage()
            producer.send(
                message,
                DeliveryMode.NON_PERSISTENT,
                Int32(4),
                60000
            )
        }

        sleep(Duration.millisecond * 1000)
        connection.start()

        var counter = 0
        for (i in 0..60) {
            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())
            counter = i
        }

        @Assert(59, counter)
        @Assert(consumer.receive(Duration.millisecond * 1000).isNone())

        producer.close()
        consumer.close()
        session.close()
        connection.close()
    }

    @TestCase
    public func testOptimizedAckWithExpiredMsgsSync2() {
        var connection = createConnection()
        var session = connection.createSession(AcknowledgeMode.AUTO_ACKNOWLEDGE)
        var destination = session.createQueue("testOptimizedAckWithExpiredMsgsSync2")
        var consumer = session.createConsumer(destination)
        var producer = session.createProducer(destination)
        producer.deliveryMode = DeliveryMode.NON_PERSISTENT

        var message: TextMessage

        // 生产一批不会过期的消息
        for (i in 0..56) {
            message = session.createTextMessage()
            producer.send(
                message,
                DeliveryMode.NON_PERSISTENT,
                Int32(4),
                600000
            )
        }

        // 生产很快过期的消息
        for (i in 0..44) {
            message = session.createTextMessage()
            producer.send(
                message,
                DeliveryMode.NON_PERSISTENT,
                Int32(4),
                200
            )
        }

        // 生产一批不会过期的消息
        for (i in 0..4) {
            message = session.createTextMessage()
            producer.send(
                message,
                DeliveryMode.NON_PERSISTENT,
                Int32(4),
                600000
            )
        }

        sleep(Duration.millisecond * 1000)
        connection.start()

        var counter = 0
        for (i in 0..60) {
            @Assert(consumer.receive(Duration.millisecond * 1000).isSome())
            counter++
        }

        @Assert(60, counter)
        @Assert(consumer.receive(Duration.millisecond * 1000).isNone())

        producer.close()
        consumer.close()
        session.close()
        connection.close()
    }
}

class OptimizedAckMessageListener <: MessageListener {
    private var counter: AtomicInt64

    public init(counter: AtomicInt64) {
        this.counter = counter
    }

    public func onMessage(message: CJMSMessage): Unit {
        counter.fetchAdd(1)
    }
}
