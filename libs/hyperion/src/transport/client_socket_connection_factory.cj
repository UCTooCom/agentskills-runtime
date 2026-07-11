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
 * 创建ClientSocketConnection的工厂
 *
 * @author yangfuping
 */
public class ClientSocketConnectionFactory <: PooledObjectFactory<Connection> {
    private let socketOptions: ClientEndpointConfig

    private let ioFilterChain: IoFilterChain

    private let threadPool: ThreadPool

    private var connectionPool: ?ObjectPool<Connection> = None

    private var connInitializer: ?ConnectionInitializer = None

    public init(socketOptions: ClientEndpointConfig, ioFilterChain: IoFilterChain, threadPool: ThreadPool) {
        this.socketOptions = socketOptions
        this.ioFilterChain = ioFilterChain
        this.threadPool = threadPool
    }

    public func setConnectionPool(connectionPool: ObjectPool<Connection>) {
        this.connectionPool = connectionPool
    }

    public func setConnectionInitializer(connInitializer: ConnectionInitializer) {
        this.connInitializer = connInitializer
    }

    /*
     * 创建缓存的对象实例
     * @throws PoolException
     */
    public func createObject(): PooledObject<Connection> {
        let conn = createConnection()
        let pooledObj = PooledObject<Connection>(conn)
        return pooledObj
    }

    /**
     * 创建Socket连接
     */
    private func createConnection(): Connection {
        let ipAddress = resolveIpAddress(socketOptions.host)
        let address = IPSocketAddress(ipAddress, socketOptions.port)
        return createConnection(address)
    }

    private func createConnection(address: IPSocketAddress): Connection {
        try {
            let socket = createSocket(address)

            let conn: Connection
            if (let Some(connectionPool) <- connectionPool) {
                conn = ClientSocketConnection(connectionPool, socket)
            } else {
                conn = ClientSocketConnection(socket)
            }
            conn.config(socketOptions)

            let session = DefaultIoSession(conn, ioFilterChain)
            if (socketOptions.stickyRead) {
                let handler = StickyReadInboudHandler(threadPool, ioFilterChain.getBufferAllocator(), session)
                handler.setMaxMessageSizeInBytes(socketOptions.maxMessageSizeInBytes)
                handler.setExecOnReadThread(socketOptions.execOnReadThread)
                spawn {
                    Thread.currentThread.name = "ReadLoop-${conn.simpleName()}"
                    handler.run()
                }
            } else {
                let handler = SimpleInboudEventLoopHandler(threadPool, ioFilterChain.getBufferAllocator(), session)
                handler.setSliceExceedBuffer(socketOptions.sliceExceedBuffer)
                handler.setMaxMessageSizeInBytes(socketOptions.maxMessageSizeInBytes)
                threadPool.addTask(handler)
            }

            if (let Some(initializer) <- connInitializer) {
                initializer.initialize(session)
            }

            return conn
        } catch (ex: Exception) {
            if (ex is PoolException) {
                throw ex
            }
            throw PoolException("Failure to create connection to ${address}, error: ${ex.message}", ex)
        }
    }

    private func createSocket(address: SocketAddress): StreamingSocket {
        let tcpSocket = TcpSocket(address)
        tcpSocket.connect(timeout: Duration.second * 5)
        SocketConnection.configSocketOptions(tcpSocket, socketOptions)
        if (!socketOptions.tlsEnabled) {
            return tcpSocket
        }

        if (let Some(config) <- socketOptions.tlsClientConfig) {
            try {
                let tls = TlsSocket.client(tcpSocket, session: None, clientConfig: config)
                tls.handshake()
                return tls
            } catch (ex: TlsException) {
                tcpSocket.close()
                throw PoolException("Failure to create tls connection to ${address}, error: ${ex.message}", ex)
            }
        } else {
            throw PoolException("Failure to create tls connection to ${address}, should provide tlsClientConfig")
        }
    }

    private func resolveIpAddress(host: String): IPAddress {
        if (let Some(ipAddress) <- IPAddress.tryParse(host)) {
            return ipAddress
        }

        let ipAddresses = IPAddress.resolve(host)
        if (ipAddresses.size > 1) {
            return ipAddresses[0]
        }

        throw PoolException("Failure to resolve IPAddress for ${host}")
    }

    /*
     * 验证缓存的对象实例
     */
    public func validObject(pooledObj: PooledObject<Connection>): Bool {
        let conn = pooledObj.value
        if (conn.isInvalid() || conn.isClosed()) {
            return false
        }

        return true
    }

    /*
     * 销毁缓存的对象实例
     * @throws PoolException
     */
    public func destoryObject(pooledObj: PooledObject<Connection>): Unit {
        let conn = pooledObj.value
        conn.markInvalid()
        if (!conn.isClosed()) {
            conn.close()
        }
    }
}
