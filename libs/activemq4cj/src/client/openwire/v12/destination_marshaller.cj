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

public abstract class ActiveMQDestinationMarshaller <: BaseDataStreamMarshaller {
    public open func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(destination) <- (object as ActiveMQDestination)) {
            super.looseMarshal(destination, dataOut)
            looseMarshalString(destination.name, dataOut)
        }
    }

    public open func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(destination) <- (data as ActiveMQDestination)) {
            super.looseUnmarshal(destination, dataIn)
            destination.name = looseUnmarshalString(dataIn)
        }
    }

    public open func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(destination) <- (object as ActiveMQDestination)) {
            super.tightMarshal(destination, dataOut, bs)
            tightMarshalString(destination.name, dataOut, bs)
        }
    }

    public open func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(destination) <- (data as ActiveMQDestination)) {
            super.tightUnmarshal(destination, dataIn, bs)
            destination.name = tightUnmarshalString(dataIn, bs)
        }
    }
}

public class ActiveMQQueueMarshaller <: ActiveMQDestinationMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(activeMQQueue) <- (object as ActiveMQQueue)) {
            super.looseMarshal(activeMQQueue, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQQueue) <- (data as ActiveMQQueue)) {
            activeMQQueue.name = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQQueue) <- (object as ActiveMQQueue)) {
            super.tightMarshal(activeMQQueue, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQQueue) <- (data as ActiveMQQueue)) {
            activeMQQueue.name = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQQueue {
        return ActiveMQQueue()
    }
}

public class ActiveMQTempQueueMarshaller <: ActiveMQDestinationMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(queue) <- (object as ActiveMQTempQueue)) {
            super.looseMarshal(queue, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(activeMQTempQueue) <- (data as ActiveMQTempQueue)) {
            activeMQTempQueue.name = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQTempQueue) <- (object as ActiveMQTempQueue)) {
            super.tightMarshal(activeMQTempQueue, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(activeMQTempQueue) <- (data as ActiveMQTempQueue)) {
            activeMQTempQueue.name = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQTempQueue {
        return ActiveMQTempQueue()
    }
}

public class ActiveMQTopicMarshaller <: ActiveMQDestinationMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(topic) <- (object as ActiveMQTopic)) {
            super.looseMarshal(topic, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(topic) <- (data as ActiveMQTopic)) {
            topic.name = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(topic) <- (object as ActiveMQTopic)) {
            super.tightMarshal(topic, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(topic) <- (data as ActiveMQTopic)) {
            topic.name = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQTopic {
        return ActiveMQTopic()
    }
}

public class ActiveMQTempTopicMarshaller <: ActiveMQDestinationMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(topic) <- (object as ActiveMQTempTopic)) {
            super.looseMarshal(topic, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(topic) <- (data as ActiveMQTempTopic)) {
            topic.name = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(topic) <- (object as ActiveMQTempTopic)) {
            super.tightMarshal(topic, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(topic) <- (data as ActiveMQTempTopic)) {
            topic.name = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): ActiveMQTempTopic {
        return ActiveMQTempTopic()
    }
}

public class DestinationInfoMarshaller <: BaseCommandMarshaller {

    //                             [===if not null is 1===]              [==if not null is 1=================]              [==========if not null is 1============]
    // +-------+------+----------+ [ +-------+---------+ ] +----------+ [ +------+------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------------+-----------
    // | size  | type | not null | [ |  type | value   | ] | not null | [ | type | command-specific-fields| ] | not null | [ | type | command-specific-fields   | ] | operationType  | timeout  |
    // +-------+------+----------+ [ +-------+---------+ ] +----------+ [ +------+------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------------+----------+
    // | Int32 | Byte | Byte     | [ |  Byte |  String | ] | Byte     | [ | Byte |  variable sized        | ] | Byte     | [ | Byte |   variable sized          | ] |   Byte         | Int64    |
    // +-------+------+----------+ [ +-------+---------+ ] +----------+ [ +------+------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------------+----------+
    //                             [====ConnectionId=====]              [=========ActiveMQDestination=======]              [============TransactionId=============]

    //                   [==if not null is 1==================]              [==========if not null is 1============]              [==========if not null is 1============]
    //      +----------+ [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+
    //      | not null | [ | type | command-specific-fields | ] | not null | [ | type | command-specific-fields   | ] | not null | [ | type | command-specific-fields   | ] | groupID  |
    // ==>  +----------+ [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+  ==>
    //      | Byte     | [ | Byte | variable sized          | ] | Byte     | [ | Byte |   variable sized          | ] | Byte     | [ | Byte |   variable sized          | ] | String   |
    //      +----------+ [ +------+-------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+ [ +------+---------------------------+ ] +----------+
    //                   [=======ActiveMQDestination==========]              [==============MessageId===============]              [============TransactionId=============]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(destinationInfo) <- (object as DestinationInfo)) {
            super.looseMarshal(destinationInfo, dataOut)
            looseMarshalCachedObject<ConnectionId>(destinationInfo.connectionId, dataOut)
            looseMarshalCachedObject<ActiveMQDestination>(destinationInfo.destination, dataOut)
            dataOut.putByte(destinationInfo.operationType)
            dataOut.putInt64(destinationInfo.timeout)
            looseMarshalObjectArray<BrokerId>(destinationInfo.brokerPath, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(destinationInfo) <- (data as DestinationInfo)) {
            super.looseUnmarshal(destinationInfo, dataIn)
            destinationInfo.connectionId = looseUnmarsalCachedObject<ConnectionId>(dataIn)
            destinationInfo.destination = looseUnmarsalCachedObject<ActiveMQDestination>(dataIn)
            destinationInfo.operationType = dataIn.getByte()
            destinationInfo.timeout = dataIn.getInt64()
            if (MarshallingSupport.getBool(dataIn)) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- looseUnmarsalNestedObject<BrokerId>(dataIn)) {
                        brokerPath[j] = brokerId
                    }
                }
                destinationInfo.brokerPath = brokerPath
            }
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(destinationInfo) <- (object as DestinationInfo)) {
            super.tightMarshal(destinationInfo, dataOut, bs)
            tightMarshalCachedObject<ConnectionId>(destinationInfo.connectionId, dataOut, bs)
            tightMarshalCachedObject<ActiveMQDestination>(destinationInfo.destination, dataOut, bs)
            dataOut.putByte(destinationInfo.operationType)
            tightMarshalLong(destinationInfo.timeout, dataOut, bs)
            tightMarshalObjectArray<BrokerId>(destinationInfo.brokerPath, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(destinationInfo) <- (data as DestinationInfo)) {
            super.tightUnmarshal(destinationInfo, dataIn, bs)
            destinationInfo.connectionId = tightUnmarsalCachedObject<ConnectionId>(dataIn, bs)
            destinationInfo.destination = tightUnmarsalCachedObject<ActiveMQDestination>(dataIn, bs)
            destinationInfo.operationType = dataIn.getByte()
            destinationInfo.timeout = tightUnmarshalLong(dataIn, bs)
            if (bs.readBool()) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- tightUnmarshalNestedObject<BrokerId>(dataIn, bs)) {
                        brokerPath[j] = brokerId
                    }
                }
                destinationInfo.brokerPath = brokerPath
            }
        }
    }

    public override func createObject(): DestinationInfo {
        return DestinationInfo()
    }
}
