/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_orm.wrap

public class TransactionWrap <: Transaction {
    public TransactionWrap(
        private let transaction: Transaction,
        public var connection: Connection,
        public var suspend!: Bool = false
    ) {}

    public var wrapping = None<TransactionWrap>
    public prop isDummy: Bool {
        get() {
            transaction is DummyTransaction
        }
    }

    public func setIsoLevel(level: TransactionIsoLevel): TransactionWrap {
        transaction.isoLevel = level
        this
    }
    public mut prop isoLevel: TransactionIsoLevel {
        get() {
            transaction.isoLevel
        }
        set(value) {
            transaction.isoLevel = value
        }
    }
    public func setAccessMode(mode: TransactionAccessMode): TransactionWrap {
        transaction.accessMode = mode
        this
    }
    public mut prop accessMode: TransactionAccessMode {
        get() {
            transaction.accessMode
        }
        set(value) {
            transaction.accessMode = value
        }
    }
    public func setDeferrableMode(mode: TransactionDeferrableMode): TransactionWrap {
        transaction.deferrableMode = mode
        this
    }
    public mut prop deferrableMode: TransactionDeferrableMode {
        get() {
            transaction.deferrableMode
        }
        set(value) {
            transaction.deferrableMode = value
        }
    }
    public func begin(): Unit {
        transaction.begin()
    }
    public func commit(): Unit {
        transaction.commit()
    }
    public func rollback(): Unit {
        transaction.rollback()
    }
    public func save(savePointName: String): Unit {
        transaction.save(savePointName)
    }
    public func rollback(savePointName: String): Unit {
        transaction.rollback(savePointName)
    }
    public func release(savePointName: String): Unit {
        transaction.release(savePointName)
    }
}
