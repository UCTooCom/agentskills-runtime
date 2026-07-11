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

public class ReplayCommand <: BaseCommand {
    private var producerIdVal: ?String = None
    private var firstAckNumberVal: Int32 = 0
    private var lastAckNumberVal: Int32 = 0
    private var firstNakNumberVal: Int32 = 0
    private var lastNakNumberVal: Int32 = 0

    public func getDataStructureType(): Byte {
        return CommandTypes.REPLAY
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return None
    }

    public mut prop producerId: ?String {
        get() {
            return this.producerIdVal
        }
        set(value) {
            this.producerIdVal = value
        }
    }

    public mut prop firstAckNumber: Int32 {
        get() {
            return this.firstAckNumberVal
        }
        set(value) {
            this.firstAckNumberVal = value
        }
    }

    public mut prop lastAckNumber: Int32 {
        get() {
            return this.lastAckNumberVal
        }
        set(value) {
            this.lastAckNumberVal = value
        }
    }

    public mut prop firstNakNumber: Int32 {
        get() {
            return this.firstNakNumberVal
        }
        set(value) {
            this.firstNakNumberVal = value
        }
    }

    public mut prop lastNakNumber: Int32 {
        get() {
            return this.lastNakNumberVal
        }
        set(value) {
            this.lastNakNumberVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ReplayCommand)) {
            return false
        }
        if (let Some(other) <- (other as ReplayCommand)) {
            if (this.producerIdVal != other.producerIdVal) {
                return false
            }
            if (this.firstAckNumberVal != other.firstAckNumberVal) {
                return false
            }
            if (this.lastAckNumberVal != other.lastAckNumberVal) {
                return false
            }
            if (this.firstNakNumberVal != other.firstNakNumberVal) {
                return false
            }
            if (this.lastNakNumberVal != other.lastNakNumberVal) {
                return false
            }
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ReplayCommand)) {
            return true
        }
        if (let Some(other) <- (other as ReplayCommand)) {
            if (this.producerIdVal != other.producerIdVal) {
                return true
            }
            if (this.firstAckNumberVal != other.firstAckNumberVal) {
                return true
            }
            if (this.lastAckNumberVal != other.lastAckNumberVal) {
                return true
            }
            if (this.firstNakNumberVal != other.firstNakNumberVal) {
                return true
            }
            if (this.lastNakNumberVal != other.lastNakNumberVal) {
                return true
            }
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
