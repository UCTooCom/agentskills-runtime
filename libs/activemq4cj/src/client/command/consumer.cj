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

public class ConsumerId <: DataStructure & Equatable<ConsumerId> & Hashable {
    private var connectionIdVal: ?String = None
    private var sessionIdVal: Int64 = 0
    private var valueVal: Int64 = 0

    public init() {
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.CONSUMER_ID
    }

    public init(sessionId: ?SessionId, value: Int64) {
        if (let Some(sessionId) <- sessionId) {
            this.sessionIdVal = sessionId.value
            this.connectionIdVal = sessionId.connectionId
        }
        this.value = value
    }

    public mut prop connectionId: ?String {
        get() {
            return this.connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop sessionId: Int64 {
        get() {
            return this.sessionIdVal
        }
        set(value) {
            this.sessionIdVal = value
        }
    }

    public mut prop value: Int64 {
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

    public operator override func ==(other: ConsumerId): Bool {
        if (this.connectionIdVal != other.connectionIdVal) {
            return false
        }

        if (this.sessionId != other.sessionId) {
            return false
        }
        if (this.value != other.value) {
            return false
        }
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ConsumerId)) {
            return false
        }
        if (let Some(other) <- (other as ConsumerId)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return false
            }
            if (this.sessionId != other.sessionId) {
                return false
            }
            if (this.value != other.value) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: ConsumerId): Bool {
        if (this.connectionIdVal != other.connectionIdVal) {
            return true
        }
        if (this.sessionId != other.sessionId) {
            return true
        }
        if (this.value != other.value) {
            return true
        }
        return false
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ConsumerId)) {
            return true
        }
        if (let Some(other) <- (other as ConsumerId)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return true
            }
            if (this.sessionId != other.sessionId) {
                return true
            }
            if (this.value != other.value) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 51
        var hashCode = 0
        if (let Some(connectionId) <- connectionIdVal) {
            hashCode += prime * connectionId.hashCode()
        }
        hashCode += prime * sessionIdVal.hashCode()
        hashCode += prime * valueVal.hashCode()
        return hashCode
    }

    public func toString(): String {
        var sb = StringBuilder()
        if (let Some(connectionId) <- this.connectionId) {
            sb.append(connectionId)
        }
        sb.append(":${sessionId}:${value}")
        return sb.toString()
    }
}

public class ConsumerInfo <: BaseCommand {
    private var consumerIdVal: ?ConsumerId = None
    private var destinationVal: ?ActiveMQDestination = None
    private var prefetchSizeVal: Int32 = 0
    private var maximumPendingMessageLimitVal: Int32 = 0
    private var browserVal: Bool = false
    private var dispatchAsyncVal: Bool = false
    private var selectorVal: ?String = None
    private var clientIdVal: ?String = None
    private var subscriptionNameVal: ?String = None
    private var noLocalVal: Bool = false
    private var exclusiveVal: Bool = false
    private var retroactiveVal: Bool = false
    private var priorityVal: Byte = 0
    private var brokerPathVal: ?Array<BrokerId> = None
    private var optimizedAcknowledgeVal: Bool = false
    private var noRangeAcksVal: Bool = false
    private var additionalPredicateVal: ?BooleanExpression = None
    private var networkSubscriptionVal: Bool = false
    private var networkConsumerIdsVal: ?Array<ConsumerId> = None

    public func getDataStructureType(): Byte {
        return CommandTypes.CONSUMER_INFO
    }

    public func createRemoveInfo(): RemoveInfo {
        let removeInfo = RemoveInfo()
        if (let Some(consumerId) <- this.consumerId) {
            removeInfo.objectId = consumerId
        }
        return removeInfo
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processAddConsumer(this)
    }

    public func copy(): ConsumerInfo {
        var copy = ConsumerInfo()
        super.copy(copy)
        copy.consumerId = consumerId
        copy.destination = destination
        copy.prefetchSize = prefetchSize
        copy.maximumPendingMessageLimit = maximumPendingMessageLimit
        copy.browser = browser
        copy.dispatchAsync = dispatchAsync
        copy.selector = selector
        copy.clientId = clientId
        copy.subscriptionName = subscriptionName
        copy.noLocal = noLocal
        copy.exclusive = exclusive
        copy.retroactive = retroactive
        copy.priority = priority
        copy.brokerPath = brokerPath
        copy.networkSubscription = networkSubscription
        if (let Some(networkConsumerIds) <- this.networkConsumerIds) {
            copy.networkConsumerIds = networkConsumerIds.clone()
        }
        return copy
    }

