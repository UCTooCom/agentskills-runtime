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

public class RemoveInfoMarshaller <: BaseCommandMarshaller {
    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(removeInfo) <- (object as RemoveInfo)) {
            super.looseMarshal(removeInfo, dataOut)
            looseMarshalCachedObject<DataStructure>(removeInfo.objectId, dataOut)
            dataOut.putInt64(removeInfo.lastDeliveredSequenceId)
        }
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        if (let Some(removeInfo) <- (data as RemoveInfo)) {
            super.looseUnmarshal(removeInfo, dataIn)
            removeInfo.objectId = looseUnmarsalCachedObject<DataStructure>(dataIn)
            removeInfo.lastDeliveredSequenceId = dataIn.getInt64()
        }
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(removeInfo) <- (object as RemoveInfo)) {
            super.tightMarshal(removeInfo, dataOut, bs)
            tightMarshalCachedObject<DataStructure>(removeInfo.objectId, dataOut, bs)
            tightMarshalLong(removeInfo.lastDeliveredSequenceId, dataOut, bs)
        }
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(removeInfo) <- (data as RemoveInfo)) {
            super.tightUnmarshal(removeInfo, dataIn, bs)
            removeInfo.objectId = tightUnmarsalCachedObject<DataStructure>(dataIn, bs)
            removeInfo.lastDeliveredSequenceId = tightUnmarshalLong(dataIn, bs)
        }
    }

    public override func createObject(): RemoveInfo {
        return RemoveInfo()
    }
}
