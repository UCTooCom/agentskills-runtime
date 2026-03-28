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
package f_orm

public enum TransactionStatus <: Equatable<TransactionStatus> & ToString {
    | Unknown
    | Committed
    | Rollback

    public operator func ==(other: TransactionStatus): Bool {
        match ((this, other)) {
            case (Unknown, Unknown) | (Committed, Committed) | (Rollback, Rollback) => true
            case _ => false
        }
    }
    public prop isUnknown: Bool {
        get() {
            this == Unknown
        }
    }
    public prop isCommitted: Bool {
        get() {
            this == Committed
        }
    }
    public prop isRollback: Bool {
        get() {
            this == Rollback
        }
    }
    public func toString(): String {
        match (this) {
            case Unknown => 'Unknown'
            case Committed => 'Committed'
            case Rollback => 'Rollback'
        }
    }
}
