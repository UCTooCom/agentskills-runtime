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
package activemq4cj.client.command

/**
 * ObjectMessage采用仓颉serialization模块提供的序列化和反序列化方法
 */
public class ActiveMQObjectMessage <: ActiveMQMessage & ObjectMessage {
    private var objectVal: ?DataModel = None

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_OBJECT_MESSAGE
    }

    public override func beforeMarshall(): Unit {
        super.beforeMarshall()
        storeContent()
    }

    public func copy(): Message {
        let copy: ActiveMQObjectMessage = ActiveMQObjectMessage()
        this.copy(copy)
        return copy
    }

    private func copy(copy: ActiveMQObjectMessage): Unit {
        copy.objectVal = objectVal
        super.copy(copy)
    }

    public override func storeContent(): Unit {
        if (let Some(object) <- object) {
            this.content = doCompress(object.toJson().toJsonString().toArray())
        }
    }

    public override func clearBody(): Unit {
        super.clearBody()
        this.object = None
    }

    public mut prop object: ?DataModel {
        get() {
            if (this.objectVal.isNone()) {
                if (let Some(content) <- this.content) {
                    this.objectVal = DataModel.fromJson(JsonValue.fromStr(String.fromUtf8(doDecompress(content))))
                }
            }
            return objectVal
        }
        set(value) {
            checkReadOnlyBody()
            this.objectVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQObjectMessage)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQObjectMessage)) {
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQObjectMessage)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQObjectMessage)) {
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
