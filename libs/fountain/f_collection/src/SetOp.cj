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

internal import std.collection.{ReadOnlySet, Set, HashSet, TreeSet}

public interface SetOp<T> {
    func intersection<C>(collection: C): Set<T> where C <: Collection<T>
    func union<C>(collection: C): Set<T> where C <: Collection<T>
    func difference<C>(collection: C): Set<T> where C <: Collection<T>
}
extend<T> HashSet<T> <: SetOp<T> where T <: Hashable & Equatable<T> {
    public func intersection<C>(collection: C): Set<T> where C <: Collection<T>{
        IntersectionSetView<T, C>(this, HashSet<T>(collection))
    }
    public func union<C>(collection: C): Set<T> where C <: Collection<T>{
        UnionSetView<T, C>(this, HashSet<T>(collection))
    }
    public func difference<C>(collection: C): Set<T> where C <: Collection<T>{
        DifferenceSetView<T, C>(this, HashSet<T>(collection))
    }
}
extend<T> LinkedHashSet<T> <: SetOp<T> where T <: Hashable & Equatable<T> {
    public func intersection<C>(collection: C): Set<T> where C <: Collection<T>{
        IntersectionSetView<T, C>(this, LinkedHashSet<T>(collection))
    }
    public func union<C>(collection: C): Set<T> where C <: Collection<T>{
        UnionSetView<T, C>(this, LinkedHashSet<T>(collection))
    }
    public func difference<C>(collection: C): Set<T> where C <: Collection<T>{
        DifferenceSetView<T, C>(this, LinkedHashSet<T>(collection))
    }
}
extend<T> TreeSet<T> <: SetOp<T> where T <: Comparable<T> {
    public func intersection<C>(collection: C): Set<T> where C <: Collection<T>{
        IntersectionSetView<T, C>(this, TreeSet<T>(collection))
    }
    public func union<C>(collection: C): Set<T> where C <: Collection<T>{
        UnionSetView<T, C>(this, TreeSet<T>(collection))
    }
    public func difference<C>(collection: C): Set<T> where C <: Collection<T>{
        DifferenceSetView<T, C>(this, TreeSet<T>(collection))
    }
}