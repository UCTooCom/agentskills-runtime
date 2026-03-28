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
package f_data.json

import std.collection.concurrent.ConcurrentMap

public interface ToJsonString {
    func toJsonString(): String
}

extend DataBool <: ToJsonString {
    public func toJsonString(): String {
        toString()
    }
}

extend DataDateTime <: ToJsonString {
    public func toJsonString(): String {
        '\"${toString()}\"'
    }
}

extend DataDuration <: ToJsonString {
    public func toJsonString(): String {
        '\"${toString()}\"'
    }
}

extend DataNone <: ToJsonString {
    public func toJsonString(): String {
        'null'
    }
}

extend DataString <: ToJsonString {
    public func toJsonString(): String {
        '"${toString()}"'
    }
}

extend DataReal <: ToJsonString {
    public func toJsonString(): String {
        toString()
    }
}

extend<T> DataObject<T> <: ToJsonString where T <: ObjectData<T> {
    public func toJsonString(): String {
        let builder = StringGenerator('{')
        for ((name, value) in this) {
            let valStr = match (value) {
                case x: ToJsonString => x.toJsonString()
                case _ => continue
            }
            if (builder.size > 1) {
                builder.append(',')
            }
            builder.append('"${name}"')
            builder.append(':')
            builder.append(valStr)
        }
        builder.append('}')
        builder.toString()
    }
}

extend<C, T> DataCollection<C, T> <: ToJsonString where T <: DataFields<T>, C <: DataFields<C> & Collection<T> {
    public func toJsonString(): String {
        let builder = StringGenerator('[')
        for (d in this) {
            let valStr = match (d) {
                case x: ToJsonString => x.toJsonString()
                case _ => continue
            }
            if (builder.size > 1) {
                builder.append(',')
            }
            builder.append(valStr)
        }
        builder.append(']')
        builder.toString()
    }
}

extend<M, K, V> DataMap<M, K, V> <: ToJsonString where K <: DataFields<K>, V <: DataFields<V>,
    M <: DataFields<M> & Map<K, V> {
    public func toJsonString(): String {
        let builder = StringGenerator('{')
        for ((k, v) in this) {
            let (ks, vs) = match ((k, v)) {
                case (x: ToJsonString, y: ToJsonString) => (x.toJsonString(), y.toJsonString())
                case _ => continue
            }
            if (builder.size > 1) {
                builder.append(',')
            }
            if (ks.startsWith('"') && ks.endsWith('"')) {
                builder.append(ks)
            } else {
                builder.append('"${ks}"')
            }
            builder.append(':')
            builder.append(vs)
        }
        builder.append('}')
        builder.toString()
    }
}

extend<M, K, V> DataConcurrentMap<M, K, V> <: ToJsonString where K <: DataFields<K>, V <: DataFields<V>,
    M <: DataFields<M> & ConcurrentMap<K, V> {
    public func toJsonString(): String {
        let builder = StringGenerator('{')
        for ((k, v) in this) {
            let (ks, vs) = match ((k, v)) {
                case (x: ToJsonString, y: ToJsonString) => (x.toJsonString(), y.toJsonString())
                case _ => continue
            }
            if (builder.size > 1) {
                builder.append(',')
            }
            if (ks.startsWith('"') && ks.endsWith('"')) {
                builder.append(ks)
            } else {
                builder.append('"${ks}"')
            }
            builder.append(':')
            builder.append(vs)
        }
        builder.append('}')
        builder.toString()
    }
}
