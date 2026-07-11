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
package activemq4cj.cjms

public interface XAResource {

    /**
     * 提交xid指定的全局事务
     */
    func commit(xid: Xid, onePhase: Bool): Unit

    /**
     * 结束代表事务分支执行的工作
     */
    func end(xid: Xid, flags: Bool): Unit

    /**
     * 告诉资源管理器忘记启发式完成的事务分支
     */
    func forget(xid: Xid): Unit

    /**
     * 获取为此XAResource实例设置的当前事务超时值
     */
    func getTransactionTimeout(): Int32

    /**
     * 调用此方法以确定目标对象表示的资源管理器实例是否与参数xares表示的资源管理器实例相同
     */
    func isSameRM(xares: XAResource): Bool

    /**
     * 请资源管理器准备xid中指定的事务的事务提交
     */
    func prepare(xid: Xid): Int32

    /**
     * 从资源管理器获取准备好的事务分支列表
     */
    func recover(flag: Int32): Array<Xid>

    /**
     * 通知资源管理器回滚代表事务分支完成的工作
     */
    func rollback(xid: Xid): Unit

    /**
     * 设置此XAResource实例的当前事务超时值
     */
    func setTransactionTimeout(seconds: Int32): Bool

    /**
     * 代表 xid指定的事务分支开始工作
     */
    func start(xid: Xid, flags: Int32): Unit
}
