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

internal class SizeFilter <: DataFilter {
    SizeFilter(private let left: DataPath, private let right: Int64) {}
    init(left: String, right: String, solid: String) {
        this(compilePath(left, solid), Int64.parse(right))
    }
    public func check(data: Data): Bool {
        let d = match (left.get(data).next()) {
            case Some(x) => x
            case _ => return false
        }
        match (d) {
            case x: Collection<Data> => x.size
            case x: Collection<(String, Data)> => x.size
            case x: Collection<(Data, Data)> => x.size
            case x: DataString =>
                var s = 0
                for (_ in x.data.runes()) {
                    s++
                }
                s
            case _ =>
                var size = -1
                let info = ClassTypeInfo.of(left)
                if (info.qualifiedName.startsWith('f_data.DataObject') && let Some(fn) <- TypeMemberInfos
                    .instanceFunction(info, 'fields') && let fields: Iterator<ReadableField> <- fn.apply(left)) {
                    size = 0
                    for (_ in fields) {
                        size++
                    }
                }
                size
        } == right
    }
}
