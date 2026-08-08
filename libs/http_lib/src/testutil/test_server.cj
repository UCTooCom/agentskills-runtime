package http_lib.testutil
/**
 * TestServer：HTTP 测试服务器。
 * 用于集成测试，启动本地 HTTP 服务器处理请求并验证响应。
 */

import std.net.{TcpServerSocket, TcpSocket}
import std.random.Random
import std.time.DateTime
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.router.Handler
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.{HttpStatus, HttpHeaders}
import http_lib.client.{HttpClient, HttpClientConfig}
import http_lib.connection.TlsConfig

/**
 * ResponseRecorder 测试响应记录器。
 *
 * 与基于 ResponseBuilder 的记录器不同，此记录器使用
 * (HttpRequest) -> HttpResponse 处理器签名，通过调用处理器并
 * 存储返回的 HttpResponse 以供后续检查。
 *
 * 用法：
 *   let handler = {req: HttpRequest => HttpResponse.text(HttpStatus.OK, "hello")}
 *   let recorder = ResponseRecorder(handler)
 *   recorder.serve(HttpRequest(url: "/test"))
 *   assertTrue(recorder.code() == 200u16)
 *   assertTrue(recorder.bodyAsString() == "hello")
 */
public class ResponseRecorder {
    /**
     * 已捕获的 HttpResponse，若尚未调用 serve() 或处理器抛出异常则为 None。
     */
    private var capturedResponse: ?HttpResponse = None

    /**
     * 若处理器在 serve() 期间抛出异常，此处存储该异常。
     */
    private var handlerError: ?Exception = None

    /**
     * 待测试的处理器。
     */
    private var handler: Handler

    public init(handler: Handler) {
        this.handler = handler
    }

    /**
     * 使用给定请求执行处理器并捕获响应。
     *
     * 若处理器抛出异常，该异常会被记录并可通过 getHandlerError() /
     * hasError() 获取。后续对 code()、bodyAsString() 等的调用
     * 将返回零值/空值，直到成功调用 serve() 为止。
     */
    public func serve(req: HttpRequest): Unit {
        capturedResponse = None
        handlerError = None
        try {
            let resp = handler(req)
            capturedResponse = Some(resp)
        } catch (e: Exception) {
            handlerError = Some(e)
        }
    }

    /**
     * 处理器返回的 HTTP 状态码，若尚未捕获响应（或处理器抛出异常）则为 0。
     */
    public func code(): UInt16 {
        match (capturedResponse) {
            case Some(resp) => resp.status.code
            case None => 0
        }
    }

    /**
     * 处理器返回的 HttpStatus 对象，或为 None。
     */
    public func status(): ?HttpStatus {
        match (capturedResponse) {
            case Some(resp) => Some(resp.status)
            case None => None
        }
    }

    /**
     * 处理器返回的响应头。
     * 若尚未捕获响应则返回空的 HttpHeaders。
     */
    public func headers(): HttpHeaders {
        match (capturedResponse) {
            case Some(resp) => resp.headers
            case None => HttpHeaders()
        }
    }

    /**
     * 以 UTF-8 字符串形式返回的响应体。
     * 若尚未捕获响应则返回空字符串。
     */
    public func bodyAsString(): String {
        match (capturedResponse) {
            case Some(resp) => resp.bodyAsString()
            case None => ""
        }
    }

    /**
     * 以原始字节形式返回的响应体。
     * 若尚未捕获响应则返回空数组。
     */
    public func bodyAsBytes(): Array<UInt8> {
        match (capturedResponse) {
            case Some(resp) => resp.bodyAsBytes()
            case None => []
        }
    }

    /**
     * 完整捕获的 HttpResponse，若尚未调用 serve() 或处理器
     * 抛出异常则为 None。
     */
    public func result(): ?HttpResponse {
        capturedResponse
    }

    /**
     * 是否已成功捕获响应。
     */
    public func hasResult(): Bool {
        match (capturedResponse) {
            case Some(_) => true
            case None => false
        }
    }

    /**
     * 若处理器在 serve() 期间抛出异常，返回被捕获的异常。
     */
    public func getHandlerError(): ?Exception {
        handlerError
    }

    /**
     * 处理器在 serve() 期间是否抛出了异常。
     */
    public func hasError(): Bool {
        match (handlerError) {
            case Some(_) => true
            case None => false
        }
    }
}

/**
 * 为给定处理器创建 ResponseRecorder。
 */
public func NewRecorder(handler: Handler): ResponseRecorder {
    ResponseRecorder(handler)
}

