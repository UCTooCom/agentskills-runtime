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

import std.collection.{Map, EquatableCollection}

class MapKeyIterator<K, V> <: Iterator<K> {
    MapKeyIterator(private let entryIterator: Iterator<(K, V)>) {}
    public func next(): Option<K> {
        entryIterator.next()?[0]
    }
}

class MapKeys<K, V> <: EquatableCollection<K> where K <: Equatable<K> {
    MapKeys(private let map: Map<K, V>) {}

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
    public func toArray(): Array<K> {
        let itr = iterator()
        return Array<K>(size) {
            _ => itr.next().getOrThrow()
        }
    }

    /**
     * 返回实例类型的迭代器
     * 返回值 Iterator<E> - 返回实例类型的迭代器。
     */
    public func iterator(): Iterator<K> {
        return MapKeyIterator(map.iterator())
    }
    /**
     * 判断 Keys 是否包含指定元素
     * 参数 element - T
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(element: K): Bool {
        return map.contains(element)
    }

    /**
     * 判断 Keys 是否包含指定集合的元素
     * 参数 elements - 待判断的集合 elements
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<K>): Bool {
        return map.contains(all: all)
    }
}

class MapValueIterator<K, V> <: Iterator<V> {
    MapValueIterator(private let entryIterator: Iterator<(K, V)>) {}
    public func next(): Option<V> {
        entryIterator.next()?[1]
    }
}

class MapValues<K, V> <: Collection<V> where K <: Equatable<K> {
    private var map: Map<K, V>
    init(map: Map<K, V>) {
        this.map = map
    }

    /**
     * 返回 Values 的迭代器
     * 返回值 Iterator<T> - Values 的迭代器
     */
    public func iterator(): Iterator<V> {
        return MapValueIterator(map.iterator())
    }

    /**
     * 返回 Values 的元素个数
     * 返回值 Int64 - 元素的个数
     */
    public prop size: Int64 {
        get() {
            return map.size
        }
    }

    /**
       130
       3.2.8 class ArrayListIterator
       此类主要实现 ArrayList 的迭代器功能。
       3.2.9 class HashMapIterator
       此类主要实现 HashMap 的迭代器功能。
     * 判断 Values 是否为空
     * 返回值 Bool - 如果为空，则返回 true, 否则，返回 false
     */
    public func isEmpty(): Bool {
        return map.isEmpty()
    }

    /**
     * 清除所有 Values 中的元素
     */
    public func clear(): Unit {
        map.clear()
    }
    public func toArray(): Array<V> {
        let itr = iterator()
        Array<V>(size) {
            _ => itr.next().getOrThrow()
        }
    }
}
