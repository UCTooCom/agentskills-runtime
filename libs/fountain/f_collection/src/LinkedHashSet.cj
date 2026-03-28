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

import std.collection.{Set, ReadOnlySet}
import f_base.StringGenerator

public class LinkedHashSet<T> <: Set<T> where T <: Hashable & Equatable<T> {
    private let map: LinkedHashMap<T, Unit>
    public init() {
        map = LinkedHashMap<T, Unit>()
    }
    public init(elements: Collection<T>) {
        this()
        for (e in elements) {
            map.add(e, ())
        }
    }
    public init(elements: Array<T>) {
        this()
        for (e in elements) {
            map.add(e, ())
        }
    }
    public init(size: Int64, initElement: (Int64) -> T) {
        map = LinkedHashMap<T, Unit>(size) {i => (initElement(i), ())}
    }
    public func clear(): Unit {
        map.clear()
    }
    public func clone(): Set<T> {
        let c: Collection<T> = map.keys()
        LinkedHashSet<T>(c)
    }
    public func isEmpty(): Bool {
        map.isEmpty()
    }
    public func iterator(): Iterator<T> {
        map.keys().iterator()
    }
    public prop size: Int64 {
        get() {
            map.size
        }
    }
    public func contains(key: T): Bool {
        map.contains(key)
    }
    public func contains(all!: Collection<T>): Bool {
        map.contains(all: all)
    }
    public func subsetOf(other: ReadOnlySet<T>): Bool {
        for (v in map.keys() where !other.contains(v)) {
            return false
        }
        return true
    }
    public func retain(all!: Set<T>): Unit {
        map.removeIf {k, _ => !all.contains(k)}
    }
    public func add(element: T): Bool {
        map.add(element, ()).isNone()
    }
    public func add(all!: Collection<T>): Unit {
        for (e in all) {
            map.add(e, ())
        }
    }
    public func remove(element: T): Bool {
        map.remove(element).isSome()
    }
    public func remove(all!: Collection<T>): Unit {
        map.remove(all: all)
    }
    public func removeIf(predicate: (T) -> Bool): Unit {
        map.removeIf {k, _ => predicate(k)}
    }
    public func retainAll(elements: Set<T>): Unit {
        removeIf {v => !elements.contains(v)}
    }
    public prop first: ?T {
        get() {
            map.firstEntry()?[0]
        }
    }
    public prop last: ?T {
        get() {
            map.lastEntry()?[0]
        }
    }
    public func removeFirst(): ?T {
        map.pollFirstEntry()?[0]
    }
    public func removeLast(): ?T {
        map.pollLastEntry()?[0]
    }
}

extend<T> LinkedHashSet<T> <: Equatable<LinkedHashSet<T>> where T <: Comparable<T> {
    public operator func ==(other: LinkedHashSet<T>): Bool {
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

extend<T> LinkedHashSet<T> <: ToString where T <: Comparable<T> & ToString {
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
