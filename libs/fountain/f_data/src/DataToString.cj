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

public struct DataToString <: ToString {
    private let builder = StringGenerator()

    public func toString(): String {
        builder.append('}')
        builder.toString()
    }
    public func append<T>(): Unit {
        builder.append(TypeInfo.of<T>())
        builder.append('{')
    }
    public func append(name: String, value: Bool): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Float16): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Float32): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Float64): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Int8): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Int16): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Int32): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Int64): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: UInt8): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: UInt16): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: UInt32): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: UInt64): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: IntNative): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: UIntNative): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Rune): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: String): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Duration): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: DateTime): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: BigInt): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append(name: String, value: Decimal): Unit {
        builder.append('${name}: ${value}; ')
    }
    public func append<T>(name: String, value: ?T): Unit {
        match (value) {
            case Some(x) => match (x) {
                case v: ToString => builder.append('${name}: ${v}; ')
                case v: ToData => builder.append('${name}: ${v.toData()};')
                case v: Object => append(name, v)
                case _ => builder.append('${name}: _; ')
            }
            case _ => builder.append('${name}: None; ')
        }
    }
    public func append(name: String, value: Object): Unit {
        match (value) {
            case x: ToString => builder.append("${name}: ${x}; ")
            case x: ToData => builder.append("${name}: ${x.toData()}; ")
            case _ => builder.append('${name}: {_}; ')
        }
    }
    public func append<T, C>(name: String, value: C): Unit where C <: Collection<T> {
        builder.append('${name}: ')
        if (value.isEmpty()) {
            builder.append("[]; ")
            return
        } else if (let x: ToString <- value) {
            builder.append(x).append('; ')
            return
        }
        builder.append('[')
        var i = 0
        for (v in value) {
            if (i > 0) {
                builder.append(',')
            }
            if (let x: ToString <- v) {
                builder.append(x)
            } else {
                builder.append('_')
            }
            i++
        }
        builder.append(']; ')
    }
    public func append<T>(name: String, value: Array<T>): Unit {
        let c: Collection<T> = value
        append(name, c)
    }

    public func append<T>(name: String, value: ArrayList<T>): Unit {
        let c: Collection<T> = value
        append(name, c)
    }
    public func append<T>(name: String, value: LinkedList<T>): Unit {
        let c: Collection<T> = value
        append(name, c)
    }
    public func append<T>(name: String, value: HashSet<T>): Unit where T <: Hashable & Equatable<T> {
        let c: Collection<T> = value
        append(name, c)
    }
    public func append<T>(name: String, value: TreeSet<T>): Unit where T <: Comparable<T> {
        let c: Collection<T> = value
        append(name, c)
    }
    public func append<T>(name: String, value: LinkedHashSet<T>): Unit where T <: Hashable & Equatable<T> {
        let c: Collection<T> = value
        append(name, c)
    }
    public func append<T>(name: String, value: ConcurrentHashSet<T>): Unit where T <: Hashable & Equatable<T> {
        let c: Collection<T> = value
        append(name, c)
    }
    public func append<K, V, M>(name: String, value: M): Unit where K <: Equatable<K>, M <: Map<K, V> {
        builder.append('${name}: ')
        if (value.isEmpty()) {
            builder.append("{}; ")
            return
        } else if (let x: ToString <- value) {
            builder.append(x).append('; ')
            return
        }
        builder.append('{')
        var i = 0
        for ((k, v) in value) {
            if (i > 0) {
                builder.append(',')
            }
            match ((k, v)) {
                case (x: ToString, y: ToString) => builder.append("${x}: ${y}")
                case (_, y: ToString) => builder.append("_: ${y}")
                case (x: ToString, _) => builder.append("${x}: _")
                case _ => builder.append('_')
            }
            i++
        }
        builder.append('}')
    }
    public func append<K, V>(name: String, value: HashMap<K, V>): Unit where K <: Hashable & Equatable<K> {
        let m: Map<K, V> = value
        append(name, m)
    }
    public func append<K, V>(name: String, value: TreeMap<K, V>): Unit where K <: Comparable<K> {
        let m: Map<K, V> = value
        append(name, m)
    }
    public func append<K, V>(name: String, value: LinkedHashMap<K, V>): Unit where K <: Hashable & Equatable<K> {
        let m: Map<K, V> = value
        append(name, m)
    }

    public func append<K, V>(name: String, value: ConcurrentHashMap<K, V>): Unit where K <: Hashable & Equatable<K> {
        builder.append('${name}: ')
        if (value.isEmpty()) {
            builder.append("{}; ")
            return
        } else if (let x: ToString <- value) {
            builder.append(x).append('; ')
            return
        }
        builder.append('{')
        var i = 0
        for ((k, v) in value) {
            if (i > 0) {
                builder.append(',')
            }
            match ((k, v)) {
                case (x: ToString, y: ToString) => builder.append("${x}: ${y}")
                case (_, y: ToString) => builder.append("_: ${y}")
                case (x: ToString, _) => builder.append("${x}: _")
                case _ => builder.append('_')
            }
            i++
        }
        builder.append('}; ')
    }
}
