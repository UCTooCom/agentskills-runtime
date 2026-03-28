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

import std.collection.{HashMap, Map, EquatableCollection, MapEntryView, ArrayList}
import f_exception.UnreachableException

public class LinkedHashMap<K, V> <: Map<K, V> where K <: Hashable & Equatable<K> {
    private let map: HashMap<K, ValueNode<(K, V)>>
    private var head = HeadNode<(K, V)>()
    private var tail = head.tail
    private let size_: Int64
    private let max: Bool

    public init() {
        this.max = false
        this.size_ = 0
        this.map = HashMap<K, ValueNode<(K, V)>>()
    }
    public init(size: Int64, max: Bool) {
        this.max = max
        this.size_ = size
        map = HashMap<K, ValueNode<(K, V)>>(size)
    }
    public init(c: Collection<(K, V)>) {
        map = HashMap<K, ValueNode<(K, V)>>(c.size)
        this.max = false
        this.size_ = c.size
        add(all: c)
    }
    public init(c: Collection<(K, V)>, size: Int64, max: Bool) {
        map = HashMap<K, ValueNode<(K, V)>>(size)
        this.max = max
        this.size_ = size
        add(all: c)
    }
    public init(size: Int64, initElement: (Int64) -> (K, V)) {
        map = HashMap<K, ValueNode<(K, V)>>(size)
        this.size_ = size
        this.max = false
        for (i in 0..size) {
            let (k, v) = initElement(i)
            add(k, v)
        }
    }

    /**
     * 返回对象的长度。
     * 返回值 Int64 - 列表的容量
     */
    public prop size: Int64 {
        get() {
            return map.size
        }
    }

    /**
     * 判断对象是否为空
     * 返回值 Bool - 若为空返回 true，否则返回 false
     */
    public func isEmpty(): Bool {
        return map.isEmpty()
    }

    /**
     * 将对象转为数组类型
     * 返回值 Array<T> - 转换后的数组
     */
    public func toArray(): Array<(K, V)> {
        let itr = iterator()
        Array<(K, V)>(size) {
            _ => itr.next().getOrThrow()
        }
    }

    /**
     * 返回实例类型的迭代器
     * 返回值 Iterator<(K,V)> - 返回实例类型的迭代器。
     */
    public func iterator(): LinkedNodeIterator<(K, V)> {
        return LinkedNodeIterator<(K, V)>(head)
    }
    private func turnToTail(entry: ValueNode<(K, V)>) {
        if (size <= 1) {
            return
        }
        entry.turnTo(tail)
    }
    public func entryView(key: K): MapEntryView<K, V> {
        LinkedHashMapEntryView<K, V>(key, this)
    }
    /**
     * 根据 key 得到 Map 中映射的值
     * 参数 key - 传递 key，获取 value
     * 返回值 Option<V> - key 对应的值是用 Option 封装的
     */
    public func get(key: K): Option<V> {
        return get(key, true)
    }
    public func get(key: K, turn: Bool): Option<V> {
        return match (map.get(key)) {
            case Some(n) =>
                if (turn) {
                    this.turnToTail(n)
                }
                n.value[1]
            case _ => None<V>
        }
    }

