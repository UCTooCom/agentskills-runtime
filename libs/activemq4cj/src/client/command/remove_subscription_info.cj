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

public class RemoveSubscriptionInfo <: BaseCommand {
    private var connectionIdVal: ?ConnectionId = None
    private var clientIdVal: ?String = None
    private var subscriptionNameVal: ?String = None

    public func getDataStructureType(): Byte {
        return CommandTypes.REMOVE_SUBSCRIPTION_INFO
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processRemoveSubscription(this)
    }

    public mut prop connectionId: ?ConnectionId {
        get() {
            return connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop clientId: ?String {
        get() {
            return clientIdVal
        }
        set(value) {
            this.clientIdVal = value
        }
    }

    public mut prop subscriptionName: ?String {
        get() {
            return subscriptionNameVal
        }
        set(value) {
            this.subscriptionNameVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is RemoveSubscriptionInfo)) {
            return false
        }
        if (let Some(other) <- (other as RemoveSubscriptionInfo)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return false
            }

            if (this.clientIdVal != other.clientIdVal) {
                return false
            }

            if (this.subscriptionNameVal != other.subscriptionNameVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is RemoveSubscriptionInfo)) {
            return true
        }
        if (let Some(other) <- (other as RemoveSubscriptionInfo)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return true
            }

            if (this.clientIdVal != other.clientIdVal) {
                return true
            }

            if (this.subscriptionNameVal != other.subscriptionNameVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        return "RemoveSubscriptionInfo: {${super.toString()}, connectionId: ${connectionIdVal}, clientId: ${clientIdVal}, subscriptionName: ${subscriptionNameVal}}"
    }
}
