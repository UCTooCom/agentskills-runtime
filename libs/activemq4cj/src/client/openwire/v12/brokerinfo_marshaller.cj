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

public class BrokerInfoMarshaller <: BaseCommandMarshaller {

    //                                                           [==if not null is 1=====]    
    // +------+------+-----------+------------------+----------+ [ +-------+----------+  ] +------------+----------------+------------+-------------+------------+---------------------------+
    // | size | type | commandId | responseRequired | not null | [ |  type | BrokerId |  ] |  BrokerURL |peerbrokerinfos | brokerName | slaveBroker |masterBroker|faultTolerantConfiguration |
    // +------+------+-----------+------------------+----------+ [ +-------+----------+  ] +------------+----------------+------------+-------------+------------+---------------------------+  ==>                                          
    // | Int32| Byte |   Int32   |   Byte           | Byte     | [ |  Byte |  String  |  ] |  String    | Byte Array     |  String    |  Bool       | Bool       |    Bool                   |    
    // +------+------+-----------+------------------+----------+ [ +-------+----------+  ] +------------+----------------+------------+-------------+------------+---------------------------+                                  
    //                                                           [=======================]

    //     +------------------+-------------------+--------------+------------------+-------------------+ 
    //     | duplexConnection | networkConnection | connectionId | brokerUploadUrl  | networkProperties | 
    // ==> +------------------+-------------------+--------------+------------------+-------------------+                                            
    //     | Bool             | Bool              |   Int64      |   String         | String            | 
    //     +------------------+-------------------+--------------+------------------+-------------------+ 

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(brokerInfo) <- (object as BrokerInfo)) {
            super.looseMarshal(brokerInfo, dataOut)
            looseMarshalCachedObject<BrokerId>(brokerInfo.brokerId, dataOut)
            looseMarshalString(brokerInfo.brokerURL, dataOut)
            looseMarshalObjectArray<BrokerInfo>(brokerInfo.peerBrokerInfos, dataOut)
            looseMarshalString(brokerInfo.brokerName, dataOut)
            MarshallingSupport.putBool(brokerInfo.slaveBroker, dataOut)
            MarshallingSupport.putBool(brokerInfo.masterBroker, dataOut)
            MarshallingSupport.putBool(brokerInfo.faultTolerantConfiguration, dataOut)
            MarshallingSupport.putBool(brokerInfo.duplexConnection, dataOut)
            MarshallingSupport.putBool(brokerInfo.networkConnection, dataOut)
            dataOut.putInt64(brokerInfo.connectionId)
            looseMarshalString(brokerInfo.brokerUploadUrl, dataOut)
            looseMarshalString(brokerInfo.networkProperties, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(brokerInfo) <- (data as BrokerInfo)) {
            super.looseUnmarshal(brokerInfo, dataIn)
            brokerInfo.brokerId = looseUnmarsalCachedObject<BrokerId>(dataIn)
            brokerInfo.brokerURL = looseUnmarshalString(dataIn)
            if (MarshallingSupport.getBool(dataIn)) {
                let size = Int64(dataIn.getInt16())
                let peerBrokerInfos = Array<BrokerInfo>(size, repeat: BrokerInfo())
                for (i in 0..size) {
                    if (let Some(brokerInfo) <- looseUnmarsalNestedObject<BrokerInfo>(dataIn)) {
                        peerBrokerInfos[i] = brokerInfo
                    }
                }
                brokerInfo.peerBrokerInfos = peerBrokerInfos
            }
            brokerInfo.brokerName = looseUnmarshalString(dataIn)
            brokerInfo.slaveBroker = MarshallingSupport.getBool(dataIn)
            brokerInfo.masterBroker = MarshallingSupport.getBool(dataIn)
            brokerInfo.faultTolerantConfiguration = MarshallingSupport.getBool(dataIn)
            brokerInfo.duplexConnection = MarshallingSupport.getBool(dataIn)
            brokerInfo.networkConnection = MarshallingSupport.getBool(dataIn)
            brokerInfo.connectionId = dataIn.getInt64()
            brokerInfo.brokerUploadUrl = looseUnmarshalString(dataIn)
            brokerInfo.networkProperties = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(brokerInfo) <- (object as BrokerInfo)) {
            super.tightMarshal(brokerInfo, dataOut, bs)
            tightMarshalCachedObject<BrokerId>(brokerInfo.brokerId, dataOut, bs)
            tightMarshalString(brokerInfo.brokerURL, dataOut, bs)
            tightMarshalObjectArray<BrokerInfo>(brokerInfo.peerBrokerInfos, dataOut, bs)
            tightMarshalString(brokerInfo.brokerName, dataOut, bs)
            bs.writeBool(brokerInfo.slaveBroker)
            bs.writeBool(brokerInfo.masterBroker)
            bs.writeBool(brokerInfo.faultTolerantConfiguration)
            bs.writeBool(brokerInfo.duplexConnection)
            bs.writeBool(brokerInfo.networkConnection)
            tightMarshalLong(brokerInfo.connectionId, dataOut, bs)
            tightMarshalString(brokerInfo.brokerUploadUrl, dataOut, bs)
            tightMarshalString(brokerInfo.networkProperties, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(brokerInfo) <- (data as BrokerInfo)) {
            super.tightUnmarshal(data, dataIn, bs)
            brokerInfo.brokerId = tightUnmarsalCachedObject<BrokerId>(dataIn, bs)
            brokerInfo.brokerURL = tightUnmarshalString(dataIn, bs)
            if (bs.readBool()) {
                let size = Int64(dataIn.getInt16())
                let peerBrokerInfos = Array<BrokerInfo>(size, repeat: BrokerInfo())
                for (i in 0..size) {
                    if (let Some(brokerInfo) <- tightUnmarshalNestedObject<BrokerInfo>(dataIn, bs)) {
                        peerBrokerInfos[i] = brokerInfo
                    }
                }
                brokerInfo.peerBrokerInfos = peerBrokerInfos
            } else {
                brokerInfo.peerBrokerInfos = None
            }
            brokerInfo.brokerName = tightUnmarshalString(dataIn, bs)
            brokerInfo.slaveBroker = bs.readBool()
            brokerInfo.masterBroker = bs.readBool()
            brokerInfo.faultTolerantConfiguration = bs.readBool()
            brokerInfo.duplexConnection = bs.readBool()
            brokerInfo.networkConnection = bs.readBool()
            brokerInfo.connectionId = tightUnmarshalLong(dataIn, bs)
            brokerInfo.brokerUploadUrl = tightUnmarshalString(dataIn, bs)
            brokerInfo.networkProperties = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): BrokerInfo {
        return BrokerInfo()
    }
}

public class BrokerIdMarshaller <: BaseDataStreamMarshaller {

    // +------+--------+
    // | type | value  |
    // +------+--------+
    // | Byte | String |
    // +------+--------+

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(brokerId) <- (object as BrokerId)) {
            super.looseMarshal(object, dataOut)
            if (let Some(value) <- brokerId.value) {
                MarshallingSupport.putBool(true, dataOut)
                MarshallingSupport.writeUTF(value, dataOut)
            } else {
                MarshallingSupport.putBool(false, dataOut)
            }
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(brokerId) <- (data as BrokerId)) {
            brokerId.value = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(brokerId) <- (object as BrokerId)) {
            super.tightMarshal(brokerId, dataOut, bs)
            tightMarshalString(brokerId.value, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(brokerId) <- (data as BrokerId)) {
            super.tightUnmarshal(brokerId, dataIn, bs)
            brokerId.value = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): BrokerId {
        return BrokerId()
    }
}
