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

public class ConnectionErrorMarshaller <: BaseCommandMarshaller {

    //                                                           [=If not-null is 1===========================================================================]
    //                                                           [                               [=If StackTraceEnabled option is enabled.==================] ]
    //                                                           [                               [             [=Repeated size times======================] ] ]              [=If not-null is 1========]
    // +------+------+-----------+------------------+----------+ [ +----------------+---------+  [ +-------+ [ +--------+--------+--------+-------------+ ] ] ] +----------+ [ +----------+----------+ ]                         ]
    // | size | type | commandId | responseRequired | not-null | [ | exception-name | message |  [ | size  | [ | class  | method | file   | line-number | ] ] ] | not-null | [ | type     | value    | ]
    // +------+------+-----------+------------------+----------+ [ +----------------+---------+  [ +-------+ [ +--------+--------+--------+-------------+ ] ] ] +----------+ [ +----------+----------+ ]
    // | Int32| Byte |   Int32   |   Byte           | byte     | [ | string         | string  |  [ | short | [ | string | string | string | int         | ] ] ] | byte     | [ | byte     | String   | ]
    // +------+------+-----------+------------------+----------+ [ +----------------+---------+  [ +-------+ [ +--------+--------+--------+-------------+ ] ] ] +----------+ [ +----------+----------+ ]
    //                                                           [                               [           [============================================] ] ]              [===ConnectionId==========]
    //                                                           [                               [==========================================================] ]
    //                                                           [============================================================================================]
    //

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(connectionError) <- (object as ConnectionError)) {
            super.looseMarshal(connectionError, dataOut)
            looseMarshalThrowable(connectionError.exception, dataOut)
            looseMarshalNestedObject<ConnectionId>(connectionError.connectionId, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(connectionError) <- (data as ConnectionError)) {
            super.looseUnmarshal(connectionError, dataIn)
            connectionError.exception = looseUnmarsalThrowable(dataIn)
            connectionError.connectionId = looseUnmarsalNestedObject<ConnectionId>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionError) <- (object as ConnectionError)) {
            super.tightMarshal(connectionError, dataOut, bs)
            tightMarshalThrowable(connectionError.exception, dataOut, bs)
            tightMarshalNestedObject<ConnectionId>(connectionError.connectionId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(connectionError) <- (data as ConnectionError)) {
            super.tightUnmarshal(connectionError, dataIn, bs)
            connectionError.exception = tightUnmarsalThrowable(dataIn, bs)
            connectionError.connectionId = tightUnmarshalNestedObject<ConnectionId>(dataIn, bs)
        }
    }

    public override func createObject(): ConnectionError {
        return ConnectionError()
    }
}
