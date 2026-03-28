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
package f_cache

import std.collection.{Map, EquatableCollection}
import std.sync.AtomicInt64
import f_base.{EmptyIterator, nextPowerOf2}

class ConcHashMapKeysIterator<V> <: Iterator<String> {
    ConcHashMapKeysIterator(private let itr: Iterator<(String, V)>) {}

    /**
     * 返回迭代过程中的下一个元素
     * 返回值 Option<E> - 迭代过程中的下一个元素
     */
    public func next(): Option<String> {
        if (let Some((k, v)) <- itr.next()) {
            return Some(k)
        }
        return None<String>
    }
}

class ConcHashMapKeys<V> <: EquatableCollection<String> {
    ConcHashMapKeys(private let map: ConcHashMap<V>) {}

    /**
     * 返回 Keys 的迭代器
     * 返回值 Iterator<K> - Keys 的迭代器
     */
    public func iterator(): Iterator<String> {
        ConcHashMapKeysIterator<V>(map.iterator())
    }

    /**
     * 返回 Keys 中所有的元素个数
     * 返回值 Int64 - 元素个数
     */
    public prop size: Int64 {
        get() {
            return map.size
        }
    }

    /**
     * 检查 Keys 是否为空
     * 返回值 Bool - 如果是，则返回 true; 否则，返回 false
     */
    public func isEmpty(): Bool {
        return map.isEmpty()
    }

    /**
     * 判断 Keys 是否包含指定元素
     * 参数 element - K
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(element: String): Bool {
        map.contains(element)
    }

    public func contains(all!: Collection<String>): Bool {
        for (e in all where contains(e)) {
            return true
        }
        false
    }
}

class ConcHashMapValuesIterator<V> <: Iterator<V> {
    ConcHashMapValuesIterator(private let itr: Iterator<(String, V)>) {}

    /**
     * 返回迭代过程中的下一个元素
     * 返回值 Option<E> - 迭代过程中的下一个元素
     */
    public func next(): Option<V> {
        if (let Some((k, v)) <- itr.next()) {
            return Some(v)
        }
        return None<V>
    }
}

class ConcHashMapValues<V> <: Collection<V> {
    ConcHashMapValues(private let map: ConcHashMap<V>) {}

    /**
     * 返回 Values 的迭代器
     * 返回值 Iterator<V> - Values 的迭代器
     */
    public func iterator(): Iterator<V> {
        ConcHashMapValuesIterator<V>(map.iterator())
    }

    /**
     * 返回 Values 的元素个数
     * 返回值 Int64 - 元素的个数
     */
    public prop size: Int64 {
        get() {
            map.size
        }
    }

    /**
     * 判断 Values 是否为空
     * 返回值 Bool - 如果为空，则返回 true, 否则，返回 false
     */
    public func isEmpty(): Bool {
        map.isEmpty()
    }

    /**
     * 清除所有 Values 中的元素
     */
    public func clear(): Unit {
        map.clear()
    }
}

class ConcHashMapIterator<V> <: Iterator<(String, V)> {
    private var cur = 0
    private var itr: Iterator<(String, V)> = EmptyIterator<(String, V)>.INSTANCE()
    ConcHashMapIterator(private let m: ConcHashMap<V>) {
        (cur, itr) = doNextSegment(cur)
    }

    /**
     * 返回迭代过程中的下一个元素
     * 返回值 Option<E> - 迭代过程中的下一个元素
     */
    public func next(): Option<(String, V)> {
        while (cur <= m.concurrency) {
            if (let Some(x) <- itr.next()) {
                return x
            } else {
                (cur, itr) = doNextSegment(cur)
            }
        }
        Option<(String, V)>.None
    }
    private func doNextSegment(cur: Int64): (Int64, Iterator<(String, V)>) {
        if (cur >= 0 && cur < m.segments.size) {
            (cur + 1, segmentIterator(cur))
        } else {
            (cur + 1, EmptyIterator<(String, V)>.INSTANCE())
        }
    }
    func segmentIterators(): Array<Iterator<(String, V)>> {
        Array<Iterator<(String, V)>>(m.concurrency) {
            i => segmentIterator(i)
        }
    }
    private func segmentIterator(idx: Int64): Iterator<(String, V)> {
        m.segments[idx].iterator()
    }
}

class ConcHashMap<V> <: Collection<(String, V)> {
    static const DEFAULT_CONCURRENCY = 16
    private let size_ = AtomicInt64(0)
    private let hashMask: Int64

