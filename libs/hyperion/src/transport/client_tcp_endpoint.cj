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
 * 客户端特有的配置
 *
 * @author yangfuping
 */
public open class ClientEndpointConfig <: TcpSocketOptions {
    // 服务端监听地址
    private var hostVal: String = "127.0.0.1"

    private var tlsEnabledVal: Bool = false

    private var tlsClientConfigVal: ?TlsClientConfig = None

    public mut prop tlsClientConfig: ?TlsClientConfig {
        get() {
            return tlsClientConfigVal
        }
        set(value) {
            this.tlsClientConfigVal = value
        }
    }

    public mut prop tlsEnabled: Bool {
        get() {
            return tlsEnabledVal
        }
        set(value) {
            this.tlsEnabledVal = value
        }
    }

    public mut prop host: String {
        get() {
            hostVal
        }
        set(v) {
            this.hostVal = v
        }
    }

    private var minConnectionsVal = 0

    public mut prop minConnections: Int64 {
        get() {
            minConnectionsVal
        }
        set(v) {
            this.minConnectionsVal = v
        }
    }

    private var maxConnectionsVal = 1

    public mut prop maxConnections: Int64 {
        get() {
            maxConnectionsVal
        }
        set(v) {
            this.maxConnectionsVal = v
        }
    }

    private var waitConnectionTimeoutVal: Duration = Duration.second * 30

    public mut prop waitConnectionTimeout: Duration {
        get() {
            return waitConnectionTimeoutVal
        }
        set(value) {
            this.waitConnectionTimeoutVal = value
        }
    }

    private var useNonExclusiveObjectPoolVal: Bool = false

    public mut prop useNonExclusiveObjectPool: Bool {
        get() {
            return useNonExclusiveObjectPoolVal
        }
        set(value) {
            this.useNonExclusiveObjectPoolVal = value
        }
    }

    private var evictionIntervalsVal: Duration = Duration.second * 10

    public mut prop evictionIntervals: Duration {
        get() {
            return evictionIntervalsVal
        }
        set(value) {
            this.evictionIntervalsVal = value
        }
    }

    private var lifoVal: Bool = true

    public mut prop lifo: Bool {
        get() {
            return lifoVal
        }
        set(value) {
            this.lifoVal = value
        }
    }

    private var testOnCreateVal: Bool = false

    public mut prop testOnCreate: Bool {
        get() {
            return testOnCreateVal
        }
        set(value) {
            this.testOnCreateVal = value
        }
    }

    private var testOnBorrowVal: Bool = false

    public mut prop testOnBorrow: Bool {
        get() {
            return testOnBorrowVal
        }
        set(value) {
            this.testOnBorrowVal = value
        }
    }

    private var testOnReturnVal: Bool = false

    public mut prop testOnReturn: Bool {
        get() {
            return testOnReturnVal
        }
        set(value) {
            this.testOnReturnVal = value
        }
    }

    private var testWhileIdleVal: Bool = false

    public mut prop testWhileIdle: Bool {
        get() {
            return testWhileIdleVal
        }
        set(value) {
            this.testWhileIdleVal = value
        }
    }

    public func getPoolConfig(): PoolConfig {
        let poolConfig = PoolConfig()
        poolConfig.minActiveSize = minConnections
        poolConfig.maxActiveSize = maxConnections
        poolConfig.idleTimeout = idleTimeout
        poolConfig.borrowTimeout = waitConnectionTimeout
        poolConfig.lifo = lifo
        poolConfig.evictionIntervals = evictionIntervals
        poolConfig.testOnCreate = testOnCreate
        poolConfig.testOnBorrow = testOnBorrow
        poolConfig.testOnReturn = testOnReturn
        poolConfig.testWhileIdle = testWhileIdle

        return poolConfig
    }
}

/**
 * TCP客户端实现的入口类
 *
 * @author yangfuping
 */
public open class ClientTcpEndpoint <: AbstractEndPoint {
    protected static let logger = LoggerFactory.getLogger("transport")
    private let connectionConfig: ClientEndpointConfig
    private let connectionPool: ObjectPool<Connection>
    private let socketConnFactory: ClientSocketConnectionFactory
    private let initialized = AtomicBool(false)
    private let started = AtomicBool(false)

    public init(connectionConfig: ClientEndpointConfig, threadPool: ThreadPool) {
        super(threadPool)
        this.connectionConfig = connectionConfig
        this.socketConnFactory = ClientSocketConnectionFactory(connectionConfig, ioFilterChain, threadPool)
        this.connectionPool = getObjectPool(connectionConfig, socketConnFactory)
        this.socketConnFactory.setConnectionPool(connectionPool)
    }

    private static func getObjectPool(
        connectionConfig: ClientEndpointConfig,
        socketConnFactory: PooledObjectFactory<Connection>
    ): ObjectPool<Connection> {
        if (connectionConfig.useNonExclusiveObjectPool) {
            return NonExclusiveObjectPool<Connection>(connectionConfig.getPoolConfig(), socketConnFactory)
        } else {
            return GenericObjectPool<Connection>(connectionConfig.getPoolConfig(), socketConnFactory)
        }
    }

    public func setConnectionInitializer(connInitializer: ConnectionInitializer) {
        socketConnFactory.setConnectionInitializer(connInitializer)
    }

    public func createSession(): Session {
        if (isStoped()) {
            throw TransportException("Endpoint stoped")
        }

        if (!started.load()) {
            throw TransportException("The endpoint did not start yet, please call ClientTcpEndpoint::start first")
        }

        try {
            let conn = connectionPool.borrowObject()
            if (conn.isClosed()) {
                throw TransportException("Connection closed")
            }

            return DefaultSession(conn, filterChain)
        } catch (ex: Exception) {
            logger.error(ex.message, ex)
            if (let Some(transportEx) <- (ex as TransportException)) {
                throw transportEx
            }

            throw TransportException("Failure to create session, error: ${ex.message}", ex)
        }
    }

    public func invalidateConnectionPool() {
        connectionPool.invalidateAll()
    }

    public func start() {
        initEndPoint()
        started.compareAndSwap(false, true)
        return
    }

    /**
     * @throws IOException
     */
    private func initEndPoint() {
        if (initialized.compareAndSwap(false, true)) {
            let allocateSize = connectionConfig.bufferAllocateSize
            var bufferAllocator = ArrayByteBufferAllocator(allocateSize, false)
            if (connectionConfig.usePooledBufferAllocator) {
                bufferAllocator = PooledArrayByteBufferAllocator(
                    allocateSize,
                    connectionConfig.maxPooledBuffers
                )
            }

            this.filterChain.setBufferAllocator(bufferAllocator)
        }
    }

    public func getRemoteAddress(): String {
        return connectionConfig.host + ":" + connectionConfig.port.toString()
    }

    /**
     * 关闭客户端连接池和线程池
     */
    public func stop() {
        super.stop()

        connectionPool.close()
    }
}
