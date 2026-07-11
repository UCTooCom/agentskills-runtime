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
package activemq4cj.client.transport

public class TcpTransport <: TransportListener & Transport {
    protected let location: URL
    protected let wireFormat: WireFormat
    private var endpoint: ?ClientTcpEndpoint = None
    private var transportListenerVal: ?TransportListener = None
    private var threadPoolConfig: ThreadPoolConfig

    protected let socketBufferSize: Int64 = 64 * 1024

    private let started = AtomicBool(false)
    private let closed = AtomicBool(false)

    public init(wf: WireFormat, location: URL, threadPoolConfig: ThreadPoolConfig) {
        this.wireFormat = wf
        this.location = location
        this.threadPoolConfig = threadPoolConfig
        var tcpNoDelay = true
        if (wf is OpenWireFormat) {
            if (let Some(tcpNoDelayEnabled) <- location.queryForm.get("wireFormat.tcpNoDelayEnabled")) {
                tcpNoDelay = Bool.parse(tcpNoDelayEnabled)
            }
        }
        let endpoint = buildClientEndpoint(tcpNoDelay)
        configEndpoint(endpoint)
        this.endpoint = endpoint
    }

    private func configEndpoint(tcpEndpoint: ClientTcpEndpoint) {
        // ActiveMQCodec
        let encoder = ActiveMQCommandToByteEncoder(wireFormat)
        let decoder = ByteToActiveMQCommandDecoder(wireFormat)
        let activemqCodec = ActiveMQCodec(encoder, decoder)

        tcpEndpoint.setMessageCompletedHandler(wireFormat)
        tcpEndpoint.addFilter(activemqCodec)
        let handler = ActiveMQCommandHandler()
        //设置侦听器，handler收到服务端命令后会交给listener的onCommand方法处理
        handler.setTransportListener(this)
        tcpEndpoint.addFilter(handler)
    }

    private func buildClientEndpoint(noDelay: Bool): ClientTcpEndpoint {
        let config = ClientEndpointConfig()
        var hostName = location.hostName
        if (hostName == "localhost") {
            hostName = "127.0.0.1"
        }
        config.host = hostName
        config.asyncWrite = false

        var port: String = location.port
        if (!port.isEmpty()) {
            config.port = UInt16.parse(port)
        } else {
            config.port = 61616
        }

        config.noDelay = noDelay
        config.receiveBufferSize = this.socketBufferSize
        if (let Some(tlsClientConfig) <- TlsContext.getCurrent()) {
            config.tlsEnabled = true
            config.tlsClientConfig = tlsClientConfig
        }
        let threadPool = ThreadPoolFactory.createThreadPool(this.threadPoolConfig)
        let tcpEndpoint = ClientTcpEndpoint(config, threadPool)
        return tcpEndpoint
    }

    /**
     * 侦听服务端发送的响应命令
     */
    public func onCommand(command: Command): Unit {
        if (let Some(transportListener) <- this.transportListener) {
            transportListener.onCommand(command)
        }
    }

    /**
     * 所有命令最终从这里发送出去，后续会经过编解码器
     */
    public override func oneway(command: Command): Unit {
        checkOpen()
        var needCloseSession: ?Session = None<Session>
        try {
            if (let Some(endpoint) <- this.endpoint) {
                let session = endpoint.createSession()
                session.writeAndFlushMessage(command)
                needCloseSession = session
            }
        } catch (ex: TransportException) {
            throw ex
        } finally {
            if (let Some(session) <- needCloseSession) {
                session.close()
            }
        }
    }

    public func asyncRequest(command: Command, responseCallback: ?(FutureResponse) -> Unit): FutureResponse {
        throw UnsupportedException("Unsupported operation: asyncRequest(command, responseCallback)")
    }

    public override func request(command: Command): ?Response {
        throw UnsupportedException("Unsupported operation: request(command)")
    }

    public override func request(command: Command, timeout: Duration): ?Response {
        throw UnsupportedException("Unsupported operation: request(command, timeout)")
    }

    public mut prop transportListener: ?TransportListener {
        get() {
            return this.transportListenerVal
        }
        set(value) {
            this.transportListenerVal = value
        }
    }

    public prop faultTolerant: Bool {
        get() {
            return false
        }
    }

    public prop disposed: Bool {
        get() {
            return isClosed()
        }
    }

    public override func updateURLs(rebalance: Bool, urls: Array<String>): Unit {
        throw UnsupportedException("Unsupported operation: updateURLs")
    }

    private func checkOpen(): Unit {
        if (isClosed()) {
            throw ActiveMQException("Client is already closed")
        }
    }

    public override func onException(e: TransportException) {
        if (let Some(listener) <- this.transportListener) {
            listener.onException(e)
        }
    }

    public func transportInterupted(): Unit {
        if (let Some(transportListener) <- transportListener) {
            transportListener.transportInterupted()
        }
    }

    public func transportResumed(): Unit {
        if (let Some(transportListener) <- transportListener) {
            transportListener.transportResumed()
        }
    }

    public override func narrow(target: TypeInfo): Any {
        if (ClassTypeInfo.of(this).isSubtypeOf(target)) {
            return this
        }
        return Option<Transport>.None
    }

    public func isClosed(): Bool {
        return closed.load()
    }

    public func start() {
        if (started.compareAndSwap(false, true)) {
            if (let Some(endpoint) <- endpoint) {
                endpoint.start()
            }
        }
    }

    public func stop() {
        if (closed.compareAndSwap(false, true)) {
            if (let Some(endpoint) <- endpoint) {
                endpoint.stop()
            }
        }
    }

    public override func toString(): String {
        return "TcpTransport"
    }
}
