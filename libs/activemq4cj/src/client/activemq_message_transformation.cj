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
package activemq4cj.client

public class ActiveMQMessageTransformation {
    private init() {
    }

    public static func transformDestination(destination: Destination): ActiveMQDestination {
        return ActiveMQDestination.transform(destination)
    }

    public static func transformMessage(message: CJMSMessage, connection: ActiveMQConnection): ActiveMQMessage {
        if (let Some(message) <- (message as ActiveMQMessage)) {
            return message
        } else {
            var activemqMessage: ActiveMQMessage = ActiveMQMessage()
            activemqMessage.connection = connection

            if (let Some(bytesMessage) <- (message as BytesMessage)) {
                let msg: ActiveMQBytesMessage = ActiveMQBytesMessage()
                bytesMessage.reset()
                for (i in 0..bytesMessage.getBodyLength()) {
                    msg.writeByte(bytesMessage.readByte())
                }
                activemqMessage = msg
            } else if (let Some(mapMessage) <- (message as MapMessage)) {
                let msg: ActiveMQMapMessage = ActiveMQMapMessage()
                if (let Some(names) <- mapMessage.getMapNames()) {
                    for (name in names) {
                        msg.setObject(name, mapMessage.getObject(name))
                    }
                }
                activemqMessage = msg
            } else if (let Some(objectMessage) <- (message as ObjectMessage)) {
                let msg: ActiveMQObjectMessage = ActiveMQObjectMessage()
                msg.object = objectMessage.object
                msg.storeContent()
                activemqMessage = msg
            } else if (let Some(streamMessage) <- (message as StreamMessage)) {
                streamMessage.reset()
                let msg: ActiveMQStreamMessage = ActiveMQStreamMessage()
                while (true) {
                    try {
                        msg.writeObject(streamMessage.readObject())
                    } catch (ex: IndexOutOfBoundsException) {
                        break
                    }
                }
                activemqMessage = msg
            } else if (let Some(textMessage) <- (message as TextMessage)) {
                let msg: ActiveMQTextMessage = ActiveMQTextMessage()
                msg.text = textMessage.text
                activemqMessage = msg
            } else if (let Some(blobMessage) <- (message as BlobMessage)) {
                let msg: ActiveMQBlobMessage = ActiveMQBlobMessage()
                msg.setURL(blobMessage.getURL())
                activemqMessage = msg
            }

            return activemqMessage
        }
    }

    public static func copyProperties(fromMessage: CJMSMessage, toMessage: CJMSMessage): Unit {
        //拷贝头字段
        toMessage.setCJMSMessageID(fromMessage.getCJMSMessageID())
        toMessage.setCJMSCorrelationID(fromMessage.getCJMSCorrelationID())
        if (let Some(replyTo) <- fromMessage.getCJMSReplyTo()) {
            toMessage.setCJMSReplyTo(transformDestination(replyTo))
        }
        if (let Some(destination) <- fromMessage.getCJMSDestination()) {
            toMessage.setCJMSDestination(transformDestination(destination))
        }
        toMessage.setCJMSDeliveryMode(fromMessage.getCJMSDeliveryMode())
        toMessage.setCJMSDeliveryTime(fromMessage.getCJMSDeliveryTime())
        toMessage.setCJMSRedelivered(fromMessage.getCJMSRedelivered())
        toMessage.setCJMSType(fromMessage.getCJMSType())
        toMessage.setCJMSExpiration(fromMessage.getCJMSExpiration())
        toMessage.setCJMSPriority(fromMessage.getCJMSPriority())
        toMessage.setCJMSTimestamp(fromMessage.getCJMSTimestamp())
        //拷贝属性值
        if (let Some(propertyNames) <- fromMessage.getPropertyNames()) {
            for (name in propertyNames) {
                toMessage.setObjectProperty(name, fromMessage.getObjectProperty(name))
            }
        }
    }
}
