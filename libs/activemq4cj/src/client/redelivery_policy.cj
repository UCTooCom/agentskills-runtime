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
package activemq4cj.client

public class RedeliveryPolicy <: Equatable<RedeliveryPolicy> & Hashable {
    public static let NO_MAXIMUM_REDELIVERIES: Int32 = -1
    //默认最大重发次数6
    public static let DEFAULT_MAXIMUM_REDELIVERIES: Int32 = 6

    private static var randomNumberGenerator: ?Random = None
    private static let monitor = Mutex()

    protected var collisionAvoidanceFactorVal: Float64 = 0.15
    //最大重传次数6，达到最大次数后进入死信队列，-1表示无限重试
    protected var maximumRedeliveriesVal: Int32 = DEFAULT_MAXIMUM_REDELIVERIES
    //如果useExponentialBackOff选项被设置，设置的这个最大重试延迟数将起作用
    protected var maximumRedeliveryDelayVal: Int64 = -1
    protected var initialRedeliveryDelayVal: Int64 = 1000
    //重传机制应该避免碰撞
    protected var useCollisionAvoidanceVal: Bool = false
    protected var useExponentialBackOffVal: Bool = false
    protected var backOffMultiplierVal: Float64 = 5.0
    protected var redeliveryDelayVal = initialRedeliveryDelayVal
    protected var preDispatchCheckVal: Bool = true

    public func copy(): RedeliveryPolicy {
        let copy = RedeliveryPolicy()
        copy.collisionAvoidanceFactor = this.collisionAvoidanceFactor
        copy.maximumRedeliveries = this.maximumRedeliveries
        copy.maximumRedeliveryDelay = this.maximumRedeliveryDelay
        copy.initialRedeliveryDelay = this.initialRedeliveryDelay
        copy.useCollisionAvoidance = this.useCollisionAvoidance
        copy.useExponentialBackOff = this.useExponentialBackOff
        copy.backOffMultiplier = this.backOffMultiplier
        copy.redeliveryDelay = this.redeliveryDelay
        copy.preDispatchCheck = this.preDispatchCheck
        return copy
    }

    public mut prop collisionAvoidanceFactor: Float64 {
        get() {
            return this.collisionAvoidanceFactorVal
        }
        set(value) {
            this.collisionAvoidanceFactorVal = value
        }
    }

    public mut prop maximumRedeliveries: Int32 {
        get() {
            return this.maximumRedeliveriesVal
        }
        set(value) {
            this.maximumRedeliveriesVal = value
        }
    }

    public mut prop maximumRedeliveryDelay: Int64 {
        get() {
            return this.maximumRedeliveryDelayVal
        }
        set(value) {
            this.maximumRedeliveryDelayVal = value
        }
    }

    public mut prop initialRedeliveryDelay: Int64 {
        get() {
            return this.initialRedeliveryDelayVal
        }
        set(value) {
            this.initialRedeliveryDelayVal = value
        }
    }

    public mut prop useCollisionAvoidance: Bool {
        get() {
            return this.useCollisionAvoidanceVal
        }
        set(value) {
            this.useCollisionAvoidanceVal = value
        }
    }

    public mut prop useExponentialBackOff: Bool {
        get() {
            return this.useExponentialBackOffVal
        }
        set(value) {
            this.useExponentialBackOffVal = value
        }
    }

    public mut prop backOffMultiplier: Float64 {
        get() {
            return this.backOffMultiplierVal
        }
        set(value) {
            this.backOffMultiplierVal = value
        }
    }

    public mut prop redeliveryDelay: Int64 {
        get() {
            return this.redeliveryDelayVal
        }
        set(value) {
            this.redeliveryDelayVal = value
        }
    }

    public mut prop preDispatchCheck: Bool {
        get() {
            return this.preDispatchCheckVal
        }
        set(value) {
            this.preDispatchCheckVal = value
        }
    }

