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

public class MessageIdMarshaller <: BaseDataStreamMarshaller {

    //                                 [=======if not null is 1=======================]            
    // +------+-----------+----------+ [ +-------+--------------+-------+-----------+ ] +--------------------+------------------+
    // | type | textView  | not null | [ |  type | connectionId | value | sessionId | ] | producerSequenceId | brokerSequenceId |  
    // +------+-----------+----------+ [ +-------+--------------+-------+-----------+ ] +--------------------+------------------+                                       
    // | Byte |   String  | Byte     | [ |  Byte |  String      | Int64 | Int64     | ] |        Int64       |     Byte         |     
    // +------+-----------+----------+ [ +-------+--------------+-------+-----------+ ] +--------------------+------------------+                         
    //                                 [========producerId============================]              

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(messageId) <- (object as MessageId)) {
            super.looseMarshal(messageId, dataOut)
            looseMarshalString(messageId.textView, dataOut)
            looseMarshalCachedObject<ProducerId>(messageId.producerId, dataOut)
            dataOut.putInt64(messageId.producerSequenceId)
            dataOut.putInt64(messageId.brokerSequenceId)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(messageId) <- (data as MessageId)) {
            super.looseUnmarshal(messageId, dataIn)
            messageId.textView = looseUnmarshalString(dataIn)
            messageId.producerId = looseUnmarsalCachedObject<ProducerId>(dataIn)
            messageId.producerSequenceId = dataIn.getInt64()
            messageId.brokerSequenceId = dataIn.getInt64()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messageId) <- (object as MessageId)) {
            super.tightMarshal(messageId, dataOut, bs)
            tightMarshalString(messageId.textView, dataOut, bs)
            tightMarshalCachedObject<ProducerId>(messageId.producerId, dataOut, bs)
            tightMarshalLong(messageId.producerSequenceId, dataOut, bs)
            tightMarshalLong(messageId.brokerSequenceId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messageId) <- (data as MessageId)) {
            super.tightUnmarshal(messageId, dataIn, bs)
            messageId.textView = tightUnmarshalString(dataIn, bs)
            messageId.producerId = tightUnmarsalCachedObject<ProducerId>(dataIn, bs)
            messageId.producerSequenceId = tightUnmarshalLong(dataIn, bs)
            messageId.brokerSequenceId = tightUnmarshalLong(dataIn, bs)
        }
    }

    public override func createObject(): MessageId {
        return MessageId()
    }
}

public abstract class MessageMarshaller <: BaseCommandMarshaller {

    //                             [=======if not null is 1=======================]              [==if not null is 1=================]              [==========if not null is 1============]
    // +-------+------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+ [ +------+------------------------+ ] +----------+ [ +------+---------------------------+ ]
    // | size  | type | not null | [ |  type | connectionId | value | sessionId | ] | not null | [ | type | command-specific-fields| ] | not null | [ | type | command-specific-fields   | ]
    // +-------+------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+ [ +------+------------------------+ ] +----------+ [ +------+---------------------------+ ]   ==>
    // | Int32 | Byte | Byte     | [ |  Byte |  String      | Int64 | Int64     | ] | Byte     | [ | Byte |  variable sized        | ] | Byte     | [ | Byte |   variable sized          | ]
    // +-------+------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+ [ +------+------------------------+ ] +----------+ [ +------+---------------------------+ ]
    //                             [========producerId============================]              [=========ActiveMQDestination=======]              [============TransactionId=============]

    //                   [==if not null is 1==================]              [==========if not null is 1============]              [==========if not null is 1============]
    //      +----------+ [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+
    //      | not null | [ | type | command-specific-fields | ] | not null | [ | type | command-specific-fields   | ] | not null | [ | type | command-specific-fields   | ] | groupID  |
    // ==>  +----------+ [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+  ==>
    //      | Byte     | [ | Byte | variable sized          | ] | Byte     | [ | Byte |   variable sized          | ] | Byte     | [ | Byte |   variable sized          | ] | String   |
    //      +----------+ [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+
    //                   [=======ActiveMQDestination==========]              [==============MessageId===============]              [============TransactionId=============]

