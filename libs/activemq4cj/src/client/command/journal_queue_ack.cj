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

public class JournalQueueAck <: DataStructure {
    private var destinationVal: ?ActiveMQDestination = None
    private var messageAckVal: ?MessageAck = None

    public func getDataStructureType(): Byte {
        return CommandTypes.JOURNAL_REMOVE
    }

    public mut prop destination: ?ActiveMQDestination {
        get() {
            return this.destinationVal
        }
        set(value) {
            this.destinationVal = value
        }
    }

    public mut prop messageAck: ?MessageAck {
        get() {
            return this.messageAckVal
        }
        set(value) {
            this.messageAckVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is JournalQueueAck)) {
            return false
        }
        if (let Some(other) <- (other as JournalQueueAck)) {
            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (let Some(messageAck) <- this.messageAckVal) {
                if (let Some(otherMessageAck) <- other.messageAckVal) {
                    if (messageAck != otherMessageAck) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.messageAckVal.isSome()) {
                    return false
                }
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is JournalQueueAck)) {
            return true
        }
        if (let Some(other) <- (other as JournalQueueAck)) {
            if (this.destinationVal != other.destinationVal) {
                return true
            }

            if (let Some(messageAck) <- this.messageAckVal) {
                if (let Some(otherMessageAck) <- other.messageAckVal) {
                    if (messageAck != otherMessageAck) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.messageAckVal.isSome()) {
                    return true
                }
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(destination) <- this.destinationVal) {
            hashCode += prime * destination.hashCode()
        }
        if (let Some(messageAck) <- this.messageAckVal) {
            hashCode += prime * messageAck.hashCode()
        }
        return hashCode
    }

    public override func toString(): String {
        return "JournalQueueAck: {destination: ${destinationVal}, messageAck: ${messageAckVal}}"
    }
}
