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

import std.collection.Map
import std.collection.concurrent.ConcurrentHashMap

/* 此类一般只作为局部变量使用，不会发生逃逸
   仓颉已支持类实例的逃逸分析和栈上分配
   按照HashBuilder_test的简单性能测试。
 */
public class HashBuilder {
    private static const coefficient: Int64 = 131
    private static const initHash = 71
    private var hashed = initHash

    /**
     * 调用一次，本类的实例回到初始状态
     */
    public func build(): Int64 {
        let h = hashed
        hashed = initHash
        h
    }

    @OverflowWrapping
    public func append(arg: Int64): This {
        hashed = hashed * coefficient + arg
        this
    }
    public func append<T>(arg: T): This where T <: Hashable {
        append(arg.hashCode())
    }
    public func append(arg: Int8): This {
        append(arg.hashCode())
    }
    public func append(arg: UInt8): This {
        append(arg.hashCode())
    }
    public func append(arg: Int16): This {
        append(arg.hashCode())
    }
    public func append(arg: UInt16): This {
        append(arg.hashCode())
    }
    public func append(arg: Int32): This {
        append(arg.hashCode())
    }
    public func append(arg: UInt32): This {
        append(arg.hashCode())
    }
    public func append(arg: UInt64): This {
        append(arg.hashCode())
    }
    public func append(arg: Float64): This {
        append(arg.hashCode())
    }
    public func append(arg: Float32): This {
        append(arg.hashCode())
    }
    public func append(arg: Float16): This {
        append(arg.hashCode())
    }
    public func append(arg: Rune): This {
        append(arg.hashCode())
    }
    public func append(arg: Bool): This {
        append(arg.hashCode())
    }

    public func append<T, I>(args: I): This where T <: Hashable, I <: Iterable<T> {
        if (let x: Hashable <- args) {
            append(x.hashCode())
            return this
        }
        match (args) {
            case x: Hashable => append(x.hashCode())
            case _ => for (arg in args) {
                append(arg.hashCode())
            }
        }
        this
    }
    public func append<T>(args: Range<T>): This where T <: Hashable & Countable<T> & Comparable<T> & Equatable<T> {
        append(args.hashCode())
    }
    public func append(arg: String): This {
        append(arg.hashCode())
    }
    public func append(arg: StringGenerator): This {
        append(arg.toString())
    }
    public func append<K, V>(value: ConcurrentHashMap<K, V>): This where K <: Hashable & Equatable<K> {
        for ((k, v) in value) {
            match ((k, v)) {
                case (x: Hashable, y: Hashable) => append(x.hashCode()).append(y.hashCode())
                case (x: Hashable, y: ToString) => append(x.hashCode()).append(y.toString())
                case (x: Hashable, _) => append(x.hashCode()).append('_')
                case _ => append('_').append('_')
            }
        }
        this
    }
    public func append(value: Any): This {
        match (value) {
            case x: Hashable => append(x.hashCode())
            case x: ToString => append(x.toString())
            case _ => ()
        }
        this
    }

    private func append<K, V>(value: Map<K, V>): This where K <: Equatable<K> {
        if (let x: Hashable <- value) {
            append(x.hashCode())
            return this
        }
        for ((k, v) in value) {
            match ((k, v)) {
                case (x: Hashable, y: Hashable) => append(x.hashCode()).append(y.hashCode())
                case (x: Hashable, y: ToString) => append(x.hashCode()).append(y.toString())
                case (x: ToString, y: Hashable) => append(x.toString()).append(y.hashCode())
                case (x: ToString, y: ToString) => append(x.toString()).append(y.toString())
                case (x: Hashable, _) => append(x.hashCode()).append('_')
                case (x: ToString, _) => append(x.toString()).append('_')
                case (_, y: Hashable) => append('_').append(y.hashCode())
                case (_, y: ToString) => append('_').append(y.toString())
                case _ => append('_').append('_')
            }
        }
        this
    }
}
