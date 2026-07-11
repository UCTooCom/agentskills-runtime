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
package activemq4cj.client.openwire.v12

public class MessageDispatchNotificationMarshaller <: BaseCommandMarshaller {

    //                                                              [==if not null is 1=================]               [==if not null is 1=================]                                      [==if not null is 1=================]
    //   +------+------+-----------+------------------+----------+  [ +------+------------------------+ ] +----------+  [ +------+------------------------+ ]  +---------------------+-----------+ [ +------+------------------------+ ]
    //   | size | type | commandId | responseRequired | not null |  [ | type | command-specific-fields| ] | not null |  [ | type | command-specific-fields| ]  | deliverySequenceId  | not null  | [ | type | command-specific-fields| ]
    //   +------+------+-----------+------------------+----------+  [ +------+------------------------+ ] +----------+  [ +------+------------------------+ ]  +---------------------+-----------+ [ +------+------------------------+ ]
    //   | Int32| Byte |   Int32   |   Byte           | Byte     |  [ | Byte |  variable sized        | ] | Byte     |  [ | Byte |  variable sized        | ]  | Int32               | Bool      | [ | Byte |  variable sized        | ]
    //   +------+------+-----------+------------------+----------+  [ +------+------------------------+ ] +----------+  [ +------+------------------------+ ]  +---------------------+-----------+ [ +------+------------------------+ ]
    //                                                              [=========ConsumerId================]               [========ActiveMQDestination========]                                      [========MessageId==================]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(messageDispatchNotification) <- (object as MessageDispatchNotification)) {
            super.looseMarshal(messageDispatchNotification, dataOut)
            looseMarshalCachedObject<ConsumerId>(messageDispatchNotification.consumerId, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(messageDispatchNotification.destination, dataOut)
            dataOut.putInt64(messageDispatchNotification.deliverySequenceId)
            looseMarshalNestedObject<MessageId>(messageDispatchNotification.messageId, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(messageDispatchNotification) <- (data as MessageDispatchNotification)) {
            super.looseUnmarshal(messageDispatchNotification, dataIn)
            messageDispatchNotification.consumerId = looseUnmarsalCachedObject<ConsumerId>(dataIn)
            messageDispatchNotification.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            messageDispatchNotification.deliverySequenceId = dataIn.getInt64()
            messageDispatchNotification.messageId = looseUnmarsalNestedObject<MessageId>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messageDispatchNotification) <- (object as MessageDispatchNotification)) {
            super.tightMarshal(messageDispatchNotification, dataOut, bs)
            tightMarshalCachedObject<ConsumerId>(messageDispatchNotification.consumerId, dataOut, bs)
            tightMarshalCachedObject<ActiveMQDestination>(messageDispatchNotification.destination, dataOut, bs)
            tightMarshalLong(messageDispatchNotification.deliverySequenceId, dataOut, bs)
            tightMarshalNestedObject<MessageId>(messageDispatchNotification.messageId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messageDispatchNotification) <- (data as MessageDispatchNotification)) {
            super.tightUnmarshal(messageDispatchNotification, dataIn, bs)
            messageDispatchNotification.consumerId = tightUnmarsalCachedObject<ConsumerId>(dataIn, bs)
            messageDispatchNotification.destination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            messageDispatchNotification.deliverySequenceId = tightUnmarshalLong(dataIn, bs)
            messageDispatchNotification.messageId = tightUnmarshalNestedObject<MessageId>(dataIn, bs)
        }
    }

    public override func createObject(): MessageDispatchNotification {
        return MessageDispatchNotification()
    }
}