    public mut prop consumerId: ?ConsumerId {
        get() {
            return this.consumerIdVal
        }
        set(value) {
            this.consumerIdVal = value
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

    public mut prop prefetchSize: Int32 {
        get() {
            return this.prefetchSizeVal
        }
        set(value) {
            this.prefetchSizeVal = value
        }
    }

    public mut prop maximumPendingMessageLimit: Int32 {
        get() {
            return this.maximumPendingMessageLimitVal
        }
        set(value) {
            this.maximumPendingMessageLimitVal = value
        }
    }

    public mut prop browser: Bool {
        get() {
            return this.browserVal
        }
        set(value) {
            this.browserVal = value
        }
    }

    public mut prop dispatchAsync: Bool {
        get() {
            return this.dispatchAsyncVal
        }
        set(value) {
            this.dispatchAsyncVal = value
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

    public mut prop noLocal: Bool {
        get() {
            return this.noLocalVal
        }
        set(value) {
            this.noLocalVal = value
        }
    }

    public mut prop exclusive: Bool {
        get() {
            return this.exclusiveVal
        }
        set(value) {
            this.exclusiveVal = value
        }
    }

    public mut prop retroactive: Bool {
        get() {
            return this.retroactiveVal
        }
        set(value) {
            this.retroactiveVal = value
        }
    }

    public mut prop priority: Byte {
        get() {
            return this.priorityVal
        }
        set(value) {
            this.priorityVal = value
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

    public mut prop optimizedAcknowledge: Bool {
        get() {
            return this.optimizedAcknowledgeVal
        }
        set(value) {
            this.optimizedAcknowledgeVal = value
        }
    }

    public mut prop noRangeAcks: Bool {
        get() {
            return this.noRangeAcksVal
        }
        set(value) {
            this.noRangeAcksVal = value
        }
    }

    public mut prop additionalPredicate: ?BooleanExpression {
        get() {
            return this.additionalPredicateVal
        }
        set(value) {
            this.additionalPredicateVal = value
        }
    }

    public mut prop networkSubscription: Bool {
        get() {
            return this.networkSubscriptionVal
        }
        set(value) {
            this.networkSubscriptionVal = value
        }
    }

    public mut prop networkConsumerIds: ?Array<ConsumerId> {
        get() {
            return this.networkConsumerIdsVal
        }
        set(value) {
            this.networkConsumerIdsVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ConsumerInfo)) {
            return false
        }
        if (let Some(other) <- (other as ConsumerInfo)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return false
            }

            if (let Some(destination) <- destinationVal) {
                if (let Some(otherDestination) <- other.destinationVal) {
                    if (destination != otherDestination) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.destinationVal.isSome()) {
                    return false
                }
            }

            if (this.prefetchSizeVal != other.prefetchSizeVal) {
                return false
            }

            if (this.maximumPendingMessageLimitVal != other.maximumPendingMessageLimitVal) {
                return false
            }

            if (this.browserVal != other.browserVal) {
                return false
            }

            if (this.dispatchAsyncVal != other.dispatchAsyncVal) {
                return false
            }

            if (this.selectorVal != other.selectorVal) {
                return false
            }

            if (this.clientIdVal != other.clientIdVal) {
                return false
            }

            if (this.subscriptionNameVal != other.subscriptionNameVal) {
                return false
            }

            if (this.noLocalVal != other.noLocalVal) {
                return false
            }

            if (this.exclusiveVal != other.exclusiveVal) {
                return false
            }

            if (this.retroactiveVal != other.retroactiveVal) {
                return false
            }

            if (this.priorityVal != other.priorityVal) {
                return false
            }

            if (let Some(brokerPath) <- brokerPathVal) {
                if (let Some(otherBrokerPath) <- other.brokerPathVal) {
                    if (brokerPath.size != otherBrokerPath.size) {
                        return false
                    }
                    for (i in 0..brokerPath.size) {
                        if (brokerPath[i] != otherBrokerPath[i]) {
                            return false
                        }
                    }
                } else {
                    return false
                }
            } else {
                if (other.brokerPathVal.isSome()) {
                    return false
                }
            }

            if (this.optimizedAcknowledgeVal != other.optimizedAcknowledgeVal) {
                return false
            }

            if (this.noRangeAcksVal != other.noRangeAcksVal) {
                return false
            }

            if (this.networkSubscriptionVal != other.networkSubscriptionVal) {
                return false
            }

            if (let Some(networkConsumerIds) <- networkConsumerIdsVal) {
                if (let Some(otherNetworkConsumerIds) <- other.networkConsumerIdsVal) {
                    if (networkConsumerIds.size != otherNetworkConsumerIds.size) {
                        return false
                    }
                    for (i in 0..networkConsumerIds.size) {
                        if (networkConsumerIds[i] != otherNetworkConsumerIds[i]) {
                            return false
                        }
                    }
                } else {
                    return false
                }
            } else {
                if (other.networkConsumerIdsVal.isSome()) {
                    return false
                }
            }
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ConsumerInfo)) {
            return true
        }
        if (let Some(other) <- (other as ConsumerInfo)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return true
            }

            if (let Some(destination) <- destinationVal) {
                if (let Some(otherDestination) <- other.destinationVal) {
                    if (destination != otherDestination) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.destinationVal.isSome()) {
                    return true
                }
            }

            if (this.prefetchSizeVal != other.prefetchSizeVal) {
                return true
            }

            if (this.maximumPendingMessageLimitVal != other.maximumPendingMessageLimitVal) {
                return true
            }

            if (this.browserVal != other.browserVal) {
                return true
            }

            if (this.dispatchAsyncVal != other.dispatchAsyncVal) {
                return true
            }

            if (this.selectorVal != other.selectorVal) {
                return true
            }

            if (this.clientIdVal != other.clientIdVal) {
                return true
            }

            if (this.subscriptionNameVal != other.subscriptionNameVal) {
                return true
            }

            if (this.noLocalVal != other.noLocalVal) {
                return true
            }

            if (this.exclusiveVal != other.exclusiveVal) {
                return true
            }

            if (this.retroactiveVal != other.retroactiveVal) {
                return true
            }

            if (this.priorityVal != other.priorityVal) {
                return true
            }

            if (let Some(brokerPath) <- brokerPathVal) {
                if (let Some(otherBrokerPath) <- other.brokerPathVal) {
                    if (brokerPath.size != otherBrokerPath.size) {
                        return true
                    }
                    for (i in 0..brokerPath.size) {
                        if (brokerPath[i] != otherBrokerPath[i]) {
                            return true
                        }
                    }
                } else {
                    return true
                }
            } else {
                if (other.brokerPathVal.isSome()) {
                    return true
                }
            }

            if (this.optimizedAcknowledgeVal != other.optimizedAcknowledgeVal) {
                return true
            }

            if (this.noRangeAcksVal != other.noRangeAcksVal) {
                return true
            }

            if (this.networkSubscriptionVal != other.networkSubscriptionVal) {
                return true
            }

            if (let Some(networkConsumerIds) <- networkConsumerIdsVal) {
                if (let Some(otherNetworkConsumerIds) <- other.networkConsumerIdsVal) {
                    if (networkConsumerIds.size != otherNetworkConsumerIds.size) {
                        return true
                    }
                    for (i in 0..networkConsumerIds.size) {
                        if (networkConsumerIds[i] != otherNetworkConsumerIds[i]) {
                            return true
                        }
                    }
                } else {
                    return true
                }
            } else {
                if (other.networkConsumerIdsVal.isSome()) {
                    return true
                }
            }
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        return """
    ConsumerInfo: {${super.toString()}, consumerId: ${consumerIdVal}, destination: ${this.destinationVal}, prefetchSize: ${prefetchSizeVal}, maximumPendingMessageLimit: ${maximumPendingMessageLimitVal}, 
    browser: ${browserVal}, dispatchAsync: ${dispatchAsyncVal}, selector: ${selectorVal}, clientId: ${clientIdVal}, subscriptionName: ${subscriptionNameVal}, noLocal: ${noLocalVal}, 
        exclusive: ${exclusiveVal}, retroactive: ${retroactiveVal}, priority: ${priorityVal}, brokerPath: ${brokerPathVal}, optimizedAcknowledge: ${optimizedAcknowledgeVal}, noRangeAcks: ${noRangeAcksVal}, 
        additionalPredicate: ${additionalPredicateVal}, networkSubscription: ${networkSubscriptionVal}, networkConsumerIds: ${networkConsumerIdsVal}}
            """
    }
}
