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

public class DiscoveryEvent <: DataStructure {
    private var serviceNameVal: ?String = None
    private var brokerNameVal: ?String = None

    public func getDataStructureType(): Byte {
        return CommandTypes.DISCOVERY_EVENT
    }

    public mut prop serviceName: ?String {
        get() {
            return this.serviceNameVal
        }
        set(value) {
            this.serviceNameVal = value
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

    public override func isMarshallAware(): Bool {
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is DiscoveryEvent)) {
            return false
        }
        if (let Some(other) <- (other as DiscoveryEvent)) {
            if (this.serviceNameVal != other.serviceNameVal) {
                return false
            }

            if (this.brokerNameVal != other.brokerNameVal) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is DiscoveryEvent)) {
            return true
        }
        if (let Some(other) <- (other as DiscoveryEvent)) {
            if (this.serviceNameVal != other.serviceNameVal) {
                return true
            }

            if (this.brokerNameVal != other.brokerNameVal) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(serviceName) <- this.serviceNameVal) {
            hashCode += prime * serviceName.hashCode()
        }
        if (let Some(brokerName) <- this.brokerNameVal) {
            hashCode += prime * brokerName.hashCode()
        }
        return hashCode
    }

    public func toString(): String {
        return "DiscoveryEvent: {serviceName: ${serviceNameVal},brokerName: ${brokerNameVal}}"
    }
}