    /**
     * 判断是否包含指定键的映射
     * 参数 key - 传递要判断的 key
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(key: K): Bool {
        return map.contains(key)
    }

    /**
     * 判断是否包含指定集合键的映射
     * 参数 all - 传递待判断的 all
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<K>): Bool {
        return map.contains(all: all)
    }
    private func delete(opt: Option<ValueNode<(K, V)>>, removeMap!: Bool = false): Option<V> {
        return match (opt) {
            case Some(n) =>
                n.remove()
                if (removeMap) {
                    map.remove(n.value[0])
                }
                n.value[1]
            case _ => None<V>
        }
    }
    private func getFirstEntry(): Option<ValueNode<(K, V)>> {
        match (head.next) {
            case n: ValueNode<(K, V)> => n
            case n: TailNode<(K, V)> => None<ValueNode<(K, V)>>
            case _ => throw UnreachableException()
        }
    }
    private func getLastEntry(): Option<ValueNode<(K, V)>> {
        match (tail.prev) {
            case n: ValueNode<(K, V)> => n
            case n: HeadNode<(K, V)> => None<ValueNode<(K, V)>>
            case _ => throw UnreachableException()
        }
    }
    private func extract(opt: Option<ValueNode<(K, V)>>): Option<(K, V)> {
        match (opt) {
            case Some(n) => n.value
            case _ => None<(K, V)>
        }
    }
    public func firstEntry(): Option<(K, V)> {
        if (map.isEmpty()) {
            return None<(K, V)>
        }
        let entry = getFirstEntry()
        match (entry) {
            case Some(e) =>
                turnToTail(e)
                return extract(entry)
            case _ => return None<(K, V)>
        }
    }
    public func pollFirstEntry(): Option<(K, V)> {
        if (map.isEmpty()) {
            return None<(K, V)>
        }
        let entry = getFirstEntry()
        delete(entry, removeMap: true)
        return extract(entry)
    }
    public func lastEntry(): Option<(K, V)> {
        if (map.isEmpty()) {
            return None<(K, V)>
        }
        let entry = getLastEntry()
        return extract(entry)
    }
    public func pollLastEntry(): Option<(K, V)> {
        if (map.isEmpty()) {
            return None<(K, V)>
        }
        let entry = getLastEntry()
        delete(entry, removeMap: true)
        return extract(entry)
    }

    /**
     * 将指定的值与此映射中指定的键关联
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 key - 要放置的键
     * 参数 value - 要分配的值
     * 返回值 Option<V> - 如果赋值之前 key 存在，旧的 value 用 Option 封装；
     * 否则，返回 None<V>
     */
    public func add(key: K, value: V): Option<V> {
        var s = size
        while (max && s > 0 && s >= size_ && !this.contains(key)) {
            match (head.next) {
                case n: ValueNode<(K, V)> => remove(n.value[0])
                case _ => throw UnreachableException()
            }
            s = size
        }
        let old = map.add(key, tail.insertPrev((key, value)))
        delete(old)
    }
    public func add(entry: (K, V)): Option<V> {
        return add(entry[0], entry[1])
    }

    /**
     * 传递指定元素进行遍历，并按顺序赋值
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 element - 传递给遍历赋值的元素
     */
    public func add(all!: Collection<(K, V)>): Unit {
        for (e in all) {
            add(e)
        }
    }

    /**
     * 从此映射中删除指定键的映射（如果存在）
     * 参数 key - 传入要删除的 key
     * 返回值 Option<V> - 被移除映射的 V 用 Option 封装
     */
    public func remove(key: K): Option<V> {
        let opt = map.remove(key)
        return delete(opt)
    }

    /**
     * 从此映射中删除指定集合的映射（如果存在）
     * 参数 all - 传人要删除的集合
     */
    public func remove(all!: Collection<K>): Unit {
        map.remove(all: all)
    }

    /**
     * 传入 lambda 表达式，如果满足条件，则删除对应的键值
     * 参数 predicate - 传递一个 lambda 表达式进行判断
     */
    public func removeIf(predicate: (K, V) -> Bool): Unit {
        map.removeIf{k, n => 
            let r = predicate(k, n.value[1])
            if(r){
                n.remove()
            }
            r
        }
    }

    /**
     * 清除所有键值对
     */
    public func clear(): Unit {
        map.clear()
        this.head.reset(tail)
    }

    /**
     * 克隆 Map
     * 返回值 Map<K, V> - 返回一个 Map<K, V>
     */
    public func clone(): Map<K, V> {
        return LinkedHashMap<K, V>(this)
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
    public func keys(): EquatableCollection<K> {
        return MapKeys<K, V>(this)
    }

    /**
     * 返回 Map 中所有的 value，并将所有 value 存储在一个 Values 容器中
     * 返回值 Values<V> - 保存所有返回的 value
     */
    public func values(): Collection<V> {
        return MapValues<K, V>(this)
    }
}

public class LinkedHashMapEntryView<K, V> <: MapEntryView<K, V> where K <: Hashable & Equatable<K> {
    public LinkedHashMapEntryView(private let k: K, private let map: LinkedHashMap<K, V>) {}
    public prop key: K {
        get() {
            k
        }
    }
    public mut prop value: ?V {
        get() {
            map.get(k)
        }
        set(value) {
            match (value) {
                case Some(v) => map[k] = v
                case _ => map.remove(k)
            }
        }
    }
}
