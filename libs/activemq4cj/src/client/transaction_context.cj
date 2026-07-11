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
package activemq4cj.client

public class TransactionContext {
    private static let logger = LoggerFactory.getLogger("TransactionContext")

    private let connection: ActiveMQConnection
    private let localTransactionIdGenerator: Int64SequenceGenerator
    private var synchronizations: ?LinkedList<Synchronization> = None

    private var transactionIdVal: ?TransactionId = None
    private var rollbackOnlyVal: Bool = false
    private var beforeEndIndex: Int32 = 0

    public init(connection: ActiveMQConnection) {
        this.connection = connection
        this.localTransactionIdGenerator = connection.localTransactionIdGenerator
    }

    public func isInLocalTransaction(): Bool {
        if (let Some(transactionId) <- this.transactionId) {
            return transactionId.isLocalTransaction()
        }
        return false
    }

    public func isInTransaction(): Bool {
        return transactionId.isSome()
    }

    public func addSynchronization(s: Synchronization): Unit {
        if (let Some(synchronizations) <- synchronizations) {
            synchronizations.addLast(s)
        } else {
            synchronizations = LinkedList<Synchronization>()
            addSynchronization(s)
        }
    }

    private func afterRollback(): Unit {
        var firstException: ?Exception = None
        if (let Some(synchronizations) <- synchronizations) {
            for (synchronization in synchronizations) {
                try {
                    synchronization.afterRollback()
                } catch (e: Exception) {
                    if (logger.isDebugEnabled()) {
                        logger.log(LogLevel.DEBUG, "Exception from afterRollback")
                    }
                    if (firstException.isNone()) {
                        firstException = e
                    }
                }
            }
        }
        synchronizations = None
        if (let Some(firstException) <- firstException) {
            throw CJMSExceptionSupport.create(firstException)
        }
    }

    private func afterCommit(): Unit {
        var firstException: ?Exception = None
        if (let Some(synchronizations) <- synchronizations) {
            for (synchronization in synchronizations) {
                try {
                    synchronization.afterCommit()
                } catch (e: Exception) {
                    if (logger.isDebugEnabled()) {
                        logger.log(LogLevel.DEBUG, "Exception from afterCommit")
                    }
                    if (firstException.isNone()) {
                        firstException = e
                    }
                }
            }
        }
        synchronizations = None
        if (let Some(firstException) <- firstException) {
            throw CJMSExceptionSupport.create(firstException)
        }
    }

    private func beforeEnd(): Unit {
        if (let Some(synchronizations) <- synchronizations) {
            try {
                var index: Int32 = 0
                for (synchronization in synchronizations) {
                    if (index == beforeEndIndex) {
                        beforeEndIndex++
                        synchronization.beforeEnd()
                    }
                    index++
                }
            } catch (e: CJMSException) {
                throw e
            } catch (ex: Exception) {
                throw CJMSExceptionSupport.create(ex)
            }
        }
    }

    public func begin(): Unit {
        if (transactionId.isNone()) {
            synchronizations = None
            beforeEndIndex = 0
            rollbackOnly = false
            transactionIdVal = LocalTransactionId(getConnectionId(), localTransactionIdGenerator.getNextSequenceId())
            let transactionInfo = TransactionInfo(getConnectionId(), transactionId, TransactionInfo.BEGIN)
            connection.ensureConnectionInfoSent()
            connection.asyncSendPacket(transactionInfo)

            if (logger.isDebugEnabled()) {
                logger.log(LogLevel.DEBUG, "Begin: ${transactionId}")
            }
        }
    }

    public func rollback(): Unit {
        try {
            beforeEnd()
        } catch (ex: TransactionRolledBackException) {
            logger.warn("rollback processing error: ${ex}")
        }
        if (let Some(transactionId) <- transactionId) {
            if (logger.isDebugEnabled()) {
                logger.log(LogLevel.DEBUG, "Rollback: ${transactionId}")
            }

            let transactionInfo = TransactionInfo(getConnectionId(), transactionId, TransactionInfo.ROLLBACK)
            this.transactionIdVal = None
            var timeout = Duration.Zero
            if (connection.isClosing()) {
                timeout = Duration.millisecond * Int64(connection.closeTimeout)
            }
            this.connection.syncSendPacket(transactionInfo, timeout)
        }
        afterRollback()
    }

    public func commit(): Unit {
        try {
            beforeEnd()
        } catch (e: CJMSException) {
            rollback()
            throw e
        }

        if (let Some(transactionId) <- transactionId) {
            if (rollbackOnly) {
                let message = "Commit of ${transactionId} failed due to rollback only request; typically due to failover with pending acks"
                try {
                    rollback()
                } finally {
                    logger.warn(message)
                    throw TransactionRolledBackException(message)
                }
            }

            if (logger.isDebugEnabled()) {
                logger.log(LogLevel.DEBUG, "Commit: ${transactionId}")
            }

            let transactionInfo = TransactionInfo(getConnectionId(), transactionId, TransactionInfo.COMMIT_ONE_PHASE)
            this.transactionIdVal = None
            try {
                this.connection.syncSendPacket(transactionInfo)
                afterCommit()
            } catch (e: CJMSException) {
                logger.info("commit failed for transaction: ${transactionInfo.transactionId}")
                afterRollback()
                throw e
            }
        }
    }

    public prop transactionId: ?TransactionId {
        get() {
            return transactionIdVal
        }
    }

    public func getConnectionId(): ?ConnectionId {
        return connection.connectionInfo.connectionId
    }

    public mut prop rollbackOnly: Bool {
        get() {
            return this.rollbackOnlyVal
        }
        set(value) {
            this.rollbackOnlyVal = value
        }
    }
}
