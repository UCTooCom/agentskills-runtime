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

public class LocalTransactionIdMarshaller <: BaseDataStreamMarshaller {

    //                                 [==if not null is 1=========]    
    // +------+-----------+----------+ [ +-------+--------------+  ] 
    // | type |   value   | not null | [ |  type | value        |  ] 
    // +------+-----------+----------+ [ +-------+--------------+  ]                                           
    // | Byte |   Int64   | Byte     | [ |  Byte |  String      |  ]    
    // +------+-----------+----------+ [ +-------+--------------+  ]                                
    //                                 [=========connectionId======]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(localTransactionId) <- (object as LocalTransactionId)) {
            super.looseMarshal(localTransactionId, dataOut)
            dataOut.putInt64(localTransactionId.value)
            looseMarshalCachedObject<ConnectionId>(localTransactionId.connectionId, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(localTransactionId) <- (data as LocalTransactionId)) {
            super.looseUnmarshal(localTransactionId, dataIn)
            localTransactionId.value = dataIn.getInt64()
            localTransactionId.connectionId = looseUnmarsalCachedObject<ConnectionId>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(localTransactionId) <- (object as LocalTransactionId)) {
            super.tightMarshal(localTransactionId, dataOut, bs)
            tightMarshalLong(localTransactionId.value, dataOut, bs)
            tightMarshalCachedObject<ConnectionId>(localTransactionId.connectionId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(localTransactionId) <- (data as LocalTransactionId)) {
            super.tightUnmarshal(localTransactionId, dataIn, bs)
            localTransactionId.value = tightUnmarshalLong(dataIn, bs)
            localTransactionId.connectionId = tightUnmarsalCachedObject<ConnectionId>(dataIn, bs)
        }
    }

    public override func createObject(): LocalTransactionId {
        return LocalTransactionId()
    }
}

public class XATransactionIdMarshaller <: BaseDataStreamMarshaller {
    //
    // +------+----------+-----------------+---------------------+
    // | type | formatId | branchQualifier | globalTransactionId |
    // +------+----------+-----------------+---------------------+
    // | Byte |  Int32   | ByteArray       | ByteArray           |
    // +------+----------+-----------------+---------------------+
    //

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(xaTransactionId) <- (object as XATransactionId)) {
            super.looseMarshal(xaTransactionId, dataOut)
            dataOut.putInt32(xaTransactionId.formatId)
            looseMarshalByteArray(xaTransactionId.globalTransactionId, dataOut)
            looseMarshalByteArray(xaTransactionId.branchQualifier, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(xaTransactionId) <- (data as XATransactionId)) {
            super.looseUnmarshal(xaTransactionId, dataIn)
            xaTransactionId.formatId = dataIn.getInt32()
            xaTransactionId.globalTransactionId = looseUnmarshalByteArray(dataIn)
            xaTransactionId.branchQualifier = looseUnmarshalByteArray(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(xaTransactionId) <- (object as XATransactionId)) {
            super.tightMarshal(xaTransactionId, dataOut, bs)
            dataOut.putInt32(xaTransactionId.formatId)
            tightMarshalByteArray(xaTransactionId.globalTransactionId, dataOut, bs)
            tightMarshalByteArray(xaTransactionId.branchQualifier, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(xaTransactionId) <- (data as XATransactionId)) {
            super.tightUnmarshal(xaTransactionId, dataIn, bs)
            xaTransactionId.formatId = dataIn.getInt32()
            xaTransactionId.globalTransactionId = tightUnmarshalByteArray(dataIn, bs)
            xaTransactionId.branchQualifier = tightUnmarshalByteArray(dataIn, bs)
        }
    }

    public override func createObject(): XATransactionId {
        return XATransactionId()
    }
}

public class TransactionInfoMarshaller <: BaseCommandMarshaller {

    //                                                           [===if not null is 1==]              [===========if not null is 1============]
    // +------+------+-----------+------------------+----------+ [ +-------+---------+ ] +----------+ [ +------+----------------------------+ ]  +------+
    // | size | type | commandId | responseRequired | not null | [ |  type | value   | ] | not null | [ | type | command-specific-fields    | ]  | type |
    // +------+------+-----------+------------------+----------+ [ +-------+---------+-] +----------+ [ +------+----------------------------+ ]  +------+
    // | Int32| Byte |   Int32   |   Byte           | Byte     | [ |  Byte |  String | ] | Byte     | [ | Byte | variable sized             | ]  | Byte |
    // +------+------+-----------+------------------+----------+ [ +-------+---------+-] +----------+ [ +------+----------------------------+ ]  +------+
    //                                                           [=====ConnectionId====]              [=====TransactionId=====================]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(transactionInfo) <- (object as TransactionInfo)) {
            super.looseMarshal(transactionInfo, dataOut)
            looseMarshalCachedObject<ConnectionId>(transactionInfo.connectionId, dataOut)
            looseMarshalCachedObject<TransactionId>(transactionInfo.transactionId, dataOut)
            dataOut.putByte(transactionInfo.transactionType)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(transactionInfo) <- (data as TransactionInfo)) {
            super.looseUnmarshal(transactionInfo, dataIn)
            transactionInfo.connectionId = looseUnmarsalCachedObject<ConnectionId>(dataIn)
            transactionInfo.transactionId = looseUnmarsalCachedObject<TransactionId>(dataIn)
            transactionInfo.transactionType = dataIn.getByte()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(transactionInfo) <- (object as TransactionInfo)) {
            super.tightMarshal(transactionInfo, dataOut, bs)
            tightMarshalCachedObject<ConnectionId>(transactionInfo.connectionId, dataOut, bs)
            tightMarshalCachedObject<TransactionId>(transactionInfo.transactionId, dataOut, bs)
            dataOut.putByte(transactionInfo.transactionType)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(transactionInfo) <- (data as TransactionInfo)) {
            super.tightUnmarshal(transactionInfo, dataIn, bs)
            transactionInfo.connectionId = tightUnmarsalCachedObject<ConnectionId>(dataIn, bs)
            transactionInfo.transactionId = tightUnmarsalCachedObject<TransactionId>(dataIn, bs)
            transactionInfo.transactionType = dataIn.getByte()
        }
    }

    public override func createObject(): TransactionInfo {
        return TransactionInfo()
    }
}
