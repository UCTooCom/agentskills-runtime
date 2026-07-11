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

public interface Connection <: Resource {
    mut prop exceptionListener: ?ExceptionListener

    /**
     * 用给定的确认模式创建一个Session
     */
    func createSession(ackMode: AcknowledgeMode): Session

    /**
     * 用给定的确认模式创建一个Session
     */
    func createSession(transacted: Bool, ackMode: AcknowledgeMode): Session

    /**
     * 创建AUTO_ACKNOWLEDGE Session.
     */
    func createSession(): Session

    /**
     * 获取此会话的clientId
     */
    func getClientID(): ?String

    /**
     * 给连接的客户端分配唯一的标识符
     */
    func setClientID(client: String): Unit

    /**
     * 获取此连接的元数据
     */
    func getMetaData(): ConnectionMetaData

    /**
     * connection刚创建时，处于stopped mode，收不到消息，调用start后，消息可以到达连接的消费者。
     * start或者stop只影响消息的接收，不影响使用connection发送消息
     */
    func start(): Unit

    func stop(): Unit
}
