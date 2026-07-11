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

public class BrokerId <: DataStructure {
    private var valueVal: ?String = None

    public init(value: String) {
        this.valueVal = value
    }

    public init() {
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.BROKER_ID
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
        if (!(other is BrokerId)) {
            return false
        }
        if (let Some(other) <- (other as BrokerId)) {
            if (this.valueVal != other.valueVal) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is BrokerId)) {
            return true
        }
        if (let Some(other) <- (other as BrokerId)) {
            if (this.valueVal != other.valueVal) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(value) <- this.valueVal) {
            hashCode += prime * value.hashCode()
        }
        return hashCode
    }

    public func toString(): String {
        return "BrokerId: {value: ${valueVal}}"
    }
}

public class BrokerInfo <: BaseCommand {
    private var brokerIdVal: ?BrokerId = None
    private var brokerURLVal: ?String = None
    private var slaveBrokerVal: Bool = false
    private var masterBrokerVal: Bool = false
    private var faultTolerantConfigurationVal: Bool = false
    private var networkConnectionVal: Bool = false
    private var duplexConnectionVal: Bool = false
    private var peerBrokerInfosVal: ?Array<BrokerInfo> = None
    private var brokerNameVal: ?String = None
    private var connectionIdVal: Int64 = 0
    private var brokerUploadUrlVal: ?String = None
    private var networkPropertiesVal: ?String = None

    public func getDataStructureType(): Byte {
        return CommandTypes.BROKER_INFO
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processBrokerInfo(this)
    }

    public mut prop brokerId: ?BrokerId {
        get() {
            return this.brokerIdVal
        }
        set(value) {
            this.brokerIdVal = value
        }
    }

    public mut prop brokerURL: ?String {
        get() {
            return this.brokerURLVal
        }
        set(value) {
            this.brokerURLVal = value
        }
    }

    public mut prop slaveBroker: Bool {
        get() {
            return this.slaveBrokerVal
        }
        set(value) {
            this.slaveBrokerVal = value
        }
    }

    public mut prop masterBroker: Bool {
        get() {
            return this.masterBrokerVal
        }
        set(value) {
            this.masterBrokerVal = value
        }
    }

    public mut prop faultTolerantConfiguration: Bool {
        get() {
            return this.faultTolerantConfigurationVal
        }
        set(value) {
            this.faultTolerantConfigurationVal = value
        }
    }

    public mut prop networkConnection: Bool {
        get() {
            return this.networkConnectionVal
        }
        set(value) {
            this.networkConnectionVal = value
        }
    }

    public mut prop duplexConnection: Bool {
        get() {
            return this.duplexConnectionVal
        }
        set(value) {
            this.duplexConnectionVal = value
        }
    }

    public mut prop peerBrokerInfos: ?Array<BrokerInfo> {
        get() {
            return this.peerBrokerInfosVal
        }
        set(value) {
            this.peerBrokerInfosVal = value
        }
    }

    public mut prop brokerName: ?String {
        get() {
            return this.brokerNameVal
        }
        set(value) {
            this.brokerNameVal = value
        }
    }

