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

public class MockQueryResult <: QueryResult {
    private var rowIndex = -1
    private var rowData = MOCKDB.getQueryResultRows()
    public prop columnInfos: Array<ColumnInfo> {
        get() {
            let infos = MOCKDB.queryResultColumnInfos
            if(infos.isEmpty()){
                throw MockDbException('column infos from QueryResult must not be empty, to invoke MOCKDB.addQueryResultColumnInfo(name: "...", nullable: "...", typeName: "...") to add ColumnInfo for QueryResult.')
            }
            infos
        }
    }
    public func next(values: Array<SqlDbType>): Bool {
        throw MockDbException('not supported')
    }
    public func next(): Bool {
        rowIndex++
        rowIndex < rowData.size
    }
    public func get<T>(index: Int): T {
        getOrNull<T>(index).getOrThrow()
    }
    public func getOrNull<T>(index: Int): ?T {
        match(rowData[index]){
            case x: T => x
            case x: ?T => x
            case x => throw MockDbException('target: ${TypeInfo.of<T>()}')
        }
    }
    public func isClosed(): Bool {
        false
    }
    public func close(): Unit {}
}