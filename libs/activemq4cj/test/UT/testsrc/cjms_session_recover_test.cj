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
public class CJMSSessionRecoverTest {
    private var connection: ?ActiveMQConnection = None

    @BeforeAll
    public func beforeAll() {
        connection = TestUtils.createConnection() as ActiveMQConnection
    }

    @TestCase
    public func testQueueSynchRecover() {
        doTestSynchRecover(ActiveMQQueue("Queue-${DateTime.now()}"))
    }

    @TestCase
    public func testQueueAsynchRecover() {
        doTestAsynchRecover(ActiveMQQueue("Queue-${DateTime.now()}"))
    }

    @TestCase
    public func testTopicSynchRecover() {
        doTestSynchRecover(ActiveMQTopic("Topic-${DateTime.now()}"))
    }

    @TestCase
    public func testTopicAsynchRecover() {
        doTestAsynchRecover(ActiveMQTopic("Topic-${DateTime.now()}"))
    }

    @TestCase
    public func testQueueAsynchRecoverWithAutoAck() {
        doTestAsynchRecoverWithAutoAck(ActiveMQQueue("Queue-${DateTime.now()}"))
    }

    @TestCase
    public func testTopicAsynchRecoverWithAutoAck() {
        doTestAsynchRecoverWithAutoAck(ActiveMQTopic("Topic-${DateTime.now()}"))
    }

    private func doTestSynchRecover(dest: Destination): Unit {
        let connection = connection.getOrThrow()
        var session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
        var consumer = session.createConsumer(dest)
        connection.start()

        var producer = session.createProducer(dest)
        producer.deliveryMode = DeliveryMode.NON_PERSISTENT
        producer.send(session.createTextMessage("First"))
        producer.send(session.createTextMessage("Second"))

        var message = (consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage).getOrThrow()
        @Assert(Some("First"), message.text)
        @Assert(!message.getCJMSRedelivered())
        message.acknowledge()

        message = (consumer.receive(Duration.millisecond * 1000).getOrThrow() as TextMessage).getOrThrow()
        @Assert(Some("Second"), message.text)
        @Assert(!message.getCJMSRedelivered())

        session.recover()

        message = (consumer.receive(Duration.millisecond * 2000).getOrThrow() as TextMessage).getOrThrow()
        @Assert(Some("Second"), message.text)
        @Assert(message.getCJMSRedelivered())

        message.acknowledge()
    }

    private func doTestAsynchRecover(dest: Destination): Unit {
        let connection = connection.getOrThrow()
        let session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)
        let errorMessage: Array<String> = Array<String>(1, repeat: "")
        let doneCountDown = SyncCounter(1)

        var consumer = session.createConsumer(dest)

        var producer = session.createProducer(dest)
        producer.deliveryMode = DeliveryMode.NON_PERSISTENT
        producer.send(session.createTextMessage("First"))
        producer.send(session.createTextMessage("Second"))

        consumer.messageListener = AsyncRecoverMessageListener(doneCountDown, errorMessage, session)

        connection.start()
        doneCountDown.waitUntilZero(timeout: Duration.second * 5)
        if (doneCountDown.count == 0) {
            if (errorMessage[0] != "") {
                @Assert(false)
            }
        } else {
            @Assert(false)
        }
    }

    private func doTestAsynchRecoverWithAutoAck(dest: Destination) {
        let connection = connection.getOrThrow()
        let session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
        let errorMessage: Array<String> = Array<String>(1, repeat: "")
        let doneCountDown = SyncCounter(1)

        var consumer = session.createConsumer(dest)

        var producer = session.createProducer(dest)
        producer.deliveryMode = DeliveryMode.NON_PERSISTENT
        producer.send(session.createTextMessage("First"))
        producer.send(session.createTextMessage("Second"))

        consumer.messageListener = AsynchRecoverWithAutoAckMessageListener(doneCountDown, errorMessage, session)

        connection.start()
        doneCountDown.waitUntilZero(timeout: Duration.second * 5)
        if (doneCountDown.count == 0) {
            if (errorMessage[0] != "") {
                @Assert(false)
            }
        } else {
            @Assert(false)
        }
    }

    @AfterAll
    public func afterAll() {
        if (let Some(connection) <- connection) {
            connection.close()
        }
    }
}

class AsyncRecoverMessageListener <: MessageListener {
    var counter = 0

    private let doneCountDown: SyncCounter
    private let errorMessage: Array<String>
    private let session: Session

    public init(doneCountDown: SyncCounter, errorMessage: Array<String>, session: Session) {
        this.doneCountDown = doneCountDown
        this.errorMessage = errorMessage
        this.session = session
    }

    public func onMessage(message: CJMSMessage): Unit {
        counter++
        try {
            var textMessage = (message as TextMessage).getOrThrow()
            match (counter) {
                case 1 =>
                    @Assert(Some("First"), textMessage.text)
                    @Assert(!textMessage.getCJMSRedelivered())
                    textMessage.acknowledge()
                case 2 =>
                    @Assert(Some("Second"), textMessage.text)
                    @Assert(!textMessage.getCJMSRedelivered())
                    session.recover()
                case 3 =>
                    @Assert(Some("Second"), textMessage.text)
                    @Assert(textMessage.getCJMSRedelivered())
                    doneCountDown.dec()
                case _ =>
                    errorMessage[0] = "Got too many messages: ${counter}"
                    doneCountDown.dec()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            errorMessage[0] = "Got exception: ${e}"
            doneCountDown.dec()
        }
    }
}

class AsynchRecoverWithAutoAckMessageListener <: MessageListener {
    var counter = 0

    private let doneCountDown: SyncCounter
    private let errorMessage: Array<String>
    private let session: Session

    public init(doneCountDown: SyncCounter, errorMessage: Array<String>, session: Session) {
        this.doneCountDown = doneCountDown
        this.errorMessage = errorMessage
        this.session = session
    }

    public func onMessage(message: CJMSMessage): Unit {
        counter++
        try {
            var textMessage = (message as TextMessage).getOrThrow()
            match (counter) {
                case 1 =>
                    @Assert(Some("First"), textMessage.text)
                    @Assert(!textMessage.getCJMSRedelivered())
                    textMessage.acknowledge()
                case 2 =>
                    @Assert(Some("Second"), textMessage.text)
                    @Assert(!textMessage.getCJMSRedelivered())
                    session.recover()
                case 3 =>
                    @Assert(Some("Second"), textMessage.text)
                    @Assert(textMessage.getCJMSRedelivered())
                    textMessage.acknowledge()
                    doneCountDown.dec()
                case _ =>
                    errorMessage[0] = "Got too many messages: ${counter}"
                    doneCountDown.dec()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            errorMessage[0] = "Got exception: ${e}"
            doneCountDown.dec()
        }
    }
}
