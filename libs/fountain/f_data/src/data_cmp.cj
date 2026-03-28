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
package f_data

public func f_data_eq<T>(a: T, b: T): Bool where T <: Equatable<T> {
    a == b
}

public func f_data_eq<T1, T2>(a: T1, b: T2): Bool {
    match (a) {
        case x: Equatable<T2> => x == b
        case _ => match (b) {
            case x: Equatable<T1> => x == a
            case _ => true
        }
    }
}

public func f_data_cmp<T>(a: T, b: T): Ordering where T <: Comparable<T> {
    a.compare(b)
}

public func f_data_cmp<T1, T2>(a: T1, b: T2): Ordering {
    match (a) {
        case x: Comparable<T2> => x.compare(b)
        case _ => match (b) {
            case x: Comparable<T1> => match (x.compare(a)) {
                case GT => LT
                case LT => GT
                case _ => EQ
            }
            case _ => EQ
        }
    }
}
