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

public class MessageDispatch <: BaseCommand & Equatable<MessageDispatch> {
    private var consumerIdVal: ?ConsumerId = None
    private var destinationVal: ?ActiveMQDestination = None
    private var messageVal: ?Message = None
    private var redeliveryCounterVal: Int32 = 0

    private var deliverySequenceIdVal: Int64 = 0
    private var rollbackCauseVal: ?Exception = None

    public func getDataStructureType(): Byte {
        return CommandTypes.MESSAGE_DISPATCH
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processMessageDispatch(this)
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

    public mut prop message: ?Message {
        get() {
            return this.messageVal
        }
        set(value) {
            this.messageVal = value
        }
    }

    public mut prop redeliveryCounter: Int32 {
        get() {
            return this.redeliveryCounterVal
        }
        set(value) {
            this.redeliveryCounterVal = value
        }
    }

    public mut prop deliverySequenceId: Int64 {
        get() {
            return this.deliverySequenceIdVal
        }
        set(value) {
            this.deliverySequenceIdVal = value
        }
    }

    public mut prop rollbackCause: ?Exception {
        get() {
            return this.rollbackCauseVal
        }
        set(value) {
            this.rollbackCauseVal = value
        }
    }

    public func checkEquals(other: MessageDispatch): Bool {
        if (this.consumerIdVal != other.consumerIdVal) {
            return false
        }

        if (this.destinationVal != other.destinationVal) {
            return false
        }

        if (let Some(message) <- this.messageVal) {
            if (let Some(otherMessage) <- other.messageVal) {
                if (message != otherMessage) {
                    return false
                }
            } else {
                return false
            }
        } else {
            if (other.messageVal.isSome()) {
                return false
            }
        }

        if (this.redeliveryCounterVal != other.redeliveryCounterVal) {
            return false
        }
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is MessageDispatch)) {
            return false
        }
        if (let Some(other) <- (other as MessageDispatch)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is MessageDispatch)) {
            return true
        }
        if (let Some(other) <- (other as MessageDispatch)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public operator override func ==(other: MessageDispatch): Bool {
        if (!checkEquals(other)) {
            return false
        }
        return true
    }

    public operator override func !=(other: MessageDispatch): Bool {
        if (!checkEquals(other)) {
            return true
        }
        return false
    }

    public func toString(): String {
        return "MessageDispatch: ${super.toString()}, consumerId: ${consumerId}, destination: ${destination}, message:${message}, redeliveryCounter: ${redeliveryCounterVal}"
    }
}
