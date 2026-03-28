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

import std.collection.{TreeMap, MapEntryView}

public struct ComparableKey<K> <: Comparable<K> & Comparable<ComparableKey<K>> {
    ComparableKey(
        let key: K,
        private let cmp: (K, K) -> Ordering
    ){}
    public func compare(that: K): Ordering {
        cmp(this.key, that)
    }
    public func compare(that: ComparableKey<K>): Ordering {
        cmp(this.key, that.key)
    }
}
public class TreeDict<K, V> <: Dict<K, V> {
    let map: TreeMap<ComparableKey<K>, V>
    public TreeDict(private let cmp: (K, K) -> Ordering){
        map = TreeMap<ComparableKey<K>, V>()
    }
    public init(elements: Array<(K, V)>, cmp: (K, K) -> Ordering){
        this(cmp)
        add(all: elements)
    }
    public init(elements: Collection<(K, V)>, cmp: (K, K) -> Ordering){
        this(cmp)
        add(all: elements)
    }
    public init(size: Int64, initElement: (Int64) -> (K, V), cmp: (K, K) -> Ordering) {
        this(cmp)
        for(i in 0..size) {
            let (k, v) = initElement(i)
            add(k, v)
        }
    }
    
    func newKey(key: K){
        ComparableKey<K>(key, cmp)
    }
    /**
     * 根据 key 得到 Map 中映射的值
     * 参数 key - 传递 key，获取 value
     * 返回值 Option<V> - key 对应的值是用 Option 封装的
     */
    public func get(key: K): Option<V> {
        map.get(newKey(key))
    }

    /**
     * 判断是否包含指定键的映射
     * 参数 key - 传递要判断的 key
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(key: K): Bool {
        map.contains(newKey(key))
    }

    /**
     * 判断是否包含指定集合键的映射
     * 参数 keys - 传递待判断的 keys
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<K>): Bool {
        for(k in all where !contains(k)){
            return false
        }
        true
    }

    /**
     * 将指定的值与此映射中指定的键关联
           120
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 key - 要放置的键
     * 参数 value - 要分配的值
     * 返回值 Option<V> - 如果赋值之前 key 存在，旧的 value 用 Option 封装；
     * 否则，返回 Option<V>.None
     */
    public func add(key: K, value: V): Option<V> {
        map.add(newKey(key), value)
    }

    /**
     * 传递指定元素进行遍历，并按顺序赋值
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 element - 传递给遍历赋值的元素
     */
    public func add(all!: Collection<(K, V)>): Unit {
        for((k, v) in all){
            add(k, v)
        }
    }
    public func addIfAbsent(key: K, value: V): ?V {
        map.addIfAbsent(newKey(key), value)
    }
    public func replace(key: K, value: V): ?V {
        map.replace(newKey(key), value)
    }

    /**
     * 从此映射中删除指定键的映射（如果存在）
     * 参数 key - 传入要删除的 key
     * 返回值 Option<V> - 被移除映射的 V 用 Option 封装
     */
    public func remove(key: K): Option<V> {
        map.remove(newKey(key))
    }

    /**
     * 从此映射中删除指定集合的映射（如果存在）
     * 参数 all - 传人要删除的集合
     */
    public func remove(all!: Collection<K>): Unit {
        let keys = all.iterator()
        map.remove(all: Array<ComparableKey<K>>(all.size){_ => newKey(keys.next().getOrThrow())})
    }

    /**
     * 传入 lambda 表达式，如果满足条件，则删除对应的键值
     * 参数 predicate - 传递一个 lambda 表达式进行判断
     */
    public func removeIf(predicate: (K, V) -> Bool): Unit {
        map.removeIf{k, v => predicate(k.key, v)}
    }

    /**
     * 清除所有键值对
     */
    public func clear(): Unit {
        map.clear()
    }

    /**
     * 运算符重载集合，如果键存在，返回键对应的值，如果不存在，抛出异常。
     * 参数 key - 传递值进行判断
     * 返回值 V - 与键对应的值
     */
    public operator func [](key: K): V {
        get(key).getOrThrow()
    }

    /**
     * 运算符重载集合，如果键存在，新 value 覆盖旧 value，如果键不存在，
     * 添加此键值对
     * 参数 key - 传递值进行判断
     * 参数 value - 传递要设置的值
     */
    public operator func [](key: K, value!: V): Unit {
        add(key, value)
    }

