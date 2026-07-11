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

public class MessageAckMarshaller <: BaseCommandMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(messageAck) <- (object as MessageAck)) {
            super.looseMarshal(messageAck, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(messageAck.destination, dataOut)
            looseMarshalCachedObject<TransactionId>(messageAck.transactionId, dataOut)
            looseMarshalCachedObject<ConsumerId>(messageAck.consumerId, dataOut)
            dataOut.putByte(messageAck.ackType)
            looseMarshalNestedObject<MessageId>(messageAck.firstMessageId, dataOut)
            looseMarshalNestedObject<MessageId>(messageAck.lastMessageId, dataOut)
            dataOut.putInt32(messageAck.messageCount)
            looseMarshalThrowable(messageAck.poisonCause, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(messageAck) <- (data as MessageAck)) {
            super.looseUnmarshal(messageAck, dataIn)
            messageAck.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            messageAck.transactionId = looseUnmarsalCachedObject<TransactionId>(dataIn)
            messageAck.consumerId = looseUnmarsalCachedObject<ConsumerId>(dataIn)
            messageAck.ackType = dataIn.getByte()
            messageAck.firstMessageId = looseUnmarsalNestedObject<MessageId>(dataIn)
            messageAck.lastMessageId = looseUnmarsalNestedObject<MessageId>(dataIn)
            messageAck.messageCount = dataIn.getInt32()
            messageAck.poisonCause = looseUnmarsalThrowable(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messageAck) <- (object as MessageAck)) {
            super.tightMarshal(messageAck, dataOut, bs)
            tightMarshalCachedObject<ActiveMQDestination>(messageAck.destination, dataOut, bs)
            tightMarshalCachedObject<TransactionId>(messageAck.transactionId, dataOut, bs)
            tightMarshalCachedObject<ConsumerId>(messageAck.consumerId, dataOut, bs)
            dataOut.putByte(messageAck.ackType)
            tightMarshalNestedObject<MessageId>(messageAck.firstMessageId, dataOut, bs)
            tightMarshalNestedObject<MessageId>(messageAck.lastMessageId, dataOut, bs)
            dataOut.putInt32(messageAck.messageCount)
            tightMarshalThrowable(messageAck.poisonCause, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messageAck) <- (data as MessageAck)) {
            super.tightUnmarshal(messageAck, dataIn, bs)
            messageAck.destination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            messageAck.transactionId = tightUnmarsalCachedObject<TransactionId>(dataIn, bs)
            messageAck.consumerId = tightUnmarsalCachedObject<ConsumerId>(dataIn, bs)
            messageAck.ackType = dataIn.getByte()
            messageAck.firstMessageId = tightUnmarshalNestedObject<MessageId>(dataIn, bs)
            messageAck.lastMessageId = tightUnmarshalNestedObject<MessageId>(dataIn, bs)
            messageAck.messageCount = dataIn.getInt32()
            messageAck.poisonCause = tightUnmarsalThrowable(dataIn, bs)
        }
    }

    public override func createObject(): MessageAck {
        return MessageAck()
    }
}
