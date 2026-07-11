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

public class JournalTopicAck <: DataStructure {
    private var destinationVal: ?ActiveMQDestination = None
    private var clientIdVal: ?String = None
    private var subscritionNameVal: ?String = None
    private var messageIdVal: ?MessageId = None
    private var messageSequenceIdVal: Int64 = 0
    private var transactionIdVal: ?TransactionId = None

    public func getDataStructureType(): Byte {
        return CommandTypes.JOURNAL_ACK
    }

    public mut prop destination: ?ActiveMQDestination {
        get() {
            return this.destinationVal
        }
        set(value) {
            this.destinationVal = value
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

    public mut prop subscritionName: ?String {
        get() {
            return this.subscritionNameVal
        }
        set(value) {
            this.subscritionNameVal = value
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

    public mut prop messageSequenceId: Int64 {
        get() {
            return this.messageSequenceIdVal
        }
        set(value) {
            this.messageSequenceIdVal = value
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

    public override func isMarshallAware(): Bool {
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is JournalTopicAck)) {
            return false
        }
        if (let Some(other) <- (other as JournalTopicAck)) {
            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (this.clientIdVal != other.clientIdVal) {
                return false
            }

            if (this.subscritionNameVal != other.subscritionNameVal) {
                return false
            }

            if (this.messageIdVal != other.messageIdVal) {
                return false
            }

            if (this.messageSequenceIdVal != other.messageSequenceIdVal) {
                return false
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is JournalTopicAck)) {
            return true
        }
        if (let Some(other) <- (other as JournalTopicAck)) {
            if (this.destinationVal != other.destinationVal) {
                return false
            }

            if (this.clientIdVal != other.clientIdVal) {
                return true
            }

            if (this.subscritionNameVal != other.subscritionNameVal) {
                return true
            }

            if (this.messageIdVal != other.messageIdVal) {
                return false
            }

            if (this.messageSequenceIdVal != other.messageSequenceIdVal) {
                return true
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return false
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(destination) <- destinationVal) {
            hashCode += prime * destination.hashCode()
        }
        if (let Some(clientId) <- clientIdVal) {
            hashCode += prime * clientId.hashCode()
        }
        if (let Some(subscritionName) <- subscritionNameVal) {
            hashCode += prime * subscritionName.hashCode()
        }
        if (let Some(messageId) <- messageIdVal) {
            hashCode += prime * messageId.hashCode()
        }
        hashCode += messageSequenceIdVal.hashCode()
        if (let Some(transactionId) <- transactionIdVal) {
            hashCode += prime * transactionId.hashCode()
        }
        return hashCode
    }

    public override func toString(): String {
        return "JournalTopicAck: {destination: ${destinationVal},clientId: ${clientIdVal},subscritionName: ${subscritionNameVal},messageId: ${messageIdVal}, messageSequenceId: ${messageSequenceIdVal}, transactionId: ${transactionIdVal}}"
    }
}
