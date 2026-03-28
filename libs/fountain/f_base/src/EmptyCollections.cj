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

import std.collection.{Set, Map, EquatableCollection}

public class EmptyArray<T> {
    // public static let INSTANCE = Array<T>() 
    public static func INSTANCE() {
        Array<T>()
    }
    private init() {}
}

public class EmptySet<T> <: Set<T> where T <: Equatable<T> {
    // public static let INSTANCE = EmptySet<T>()
    public static func INSTANCE() {
        EmptySet<T>()
    }

    private init() {}

    public func iterator(): Iterator<T> {
        EmptyIterator<T>.INSTANCE()
    }
    public func isEmpty(): Bool {
        true
    }
    public prop size: Int64 {
        get() {
            0
        }
    }

    /**
     * 如果该集合包含指定元素，则返回 true
     * 参数 element - 需要判断的元素
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(element: T): Bool {
        false
    }

    /**
     * 检查该集合是否为其他集合的子集
     * 参数 other - 其他集合
     * 返回值 Bool - 如果它是子集，则返回 true，否则返回 false
     */
    public func subsetOf(other: ReadOnlySet<T>): Bool {
        true
    }

    /**
     * 检查该集合是否包含其他集合
     * 参数 all - 其他集合
     * 返回值 Bool - 如果包含，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<T>): Bool {
        all.isEmpty()
    }

    /**
     * 添加元素操作。如果元素已经存在，则不会添加它
     * 参数 element - 要添加的元素
     */
    public func add(element: T): Bool {
        false
    }

    /**
     * 添加 Collection 中的所有元素至此 Set 中，如果元素存在，则不添加
     * 参数 all - 需要被添加的元素的集合
     */
    public func add(all!: Collection<T>): Unit {
        ()
    }

    /**
     * 从该结合中移除指定元素（如果存在）
     * 参数 element - 要删除的元素
     */
    public func remove(element: T): Bool {
        false
    }

    /**
     * 移除此 Set 中那些也包含在指定 Collection 中的所有元素
     * 参数 all - 传入 Collection<T>
     */
    public func remove(all!: Collection<T>): Unit {
        ()
    }

    /**
     * 传入 lambda 表达式，如果满足 true 条件，则删除对应的元素
     * 参数 predicate - 传入一个 lambda 表达式进行判断
     */
    public func removeIf(predicate: (T) -> Bool): Unit {
        ()
    }

    /**
     * 清除所有键值对
     */
    public func clear(): Unit {
        ()
    }

    /**
     * 只保留重复的 T
     * 参数 all - 要保存的元素集合
     */
    public func retain(all!: Set<T>): Unit {
        ()
    }

    /**
     * 克隆 Set
     * 返回新的 Set
     */
    public func clone(): Set<T> {
        this
    }
}

public class EmptyIterator<T> <: Iterator<T> {
    // public static let INSTANCE = EmptyIterator<T>()
    public static func INSTANCE() {
        EmptyIterator<T>()
    }
    private init() {}
    public func next(): Option<T> {
        None<T>
    }
}

public class EmptyIterable<T> <: Iterable<T> {
    // public static let INSTANCE = EmptyIterable<T>()
    public static func INSTANCE() {
        EmptyIterable<T>()
    }
    private init() {}
    public func iterator(): Iterator<T> {
        EmptyIterator<T>.INSTANCE()
    }
}

public class EmptyMap<K, V> <: Map<K, V> & Bucket<K, V> where K <: Equatable<K> {
    // public static let INSTANCE = EmptyMap<K, V>()
    public static func INSTANCE() {
        EmptyMap<K, V>()
    }

    private init() {}

    /**
     * 根据 key 得到 Map 中映射的值
     * 参数 key - 传递 key，获取 value
     * 返回值 Option<V> - key 对应的值是用 Option 封装的
     */
    public func get(key: K): Option<V> {
        None<V>
    }

