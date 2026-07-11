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
package text_message_samples

internal import activemq4cj.client.*
internal import activemq4cj.client.api.*
internal import activemq4cj.client.command.*
internal import activemq4cj.client.util.*
internal import activemq4cj.cjms.*

main(): Unit {
    let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
    try (connection = connectionFactory.createConnection()) {
        connection.start()

        try (session = connection.createSession()) {
            let textMessage = session.createTextMessage("hello, Cangjie")

            let queue = ActiveMQQueue("test_queue_cangjie")

            try (producer = session.createProducer(queue), consumer = session.createConsumer(queue)) {
                producer.send(textMessage)

                let message = consumer.receive()
                if (let Some(msg) <- message) {
                    if (let Some(msg) <- (msg as ActiveMQTextMessage)) {
                        println(msg.text)
                    }
                }
            }
        }
    }
}