/**
 * 进程内 HTTP 测试服务器，使用真实的环回 TCP 连接。
 *
 * 在 127.0.0.1:<port> 上启动一个真实的 HTTP/1.1 服务器，
 * 通过短暂的启动延迟同步就绪状态，并提供预配置的
 * HttpClient 以供发送请求。
 *
 * 每个 TestServer 实例在构建时会探测并绑定到
 * 临时端口范围内的一个随机端口。
 *
 * TLS 支持：
 *   要创建 TLS 测试服务器，调用 NewTLSTestServer() 并传入
 *   已设置 serverCertPath 和 serverKeyPath 的 TlsConfig。
 *   自签名证书可通过 test/scripts/gen_cert.sh 或
 *   使用 OpenSSL 生成：
 *     openssl req -x509 -newkey rsa:2048 -keyout /tmp/key.pem \
 *       -out /tmp/cert.pem -days 365 -nodes \
 * -subj "/CN=localhost"
 */
public class TestServer {
    private var handler: Handler
    private var server: ?HttpServer = None
    private var portNum: UInt16 = 0
    private var started: Bool = false
    private var httpClient: ?HttpClient = None
    private var tlsConfig: ?TlsConfig = None
    private var useTls: Bool = false

    public init(handler: Handler) {
        this.handler = handler
    }

    /**
     * 获取服务器监听的端口。
     * 端口在首次访问时随机选择，通过向操作系统探测
     * 临时范围内的可用端口。
     */
    public func port(): UInt16 {
        if (portNum == 0) {
            portNum = probeAvailablePort()
        }
        portNum
    }

    /**
     * 使用给定配置为此测试服务器启用 TLS。
     * TlsConfig 必须设置 serverCertPath 和 serverKeyPath
     * 为有效的 PEM 文件。返回 this 以支持链式调用。
     *
     * 示例：
     *   let cfg = TlsConfig.default()
     *   cfg.serverCertPath = "/tmp/test_cert.pem"
     *   cfg.serverKeyPath = "/tmp/test_key.pem"
     *   let ts = TestServer(myHandler).withTls(cfg).start()
     */
    public func withTls(cfg: TlsConfig): TestServer {
        this.tlsConfig = Some(cfg)
        this.useTls = true
        this
    }

    /**
     * 启动服务器。生成一个后台线程运行 listenAndServe
     * （若配置了 TLS 则运行 listenAndServeTls）。
     * 调用方应在发送请求前等待服务器绑定并开始
     * 接受连接。
     */
    public func start(): TestServer {
        if (started) { return this }
        started = true

        let config = HttpServerConfig()
        config.keepAlive = true
        config.autoDateHeader = false
        config.autoServerHeader = false
        config.autoCompress = false
        config.readTimeout = Duration.second * 30
        config.enableHttp2 = false
        config.concurrent = true

        if (useTls) {
            config.tlsConfig = tlsConfig
        }

        let srv = HttpServer(handler: handler, config: config)
        this.server = Some(srv)
        let p = port()

        // 创建客户端
        let cc = HttpClientConfig()
        cc.followRedirects = false
        cc.connectionPoolEnabled = false
        cc.enableHttp2 = false
        if (useTls) {
            cc.tlsConfig = TlsConfig.insecure()
        }
        this.httpClient = Some(HttpClient(config: cc))

        // 启动服务器 —— 在后台线程中阻塞执行 listenAndServe
        let s = srv
        spawn {
            if (useTls) {
                try { s.listenAndServeTls("127.0.0.1", p) } catch (_: Exception) {}
            } else {
                try { s.listenAndServe("127.0.0.1", p) } catch (_: Exception) {}
            }
        }

        // 短暂休眠以允许生成的线程完成绑定并开始接受连接
        sleep(Duration.millisecond * 200)

        this
    }

    /**
     * 获取服务器 URL（http://127.0.0.1:<port>，TLS 则为 https://...）。
     */
    public func url(): String {
        let scheme = if (useTls) { "https" } else { "http" }
        "${scheme}://127.0.0.1:${portNum}"
    }

    /**
     * 获取指向此服务器的预配置 HttpClient。
     * 对于 TLS 服务器，客户端使用 TlsConfig.insecure() 配置
     * 以接受自签名测试证书。
     */
    public func client(): HttpClient {
        match (httpClient) {
            case Some(c) => c
            case None =>
                let cc = HttpClientConfig()
                cc.connectionPoolEnabled = false
                cc.enableHttp2 = false
                if (useTls) {
                    cc.tlsConfig = TlsConfig.insecure()
                }
                let c = HttpClient(config: cc)
                httpClient = Some(c)
                c
        }
    }

