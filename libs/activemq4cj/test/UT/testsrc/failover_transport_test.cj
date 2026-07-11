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
public class FailoverTransportTest {
    @TestCase
    public func testReconnectUnlimited(): Unit {
        var transport = TransportFactory.connect(
            URL.parse(
                "failover:(tcp://localhost:161617)?useExponentialBackOff=false&reconnectDelay=0&initialReconnectDelay=0"
            ))
        transport.transportListener = DefaultTransportListener()
        transport.start()

        var target = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (target as FailoverTransport)) {
            while (ft.connectFailures < 1024) {
                //do nothing
            }
            @Assert(ft.connectFailures >= 1024)
        }
        transport.stop()
    }

    @TestCase
    public func testTransportOptions(): Unit {
        var transport = TransportFactory.connect(
            URL.parse(
                "failover:(tcp://localhost:161617)?priorityBackup=true&warnAfterReconnectAttempts=20&updateURIsSupported=false&trackMessages=true&startupMaxReconnectAttempts=3&backup=true&maxReconnectAttempts=5&maxReconnectDelay=20000&randomize=false&reconnectDelayExponent=3.0&reconnectSupported=false&useExponentialBackOff=false&reconnectDelay=0&initialReconnectDelay=60&maxCacheSize=4096"
            ))

        var target = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (target as FailoverTransport)) {
            @Assert(true, ft.backup)
            @Assert(60, ft.initialReconnectDelay)
            @Assert(4096, ft.maxCacheSize)
            @Assert(5, ft.maxReconnectAttempts)
            @Assert(20000, ft.maxReconnectDelay)
            @Assert(false, ft.randomize)
            @Assert(3.0, ft.reconnectDelayExponent)
            @Assert(false, ft.reconnectSupported)
            @Assert(3, ft.startupMaxReconnectAttempts)
            @Assert(true, ft.trackMessages)
            @Assert(false, ft.updateURIsSupported)
            @Assert(false, ft.useExponentialBackOff)
            @Assert(20, ft.warnAfterReconnectAttempts)
            @Assert(true, ft.priorityBackup)
        }
    }

    @TestCase
    public func testTimeout(): Unit {
        var timeout = 1000
        var transport = TransportFactory.connect(URL.parse("failover:(tcp://127.0.0.1:61618)?timeout=${timeout}"))
        transport.transportListener = DefaultTransportListener()
        transport.start()

        var target = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (target as FailoverTransport)) {
            try {
                ft.oneway(ActiveMQTextMessage())
            } catch (ex: TransportException) {
                @Assert("Failover timeout of ${timeout}ms reached", ex.message)
            }
        }
        transport.stop()
    }

    @TestCase
    public func testUpdateUris(): Unit {
        var transport = TransportFactory.connect(URL.parse("failover:(tcp://127.0.0.1:61616)"))
        transport.transportListener = DefaultTransportListener()
        transport.start()

        sleep(Duration.millisecond * 200)

        var target = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (target as FailoverTransport)) {
            ft.add(false, ["tcp://localhost:61617", "tcp://localhost:61618"])
        }
        transport.stop()
    }

    @TestCase
    public func testMaxReconnectAttempts(): Unit {
        var transport = TransportFactory.connect(URL.parse("failover:(tcp://127.0.0.1:61619)?maxReconnectAttempts=5"))
        transport.transportListener = DefaultTransportListener()
        transport.start()

        sleep(Duration.second * 25)

        var target = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (target as FailoverTransport)) {
            @Assert(5, ft.connectFailures)
        }
        transport.stop()
    }

    @TestCase
    public func testBackupsAreCreated(): Unit {
        var transport = TransportFactory.connect(
            URL.parse(
                "failover:(tcp://127.0.0.1:61616,tcp://127.0.0.1:61617)?randomize=false&backup=true&backupPoolSize=2"))
        transport.transportListener = DefaultTransportListener()
        transport.start()

        sleep(Duration.millisecond * 200)

        var target = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (target as FailoverTransport)) {
            @Assert(ft.backup)
            @Assert(ft.backupPoolSize, 2)
            @Assert(ft.getCurrentBackupSize(),1)
        }
        transport.stop()
    }

    @TestCase
    public func testResponsesSentWhenRequestForIgnoredCommands(): Unit {
        var transport = TransportFactory.connect(URL.parse("failover:(tcp://127.0.0.1:61616)"))
        transport.transportListener = DefaultTransportListener()
        var response = transport.request(MessageAck())
        @Assert(response.isSome())
    }

    @TestCase
    public func testUpdateURIsViaFile(): Unit {
        var updateFile = File(Path("testsrc/updateURIsFile.txt"), OpenMode.Read)

        let connectionFactory = ActiveMQConnectionFactory("admin", "admin",
            "failover:()?updateURIsURL=${updateFile.info.path}")
        try (connection = connectionFactory.createConnection()) {
            connection.start()

            try (session = connection.createSession()) {
                var text = "testFailOver"
                let textMessage = session.createTextMessage(text)

                let queue = ActiveMQQueue("test.failoverupdateurls")

                try (producer = session.createProducer(queue), consumer = session.createConsumer(queue)) {
                    producer.send(textMessage)

                    let message = consumer.receive()
                    if (let Some(msg) <- message) {
                        if (let Some(msg) <- (msg as ActiveMQTextMessage)) {
                            @Assert(msg.text, text)
                        }
                    }
                }
            }
        }
    }
}
