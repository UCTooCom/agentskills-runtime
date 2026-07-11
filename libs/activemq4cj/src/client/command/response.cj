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

public open class Response <: BaseCommand & ToString {
    public open func getDataStructureType(): Byte {
        return CommandTypes.RESPONSE
    }

    //这个值与发送命令时的commandId对应
    private var correlationIdVal: Int32 = 0

    public override func visit(visitor: CommandVisitor): ?Response {
        return None
    }

    public mut prop correlationId: Int32 {
        get() {
            return correlationIdVal
        }
        set(val) {
            this.correlationIdVal = val
        }
    }

    public func checkEquals(other: Response) {
        if (this.correlationIdVal != other.correlationIdVal) {
            return false
        }

        if (!super.checkEquals(other)) {
            return false
        }
        return true
    }

    public open operator func ==(other: DataStructure): Bool {
        if (!(other is Response)) {
            return false
        }
        if (let Some(other) <- (other as Response)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public open operator func !=(other: DataStructure): Bool {
        if (!(other is Response)) {
            return true
        }
        if (let Some(other) <- (other as Response)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public open func toString(): String {
        return "Response: {${super.toString()}, correlationId: ${correlationIdVal}}"
    }
}
