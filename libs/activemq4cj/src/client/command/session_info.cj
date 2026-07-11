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

public class SessionInfo <: BaseCommand {
    private var sessionIdVal: ?SessionId = None

    public init(connectionId: ConnectionId, sessionId: Int64) {
        if (let Some(value) <- connectionId.value) {
            this.sessionIdVal = SessionId(value, sessionId)
        } else {
            throw ActiveMQException("ConnectionId canot be null")
        }
    }

    public init() {
        this.sessionIdVal = SessionId()
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.SESSION_INFO
    }

    public func createRemoveInfo(): RemoveInfo {
        let removeInfo = RemoveInfo()
        if (let Some(sessionId) <- this.sessionId) {
            removeInfo.objectId = sessionId
        }
        return removeInfo
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processAddSession(this)
    }

    public mut prop sessionId: ?SessionId {
        get() {
            return this.sessionIdVal
        }
        set(value) {
            this.sessionIdVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is SessionInfo)) {
            return false
        }
        if (let Some(other) <- (other as SessionInfo)) {
            if (this.sessionIdVal != other.sessionIdVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is SessionInfo)) {
            return true
        }
        if (let Some(other) <- (other as SessionInfo)) {
            if (this.sessionIdVal != other.sessionIdVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        return "SessionInfo: {sessionId : ${sessionIdVal}}"
    }
}

public class SessionId <: DataStructure & Equatable<SessionId> {
    private var connectionIdVal: ?String = None
    private var valueVal: Int64 = 0

    public init() {
    }

    public init(connectionId: ?String, sessionId: Int64) {
        this.connectionIdVal = connectionId
        this.valueVal = sessionId
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.SESSION_ID
    }

    public mut prop connectionId: ?String {
        get() {
            return this.connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop value: Int64 {
        get() {
            return this.valueVal
        }
        set(value) {
            this.valueVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public func checkEquals(other: SessionId): Bool {
        if (this.connectionIdVal != other.connectionIdVal) {
            return false
        }

        if (this.valueVal != other.valueVal) {
            return false
        }
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is SessionId)) {
            return false
        }
        if (let Some(other) <- (other as SessionId)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is SessionId)) {
            return true
        }
        if (let Some(other) <- (other as SessionId)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public operator override func ==(other: SessionId): Bool {
        if (!checkEquals(other)) {
            return false
        }
        return true
    }

    public operator override func !=(other: SessionId): Bool {
        if (!checkEquals(other)) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = prime * this.valueVal.hashCode()
        if (let Some(connectionId) <- this.connectionIdVal) {
            hashCode += prime * connectionId.hashCode()
        }
        return hashCode
    }

    public func toString(): String {
        return "SessionId: {connectionId: ${connectionIdVal}, value: ${valueVal}}"
    }
}
