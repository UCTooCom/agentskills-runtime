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

public class RemoveInfo <: BaseCommand {
    public static let LAST_DELIVERED_UNSET: Int32 = -1
    public static let LAST_DELIVERED_UNKNOWN: Int32 = -2

    private var objectIdVal: ?DataStructure = None
    private var lastDeliveredSequenceIdVal: Int64 = Int64(LAST_DELIVERED_UNKNOWN)

    public func getDataStructureType(): Byte {
        return CommandTypes.REMOVE_INFO
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        if (let Some(objectId) <- objectId) {
            match (objectId.getDataStructureType()) {
                case 120 =>
                    if (let Some(id) <- (objectId as ConnectionId)) {
                        return visitor.processRemoveConnection(id, lastDeliveredSequenceId)
                    }
                case 121 =>
                    if (let Some(id) <- (objectId as SessionId)) {
                        return visitor.processRemoveSession(id, lastDeliveredSequenceId)
                    }
                case 122 =>
                    if (let Some(id) <- (objectId as ConsumerId)) {
                        return visitor.processRemoveConsumer(id, lastDeliveredSequenceId)
                    }
                case 123 =>
                    if (let Some(id) <- (objectId as ProducerId)) {
                        return visitor.processRemoveProducer(id)
                    }
                case _ => return None
            }
        }
        return None
    }

    public mut prop objectId: ?DataStructure {
        get() {
            return this.objectIdVal
        }
        set(value) {
            this.objectIdVal = value
        }
    }

    public mut prop lastDeliveredSequenceId: Int64 {
        get() {
            return this.lastDeliveredSequenceIdVal
        }
        set(value) {
            this.lastDeliveredSequenceIdVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is RemoveInfo)) {
            return false
        }
        if (let Some(other) <- (other as RemoveInfo)) {
            if (this.objectIdVal != other.objectIdVal) {
                return false
            }

            if (this.lastDeliveredSequenceIdVal != other.lastDeliveredSequenceIdVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is RemoveInfo)) {
            return true
        }
        if (let Some(other) <- (other as RemoveInfo)) {
            if (this.objectIdVal != other.objectIdVal) {
                return false
            }

            if (this.lastDeliveredSequenceIdVal != other.lastDeliveredSequenceIdVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        return "RemoveInfo: {${super.toString()}, objectId: ${objectIdVal}, lastDeliveredSequenceId: ${lastDeliveredSequenceIdVal}}"
    }
}
