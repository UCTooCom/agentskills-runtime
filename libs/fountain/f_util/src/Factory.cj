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

import std.collection.HashMap
import std.reflect.TypeInfo
import f_base.TypeInfos
import f_exception.{IllegalAccessException, TypeNotMatchException}

public interface Producer<A, O> {
    func produce(): O {
        throw IllegalAccessException("unimplemented")
    }
    func produce(arg: A): O {
        throw IllegalAccessException("unimplemented")
    }
}

public class Factory<A, O> {
    private let producers = HashMap<TypeInfo, Producer<A, O>>()

    public func assemble<T>(producer: Producer<A, O>): Unit {
        producers.add(TypeInfo.of<T>(), producer)
    }
    public func assemble<T>(producers: Iterable<Producer<A, O>>): Unit {
        for (producer in producers) {
            assemble<T>(producer)
        }
    }
    private func convert<T>(o: O): T {
        match(o){
            case x: T => x
            case _ => throw TypeNotMatchException('${TypeInfo.of<T>()} must be subtype of ${TypeInfo.of<O>()}')
        }
    }
    public func produce<T>(): T {
        convert<T>(producers[TypeInfo.of<T>()].produce())
    }
    public func produce<T>(arg: A): T {
        convert<T>(producers[TypeInfo.of<T>()].produce(arg))
    }
}