    public func getNextRedeliveryDelay(previousDelay: Int64): Int64 {
        var nextDelay: Int64 = redeliveryDelay

        if (previousDelay > 0 && useExponentialBackOff && backOffMultiplier > Float64(1)) {
            nextDelay = Int64(Float64(previousDelay) * backOffMultiplier)
            if (maximumRedeliveryDelay != -1 && nextDelay > maximumRedeliveryDelay) {
                // in case the user made max redelivery delay less than redelivery delay for some reason.
                nextDelay = max(maximumRedeliveryDelay, redeliveryDelay)
            }
        }

        if (useCollisionAvoidance) {
            /*
             * First random determines +/-, second random determines how far to
             * go in that direction. -cgs
             */
            let random = getRandomNumberGenerator()
            var variance: Float64
            if (random.nextBool()) {
                variance = collisionAvoidanceFactor * random.nextFloat64()
            } else {
                variance = -collisionAvoidanceFactor * random.nextFloat64()
            }
            nextDelay += Int64(Float64(nextDelay) * variance)
        }
        return nextDelay;
    }

    protected static func getRandomNumberGenerator(): Random {
        if (let Some(random) <- randomNumberGenerator) {
            return random
        } else {
            synchronized(monitor) {
                if (randomNumberGenerator.isNone()) {
                    let random = Random()
                    randomNumberGenerator = random
                    return random
                }
                return getRandomNumberGenerator()
            }
        }
    }

    public operator func ==(other: RedeliveryPolicy): Bool {
        if (this.collisionAvoidanceFactor != other.collisionAvoidanceFactor) {
            return false
        }
        if (this.maximumRedeliveries != other.maximumRedeliveries) {
            return false
        }
        if (this.maximumRedeliveryDelay != other.maximumRedeliveryDelay) {
            return false
        }
        if (this.initialRedeliveryDelay != other.initialRedeliveryDelay) {
            return false
        }
        if (this.useCollisionAvoidance != other.useCollisionAvoidance) {
            return false
        }
        if (this.useExponentialBackOff != other.useExponentialBackOff) {
            return false
        }
        if (this.backOffMultiplier != other.backOffMultiplier) {
            return false
        }
        if (this.redeliveryDelay != other.redeliveryDelay) {
            return false
        }
        if (this.preDispatchCheck != other.preDispatchCheck) {
            return false
        }
        return true
    }

    public operator func !=(other: RedeliveryPolicy): Bool {
        if (this.collisionAvoidanceFactor != other.collisionAvoidanceFactor) {
            return true
        }
        if (this.maximumRedeliveries != other.maximumRedeliveries) {
            return true
        }
        if (this.maximumRedeliveryDelay != other.maximumRedeliveryDelay) {
            return true
        }
        if (this.initialRedeliveryDelay != other.initialRedeliveryDelay) {
            return true
        }
        if (this.useCollisionAvoidance != other.useCollisionAvoidance) {
            return true
        }
        if (this.useExponentialBackOff != other.useExponentialBackOff) {
            return true
        }
        if (this.backOffMultiplier != other.backOffMultiplier) {
            return true
        }
        if (this.redeliveryDelay != other.redeliveryDelay) {
            return true
        }
        if (this.preDispatchCheck != other.preDispatchCheck) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        let prime: Int64 = 53
        var hashCode = prime * collisionAvoidanceFactor.hashCode()
        hashCode += prime * maximumRedeliveries.hashCode()
        hashCode += prime * maximumRedeliveryDelay.hashCode()
        hashCode += prime * initialRedeliveryDelay.hashCode()
        hashCode += prime * useCollisionAvoidance.hashCode()
        hashCode += prime * useExponentialBackOff.hashCode()
        hashCode += prime * backOffMultiplier.hashCode()
        hashCode += prime * redeliveryDelay.hashCode()
        hashCode += prime * preDispatchCheck.hashCode()
        return hashCode
    }
}
