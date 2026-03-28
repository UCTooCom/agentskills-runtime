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

public struct Equaler<T> {
    public Equaler(private let eq: (T, T) -> Bool) {}

    public static func equals<T>(left: T, right: T): Bool where T <: Equal<T> {
        left == right
    }
    public static func create<T>() where T <: Equal<T> {
        Equaler<T>(equals<T>)
    }
    public operator func ()(left: T, right: T): Bool {
        eq(left, right)
    }
    public func then(equal: (T, T) -> Bool): Equaler<T> {
        Equaler<T> {
            left, right => match (this.eq(left, right)) {
                case true => equal(left, right)
                case _ => false
            }
        }
    }
    public func then(equal: Equaler<T>): Equaler<T> {
        Equaler<T> {
            left, right => match (this.eq(left, right)) {
                case true => equal(left, right)
                case _ => false
            }
        }
    }
    public static func equalling<O, T>(mapper: (O) -> T): Equaler<O> where T <: Equal<T> {
        Equaler<O> {
            left, right => mapper(left) == mapper(right)
        }
    }
    public static func equalling<O, T>(mapper: (O) -> T, equal: (T, T) -> Bool): Equaler<O> {
        Equaler<O> {
            left, right => equal(mapper(left), mapper(right))
        }
    }
    public static func equalling<O, T>(mapper: (O) -> T, equal: Equaler<T>): Equaler<O> {
        Equaler<O> {
            left, right => equal(mapper(left), mapper(right))
        }
    }
    public func then<O>(mapper: (T) -> O, equal: (O, O) -> Bool): Equaler<T> {
        Equaler<T> {
            left, right => match (this.eq(left, right)) {
                case true => equal(mapper(left), mapper(right))
                case _ => false
            }
        }
    }
    public func then<O>(mapper: (T) -> O, equal: Equaler<O>): Equaler<T> {
        Equaler<T> {
            left, right => match (this.eq(left, right)) {
                case true => equal(mapper(left), mapper(right))
                case _ => false
            }
        }
    }
}