    /**
     * 判断是否包含指定键的映射
     * 参数 key - 传递要判断的 key
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(key: K): Bool {
        false
    }

    /**
     * 判断是否包含指定集合键的映射
     * 参数 keys - 传递待判断的 keys
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<K>): Bool {
        all.isEmpty()
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
        None<V>
    }

    /**
     * 传递指定元素进行遍历，并按顺序赋值
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 element - 传递给遍历赋值的元素
     */
    public func add(all!: Collection<(K, V)>): Unit {
        ()
    }
    public func addIfAbsent(key: K, value: V): ?V {
        None<V>
    }
    public func replace(key: K, value: V): ?V {
        None<V>
    }

    /**
     * 从此映射中删除指定键的映射（如果存在）
     * 参数 key - 传入要删除的 key
     * 返回值 Option<V> - 被移除映射的 V 用 Option 封装
     */
    public func remove(key: K): Option<V> {
        None<V>
    }

    /**
     * 从此映射中删除指定集合的映射（如果存在）
     * 参数 all - 传人要删除的集合
     */
    public func remove(all!: Collection<K>): Unit {
        ()
    }

    /**
     * 传入 lambda 表达式，如果满足条件，则删除对应的键值
     * 参数 predicate - 传递一个 lambda 表达式进行判断
     */
    public func removeIf(predicate: (K, V) -> Bool): Unit {
        ()
    }

    /**
     * 清除所有键值对
     */
    public func clear(): Unit {
        ()
    }

    /**
     * 克隆 Map
     * 返回值 Map<K, V> - 返回一个 Map<K, V>
     */
    public func clone(): Map<K, V> {
        this
    }

    /**
     * 运算符重载集合，如果键存在，返回键对应的值，如果不存在，抛出异常。
     * 参数 key - 传递值进行判断
     * 返回值 V - 与键对应的值
     */
    public operator func [](key: K): V {
        None<V>.getOrThrow()
    }

    /**
     * 运算符重载集合，如果键存在，新 value 覆盖旧 value，如果键不存在，
     * 添加此键值对
     * 参数 key - 传递值进行判断
     * 参数 value - 传递要设置的值
     */
    public operator func [](key: K, value!: V): Unit {
        ()
    }

    /**
     * 返回 Map 中所有的 key，并将所有 key 存储在一个 Keys 容器中
     * 返回值 Keys<K> - 保存所有返回的 key
     */
    public func keys(): EquatableCollection<K> {
        EmptyEquatableCollection<K>.INSTANCE()
    }

    /**
     * 返回 Map 中所有的 value，并将所有 value 存储在一个 Values 容器中
     * 返回值 Values<V> - 保存所有返回的 value
     */
    public func values(): Collection<V> {
        EmptyCollection<V>.INSTANCE()
    }

    /**
     * 返回 Map 中所有的元素个数
     * 返回值 Int64 - 元素个数
     */
    public prop size: Int64 {
        get() {
            0
        }
    }

    /**
     * 检查 Map 是否为空
     * 返回值 Bool - 如果是，则返回 true; 否则，返回 false
     */
    public func isEmpty(): Bool {
        true
    }

    /**
     * 返回 Map 的迭代器
     * 返回值 Iterator<(K,V)> - Map 的迭代器
     */
    public func iterator(): Iterator<(K, V)> {
        EmptyIterator<(K, V)>.INSTANCE()
    }
    public func toArray(): Array<(K, V)> {
        []
    }
    public func entryView(k: K): MapEntryView<K, V> {
        EmptyMapEntryView<K, V>(k)
    }
}

public class EmptyMapEntryView<K, V> <: MapEntryView<K, V> {
    EmptyMapEntryView(private let k: K) {}
    public prop key: K {
        get() {
            k
        }
    }
    public mut prop value: ?V {
        get() {
            None<V>
        }
        set(value) {}
    }
}