    /**
     * 返回 Map 中所有的 key，并将所有 key 存储在一个 Keys 容器中
     * 返回值 Keys<K> - 保存所有返回的 key
     */
    public func keys(): Collection<K> {
        ComparableKeyCollection<K, V>(this)
    }

    /**
     * 返回 Map 中所有的 value，并将所有 value 存储在一个 Values 容器中
     * 返回值 Values<V> - 保存所有返回的 value
     */
    public func values(): Collection<V> {
        map.values()
    }

    /**
     * 返回 Map 中所有的元素个数
     * 返回值 Int64 - 元素个数
     */
    public prop size: Int64 {
        get() {
            map.size
        }
    }

    /**
     * 检查 Map 是否为空
     * 返回值 Bool - 如果是，则返回 true; 否则，返回 false
     */
    public func isEmpty(): Bool {
        map.isEmpty()
    }

    /**
     * 返回 Map 的迭代器
     * 返回值 Iterator<(K,V)> - Map 的迭代器
     */
    public func iterator(): Iterator<(K, V)> {
        ComparableKeyMapIterator<K, V>(map.iterator())
    }
    public func toArray(): Array<(K, V)> {
        let itr = map.iterator()
        Array<(K, V)>(map.size){_ => 
            let (hk, v) = itr.next().getOrThrow()
            (hk.key, v)
        }
    }
    public func entryView(k: K): MapEntryView<K, V> {
        ComparableKeyMapEntryView<K, V>(map.entryView(newKey(k)))
    }
    private func extract(tuple: ?(ComparableKey<K>, V)): ?(K, V) {
        if(let Some((tk, v)) <- tuple){
            (tk.key, v)
        }else{
            None<(K, V)>
        }
    }
    public prop first: ?(K, V) {
        get(){
            extract(map.first)
        }
    }
    public prop last: ?(K, V) {
        get(){
            extract(map.last)
        }
    }
    public func forward(mark: K, inclusive!: Bool = true): Iterator<(K, V)> {
        ComparableKeyMapIterator<K, V>(map.forward(newKey(mark), inclusive: inclusive))
    }
    public func removeFirst(): ?(K, V) {
        extract(map.removeFirst())
    }
    public func removeLast(): ?(K, V) {
        extract(map.removeLast())
    }
}
class ComparableKeyMapIterator<K, V> <: Iterator<(K, V)> {
    ComparableKeyMapIterator(private let itr: Iterator<(ComparableKey<K>, V)>) {}
    public func next(): ?(K, V) {
        for((hk, v) in itr){
            return (hk.key, v)
        }
        None<(K, V)>
    }
}
class ComparableKeyCollection<K, V> <: Collection<K> {
    ComparableKeyCollection(private let dict: TreeDict<K, V>) {}

    /**
     * 返回 Keys 的迭代器
     * 返回值 Iterator<K> - Keys 的迭代器
     */
    public func iterator(): Iterator<K> {
        ComparableKeyIterator<K>(dict.map.keys().iterator())
    }

    /**
     * 返回 Keys 中所有的元素个数
     * 返回值 Int64 - 元素个数
     */
    public prop size: Int64 {
        get() {
            dict.size
        }
    }

    /**
     * 检查 Keys 是否为空
     * 返回值 Bool - 如果是，则返回 true; 否则，返回 false
     */
    public func isEmpty(): Bool {
        dict.isEmpty()
    }

    /**
     * 判断 Keys 是否包含指定元素
     * 参数 element - K
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(element: K): Bool {
        dict.contains(element)
    }

    /**
     * 判断 Keys 是否包含指定集合的元素
     * 参数 all - 待判断的集合 all
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<K>): Bool {
        dict.contains(all: all)
    }
}
class ComparableKeyIterator<K> <: Iterator<K> {
    ComparableKeyIterator(private let itr: Iterator<ComparableKey<K>>) {}
    public func next(): ?K {
        for(hk in itr){
            return hk.key
        }
        None<K>
    }
}
class ComparableKeyMapEntryView<K, V> <: MapEntryView<K, V> {
    ComparableKeyMapEntryView(private let view: MapEntryView<ComparableKey<K>, V>){}
    public prop key: K {
        get(){
            view.key.key
        }
    }
    public mut prop value: ?V {
        get(){
            view.value
        }
        set(value) {
            view.value = value
        }
    }
}