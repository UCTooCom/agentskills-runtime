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

public class StatementTest <: Statement {
    public prop parameterColumnInfos: Array<ColumnInfo>{
        get(){
            []
        }
    }
    public func query(params: Array<SqlDbType>): QueryResult{
        QueryResultTest()
    }
    public func setOption(key: String, value: String): Unit{}
    public func update(params: Array<SqlDbType>): UpdateResult{
        UpdateResultTest()
    }
    public func set<T>(index: Int, value: T): Unit{}
    public func setNull(index: Int): Unit{}
    public func update(): UpdateResult{
        UpdateResultTest()
    }
    public func query(): QueryResult{
        QueryResultTest()
    }
    public func close(): Unit {}
    public func isClosed(): Bool {
        false
    }
}