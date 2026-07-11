/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq4cj.client.util

public class IntrospectionSupport {

    /**
     * 找到有指定前缀的name，并将前缀移除
     */
    public static func extractProperties<T>(props: HashMap<String, T>, optionPrefix: String): HashMap<String, T> {
        let rc = HashMap<String, T>()
        let iterator = HashMapIterator(props)
        while (true) {
            let next: Option<(String, T)> = iterator.next()
            match (next) {
                case Some((k, v)) =>
                    if (k.startsWith(optionPrefix)) {
                        let name = k[optionPrefix.size..k.size]
                        rc[name] = v
                        iterator.remove()
                    }
                case None => break
            }
        }
        return rc
    }

    /**
     * 利用反射设置object成员变量的值
     */
    public static func setProperties(target: Any, props: HashMap<String, Any>, optionPrefix: String): Unit {
        let info = TypeInfo.of(target)
        let deletetKeys = LinkedList<String>()
        for ((k, v) in props) {
            if (k.startsWith(optionPrefix)) {
                let name = k[optionPrefix.size..k.size]
                //找不到成员变量的话跳过继续设置其他变量
                try {
                    let instancePropertyInfo = info.getInstanceProperty(name)
                    instancePropertyInfo.setValue(
                        target,
                        TypeConversionSupport.convert(v, instancePropertyInfo.typeInfo)
                    )
                    deletetKeys.addLast(k)
                } catch (ex: InfoNotFoundException) {
                }
            }
        }
        props.remove(all: deletetKeys)
    }

    public static func setProperties(target: Any, props: HashMap<String, Any>): Unit {
        let info = TypeInfo.of(target)
        let deletetKeys = LinkedList<String>()
        for ((k, v) in props) {
            try {
                let instancePropertyInfo = info.getInstanceProperty(k)
                instancePropertyInfo.setValue(target, TypeConversionSupport.convert(v, instancePropertyInfo.typeInfo))
                deletetKeys.addLast(k)
            } catch (ex: InfoNotFoundException) {
            }
        }
        props.remove(all: deletetKeys)
    }
}
