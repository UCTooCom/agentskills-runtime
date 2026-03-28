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
package f_util

import std.collection.ArrayList
import std.collection.HashMap

public interface TreeNode<ID, T> where ID <: Hashable & Equatable<ID>, T <: Object & TreeNode<ID, T> {
    prop children: ArrayList<T>
    func addChild(child: T): Unit {
        children.add(child)
    }

    func addChildren(children: Iterable<T>) {
        for (ch in children) {
            addChild(ch)
        }
    }
    func addChildren(children: Array<T>) {
        let itr: Iterable<T> = children
        addChildren(itr)
    }
    prop id: ID
    prop parentId: ID

    static func transform<S>(iterable: Iterable<S>, emptyId: ID, ignoreDuplicate: Bool, transferFn: (S) -> ?T): ArrayList<T> {
        let map = HashMap<ID, T>()
        let root = ArrayList<T>()
        let list = ArrayList<T>()
        for (s in iterable) {
            let t = transferFn(s).getOrThrow {
                IllegalArgumentException("There is some element in arg iterable which cannot be transformed into T")
            }
            if (map.add(t.id, t).isNone()) {
                list.add(t)
            } else if (!ignoreDuplicate) {
                throw IllegalArgumentException("Some elements are duplicate which are transformed from arg iterable.")
            }
        }
        for (t in list) {
            let parentId = t.parentId
            if (parentId == emptyId) {
                root.add(t)
            } else {
                map[parentId].addChild(t)
            }
        }
        return root
    }
    static func transform<S>(iterable: Iterable<S>, emptyId: ID, transferFn: (S) -> ?T): ArrayList<T> {
        transform<S>(iterable, emptyId, false, transferFn)
    }
    static func transform<S>(iterable: Iterable<S>, emptyId: ID) {
        transform<S>(iterable, emptyId, false)
    }
    static func transform<S>(iterable: Iterable<S>, emptyId: ID, ignoreDuplicate: Bool) {
        transform<S>(iterable, emptyId, ignoreDuplicate) {s => s as T}
    }
}
