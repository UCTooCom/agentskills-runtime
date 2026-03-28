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
package f_mockdb

public class MockStatement <: Statement {
    private let args = ArrayList<Any>()
    MockStatement(private let sql: String){}
    public prop parameterColumnInfos: Array<ColumnInfo> {
        get() {
            []
        }
    }
    public func query(params: Array<SqlDbType>): QueryResult {
        throw MockDbException('not supported')
    }
    public func setOption(key: String, value: String): Unit {
        output.writeln('Statement option: (key: ${key}, value: ${value})')
    }
    public func update(params: Array<SqlDbType>): UpdateResult {
        throw MockDbException('not supported')
    }
    public func set<T>(index: Int, value: T): Unit {
        for(_ in args.size ..= index) {
            args.add(None<Any>)
        }
        args[index] = value
    }
    public func setNull(index: Int): Unit {
        for(_ in args.size ..= index) {
            args.add(None<Any>)
        }
    }
    public func update(): UpdateResult {
        if(MOCKDB.toThrowOnExecuting(sql, args)){
            throw MockDbException()
        }
        MockUpdateResult()
    }
    public func query(): QueryResult {
        if(MOCKDB.toThrowOnExecuting(sql, args)){
            throw MockDbException()
        }
        MockQueryResult()
    }
    public func isClosed(): Bool {
        false
    }
    public func close(): Unit {

    }
}