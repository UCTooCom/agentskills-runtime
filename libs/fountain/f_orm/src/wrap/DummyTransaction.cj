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

public enum DummyTransactionMode {
    | Common
    | Mandatory
    | Never
    | StartFailure
}

public class DummyTransaction <: Transaction {
    public DummyTransaction(private let mode: DummyTransactionMode, private let ex: ?Exception) {}
    private var level: TransactionIsoLevel = TransactionIsoLevel.Unspecified
    public mut prop isoLevel: TransactionIsoLevel {
        get() {
            level
        }
        set(value) {
            level = value
        }
    }
    private var access: TransactionAccessMode = TransactionAccessMode.Unspecified
    public mut prop accessMode: TransactionAccessMode {
        get() {
            access
        }
        set(value) {
            access = value
        }
    }
    private var deferrable: TransactionDeferrableMode = TransactionDeferrableMode.Unspecified
    public mut prop deferrableMode: TransactionDeferrableMode {
        get() {
            deferrable
        }
        set(value) {
            deferrable = value
        }
    }
    public func begin(): Unit {
        match ((mode, ex)) {
            case (Mandatory, Some(e)) => throw MandatoryTransactionException(e)
            case (Mandatory, _) => throw MandatoryTransactionException()
            case (Never, Some(e)) => throw NeverTransactionException(e)
            case (Never, _) => throw NeverTransactionException()
            case (StartFailure, Some(e)) => throw StartFailureTransactionException("transaction is not be created", e)
            case (StartFailure, _) => throw StartFailureTransactionException("transaction is not be created")
            case (_, Some(e)) => throw TransactionException(e)
            case _ => ()
        }
    }
    public func commit(): Unit {}
    public func rollback(): Unit {}
    public func save(savePointName: String): Unit {}
    public func rollback(savePointName: String): Unit {}
    public func release(savePointName: String): Unit {}
}
