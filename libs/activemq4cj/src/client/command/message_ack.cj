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

public class MessageAck <: BaseCommand {
    public static let DELIVERED_ACK_TYPE: Byte = 0
    public static let STANDARD_ACK_TYPE: Byte = 2
    public static let POISON_ACK_TYPE: Byte = 1
    public static let REDELIVERED_ACK_TYPE: Byte = 3
    public static let INDIVIDUAL_ACK_TYPE: Byte = 4
    public static let UNMATCHED_ACK_TYPE: Byte = 5
    public static let EXPIRED_ACK_TYPE: Byte = 6

    private var ackTypeVal: Byte = 0
    private var consumerIdVal: ?ConsumerId = None
    private var firstMessageIdVal: ?MessageId = None
    private var lastMessageIdVal: ?MessageId = None
    private var destinationVal: ?ActiveMQDestination = None
    private var transactionIdVal: ?TransactionId = None
    private var messageCountVal: Int32 = 0
    private var poisonCauseVal: ?Throwable = None

    public init() {
    }

    public init(md: MessageDispatch, ackType: Byte, messageCount: Int32) {
        this.ackTypeVal = ackType
        this.consumerIdVal = md.consumerId
        this.destinationVal = md.destination
        if (let Some(message) <- md.message) {
            this.lastMessageIdVal = message.messageId
        }
        this.messageCountVal = messageCount
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.MESSAGE_ACK
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processMessageAck(this)
    }

    public func isStandardAck(): Bool {
        return ackType == STANDARD_ACK_TYPE
    }

    public func isDeliveredAck(): Bool {
        return ackType == DELIVERED_ACK_TYPE
    }

    public func isExpiredAck(): Bool {
        return ackType == EXPIRED_ACK_TYPE
    }

    public mut prop ackType: Byte {
        get() {
            return this.ackTypeVal
        }
        set(value) {
            this.ackTypeVal = value
        }
    }

    public mut prop consumerId: ?ConsumerId {
        get() {
            return this.consumerIdVal
        }
        set(value) {
            this.consumerIdVal = value
        }
    }

    public mut prop firstMessageId: ?MessageId {
        get() {
            return this.firstMessageIdVal
        }
        set(value) {
            this.firstMessageIdVal = value
        }
    }

    public mut prop lastMessageId: ?MessageId {
        get() {
            return this.lastMessageIdVal
        }
        set(value) {
            this.lastMessageIdVal = value
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

    public mut prop transactionId: ?TransactionId {
        get() {
            return this.transactionIdVal
        }
        set(value) {
            this.transactionIdVal = value
        }
    }

    public mut prop messageCount: Int32 {
        get() {
            return this.messageCountVal
        }
        set(value) {
            this.messageCountVal = value
        }
    }

    public mut prop poisonCause: ?Throwable {
        get() {
            return this.poisonCauseVal
        }
        set(value) {
            this.poisonCauseVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is MessageAck)) {
            return false
        }
        if (let Some(other) <- (other as MessageAck)) {
            if (ackTypeVal != other.ackTypeVal) {
                return false
            }

            if (this.consumerIdVal != other.consumerIdVal) {
                return false
            }

            if (let Some(firstMessageId) <- firstMessageIdVal) {
                if (let Some(otherFirstMessageId) <- other.firstMessageIdVal) {
                    if (firstMessageId != otherFirstMessageId) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.firstMessageIdVal.isSome()) {
                    return false
                }
            }

            if (let Some(lastMessageId) <- lastMessageIdVal) {
                if (let Some(otherLastMessageId) <- other.lastMessageIdVal) {
                    if (lastMessageId != otherLastMessageId) {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                if (other.lastMessageIdVal.isSome()) {
                    return false
                }
            }

            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return false
            }

            if (this.messageCountVal != other.messageCountVal) {
                return false
            }

            if (this.poisonCauseVal != other.poisonCauseVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }

        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is MessageAck)) {
            return true
        }
        if (let Some(other) <- (other as MessageAck)) {
            if (ackTypeVal != other.ackTypeVal) {
                return true
            }
            if (this.consumerIdVal != other.consumerIdVal) {
                return true
            }

            if (let Some(firstMessageId) <- firstMessageIdVal) {
                if (let Some(otherFirstMessageId) <- other.firstMessageIdVal) {
                    if (firstMessageId != otherFirstMessageId) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.firstMessageIdVal.isSome()) {
                    return true
                }
            }

            if (let Some(lastMessageId) <- lastMessageIdVal) {
                if (let Some(otherLastMessageId) <- other.lastMessageIdVal) {
                    if (lastMessageId != otherLastMessageId) {
                        return true
                    }
                } else {
                    return true
                }
            } else {
                if (other.lastMessageIdVal.isSome()) {
                    return true
                }
            }

            if (this.destinationVal != other.destinationVal) {
                return true
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return true
            }

            if (this.messageCountVal != other.messageCountVal) {
                return true
            }

            if (this.poisonCauseVal != other.poisonCauseVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        hashCode += prime * ackTypeVal.hashCode()
        if (let Some(consumerId) <- consumerIdVal) {
            hashCode += prime * consumerId.hashCode()
        }
        if (let Some(firstMessageId) <- firstMessageIdVal) {
            hashCode += prime * firstMessageId.hashCode()
        }
        if (let Some(lastMessageId) <- lastMessageIdVal) {
            hashCode += prime * lastMessageId.hashCode()
        }
        if (let Some(destination) <- destinationVal) {
            hashCode += prime * destination.hashCode()
        }
        if (let Some(transactionId) <- transactionIdVal) {
            hashCode += prime * transactionId.hashCode()
        }
        hashCode += prime * messageCountVal.hashCode()
        if (let Some(poisonCause) <- poisonCauseVal) {
            hashCode += prime * poisonCause.hashCode()
        }
        return hashCode
    }

    public func toString(): String {
        return "MessageAck: {consumerId: ${consumerIdVal}, ackType: ${ackTypeVal}, firstMessageId: ${firstMessageIdVal}, lastMessageId: ${lastMessageIdVal}, destination: ${destinationVal}, transactionId: ${transactionIdVal}, messageCount: ${messageCountVal}, poisonCause: ${poisonCauseVal}}"
    }
}
