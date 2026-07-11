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
 * 用于注册回调逻辑
 *
 * @author yangfuping
 */
public interface WriteActionListener {
    func beforeWrite(): Unit
}

/**
 * 跟踪写数据操作是否成功。
 *
 * 每个请求使用一个单独的WriteBeforePromise，不能多请求共享使用。
 *
 * @author yangfuping
 */
public open class WriteBeforePromise {

    // 针对只需要一个WriteActionListener的场景的优化
    private var firstListener: ?WriteActionListener = None

    private var listeners: ?LinkedList<WriteActionListener> = None

    private let calledBeforeWrite = AtomicBool(false)

    /*
     * 添加写之前的回调器
     */
    public func addWriteActionListener(listener: WriteActionListener): Unit {
        if (firstListener.isNone()) {
            // 针对只需要一个WriteActionListener的场景的优化, 不需要使用数组
            firstListener = listener
            return
        }

        getListeners().addLast(listener)
    }

    private func getListeners(): LinkedList<WriteActionListener> {
        if (let Some(listeners) <- listeners) {
            return listeners
        } else {
            let listeners = LinkedList<WriteActionListener>()
            this.listeners = listeners
            return listeners
        }
    }

    /**
     * 写入之前回调
     */
    public func beforeWrite(): Unit {
        if (let Some(firstListener) <- this.firstListener) {
            // 因每个请求使用一个单独的WritePromise，不能多请求共享使用，应避免重复调用callback
            if (calledBeforeWrite.compareAndSwap(false, true)) {
                firstListener.beforeWrite()

                if (let Some(listeners) <- this.listeners) {
                    for (listener in listeners) {
                        listener.beforeWrite()
                    }
                }
            }
        }
    }
}

/**
 * 为已经依赖了WritePromise类的程序保留编译时兼容性
 *
 * @author yangfuping
 */
public class WritePromise <: WriteBeforePromise {}
