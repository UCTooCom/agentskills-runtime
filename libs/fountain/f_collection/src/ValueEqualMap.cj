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
package f_collection

public import std.collection.{HashMap, TreeMap}
public import std.collection.concurrent.ConcurrentHashMap

public interface Values<V> {
    func values(): Collection<V>
}

public interface ValueContainsMap<K, V> <: Values<V> where K <: Equatable<K> {
    func containsValue(predicate: (V) -> Bool): Bool {
        for (v in this.values() where predicate(v)) {
            return true
        }
        return false
    }
}

public interface ValueEqualMap<K, V> <: Values<V> where K <: Equatable<K>, V <: Equal<V> {
    func containsValue(value: V): Bool {
        for (v in this.values() where v == value) {
            return true
        }
        return false
    }
}

extend<K, V> HashMap<K, V> <: ValueContainsMap<K, V> where K <: Hashable & Equatable<K> {}

extend<K, V> HashMap<K, V> <: ValueEqualMap<K, V> where K <: Hashable & Equatable<K>, V <: Equal<V> {}

extend<K, V> TreeMap<K, V> <: ValueContainsMap<K, V> where K <: Comparable<K> {}

extend<K, V> TreeMap<K, V> <: ValueEqualMap<K, V> where K <: Comparable<K>, V <: Equal<V> {}

extend<K, V> LinkedHashMap<K, V> <: ValueContainsMap<K, V> where K <: Hashable & Equatable<K> {}

extend<K, V> LinkedHashMap<K, V> <: ValueEqualMap<K, V> where K <: Hashable & Equatable<K>, V <: Equal<V> {}

extend<K, V> ConcurrentHashMap<K, V> <: ValueContainsMap<K, V> where K <: Hashable & Equatable<K> {
    public func values(): Collection<V> {
        ConcurrentHashMapValues<K, V>(this)
    }
}

extend<K, V> ConcurrentHashMap<K, V> <: ValueEqualMap<K, V> where K <: Hashable & Equatable<K>, V <: Equal<V> {}

public class ConcurrentHashMapValues<K, V> <: Collection<V> where K <: Hashable & Equatable<K> {
    public ConcurrentHashMapValues(private let map: ConcurrentHashMap<K, V>) {}
    public func isEmpty(): Bool {
        map.isEmpty()
    }
    public prop size: Int64 {
        get() {
            map.size
        }
    }
    public func iterator(): Iterator<V> {
        ConcurrentHashMapValueIterator<K, V>(map.iterator())
    }
}

public class ConcurrentHashMapValueIterator<K, V> <: Iterator<V> where K <: Hashable & Equatable<K> {
    public ConcurrentHashMapValueIterator(private let itr: Iterator<(K, V)>) {}
    public func next(): ?V {
        itr.next()?[1]
    }
}
