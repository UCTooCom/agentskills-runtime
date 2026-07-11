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
public class ActiveMQSslConnectionFactoryTest {
    @TestCase
    private func testCreateSslConnection(): Unit {
        let pem = String.fromUtf8(File.readFrom("~/tls/client.pem"))
        let keyPem = String.fromUtf8(File.readFrom("~/tls/client.key"))
        var config = TlsClientConfig()
        config.verifyMode = TrustAll
        config.alpnProtocolsList =["h2"]
        config.clientCertificate = (X509Certificate.decodeFromPem(pem), PrivateKey.decodeFromPem(keyPem))

        let connectionFactory = ActiveMQTlsConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
        connectionFactory.setTlsClientConfig(config)

        try (connection = connectionFactory.createConnection()) {
            connection.start()

            try(session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
                var destination = session.createQueue("TEST.TLS")
                var consumer = session.createConsumer(destination)
                var producer = session.createProducer(destination)
                producer.send(session.createTextMessage("TLS communication"))
                @Assert(consumer.receive(Duration.millisecond *1000).isSome())
            }
        }
    }
}