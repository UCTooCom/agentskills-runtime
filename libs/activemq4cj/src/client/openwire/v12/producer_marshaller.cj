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

public class ProducerIdMarshaller <: BaseDataStreamMarshaller {

    // +------+--------------+-----------+--------+
    // | type | connectionId | sessionId | value  |
    // +------+--------------+-----------+--------+                                  
    // | Byte |   String     | Int64     | Int64  |
    // +------+--------------+-----------+--------+
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(producerId) <- (object as ProducerId)) {
            super.looseMarshal(producerId, dataOut)
            looseMarshalString(producerId.connectionId, dataOut)
            dataOut.putInt64(producerId.value)
            dataOut.putInt64(producerId.sessionId)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(producerId) <- (data as ProducerId)) {
            super.looseUnmarshal(producerId, dataIn)
            producerId.connectionId = looseUnmarshalString(dataIn)
            producerId.value = dataIn.getInt64()
            producerId.sessionId = dataIn.getInt64()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(producerId) <- (object as ProducerId)) {
            super.tightMarshal(producerId, dataOut, bs)
            tightMarshalString(producerId.connectionId, dataOut, bs)
            tightMarshalLong(producerId.value, dataOut, bs)
            tightMarshalLong(producerId.sessionId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(producerId) <- (data as ProducerId)) {
            super.tightUnmarshal(producerId, dataIn, bs)
            producerId.connectionId = tightUnmarshalString(dataIn, bs)
            producerId.value = tightUnmarshalLong(dataIn, bs)
            producerId.sessionId = tightUnmarshalLong(dataIn, bs)
        }
    }

    public override func createObject(): ProducerId {
        return ProducerId()
    }
}

public class ProducerInfoMarshaller <: BaseCommandMarshaller {
    //                                                           [=======if not null is 1=======================]              [==if not null is 1==]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+ [ +------+---------+ ]
    // | size | type | commandId | responseRequired | not null | [ |  type | connectionId | value | sessionId | ] | not null | [ | type | Name    | ]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+ [ +------+---------+ ]  ==>
    // | Int32| Byte |   Int32   |   Byte           | Byte     | [ |  Byte |  String      | Int64 | Int64     | ] | Byte     | [ | Byte | String  | ]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+ [ +------+---------+ ]
    //                                                           [========producerId============================]              [=====destination====]
    //                  [==========if not null is 1===================]
    //      +----------+ [ +------+--------+        +-------+--------+ ] +---------------+------------+
    //      | not null | [ | type | value  |        |type   | value  | ] | dispatchAsync | windowSize |
    // ==>  +----------+ [ +------+--------+  ..... +-------+--------+ ] +---------------+------------+
    //      | Byte     | [ | Byte | String |        | Byte  | String | ] |   Bool        |   Int32    |
    //      +----------+ [ +------+--------+        +-------+--------+ ] +---------------+------------+
    //                   [=========BrokerId Array======================]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(producerInfo) <- (object as ProducerInfo)) {
            super.looseMarshal(producerInfo, dataOut)
            //producerId
            looseMarshalCachedObject<ProducerId>(producerInfo.producerId, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(producerInfo.destination, dataOut)
            looseMarshalObjectArray<BrokerId>(producerInfo.brokerPath, dataOut)
            //dispatchAsync
            MarshallingSupport.putBool(producerInfo.dispatchAsync, dataOut)
            dataOut.putInt32(Int32(producerInfo.windowSize))
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(producerInfo) <- (data as ProducerInfo)) {
            super.looseUnmarshal(producerInfo, dataIn)
            producerInfo.producerId = looseUnmarsalCachedObject<ProducerId>(dataIn)
            producerInfo.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            if (MarshallingSupport.getBool(dataIn)) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- looseUnmarsalNestedObject<BrokerId>(dataIn)) {
                        brokerPath[j] = brokerId
                    }
                }
                producerInfo.brokerPath = brokerPath
            }
            producerInfo.dispatchAsync = MarshallingSupport.getBool(dataIn)
            producerInfo.windowSize = dataIn.getInt32()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(producerInfo) <- (object as ProducerInfo)) {
            super.tightMarshal(producerInfo, dataOut, bs)
            tightMarshalCachedObject<ProducerId>(producerInfo.producerId, dataOut, bs)
            tightMarshalCachedObject<ActiveMQDestination>(producerInfo.destination, dataOut, bs)
            tightMarshalObjectArray<BrokerId>(producerInfo.brokerPath, dataOut, bs)
            //dispatchAsync
            bs.writeBool(producerInfo.dispatchAsync)
            dataOut.putInt32(Int32(producerInfo.windowSize))
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(producerInfo) <- (data as ProducerInfo)) {
            super.tightUnmarshal(producerInfo, dataIn, bs)
            producerInfo.producerId = tightUnmarsalCachedObject<ProducerId>(dataIn, bs)
            producerInfo.destination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            if (bs.readBool()) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- tightUnmarshalNestedObject<BrokerId>(dataIn, bs)) {
                        brokerPath[j] = brokerId
                    }
                }
                producerInfo.brokerPath = brokerPath
            }
            producerInfo.dispatchAsync = bs.readBool()
            producerInfo.windowSize = dataIn.getInt32()
        }
    }

    public override func createObject(): ProducerInfo {
        return ProducerInfo()
    }
}
