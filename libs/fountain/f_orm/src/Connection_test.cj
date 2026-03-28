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

public class ConnectionTest <: Connection {
    public prop state: ConnectionState{
        get(){
            Connected
        }
    }
    public func createTransaction(): Transaction {
        TransactionTest()
    }
    public func getMetaData(): Map<String, String>{
        HashMap<String, String>()
    }
    public func prepareStatement(sql: String): Statement{
        StatementTest()
    }
    public func close(): Unit {}
    public func isClosed(): Bool {
        false
    }
}