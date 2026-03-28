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
package f_log

import std.collection.concurrent.ConcurrentHashMap
import std.reflect.TypeInfo
import stdx.log.Attr
import f_base.*
import f_collection.*

internal let globalAttrMap = ConcurrentHashMap<String, Array<Attr>>()

public class LoggerFactory {
    private static let loggers = ConcurrentHashMap<String, LoggerWrapper>()

    private init() {}

    /**
     * name和attrs一一对应，如果在不同的代码用相同的名字，请务必确保attrs一致，否则只保留每一个名称最后一次调用的attrs。
     */
    public static func getLogger(name: String, attrs: Array<Attr>): AbstractLogger {
        if (!attrs.isEmpty()) {
            globalAttrMap[name] = attrs
        }
        loggers.computeIfAbsent(name){
            LoggerWrapper(name)
        }
    }
    /**
     * 把泛型O的全限定名作为日志实例的唯一标识
     */
    public static func getLogger<O>(attrs: Array<Attr>): AbstractLogger {
        getLogger(TypeInfo.of<O>(), attrs)
    }
    /**
     * 把typeInfo的全限定名作为日志实例的唯一标识
     */
    public static func getLogger(typeInfo: TypeInfo, attrs: Array<Attr>): AbstractLogger {
        getLogger('std.reflect.TypeInfo.get("${typeInfo.qualifiedName}")', attrs)
    }
    public static func refresh() {
        for ((_, w) in loggers) {
            w.refresh()
        }
    }
}
