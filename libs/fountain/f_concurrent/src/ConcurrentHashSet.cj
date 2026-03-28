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
package f_concurrent

public class ConcurrentHashSetIterator<T> <: Iterator<T> {
    public ConcurrentHashSetIterator(public let itr: Iterator<(T, Unit)>) {}
    public func next(): ?T {
        itr.next()?[0]
    }
}

public class ConcurrentHashSet<T> <: Set<T> where T <: Hashable & Equatable<T> {
    private let store: ConcurrentHashMap<T, Unit>
    public init() {
        store = ConcurrentHashMap<T, Unit>()
    }
    public init(capacity: Int64) {
        store = ConcurrentHashMap<T, Unit>(capacity)
    }
    public init(elements: Collection<T>) {
        this()
        for (v in elements) {
            store[v] = ()
        }
    }
    public init(elements: Array<T>) {
        this()
        for (v in elements) {
            store[v] = ()
        }
    }
    public prop size: Int64 {
        get() {
            store.size
        }
    }
    public func isEmpty(): Bool {
        return store.isEmpty()
    }
    public func iterator(): Iterator<T> {
        ConcurrentHashSetIterator<T>(store.iterator())
    }
    public func add(value: T): Bool {
        store.add(value, ()).isNone()
    }
    public func add(all!: Collection<T>): Unit {
        for (v in all) {
            add(v)
        }
    }
    public func contains(value: T): Bool {
        store.contains(value)
    }
    public func contains(all!: Collection<T>): Bool {
        for (v in all where !this.contains(v)) {
            return false
        }
        return true
    }
    public func retain(all!: Set<T>): Unit {
        for ((k, _) in store where !all.contains(k)) {
            store.remove(k)
        }
    }
    public func subsetOf(other: ReadOnlySet<T>): Bool {
        for (v in this where !other.contains(v)) {
            return false
        }
        return true
    }
    public func remove(value: T): Bool {
        store.remove(value).isSome()
    }
    public func remove(all!: Collection<T>): Unit {
        for (v in all) {
            store.remove(v)
        }
    }
    public func removeIf(predicate: (T) -> Bool): Unit {
        for ((k, _) in store where predicate(k)) {
            store.remove(k)
        }
    }
    public func clear(): Unit {
        removeIf {_ => true}
    }
    public func retainAll(values: Set<T>): Unit {
        for (v in this where !values.contains(v)) {
            remove(v)
        }
    }
    public func clone(): ConcurrentHashSet<T> {
        ConcurrentHashSet<T>(this)
    }
}

extend<T> ConcurrentHashSet<T> <: Equatable<ConcurrentHashSet<T>> where T <: Hashable & Equatable<T> {
    public operator func ==(other: ConcurrentHashSet<T>): Bool {
        if(refEq(this, other)){
            return true
        }else if (this.size != other.size) {
            return false
        }
        let itr1 = this.iterator()
        let itr2 = other.iterator()
        var i = 0
        while (let (Some(x), Some(y)) <- (itr1.next(), itr2.next()) && x == y) {
            i++
        }
        i == this.size
    }
}

extend<T> ConcurrentHashSet<T> <: ToString where T <: Hashable & Equatable<T> & ToString {
    public func toString(): String {
        let builder = StringGenerator()
        builder.append('[')
        var i = 0
        for (v in this) {
            if (i > 0) {
                builder.append(', ')
            }
            builder.append(v)
            i++
        }
        builder.append(']')
        builder.toString()
    }
}
extend<T> ConcurrentHashSet<T> <: SetOp<T> where T <: Hashable & Equatable<T> {
    public func intersection<C>(collection: C): Set<T> where C <: Collection<T>{
        IntersectionSetView<T, C>(this, ConcurrentHashSet<T>(collection))
    }
    public func union<C>(collection: C): Set<T> where C <: Collection<T>{
        UnionSetView<T, C>(this, ConcurrentHashSet<T>(collection))
    }
    public func difference<C>(collection: C): Set<T> where C <: Collection<T>{
        DifferenceSetView<T, C>(this, ConcurrentHashSet<T>(collection))
    }
}