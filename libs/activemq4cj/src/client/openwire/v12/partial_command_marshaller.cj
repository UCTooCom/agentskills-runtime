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

public open class PartialCommandMarshaller <: BaseDataStreamMarshaller {

    //                                       [==if not null is 1=================]
    //    +------+------------+------------+ [ +-------+-----------------------+ ]
    //    | type | commandId  | not null   | [ | size  | data                  | ]
    //    +------+------------+------------+ [ +-------+-----------------------+ ]
    //    | Byte | Int32      | Byte       | [ | int32 |  size octects         | ]
    //    +------+------------+------------+ [ +-------+-----------------------+ ]
    //                                       [========ByteArray==================]

    public open func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(partialCommand) <- (object as PartialCommand)) {
            super.looseMarshal(partialCommand, dataOut)
            dataOut.putInt32(partialCommand.commandId)
            looseMarshalByteArray(partialCommand.data, dataOut)
        }
    }

    public open func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(partialCommand) <- (data as PartialCommand)) {
            super.looseUnmarshal(partialCommand, dataIn)
            partialCommand.commandId = dataIn.getInt32()
            partialCommand.data = looseUnmarshalByteArray(dataIn)
        }
    }

    public open func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(partialCommand) <- (object as PartialCommand)) {
            super.tightMarshal(partialCommand, dataOut, bs)
            dataOut.putInt32(partialCommand.commandId)
            tightMarshalByteArray(partialCommand.data, dataOut, bs)
        }
    }

    public open func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(partialCommand) <- (data as PartialCommand)) {
            super.tightUnmarshal(partialCommand, dataIn, bs)
            partialCommand.commandId = dataIn.getInt32()
            partialCommand.data = tightUnmarshalByteArray(dataIn, bs)
        }
    }

    public open func createObject(): PartialCommand {
        return PartialCommand()
    }
}

public class LastPartialCommandMarshaller <: PartialCommandMarshaller {

    //                                       [==if not null is 1=================]
    //    +------+------------+------------+ [ +-------+-----------------------+ ]
    //    | type | commandId  | not null   | [ | size  | data                  | ]
    //    +------+------------+------------+ [ +-------+-----------------------+ ]
    //    | Byte | Int32      | Byte       | [ | int32 |  size octects         | ]
    //    +------+------------+------------+ [ +-------+-----------------------+ ]
    //                                       [========ByteArray==================]

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(lastPartialCommand) <- (object as LastPartialCommand)) {
            super.looseMarshal(lastPartialCommand, dataOut)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(lastPartialCommand) <- (data as LastPartialCommand)) {
            super.looseUnmarshal(lastPartialCommand, dataIn)
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(lastPartialCommand) <- (object as LastPartialCommand)) {
            super.tightMarshal(lastPartialCommand, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(lastPartialCommand) <- (data as LastPartialCommand)) {
            super.tightUnmarshal(lastPartialCommand, dataIn, bs)
        }
    }

    public override func createObject(): LastPartialCommand {
        return LastPartialCommand()
    }
}
