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

public class SessionIdMarshaller <: BaseDataStreamMarshaller {

    // +------+--------------+-------+
    // | type | connectionId | value |
    // +------+--------------+-------+                                  
    // | Byte |   String     | Int64 | 
    // +------+--------------+-------+

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(sessionId) <- (object as SessionId)) {
            super.looseMarshal(sessionId, dataOut)
            looseMarshalString(sessionId.connectionId, dataOut)
            dataOut.putInt64(sessionId.value)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(sessionId) <- (data as SessionId)) {
            super.looseUnmarshal(sessionId, dataIn)
            sessionId.connectionId = looseUnmarshalString(dataIn)
            sessionId.value = dataIn.getInt64()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(sessionId) <- (object as SessionId)) {
            super.tightMarshal(sessionId, dataOut, bs)
            tightMarshalString(sessionId.connectionId, dataOut, bs)
            tightMarshalLong(sessionId.value, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(sessionId) <- (data as SessionId)) {
            super.tightUnmarshal(sessionId, dataIn, bs)
            sessionId.connectionId = tightUnmarshalString(dataIn, bs)
            sessionId.value = tightUnmarshalLong(dataIn, bs)
        }
    }

    public override func createObject(): SessionId {
        return SessionId()
    }
}

public class SessionInfoMarshaller <: BaseCommandMarshaller {
    //                                                           [=======if not null is 1===========]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+ ]
    // | size | type | commandId | responseRequired | not null | [ |  type | connectionId | value | ]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+ ]
    // | Int32| Byte |   Int32   |   Byte           | Byte     | [ |  Byte |  String      | Int64 | ]
    // +------+------+-----------+------------------+----------+ [ +-------+--------------+-------+ ]
    //                                                           [========SessionId=================]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(sessionInfo) <- (object as SessionInfo)) {
            super.looseMarshal(sessionInfo, dataOut)
            looseMarshalCachedObject<SessionId>(sessionInfo.sessionId, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(sessionInfo) <- (data as SessionInfo)) {
            super.looseUnmarshal(sessionInfo, dataIn)
            sessionInfo.sessionId = looseUnmarsalCachedObject<SessionId>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(sessionInfo) <- (object as SessionInfo)) {
            super.tightMarshal(sessionInfo, dataOut, bs)
            tightMarshalCachedObject<SessionId>(sessionInfo.sessionId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(sessionInfo) <- (data as SessionInfo)) {
            super.tightUnmarshal(sessionInfo, dataIn, bs)
            sessionInfo.sessionId = tightUnmarsalCachedObject<SessionId>(dataIn, bs)
        }
    }

    public override func createObject(): SessionInfo {
        return SessionInfo()
    }
}