    //                                                                                      [==if not null is 1==================]
    //      +---------------+---------------+------------+----------+----------+----------+ [ +------+-------------------------+ ] +-----------+--------+-----------+----------------------+----------+
    //      | groupSequence | correlationId | persistent |expiration| priority | not null | [ | type | command-specific-fields | ] | timestamp | type   | content   | marshalledProperties | not null |
    // ==>  +---------------+---------------+------------+----------+----------+----------+ [ +------+-------------------------+ ] +-----------+--------+-----------+----------------------+----------+  ==>
    //      | Int32         | String        | Bool       | Int64    | Byte     | Byte     | [ | Byte | variable sized          | ] | Int64     | String | ByteArray |   ByteArray          | Byte     |
    //      +---------------+---------------+------------+----------+----------+----------+ [ +------+-------------------------+ ] +-----------+--------+-----------+----------------------+----------+
    //                                                                                      [=======ActiveMQDestination==========]

    //      [==if not null is 1==================]              [==========if not null is 1============]
    //      [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +------------+-------------------+-------------+----------+--------+--------------------+
    //      [ | type | command-specific-fields | ] | not null | [ | type | command-specific-fields   | ] | compressed | redeliveryCounter | brokerPath  | arrival  | userID | recievedByDFBridge |
    // ==>  [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +------------+-------------------+-------------+----------+--------+--------------------+  ==>
    //      [ | Byte | variable sized          | ] | Byte     | [ | Byte |   variable sized          | ] | Bool       |    Int32          |  ByteArray  | Int64    | String | Bool               |
    //      [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +------------+-------------------+------------ +----------+--------+--------------------+
    //      [============DataStructure===========]              [==============ConsumerId==============]

    //
    //      +-----------+-----------+--------------+--------------+---------------------------+
    //      | droppable | cluster   | brokerInTime | brokerOutTime| jmsXGroupFirstForConsumer |
    // ==>  +-----------+-----------+--------------+--------------+---------------------------+
    //      | Bool      | ByteArray | Int64        | Int64        |       Bool                |
    //      +-----------+-----------+--------------+--------------+---------------------------+
    //

