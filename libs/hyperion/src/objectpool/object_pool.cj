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

package hyperion.objectpool

/** 
 * 接口：对象池
 *
 * @author yangfuping
 */
public interface ObjectPool<T> where T <: Hashable & Equatable<T> {

    /**
     * 初始化对象池
     * @throws PoolException
     */
    func initialize(): Unit

    /**
     * 往对象池中添加实例
     * @throws PoolException
     */
    func addObject(): Unit

    /**
     * 往对象池中添加指定数量的实例
     *
     * @param count
     * @throws PoolException
     */
    func addObject(count: Int64): Unit

    /**
     * 从对象池中借出实例
     *
     * @throws PoolException
     */
    func borrowObject(): T

    /**
     * 归还实例到对象池中
     *
     * @param obj
     * @throws PoolException
     */
    func returnObject(obj: T): Unit

    /**
     * 从对象池中销毁指定实例
     *
     * @param obj
     * @throws PoolException
     */
    func invalidateObject(obj: T): Unit

    /**
     * 从对象池中销毁所有实例
     *
     * @param obj
     * @throws PoolException
     */
    func invalidateAll(): Unit

    /**
     * @throws PoolException
     */
    func close(): Unit
}
