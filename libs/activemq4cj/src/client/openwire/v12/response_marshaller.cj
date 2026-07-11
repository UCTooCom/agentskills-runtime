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

public class ResponseMarshaller <: BaseCommandMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(response) <- (object as Response)) {
            super.looseMarshal(response, dataOut)
            dataOut.putInt32(response.correlationId)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(response) <- (data as Response)) {
            super.looseUnmarshal(response, dataIn)
            response.correlationId = dataIn.getInt32()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(response) <- (object as Response)) {
            super.tightMarshal(response, dataOut, bs)
            dataOut.putInt32(response.correlationId)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(response) <- (data as Response)) {
            super.tightUnmarshal(response, dataIn, bs)
            response.correlationId = dataIn.getInt32()
        }
    }

    public override func createObject(): Response {
        return Response()
    }
}

public class DataResponseMarshaller <: BaseCommandMarshaller {
    //                                                                            [==if not null is 1=================]
    //   +------+------+-----------+------------------+---------------+----------+  [ +------+------------------------+ ]
    //   | size | type | commandId | responseRequired | correlationId | not null |  [ | type | command-specific-fields| ]
    //   +------+------+-----------+------------------+---------------+----------+  [ +------+------------------------+ ]
    //   | Int32| Byte |   Int32   |   Byte           | Int32         | Byte     |  [ | Byte |  variable sized        | ]
    //   +------+------+-----------+------------------+---------------+----------+  [ +------+------------------------+ ]
    //                                                                              [=========DataStructure=============]
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(dataResponse) <- (object as DataResponse)) {
            super.looseMarshal(dataResponse, dataOut)
            dataOut.putInt32(dataResponse.correlationId)
            looseMarshalNestedObject<DataStructure>(dataResponse.data, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(dataResponse) <- (data as DataResponse)) {
            super.looseUnmarshal(dataResponse, dataIn)
            dataResponse.correlationId = dataIn.getInt32()
            dataResponse.data = looseUnmarsalNestedObject<DataStructure>(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(dataResponse) <- (object as DataResponse)) {
            super.tightMarshal(dataResponse, dataOut, bs)
            dataOut.putInt32(dataResponse.correlationId)
            tightMarshalNestedObject<DataStructure>(dataResponse.data, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(dataResponse) <- (data as DataResponse)) {
            super.tightUnmarshal(dataResponse, dataIn, bs)
            dataResponse.correlationId = dataIn.getInt32()
            dataResponse.data = tightUnmarshalNestedObject<DataStructure>(dataIn, bs)
        }
    }

    public override func createObject(): DataResponse {
        return DataResponse()
    }
}

public class IntegerResponseMarshaller <: BaseCommandMarshaller {
    //   +------+------+-----------+------------------+---------------+----------+
    //   | size | type | commandId | responseRequired | correlationId | result   |
    //   +------+------+-----------+------------------+---------------+----------+
    //   | Int32| Byte |   Int32   |   Byte           | Int32         | Int32    |
    //   +------+------+-----------+------------------+---------------+----------+
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(integerResponse) <- (object as IntegerResponse)) {
            super.looseMarshal(integerResponse, dataOut)
            dataOut.putInt32(integerResponse.correlationId)
            dataOut.putInt32(integerResponse.result)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(integerResponse) <- (data as IntegerResponse)) {
            super.looseUnmarshal(integerResponse, dataIn)
            integerResponse.correlationId = dataIn.getInt32()
            integerResponse.result = dataIn.getInt32()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(integerResponse) <- (object as IntegerResponse)) {
            super.tightMarshal(integerResponse, dataOut, bs)
            dataOut.putInt32(integerResponse.correlationId)
            dataOut.putInt32(integerResponse.result)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(integerResponse) <- (data as IntegerResponse)) {
            super.tightUnmarshal(integerResponse, dataIn, bs)
            integerResponse.correlationId = dataIn.getInt32()
            integerResponse.result = dataIn.getInt32()
        }
    }

    public override func createObject(): IntegerResponse {
        return IntegerResponse()
    }
}

