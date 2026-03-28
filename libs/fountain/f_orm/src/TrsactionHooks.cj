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

import std.collection.ArrayList
import std.sort.*

struct TransactionHookWrap <: TransactionHook & Comparable<TransactionHookWrap> {
    TransactionHookWrap(private let hook: TransactionHook, let count: Int64) {}

    public func beforeTx(): Unit {
        hook.beforeTx()
    }
    public func beforeCommit(readOnly: Bool): Unit {
        hook.beforeCommit(readOnly)
    }
    public func afterCommit(): Unit {
        hook.afterCommit()
    }
    public func afterThrowing(e: Exception): Unit {
        hook.afterThrowing(e)
    }
    public func beforeRollback(e: Exception): Unit {
        hook.beforeRollback(e)
    }
    public func afterRollback(e: Exception): Unit {
        hook.afterRollback(e)
    }
    public func afterComplete(status: TransactionStatus) {
        hook.afterComplete(status)
    }
    public func compare(other: TransactionHookWrap): Ordering {
        match (this.order.compare(other.order)) {
            case EQ => this.count.compare(other.count)
            case cmp => cmp
        }
    }
}

class TransactionHooks <: TransactionHook {
    private let list = ArrayList<TransactionHookWrap>()
    func register<T>(hook: TransactionHook): Unit where T <: TransactionHook {
        list.add(TransactionHookWrap(hook, list.size))
        sort(list)
    }
    public func beforeTx(): Unit {
        for (h in list) {
            h.beforeTx()
        }
    }
    public func beforeCommit(readOnly: Bool): Unit {
        for (h in list) {
            h.beforeCommit(readOnly)
        }
    }
    public func afterCommit(): Unit {
        for (h in list) {
            h.afterCommit()
        }
    }
    public func afterThrowing(e: Exception): Unit {
        for (h in list) {
            h.afterThrowing(e)
        }
    }
    public func beforeRollback(e: Exception): Unit {
        for (h in list) {
            h.beforeRollback(e)
        }
    }
    public func afterRollback(e: Exception): Unit {
        for (h in list) {
            h.afterRollback(e)
        }
    }
    public func afterComplete(status: TransactionStatus) {
        for (h in list) {
            h.afterComplete(status)
        }
    }
}
