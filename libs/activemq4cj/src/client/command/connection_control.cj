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

public class ConnectionControl <: BaseCommand {
    private var suspendVal: Bool = false
    private var resumeVal: Bool = false
    private var closeVal: Bool = false
    private var exitVal: Bool = false
    private var faultTolerantVal: Bool = false
    private var connectedBrokersVal: ?String = None
    private var reconnectToVal: ?String = None
    private var tokenVal: ?Array<Byte> = None
    private var rebalanceConnectionVal: Bool = false

    public func getDataStructureType(): Byte {
        return CommandTypes.CONNECTION_CONTROL
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processConnectionControl(this)
    }

    public mut prop suspend: Bool {
        get() {
            return this.suspendVal
        }
        set(value) {
            this.suspendVal = value
        }
    }

    public mut prop resume: Bool {
        get() {
            return this.resumeVal
        }
        set(value) {
            this.resumeVal = value
        }
    }

    public mut prop close: Bool {
        get() {
            return this.closeVal
        }
        set(value) {
            this.closeVal = value
        }
    }

    public mut prop exit: Bool {
        get() {
            return this.exitVal
        }
        set(value) {
            this.exitVal = value
        }
    }

    public mut prop faultTolerant: Bool {
        get() {
            return this.faultTolerantVal
        }
        set(value) {
            this.faultTolerantVal = value
        }
    }

    public mut prop connectedBrokers: ?String {
        get() {
            return this.connectedBrokersVal
        }
        set(value) {
            this.connectedBrokersVal = value
        }
    }

    public mut prop reconnectTo: ?String {
        get() {
            return this.reconnectToVal
        }
        set(value) {
            this.reconnectToVal = value
        }
    }

    public mut prop token: ?Array<Byte> {
        get() {
            return this.tokenVal
        }
        set(value) {
            this.tokenVal = value
        }
    }

    public mut prop rebalanceConnection: Bool {
        get() {
            return this.rebalanceConnectionVal
        }
        set(value) {
            this.rebalanceConnectionVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ConnectionControl)) {
            return false
        }
        if (let Some(other) <- (other as ConnectionControl)) {
            if (this.suspendVal != other.suspendVal) {
                return false
            }
            if (this.resumeVal != other.resumeVal) {
                return false
            }
            if (this.closeVal != other.closeVal) {
                return false
            }
            if (this.exitVal != other.exitVal) {
                return false
            }
            if (this.faultTolerantVal != other.faultTolerantVal) {
                return false
            }

            if (this.connectedBrokersVal != other.connectedBrokersVal) {
                return false
            }

            if (this.reconnectToVal != other.reconnectToVal) {
                return false
            }

            if (this.tokenVal != other.tokenVal) {
                return false
            }

            if (this.rebalanceConnectionVal != other.rebalanceConnectionVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ConnectionControl)) {
            return true
        }
        if (let Some(other) <- (other as ConnectionControl)) {
            if (this.suspendVal != other.suspendVal) {
                return true
            }
            if (this.resumeVal != other.resumeVal) {
                return true
            }
            if (this.closeVal != other.closeVal) {
                return true
            }
            if (this.exitVal != other.exitVal) {
                return true
            }
            if (this.faultTolerantVal != other.faultTolerantVal) {
                return true
            }

            if (this.connectedBrokersVal != other.connectedBrokersVal) {
                return true
            }

            if (this.reconnectToVal != other.reconnectToVal) {
                return true
            }

            if (this.tokenVal != other.tokenVal) {
                return true
            }

            if (this.rebalanceConnectionVal != other.rebalanceConnectionVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        return "ConnectionControl: {suspend: ${suspendVal}, resume: ${resumeVal}, close: ${closeVal}, exit: ${exitVal}, faultTolerant: ${faultTolerantVal}, connectedBrokers: ${connectedBrokersVal}, reconnectTo: ${reconnectToVal}, token: ${tokenVal}, rebalanceConnection: ${rebalanceConnectionVal}}"
    }
}
