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

package hyperion.transport

/**
 * 记录ReadCompletionListener的处理结果。
 *
 * 非线程安全。需要多线程同时操作的属性应记录到Session中
 * 
 * @author yangfuping
 */
public class ReadCompletion {
    private let attributes = HashMap<String, Any>()

    public func getAttribute(name: String): ?Any {
        return attributes.get(name)
    }

    public func setAttribute(name: String, value: Any): Unit {
        attributes.add(name, value)
    }
}

/**
  * 用于注册回调逻辑。
  *
  * 多个请求会复用该ReadCompletionListener，每个请求将处理的结果记录到ReadCompletion中。
  */
public interface ReadCompletionListener {
    func afterRead(completion: ReadCompletion): Unit
}

/**
 * 处理ReadCompletionListener回调的Handler，每个连接只能至多配置一个。
 */
public class ReadCompletionHandler {
    private let listeners = LinkedList<ReadCompletionListener>()

    /*
     * 添加读完报文之后的回调器
     */
    public func addListener(listener: ReadCompletionListener): Unit {
        listeners.addLast(listener)
    }

    /**
     * 读完报文之后回调
     */
    public func readCompletion(): ReadCompletion {
        let completion: ReadCompletion = ReadCompletion()
        if (listeners.size > 0) {
            for (listener in listeners) {
                listener.afterRead(completion)
            }
        }

        return completion
    }
}
