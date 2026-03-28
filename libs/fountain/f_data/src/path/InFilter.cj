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

internal class InFilter<T> <: DataFilter where T <: Hashable & Equatable<T> {
    InFilter(private let left: DataPath, private let right: HashSet<T>) {}
    init(left: String, right: String, solid: String) {
        this(compilePath(left, solid), parseHashSet<T>(right))
    }
    public func check(data: Data): Bool {
        let d = match (left.get(data).next()) {
            case Some(x) => x
            case _ => return false
        }
        match (d) {
            case x: DataDateTime => match (x.data) {
                case x: T => right.contains(x)
                case _ => false
            }
            case x: DataDuration => match (x.data) {
                case x: T => right.contains(x)
                case _ => false
            }
            case x: DataReal => match (x.data) {
                case x: T => right.contains(x)
                case _ => false
            }
            case x: DataString => match (x.data) {
                case x: T => right.contains(x)
                case _ => false
            }
            case x: DataBool => match (x.data) {
                case x: T => right.contains(x)
                case _ => false
            }
            case _ => false
        }
    }
}
