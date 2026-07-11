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

public class NetworkBridgeFilterMarshaller <: BaseDataStreamMarshaller {

    //                        [==if not null is 1=================]
    //   +------+----------+  [ +------+------------------------+ ] +------------+-------------+
    //   | type | not null |  [ | type | command-specific-fields| ] | messageTTL | consumerTTL |
    //   +------+----------+  [ +------+------------------------+ ] +------------+-------------+
    //   | Byte | Byte     |  [ | Byte |  variable sized        | ] | Int32      | Int32       |
    //   +------+----------+  [ +------+------------------------+ ] +------------+-------------+
    //                        [===========BrokerId================]
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(networkBridgeFilter) <- (object as NetworkBridgeFilter)) {
            super.looseMarshal(networkBridgeFilter, dataOut)
            looseMarshalCachedObject<BrokerId>(networkBridgeFilter.networkBrokerId, dataOut)
            dataOut.putInt32(networkBridgeFilter.messageTTL)
            dataOut.putInt32(networkBridgeFilter.consumerTTL)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(networkBridgeFilter) <- (data as NetworkBridgeFilter)) {
            super.looseUnmarshal(networkBridgeFilter, dataIn)
            networkBridgeFilter.networkBrokerId = looseUnmarsalCachedObject<BrokerId>(dataIn)
            networkBridgeFilter.messageTTL = dataIn.getInt32()
            networkBridgeFilter.consumerTTL = dataIn.getInt32()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(networkBridgeFilter) <- (object as NetworkBridgeFilter)) {
            super.tightMarshal(networkBridgeFilter, dataOut, bs)
            tightMarshalCachedObject<BrokerId>(networkBridgeFilter.networkBrokerId, dataOut, bs)
            dataOut.putInt32(networkBridgeFilter.messageTTL)
            dataOut.putInt32(networkBridgeFilter.consumerTTL)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(networkBridgeFilter) <- (data as NetworkBridgeFilter)) {
            super.tightUnmarshal(networkBridgeFilter, dataIn, bs)
            networkBridgeFilter.networkBrokerId = tightUnmarsalCachedObject<BrokerId>(dataIn, bs)
            networkBridgeFilter.messageTTL = dataIn.getInt32()
            networkBridgeFilter.consumerTTL = dataIn.getInt32()
        }
    }

    public override func createObject(): NetworkBridgeFilter {
        return NetworkBridgeFilter()
    }
}
