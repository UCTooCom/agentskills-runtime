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
package activemq4cj.client.filter

/**
 * 作为数据存储在DestinationNode上
 */
public class DestinationMapEntry<T> <: Comparable<DestinationMapEntry<T>> & Hashable where T <: Equatable<T> & Hashable {
    private var destinationVal: ?ActiveMQDestination = None
    private var value: T

    public init(value: T) {
        this.value = value
    }

    public init(destination: ActiveMQDestination, value: T) {
        this.destinationVal = destination
        this.value = value
    }

    public func setQueue(name: String): Unit {
        this.destinationVal = ActiveMQQueue(name)
    }

    /**
     * A helper method to set the destination from a configuration file
     */
    public func setTopic(name: String): Unit {
        this.destinationVal = ActiveMQTopic(name)
    }

    public func setTempTopic() {
        this.destinationVal = ActiveMQTempTopic(">")
    }

    public func setTempQueue() {
        this.destinationVal = ActiveMQTempQueue(">")
    }

    public mut prop destination: ?ActiveMQDestination {
        get() {
            return this.destinationVal
        }
        set(value) {
            this.destinationVal = value
        }
    }

    public func getValue(): T {
        return this.value
    }

    public operator override func ==(other: DestinationMapEntry<T>): Bool {
        if (this.destination != other.destination) {
            return false
        }
        if (this.value != other.value) {
            return false
        }
        return true
    }

    public operator override func !=(other: DestinationMapEntry<T>): Bool {
        if (this.destination != other.destination) {
            return true
        }
        if (this.value != other.value) {
            return true
        }
        return false
    }

    public operator override func >=(other: DestinationMapEntry<T>): Bool {
        if (ActiveMQDestination.compareTo(this.destination, other.destination) == Ordering.LT) {
            return false
        }
        return true
    }

    public operator override func >(other: DestinationMapEntry<T>): Bool {
        if (this.destination == other.destination) {
            return false
        }
        if (ActiveMQDestination.compareTo(this.destination, other.destination) == Ordering.LT) {
            return false
        }
        return true
    }

    public operator override func <=(other: DestinationMapEntry<T>): Bool {
        if (ActiveMQDestination.compareTo(this.destination, other.destination) == Ordering.GT) {
            return false
        }
        return true
    }

    public operator override func <(other: DestinationMapEntry<T>): Bool {
        if (this.destination == other.destination) {
            return false
        }
        if (ActiveMQDestination.compareTo(this.destination, other.destination) == Ordering.GT) {
            return false
        }
        return true
    }

    public override func compare(other: DestinationMapEntry<T>): Ordering {
        return ActiveMQDestination.compareTo(this.destination, other.destination)
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        let prime = 53
        var hashCode: Int64 = 0
        if (let Some(destination) <- this.destination) {
            hashCode += prime * destination.hashCode()
        }
        hashCode += prime * value.hashCode()
        return hashCode
    }
}
