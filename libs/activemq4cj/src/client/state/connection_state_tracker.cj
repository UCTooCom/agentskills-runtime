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

public class ConnectionStateTracker <: CommandVisitorAdapter {
    private static let logger = LoggerFactory.getLogger("ConnectionStateTracker")

    private let connectionStates: ConcurrentHashMap<ConnectionId, ConnectionState> = ConcurrentHashMap<ConnectionId, ConnectionState>(
    )

    private let messageCache: MessageCache

    private var trackTransactionsVal: Bool = false
    private var trackMessagesVal: Bool = true
    private var restoreSessionsVal: Bool = true
    private var restoreConsumersVal: Bool = true
    private var restoreProducersVal: Bool = true
    private var restoreTransactionVal: Bool = true

    public init(maxCacheSize: Int64) {
        this.messageCache = MessageCache(maxCacheSize)
    }

    public func track(command: Command): ?Response {
        var result = command.visit(this)
        if (trackMessages) {
            if (let Some(message) <- (command as Message)) {
                messageCache.currentCacheSize += message.getSize()
            } else if (let Some(messagePull) <- (command as MessagePull)) {
                messageCache.currentCacheSize += MessageCache.MESSAGE_PULL_SIZE
            }
        }
        return result
    }

    public func restore(transport: Transport): Unit {
        for ((connectionId, connectionState) in connectionStates) {
            connectionState.info.failoverReconnect = true
            transport.oneway(connectionState.info)

            //恢复临时目的地
            for (tempDest in connectionState.tempDestinations) {
                transport.oneway(tempDest)
                logger.log(LogLevel.DEBUG, "tempDest: ${tempDest.toString()}")
            }

            //恢复session
            if (restoreSessions) {
                restoreConnectionSessions(transport, connectionState)
            }

            //恢复事务
            if (restoreTransaction) {
                restoreConnectionTransactions(transport, connectionState)
            }
        }

        //重放追踪的消息
        logger.log(LogLevel.DEBUG, "replay commands: ")
        for ((k, v) in messageCache) {
            if (let Some(baseCommand) <- (v as BaseCommand)) {
                logger.log(LogLevel.DEBUG, baseCommand.toString())
            }

            transport.oneway(v)
        }
    }

    private func restoreConnectionSessions(transport: Transport, connectionState: ConnectionState): Unit {
        for ((sessionId, sessionState) in connectionState.sessions) {
            transport.oneway(sessionState.info)
            logger.debug("restore session: ${sessionState.info.sessionId}")

            for ((producerId, producerInfo) in sessionState.producers) {
                transport.oneway(producerInfo)
                logger.debug("restore producer: ${producerInfo.producerId}")
            }

            for ((consumerId, consumerInfo) in sessionState.consumers) {
                restoreConsumer(transport, connectionState, consumerInfo)
            }
        }
    }

    private func restoreConsumer(transport: Transport, connectionState: ConnectionState, consumerInfo: ConsumerInfo): Unit {
        var infoToSend: ConsumerInfo = consumerInfo.copy()
        if (!connectionState.connectionInterruptProcessingComplete && infoToSend.prefetchSize > 0) {
            if (let Some(consumerId) <- infoToSend.consumerId) {
                connectionState.recoveringPullConsumers.put(consumerId, consumerInfo)
            }
            infoToSend.prefetchSize = 0
            logger.debug(
                    "restore consumer: ${infoToSend.consumerId} in pull mode pending recovery, overriding prefetch: ${consumerInfo.prefetchSize}"
            )
        }
        logger.debug("restore consumer: ${infoToSend.consumerId}")
        transport.oneway(infoToSend)
    }

    private func restoreConnectionTransactions(transport: Transport, connectionState: ConnectionState): Unit {
        var toRollback = LinkedList<TransactionInfo>()
        for ((k, transactionState) in connectionState.transctions) {
            if (let Some(lastCommand) <- transactionState.commands.last) {
                if (let Some(transactionInfo) <- (lastCommand as TransactionInfo)) {
                    if (transactionInfo.transactionType == TransactionInfo.COMMIT_ONE_PHASE) {
                        toRollback.addLast(transactionInfo)
                        continue
                    }
                }
            }

            if (logger.isDebugEnabled()) {
                logger.log(LogLevel.DEBUG, "restore transaction: ${transactionState.id}")
            }

            for ((k, producerInfo) in transactionState.producers) {
                transport.oneway(producerInfo)
            }

            for (command in transactionState.commands) {
                transport.oneway(command)
            }

            for ((k, producerInfo) in transactionState.producers) {
                transport.oneway(producerInfo.createRemoveInfo())
            }

            for (command in toRollback) {
                var response = ExceptionResponse()
                var throwable = Throwable()
                throwable.message = "Transaction completion in doubt due to failover. Forcing rollback of ${command.transactionId}"
                response.exception = throwable
                response.correlationId = command.commandId
                if (let Some(transportListener) <- transport.transportListener) {
                    transportListener.onCommand(response)
                }
            }
        }
    }