    public open func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(message) <- (object as Message)) {
            super.looseMarshal(message, dataOut)
            message.beforeMarshall()
            looseMarshalCachedObject<ProducerId>(message.producerId, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(message.destination, dataOut)
            looseMarshalCachedObject<TransactionId>(message.transactionId, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(message.originalDestination, dataOut)
            looseMarshalNestedObject<MessageId>(message.messageId, dataOut)
            looseMarshalCachedObject<TransactionId>(message.originalTransactionId, dataOut)
            looseMarshalString(message.groupID, dataOut)
            dataOut.putInt32(message.groupSequence)
            looseMarshalString(message.correlationId, dataOut)
            MarshallingSupport.putBool(message.persistent, dataOut)
            dataOut.putInt64(message.expiration)
            dataOut.putByte(message.priority)
            looseMarshalNestedObject<ActiveMQDestination>(message.replyTo, dataOut)
            dataOut.putInt64(message.timestamp)
            looseMarshalString(message.messageType, dataOut)
            looseMarshalByteArray(message.content, dataOut)
            looseMarshalByteArray(message.marshalledProperties, dataOut)
            looseMarshalNestedObject<DataStructure>(message.dataStructure, dataOut)
            looseMarshalCachedObject<ConsumerId>(message.targetConsumerId, dataOut)
            MarshallingSupport.putBool(message.compressed, dataOut)
            dataOut.putInt32(message.redeliveryCounter)
            looseMarshalObjectArray<BrokerId>(message.brokerPath, dataOut)
            dataOut.putInt64(message.arrival)
            looseMarshalString(message.userID, dataOut)
            MarshallingSupport.putBool(message.recievedByDFBridge, dataOut)
            MarshallingSupport.putBool(message.droppable, dataOut)
            looseMarshalObjectArray<BrokerId>(message.cluster, dataOut)
            dataOut.putInt64(message.brokerInTime)
            dataOut.putInt64(message.brokerOutTime)
            MarshallingSupport.putBool(message.jmsXGroupFirstForConsumer, dataOut)
        }
    }

    public open func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(message) <- (data as Message)) {
            super.looseUnmarshal(message, dataIn)
            message.producerId = looseUnmarsalCachedObject<ProducerId>(dataIn)
            message.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            message.transactionId = looseUnmarsalCachedObject<TransactionId>(dataIn)
            message.originalDestination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            message.messageId = looseUnmarsalNestedObject<MessageId>(dataIn)
            message.originalTransactionId = looseUnmarsalCachedObject<TransactionId>(dataIn)
            message.groupID = looseUnmarshalString(dataIn)
            message.groupSequence = dataIn.getInt32()
            message.correlationId = looseUnmarshalString(dataIn)
            message.persistent = MarshallingSupport.getBool(dataIn)
            message.expiration = dataIn.getInt64()
            message.priority = UInt8(dataIn.getInt8())
            message.replyTo = looseUnmarsalNestedObject<ActiveMQDestination>(dataIn)
            message.timestamp = dataIn.getInt64()
            message.messageType = looseUnmarshalString(dataIn)
            message.content = looseUnmarshalByteArray(dataIn)
            message.marshalledProperties = looseUnmarshalByteArray(dataIn)
            message.dataStructure = looseUnmarsalNestedObject<DataStructure>(dataIn)
            message.targetConsumerId = looseUnmarsalCachedObject<ConsumerId>(dataIn)
            message.compressed = MarshallingSupport.getBool(dataIn)
            message.redeliveryCounter = dataIn.getInt32()
            if (MarshallingSupport.getBool(dataIn)) {
                let size = dataIn.getInt16()
                let brokerPath = Array<BrokerId>(Int64(size), repeat: BrokerId())
                for (i in 0..size) {
                    if (let Some(brokerId) <- looseUnmarsalNestedObject<BrokerId>(dataIn)) {
                        brokerPath[Int64(i)] = brokerId
                    }
                }
                message.brokerPath = brokerPath
            }
            message.arrival = dataIn.getInt64()
            message.userID = looseUnmarshalString(dataIn)
            message.recievedByDFBridge = MarshallingSupport.getBool(dataIn)
            message.droppable = MarshallingSupport.getBool(dataIn)
            if (MarshallingSupport.getBool(dataIn)) {
                let size = dataIn.getInt16()
                let brokerPath = Array<BrokerId>(Int64(size), repeat: BrokerId())
                for (i in 0..size) {
                    if (let Some(brokerId) <- looseUnmarsalNestedObject<BrokerId>(dataIn)) {
                        brokerPath[Int64(i)] = brokerId
                    }
                }
                message.cluster = brokerPath
            }
            message.brokerInTime = dataIn.getInt64()
            message.brokerOutTime = dataIn.getInt64()
            message.jmsXGroupFirstForConsumer = MarshallingSupport.getBool(dataIn)
        }
    }

    public open func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(message) <- (object as Message)) {
            super.tightMarshal(message, dataOut, bs)
            message.beforeMarshall()
            tightMarshalCachedObject<ProducerId>(message.producerId, dataOut, bs)
            tightMarshalCachedObject<ActiveMQDestination>(message.destination, dataOut, bs)
            tightMarshalCachedObject<TransactionId>(message.transactionId, dataOut, bs)
            tightMarshalCachedObject<ActiveMQDestination>(message.originalDestination, dataOut, bs)
            tightMarshalNestedObject<MessageId>(message.messageId, dataOut, bs)
            tightMarshalCachedObject<TransactionId>(message.originalTransactionId, dataOut, bs)
            tightMarshalString(message.groupID, dataOut, bs)
            dataOut.putInt32(message.groupSequence)
            tightMarshalString(message.correlationId, dataOut, bs)
            bs.writeBool(message.persistent)
            tightMarshalLong(message.expiration, dataOut, bs)
            dataOut.putByte(message.priority)
            tightMarshalNestedObject<ActiveMQDestination>(message.replyTo, dataOut, bs)
            tightMarshalLong(message.timestamp, dataOut, bs)
            tightMarshalString(message.messageType, dataOut, bs)
            tightMarshalByteArray(message.content, dataOut, bs)
            tightMarshalByteArray(message.marshalledProperties, dataOut, bs)
            tightMarshalNestedObject<DataStructure>(message.dataStructure, dataOut, bs)
            tightMarshalCachedObject<ConsumerId>(message.targetConsumerId, dataOut, bs)
            bs.writeBool(message.compressed)
            dataOut.putInt32(message.redeliveryCounter)
            tightMarshalObjectArray<BrokerId>(message.brokerPath, dataOut, bs)
            tightMarshalLong(message.arrival, dataOut, bs)
            tightMarshalString(message.userID, dataOut, bs)
            bs.writeBool(message.recievedByDFBridge)
            bs.writeBool(message.droppable)
            tightMarshalObjectArray<BrokerId>(message.cluster, dataOut, bs)
            tightMarshalLong(message.brokerInTime, dataOut, bs)
            tightMarshalLong(message.brokerOutTime, dataOut, bs)
            bs.writeBool(message.jmsXGroupFirstForConsumer)
        }
    }

    public open func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(message) <- (data as Message)) {
            super.tightUnmarshal(message, dataIn, bs)
            message.producerId = tightUnmarsalCachedObject<ProducerId>(dataIn, bs)
            message.destination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            message.transactionId = tightUnmarsalCachedObject<TransactionId>(dataIn, bs)
            message.originalDestination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            message.messageId = tightUnmarshalNestedObject<MessageId>(dataIn, bs)
            message.originalTransactionId = tightUnmarsalCachedObject<TransactionId>(dataIn, bs)
            message.groupID = tightUnmarshalString(dataIn, bs)
            message.groupSequence = dataIn.getInt32()
            message.correlationId = tightUnmarshalString(dataIn, bs)
            message.persistent = bs.readBool()
            message.expiration = tightUnmarshalLong(dataIn, bs)
            message.priority = UInt8(dataIn.getInt8())
            message.replyTo = tightUnmarshalNestedObject<ActiveMQDestination>(dataIn, bs)
            message.timestamp = tightUnmarshalLong(dataIn, bs)
            message.messageType = tightUnmarshalString(dataIn, bs)
            message.content = tightUnmarshalByteArray(dataIn, bs)
            message.marshalledProperties = tightUnmarshalByteArray(dataIn, bs)
            message.dataStructure = tightUnmarshalNestedObject<DataStructure>(dataIn, bs)
            message.targetConsumerId = tightUnmarsalCachedObject<ConsumerId>(dataIn, bs)
            message.compressed = bs.readBool()
            message.redeliveryCounter = dataIn.getInt32()
            if (bs.readBool()) {
                let size = dataIn.getInt16()
                let brokerPath = Array<BrokerId>(Int64(size), repeat: BrokerId())
                for (i in 0..size) {
                    if (let Some(b) <- tightUnmarshalNestedObject<BrokerId>(dataIn, bs)) {
                        brokerPath[Int64(i)] = b
                    }
                }
                message.brokerPath = brokerPath
            }
            message.arrival = tightUnmarshalLong(dataIn, bs)
            message.userID = tightUnmarshalString(dataIn, bs)
            message.recievedByDFBridge = bs.readBool()
            message.droppable = bs.readBool()
            if (bs.readBool()) {
                let size = dataIn.getInt16()
                let brokerPath = Array<BrokerId>(Int64(size), repeat: BrokerId())
                for (i in 0..size) {
                    if (let Some(b) <- tightUnmarshalNestedObject<BrokerId>(dataIn, bs)) {
                        brokerPath[Int64(i)] = b
                    }
                }
                message.cluster = brokerPath
            }
            message.brokerInTime = tightUnmarshalLong(dataIn, bs)
            message.brokerOutTime = tightUnmarshalLong(dataIn, bs)
            message.jmsXGroupFirstForConsumer = bs.readBool()
        }
    }
}

