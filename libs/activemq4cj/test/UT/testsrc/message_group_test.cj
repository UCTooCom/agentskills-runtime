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
public class MessageGroupTest {
    @TestCase
    public func testGroupedMessagesDeliveredToOnlyOneConsumer(): Unit {
        let destination = ActiveMQQueue("TEST.MESSAGEGROUP");

        try (connection = TestUtils.createConnection()) {
            // Setup a first connection
            connection.start()
            try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
                let consumer1 = session.createConsumer(destination)
                let producer = session.createProducer(destination)
                // Send the messages.
                for (i in 0..4) {
                    var message = session.createTextMessage("message ${i}")
                    message.setStringProperty("JMSXGroupID", "TEST-GROUP")
                    message.setInt32Property("JMSXGroupSeq", Int32(i + 1));
                    producer.send(message)
                }

                // All the messages should have been sent down connection 1.. just get
                // the first 3
                for (i in 0..3) {
                    var m1 = consumer1.receive(Duration.millisecond * 500)
                    @Assert(m1.isSome())
                    if (let Some(textMessage) <- m1) {
                        @Assert(textMessage.getInt32Property("JMSXGroupSeq"), Int32(i + 1))
                    }
                }

                consumer1.close()
            }

            // Setup a second connection
            try (connection1 = TestUtils.createConnection()) {
                connection1.start();
                try (session2 = connection1.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
                    let consumer2 = session2.createConsumer(destination)

                    // The last messages should now go the the second consumer.
                    for (i in 0..1) {
                        var m1 = consumer2.receive(Duration.millisecond * 500)
                        @Assert(m1.isSome())
                        if (let Some(textMessage) <- m1) {
                            @Assert(textMessage.getInt32Property("JMSXGroupSeq"), Int32(i + 4))
                        }
                    }

                    //assert that there are no other messages left for the consumer 2
                    @Assert(consumer2.receive(Duration.millisecond *100).isNone())
                    consumer2.close()
                }
            }
        }
    }

    @TestCase
    public func testClosingMessageGroup() : Unit{
        let destination = ActiveMQQueue("TEST.MESSAGEGROUP.CLOSE")

        try (connection = TestUtils.createConnection()) {
            // Setup a first connection
            connection.start()

            try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
                let consumer1 = session.createConsumer(destination)
                let producer = session.createProducer(destination)

                // Send the messages.
                for (i in 0..4) {     	
                    var message = session.createTextMessage("message ${i}")
                    message.setStringProperty("JMSXGroupID", "TEST-GROUP");
                    producer.send(message)
                }

                // All the messages should have been sent down consumer1.. just get
                // the first 3
                for (i in 0..3) {
                    var m1 = consumer1.receive(Duration.millisecond * 500)
                    @Assert(m1.isSome())
                }

                // Setup a second consumer
                try (connection1 = TestUtils.createConnection()) {
                    connection1.start()
                    try (session2 = connection1.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
                        let consumer2 = session2.createConsumer(destination)

                        //assert that there are no messages for the consumer 2
                        var m = consumer2.receive(Duration.millisecond * 100)
                        @Assert(m.isNone())

                        // Close the group
                        var message = session.createTextMessage("message 5")
                        message.setStringProperty("JMSXGroupID", "TEST-GROUP")
                        message.setInt32Property("JMSXGroupSeq", -1)
                        producer.send(message)

                        //Send some more messages
                        for (i in 0..4) {     	
                            message = session.createTextMessage("message ${i}")
                            message.setStringProperty("JMSXGroupID", "TEST-GROUP")
                            producer.send(message)
                        }

                         // Receive the fourth message
                        var m1 = consumer1.receive(Duration.millisecond * 500)
                        @Assert(m1.isSome())
                        
                        // Receive the closing message
                        m1 = consumer1.receive(Duration.millisecond * 500)
                        @Assert(m1.isSome())
                        
                        //assert that there are no messages for the consumer 1
                        m = consumer1.receive(Duration.millisecond * 100)
                        @Assert(m.isNone())

                        // The messages should now go to the second consumer.
                        for (i in 0..4) {
                            m1 = consumer2.receive(Duration.millisecond * 500)
                            @Assert(m1.isSome())
                        }
                    }
                }
            }
        }
    }
}
