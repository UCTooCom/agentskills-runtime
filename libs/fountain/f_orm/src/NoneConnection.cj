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

import std.collection.*
import f_exception.IllegalAccessException

class NoneConnection <: Connection {
    public static const instance = NoneConnection()
    private const init() {}

    public prop state: ConnectionState {
        get() {
            Closed
        }
    }
    public func getMetaData(): Map<String, String> {
        throw IllegalAccessException()
    }
    public func prepareStatement(sql: String): Statement {
        throw IllegalAccessException()
    }
    public func createTransaction(): Transaction {
        throw IllegalAccessException()
    }
    public func isClosed(): Bool {
        true
    }
    public func close(): Unit {}
}
