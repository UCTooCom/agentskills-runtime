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
 * 客户端Socket连接封装，支持池化
 *
 * @author yangfuping
 */
public class ClientSocketConnection <: SocketConnection {
    private let connectionPool: ?ObjectPool<Connection>

    public init(socket: StreamingSocket) {
        super(socket)
        this.connectionPool = None
    }

    public init(connectionPool: ObjectPool<Connection>, socket: StreamingSocket) {
        super(socket)
        this.connectionPool = connectionPool
    }

    public func close() {
        if (let Some(connectionPool) <- connectionPool) {
            if (!isInvalid() && !isClosed()) {
                // 连接仍为有效状态，归还到连接池
                connectionPool.returnObject(this)
                return
            }
        }

        // 真正关闭连接
        super.internalClose()
    }

    public open func close(markInvalid!: Bool): Unit {
        super.close(markInvalid: markInvalid)

        if (let Some(connectionPool) <- connectionPool) {
            if (markInvalid) {
                // 从连接池中移除连接
                connectionPool.invalidateObject(this)
            }
        }
    }
}
