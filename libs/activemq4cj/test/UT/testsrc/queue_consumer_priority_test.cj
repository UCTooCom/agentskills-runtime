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
public class QueueConsumerPriorityTest {
    protected static let DESTINATION_NAME = "TEST.QueueConsumerPriority"
    protected static let TEST_CLIENT_ID = "QueueConsumerPriorityTestClientId"
    protected static let MSG_COUNT = 50

    @TestCase
    public func QueueConsumerPriorityTest(): Unit {
        try (conn = createConnection()) {
            conn.start()

            let session = conn.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            let queue = session.createQueue(DESTINATION_NAME)
            TestUtils.purgeQueue(conn, queue)

            var consumer = session.createConsumer(queue)

            let fut1 = sendMessage(session, queue, 7)
            let fut2 = sendMessage(session, queue, 2)

            fut1.get()
            fut2.get()

            for (i in 0..MSG_COUNT * 2) {
                let msg = consumer.receive(Duration.millisecond * 1000)
                @Assert(msg.isSome())

                let priority = msg.getOrThrow().getCJMSPriority()
                if (i < MSG_COUNT) {
                    @Assert(priority, 7)
                } else {
                    @Assert(priority, 2)
                }
            }
        }
    }

    private func sendMessage(session: Session, queue: Destination, priority: Int32): Future<Unit> {
        let producer = session.createProducer(queue)
        producer.priority = priority
        let fut = spawn {
            => for (i in 0..MSG_COUNT) {
                producer.send(session.createTextMessage("Message ${i}, Priority = ${priority}"))
            }
        }
        return fut
    }

    private func createConnection(): Connection {
        var conn = TestUtils.createConnection()
        if (let Some(activemqConn) <- (conn as ActiveMQConnection)) {
            activemqConn.setClientID(TEST_CLIENT_ID)
            activemqConn.messagePrioritySupported = true
        }
        return conn
    }
}
