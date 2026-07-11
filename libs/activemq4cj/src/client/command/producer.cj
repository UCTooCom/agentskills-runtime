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

public class ProducerId <: DataStructure & Equatable<ProducerId> {
    private var connectionIdVal: ?String = None
    private var sessionIdVal: Int64 = 0
    private var valueVal: Int64 = 0

    public init() {
    }

    public ProducerId(producerKey: String) {
        var key = producerKey
        // 解析ProducerId
        if (let Some(p) <- producerKey.lastIndexOf(":")) {
            if (p >= 0) {
                key = producerKey[0..p]
                value = Int64.parse(producerKey[p + 1..producerKey.size])
            }
        }
        setProducerSessionKey(key)
    }

    public init(sessionId: ?SessionId, value: Int64) {
        if (let Some(sessionId) <- sessionId) {
            this.sessionIdVal = sessionId.value
            this.connectionIdVal = sessionId.connectionId
        }
        this.value = value
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.PRODUCER_ID
    }

    public func copy(): ProducerId {
        var copy = ProducerId()
        copy.connectionId = this.connectionId
        copy.sessionId = this.sessionId
        copy.value = this.value
        return copy
    }

    public mut prop connectionId: ?String {
        get() {
            return connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop sessionId: Int64 {
        get() {
            return sessionIdVal
        }
        set(value) {
            this.sessionIdVal = value
        }
    }

    public mut prop value: Int64 {
        get() {
            return valueVal
        }
        set(value) {
            this.valueVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ProducerId)) {
            return false
        }
        if (let Some(other) <- (other as ProducerId)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return false
            }

            if (this.sessionIdVal != other.sessionIdVal) {
                return false
            }

            if (this.valueVal != other.valueVal) {
                return false
            }
        }
        return true
    }

    public operator override func ==(other: ProducerId): Bool {
        if (this.connectionIdVal != other.connectionIdVal) {
            return false
        }

        if (this.sessionIdVal != other.sessionIdVal) {
            return false
        }

        if (this.valueVal != other.valueVal) {
            return false
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ProducerId)) {
            return true
        }
        if (let Some(other) <- (other as ProducerId)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return true
            }

            if (this.sessionIdVal != other.sessionIdVal) {
                return true
            }

            if (this.valueVal != other.valueVal) {
                return true
            }
        }
        return false
    }

    public operator override func !=(other: ProducerId): Bool {
        if (this.connectionIdVal != other.connectionIdVal) {
            return false
        }

        if (this.sessionIdVal != other.sessionIdVal) {
            return true
        }

        if (this.valueVal != other.valueVal) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(connectionId) <- this.connectionIdVal) {
            hashCode += prime * connectionId.hashCode()
        }
        hashCode += prime * this.sessionIdVal
        hashCode += prime * this.valueVal
        return hashCode
    }

    private func setProducerSessionKey(sessionKey: String) {
        // 解析出value
        var key = sessionKey
        if (let Some(p) <- sessionKey.lastIndexOf(":")) {
            if (p >= 0) {
                key = sessionKey[0..p]
                sessionId = Int64.parse(sessionKey[p + 1..sessionKey.size])
            }
        }
        // The rest is the value
        connectionId = key
    }

    public func toString(): String {
        var sb = StringBuilder()
        if (let Some(connectionId) <- connectionId) {
            sb.append(connectionId)
        }
        sb.append(":${sessionIdVal}:${valueVal}")
        return sb.toString()
    }
}

public class ProducerInfo <: BaseCommand {
    private var producerIdVal: ?ProducerId = None
    private var destinationVal: ?ActiveMQDestination = None
    private var brokerPathVal: ?Array<BrokerId> = None
    private var dispatchAsyncVal: Bool = false
    private var windowSizeVal: Int32 = 0
    private var sentCount: ?AtomicInt64 = None

    public func getDataStructureType(): Byte {
        return CommandTypes.PRODUCER_INFO
    }

    public init() {
    }

    public init(producerId: ProducerId) {
        this.producerIdVal = producerId
    }

    public func createRemoveInfo(): RemoveInfo {
        let removeInfo = RemoveInfo()
        if (let Some(producerId) <- this.producerId) {
            removeInfo.objectId = producerId
        }
        return removeInfo
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processAddProducer(this)
    }

    public mut prop producerId: ?ProducerId {
        get() {
            return producerIdVal
        }
        set(value) {
            this.producerIdVal = value
        }
    }

    public mut prop destination: ?ActiveMQDestination {
        get() {
            return destinationVal
        }
        set(value) {
            this.destinationVal = value
        }
    }

    public mut prop brokerPath: ?Array<BrokerId> {
        get() {
            return brokerPathVal
        }
        set(value) {
            this.brokerPathVal = value
        }
    }

    public mut prop dispatchAsync: Bool {
        get() {
            return dispatchAsyncVal
        }
        set(value) {
            this.dispatchAsyncVal = value
        }
    }

    public mut prop windowSize: Int32 {
        get() {
            return windowSizeVal
        }
        set(value) {
            this.windowSizeVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is ProducerInfo)) {
            return false
        }
        if (let Some(other) <- (other as ProducerInfo)) {
            if (this.producerIdVal != other.producerIdVal) {
                return false
            }

            if (this.destinationVal != other.destinationVal) {
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

            if (this.dispatchAsyncVal != dispatchAsyncVal) {
                return false
            }

            if (this.windowSizeVal != other.windowSizeVal) {
                return false
            }
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is ProducerInfo)) {
            return true
        }
        if (let Some(other) <- (other as ProducerInfo)) {
            if (this.producerIdVal != other.producerIdVal) {
                return true
            }

            if (this.destinationVal != other.destinationVal) {
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

            if (this.dispatchAsyncVal != dispatchAsyncVal) {
                return true
            }

            if (this.windowSizeVal != other.windowSizeVal) {
                return true
            }
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
