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
package f_data.path

import std.ast.{cangjieLex, TokenKind}

internal interface DataFilter {
    func check(data: Data): Bool

    operator func &(right: DataFilter): DataFilter {
        AndFilter(this, right)
    }
    operator func |(right: DataFilter): DataFilter {
        OrFilter(this, right)
    }
    operator func !(): DataFilter {
        NotFilter(this)
    }
    static func compilePath(path: String, solid: String) {
        if (Bool.parse(solid)) {
            DataPath.solid(path)
        } else {
            DataPath.cache(path)
        }
    }
    static func parse<T>(value: String): T {
        let t = TypeInfo.of<T>()
        let any: Any = if (t == TypeInfo.of<String>()) {
            value
        } else if (t == TypeInfo.of<Int64>()) {
            Int64.parse(value)
        } else if (t == TypeInfo.of<Float64>()) {
            Float64.parse(value)
        } else if (t == TypeInfo.of<Bool>()) {
            Bool.parse(value)
        } else {
            throw DataException('unsupported for comparing type ${t}')
        }
        (any as T).getOrThrow()
    }
    static func parseArrayList<T>(value: String): ArrayList<T> {
        let list = ArrayList<T>()
        for (t in cangjieLex(value, true)) {
            match (t.kind) {
                case COMMA => continue
                case STRING_LITERAL | SINGLE_QUOTED_STRING_LITERAL | INT64 | FLOAT64 | BOOL_LITERAL => list.add(parse<T>(t.value))
                case _ => throw DataException('illegal token for set filter ${value}')
            }
        }
        list
    }
    static func parseHashSet<T>(value: String): HashSet<T> where T <: Hashable & Equatable<T> {
        let set = HashSet<T>()
        for (t in cangjieLex(value, true)) {
            match (t.kind) {
                case COMMA => continue
                case STRING_LITERAL | SINGLE_QUOTED_STRING_LITERAL | INT64 | FLOAT64 | BOOL_LITERAL => set.add(parse<T>(t.value))
                case _ => throw DataException('illegal token for set filter ${value}')
            }
        }
        set
    }
}
