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

import std.collection.{Set, ArrayList, MapEntryView, EquatableCollection}
import std.collection.concurrent.ConcurrentHashMap

public interface ExtendCollection<T, C> where T <: Equatable<T>, C <: Collection<T> {
    func retain(set: C): Unit
}

public interface ExtendList<T> <: ExtendCollection<T, Set<T>> where T <: Equatable<T> {
    func remove(set: Set<T>): Unit
}

extend<T> ArrayList<T> <: ExtendList<T> where T <: Equatable<T> {
    public func retain(set: Set<T>): Unit {
        batchRemove(set, true)
    }
    public func remove(set: Set<T>): Unit {
        batchRemove(set, false)
    }
    private func batchRemove(set: Set<T>, complement: Bool): Unit {
        let s = size
        var w = 0
        for (r in 0..s where set.contains(this[r]) == complement) {
            this[w] = this[r]
            w++
        }
        if (w == s) {
            return
        }
        for (i in s - 1..=w : -1) {
            remove(at: i)
        }
    }
}

public interface ExtendMap<K, V> <: ExtendCollection<K, Collection<K>> where K <: Equatable<K> {
    func remove(k: K): ?V
    func contains(k: K): Bool
    func retain(c: Collection<K>): Unit {
        for (k in c where !contains(k)) {
            remove(k)
        }
    }
    func entryView(key: K, fn: (K, ?V) -> ?V): ?V
    func computeIfAbsent(key: K, fn: () -> V): V {
        entryView(key){k, optv =>
            if(let Some(_) <- optv){
                optv
            }else{
                fn()
            }
        }.getOrThrow()
    }
    func computeIfPresent(key: K, fn: () -> V): ?V {
        entryView(key){k, optv => 
            if(let Some(_) <- optv){
                fn()
            }else{
                None<V>
            }
        }
    }
    func removeIf(key: K, predicate: (V) -> Bool): ?V
    func removeIf(predicate: (K, V) -> Bool): Unit
    func keys(): EquatableCollection<K>

    func contains(all!: Collection<K>): Bool
}

public interface ExtendNonConcurrentMap<K, V> <: ExtendMap<K, V> where K <: Equatable<K> {
    func entryView(key: K): MapEntryView<K, V>
    func entryView(key: K, fn: (K, ?V) -> ?V): ?V {
        let entry = this.entryView(key)
        let value = fn(entry.key, entry.value)
        entry.value = value
        value
    }
    func removeIf(key: K, predicate: (V) -> Bool): ?V {
        let view = entryView(key)
        if (let Some(v) <- view.value && predicate(v)) {
            view.value = None<V>
            v
        } else {
            None<V>
        }
    }
}

extend<K, V> HashMap<K, V> <: ExtendNonConcurrentMap<K, V> where K <: Hashable & Equatable<K> {}

extend<K, V> TreeMap<K, V> <: ExtendNonConcurrentMap<K, V> where K <: Comparable<K> {
    public func entryView(key: K, fn: (K, ?V) -> ?V): ?V {
        let entry = this.entryView(key)
        // let value = fn(entry.key, entry.value)//todo 我认为TreeMapEntryView有BUG，entry.value会出NoneValueException
        let value = fn(key, if(let Some(v) <- this.get(key)){
            v
        }else{
            None<V>
        })
        entry.value = value
        value
    }
}

extend<K, V> LinkedHashMap<K, V> <: ExtendNonConcurrentMap<K, V> where K <: Hashable & Equatable<K> {}

extend<K, V> ConcurrentHashMap<K, V> <: ExtendMap<K, V> where K <: Hashable & Equatable<K> {
    public func entryView(key: K, fn: (K, ?V) -> ?V): ?V {
        this.entryView(key) {
            entry => entry.value = fn(key, entry.value)//entry.key会导致栈溢出
        }
    }
    public func removeIf(key: K, predicate: (V) -> Bool): ?V {
        entryView(key) {
            view => if (let Some(v) <- view.value && predicate(v)) {
                view.value = None<V>
                v
            } else {
                None<V>
            }
        }
    }
    public func removeIf(predicate: (K, V) -> Bool): Unit {
        for ((k, v) in this where predicate(k, v)) {
            remove(k)
        }
    }
    public func keys(): EquatableCollection<K> {
        ConcurrentHashMapKeys<K, V>(this)
    }

    public func contains(all!: Collection<K>): Bool {
        for(k in all where !contains(k)){
            return false
        }
        true
    }
}
class ConcurrentHashMapKeys<K, V> <: EquatableCollection<K> where K <: Hashable & Equatable<K> {
    @Frozen
    ConcurrentHashMapKeys(private let map: ConcurrentHashMap<K, V>) {}

    @Frozen
    public prop size: Int64 {
        get() {
            return map.size
        }
    }

    @Frozen
    public func isEmpty(): Bool {
        return map.isEmpty()
    }

    @Frozen
    public func contains(element: K): Bool {
        return map.contains(element)
    }

    @Frozen
    public func contains(all!: Collection<K>): Bool {
        return map.contains(all: all)
    }

    @Frozen
    public func iterator(): Iterator<K> {
        return map.iterator().map<K> {i: (K, V) => i[0]}
    }

    @Frozen
    public func toArray(): Array<K> {
        let itr = iterator()
        return Array<K>(size){_ => itr.next().getOrThrow()}
    }
}
