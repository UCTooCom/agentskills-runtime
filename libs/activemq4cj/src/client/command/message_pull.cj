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

public class MessagePull <: BaseCommand {
    private var consumerIdVal: ?ConsumerId = None
    private var destinationVal: ?ActiveMQDestination = None
    private var timeoutVal: Int64 = 0
    private var messageIdVal: ?MessageId = None
    private var correlationIdVal: ?String = None

    public func getDataStructureType(): Byte {
        return CommandTypes.MESSAGE_PULL
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processMessagePull(this)
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

    public mut prop timeout: Int64 {
        get() {
            return this.timeoutVal
        }
        set(value) {
            this.timeoutVal = value
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

    public mut prop correlationId: ?String {
        get() {
            return this.correlationIdVal
        }
        set(value) {
            this.correlationIdVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is MessagePull)) {
            return false
        }
        if (let Some(other) <- (other as MessagePull)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return false
            }

            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (this.timeoutVal != other.timeoutVal) {
                return false
            }

            if (this.messageIdVal != other.messageIdVal) {
                return false
            }

            if (this.correlationIdVal != other.correlationIdVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is MessagePull)) {
            return true
        }
        if (let Some(other) <- (other as MessagePull)) {
            if (this.consumerIdVal != other.consumerIdVal) {
                return true
            }

            if (this.destinationVal != other.destinationVal) {
                return true
            }

            if (this.timeoutVal != other.timeoutVal) {
                return true
            }

            if (this.messageIdVal != other.messageIdVal) {
                return true
            }

            if (this.correlationIdVal != other.correlationIdVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
