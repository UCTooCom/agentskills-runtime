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

public class MessageDispatchNotification <: BaseCommand {
    private var consumerIdVal: ?ConsumerId = None
    private var destinationVal: ?ActiveMQDestination = None
    private var messageIdVal: ?MessageId = None
    private var deliverySequenceIdVal: Int64 = 0

    public func getDataStructureType(): Byte {
        return CommandTypes.MESSAGE_DISPATCH_NOTIFICATION
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processMessageDispatchNotification(this)
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

    public mut prop messageId: ?MessageId {
        get() {
            return this.messageIdVal
        }
        set(value) {
            this.messageIdVal = value
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

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is MessageDispatchNotification)) {
            return false
        }

        if (let Some(other) <- (other as MessageDispatchNotification)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return false
            }

            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (this.messageIdVal != other.messageIdVal) {
                return false
            }

            if (this.deliverySequenceIdVal != other.deliverySequenceIdVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is MessageDispatchNotification)) {
            return true
        }

        if (let Some(other) <- (other as MessageDispatchNotification)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return true
            }

            if (this.destinationVal != other.destinationVal) {
                return true
            }

            if (this.messageIdVal != other.messageIdVal) {
                return true
            }

            if (this.deliverySequenceIdVal != other.deliverySequenceIdVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