    public mut prop connectionId: Int64 {
        get() {
            return this.connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop brokerUploadUrl: ?String {
        get() {
            return this.brokerUploadUrlVal
        }
        set(value) {
            this.brokerUploadUrlVal = value
        }
    }

    public mut prop networkProperties: ?String {
        get() {
            return this.networkPropertiesVal
        }
        set(value) {
            this.networkPropertiesVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is BrokerInfo)) {
            return false
        }
        if (let Some(other) <- (other as BrokerInfo)) {
            if (let Some(brokerId) <- this.brokerIdVal) {
                if (let Some(otherBrokerId) <- other.brokerIdVal) {
                    if (brokerId != otherBrokerId) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.brokerIdVal.isSome()) {
                    return false
                }
            }

            if (this.brokerURLVal != other.brokerURLVal) {
                return false
            }

            if (this.slaveBrokerVal != other.slaveBrokerVal) {
                return false
            }

            if (this.masterBrokerVal != other.masterBrokerVal) {
                return false
            }

            if (this.faultTolerantConfigurationVal != other.faultTolerantConfigurationVal) {
                return false
            }

            if (this.networkConnectionVal != other.networkConnectionVal) {
                return false
            }

            if (this.duplexConnectionVal != other.duplexConnectionVal) {
                return false
            }

            if (let Some(peerBrokerInfos) <- this.peerBrokerInfosVal) {
                if (let Some(otherPeerBrokerInfos) <- other.peerBrokerInfosVal) {
                    if (peerBrokerInfos.size != otherPeerBrokerInfos.size) {
                        return false
                    }
                    for (i in 0..peerBrokerInfos.size) {
                        if (peerBrokerInfos[i] != otherPeerBrokerInfos[i]) {
                            return false
                        }
                    }
                } else {
                    return false
                }
            } else {
                if (other.peerBrokerInfosVal.isSome()) {
                    return false
                }
            }

            if (this.brokerNameVal != other.brokerNameVal) {
                return false
            }

            if (this.connectionIdVal != other.connectionIdVal) {
                return false
            }

            if (this.brokerUploadUrlVal != other.brokerUploadUrlVal) {
                return false
            }

            if (this.networkPropertiesVal != other.networkPropertiesVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is BrokerInfo)) {
            return true
        }
        if (let Some(other) <- (other as BrokerInfo)) {
            if (let Some(brokerId) <- this.brokerIdVal) {
                if (let Some(otherBrokerId) <- other.brokerIdVal) {
                    if (brokerId != otherBrokerId) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.brokerIdVal.isSome()) {
                    return true
                }
            }

            if (this.brokerURLVal != other.brokerURLVal) {
                return true
            }

            if (this.slaveBrokerVal != other.slaveBrokerVal) {
                return true
            }

            if (this.masterBrokerVal != other.masterBrokerVal) {
                return true
            }

            if (this.faultTolerantConfigurationVal != other.faultTolerantConfigurationVal) {
                return true
            }

            if (this.networkConnectionVal != other.networkConnectionVal) {
                return true
            }

            if (this.duplexConnectionVal != other.duplexConnectionVal) {
                return true
            }

            if (let Some(peerBrokerInfos) <- this.peerBrokerInfosVal) {
                if (let Some(otherPeerBrokerInfos) <- other.peerBrokerInfosVal) {
                    if (peerBrokerInfos.size != otherPeerBrokerInfos.size) {
                        return true
                    }
                    for (i in 0..peerBrokerInfos.size) {
                        if (peerBrokerInfos[i] != otherPeerBrokerInfos[i]) {
                            return true
                        }
                    }
                } else {
                    return true
                }
            } else {
                if (other.peerBrokerInfosVal.isSome()) {
                    return true
                }
            }

            if (this.brokerNameVal != other.brokerNameVal) {
                return true
            }

            if (this.connectionIdVal != other.connectionIdVal) {
                return true
            }

            if (this.brokerUploadUrlVal != other.brokerUploadUrlVal) {
                return true
            }

            if (this.networkPropertiesVal != other.networkPropertiesVal) {
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
            "{${super.toString()}, brokerId: ${brokerIdVal}, brokerURL:${brokerURLVal}, slaveBroker: ${slaveBrokerVal}, masterBroker: ${masterBrokerVal},"
        )
        sb.append(
            "faultTolerantConfiguration: ${faultTolerantConfigurationVal}, networkConnection: ${networkConnectionVal}, duplexConnection: ${duplexConnectionVal}, peerBrokerInfos: ${peerBrokerInfosVal},"
        )
        sb.append(
            "brokerName: ${brokerNameVal}, connectionId: ${connectionIdVal}, brokerUploadUrl:${brokerUploadUrlVal}, networkProperties: ${networkPropertiesVal}}"
        )
        return sb.toString()
    }
}
