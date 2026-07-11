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

package hyperion.transport.server

/**
 *
 * @author yangfuping
 */
public open class EndpointConfig <: TcpSocketOptions {
    //监听地址
    private var addressVal: String = "0.0.0.0"

    public mut prop address: String {
        get() {
            addressVal
        }
        set(v) {
            this.addressVal = v
        }
    }

    //Backlog
    private var backlogSizeVal: ?Int64 = None

    public mut prop backlogSize: ?Int64 {
        get() {
            backlogSizeVal
        }
        set(v) {
            this.backlogSizeVal = v
        }
    }

    //SO_REUSE_ADDR
    private var reuseAddressVal: ?Bool = None

    public mut prop reuseAddress: ?Bool {
        get() {
            reuseAddressVal
        }
        set(v) {
            this.reuseAddressVal = v
        }
    }

    //SO_REUSE_PORT
    private var reusePortVal: ?Bool = None

    public mut prop reusePort: ?Bool {
        get() {
            reusePortVal
        }
        set(v) {
            this.reusePortVal = v
        }
    }

    // 接收Socket超时时间
    private var acceptTimeoutVal: ?Duration = None

    public mut prop acceptTimeout: ?Duration {
        get() {
            acceptTimeoutVal
        }
        set(v) {
            this.acceptTimeoutVal = v
        }
    }
}

/**
 *
 * @author yangfuping
 */
public open class TcpEndpoint <: AbstractEndPoint & Runnable {
    private static let logger = LoggerFactory.getLogger("transport")

    private let endpointConfig: EndpointConfig

    private var serverSocket: ?ServerSocket = None

    private var acceptTimeout: Duration = 30 * Duration.second

    private var connInitializer: ?ConnectionInitializer = None

    public init(endpointConfig: EndpointConfig, threadPool: ThreadPool) {
        super(threadPool)
        this.endpointConfig = endpointConfig
    }

    public func start() {
        initEndPoint()
        threadPool.addTask(this)
    }

    public func run() {
        while (running) {
            handleAccept()
        }
    }

    /**
     * @throws IOException
     */
    private func initEndPoint() {
        try {
            let allocateSize = endpointConfig.bufferAllocateSize
            var bufferAllocator = ArrayByteBufferAllocator(allocateSize, false)
            if (endpointConfig.usePooledBufferAllocator) {
                bufferAllocator = PooledArrayByteBufferAllocator(
                    allocateSize,
                    endpointConfig.maxPooledBuffers
                )
            }
            this.ioFilterChain.setBufferAllocator(bufferAllocator)

            if (let Some(timeout) <- endpointConfig.acceptTimeout) {
                acceptTimeout = timeout
            } else {
                if (let Some(timeout) <- endpointConfig.readTimeout) {
                    acceptTimeout = timeout
                }
            }

            let bindAdress = IPSocketAddress(endpointConfig.address, endpointConfig.port)

            let endpoint = TcpServerSocket(bindAt: bindAdress)
            this.configServerSocketOptions(endpoint)
            endpoint.bind()

            serverSocket = endpoint
        } catch (ex: IOException) {
            logger.log(LogLevel.ERROR, ex.message, ex)
            throw ex
        } catch (ex: SocketException) {
            logger.log(LogLevel.ERROR, ex.message, ex)
            throw ex
        }
    }

    private func handleAccept() {
        try {
            if (let Some(endpoint) <- serverSocket) {
                let socket = endpoint.accept(timeout: acceptTimeout)

                if (let Some(tcpSocket) <- (socket as TcpSocket)) {
                    SocketConnection.configSocketOptions(tcpSocket, endpointConfig)
                }

                if (!running) {
                    return
                }

                let tcpConnection = SocketConnection(socket)
                tcpConnection.config(endpointConfig)

                let session = DefaultIoSession(tcpConnection, filterChain)
                if (endpointConfig.stickyRead) {
                    let handler = StickyReadInboudOutboundHandler(threadPool, filterChain.getBufferAllocator(), session)
                    handler.setMaxMessageSizeInBytes(endpointConfig.maxMessageSizeInBytes)
                    handler.setExecOnReadThread(endpointConfig.execOnReadThread)
                    spawn {
                        Thread.currentThread.name = "ReadLoop-${tcpConnection.simpleName()}"
                        handler.run()
                    }
                } else {
                    let handler = SimpleInboudOutboundEventLoopHandler(threadPool, filterChain.getBufferAllocator(),
                        session)
                    handler.setSliceExceedBuffer(endpointConfig.sliceExceedBuffer)
                    handler.setMaxMessageSizeInBytes(endpointConfig.maxMessageSizeInBytes)
                    threadPool.addTask(handler)
                }

                if (let Some(initializer) <- connInitializer) {
                    initializer.initialize(session)
                }
            }
        } catch (soTimeoutEx: SocketTimeoutException) {
            if (logger.isLoggable(LogLevel.DEBUG)) {
                logger.log(LogLevel.DEBUG, soTimeoutEx.message, soTimeoutEx)
            }
        }
    }

    private func configServerSocketOptions(serverSocket: TcpServerSocket) {
        if (let Some(backlogSize) <- endpointConfig.backlogSize) {
            if (backlogSize > 0) {
                serverSocket.backlogSize = backlogSize
            }
        }

        if (let Some(reuseAddress) <- endpointConfig.reuseAddress) {
            serverSocket.reuseAddress = reuseAddress
        }

        if (let Some(reusePort) <- endpointConfig.reusePort) {
            serverSocket.reusePort = reusePort
        }
    }

    /**
     * 关闭ServerSocket和线程池
     */
    public func stop() {
        super.stop()

        if (let Some(endpoint) <- serverSocket) {
            endpoint.close()
        }
    }
}