public open class ActiveMQMessageMarshaller <: MessageMarshaller {
    public open func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQMessage) <- (object as ActiveMQMessage)) {
            super.looseMarshal(activeMQMessage, dataOut)
        }
    }

    public open func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQMessage) <- (data as ActiveMQMessage)) {
            super.looseUnmarshal(activeMQMessage, dataIn)
        }
    }

    public open func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQMessage) <- (object as ActiveMQMessage)) {
            super.tightMarshal(activeMQMessage, dataOut, bs)
        }
    }

    public open func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQMessage) <- (data as ActiveMQMessage)) {
            super.tightUnmarshal(activeMQMessage, dataIn, bs)
        }
    }

    public open func createObject(): ActiveMQMessage {
        return ActiveMQMessage()
    }
}

public class ActiveMQTextMessageMarshaller <: ActiveMQMessageMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQTextMessage) <- (object as ActiveMQTextMessage)) {
            super.looseMarshal(activeMQTextMessage, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQTextMessage) <- (data as ActiveMQTextMessage)) {
            super.looseUnmarshal(activeMQTextMessage, dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQTextMessage) <- (object as ActiveMQTextMessage)) {
            activeMQTextMessage.storeContent()
            super.tightMarshal(activeMQTextMessage, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQTextMessage) <- (data as ActiveMQTextMessage)) {
            super.tightUnmarshal(activeMQTextMessage, dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQTextMessage {
        return ActiveMQTextMessage()
    }
}

public class ActiveMQObjectMessageMarshaller <: ActiveMQMessageMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQObjectMessage) <- (object as ActiveMQObjectMessage)) {
            super.looseMarshal(activeMQObjectMessage, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQObjectMessage) <- (data as ActiveMQObjectMessage)) {
            super.looseUnmarshal(activeMQObjectMessage, dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQObjectMessage) <- (object as ActiveMQObjectMessage)) {
            super.tightMarshal(activeMQObjectMessage, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQObjectMessage) <- (data as ActiveMQObjectMessage)) {
            super.tightUnmarshal(activeMQObjectMessage, dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQObjectMessage {
        return ActiveMQObjectMessage()
    }
}

public class ActiveMQBytesMessageMarshaller <: ActiveMQMessageMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQBytesMessage) <- (object as ActiveMQBytesMessage)) {
            super.looseMarshal(activeMQBytesMessage, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQBytesMessage) <- (data as ActiveMQBytesMessage)) {
            super.looseUnmarshal(activeMQBytesMessage, dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQBytesMessage) <- (object as ActiveMQBytesMessage)) {
            super.tightMarshal(activeMQBytesMessage, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQBytesMessage) <- (data as ActiveMQBytesMessage)) {
            super.tightUnmarshal(activeMQBytesMessage, dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQBytesMessage {
        return ActiveMQBytesMessage()
    }
}

public class ActiveMQMapMessageMarshaller <: ActiveMQMessageMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQMapMessage) <- (object as ActiveMQMapMessage)) {
            super.looseMarshal(activeMQMapMessage, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQMapMessage) <- (data as ActiveMQMapMessage)) {
            super.looseUnmarshal(activeMQMapMessage, dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQMapMessage) <- (object as ActiveMQMapMessage)) {
            super.tightMarshal(activeMQMapMessage, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQMapMessage) <- (data as ActiveMQMapMessage)) {
            super.tightUnmarshal(activeMQMapMessage, dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQMapMessage {
        return ActiveMQMapMessage()
    }
}

public class ActiveMQBlobMessageMarshaller <: ActiveMQMessageMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQBlobMessage) <- (object as ActiveMQBlobMessage)) {
            super.looseMarshal(activeMQBlobMessage, dataOut)
            looseMarshalString(activeMQBlobMessage.remoteBlobUrl, dataOut)
            looseMarshalString(activeMQBlobMessage.mimeType, dataOut)
            MarshallingSupport.putBool(activeMQBlobMessage.deletedByBroker, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQBlobMessage) <- (data as ActiveMQBlobMessage)) {
            super.looseUnmarshal(activeMQBlobMessage, dataIn)
            activeMQBlobMessage.remoteBlobUrl = looseUnmarshalString(dataIn)
            activeMQBlobMessage.mimeType = looseUnmarshalString(dataIn)
            activeMQBlobMessage.deletedByBroker = MarshallingSupport.getBool(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQBlobMessage) <- (object as ActiveMQBlobMessage)) {
            super.tightMarshal(activeMQBlobMessage, dataOut, bs)
            tightMarshalString(activeMQBlobMessage.remoteBlobUrl, dataOut, bs)
            tightMarshalString(activeMQBlobMessage.mimeType, dataOut, bs)
            bs.writeBool(activeMQBlobMessage.deletedByBroker)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQBlobMessage) <- (data as ActiveMQBlobMessage)) {
            super.tightUnmarshal(activeMQBlobMessage, dataIn, bs)
            activeMQBlobMessage.remoteBlobUrl = tightUnmarshalString(dataIn, bs)
            activeMQBlobMessage.mimeType = tightUnmarshalString(dataIn, bs)
            activeMQBlobMessage.deletedByBroker = bs.readBool()
        }
    }

    public override func createObject(): ActiveMQBlobMessage {
        return ActiveMQBlobMessage()
    }
}

public class ActiveMQStreamMessageMarshaller <: ActiveMQMessageMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQStreamMessage) <- (object as ActiveMQStreamMessage)) {
            super.looseMarshal(activeMQStreamMessage, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQStreamMessage) <- (data as ActiveMQStreamMessage)) {
            super.looseUnmarshal(activeMQStreamMessage, dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQStreamMessage) <- (object as ActiveMQStreamMessage)) {
            super.tightMarshal(activeMQStreamMessage, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQStreamMessage) <- (data as ActiveMQStreamMessage)) {
            super.tightUnmarshal(activeMQStreamMessage, dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQStreamMessage {
        return ActiveMQStreamMessage()
    }
}
