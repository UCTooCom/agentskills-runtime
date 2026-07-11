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

public class ConsumerControlMarshaller <: BaseCommandMarshaller {

    //                                                            [==if not null is 1=================]                       [==if not null is 1=================]
    //   +------+------+-----------+------------------+----------+  [ +------+------------------------+ ] +-------+----------+  [ +------+------------------------+ ]  +-----------+-----------+-----------+-----------+
    //   | size | type | commandId | responseRequired | not null |  [ | type | command-specific-fields| ] | close | not null |  [ | type | command-specific-fields| ]  | prefetch  | flush     | start     | stop      |
    //   +------+------+-----------+------------------+----------+  [ +------+------------------------+ ] +-------+----------+  [ +------+------------------------+ ]  +-----------+-----------+-----------+-----------+
    //   | Int32| Byte |   Int32   |   Byte           | Byte     |  [ | Byte |  variable sized        | ] | Bool  | Byte     |  [ | Byte |  variable sized        | ]  | Int32     | Bool      | Bool      | Bool      |
    //   +------+------+-----------+------------------+----------+  [ +------+------------------------+ ] +-------+----------+  [ +------+------------------------+ ]  +-----------+-----------+-----------+-----------+
    //                                                              [=========ActiveMQDestination=======]                       [=========ConsumerId================]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(consumerControl) <- (object as ConsumerControl)) {
            super.looseMarshal(consumerControl, dataOut)
            looseMarshalNestedObject<ActiveMQDestination>(consumerControl.destination, dataOut)
            MarshallingSupport.putBool(consumerControl.close, dataOut)
            looseMarshalNestedObject<ConsumerId>(consumerControl.consumerId, dataOut)
            dataOut.putInt32(consumerControl.prefetch)
            MarshallingSupport.putBool(consumerControl.flush, dataOut)
            MarshallingSupport.putBool(consumerControl.start, dataOut)
            MarshallingSupport.putBool(consumerControl.stop, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(consumerControl) <- (data as ConsumerControl)) {
            super.looseUnmarshal(consumerControl, dataIn)
            consumerControl.destination = looseUnmarsalNestedObject<ActiveMQDestination>(dataIn)
            consumerControl.close = MarshallingSupport.getBool(dataIn)
            consumerControl.consumerId = looseUnmarsalNestedObject<ConsumerId>(dataIn)
            consumerControl.prefetch = dataIn.getInt32()
            consumerControl.flush = MarshallingSupport.getBool(dataIn)
            consumerControl.start = MarshallingSupport.getBool(dataIn)
            consumerControl.stop = MarshallingSupport.getBool(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(consumerControl) <- (object as ConsumerControl)) {
            super.tightMarshal(consumerControl, dataOut, bs)
            tightMarshalNestedObject<ActiveMQDestination>(consumerControl.destination, dataOut, bs)
            bs.writeBool(consumerControl.close)
            tightMarshalNestedObject<ConsumerId>(consumerControl.consumerId, dataOut, bs)
            dataOut.putInt32(consumerControl.prefetch)
            bs.writeBool(consumerControl.flush)
            bs.writeBool(consumerControl.start)
            bs.writeBool(consumerControl.stop)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(consumerControl) <- (data as ConsumerControl)) {
            super.tightUnmarshal(consumerControl, dataIn, bs)
            consumerControl.destination = tightUnmarshalNestedObject<ActiveMQDestination>(dataIn, bs)
            consumerControl.close = bs.readBool()
            consumerControl.consumerId = tightUnmarshalNestedObject<ConsumerId>(dataIn, bs)
            consumerControl.prefetch = dataIn.getInt32()
            consumerControl.flush = bs.readBool()
            consumerControl.start = bs.readBool()
            consumerControl.stop = bs.readBool()
        }
    }

    public override func createObject(): ConsumerControl {
        return ConsumerControl()
    }
}
