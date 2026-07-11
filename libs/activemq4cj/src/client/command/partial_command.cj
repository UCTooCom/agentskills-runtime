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

public open class PartialCommand <: Command {
    private var commandIdVal: Int32 = 0
    private var dataVal: ?Array<Byte> = None

    public open func getDataStructureType(): Byte {
        return CommandTypes.PARTIAL_COMMAND
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return None
    }

    public mut prop commandId: Int32 {
        get() {
            return this.commandIdVal
        }
        set(value) {
            this.commandIdVal = value
        }
    }

    public mut prop responseRequired: Bool {
        get() {
            throw UnsupportedException("Unsupported operation")
        }
        set(val) {
            throw UnsupportedException("Unsupported operation")
        }
    }

    public mut prop data: ?Array<Byte> {
        get() {
            return this.dataVal
        }
        set(value) {
            this.dataVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public func checkEquals(other: PartialCommand): Bool {
        if (this.commandIdVal != other.commandIdVal) {
            return false
        }

        if (this.dataVal != other.dataVal) {
            return false
        }
        return true
    }

    public open operator func ==(other: DataStructure): Bool {
        if (!(other is PartialCommand)) {
            return false
        }
        if (let Some(other) <- (other as PartialCommand)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public open operator func !=(other: DataStructure): Bool {
        if (!(other is PartialCommand)) {
            return true
        }
        if (let Some(other) <- (other as PartialCommand)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = prime * commandIdVal.hashCode()
        if (let Some(data) <- this.dataVal) {
            for (item in data) {
                hashCode += prime * item.hashCode()
            }
        }
        return hashCode
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("PartialCommand: {commandId: ${commandIdVal}, data: [")
        if (let Some(data) <- this.dataVal) {
            for (item in data) {
                sb.append("${item}, ")
            }
        }
        sb.append("]}")
        return sb.toString()
    }
}

public class LastPartialCommand <: PartialCommand {
    public func getDataStructureType(): Byte {
        return CommandTypes.PARTIAL_LAST_COMMAND
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is LastPartialCommand)) {
            return false
        }
        if (let Some(other) <- (other as LastPartialCommand)) {
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is LastPartialCommand)) {
            return true
        }
        if (let Some(other) <- (other as LastPartialCommand)) {
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
