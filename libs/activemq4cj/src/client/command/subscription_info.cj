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

public class SubscriptionInfo <: DataStructure {
    private var subscribedDestinationVal: ?ActiveMQDestination = None
    private var destinationVal: ?ActiveMQDestination = None
    private var clientIdVal: ?String = None
    private var subscriptionNameVal: ?String = None
    private var selectorVal: ?String = None
    private var noLocalVal: Bool = false

    public func getDataStructureType(): Byte {
        return CommandTypes.DURABLE_SUBSCRIPTION_INFO
    }

    public mut prop subscribedDestination: ?ActiveMQDestination {
        get() {
            return this.subscribedDestinationVal
        }
        set(value) {
            this.subscribedDestinationVal = value
        }
    }

    public mut prop destination: ?ActiveMQDestination {
        get() {
            return this.destinationVal
        }
        set(value) {
            this.destinationVal = value
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

    public mut prop subscriptionName: ?String {
        get() {
            return this.subscriptionNameVal
        }
        set(value) {
            this.subscriptionNameVal = value
        }
    }

    public mut prop selector: ?String {
        get() {
            return this.selectorVal
        }
        set(value) {
            this.selectorVal = value
        }
    }

    public mut prop noLocal: Bool {
        get() {
            return this.noLocalVal
        }
        set(value) {
            this.noLocalVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is SubscriptionInfo)) {
            return false
        }
        if (let Some(other) <- (other as SubscriptionInfo)) {
            if (this.subscribedDestinationVal != other.subscribedDestinationVal) {
                return false
            }

            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (this.clientIdVal != other.clientIdVal) {
                return false
            }

            if (this.subscriptionNameVal != other.subscriptionNameVal) {
                return false
            }

            if (this.selectorVal != other.selectorVal) {
                return false
            }

            if (this.noLocalVal != other.noLocalVal) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is SubscriptionInfo)) {
            return true
        }
        if (let Some(other) <- (other as SubscriptionInfo)) {
            if (this.subscribedDestinationVal != other.subscribedDestinationVal) {
                return true
            }

            if (this.destinationVal != other.destinationVal) {
                return true
            }

            if (this.clientIdVal != other.clientIdVal) {
                return true
            }

            if (this.subscriptionNameVal != other.subscriptionNameVal) {
                return true
            }

            if (this.selectorVal != other.selectorVal) {
                return true
            }

            if (this.noLocalVal != other.noLocalVal) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(subscribedDestination) <- this.subscribedDestinationVal) {
            hashCode += prime * subscribedDestination.hashCode()
        }
        if (let Some(destination) <- this.destinationVal) {
            hashCode += prime * destination.hashCode()
        }
        if (let Some(clientId) <- this.clientIdVal) {
            hashCode += prime * clientId.hashCode()
        }
        if (let Some(subscriptionName) <- this.subscriptionNameVal) {
            hashCode += prime * subscriptionName.hashCode()
        }
        if (let Some(selector) <- this.selectorVal) {
            hashCode += prime * selector.hashCode()
        }
        hashCode += prime * this.noLocalVal.hashCode()
        return hashCode
    }

    public override func toString(): String {
        return "SubscriptionInfo: {subscribedDestination: ${subscribedDestinationVal}, destination: ${destinationVal}, clientId: ${clientIdVal}, subscriptionName: ${subscriptionNameVal}, selector: ${selectorVal}, noLocal:${noLocalVal}}"
    }
}
