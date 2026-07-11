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

/**
 * 编解码公共字段
 */
public abstract class BaseCommandMarshaller <: BaseDataStreamMarshaller {
    public open func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(object) <- (object as Command)) {
            super.looseMarshal(object, dataOut)
            //commandId
            dataOut.putInt32(object.commandId)
            //responseRequired
            MarshallingSupport.putBool(object.responseRequired, dataOut)
        }
    }

    public open func looseUnmarshal(object: DataStructure, dataIn: ByteBuffer) {
        if (let Some(command) <- (object as Command)) {
            command.commandId = dataIn.getInt32()
            command.responseRequired = MarshallingSupport.getBool(dataIn)
        }
    }

    public open func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(object) <- (object as Command)) {
            super.tightMarshal(object, dataOut, bs)
            //commandId
            dataOut.putInt32(object.commandId)
            //responseRequired
            bs.writeBool(object.responseRequired)
        }
    }

    public open func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(command) <- (data as Command)) {
            command.commandId = dataIn.getInt32()
            command.responseRequired = bs.readBool()
        }
    }
}