public class EmptyEquatableCollection<K> <: EquatableCollection<K> where K <: Equatable<K> {
    // public static let INSTANCE = EmptyEquatableCollection<K>()
    public static func INSTANCE() {
        EmptyEquatableCollection<K>()
    }
    private init() {}

    /**
     * 返回 Keys 的迭代器
     * 返回值 Iterator<K> - Keys 的迭代器
     */
    public func iterator(): Iterator<K> {
        EmptyIterator<K>.INSTANCE()
    }

    /**
     * 返回 Keys 中所有的元素个数
     * 返回值 Int64 - 元素个数
     */
    public prop size: Int64 {
        get() {
            0
        }
    }

    /**
     * 检查 Keys 是否为空
     * 返回值 Bool - 如果是，则返回 true; 否则，返回 false
     */
    public func isEmpty(): Bool {
        true
    }

    /**
     * 判断 Keys 是否包含指定元素
     * 参数 element - K
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(element: K): Bool {
        false
    }

    /**
     * 判断 Keys 是否包含指定集合的元素
     * 参数 all - 待判断的集合 all
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<K>): Bool {
        all.isEmpty()
    }
}

public class EmptyCollection<T> <: Collection<T> {
    // public static let INSTANCE = EmptyCollection<T>()
    public static func INSTANCE() {
        EmptyCollection<T>()
    }
    private init() {}

    /**
     * 返回对象的长度。
     * 返回值 Int64 - 列表的容量
     */
    public prop size: Int64 {
        get() {
            0
        }
    }

    /**
     * 判断对象是否为空
     * 返回值 Bool - 若为空返回 true，否则返回 false
     */
    public func isEmpty(): Bool {
        true
    }

    /**
     * 将对象转为数组类型
     * 返回值 Array<T> - 转换后的数组
     */
    public func toArray(): Array<T> {
        EmptyArray<T>.INSTANCE()
    }
    public func iterator(): Iterator<T> {
        EmptyIterator<T>.INSTANCE()
    }
}

public class EmptyList<T> <: List<T> {
    // public static let INSTANCE = EmptyList<T>()
    public static func INSTANCE() {
        EmptyList<T>()
    }
    private init() {}
    public func isEmpty(): Bool {
        true
    }
    public func iterator(): Iterator<T> {
        EmptyIterator<T>.INSTANCE()
    }
    public prop size: Int64 {
        get() {
            0
        }
    }
    public func add(element: T): Unit {}
    public func add(all!: Collection<T>): Unit {}
    public func add(element: T, at!: Int64): Unit {}
    public func add(all!: Collection<T>, at!: Int64): Unit {}
    public func remove(at!: Int64): T {
        throw IndexOutOfBoundsException('current list is empty')
    }
    public func remove(range: Range<Int64>): Unit {}
    public func removeIf(predicate: (T) -> Bool): Unit {}
    public func clear(): Unit {}

    public operator func [](index: Int64, value!: T): Unit {}
    public operator func [](index: Int64): T {
        throw IndexOutOfBoundsException('current list is empty')
    }
    public func insert(at: Int64, element: T): Unit {}
    public func remove(element: T): Bool {
        false
    }
    public func contains(element: T): Bool {
        false
    }
    public func contains(all!: Collection<T>): Bool {
        false
    }
    public func indexOf(element: T): ?Int64 {
        None<Int64>
    }
    public func lastIndexOf(element: T): ?Int64 {
        None<Int64>
    }
    public func count(element: T): Int64 {
        0
    }
    public func reverse(): Unit {}
    public func sortBy(comparator: (T, T) -> Ordering, stable!: Bool): Unit {}
    public func reserve(additional: Int64): Unit {}
    public func capacity(): Int64 {
        0
    }
    public prop first: ?T {
        get() {
            None<T>
        }
    }
    public prop last: ?T {
        get() {
            None<T>
        }
    }
    public func get(index: Int64): ?T {
        None<T>
    }
}
