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

public interface TransactionId <: DataStructure & Equatable<TransactionId> {
    func isXATransaction(): Bool
    func isLocalTransaction(): Bool
}

public class LocalTransactionId <: TransactionId {
    private var connectionIdVal: ?ConnectionId = None
    private var valueVal: Int64 = 0

    public init() {
    }

    public init(connectionId: ?ConnectionId, transactionId: Int64) {
        this.connectionIdVal = connectionId
        this.value = transactionId
    }

    public override func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_LOCAL_TRANSACTION_ID
    }

    public override func isXATransaction(): Bool {
        return false
    }
    public override func isLocalTransaction(): Bool {
        return true
    }

    public mut prop connectionId: ?ConnectionId {
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

    public func checkEquals(other: LocalTransactionId): Bool {
        if (this.connectionIdVal != other.connectionIdVal) {
            return false
        }

        if (this.valueVal != other.valueVal) {
            return false
        }
        return true
    }

    public operator override func ==(other: TransactionId): Bool {
        if (!(other is LocalTransactionId)) {
            return false
        }
        if (let Some(other) <- (other as LocalTransactionId)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: TransactionId): Bool {
        if (!(other is LocalTransactionId)) {
            return true
        }
        if (let Some(other) <- (other as LocalTransactionId)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is LocalTransactionId)) {
            return true
        }
        if (let Some(other) <- (other as LocalTransactionId)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is LocalTransactionId)) {
            return false
        }
        if (let Some(other) <- (other as LocalTransactionId)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
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
        return "LocalTransactionId: {connectionId: ${connectionIdVal}, value: ${valueVal}}"
    }
}

public class XATransactionId <: TransactionId {
    private var formatIdVal: Int32 = 0
    private var branchQualifierVal: ?Array<Byte> = None
    private var globalTransactionIdVal: ?Array<Byte> = None

    public override func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_XA_TRANSACTION_ID
    }

    public override func isXATransaction(): Bool {
        return false
    }
    public override func isLocalTransaction(): Bool {
        return true
    }

    public mut prop formatId: Int32 {
        get() {
            return this.formatIdVal
        }
        set(value) {
            this.formatIdVal = value
        }
    }

    public mut prop branchQualifier: ?Array<Byte> {
        get() {
            return this.branchQualifierVal
        }
        set(value) {
            this.branchQualifierVal = value
        }
    }

    public mut prop globalTransactionId: ?Array<Byte> {
        get() {
            return this.globalTransactionIdVal
        }
        set(value) {
            this.globalTransactionIdVal = value
        }
    }

    public override func isMarshallAware(): Bool {
        return false
    }

    public func checkEquals(other: XATransactionId): Bool {
        if (this.formatIdVal != other.formatIdVal) {
            return false
        }

        if (this.branchQualifierVal != other.branchQualifierVal) {
            return false
        }

        if (this.globalTransactionIdVal != other.globalTransactionIdVal) {
            return false
        }
        return true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is XATransactionId)) {
            return false
        }
        if (let Some(other) <- (other as XATransactionId)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is XATransactionId)) {
            return true
        }
        if (let Some(other) <- (other as XATransactionId)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public operator override func ==(other: TransactionId): Bool {
        if (!(other is XATransactionId)) {
            return false
        }
        if (let Some(other) <- (other as XATransactionId)) {
            if (!checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: TransactionId): Bool {
        if (!(other is XATransactionId)) {
            return true
        }
        if (let Some(other) <- (other as XATransactionId)) {
            if (!checkEquals(other)) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = prime * formatIdVal.hashCode()
        if (let Some(branchQualifier) <- this.branchQualifierVal) {
            for (item in branchQualifier) {
                hashCode += prime * item.hashCode()
            }
        }
        if (let Some(globalTransactionId) <- this.globalTransactionIdVal) {
            for (item in globalTransactionId) {
                hashCode += prime * item.hashCode()
            }
        }
        return hashCode
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("XATransactionId: {formatId: ${formatIdVal}, branchQualifier: [")
        if (let Some(branchQualifier) <- this.branchQualifierVal) {
            for (item in branchQualifier) {
                sb.append("${item}, ")
            }
        }
        sb.append("], globalTransactionId: [")
        if (let Some(globalTransactionId) <- this.globalTransactionIdVal) {
            for (item in globalTransactionId) {
                sb.append("${item}, ")
            }
        }
        sb.append("]}")
        return sb.toString()
    }
}

public class TransactionInfo <: BaseCommand {
    public static let BEGIN: Byte = 0
    public static let PREPARE: Byte = 1
    public static let COMMIT_ONE_PHASE: Byte = 2
    public static let COMMIT_TWO_PHASE: Byte = 3
    public static let ROLLBACK: Byte = 4
    public static let RECOVER: Byte = 5
    public static let FORGET: Byte = 6
    public static let END: Byte = 7

    private var transactionTypeVal: Byte = BEGIN
    private var connectionIdVal: ?ConnectionId = None
    private var transactionIdVal: ?TransactionId = None

    public init() {
    }

    public init(connectionId: ?ConnectionId, transactionId: ?TransactionId, transactionType: Byte) {
        this.connectionIdVal = connectionId
        this.transactionIdVal = transactionId
        if (transactionType > 7) {
            throw IllegalArgumentException("Type must be a value between 0 and 7")
        }
        this.transactionTypeVal = transactionType
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.TRANSACTION_INFO
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return match (transactionType) {
            case 0 => visitor.processBeginTransaction(this)
            case 2 => visitor.processCommitTransaction(this)
            case 4 => visitor.processRollbackTransaction(this)
            case _ => None
        }
    }

    public mut prop transactionType: Byte {
        get() {
            return transactionTypeVal
        }
        set(value) {
            this.transactionTypeVal = value
        }
    }

    public mut prop connectionId: ?ConnectionId {
        get() {
            return connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop transactionId: ?TransactionId {
        get() {
            return transactionIdVal
        }
        set(value) {
            this.transactionIdVal = value
        }
    }

    public operator func ==(other: DataStructure): Bool {
        if (!(other is TransactionInfo)) {
            return false
        }
        if (let Some(other) <- (other as TransactionInfo)) {
            if (this.transactionTypeVal != other.transactionTypeVal) {
                return false
            }

            if (this.connectionIdVal != other.connectionIdVal) {
                return false
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator func !=(other: DataStructure): Bool {
        if (!(other is TransactionInfo)) {
            return true
        }
        if (let Some(other) <- (other as TransactionInfo)) {
            if (this.transactionTypeVal != other.transactionTypeVal) {
                return true
            }

            if (this.connectionIdVal != other.connectionIdVal) {
                return true
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return true
            }
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString() {
        return "TransactionInfo: {${super.toString()}, type: ${transactionTypeVal}, connectionId: ${connectionIdVal}, transactionId: ${transactionIdVal}}"
    }
}
