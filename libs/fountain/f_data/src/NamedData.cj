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

import std.collection.concurrent.ConcurrentMap

public interface NamedData {
    func get(name: String): ?Data
    operator func [](name: String): Data
}

extend<M, V> DataMap<M, String, V> <: NamedData where V <: DataFields<V>, M <: DataFields<M> & Map<String, V> {
    public func get(name: String): ?Data {
        this.data.get(name)?.toData()
    }
    public operator func [](name: String): Data {
        get(name).getOrThrow {DataException('key ${name} is not found in ${TypeInfo.of<M>()}')}
    }
}

extend<M, V> DataConcurrentMap<M, String, V> <: NamedData where V <: DataFields<V>,
    M <: DataFields<M> & ConcurrentMap<String, V> {
    public func get(name: String): ?Data {
        this.data.get(name)?.toData()
    }
    public operator func [](name: String): Data {
        get(name).getOrThrow {DataException('key ${name} is not found in ${TypeInfo.of<M>()}')}
    }
}
