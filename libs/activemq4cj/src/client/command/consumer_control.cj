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

public class ConsumerControl <: BaseCommand {
    private var consumerIdVal: ?ConsumerId = None
    private var closeVal: Bool = false
    private var stopVal: Bool = false
    private var startVal: Bool = false
    private var flushVal: Bool = false
    private var prefetchVal: Int32 = 0
    private var destinationVal: ?ActiveMQDestination = None

    public func getDataStructureType(): Byte {
        return CommandTypes.CONSUMER_CONTROL
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processConsumerControl(this)
    }

    public mut prop consumerId: ?ConsumerId {
        get() {
            return this.consumerIdVal
        }
        set(value) {
            this.consumerIdVal = value
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

    public mut prop stop: Bool {
        get() {
            return this.stopVal
        }
        set(value) {
            this.stopVal = value
        }
    }

    public mut prop start: Bool {
        get() {
            return this.startVal
        }
        set(value) {
            this.startVal = value
        }
    }

    public mut prop flush: Bool {
        get() {
            return this.flushVal
        }
        set(value) {
            this.flushVal = value
        }
    }

    public mut prop prefetch: Int32 {
        get() {
            return this.prefetchVal
        }
        set(value) {
            this.prefetchVal = value
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

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ConsumerControl)) {
            return false
        }
        if (let Some(other) <- (other as ConsumerControl)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return false
            }

            if (this.closeVal != other.closeVal) {
                return false
            }

            if (this.stopVal != other.stopVal) {
                return false
            }

            if (this.startVal != other.startVal) {
                return false
            }

            if (this.flushVal != other.flushVal) {
                return false
            }

            if (this.prefetchVal != other.prefetchVal) {
                return false
            }

            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ConsumerControl)) {
            return true
        }
        if (let Some(other) <- (other as ConsumerControl)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return true
            }

            if (this.closeVal != other.closeVal) {
                return true
            }

            if (this.stopVal != other.stopVal) {
                return true
            }

            if (this.startVal != other.startVal) {
                return true
            }

            if (this.flushVal != other.flushVal) {
                return true
            }

            if (this.prefetchVal != other.prefetchVal) {
                return true
            }

            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        return "ConsumerControl: {${super.toString()}, consumerId: ${consumerIdVal}, close: ${closeVal}, stop: ${stopVal}, start: ${startVal}, flush: ${flushVal}, prefetch: ${prefetchVal}, destination: ${destinationVal}}"
    }
}
