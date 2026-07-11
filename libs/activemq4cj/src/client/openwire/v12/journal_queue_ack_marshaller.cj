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

public class JournalQueueAckMarshaller <: BaseDataStreamMarshaller {

    //                       [==if not null is 1=================]                [==if not null is 1=================]
    // +------+------------+ [ +------+------------------------+ ] +------------+ [ +------+------------------------+ ] 
    // | type | not null   | [ | type | command-specific-fields| ] | not null   | [ | type | command-specific-fields| ] 
    // +------+------------+ [ +------+------------------------+ ] +------------+ [ +------+------------------------+ ] 
    // | Byte | Byte       | [ | Byte |  variable sized        | ] | byte       | [ | Byte |  variable sized        | ] 
    // +------+------------+ [ +------+------------------------+ ] +------------+ [ +------+------------------------+ ] 
    //                       [=======ActiveMQDestination=========]                [============MessageAck=============]  
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(journalQueueAck) <- (object as JournalQueueAck)) {
            super.looseMarshal(journalQueueAck, dataOut)
            looseMarshalNestedObject<ActiveMQDestination>(journalQueueAck.destination, dataOut)
            looseMarshalNestedObject<MessageAck>(journalQueueAck.messageAck, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(journalQueueAck) <- (data as JournalQueueAck)) {
            super.looseUnmarshal(journalQueueAck, dataIn)
            journalQueueAck.destination = looseUnmarsalNestedObject<ActiveMQDestination>(dataIn)
            journalQueueAck.messageAck = looseUnmarsalNestedObject<MessageAck>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(journalQueueAck) <- (object as JournalQueueAck)) {
            super.tightMarshal(journalQueueAck, dataOut, bs)
            tightMarshalNestedObject<ActiveMQDestination>(journalQueueAck.destination, dataOut, bs)
            tightMarshalNestedObject<MessageAck>(journalQueueAck.messageAck, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(journalQueueAck) <- (data as JournalQueueAck)) {
            super.tightUnmarshal(journalQueueAck, dataIn, bs)
            journalQueueAck.destination = tightUnmarshalNestedObject<ActiveMQDestination>(dataIn, bs)
            journalQueueAck.messageAck = tightUnmarshalNestedObject<MessageAck>(dataIn, bs)
        }
    }

    public override func createObject(): JournalQueueAck {
        return JournalQueueAck()
    }
}