    public func closeClientConnections(): Unit {
        match (httpClient) {
            case Some(c) =>
                try { c.close() } catch (_: Exception) {}
                httpClient = None
            case None => ()
        }
    }

    /**
     * 检查此服务器是否以 TLS 模式运行。
     */
    public func isTls(): Bool { useTls }

    /**
     * 停止服务器并释放所有资源。
     */
    public func close(): Unit {
        started = false
        match (server) {
            case Some(s) =>
                try { s.shutdown() } catch (_: Exception) {}
                try { s.close() } catch (_: Exception) {}
            case None => ()
        }
        match (httpClient) {
            case Some(c) =>
                try { c.close() } catch (_: Exception) {}
            case None => ()
        }
    }

    public func isStarted(): Bool { started }

    /**
     * 向操作系统探测临时范围内的可用 TCP 端口。
     *
     * 在 [32768, 60999] 范围内随机选择最多 30 个端口尝试绑定，
     * 返回第一个成功的端口。若全部探测失败则回退到固定默认值。
     */
    public static func probeAvailablePort(): UInt16 {
        let rand = Random()
        var attempt: Int64 = 0
        while (attempt < 30) {
            let raw = rand.nextInt64()
            let pos = if (raw < 0) { -raw } else { raw }
            let port: UInt16 = UInt16(pos % 28232 + 32768)
            try {
                let sock = TcpServerSocket(bindAt: port)
                sock.bind()
                // 端口可用 —— 关闭探测套接字并使用此端口。
                // 存在 TOCTOU 竞态条件，但在测试场景下可接受。
                try { sock.close() } catch (_: Exception) {}
                return port
            } catch (_: Exception) {
                attempt++
            }
        }
        // 回退：若所有随机探测均失败则使用固定端口
        18080u16
    }
}

/**
 * 创建并启动一个分配随机端口的 TestServer。
 * 调用方使用完毕后必须调用 close() 关闭服务器。
 */
public func NewTestServer(handler: Handler): TestServer {
    let ts = TestServer(handler)
    ts.start()
    ts
}

/**
 * 使用给定的处理器和 TLS 配置创建并启动 TLS TestServer。
 * TlsConfig 必须设置 serverCertPath 和 serverKeyPath 为有效的 PEM 文件。
 *
 * 客户端自动使用 TlsConfig.insecure() 配置以接受自签名测试证书
 * —— 请勿在生产环境使用。
 *
 * 使用 OpenSSL 生成证书：
 *   openssl req -x509 -newkey rsa:2048 -keyout /tmp/test_key.pem \
 *     -out /tmp/test_cert.pem -days 365 -nodes \
 * -subj "/CN=localhost"
 *
 * 用法：
 *   let tlsCfg = TlsConfig.default()
 *   tlsCfg.serverCertPath = "/tmp/test_cert.pem"
 *   tlsCfg.serverKeyPath = "/tmp/test_key.pem"
 *   let ts = NewTLSTestServer(myHandler, tlsCfg)
 *   let resp = ts.client().get(ts.url() + "/path")
 *   ts.close()
 */
public func NewTLSTestServer(handler: Handler, tlsCfg: TlsConfig): TestServer {
    let ts = TestServer(handler)
    ts.withTls(tlsCfg)
    ts.start()
    ts
}

/**
 * 忙等待指定时长，以便后台线程完成初始化。
 *
 * 这是一个粗糙的同步机制；在现代硬件上实际延迟约为 50 毫秒。
 * 用于为生成的 listenAndServe 线程留出时间完成绑定并开始
 * 接受连接。
 */
private func busyWait(duration: Duration): Unit {
    let deadline = DateTime.now() + duration
    while (DateTime.now() < deadline) {
        // 自旋等待直到到达截止时间
    }
}

/**
 * 等待 TCP 端口开始接受连接。
 * 每 50 毫秒尝试连接一次，最多重试 `retries` 次。
 * 若端口变为可用则返回 true，超时则返回 false。
 *
 * 用法：
 *   if (!waitForPort(port)) { println("Server failed to start") }
 */
public func waitForPort(port: UInt16, retries!: Int64 = 40): Bool {
    var i: Int64 = 0
    while (i < retries) {
        try {
            let sock = TcpSocket("127.0.0.1", port)
            sock.close()
            return true
        } catch (_: Exception) {
            sleep(Duration.millisecond * 50)
        }
        i++
    }
    false
}
