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

public class JournalTransaction <: DataStructure {
    public static let XA_PREPARE: Byte = 1
    public static let XA_COMMIT: Byte = 2
    public static let XA_ROLLBACK: Byte = 3
    public static let LOCAL_COMMIT: Byte = 4
    public static let LOCAL_ROLLBACK: Byte = 5

    private var transactionTypeVal: Byte = 0
    private var wasPreparedVal: Bool = false
    private var transactionIdVal: ?TransactionId = None

    public init(transactionType: Byte, transactionId: ?TransactionId, wasPrepared: Bool) {
        this.transactionTypeVal = transactionType
        this.wasPreparedVal = wasPrepared
        this.transactionIdVal = transactionId
    }

    public init() {
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.JOURNAL_TRANSACTION
    }

    public mut prop transactionType: Byte {
        get() {
            return this.transactionTypeVal
        }
        set(value) {
            this.transactionTypeVal = value
        }
    }

    public mut prop wasPrepared: Bool {
        get() {
            return this.wasPreparedVal
        }
        set(value) {
            this.wasPreparedVal = value
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
        if (!(other is JournalTransaction)) {
            return false
        }
        if (let Some(other) <- (other as JournalTransaction)) {
            if (this.transactionTypeVal != other.transactionTypeVal) {
                return false
            }
            if (this.wasPreparedVal != other.wasPreparedVal) {
                return false
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is JournalTransaction)) {
            return true
        }
        if (let Some(other) <- (other as JournalTransaction)) {
            if (this.transactionTypeVal != other.transactionTypeVal) {
                return true
            }
            if (this.wasPreparedVal != other.wasPreparedVal) {
                return true
            }

            if (this.transactionIdVal != other.transactionIdVal) {
                return true
            }
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = prime * transactionTypeVal.hashCode()
        hashCode += prime * wasPreparedVal.hashCode()
        if (let Some(transactionId) <- this.transactionIdVal) {
            hashCode += prime * transactionId.hashCode()
        }
        return hashCode
    }

    public override func toString(): String {
        return "JournalTrace: {type: ${transactionType}, wasPrepared: ${wasPrepared}, transactionId: ${transactionId}}"
    }
}
