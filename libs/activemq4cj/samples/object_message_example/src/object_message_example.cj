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
package object_message_samples

internal import activemq4cj.client.*
internal import activemq4cj.client.command.*
internal import activemq4cj.cjms.*
internal import stdx.serialization.serialization.*

main(): Unit {
    let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
    try (connection = connectionFactory.createConnection()) {
        connection.start()

        try (session = connection.createSession()) {
            let objectMessage = session.createObjectMessage()
            objectMessage.object = Person().serialize()

            let queue = ActiveMQQueue("test_queue_cangjie")

            try (producer = session.createProducer(queue)) {
                producer.send(objectMessage)
            }

            try (consumer = session.createConsumer(queue)) {
                let message = consumer.receive()
                if (let Some(msg) <- message) {
                    if (let Some(msg) <- (msg as ActiveMQObjectMessage)) {
                        if (let Some(dm) <- msg.object) {
                            println(Person.deserialize(dm))
                        }
                    }
                }
            }
        }
    }
}

public class Person <: Serializable<Any> & ToString {
    public var name: String = "zhangsan"
    public var age: Int64 = 18

    public func serialize(): DataModel {
        return DataModelStruct().add(field<String>("name", name)).add(field<Int64>("age", age))
    }

    public static func deserialize(dm: DataModel): Person {
        let dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        let result = Person()
        result.name = String.deserialize(dms.get("name"))
        result.age = Int64.deserialize(dms.get("age"))
        return result
    }

    public func toString(): String {
        return "name: ${name},age: ${age}"
    }
}
