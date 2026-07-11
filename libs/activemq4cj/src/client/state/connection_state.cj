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
package activemq4cj.client.state

public class ConnectionState {
    private let infoVal: ConnectionInfo

    private let transctionsVal: ConcurrentHashMap<TransactionId, TransactionState> = ConcurrentHashMap<TransactionId, TransactionState>(
    )
    private let sessionsVal: ConcurrentHashMap<SessionId, SessionState> = ConcurrentHashMap<SessionId, SessionState>()
    private let tempDestinationsVal: LinkedList<DestinationInfo> = LinkedList<DestinationInfo>()

    private var connectionInterruptProcessingCompleteVal = true
    private var recoveringPullConsumersVal: ?ConcurrentHashMap<ConsumerId, ConsumerInfo> = None

    public init(info: ConnectionInfo) {
        this.infoVal = info
    }

    public func addTransaction(id: TransactionId) {
        transctionsVal.put(id, TransactionState(id))
    }

    public func removeTrasnction(id: TransactionId) {
        transctionsVal.remove(id)
    }

    public func getTransactionState(id: TransactionId): ?TransactionState {
        return transctionsVal.get(id)
    }

    public func addSession(info: SessionInfo) {
        if (let Some(sessionId) <- info.sessionId) {
            sessionsVal.put(sessionId, SessionState(info))
        }
    }

    public func removeSession(id: SessionId) {
        sessionsVal.remove(id)
    }

    public func getSessionState(id: SessionId): ?SessionState {
        return sessionsVal.get(id)
    }

    public prop sessions: ConcurrentHashMap<SessionId, SessionState> {
        get() {
            return this.sessionsVal
        }
    }

    public func addTempDestination(dest: DestinationInfo) {
        tempDestinationsVal.addLast(dest)
    }

    public func removeTempDestination(dest: ActiveMQDestination) {
        tempDestinationsVal.removeIf({e: DestinationInfo => e.destination == Some(dest)})
    }

    public prop info: ConnectionInfo {
        get() {
            return this.infoVal
        }
    }

    public prop tempDestinations: LinkedList<DestinationInfo> {
        get() {
            return this.tempDestinationsVal
        }
    }

    public mut prop connectionInterruptProcessingComplete: Bool {
        get() {
            return this.connectionInterruptProcessingCompleteVal
        }
        set(value) {
            this.connectionInterruptProcessingCompleteVal = value
        }
    }

    public mut prop recoveringPullConsumers: ConcurrentHashMap<ConsumerId, ConsumerInfo> {
        get() {
            if (let Some(recoveringPullConsumers) <- this.recoveringPullConsumersVal) {
                return recoveringPullConsumers
            }
            var rc = ConcurrentHashMap<ConsumerId, ConsumerInfo>()
            this.recoveringPullConsumersVal = rc
            return rc
        }
        set(value) {
            this.recoveringPullConsumersVal = value
        }
    }

    public prop transctions: ConcurrentHashMap<TransactionId, TransactionState> {
        get() {
            return this.transctionsVal
        }
    }
}
