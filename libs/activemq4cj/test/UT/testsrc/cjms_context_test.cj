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
public class CJMSContextTest {
    private let connectionFactory = ActiveMQConnectionFactory(TestUtils.getBrokerURL())

    @TestCase
    public func testConnectionFactoryCreateContext(): Unit {
        try (cjmsContext = connectionFactory.createContext()) {
            cjmsContext.start()
            @Assert(cjmsContext is ActiveMQContext)
            var destination: Destination = cjmsContext.createQueue("testConnectionFactoryCreateContext")
            sendMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContext")
            recvMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContext")
        }
    }

    @TestCase
    public func testConnectionFactoryCreateContextSession() {
        try (cjmsContext = connectionFactory.createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            cjmsContext.start()
            @Assert(cjmsContext is ActiveMQContext)
            var destination: Destination = cjmsContext.createQueue("testConnectionFactoryCreateContextSession")
            sendMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextSession")
            recvMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextSession")
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testConnectionFactoryCreateContextUserPass() {
        try (cjmsContext = connectionFactory.createContext("admin", "admin")) {
            cjmsContext.start()
            @Assert(cjmsContext is ActiveMQContext)
            var destination: Destination = cjmsContext.createQueue("testConnectionFactoryCreateContextUserPass")
            sendMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextUserPass")
            recvMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextUserPass")
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testConnectionFactoryCreateContextUserPassSession() {
        try (cjmsContext = connectionFactory.createContext("admin", "admin", AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            @Assert(cjmsContext is ActiveMQContext)
        }
    }

    @TestCase
    public func testConnectionFactoryCreateContexMultiContext() {
        var secondCJMSContext: ?CJMSContext = None
        var thirdCJMSContext: ?CJMSContext = None

        try (cjmsContext = connectionFactory.createContext("admin", "admin")) {
            cjmsContext.start()
            @Assert(cjmsContext is ActiveMQContext)

            var testDestination: Destination = cjmsContext.createQueue("testConnectionFactoryCreateContexMultiContext")
            sendMessage(cjmsContext, testDestination, "Test-testConnectionFactoryCreateContexMultiContext")
            recvMessage(cjmsContext, testDestination, "Test-testConnectionFactoryCreateContexMultiContext")

            secondCJMSContext = cjmsContext.createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)
        } catch (e: CJMSException) {
            @Assert(false)
        }

        var secondTestDestinationName = "testConnectionFactoryCreateContexMultiContext.SECOND"
        var secondTestDestination: Destination = secondCJMSContext.getOrThrow().createQueue(secondTestDestinationName)

        try {
            sendMessage(secondCJMSContext.getOrThrow(), secondTestDestination,
                "Test-testConnectionFactoryCreateContexMultiContext")
            recvMessage(secondCJMSContext.getOrThrow(), secondTestDestination,
                "Test-testConnectionFactoryCreateContexMultiContext")
        } catch (e: CJMSException) {
            @Assert(false)
        } finally {
            try {
                secondCJMSContext.getOrThrow().close()
            } catch (e: CJMSException) {
                @Assert(false)
            }
        }

        var caught: Bool = false
        try {
            thirdCJMSContext = secondCJMSContext.getOrThrow().createContext(AcknowledgeMode.AUTO_ACKNOWLEDGE)
            @Assert(false)
        } catch (e: CJMSException) {
            @Assert(thirdCJMSContext.isNone())
            caught = true
            @Assert("Context already closed", e.message)
        }
        @Assert(caught)
    }

    @TestCase
    public func testConnectionFactoryCreateContextBrowse() {
        try (cjmsContext = connectionFactory.createContext()) {
            cjmsContext.start()
            @Assert(cjmsContext is ActiveMQContext)
            var destination = cjmsContext.createQueue("testConnectionFactoryCreateContextBrowse")
            sendMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowse")
            browseMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowse", true)
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testConnectionFactoryCreateContextBrowseAutoStart() {
        try (cjmsContext = connectionFactory.createContext()) {
            @Assert(cjmsContext is ActiveMQContext)
            var destination = cjmsContext.createQueue("testConnectionFactoryCreateContextBrowseAutoStart")
            sendMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowseAutoStart")
            browseMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowseAutoStart", true)
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testConnectionFactoryCreateContextBrowseAutoStartFalse() {
        try (cjmsContext = connectionFactory.createContext()) {
            @Assert(cjmsContext is ActiveMQContext)
            cjmsContext.autoStart = false
            var destination = cjmsContext.createQueue("testConnectionFactoryCreateContextBrowseAutoStartFalse")
            sendMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowseAutoStartFalse")
            browseMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowseAutoStartFalse", false
            )
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testConnectionFactoryCreateContextBrowseAutoStartFalseStartDelayed() {
        try (cjmsContext = connectionFactory.createContext()) {
            @Assert(cjmsContext is ActiveMQContext)
            cjmsContext.autoStart = false
            var destination = cjmsContext.createQueue("testConnectionFactoryCreateContextBrowseAutoStartFalse")
            sendMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowseAutoStartFalse")
            cjmsContext.start()
            browseMessage(cjmsContext, destination, "Test-testConnectionFactoryCreateContextBrowseAutoStartFalse", true)
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testDisableMessageID() {
        try (cjmsContext = connectionFactory.createContext()) {
            cjmsContext.autoStart = false
            @Assert(cjmsContext is ActiveMQContext)
            cjmsContext.start()

            var cjmsProducer = cjmsContext.createProducer()
            cjmsProducer.setDisableMessageID(true)
            var destination: Destination = cjmsContext.createQueue("testDisableMessageID")
            var sendMessage = cjmsContext.createTextMessage("Test-testDisableMessageID")
            cjmsProducer.send(destination, sendMessage)
            var cjmsConsumer = cjmsContext.createConsumer(destination)
            var recvMessage = cjmsConsumer.receive(Duration.millisecond * 5000)
            @Assert(recvMessage.isSome())

            @Assert(sendMessage.getCJMSMessageID(), recvMessage.getOrThrow().getCJMSMessageID())
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testCreateShardConsumer() {
        try (cjmsContext = connectionFactory.createContext()) {
            try {
                cjmsContext.createSharedConsumer(ActiveMQTopic("testCreateShardConsumer"), "testCreateShardConsumer")
                @Assert(false)
            } catch (e: UnsupportedException) {
                @Assert(true)
            }
        }
    }

    @TestCase
    public func testCreateSharedDurableConsumer() {
        try (cjmsContext = connectionFactory.createContext()) {
            try {
                cjmsContext.createSharedDurableConsumer(ActiveMQTopic("testCreateSharedDurableConsumer"),
                    "testCreateSharedDurableConsumer")
                @Assert(false)
            } catch (e: UnsupportedException) {
                @Assert(true)
            }
        }
    }

    @TestCase
    public func testSessionDurableConsumer() {
        try (cjmsContext = connectionFactory.createContext()) {
            cjmsContext.autoStart = false
            cjmsContext.clientID = "testSessionDurableConsumer"
            cjmsContext.start()
            @Assert(cjmsContext is ActiveMQContext)

            var name = "testSessionDurableConsumer-${DateTime.now()}"
            var topic = cjmsContext.createTopic(name)

            var cjmsConsumerRegisterDurableConsumer = cjmsContext.createDurableConsumer(topic, name)
            cjmsConsumerRegisterDurableConsumer.close()
            sendMessage(cjmsContext, topic, "Test-testSessionDurableConsumer")
            recvMessageDurable(cjmsContext, topic, name, None, false, "Test-testSessionDurableConsumer")
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    @TestCase
    public func testSessionDurableConsumerSelectorNoLocal() {
        try (cjmsContext = connectionFactory.createContext()) {
            cjmsContext.autoStart = false
            cjmsContext.clientID = "testSessionDurableConsumerSelectorNoLocal"
            cjmsContext.start()
            @Assert(cjmsContext is ActiveMQContext)

            var name = "testSessionDurableConsumerSelectorNoLocal-${DateTime.now()}"
            var topic = cjmsContext.createTopic(name)
            var cjmsConsumerRegisterDurableConsumer = cjmsContext.createDurableConsumer(topic, name, "TRUE", false)
            cjmsConsumerRegisterDurableConsumer.close()

            sendMessage(cjmsContext, topic, name)
            recvMessageDurable(cjmsContext, topic, name, "TRUE", false, name)
        } catch (e: CJMSException) {
            @Assert(false)
        }
    }

    private func sendMessage(cjmsContext: CJMSContext, testDestination: Destination, textBody: String) {
        var cjmsProducer = cjmsContext.createProducer()
        cjmsProducer.send(testDestination, textBody)
    }

    private func recvMessage(cjmsContext: CJMSContext, testDestination: Destination, expectedTextBody: String) {
        try (cjmsConsumer = cjmsContext.createConsumer(testDestination)) {
            var message = cjmsConsumer.receive(Duration.millisecond * 1000)
            @Assert(message.isSome())
            @Assert(message.getOrThrow() is TextMessage)
            @Assert(expectedTextBody, (message.getOrThrow() as TextMessage).getOrThrow().text)
        }
    }

    private func browseMessage(cjmsContext: CJMSContext, testDestination: Destination, expectedTextBody: String,
        expectFound: Bool) {
        @Assert(testDestination is Queue)
        var testQueue = (testDestination as Queue).getOrThrow()
        try (queueBrowser = cjmsContext.createBrowser(testQueue)) {
            var iterator = queueBrowser.iterator()

            var found = false
            while (!found) {
                var message = iterator.next()
                if (message.isNone()) {
                    break
                }
                @Assert(message.getOrThrow() is TextMessage)
                @Assert(Some(expectedTextBody), (message.getOrThrow() as TextMessage).getOrThrow().text)
                found = true
            }
            @Assert(expectFound, found)
        }
    }

    private func recvMessageDurable(cjmsContext: CJMSContext, testTopic: Topic, subscriptionName: String,
        selector: ?String, noLocal: Bool, expectedTextBody: String) {
        try (cjmsConsumer = cjmsContext.createDurableConsumer(testTopic, subscriptionName, selector, noLocal)) {
            var message = cjmsConsumer.receive(Duration.millisecond * 1000)
            @Assert(message.isSome())
            @Assert(message.getOrThrow() is TextMessage)
            @Assert(Some(expectedTextBody), (message.getOrThrow() as TextMessage).getOrThrow().text)
        }
    }
}
