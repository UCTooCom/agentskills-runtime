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

public class NetworkBridgeFilter <: DataStructure {
    private var networkBrokerIdVal: ?BrokerId = None
    private var messageTTLVal: Int32 = 0
    private var consumerTTLVal: Int32 = 0

    public func getDataStructureType(): Byte {
        return CommandTypes.NETWORK_BRIDGE_FILTER
    }

    public mut prop networkBrokerId: ?BrokerId {
        get() {
            return this.networkBrokerIdVal
        }
        set(value) {
            this.networkBrokerIdVal = value
        }
    }

    public mut prop messageTTL: Int32 {
        get() {
            return this.messageTTLVal
        }
        set(value) {
            this.messageTTLVal = value
        }
    }

    public mut prop consumerTTL: Int32 {
        get() {
            return this.consumerTTLVal
        }
        set(value) {
            this.consumerTTLVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is NetworkBridgeFilter)) {
            return false
        }
        if (let Some(other) <- (other as NetworkBridgeFilter)) {
            if (let Some(networkBrokerId) <- this.networkBrokerIdVal) {
                if (let Some(otherNetworkBrokerId) <- other.networkBrokerIdVal) {
                    if (networkBrokerId != otherNetworkBrokerId) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.networkBrokerIdVal.isSome()) {
                    return false
                }
            }

            if (this.messageTTLVal != other.messageTTLVal) {
                return false
            }

            if (this.consumerTTLVal != other.consumerTTLVal) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is NetworkBridgeFilter)) {
            return true
        }
        if (let Some(other) <- (other as NetworkBridgeFilter)) {
            if (let Some(networkBrokerId) <- this.networkBrokerIdVal) {
                if (let Some(otherNetworkBrokerId) <- other.networkBrokerIdVal) {
                    if (networkBrokerId != otherNetworkBrokerId) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.networkBrokerIdVal.isSome()) {
                    return true
                }
            }

            if (this.messageTTLVal != other.messageTTLVal) {
                return true
            }

            if (this.consumerTTLVal != other.consumerTTLVal) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(networkBrokerId) <- this.networkBrokerIdVal) {
            hashCode += prime * networkBrokerId.hashCode()
        }
        hashCode += prime * this.messageTTLVal.hashCode()
        hashCode += prime * this.consumerTTLVal.hashCode()
        return hashCode
    }

    public func toString(): String {
        return "NetworkBridgeFilter: {networkBrokerId: ${networkBrokerIdVal},messageTTL: ${messageTTLVal},consumerTTL: ${consumerTTLVal}}"
    }
}
