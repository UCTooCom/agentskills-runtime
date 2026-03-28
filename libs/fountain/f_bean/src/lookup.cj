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
package f_bean

import f_log.*

public func lookup<T>(): T {
    lookup<T>(StringCond.IgnoreCond)
}

public func lookup<T>(name: String): T {
    lookup<T>(Exactly(name))
}

public func lookup<T>(cond: StringCond): T {
    lookupOption<T>(cond).getOrThrow {
        BeanException('bean type ${TypeInfo.of<T>()} with bean name condition ${cond} does not exist.')
    }
}

public func lookupOption<T>(): ?T {
    lookupOption<T>(StringCond.IgnoreCond)
}

public func lookupOption<T>(name: String): ?T {
    lookupOption<T>(Exactly(name))
}

public func lookupOption<T>(cond: StringCond): ?T {
    BeanFactory.instance.getFirst<T>(cond: cond)
}

public func lookupList<T>(): ArrayList<T> {
    lookupList<T>(IgnoreCond)
}

public func lookupList<T>(cond: StringCond): ArrayList<T> {
    BeanFactory.instance.getList<T>(cond: cond)
}

public func lookupHashSet<T>(): HashSet<T> where T <: Hashable & Equatable<T> {
    lookupHashSet<T>(IgnoreCond)
}

public func lookupHashSet<T>(cond: StringCond): HashSet<T> where T <: Hashable & Equatable<T> {
    HashSet<T>(lookupList<T>(cond))
}

public func lookupTreeSet<T>(): TreeSet<T> where T <: Comparable<T> {
    lookupTreeSet<T>(IgnoreCond)
}

public func lookupTreeSet<T>(cond: StringCond): TreeSet<T> where T <: Comparable<T> {
    TreeSet<T>(lookupList<T>(cond))
}

public func lookupHashMap<T>(): HashMap<String, T> where T <: Object {
    lookupHashMap<T>(IgnoreCond)
}

public func lookupHashMap<T>(cond: StringCond): HashMap<String, T> where T <: Object {
    BeanFactory.instance.getMap<T>(cond: cond)
}

public func lookupLabels<L, T>(): HashMap<L, T> where L <: Hashable & Equatable<L>, T <: BeanLabel<L> {
    lookupLabels<L, T>(IgnoreCond)
}

public func lookupLabels<L, T>(cond: StringCond): HashMap<L, T> where L <: Hashable & Equatable<L>, T <: BeanLabel<L> {
    let map = HashMap<L, T>()
    for (bean in lookupList<T>(cond)) {
        map[bean.label] = bean
    }
    map
}

public func lookupWeights<W, T>(): TreeMap<W, T> where W <: Comparable<W> & Addable<W>, T <: BeanWeight<W> {
    lookupWeights<W, T>(IgnoreCond)
}

public func lookupWeights<W, T>(cond: StringCond): TreeMap<W, T> where W <: Comparable<W> & Addable<W>,
    T <: BeanWeight<W> {
    let map = TreeMap<W, T>()
    var weight = None<W>
    for (bean in lookupList<T>(cond)) {
        let w = if (let Some(w) <- weight) {
            w + bean.weight
        } else {
            bean.weight
        }
        weight = w
        map[w] = bean
    }
    map
}