    private ConcHashMap(let segments: Array<SyncLinkedHashMap<V>>, let concurrency: Int64) {
        this.hashMask = concurrency - 1
    }
    static func create(concurrencyLevel!: Int64 = DEFAULT_CONCURRENCY): ConcHashMap<V> {
        let concurrency = conc(concurrencyLevel)
        let segments = newSegments(concurrency)
        ConcHashMap<V>(segments, concurrency)
    }
    static func create(map: Map<String, V>, concurrencyLevel!: Int64 = DEFAULT_CONCURRENCY): ConcHashMap<V> {
        var concurrency: Int64 = if (concurrencyLevel <= 0) {
            match (map) {
                case m: ConcHashMap<V> => m.concurrency
                case _ => DEFAULT_CONCURRENCY
            }
        } else {
            conc(concurrencyLevel)
        }
        let segments = newSegments(concurrency)
        var result = ConcHashMap<V>(segments, concurrency)
        result.add(all: map)
        return result
    }
    private static func newSegments(concurrency: Int64) {
        Array<SyncLinkedHashMap<V>>(concurrency) {
            _ => SyncLinkedHashMap<V>()
        }
    }
    private static func conc(concurrencyLevel: Int64) {
        nextPowerOf2(concurrencyLevel, default: 128)
    }
    private func segment(key: String): SyncLinkedHashMap<V> {
        segments[key.hashCode() & (hashMask)]
    }
    private func incrSize() {
        size_.fetchAdd(1)
    }
    private func decrSize() {
        size_.fetchSub(1)
    }

    /**
     * 根据 key 得到 Map 中映射的值
     * 参数 key - 传递 key，获取 value
     * 返回值 Option<V> - key 对应的值是用 Option 封装的
     */
    func get(key: String): Option<V> {
        segment(key).get(key)
    }

    /**
     * 判断是否包含指定键的映射
     * 参数 key - 传递要判断的 key
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    func contains(key: String): Bool {
        segment(key).contains(key)
    }

    /**
     * 判断是否包含指定集合键的映射
     * 参数 keys - 传递待判断的 keys
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    func containsAll(keys: Collection<String>): Bool {
        var cont = true
        for (key in keys) {
            cont &&= segment(key).contains(key)
            if (!cont) {
                break
            }
        }
        return cont
    }

    /**
     * 将指定的值与此映射中指定的键关联
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 key - 要放置的键
     * 参数 value - 要分配的值
     * 返回值 Option<V> - 如果赋值之前 key 存在，旧的 value 用 Option 封装；
     * 否则，返回 Option<V>.None
     */
    func add(key: String, value: V): Option<V> {
        let opt = segment(key).add(key, value)
        incrSize()
        return opt
    }

    /**
     * 传递指定元素进行遍历，并按顺序赋值
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 element - 传递给遍历赋值的元素
     */
    func add(all!: Collection<(String, V)>): Unit {
        for ((key, val) in all) {
            segment(key).add(key, val)
            incrSize()
        }
    }
    func computeIfAbsent(key: String, callable: () -> V): V {
        segment(key).computeIfAbsent(key, callable)
    }

    /**
     * 从此映射中删除指定键的映射（如果存在）
     * 参数 key - 传入要删除的 key
     * 返回值 Option<V> - 被移除映射的 V 用 Option 封装
     */
    func remove(key: String): Option<V> {
        let opt = segment(key).remove(key)
        if (let Some(_) <- opt) {
            decrSize()
        }
        return opt
    }

    /**
     * 从此映射中删除指定集合的映射（如果存在）
     * 参数 keys - 传人要删除的集合
     */
    func removeAll(keys: Collection<String>): Unit {
        for (key in keys) {
            remove(key)
        }
    }
    /**
     * 
     */
    func removeIf(predicate: (String, V) -> Bool): Unit {
        for(segment in segments){
            segment.removeIf{k, v => 
                let r = predicate(k, v)
                decrSize()
                r
            }
        }
    }

    /**
     * 清除所有键值对
     */
    public func clear(): Unit {
        for (segm in segments) {
            segm.clear()
        }
    }

    /**
     * 返回 Map 中所有的元素个数
     * 返回值 Int64 - 元素个数
     */
    public prop size: Int64 {
        get() {
            size_.load()
        }
    }

    /**
     * 检查 Map 是否为空
     * 返回值 Bool - 如果是，则返回 true; 否则，返回 false
     */
    public func isEmpty(): Bool {
        size == 0
    }

    /**
     * 返回 Map 的迭代器
     * 返回值 Iterator<(K,V)> - Map 的迭代器
     */
    public func iterator(): Iterator<(String, V)> {
        return ConcHashMapIterator<V>(this)
    }
}
