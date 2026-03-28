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

public class QueryResultTest <: QueryResult {
    public func isClosed(): Bool {
        false
    }
    public func close(): Unit {
    }
    public prop columnInfos: Array<ColumnInfo> {
        get() {
            [
                ColumnInfoTest("id", "SqlBigInt"),
                ColumnInfoTest("username", "SqlVarchar"),
                ColumnInfoTest("logged", "SqlBool"),
                ColumnInfoTest("register_time", "SqlTimestamp")
            ]
        }
    }
    private var i = 0
    private var s = String.empty
    private var b = false
    public func next(values: Array<SqlDbType>): Bool {
        if (i > 2) {
            return false
        }
        var j = 0
        while (j < values.size) {
            let value = values[j]
            match (j) {
                case 0 =>
                    let sqlval = (value as SqlBigInt).getOrThrow()
                    i++
                    sqlval.value = i
                case 1 =>
                    s += "s"
                    let sqlval = (value as SqlVarchar).getOrThrow()
                    sqlval.value = s
                case 2 =>
                    b = !b
                    let sqlval = (value as SqlBool).getOrThrow()
                    sqlval.value = b
                case 3 =>
                    let sqlval = (value as SqlTimestamp).getOrThrow()
                    sqlval.value = DateTime.now()
                case _ => throw Exception("too many columns")
            }
            j++
        }
        true
    }
    private var row = 0
    public func next(): Bool {
        row++
        row < 4
    }
    public func get<T>(index: Int): T {
        getOrNull<T>(index).getOrThrow()
    }
    public func getOrNull<T>(index: Int): ?T {
        match(None<T>){
            case _: Int64 => 
                i++
                i as T
            case _: String => 
                s+='s'
                s as T
            case _: Bool =>
                b = !b
                b as T
            case _: DateTime => 
                DateTime.now() as T
            case _ => throw Exception("get error")
        }
    }
}
