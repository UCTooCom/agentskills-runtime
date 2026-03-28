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

import std.collection.ArrayList
import f_base.*

class PriorityQueueIterator<T> <: Iterator<T> {
    private var idx = 0
    PriorityQueueIterator(private let itr: Iterator<Option<T>>, private let max_: Int64) {}

    public func next(): Option<T> {
        for (current in itr) {
            if (idx >= max_ || current.isNone()) {
                break
            }
            idx++
            return current.getOrThrow()
        }
        None<T>
    }
}

public class PriorityQueue<T> <: Queue<T> & Iterable<T> & Collection<T> & Growable {
    private static const DEFAULT_CAPACITY = 16
    /**
     * current size
     */
    private var currentSize: Int64 = 0

    /**
     * datas
     */
    private var queue: Array<Option<T>>

    public PriorityQueue(
        private let comparator: (T, T) -> Ordering,
        private var capacity!: Int64 = DEFAULT_CAPACITY,
        private let overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) {
        queue = Array<Option<T>>(capacity,repeat: None<T>)
    }
    public init(
        comparator: Comparator<T>,
        capacity!: Int64 = DEFAULT_CAPACITY,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) {
        this(comparator.comparator, capacity: capacity, overSizePolicy: overSizePolicy)
    }
    public static func create<T>(
        capacity!: Int64 = DEFAULT_CAPACITY,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) where T <: Comparable<T> {
        PriorityQueue<T>.create(Comparator<T>.create<T>(), capacity: capacity, overSizePolicy: overSizePolicy)
    }
    public static func createReverse<T>(
        capacity!: Int64 = DEFAULT_CAPACITY,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) where T <: Comparable<T> {
        PriorityQueue<T>.create(Comparator<T>.create<T>().reverse(), capacity: capacity, overSizePolicy: overSizePolicy)
    }
    public static func create(
        comparator: Comparator<T>,
        capacity!: Int64 = DEFAULT_CAPACITY,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) {
        PriorityQueue<T>(comparator.comparator, capacity: capacity, overSizePolicy: overSizePolicy)
    }

    /**
     * current size
     */
    public prop size: Int64 {
        get() {
            currentSize
        }
    }
    public func isEmpty(): Bool {
        size == 0
    }

    /**
     * add an element
     */
    public func add(x: T): Unit {
        if (capacity > 0 && size >= capacity) {
            overSizePolicy.reject(this) {doOffer(x)}
        } else {
            doOffer(x)
        }
    }
    private func doOffer(x: T): Bool {
        if (currentSize == 0) {
            queue[currentSize] = x
            currentSize++
            true
        } else if (!isFull()) {
            adjustUp(currentSize, x)
            currentSize++
            true
        } else if (capacity <= 0) {
            grow()
            doOffer(x)
        } else {
            false
        }
    }
    public func grow(): Unit {
        let q = queue
        queue = Array<Option<T>>(currentSize * 2) {
            i => if (i < currentSize) {
                q[i]
            } else {
                None<T>
            }
        }
    }

    /**
     * offer all elements in values to current queue
     */
    public func add(all!: Collection<T>) {
        for (value in all) {
            add(value)
        }
    }

    /**
     * is current heap full? if capacity is not greater than 0, heap is infinity
     */
    private func isFull() {
        return currentSize >= queue.size
    }

    /**
     * get element on top
     */
    public func peek(): Option<T> {
        if (currentSize > 0) {
            queue[0]
        } else {
            None<T>
        }
    }

    /**
     * get and remove element on top
     */
    public func remove(): Option<T> {
        let cur = peek()
        if (cur.isNone()) {
            return None<T>
        }
        currentSize--
        let temp = queue[currentSize]
        queue[currentSize] = None<T>
        if (currentSize > 0) {
            adjustDown(0, temp.getOrThrow())
        }
        return cur
    }

    /**
     * 从下往上调整
     */
    private func adjustUp(k: Int64, value: T) {
        var i = k
        while (i > 0) {
            let parent = (i - 1) >> 1 //父
            let current = queue[parent].getOrThrow()
            if (comparator(current, value) == LT) {
                break
            }
            queue[i] = queue[parent]
            i = parent
        }
        queue[i] = value
    }

    /**
     * 从上往下调整
     */
    private func adjustDown(k: Int64, value: T) { //把要插入的值传入进来，节省每转旋转交换的开销
        var i = k
        let progenitor = currentSize >> 1 //最禄的父,也是adjustDown的终点，再往下就是空转了
        while (i < progenitor) {
            var leftChild = (i << 1) + 1 //左子
            var leftChildVal = queue[leftChild].getOrThrow()
            let rightChild = leftChild + 1 //右子
            if (rightChild < currentSize && comparator(leftChildVal, queue[rightChild].getOrThrow()) == GT) {
                leftChild = rightChild
                leftChildVal = queue[leftChild].getOrThrow()
            }
            if (comparator(leftChildVal, value) == GT) {
                break
            }
            queue[i] = leftChildVal
            i = leftChild
        }
        queue[i] = value
    }

    public func iterator(): Iterator<T> {
        let itr: Iterator<Option<T>> = queue.iterator()
        let size: Int64 = currentSize
        PriorityQueueIterator<T>(itr, size)
    }
    public func removeIf(predicate: (T) -> Bool): Unit {
        let size = currentSize
        var lastIdx = size
        var toAdjust = false
        for (i in 0..size) {
            let v = queue[i].getOrThrow()
            if (predicate(v)) {
                queue[i] = None<T>
                if (!toAdjust) {
                    lastIdx = i
                    toAdjust = true
                }
            } else if (toAdjust) {
                queue[i] = None<T>
                adjustUp(lastIdx, v)
                lastIdx++
            }
        }
        currentSize = lastIdx
    }
    public func toArray(): Array<T> {
        let itr = iterator()
        Array<T>(size) {
            _ => itr.next().getOrThrow()
        }
    }
}
