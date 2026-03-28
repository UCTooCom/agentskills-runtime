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
package f_base

import std.collection.concurrent.ConcurrentHashMap
import std.sync.Mutex
public import std.reflect.TypeInfo
public import std.math.numeric.{BigInt, Decimal}
public import std.time.DateTime

// private class Types<T> {
//     static let INSTANCE = TypeInfo.of<T>()
//     private init(){}
// }
public class TypeInfos {
    private static let INFOS = ConcurrentHashMap<String, TypeInfo>()
    private static let MUTEX = Mutex()

    public static func get<T>(): TypeInfo {
        // Types<T>.INSTANCE
        //待支持静态成员再改回使用Types
        TypeInfo.of<T>()
    }
    public static func get(qualifiedName: String): TypeInfo {
        if (let Some(x) <- INFOS.get(qualifiedName)) {
            x
        } else {
            synchronized(MUTEX) {
                if (let Some(x) <- INFOS.get(qualifiedName)) {
                    x
                } else {
                    let info = TypeInfos.get(qualifiedName)
                    INFOS[qualifiedName] = info
                    info
                }
            }
        }
    }
    public static func getGenericTypes<T>(): Array<TypeInfo> {
        getGenericTypes(get<T>())
    }
    public static func getGenericTypes(info: TypeInfo): Array<TypeInfo> {
        getGenericTypes(info.qualifiedName)
    }
    public static func getGenericTypes(qualifiedName: String): Array<TypeInfo> {
        let idx = qualifiedName.indexOf("<")
        if (let Some(i) <- idx) {
            let generics = qualifiedName[i + 1 .. qualifiedName.size - 1]
            let types = parseParameterTypes(generics)
            types
        } else {
            []
        }
    }
    public static func isInstanceOf<T>(instance: Any): Bool {
        TypeInfo.of(instance).isSubtypeOf(get<T>())
    }
    public static func withAnnotation<T, A>(funcName: String, argTypes: Array<TypeInfo>): Bool where A <: Annotation {
        (TypeMemberInfos.instanceFunction(get<T>(), funcName, argTypes)?.findAnnotation<A>() ?? None).isSome()
    }
}

public interface SubTypeOf {
    func isSubtypeOf<S>(): Bool
}

extend TypeInfo <: SubTypeOf {
    public func isSubtypeOf<S>(): Bool {
        this.isSubtypeOf(TypeInfo.of<S>())
    }
}
