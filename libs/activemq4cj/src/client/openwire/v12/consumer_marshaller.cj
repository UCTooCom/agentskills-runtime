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

public class ConsumerIdMarshaller <: BaseDataStreamMarshaller {
    // +-------+--------------+-------+-----------+
    // |  type | connectionId | value | sessionId |
    // +-------+--------------+-------+-----------+                                       
    // |  Byte |  String      | Int64 | Int64     |    
    // +-------+--------------+-------+-----------+

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(consumerId) <- (object as ConsumerId)) {
            super.looseMarshal(consumerId, dataOut)
            looseMarshalString(consumerId.connectionId, dataOut)
            dataOut.putInt64(consumerId.sessionId)
            dataOut.putInt64(consumerId.value)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(consumerId) <- (data as ConsumerId)) {
            consumerId.connectionId = looseUnmarshalString(dataIn)
            consumerId.sessionId = dataIn.getInt64()
            consumerId.value = dataIn.getInt64()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(consumerId) <- (object as ConsumerId)) {
            super.tightMarshal(consumerId, dataOut, bs)
            tightMarshalString(consumerId.connectionId, dataOut, bs)
            tightMarshalLong(consumerId.sessionId, dataOut, bs)
            tightMarshalLong(consumerId.value, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(consumerId) <- (data as ConsumerId)) {
            super.tightUnmarshal(consumerId, dataIn, bs)
            consumerId.connectionId = tightUnmarshalString(dataIn, bs)
            consumerId.sessionId = tightUnmarshalLong(dataIn, bs)
            consumerId.value = tightUnmarshalLong(dataIn, bs)
        }
    }

    public override func createObject(): ConsumerId {
        return ConsumerId()
    }
}

public class ConsumerInfoMarshaller <: BaseCommandMarshaller {

