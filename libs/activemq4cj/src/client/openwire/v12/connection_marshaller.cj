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

public class ConnectionIdMarshaller <: BaseDataStreamMarshaller {
    // +------+-----------+
    // | type | value     |
    // +------+-----------+                             
    // | Byte |   String  |    
    // +------+-----------+  
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(connectionId) <- (object as ConnectionId)) {
            super.looseMarshal(connectionId, dataOut)
            looseMarshalString(connectionId.value, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(connectionId) <- (data as ConnectionId)) {
            super.looseUnmarshal(connectionId, dataIn)
            connectionId.value = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionId) <- (object as ConnectionId)) {
            super.tightMarshal(connectionId, dataOut, bs)
            tightMarshalString(connectionId.value, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionId) <- (data as ConnectionId)) {
            super.tightUnmarshal(connectionId, dataIn, bs)
            connectionId.value = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): DataStructure {
        return ConnectionId()
    }
}

public class ConnectionInfoMarshaller <: BaseCommandMarshaller {

    //                                                           [==if not null is 1=========]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+  ] +-----------+---------+----------+------------+---------------------+-----------+
    // | size | type | commandId | responseRequired | not null | [ |  type | value        |  ] |  clientId |Password | UserName | BrokerPath |BrokerMasterConnector|Manageable |
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+  ] +-----------+---------+----------+------------+---------------------+-----------+  ==>
    // | Int32| Byte |   Int32   |   Byte           | Byte     | [ |  Byte |  String      |  ] |  String   | String  |  String  |  ByteArray | Bool                |    Bool   |
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+  ] +-----------+---------+----------+------------+---------------------+-----------+
    //                                                           [=========connectionId======]
    //     +--------------+---------------+-------------------+-----------+
    //     | ClientMaster | FaultTolerant | FailoverReconnect | ClientIp  |
    // ==> +--------------+---------------+-------------------+-----------+
    //     | Bool         | Bool          |   Bool            |   String  |
    //     +--------------+---------------+-------------------+-----------+

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(connectionInfo) <- (object as ConnectionInfo)) {
            super.looseMarshal(connectionInfo, dataOut)
            looseMarshalCachedObject<ConnectionId>(connectionInfo.connectionId, dataOut)
            looseMarshalString(connectionInfo.clientId, dataOut)
            looseMarshalString(connectionInfo.password, dataOut)
            looseMarshalString(connectionInfo.userName, dataOut)
            looseMarshalObjectArray<BrokerId>(connectionInfo.brokerPath, dataOut)
            MarshallingSupport.putBool(connectionInfo.brokerMasterConnector, dataOut)
            MarshallingSupport.putBool(connectionInfo.manageable, dataOut)
            MarshallingSupport.putBool(connectionInfo.clientMaster, dataOut)
            MarshallingSupport.putBool(connectionInfo.faultTolerant, dataOut)
            MarshallingSupport.putBool(connectionInfo.failoverReconnect, dataOut)
            looseMarshalString(connectionInfo.clientIp, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(connectionInfo) <- (data as ConnectionInfo)) {
            super.looseUnmarshal(connectionInfo, dataIn)
            connectionInfo.connectionId = looseUnmarsalCachedObject<ConnectionId>(dataIn)
            connectionInfo.clientId = looseUnmarshalString(dataIn)
            connectionInfo.password = looseUnmarshalString(dataIn)
            connectionInfo.userName = looseUnmarshalString(dataIn)
            if (MarshallingSupport.getBool(dataIn)) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- looseUnmarsalNestedObject<BrokerId>(dataIn)) {
                        brokerPath[j] = brokerId
                    }
                }
                connectionInfo.brokerPath = brokerPath
            }
            connectionInfo.brokerMasterConnector = MarshallingSupport.getBool(dataIn)
            connectionInfo.manageable = MarshallingSupport.getBool(dataIn)
            connectionInfo.clientMaster = MarshallingSupport.getBool(dataIn)
            connectionInfo.faultTolerant = MarshallingSupport.getBool(dataIn)
            connectionInfo.failoverReconnect = MarshallingSupport.getBool(dataIn)
            connectionInfo.clientIp = looseUnmarshalString(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionInfo) <- (object as ConnectionInfo)) {
            super.tightMarshal(connectionInfo, dataOut, bs)
            tightMarshalCachedObject<ConnectionId>(connectionInfo.connectionId, dataOut, bs)
            tightMarshalString(connectionInfo.clientId, dataOut, bs)
            tightMarshalString(connectionInfo.password, dataOut, bs)
            tightMarshalString(connectionInfo.userName, dataOut, bs)
            tightMarshalObjectArray<BrokerId>(connectionInfo.brokerPath, dataOut, bs)
            bs.writeBool(connectionInfo.brokerMasterConnector)
            bs.writeBool(connectionInfo.manageable)
            bs.writeBool(connectionInfo.clientMaster)
            bs.writeBool(connectionInfo.faultTolerant)
            bs.writeBool(connectionInfo.failoverReconnect)
            tightMarshalString(connectionInfo.clientIp, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionInfo) <- (data as ConnectionInfo)) {
            super.tightUnmarshal(connectionInfo, dataIn, bs)
            connectionInfo.connectionId = tightUnmarsalCachedObject<ConnectionId>(dataIn, bs)
            connectionInfo.clientId = tightUnmarshalString(dataIn, bs)
            connectionInfo.password = tightUnmarshalString(dataIn, bs)
            connectionInfo.userName = tightUnmarshalString(dataIn, bs)
            if (bs.readBool()) {
                let size = Int64(dataIn.getInt16())
                let brokerPath = Array<BrokerId>(size, repeat: BrokerId())
                for (j in 0..size) {
                    if (let Some(brokerId) <- tightUnmarshalNestedObject<BrokerId>(dataIn, bs)) {
                        brokerPath[j] = brokerId
                    }
                }
                connectionInfo.brokerPath = brokerPath
            }
            connectionInfo.brokerMasterConnector = bs.readBool()
            connectionInfo.manageable = bs.readBool()
            connectionInfo.clientMaster = bs.readBool()
            connectionInfo.faultTolerant = bs.readBool()
            connectionInfo.failoverReconnect = bs.readBool()
            connectionInfo.clientIp = tightUnmarshalString(dataIn, bs)
        }
    }

    public override func createObject(): ConnectionInfo {
        return ConnectionInfo()
    }
}
