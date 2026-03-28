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

import std.collection.MapEntryView

public interface ConcDict<K, V> <: Collection<(K, V)> {
    
    /**
     * 根据 key 得到 Map 中映射的值
     * 参数 key - 传递 key，获取 value
     * 返回值 Option<V> - key 对应的值是用 Option 封装的
     */
    func get(key: K): Option<V> 

    /**
     * 判断是否包含指定键的映射
     * 参数 key - 传递要判断的 key
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    func contains(key: K): Bool 

    /**
     * 判断是否包含指定集合键的映射
     * 参数 keys - 传递待判断的 keys
     * 返回值 Bool - 如果存在，则返回 true；否则，返回 false
     */
    func contains(all!: Collection<K>): Bool 

    /**
     * 将指定的值与此映射中指定的键关联
           120
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 key - 要放置的键
     * 参数 value - 要分配的值
     * 返回值 Option<V> - 如果赋值之前 key 存在，旧的 value 用 Option 封装；
     * 否则，返回 Option<V>.None
     */
    func add(key: K, value: V): Option<V> 

    /**
     * 传递指定元素进行遍历，并按顺序赋值
     * 如果映射以前包含键的映射，则旧值将被替换
     * 参数 element - 传递给遍历赋值的元素
     */
    func add(all!: Collection<(K, V)>): Unit 
    func addIfAbsent(key: K, value: V): ?V 
    func replace(key: K, value: V): ?V 

    /**
     * 从此映射中删除指定键的映射（如果存在）
     * 参数 key - 传入要删除的 key
     * 返回值 Option<V> - 被移除映射的 V 用 Option 封装
     */
    func remove(key: K): Option<V> 

    /**
     * 从此映射中删除指定集合的映射（如果存在）
     * 参数 all - 传人要删除的集合
     */
    func remove(all!: Collection<K>): Unit 
    /**
     * 传入 lambda 表达式，如果满足条件，则删除对应的键值
     * 参数 predicate - 传递一个 lambda 表达式进行判断
     */
    func removeIf(predicate: (K, V) -> Bool): Unit 
    /**
     * 清除所有键值对
     */
    func clear(): Unit 

    /**
     * 运算符重载集合，如果键存在，返回键对应的值，如果不存在，抛出异常。
     * 参数 key - 传递值进行判断
     * 返回值 V - 与键对应的值
     */
    operator func [](key: K): V 

    /**
     * 运算符重载集合，如果键存在，新 value 覆盖旧 value，如果键不存在，
     * 添加此键值对
     * 参数 key - 传递值进行判断
     * 参数 value - 传递要设置的值
     */
    operator func [](key: K, value!: V): Unit 

    /**
     * 返回 Map 中所有的 key，并将所有 key 存储在一个 Keys 容器中
     * 返回值 Keys<K> - 保存所有返回的 key
     */
    func keys(): Collection<K> 

    /**
     * 返回 Map 中所有的 value，并将所有 value 存储在一个 Values 容器中
     * 返回值 Values<V> - 保存所有返回的 value
     */
    func values(): Collection<V> 

    /**
     * 返回 Map 中所有的元素个数
     * 返回值 Int64 - 元素个数
     */
    prop size: Int64 

    /**
     * 检查 Map 是否为空
     * 返回值 Bool - 如果是，则返回 true; 否则，返回 false
     */
    func isEmpty(): Bool 

    /**
     * 返回 Map 的迭代器
     * 返回值 Iterator<(K,V)> - Map 的迭代器
     */
    func iterator(): Iterator<(K, V)> 
    func entryView(key: K, fn: (K, ?V) -> ?V): ?V 
    func addIfAbsent(key: K, fn: () -> V): V {
        entryView(key){k, v => 
            if(v.isNone()){
                fn()
            }else{
                v
            }
        }.getOrThrow()
    }
    func addIfPreset(key: K, fn: () -> V): ?V {
        entryView(key){k, v => 
            if(v.isSome()){
                fn()
            }else{
                None<V>
            }
        }
    }
    func removeIf(key: K, predicate: (V) -> Bool): ?V {
        entryView(key){k, vv => 
            if(let Some(v) <- vv && predicate(v)){
                None<V>
            }else{
                vv
            }
        }
    }
}