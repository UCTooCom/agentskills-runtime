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

public class ConnectionControlMarshaller <: BaseCommandMarshaller {

    // +------+------+-----------+------------------+-------+-------+--------------+--------+---------+----------------+------------+---------------------+-----------+
    // | size | type | commandId | responseRequired | Close |  Exit |FaultTolerant | Resume | Suspend |ConnectedBrokers|ReconnectTo | RebalanceConnection | Token     |
    // +------+------+-----------+------------------+-------+-------+--------------+--------+---------+----------------+------------+---------------------+-----------+                                         
    // | Int32| Byte |   Int32   |   Byte           | Bool  |  Bool | Bool         |  Bool  |  Bool   | String         |  String    |    Bool             | ByteArray |
    // +------+------+-----------+------------------+-------+-------+--------------+--------+---------+----------------+------------+---------------------+-----------+    

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(connectionControl) <- (object as ConnectionControl)) {
            super.looseMarshal(connectionControl, dataOut)
            MarshallingSupport.putBool(connectionControl.close, dataOut)
            MarshallingSupport.putBool(connectionControl.exit, dataOut)
            MarshallingSupport.putBool(connectionControl.faultTolerant, dataOut)
            MarshallingSupport.putBool(connectionControl.resume, dataOut)
            MarshallingSupport.putBool(connectionControl.suspend, dataOut)
            looseMarshalString(connectionControl.connectedBrokers, dataOut)
            looseMarshalString(connectionControl.reconnectTo, dataOut)
            MarshallingSupport.putBool(connectionControl.rebalanceConnection, dataOut)
            looseMarshalByteArray(connectionControl.token, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(connectionControl) <- (data as ConnectionControl)) {
            super.looseUnmarshal(connectionControl, dataIn)
            connectionControl.close = MarshallingSupport.getBool(dataIn)
            connectionControl.exit = MarshallingSupport.getBool(dataIn)
            connectionControl.faultTolerant = MarshallingSupport.getBool(dataIn)
            connectionControl.resume = MarshallingSupport.getBool(dataIn)
            connectionControl.suspend = MarshallingSupport.getBool(dataIn)
            connectionControl.connectedBrokers = looseUnmarshalString(dataIn)
            connectionControl.reconnectTo = looseUnmarshalString(dataIn)
            connectionControl.rebalanceConnection = MarshallingSupport.getBool(dataIn)
            connectionControl.token = looseUnmarshalByteArray(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionControl) <- (object as ConnectionControl)) {
            super.tightMarshal(connectionControl, dataOut, bs)
            bs.writeBool(connectionControl.close)
            bs.writeBool(connectionControl.exit)
            bs.writeBool(connectionControl.faultTolerant)
            bs.writeBool(connectionControl.resume)
            bs.writeBool(connectionControl.suspend)
            tightMarshalString(connectionControl.connectedBrokers, dataOut, bs)
            tightMarshalString(connectionControl.reconnectTo, dataOut, bs)
            bs.writeBool(connectionControl.rebalanceConnection)
            tightMarshalByteArray(connectionControl.token, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionControl) <- (data as ConnectionControl)) {
            super.tightUnmarshal(connectionControl, dataIn, bs)
            connectionControl.close = bs.readBool()
            connectionControl.exit = bs.readBool()
            connectionControl.faultTolerant = bs.readBool()
            connectionControl.resume = bs.readBool()
            connectionControl.suspend = bs.readBool()
            connectionControl.connectedBrokers = tightUnmarshalString(dataIn, bs)
            connectionControl.reconnectTo = tightUnmarshalString(dataIn, bs)
            connectionControl.rebalanceConnection = bs.readBool()
            connectionControl.token = tightUnmarshalByteArray(dataIn, bs)
        }
    }

    public override func createObject(): ConnectionControl {
        return ConnectionControl()
    }
}