    public override func processAddConnection(info: ConnectionInfo): ?Response {
        if (let Some(connectionId) <- info.connectionId) {
            connectionStates.put(connectionId, ConnectionState(info))
        }
        return None
    }

    public override func processRemoveConnection(id: ConnectionId, lastDeliveredSequenceId: Int64): ?Response {
        connectionStates.remove(id)
        return None
    }

    public override func processAddSession(info: SessionInfo): ?Response {
        if (let Some(sessionId) <- info.sessionId) {
            if (let Some(connectionId) <- sessionId.connectionId) {
                if (let Some(connectionState) <- connectionStates.get(ConnectionId(connectionId))) {
                    connectionState.addSession(info)
                }
            }
        }
        return None
    }

    public override func processRemoveSession(id: SessionId, lastDeliveredSequenceId: Int64): ?Response {
        if (let Some(connectionId) <- id.connectionId) {
            if (let Some(connectionState) <- connectionStates.get(ConnectionId(connectionId))) {
                connectionState.removeSession(id)
            }
        }
        return None
    }

    public override func processAddDestination(info: DestinationInfo): ?Response {
        if (let Some(connectionId) <- info.connectionId) {
            if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                if (let Some(dest) <- info.destination) {
                    if (dest.isTemporary()) {
                        connectionState.addTempDestination(info)
                    }
                }
            }
        }
        return None
    }

    public override func processRemoveDestination(info: DestinationInfo): ?Response {
        if (let Some(connectionId) <- info.connectionId) {
            if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                if (let Some(dest) <- info.destination) {
                    if (dest.isTemporary()) {
                        connectionState.removeTempDestination(dest)
                    }
                }
            }
        }
        return None
    }

    public override func processAddProducer(info: ProducerInfo): ?Response {
        if (let Some(producerId) <- info.producerId) {
            var sessionId = SessionId(producerId.connectionId, producerId.sessionId)
            var connectionId = ConnectionId(producerId.connectionId)
            if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                if (let Some(sessionState) <- connectionState.getSessionState(sessionId)) {
                    sessionState.addProducer(info)
                    if (info.responseRequired) {
                        return Tracked(ExceptionResponseCheckAction(this, info))
                    }
                }
            }
        }
        return None
    }

    public override func processRemoveProducer(id: ProducerId): ?Response {
        var sessionId = SessionId(id.connectionId, id.sessionId)
        var connectionId = ConnectionId(id.connectionId)
        if (let Some(connectionState) <- connectionStates.get(connectionId)) {
            if (let Some(sessionState) <- connectionState.getSessionState(sessionId)) {
                sessionState.removeProducer(id)
            }
        }
        return None
    }

    public override func processAddConsumer(info: ConsumerInfo): ?Response {
        if (let Some(consumerId) <- info.consumerId) {
            var sessionId = SessionId(consumerId.connectionId, consumerId.sessionId)
            var connectionId = ConnectionId(consumerId.connectionId)
            if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                if (let Some(sessionState) <- connectionState.getSessionState(sessionId)) {
                    sessionState.addConsumer(info)
                    if (info.responseRequired) {
                        return Tracked(ExceptionResponseCheckAction(this, info))
                    }
                }
            }
        }
        return None
    }

    public override func processRemoveConsumer(id: ConsumerId, lastDeliveredSequenceId: Int64): ?Response {
        var sessionId = SessionId(id.connectionId, id.sessionId)
        var connectionId = ConnectionId(id.connectionId)
        if (let Some(connectionState) <- connectionStates.get(connectionId)) {
            if (let Some(sessionState) <- connectionState.getSessionState(sessionId)) {
                sessionState.removeConsumer(id)
            }
            connectionState.recoveringPullConsumers.remove(id)
        }
        return None
    }

    public override func processMessage(message: Message): ?Response {
        if (trackTransactions && message.transactionId.isSome()) {
            if (let Some(producerId) <- message.producerId) {
                var connectionId = ConnectionId(producerId.connectionId)
                if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                    if (let Some(transactionId) <- message.transactionId) {
                        if (let Some(transactionState) <- connectionState.getTransactionState(transactionId)) {
                            transactionState.addCommand(message)
                        }
                    }
                }
            }
        } else if (trackMessages) {
            if (let Some(messageId) <- message.messageId) {
                messageCache.add(messageId.toString(), message.copy())
            }
        }
        return None
    }

    public override func processMessagePull(messagePull: MessagePull): ?Response {
        var id = "${messagePull.destination}::${messagePull.consumerId}"
        messageCache.add(id, messagePull)
        return None
    }

    public override func processBeginTransaction(info: TransactionInfo): ?Response {
        if (trackTransactions) {
            if (let Some(connectionId) <- info.connectionId) {
                if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                    if (let Some(transactionId) <- info.transactionId) {
                        connectionState.addTransaction(transactionId)
                        if (let Some(transactionState) <- connectionState.getTransactionState(transactionId)) {
                            transactionState.addCommand(info)
                        }
                    }
                }
            }
        }
        return None
    }

    public override func processCommitTransaction(info: TransactionInfo): ?Response {
        if (trackTransactions) {
            if (let Some(connectionId) <- info.connectionId) {
                if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                    if (let Some(transactionId) <- info.transactionId) {
                        connectionState.addTransaction(transactionId)
                        if (let Some(transactionState) <- connectionState.getTransactionState(transactionId)) {
                            transactionState.addCommand(info)
                            return Tracked(RemoveTransactionAction(connectionState, info))
                        }
                    }
                }
            }
        }
        return None
    }

    public override func processRollbackTransaction(info: TransactionInfo): ?Response {
        if (trackTransactions) {
            if (let Some(connectionId) <- info.connectionId) {
                if (let Some(connectionState) <- connectionStates.get(connectionId)) {
                    if (let Some(transactionId) <- info.transactionId) {
                        connectionState.addTransaction(transactionId)
                        if (let Some(transactionState) <- connectionState.getTransactionState(transactionId)) {
                            transactionState.addCommand(info)
                            return Tracked(RemoveTransactionAction(connectionState, info))
                        }
                    }
                }
            }
        }
        return None
    }

    public func connectionInterruptProcessingComplete(transport: Transport, connectionId: ConnectionId): Unit {
        if (let Some(connectionState) <- connectionStates.get(connectionId)) {
            connectionState.connectionInterruptProcessingComplete = true
            for ((consumerId, consumerInfo) in connectionState.recoveringPullConsumers) {
                var control = ConsumerControl()
                control.consumerId = consumerId
                control.prefetch = consumerInfo.prefetchSize
                control.destination = consumerInfo.destination
                transport.oneway(control)
            }
            connectionState.recoveringPullConsumers = ConcurrentHashMap<ConsumerId, ConsumerInfo>()
        }
    }

    public func transportInterrupted(connectionId: ConnectionId) {
        if (let Some(connectionState) <- connectionStates.get(connectionId)) {
            connectionState.connectionInterruptProcessingComplete = false
        }
    }

    public mut prop trackTransactions: Bool {
        get() {
            return this.trackTransactionsVal
        }
        set(value) {
            this.trackTransactionsVal = value
        }
    }

    public mut prop restoreSessions: Bool {
        get() {
            return this.restoreSessionsVal
        }
        set(value) {
            this.restoreSessionsVal = value
        }
    }

    public mut prop restoreConsumers: Bool {
        get() {
            return this.restoreConsumersVal
        }
        set(value) {
            this.restoreConsumersVal = value
        }
    }

    public mut prop restoreProducers: Bool {
        get() {
            return this.restoreProducersVal
        }
        set(value) {
            this.restoreProducersVal = value
        }
    }

    public mut prop restoreTransaction: Bool {
        get() {
            return this.restoreTransactionVal
        }
        set(value) {
            this.restoreTransactionVal = value
        }
    }

    public mut prop trackMessages: Bool {
        get() {
            return this.trackMessagesVal
        }
        set(value) {
            this.trackMessagesVal = value
        }
    }

    public mut prop maxCacheSize: Int64 {
        get() {
            return this.messageCache.maxCacheSize
        }
        set(value) {
            this.messageCache.maxCacheSize = value
        }
    }
}

class RemoveTransactionAction <: ResponseCallback {
    private var connectionState: ConnectionState
    private var info: TransactionInfo

    public init(connectionState: ConnectionState, info: TransactionInfo) {
        this.connectionState = connectionState
        this.info = info
    }

    public override func onResponse(command: Command): Unit {
        if (let Some(transactionId) <- info.transactionId) {
            connectionState.removeTrasnction(transactionId)
        }
    }
}

class ExceptionResponseCheckAction <: ResponseCallback {
    private var visitor: CommandVisitor
    private var tracked: Command

    public init(visitor: CommandVisitor, tracked: Command) {
        this.visitor = visitor
        this.tracked = tracked
    }

    public override func onResponse(command: Command): Unit {
        if (command is ExceptionResponse) {
            if (let Some(consumerInfo) <- (tracked as ConsumerInfo)) {
                if (let Some(consumerId) <- consumerInfo.consumerId) {
                    visitor.processRemoveConsumer(consumerId, 0)
                }
            } else if (let Some(producerInfo) <- (tracked as ProducerInfo)) {
                if (let Some(producerId) <- producerInfo.producerId) {
                    visitor.processRemoveProducer(producerId)
                }
            }
        }
    }
}
