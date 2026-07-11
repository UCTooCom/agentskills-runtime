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

public class JournalTransactionMarshaller <: BaseDataStreamMarshaller {

    //                       [==if not null is 1=================]
    // +------+------------+ [ +------+------------------------+ ] +------------+-------------+
    // | type | not null   | [ | type | command-specific-fields| ] | type       | wasPrepared |
    // +------+------------+ [ +------+------------------------+ ] +------------+-------------+
    // | Byte | Byte       | [ | Byte |  variable sized        | ] | byte       | Bool        |
    // +------+------------+ [ +------+------------------------+ ] +------------+-------------+
    //                       [==========TransactionId============]
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(journalTransaction) <- (object as JournalTransaction)) {
            super.looseMarshal(journalTransaction, dataOut)
            looseMarshalNestedObject<TransactionId>(journalTransaction.transactionId, dataOut)
            dataOut.putByte(journalTransaction.transactionType)
            MarshallingSupport.putBool(journalTransaction.wasPrepared, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(journalTransaction) <- (data as JournalTransaction)) {
            super.looseUnmarshal(journalTransaction, dataIn)
            journalTransaction.transactionId = looseUnmarsalNestedObject<TransactionId>(dataIn)
            journalTransaction.transactionType = dataIn.getByte()
            journalTransaction.wasPrepared = MarshallingSupport.getBool(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(journalTransaction) <- (object as JournalTransaction)) {
            super.tightMarshal(journalTransaction, dataOut, bs)
            tightMarshalNestedObject<TransactionId>(journalTransaction.transactionId, dataOut, bs)
            dataOut.putByte(journalTransaction.transactionType)
            bs.writeBool(journalTransaction.wasPrepared)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(journalTransaction) <- (data as JournalTransaction)) {
            super.tightUnmarshal(journalTransaction, dataIn, bs)
            journalTransaction.transactionId = tightUnmarshalNestedObject<TransactionId>(dataIn, bs)
            journalTransaction.transactionType = dataIn.getByte()
            journalTransaction.wasPrepared = bs.readBool()
        }
    }

    public override func createObject(): JournalTransaction {
        return JournalTransaction()
    }
}
