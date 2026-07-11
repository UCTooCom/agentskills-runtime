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

public abstract class BaseCommand <: Command {
    //commandId在消息发送时按顺序自动生成
    protected var commandIdVal: Int32 = 0
    //命令是否需要响应，为true时服务端会返回Response
    protected var responseRequiredVal: Bool = false

    public func copy(copy: BaseCommand): Unit {
        copy.commandId = commandId
        copy.responseRequired = responseRequired
    }

    public mut prop commandId: Int32 {
        get() {
            return commandIdVal
        }
        set(val) {
            this.commandIdVal = val
        }
    }

    public mut prop responseRequired: Bool {
        get() {
            return responseRequiredVal
        }
        set(val) {
            this.responseRequiredVal = val
        }
    }

    public open func isMarshallAware(): Bool {
        return false
    }

    public func supportResponse(): Bool {
        return this.responseRequiredVal
    }

    protected func checkEquals(other: BaseCommand): Bool {
        if (commandId != other.commandId) {
            return false
        }
        if (responseRequired != other.responseRequired) {
            return false
        }
        return true
    }

    public open operator func ==(other: DataStructure): Bool {
        if (let Some(other) <- (other as BaseCommand)) {
            if (commandId != other.commandId) {
                return false
            }
            if (responseRequired != other.responseRequired) {
                return false
            }
            return true
        }
        return false
    }

    public open operator func !=(other: DataStructure): Bool {
        if (let Some(other) <- (other as BaseCommand)) {
            if (commandId != other.commandId) {
                return true
            }
            if (responseRequired != other.responseRequired) {
                return true
            }
            return false
        }
        return true
    }

    @OverflowWrapping
    public open override func hashCode(): Int64 {
        let prime = 53
        var hashCode = prime * commandId.hashCode()
        hashCode += prime * responseRequired.hashCode()
        return hashCode
    }

    public open func toString(): String {
        return "{commandId: ${commandIdVal}, responseRequired: ${responseRequiredVal}}"
    }
}
