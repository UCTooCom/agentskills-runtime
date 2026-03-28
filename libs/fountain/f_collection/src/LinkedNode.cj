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

import f_exception.UnreachableException

public class LinkedNodeIterator<T> <: Iterator<T> {
    private let reversed: Bool
    private var node = None<ValueNode<T>>
    LinkedNodeIterator(private var current: Node<T>) {
        this.current = match (current) {
            case n: HeadNode<T> =>
                reversed = false
                n.next
            case n: TailNode<T> =>
                reversed = true
                n.prev
            case _ => throw UnreachableException()
        }
    }

    /**
     * 返回迭代过程中的下一个元素
     * 返回值 Option<E> - 迭代过程中的下一个元素
     */
    public func next(): Option<T> {
        match (current) {
            case n: ValueNode<T> =>
                node = n
                let val = n.value
                current = if (reversed) {
                    n.prev
                } else {
                    n.next
                }
                val
            case _ => 
                node = None<ValueNode<T>>
                None<T>
        }
    }
    /**
     * 删除当前节点
     */
    public func remove(): ?T {
        match(node){
            case Some(n) => 
                n.remove()
                n.value
            case _ => None<T>
        }
    }
}

public interface Node<T> {
    func insertPrev(value: T): ValueNode<T> {
        throw UnreachableException()
    }
    func insertNext(value: T): ValueNode<T> {
        throw UnreachableException()
    }
    func remove(): T {
        throw UnreachableException()
    }
    func removePrev(): Option<T> {
        throw UnreachableException()
    }
    func removeNext(): Option<T> {
        throw UnreachableException()
    }
}

public class NoneNode<T> <: Node<T> {
    static const func instance() {
        NoneNode<T>()
    }
    private const init() {}
}

public class HeadNode<T> <: Node<T> & Iterable<T> {
    var next: Node<T>
    let tail = TailNode<T>()
    init() {
        this.next = tail
        this.reset(tail)
    }
    public func insertNext(value: T): ValueNode<T> {
        ValueNode<T>(value, this)
    }
    public func removeNext(): Option<T> {
        match (this.next) {
            case n: ValueNode<T> => n.remove()
            case n: TailNode<T> => None<T>
            case _ => throw UnreachableException()
        }
    }
    public func reset(tail: TailNode<T>): Unit {
        tail.prev = this
        this.next = tail
    }
    public func iterator(): Iterator<T> {
        LinkedNodeIterator<T>(this)
    }
}

public class TailNode<T> <: Node<T> & Iterable<T> {
    TailNode(var prev!: Node<T> = NoneNode<T>.instance()) {}
    public func insertPrev(value: T): ValueNode<T> {
        ValueNode<T>(value, this)
    }
    public func removePrev(): Option<T> {
        match (this.prev) {
            case n: ValueNode<T> => n.remove()
            case n: HeadNode<T> => None<T>
            case _ => throw UnreachableException()
        }
    }
    public func iterator(): Iterator<T> {
        LinkedNodeIterator<T>(this)
    }
}

public class ValueNode<T> <: Node<T> {
    ValueNode(var value: T, var prev: Node<T>, var next: Node<T>) {
        match (next) {
            case n: TailNode<T> => n.prev = this
            case n: ValueNode<T> => n.prev = this
            case _: NoneNode<T> => ()
            case _ => throw UnreachableException()
        }
        match (prev) {
            case n: HeadNode<T> => n.next = this
            case n: ValueNode<T> => n.next = this
            case _: NoneNode<T> => ()
            case _ => throw UnreachableException()
        }
    }
    init(value: T, prev: HeadNode<T>) {
        this(value, prev, prev.next)
    }
    init(value: T, next: TailNode<T>) {
        this(value, next.prev, next)
    }
    public func remove(): T {
        match (this.prev) {
            case n: HeadNode<T> => n.next = this.next
            case n: ValueNode<T> => n.next = this.next
            case _ => throw UnreachableException()
        }
        match (this.next) {
            case n: TailNode<T> => n.prev = this.prev
            case n: ValueNode<T> => n.prev = this.prev
            case _ => throw UnreachableException()
        }
        this.prev = this // help GC
        this.next = this // help GC
        this.value
    }
    public func removeNext(): Option<T> {
        match (this.next) {
            case n: ValueNode<T> => n.remove()
            case n: TailNode<T> => None<T>
            case _ => throw UnreachableException()
        }
    }
    public func removePrev(): Option<T> {
        match (this.prev) {
            case n: ValueNode<T> => n.remove()
            case n: HeadNode<T> => None<T>
            case _ => throw UnreachableException()
        }
    }
    public func turnTo(node: HeadNode<T>): Unit {
        if (this.prev is HeadNode<T>) {
            return
        }
        remove()
        match (node.next) {
            case n: TailNode<T> =>
                n.prev = this
                this.next = n
            case n: ValueNode<T> =>
                n.prev = this
                this.next = n
            case _ => throw UnreachableException()
        }
        node.next = this
        this.prev = node
    }
    public func turnTo(node: TailNode<T>): Unit {
        if (this.next is TailNode<T>) {
            return
        }
        remove()
        match (node.prev) {
            case n: HeadNode<T> =>
                n.next = this
                this.prev = n
            case n: ValueNode<T> =>
                n.next = this
                this.prev = n
            case _ => throw UnreachableException()
        }
        node.prev = this
        this.next = node
    }
}
