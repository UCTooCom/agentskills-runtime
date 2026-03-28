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

internal class CmpFilter<T> <: DataFilter where T <: Comparable<T> {
    CmpFilter(private let left: DataPath, private let right: T, private let ordering: Ordering, private let eq: Bool) {}
    init(left: String, right: String, orderingStr: String, eqStr: String, solid: String) {
        this(compilePath(left, solid), parse<T>(right),
            match (orderingStr) {
                case 'LT' => LT
                case 'GT' => GT
                case 'EQ' => EQ
                case _ => throw DataException('illegal Ordering string')
            }, Bool.parse(eqStr))
    }

    public func check(data: Data): Bool {
        let d = match (left.get(data).next()) {
            case Some(x) => x
            case _ => return false
        }
        match (d) {
            case x: DataDateTime => match (x.data) {
                case x: T =>
                    let cmp = x.compare(right)
                    cmp == ordering || (eq && cmp == EQ)
                case _ => false
            }
            case x: DataDuration => match (x.data) {
                case x: T =>
                    let cmp = x.compare(right)
                    cmp == ordering || (eq && cmp == EQ)
                case _ => false
            }
            case x: DataReal => match (x.data) {
                case x: T =>
                    let cmp = x.compare(right)
                    cmp == ordering || (eq && cmp == EQ)
                case _ => false
            }
            case x: DataString => match (x.data) {
                case x: T =>
                    let cmp = x.compare(right)
                    cmp == ordering || (eq && cmp == EQ)
                case _ => false
            }
            case _ => false
        }
    }
}
