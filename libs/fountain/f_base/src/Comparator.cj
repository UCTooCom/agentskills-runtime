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

public struct Comparator<T> {
    public Comparator(public let comparator: (T, T) -> Ordering) {}

    public static func compare<T>(left: T, right: T): Ordering where T <: Comparable<T> {
        left.compare(right)
    }
    public static func create<T>() where T <: Comparable<T> {
        Comparator<T>(compare<T>)
    }
    public operator func ()(left: T, right: T): Ordering {
        comparator(left, right)
    }
    public func reverse(): Comparator<T> {
        Comparator<T> {
            left, right => match (comparator(left, right)) {
                case LT => GT
                case GT => LT
                case EQ => EQ
            }
        }
    }
    public func then(comparator: (T, T) -> Ordering): Comparator<T> {
        Comparator<T> {
            left, right => match (this.comparator(left, right)) {
                case EQ => comparator(left, right)
                case x => x
            }
        }
    }
    public func then(comparator: Comparator<T>): Comparator<T> {
        Comparator<T> {
            left, right => match (this.comparator(left, right)) {
                case EQ => comparator(left, right)
                case x => x
            }
        }
    }
    public static func comparing<O, T>(mapper: (O) -> T): Comparator<O> where T <: Comparable<T> {
        Comparator<O> {
            left, right => mapper(left).compare(mapper(right))
        }
    }
    public static func comparing<O, T>(mapper: (O) -> T, comparator: (T, T) -> Ordering): Comparator<O> {
        Comparator<O> {
            left, right => comparator(mapper(left), mapper(right))
        }
    }
    public static func comparing<O>(mapper: (O) -> T, comparator: Comparator<T>): Comparator<O> {
        Comparator<O> {
            left, right => comparator(mapper(left), mapper(right))
        }
    }
    public func then<O>(mapper: (T) -> O, comparator: (O, O) -> Ordering): Comparator<T> {
        Comparator<T> {
            left, right => match (this.comparator(left, right)) {
                case EQ => comparator(mapper(left), mapper(right))
                case x => x
            }
        }
    }
    public func then<O>(mapper: (T) -> O, comparator: Comparator<O>): Comparator<T> {
        Comparator<T> {
            left, right => match (this.comparator(left, right)) {
                case EQ => comparator(mapper(left), mapper(right))
                case x => x
            }
        }
    }
}
