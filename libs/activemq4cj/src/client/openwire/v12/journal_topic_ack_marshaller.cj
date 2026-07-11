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

public class JournalTopicAckMarshaller <: BaseDataStreamMarshaller {

    //                        [==if not null is 1=================]                [==if not null is 1=================]                                                                     [==if not null is 1=================]
    // +------+------------+ [ +------+------------------------+ ] +------------+ [ +------+------------------------+ ] +--------------------+--------------------+-----------+-----------+ [ +------+------------------------+ ]
    // | type | not null   | [ | type | command-specific-fields| ] | not null   | [ | type | command-specific-fields| ] | messageSequenceId  | subscritionName    | clientId  | not null  | [ | type | command-specific-fields| ]
    // +------+------------+ [ +------+------------------------+ ] +------------+ [ +------+------------------------+ ] +--------------------+--------------------+-----------+-----------+ [ +------+------------------------+ ]
    // | Byte | Byte       | [ | Byte |  variable sized        | ] | byte       | [ | Byte |  variable sized        | ] | Int64              | String             | String    | Byte      | [ | Byte |  variable sized        | ]
    // +------+------------+ [ +------+------------------------+ ] +------------+ [ +------+------------------------+ ] +--------------------+--------------------+-----------+-----------+ [ +------+------------------------+ ]
    //                       [=======ActiveMQDestination=========]                [============MessageId==============]                                                                     [===========TransactionId===========]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(journalTopicAck) <- (object as JournalTopicAck)) {
            super.looseMarshal(journalTopicAck, dataOut)
            looseMarshalNestedObject<ActiveMQDestination>(journalTopicAck.destination, dataOut)
            looseMarshalNestedObject<MessageId>(journalTopicAck.messageId, dataOut)
            dataOut.putInt64(journalTopicAck.messageSequenceId)
            looseMarshalString(journalTopicAck.subscritionName, dataOut)
            looseMarshalString(journalTopicAck.clientId, dataOut)
            looseMarshalNestedObject<TransactionId>(journalTopicAck.transactionId, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(journalTopicAck) <- (data as JournalTopicAck)) {
            super.looseUnmarshal(journalTopicAck, dataIn)
            journalTopicAck.destination = looseUnmarsalNestedObject<ActiveMQDestination>(dataIn)
            journalTopicAck.messageId = looseUnmarsalNestedObject<MessageId>(dataIn)
            journalTopicAck.messageSequenceId = dataIn.getInt64()
            journalTopicAck.subscritionName = looseUnmarshalString(dataIn)
            journalTopicAck.clientId = looseUnmarshalString(dataIn)
            journalTopicAck.transactionId = looseUnmarsalNestedObject<TransactionId>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(journalTopicAck) <- (object as JournalTopicAck)) {
            super.tightMarshal(journalTopicAck, dataOut, bs)
            tightMarshalNestedObject<ActiveMQDestination>(journalTopicAck.destination, dataOut, bs)
            tightMarshalNestedObject<MessageId>(journalTopicAck.messageId, dataOut, bs)
            tightMarshalLong(journalTopicAck.messageSequenceId, dataOut, bs)
            tightMarshalString(journalTopicAck.subscritionName, dataOut, bs)
            tightMarshalString(journalTopicAck.clientId, dataOut, bs)
            tightMarshalNestedObject<TransactionId>(journalTopicAck.transactionId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(journalTopicAck) <- (data as JournalTopicAck)) {
            super.tightUnmarshal(journalTopicAck, dataIn, bs)
            journalTopicAck.destination = tightUnmarshalNestedObject<ActiveMQDestination>(dataIn, bs)
            journalTopicAck.messageId = tightUnmarshalNestedObject<MessageId>(dataIn, bs)
            journalTopicAck.messageSequenceId = tightUnmarshalLong(dataIn, bs)
            journalTopicAck.subscritionName = tightUnmarshalString(dataIn, bs)
            journalTopicAck.clientId = tightUnmarshalString(dataIn, bs)
            journalTopicAck.transactionId = tightUnmarshalNestedObject<TransactionId>(dataIn, bs)
        }
    }

    public override func createObject(): JournalTopicAck {
        return JournalTopicAck()
    }
}
