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

public class MessagePullMarshaller <: BaseCommandMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(messagePull) <- (object as MessagePull)) {
            super.looseMarshal(messagePull, dataOut)
            looseMarshalCachedObject<ConsumerId>(messagePull.consumerId, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(messagePull.destination, dataOut)
            dataOut.putInt64(messagePull.timeout)
            looseMarshalString(messagePull.correlationId, dataOut)
            looseMarshalNestedObject<MessageId>(messagePull.messageId, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(messagePull) <- (data as MessagePull)) {
            super.looseUnmarshal(messagePull, dataIn)
            messagePull.consumerId = looseUnmarsalCachedObject<ConsumerId>(dataIn)
            messagePull.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            messagePull.timeout = dataIn.getInt64()
            looseUnmarshalString(dataIn)
            messagePull.messageId = looseUnmarsalNestedObject<MessageId>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messagePull) <- (object as MessagePull)) {
            super.tightMarshal(messagePull, dataOut, bs)
            tightMarshalCachedObject<ConsumerId>(messagePull.consumerId, dataOut, bs)
            tightMarshalCachedObject<ActiveMQDestination>(messagePull.destination, dataOut, bs)
            tightMarshalLong(messagePull.timeout, dataOut, bs)
            tightMarshalString(messagePull.correlationId, dataOut, bs)
            tightMarshalNestedObject<MessageId>(messagePull.messageId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(messagePull) <- (data as MessagePull)) {
            super.tightUnmarshal(messagePull, dataIn, bs)
            messagePull.consumerId = tightUnmarsalCachedObject<ConsumerId>(dataIn, bs)
            messagePull.destination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            messagePull.timeout = tightUnmarshalLong(dataIn, bs)
            tightUnmarshalString(dataIn, bs)
            messagePull.messageId = tightUnmarshalNestedObject<MessageId>(dataIn, bs)
        }
    }

    public override func createObject(): MessagePull {
        return MessagePull()
    }
}
