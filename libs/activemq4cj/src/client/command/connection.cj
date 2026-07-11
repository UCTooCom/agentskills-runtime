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

public class ConnectionId <: DataStructure & Equatable<ConnectionId> {
    private var valueVal: ?String = None

    public func getDataStructureType(): Byte {
        return CommandTypes.CONNECTION_ID
    }

    public init() {
    }

    public init(value: ?String) {
        this.valueVal = value
    }

    public mut prop value: ?String {
        get() {
            return this.valueVal
        }
        set(value) {
            this.valueVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ConnectionId)) {
            return false
        }
        if (let Some(other) <- (other as ConnectionId)) {
            if (this.valueVal != other.valueVal) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ConnectionId)) {
            return true
        }
        if (let Some(other) <- (other as ConnectionId)) {
            if (this.valueVal != other.valueVal) {
                return true
            }
        }
        return false
    }

    public operator override func ==(other: ConnectionId): Bool {
        if (this.valueVal != other.valueVal) {
            return false
        }

        return true
    }

    public operator override func !=(other: ConnectionId): Bool {
        if (this.valueVal != other.valueVal) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(value) <- this.value) {
            hashCode += prime * value.hashCode()
        }
        return hashCode
    }

    public func toString(): String {
        if (let Some(value) <- value) {
            return value
        }
        return Option<String>.None.toString()
    }
}

public class ConnectionInfo <: BaseCommand {
    private var connectionIdVal: ?ConnectionId = None
    private var clientIdVal: ?String = None
    private var clientIpVal: ?String = None
    private var userNameVal: ?String = None
    private var passwordVal: ?String = None
    private var brokerPathVal: ?Array<BrokerId> = None
    private var brokerMasterConnectorVal: Bool = false
    private var manageableVal: Bool = false
    private var clientMasterVal: Bool = true
    private var faultTolerantVal: Bool = false
    private var failoverReconnectVal: Bool = false

    public func getDataStructureType(): Byte {
        return CommandTypes.CONNECTION_INFO
    }

    public func createRemoveInfo(): RemoveInfo {
        let removeInfo = RemoveInfo()
        if (let Some(connectionId) <- this.connectionId) {
            removeInfo.objectId = connectionId
        }
        return removeInfo
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processAddConnection(this)
    }

    public mut prop connectionId: ?ConnectionId {
        get() {
            return this.connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop clientId: ?String {
        get() {
            return this.clientIdVal
        }
        set(value) {
            this.clientIdVal = value
        }
    }

    public mut prop clientIp: ?String {
        get() {
            return this.clientIpVal
        }
        set(value) {
            this.clientIpVal = value
        }
    }

    public mut prop userName: ?String {
        get() {
            return this.userNameVal
        }
        set(value) {
            this.userNameVal = value
        }
    }

    public mut prop password: ?String {
        get() {
            return this.passwordVal
        }
        set(value) {
            this.passwordVal = value
        }
    }

    public mut prop brokerPath: ?Array<BrokerId> {
        get() {
            return this.brokerPathVal
        }
        set(value) {
            this.brokerPathVal = value
        }
    }

    public mut prop brokerMasterConnector: Bool {
        get() {
            return this.brokerMasterConnectorVal
        }
        set(value) {
            this.brokerMasterConnectorVal = value
        }
    }

    public mut prop manageable: Bool {
        get() {
            return this.manageableVal
        }
        set(value) {
            this.manageableVal = value
        }
    }

    public mut prop clientMaster: Bool {
        get() {
            return this.clientMasterVal
        }
        set(value) {
            this.clientMasterVal = value
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

    public mut prop failoverReconnect: Bool {
        get() {
            return this.failoverReconnectVal
        }
        set(value) {
            this.failoverReconnectVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is ConnectionInfo)) {
            return false
        }
        if (let Some(other) <- (other as ConnectionInfo)) {
            if (let Some(connectionId) <- this.connectionIdVal) {
                if (let Some(otherConnectionId) <- other.connectionIdVal) {
                    if (connectionId != otherConnectionId) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.connectionIdVal.isSome()) {
                    return false
                }
            }

            if (this.clientIdVal != other.clientIdVal) {
                return false
            }

            if (this.clientIpVal != other.clientIpVal) {
                return false
            }

            if (this.userNameVal != other.userNameVal) {
                return false
            }

            if (this.passwordVal != other.passwordVal) {
                return false
            }

            if (this.brokerMasterConnectorVal != other.brokerMasterConnectorVal) {
                return false
            }

            if (this.manageableVal != other.manageableVal) {
                return false
            }

            if (this.clientMasterVal != other.clientMasterVal) {
                return false
            }

            if (this.faultTolerantVal != other.faultTolerantVal) {
                return false
            }

            if (this.failoverReconnectVal != other.failoverReconnectVal) {
                return false
            }
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is ConnectionInfo)) {
            return true
        }
        if (let Some(other) <- (other as ConnectionInfo)) {
            if (let Some(connectionId) <- this.connectionIdVal) {
                if (let Some(otherConnectionId) <- other.connectionIdVal) {
                    if (connectionId != otherConnectionId) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.connectionIdVal.isSome()) {
                    return true
                }
            }

            if (this.clientIdVal != other.clientIdVal) {
                return true
            }

            if (this.clientIpVal != other.clientIpVal) {
                return true
            }

            if (this.userNameVal != other.userNameVal) {
                return true
            }

            if (this.passwordVal != other.passwordVal) {
                return true
            }

            if (this.brokerMasterConnectorVal != other.brokerMasterConnectorVal) {
                return true
            }

            if (this.manageableVal != other.manageableVal) {
                return true
            }

            if (this.clientMasterVal != other.clientMasterVal) {
                return true
            }

            if (this.faultTolerantVal != other.faultTolerantVal) {
                return true
            }

            if (this.failoverReconnectVal != other.failoverReconnectVal) {
                return true
            }
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append(
            "ConnectionInfo: {${super.toString()}, connectionId:${connectionIdVal}, clientId: ${clientIdVal}, clientIp: ${clientIpVal}, userName: ${userNameVal}}, "
        )
        sb.append(
            "password: ${passwordVal}, brokerPath: ${brokerPathVal}, brokerMasterConnector: ${brokerMasterConnectorVal}, manageable: ${manageableVal}, clientMaster: ${clientMasterVal}, "
        )
        sb.append("faultTolerant: ${failoverReconnectVal}, failoverReconnect: ${failoverReconnectVal}")
        return sb.toString()
    }
}
