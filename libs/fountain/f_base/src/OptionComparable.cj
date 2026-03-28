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
package f_base

public interface OptionComparable<T> where T <: Comparable<T> {
    operator func >(other: ?T): Bool {
        compare(other, noneOrder: Least) == GT
    }
    operator func <(other: ?T): Bool {
        compare(other, noneOrder: Least) == LT
    }
    operator func >=(other: ?T): Bool {
        match (compare(other, noneOrder: Least)) {
            case GT | EQ => true
            case _ => false
        }
    }
    operator func <=(other: ?T): Bool {
        match (compare(other, noneOrder: NoneOrder.Least)) {
            case LT | EQ => true
            case _ => false
        }
    }
    operator func >(other: T): Bool {
        compare(other, noneOrder: Least) == GT
    }
    operator func <(other: T): Bool {
        compare(other, noneOrder: Least) == LT
    }
    operator func >=(other: T): Bool {
        match (compare(other, noneOrder: Least)) {
            case GT | EQ => true
            case _ => false
        }
    }
    operator func <=(other: T): Bool {
        match (compare(other, noneOrder: NoneOrder.Least)) {
            case LT | EQ => true
            case _ => false
        }
    }

    func compare(other: ?T, noneOrder!: NoneOrder): Ordering
}

extend<T> Option<T> <: OptionComparable<T> where T <: Comparable<T> {
    public func compare(other: Option<T>, noneOrder!: NoneOrder = Least): Ordering {
        match ((this, other)) {
            case (Some(v1), Some(v2)) => v1.compare(v2)
            case (Some(_), _) =>
                if (noneOrder.isGreatest) {
                    LT
                } else {
                    GT
                }
            case (_, Some(_)) =>
                if (noneOrder.isLeast) {
                    LT
                } else {
                    GT
                }
            case _ => EQ
        }
    }
}
