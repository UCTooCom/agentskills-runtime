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

import std.collection.HashMap

public class AsyncIterator<T> <: Iterator<Future<?T>> {
    public AsyncIterator(private let itr: Iterator<T>) {}
    public func next(): ?Future<?T> {
        spawn {
            itr.next()
        }
    }
}

public class TypeFilterIterator<T, R> <: Iterator<R> {
    public TypeFilterIterator(private let itr: Iterator<T>, private let exactly: Bool) {}
    public func next(): ?R {
        for (v in itr where (exactly && TypeInfo.of(v) == TypeInfo.of<R>()) || v is R) {
            return v as R
        }
        None
    }
}

public interface ExtendIterator<T> {
    func async(): Iterator<Future<?T>>
    func min(cmp: (T, T) -> Ordering): ?T
    func max(cmp: (T, T) -> Ordering): ?T
    func filterType<R>(exactly!: Bool): Iterator<R>
    func flatten<R>(toThrow!: Bool): Iterator<R>
    func collect<C>(collection: C, collector: (T, C) -> Unit): C where C <: Collection<T>
    func toArray(): Array<T>{
        toArrayList().unsafeData()
    }
    func toArrayList(): ArrayList<T>{
        collect<ArrayList<T>>(ArrayList<T>()){v, l => l.add(v)}
    }
    func groupBy<K>(key: (T) -> K): HashMap<K, T> where K <: Hashable & Equatable<K> 
}

extend<T> Iterator<T> <: ExtendIterator<T> {
    public func async(): Iterator<Future<?T>> {
        AsyncIterator<T>(this)
    }
    public func min(cmp: (T, T) -> Ordering): ?T {
        var r = None<T>
        for (v in this where r.isNone() || cmp(v, r.getOrThrow()) == LT) {
            r = v
        }
        r
    }
    public func max(cmp: (T, T) -> Ordering): ?T {
        var r = None<T>
        for (v in this where r.isNone() || cmp(v, r.getOrThrow()) == GT) {
            r = v
        }
        r
    }
    public func filterType<R>(exactly!: Bool = false): Iterator<R> {
        TypeFilterIterator<T, R>(this, exactly)
    }
    public func flatten<R>(toThrow!: Bool = true): Iterator<R> {
        if (toThrow) {
            flatMap<R> {
                v => match (v) {
                    case x: Iterator<R> => x
                    case _ => throw IllegalArgumentException(
                        '${TypeInfo.of<T>()} does not match ${TypeInfo.of<Iterator<R>>()}')
                }
            }
        } else {
            flatMap<R> {
                v => match (v) {
                    case x: Iterator<R> => x
                    case _ => EmptyIterator<R>.INSTANCE()
                }
            }
        }
    }
    public func collect<C>(collection: C, collector: (T, C) -> Unit): C where C <: Collection<T> {
        for(v in this){
            collector(v, collection)
        }
        collection
    }
    public func groupBy<K>(key: (T) -> K): HashMap<K, T> where K <: Hashable & Equatable<K> {
        let m = HashMap<K, T>()
        for(t in this){
            m[key(t)] = t
        }
        m
    }
}
