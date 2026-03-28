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

import std.collection.Map

public class ConnectionWrap <: Connection {
    public ConnectionWrap(let driverName: String, private let connection: Connection) {}

    /**
     * 描 述 与 数 据 源 连 接 的 当 前 状 态
     */
    public prop state: ConnectionState {
        get() {
            connection.state
        }
    }

    /**
     * 返 回 连 接 到 的 数 据 源 元 数 据
     */
    public func getMetaData(): Map<String, String> {
        connection.getMetaData()
    }

    /**
     * 通 过 传 入 的 sql 语 句 ， 返 回 一 个 预 执 行 的 Statement 对 象 实 例
     * 参 数 sql - 预 执 行 的 sql 语 句 ，sql 语 句 的 参 数 只 支 持 ? 符 号 占 位 符
     * 返 回 值 Statement - 一 个 可 以 执 行 sql 语 句 的 实 例 对 象
     * 异 常 SqlException - 语 法 错 误 ， sql 语 句 包 含 不 认 识 的 字 符
     */
    public func prepareStatement(sql: String): Statement {
        StatementWrap(driverName, connection.prepareStatement(sql))
    }

    /**
     * 创 建 事 务 对 象
     * 异 常 SqlException - 已 经 处 于 事 务 状 态 ， 不 支 持 并 行 事 务 。
     */
    public func createTransaction(): Transaction {
        let transaction = connection.createTransaction()
        TransactionWrap(transaction, this)
    }
    public func isClosed(): Bool {
        connection.isClosed()
    }
    public func close(): Unit {
        connection.close()
    }
}
