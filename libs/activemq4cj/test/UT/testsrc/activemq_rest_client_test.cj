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
public class ActiveMQRestClientTest {
    private let restClient: ActiveMQRESTMessagingClient = ActiveMQRESTMessagingClient("admin", "admin",
        "http://${TestUtils.getHost()}:8161/api/message")

    @TestCase
    public func testSend() {
        let queue: Destination = ActiveMQQueue("TEST.REST.SEND")
        for (i in 0..10) {
            restClient.send(queue, "RestMessage${i}")
        }
    }

    @TestCase
    public func testReceive() {
        let queue: Destination = ActiveMQQueue("TEST.REST.RECEIVE")

        try (connection = TestUtils.createConnection()) {
            connection.start()
            var session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            TestUtils.purgeQueue(connection, queue)
        }

        for (i in 0..10) {
            restClient.send(queue, "RestMessage${i}")
        }

        for (i in 0..10) {
            var rc = restClient.receive<String>(queue)
            @Assert(rc, "RestMessage${i}")
        }
    }

    @TestCase
    public func testReceiveBySelector() {
        let queue: Destination = ActiveMQQueue("TEST.REST.SELECTOR")

        try (connection = TestUtils.createConnection()) {
            connection.start()
            try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
                TestUtils.purgeQueue(connection, queue)

                try (producer = session.createProducer(queue)) {
                    var message = session.createTextMessage("1st")
                    message.setStringProperty("color", "red")
                    producer.send(message)

                    message = session.createTextMessage("2nd")
                    message.setStringProperty("color", "red")
                    producer.send(message)

                    message = session.createTextMessage("3rd")
                    message.setStringProperty("color", "blue")
                    producer.send(message)
                }
            }
        }
        var rc = restClient.receive<String>(queue, selector: "color='blue'")
        @Assert(rc, Some("3rd"))
    }

    @AfterAll
    public func afterAll() {
        restClient.close()
    }
}
