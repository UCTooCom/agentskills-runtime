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
package f_rx

public interface Cache<T> <: Iterable<T> {
    func new(): Cache<T>
    func set(value: T): Unit
    func replay(observer: Observer<T>, fn: () -> Unit): Unit
}
public class EmptyCache<T> <: Cache<T> {
    public func new(): Cache<T> {
        this
    }
    public func iterator(): Iterator<T> {
        EmptyIterator<T>()
    }
    public func set(value: T): Unit{

    }
    public func replay(observer: Observer<T>, fn: () -> Unit): Unit {
        fn()
    }
}
public class QueuedCache<T> <: Cache<T> {
    private let queue: LinkedList<T>
    private let lock = Mutex()
    public QueuedCache(private let capacity: Int64) {
        queue = LinkedList<T>()
    }
    public func new(): Cache<T> {
        QueuedCache<T>(capacity)
    }
    public func iterator(): Iterator<T> {
        CacheIterator<T>(queue.iterator(), lock, capacity)
    }
    public func set(value: T): Unit{
        synchronized(lock) {
            while(queue.size >= capacity) {
                queue.removeFirst()
            }
            queue.addLast(value)
        }
    }
    public func replay(observer: Observer<T>, fn: () -> Unit): Unit {
        synchronized(lock){
            for(data in queue){
                observer.onNext(data)
            }
            fn()
        }
    }
}
class CacheIterator<T> <: Iterator<T> {
    CacheIterator(private let itr: Iterator<T>, private let lock: Mutex, private let size: Int64){}
    private var consumed = 0
    public func next(): ?T {
        synchronized(lock) {
            if(consumed >= size) {
                return None<T>
            }
            consumed++
            itr.next()
        }
    }
}