    //                                                           [=======if not null is 1=======================]                         [==if not null is 1==]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+----------+ [ +------+---------+ ]  +------------+
    // | size | type | commandId | responseRequired | not null | [ |  type | connectionId | value | sessionId | ] |  browser | not null | [ | type | Name    | ]  |prefetchSize|
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+----------+ [ +------+---------+ ]  +------------+  ==>
    // | Int32| Byte |   Int32   |   Byte           | Byte     | [ |  Byte |  String      | Int64 | Int64     | ] |  Bool    | Byte     | [ | Byte | String  | ]  |Int32       |
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+-----------+ ] +----------+----------+ [ +------+---------+ ]  +------------+
    //                                                           [========ConsumerId============================]                         [===ActiveMQTopic====]
    //                                                                                                                                                          [==if not null is 1=============================]
    //     +----------------------------+---------------+----------+-------------------+---------+-----------+-------------+----------+------------+----------+ [ +------+----------+------------+------------+ ]
    //     | maximumPendingMessageLimit | dispatchAsync | selector | subscriptionName  | noLocal | exclusive | retroactive | priority | brokerPath | not null | [ | type | BrokerId | messageTTL | consumerTTL| ]
    // ==> +----------------------------+---------------+----------+-------------------+---------+-----------+-------------+----------+------------+----------| [ +------+----------+------------+------------+ ] ==>
    //     | Int32                      | Bool          | String   |   String          | Bool    | Bool      | Bool        | Byte     | ByteArray  | Byte     | [ | Byte | BROKER_ID| Int32      |  Int32     | ]
    //     +----------------------------+---------------+----------+-------------------+---------+-----------+-------------+----------+------------+----------| [ +------+----------+------------+------------+ ]
    //                                                                                                                                                          [===============================================]
    //     +---------------------+----------------------+-------------+----------------------+
    //     | networkSubscription | optimizedAcknowledge | noRangeAcks | networkConsumerPath  |
    // ==> +---------------------+----------------------+-------------+----------------------+
    //     | Bool                | Bool                 | Bool        |   ByteArray          |
    //     +---------------------+----------------------+-------------+----------------------+

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(consumerInfo) <- (object as ConsumerInfo)) {
            super.looseMarshal(consumerInfo, dataOut)
            looseMarshalCachedObject<ConsumerId>(consumerInfo.consumerId, dataOut)
            MarshallingSupport.putBool(consumerInfo.browser, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(consumerInfo.destination, dataOut)
            dataOut.putInt32(consumerInfo.prefetchSize)
            dataOut.putInt32(consumerInfo.maximumPendingMessageLimit)
            MarshallingSupport.putBool(consumerInfo.dispatchAsync, dataOut)
            looseMarshalString(consumerInfo.selector, dataOut)
            looseMarshalString(consumerInfo.clientId, dataOut)
            looseMarshalString(consumerInfo.subscriptionName, dataOut)
            MarshallingSupport.putBool(consumerInfo.noLocal, dataOut)
            MarshallingSupport.putBool(consumerInfo.exclusive, dataOut)
            MarshallingSupport.putBool(consumerInfo.retroactive, dataOut)
            dataOut.putByte(consumerInfo.priority)
            looseMarshalObjectArray<BrokerId>(consumerInfo.brokerPath, dataOut)
            looseMarshalNestedObject<BooleanExpression>(consumerInfo.additionalPredicate, dataOut)
            MarshallingSupport.putBool(consumerInfo.networkSubscription, dataOut)
            MarshallingSupport.putBool(consumerInfo.optimizedAcknowledge, dataOut)
            MarshallingSupport.putBool(consumerInfo.noRangeAcks, dataOut)
            looseMarshalObjectArray<ConsumerId>(consumerInfo.networkConsumerIds, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(consumerInfo) <- (data as ConsumerInfo)) {
            super.looseUnmarshal(consumerInfo, dataIn)
            consumerInfo.consumerId = looseUnmarsalCachedObject<ConsumerId>(dataIn)
            consumerInfo.browser = MarshallingSupport.getBool(dataIn)
            consumerInfo.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            consumerInfo.prefetchSize = dataIn.getInt32()
            consumerInfo.maximumPendingMessageLimit = dataIn.getInt32()
            consumerInfo.dispatchAsync = MarshallingSupport.getBool(dataIn)
            consumerInfo.selector = looseUnmarshalString(dataIn)
            consumerInfo.clientId = looseUnmarshalString(dataIn)
            consumerInfo.subscriptionName = looseUnmarshalString(dataIn)
            consumerInfo.noLocal = MarshallingSupport.getBool(dataIn)
            consumerInfo.exclusive = MarshallingSupport.getBool(dataIn)
            consumerInfo.retroactive = MarshallingSupport.getBool(dataIn)
            consumerInfo.priority = UInt8(dataIn.getInt8())
            if (MarshallingSupport.getBool(dataIn)) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- looseUnmarsalNestedObject<BrokerId>(dataIn)) {
                        brokerPath[j] = brokerId
                    }
                }
                consumerInfo.brokerPath = brokerPath
            }
            consumerInfo.additionalPredicate = looseUnmarsalNestedObject<BooleanExpression>(dataIn)
            consumerInfo.networkSubscription = MarshallingSupport.getBool(dataIn)
            consumerInfo.optimizedAcknowledge = MarshallingSupport.getBool(dataIn)
            consumerInfo.noRangeAcks = MarshallingSupport.getBool(dataIn)
            if (MarshallingSupport.getBool(dataIn)) {
                let size = Int64(dataIn.getInt16())
                let consumerIds = Array<ConsumerId>(size, repeat: ConsumerId())
                for (j in 0..size) {
                    if (let Some(consumerId) <- looseUnmarsalNestedObject<ConsumerId>(dataIn)) {
                        consumerIds[j] = consumerId
                    }
                }
                consumerInfo.networkConsumerIds = consumerIds
            }
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(consumerInfo) <- (object as ConsumerInfo)) {
            super.tightMarshal(consumerInfo, dataOut, bs)
            tightMarshalCachedObject<ConsumerId>(consumerInfo.consumerId, dataOut, bs)
            bs.writeBool(consumerInfo.browser)
            tightMarshalCachedObject<ActiveMQDestination>(consumerInfo.destination, dataOut, bs)
            dataOut.putInt32(consumerInfo.prefetchSize)
            dataOut.putInt32(consumerInfo.maximumPendingMessageLimit)
            bs.writeBool(consumerInfo.dispatchAsync)
            tightMarshalString(consumerInfo.selector, dataOut, bs)
            tightMarshalString(consumerInfo.clientId, dataOut, bs)
            tightMarshalString(consumerInfo.subscriptionName, dataOut, bs)
            bs.writeBool(consumerInfo.noLocal)
            bs.writeBool(consumerInfo.exclusive)
            bs.writeBool(consumerInfo.retroactive)
            dataOut.putByte(consumerInfo.priority)
            tightMarshalObjectArray<BrokerId>(consumerInfo.brokerPath, dataOut, bs)
            tightMarshalNestedObject<BooleanExpression>(consumerInfo.additionalPredicate, dataOut, bs)
            bs.writeBool(consumerInfo.networkSubscription)
            bs.writeBool(consumerInfo.optimizedAcknowledge)
            bs.writeBool(consumerInfo.noRangeAcks)
            tightMarshalObjectArray<ConsumerId>(consumerInfo.networkConsumerIds, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(consumerInfo) <- (data as ConsumerInfo)) {
            super.tightUnmarshal(consumerInfo, dataIn, bs)
            consumerInfo.consumerId = tightUnmarsalCachedObject<ConsumerId>(dataIn, bs)
            consumerInfo.browser = bs.readBool()
            consumerInfo.destination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            consumerInfo.prefetchSize = dataIn.getInt32()
            consumerInfo.maximumPendingMessageLimit = dataIn.getInt32()
            consumerInfo.dispatchAsync = bs.readBool()
            consumerInfo.selector = tightUnmarshalString(dataIn, bs)
            consumerInfo.clientId = tightUnmarshalString(dataIn, bs)
            consumerInfo.subscriptionName = tightUnmarshalString(dataIn, bs)
            consumerInfo.noLocal = bs.readBool()
            consumerInfo.exclusive = bs.readBool()
            consumerInfo.retroactive = bs.readBool()
            consumerInfo.priority = UInt8(dataIn.getInt8())
            if (bs.readBool()) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- tightUnmarshalNestedObject<BrokerId>(dataIn, bs)) {
                        brokerPath[j] = brokerId
                    }
                }
                consumerInfo.brokerPath = brokerPath
            }
            consumerInfo.additionalPredicate = tightUnmarshalNestedObject<BooleanExpression>(dataIn, bs)
            consumerInfo.networkSubscription = bs.readBool()
            consumerInfo.optimizedAcknowledge = bs.readBool()
            consumerInfo.noRangeAcks = bs.readBool()
            if (bs.readBool()) {
                let size = Int64(dataIn.getInt16())
                let consumerIds = Array<ConsumerId>(size, repeat: ConsumerId())
                for (j in 0..size) {
                    if (let Some(consumerId) <- tightUnmarshalNestedObject<ConsumerId>(dataIn, bs)) {
                        consumerIds[j] = consumerId
                    }
                }
                consumerInfo.networkConsumerIds = consumerIds
            }
        }
    }

    public override func createObject(): ConsumerInfo {
        return ConsumerInfo()
    }
}