public class DataArrayResponseMarshaller <: BaseCommandMarshaller {
    //                                                                                 [==if not null is 1=================]
    //   +------+------+-----------+------------------+---------------+----------+  [ +-------+-----------------------+ ]
    //   | size | type | commandId | responseRequired | correlationId | not null |  [ | szie  | data                  | ]
    //   +------+------+-----------+------------------+---------------+----------+  [ +-------+-----------------------+ ]
    //   | Int32| Byte |   Int32   |   Byte           | Int32         | Byte     |  [ | Int32 |  size octects         | ]
    //   +------+------+-----------+------------------+---------------+----------+  [ +-------+-----------------------+ ]
    //                                                                              [=========DataStructure Array=======]=====]
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(dataArrayResponse) <- (object as DataArrayResponse)) {
            super.looseMarshal(dataArrayResponse, dataOut)
            dataOut.putInt32(dataArrayResponse.correlationId)
            looseMarshalObjectArray<DataStructure>(dataArrayResponse.data, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(dataArrayResponse) <- (data as DataArrayResponse)) {
            super.looseUnmarshal(dataArrayResponse, dataIn)
            dataArrayResponse.correlationId = dataIn.getInt32()
            if (MarshallingSupport.getBool(dataIn)) {
                let size = Int64(dataIn.getInt16())
                let data = Array<DataStructure>(size, repeat: Response())
                for (i in 0..size) {
                    if (let Some(dataStructure) <- looseUnmarsalNestedObject<DataStructure>(dataIn)) {
                        data[i] = dataStructure
                    }
                }
                dataArrayResponse.data = data
            }
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(dataArrayResponse) <- (object as DataArrayResponse)) {
            super.tightMarshal(dataArrayResponse, dataOut, bs)
            dataOut.putInt32(dataArrayResponse.correlationId)
            tightMarshalObjectArray<DataStructure>(dataArrayResponse.data, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(dataArrayResponse) <- (data as DataArrayResponse)) {
            super.tightUnmarshal(dataArrayResponse, dataIn, bs)
            dataArrayResponse.correlationId = dataIn.getInt32()
            if (bs.readBool()) {
                let size = Int64(dataIn.getInt16())
                let data = Array<DataStructure>(size, repeat: Response())
                for (i in 0..size) {
                    if (let Some(dataStructure) <- tightUnmarshalNestedObject<DataStructure>(dataIn, bs)) {
                        data[i] = dataStructure
                    }
                }
                dataArrayResponse.data = data
            }
        }
    }

    public override func createObject(): DataArrayResponse {
        return DataArrayResponse()
    }
}

public class ExceptionResponseMarshaller <: BaseCommandMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(exceptionResponse) <- (object as ExceptionResponse)) {
            super.looseMarshal(exceptionResponse, dataOut)
            dataOut.putInt32(exceptionResponse.correlationId)
            looseMarshalThrowable(exceptionResponse.exception, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(exceptionResponse) <- (data as ExceptionResponse)) {
            super.looseUnmarshal(exceptionResponse, dataIn)
            exceptionResponse.correlationId = dataIn.getInt32()
            exceptionResponse.exception = looseUnmarsalThrowable(dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(exceptionResponse) <- (object as ExceptionResponse)) {
            super.tightMarshal(exceptionResponse, dataOut, bs)
            dataOut.putInt32(exceptionResponse.correlationId)
            tightMarshalThrowable(exceptionResponse.exception, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(exceptionResponse) <- (data as ExceptionResponse)) {
            super.tightUnmarshal(exceptionResponse, dataIn, bs)
            exceptionResponse.correlationId = dataIn.getInt32()
            exceptionResponse.exception = tightUnmarsalThrowable(dataIn, bs)
        }
    }

    public override func createObject(): ExceptionResponse {
        return ExceptionResponse()
    }
}
