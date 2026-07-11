/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq4cj.client.util

public open class LRUCache<K, V> <: Map<K, V> where K <: Equatable<K> & Hashable {
    private var maxCacheSizeVal: Int64 = 10000
    private var map: HashMap<K, V>
    private var head: ?Entry<K, V> = None
    private var tail: ?Entry<K, V> = None

    private let mutex: ReentrantReadWriteMutex = ReentrantReadWriteMutex()

    private var sizeVal: Int64 = 0

    public init() {
        this.map = HashMap<K, V>()
    }

    public init(maximumCacheSize: Int64) {
        this.map = HashMap<K, V>()
        this.maxCacheSizeVal = maximumCacheSize
    }

    public override func get(key: K): Option<V> {
        mutex.readMutex.lock()
        try {
            if (let Some(node) <- findEntry(key)) {
                afterNodeAccess(node)
            }
            return map.get(key)
        } finally {
            mutex.readMutex.unlock()
        }
    }

    public override func contains(key: K): Bool {
        mutex.readMutex.lock()
        try {
            return map.contains(key)
        } finally {
            mutex.readMutex.unlock()
        }
    }

    public override func contains(all!: Collection<K>): Bool {
        mutex.readMutex.lock()
        try {
            return map.contains(all: all)
        } finally {
            mutex.readMutex.unlock()
        }
    }

    public override func add(key: K, value: V): Option<V> {
        mutex.writeMutex.lock()
        try {
            let containsKey = contains(key)
            let rc = map.add(key, value)
            if (containsKey) {
                if (let Some(node) <- findEntry(key)) {
                    node.value = value
                    afterNodeAccess(node)
                }
            } else {
                linkNodeLast(Entry<K, V>(key, value))
                this.sizeVal++
                afterNodeInsertion()
            }
            return rc
        } finally {
            mutex.writeMutex.unlock()
        }
    }

    public override func add(all!: Collection<(K, V)>): Unit {
        for ((k, v) in all) {
            add(k, v)
        }
    }

    public override func remove(key: K): Option<V> {
        mutex.writeMutex.lock()
        try {
            if (!contains(key)) {
                return None
            }
            let rc = map.remove(key)
            afterNodeRemoval(findEntry(key))
            this.sizeVal--
            return rc
        } finally {
            mutex.writeMutex.unlock()
        }
    }

    public override func remove(all!: Collection<K>): Unit {
        for (key in all) {
            remove(key)
        }
    }

    public override func removeIf(predicate: (K, V) -> Bool): Unit {
        mutex.writeMutex.lock()
        try {
            map.removeIf(predicate)
            var current = head
            //遍历链表，找到符合条件的entry
            while (current.isSome()) {
                if (let Some(currentNode) <- current) {
                    current = currentNode.next
                    if (predicate(currentNode.key, currentNode.value)) {
                        afterNodeRemoval(currentNode)
                        this.sizeVal--
                    }
                }
            }
        } finally {
            mutex.writeMutex.unlock()
        }
    }

    private func findEntry(key: K): ?Entry<K, V> {
        var current = head
        //遍历链表，找到符合条件的entry
        while (current.isSome()) {
            if (let Some(currentNode) <- current) {
                if (currentNode.key == key && currentNode.key.hashCode() == key.hashCode()) {
                    return currentNode
                }
                current = currentNode.next
            }
        }
        return None
    }

    public override func clear(): Unit {
        mutex.writeMutex.lock()
        try {
            map.clear()
            this.head = None
            this.tail = None
            this.sizeVal = 0
        } finally {
            mutex.writeMutex.unlock()
        }
    }

    public func clone(): Map<K, V> {
        let copy = LRUCache<K, V>()
        copy.map = map.clone()
        copy.head = this.head
        copy.tail = this.tail
        copy.sizeVal = sizeVal
        return copy
    }

    public operator func [](key: K, value!: V): Unit {
        add(key, value)
    }

    public operator func [](key: K): V {
        return map[key]
    }

    public override func keys(): EquatableCollection<K> {
        mutex.readMutex.lock()
        try {
            return map.keys()
        } finally {
            mutex.readMutex.unlock()
        }
    }

    public override func values(): Collection<V> {
        mutex.readMutex.lock()
        try {
            return map.values()
        } finally {
            mutex.readMutex.unlock()
        }
    }

    public prop size: Int64 {
        get() {
            return this.sizeVal
        }
    }

    public override func isEmpty(): Bool {
        return size == 0
    }

    public override func iterator(): LRUCacheIterator<K, V> {
        return LRUCacheIterator<K, V>(head)
    }

    private func afterNodeAccess(node: Entry<K, V>): Unit {
        var last = tail
        if (let Some(lastNode) <- last) {
            if (!refEq(lastNode, node)) {
                let b = node.prev
                let a = node.next

                node.next = None

                if (let Some(b) <- b) {
                    b.next = a
                } else {
                    head = a
                }

                if (let Some(a) <- a) {
                    a.prev = b
                } else {
                    last = b
                }
                node.prev = last
                lastNode.next = node
                tail = node
            }
        } else {
            head = node
        }
    }

    private func afterNodeInsertion() {
        let p = head
        if (let Some(p) <- p) {
            if (removeEldestEntry(p)) {
                remove(p.key)
            }
        }
    }

    public open func removeEldestEntry(eldest: Entry<K, V>): Bool {
        if (size > maxCacheSize) {
            return true
        }
        return false
    }

    /**
     * 元素删除后移除链节点
     */
    private func afterNodeRemoval(node: ?Entry<K, V>): Unit {
        if (let Some(node) <- node) {
            let b = node.prev
            let a = node.next

            node.prev = None
            node.next = None

            if (let Some(b) <- b) {
                b.next = a
            } else {
                head = a
            }

            if (let Some(a) <- a) {
                a.prev = b
            } else {
                tail = b
            }
        }
    }

    private func linkNodeLast(p: Entry<K, V>): Unit {
        let last = tail
        tail = p
        if (let Some(last) <- last) {
            p.prev = last
            last.next = p
        } else {
            head = p
        }
    }

    public mut prop maxCacheSize: Int64 {
        get() {
            return this.maxCacheSizeVal
        }
        set(value) {
            this.maxCacheSizeVal = value
        }
    }

    public func entryView(key: K): MapEntryView<K, V> {
        map.entryView(key)
    }
}

public class Entry<K, V> where K <: Equatable<K> & Hashable {
    private var prevVal: ?Entry<K, V> = None
    private var nextVal: ?Entry<K, V> = None
    protected let key: K
    public var value: V

    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }

    public mut prop prev: ?Entry<K, V> {
        get() {
            return this.prevVal
        }
        set(value) {
            this.prevVal = value
        }
    }

    public mut prop next: ?Entry<K, V> {
        get() {
            return this.nextVal
        }
        set(value) {
            this.nextVal = value
        }
    }
}

public class LRUCacheIterator<K, V> <: Iterator<(K, V)> where K <: Equatable<K> & Hashable {
    private var cursor: ?Entry<K, V>

    public init(head: ?Entry<K, V>) {
        this.cursor = head
    }

    public override func next(): Option<(K, V)> {
        if (let Some(cursor) <- this.cursor) {
            this.cursor = cursor.next
            return (cursor.key, cursor.value)
        }
        return None
    }
}
