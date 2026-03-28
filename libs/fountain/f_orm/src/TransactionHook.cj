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

public interface TransactionHook {
    func beforeTx(): Unit {}
    func beforeCommit(readOnly: Bool): Unit {}
    func afterCommit(): Unit {}
    func afterThrowing(e: Exception): Unit {}
    func beforeRollback(e: Exception): Unit {}
    func afterRollback(e: Exception): Unit {}
    func afterComplete(status: TransactionStatus): Unit {}
    /**
     * 用于决定钩子的执行顺序
     */
    prop order: Int64 {
        get() {
            Int64.Max
        }
    }
}
