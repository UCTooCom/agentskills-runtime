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

public class SyncPriorityQueue<T> <: Queue<T> & Collection<T> & Growable {
    private let mutex = Mutex()
    private let queue: PriorityQueue<T>
    public init(
        comparator: (T, T) -> Ordering,
        capacity!: Int64 = 0,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) {
        queue = PriorityQueue<T>(comparator, capacity: capacity, overSizePolicy: overSizePolicy)
    }
    public init(
        comparator: Comparator<T>,
        capacity!: Int64 = 0,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) {
        this(comparator.comparator, capacity: capacity, overSizePolicy: overSizePolicy)
    }
    public static func create<T>(
        capacity!: Int64 = 0,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) where T <: Comparable<T> {
        SyncPriorityQueue<T>.create(Comparator<T>.create<T>(), capacity: capacity, overSizePolicy: overSizePolicy)
    }
    public static func createReverse<T>(
        capacity!: Int64 = 0,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) where T <: Comparable<T> {
        SyncPriorityQueue<T>.create(Comparator<T>.create<T>().reverse(), capacity: capacity,
            overSizePolicy: overSizePolicy)
    }
    public static func create(
        comparator: Comparator<T>,
        capacity!: Int64 = 0,
        overSizePolicy!: OverSizePolicy<PriorityQueue<T>> = DiscardOverSizePolicy<PriorityQueue<T>>()
    ) {
        SyncPriorityQueue<T>(comparator.comparator, capacity: capacity, overSizePolicy: overSizePolicy)
    }

    public prop size: Int64 {
        get() {
            synchronized(mutex) {
                queue.size
            }
        }
    }
    public func isEmpty(): Bool {
        synchronized(mutex) {
            queue.isEmpty()
        }
    }
    public func add(x: T): Unit {
        synchronized(mutex) {
            queue.add(x)
        }
    }
    public func grow(): Unit {
        synchronized(mutex) {
            queue.grow()
        }
    }
    public func add(all!: Collection<T>) {
        synchronized(mutex) {
            queue.add(all: all)
        }
    }
    public func peek(): ?T {
        synchronized(mutex) {
            queue.peek()
        }
    }
    public func remove(): ?T {
        synchronized(mutex) {
            queue.remove()
        }
    }
    public func iterator(): Iterator<T> {
        synchronized(mutex) {
            SyncPriorityQueueIterator<T>(queue.iterator(), mutex)
        }
    }
    public func removeIf(predicate: (T) -> Bool): Unit {
        synchronized(mutex) {
            queue.removeIf(predicate)
        }
    }
    public func toArray(): Array<T> {
        synchronized(mutex) {
            queue.toArray()
        }
    }
}

public class SyncPriorityQueueIterator<T> <: Iterator<T> {
    public SyncPriorityQueueIterator(private let itr: Iterator<T>, private let mutex: Mutex) {}
    public func next(): ?T {
        synchronized(mutex) {
            itr.next()
        }
    }
}
