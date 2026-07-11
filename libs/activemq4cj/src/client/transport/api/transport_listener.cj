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
package activemq4cj.client.transport.api

public abstract class TransportListener <: CommandVisitorAdapter {

    /**
     * 服务端发回命令时执行此方法
     */
    public func onCommand(command: Command): Unit

    public func onException(error: TransportException): Unit

    /**
     * 连接中断
     */
    public func transportInterupted(): Unit

    /**
     * 连接从中断恢复
     */
    public func transportResumed(): Unit
}

public open class DefaultTransportListener <: TransportListener {
    public open func onCommand(command: Command): Unit {
    }

    public open func onException(error: TransportException): Unit {
    }

    public open func transportInterupted(): Unit {
    }

    public func transportResumed(): Unit {
    }
}
