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

/**
 * 只读集合，所有修改操作都会忽略
 */
public class UnionSetIterator<T> <: Iterator<T> {
    UnionSetIterator(private let itr1: Iterator<T>, private let itr2: Iterator<T>){}
    public func next(): ?T {
        for(e in itr1){
            return e
        }
        for(e in itr2){
            return e
        }
        None<T>
    }
}
public class UnionSetView<T, C> <: Set<T> where T <: Equatable<T>, C <: Collection<T> {
    public UnionSetView(private let set1: Set<T>, private let set2: Set<T>) {}

    public func iterator(): Iterator<T> {
        IntersectionSetIterator<T>(DifferenceSetView(set1, set2).iterator(), set2)
    }
    public func isEmpty(): Bool {
        iterator().next().isNone()
    }
    public prop size: Int64 {
        get() {
            var s = 0
            for(_ in this){
                s++
            }
            s
        }
    }

    /**
     * 如果该集合包含指定元素，则返回 true
     * 参数 element - 需要判断的元素
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    public func contains(element: T): Bool {
        set1.contains(element) || set2.contains(element)
    }

    /**
     * 检查该集合是否为其他集合的子集
     * 参数 other - 其他集合
     * 返回值 Bool - 如果它是子集，则返回 true，否则返回 false
     */
    public func subsetOf(other: ReadOnlySet<T>): Bool {
        for(e in this where !other.contains(e)){
            return false
        }
        true
    }

    /**
     * 检查该集合是否包含其他集合
     * 参数 all - 其他集合
     * 返回值 Bool - 如果包含，则返回 true；否则，返回 false
     */
    public func contains(all!: Collection<T>): Bool {
        for(e in all where !this.contains(e)){
            return false
        }
        true
    }

    /**
     * 
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
        IntersectionSetView<T, Set<T>>(this, all)
    }

    /**
     * 克隆 Set
     * 返回新的 Set
     */
    public func clone(): Set<T> {
        this
    }
}