package http_lib.client
/**
 * HTTP 客户端（自动跟随重定向、Cookie 管理、超时控制）。
 * 封装 HttpTransport 提供便捷的 GET/POST/PUT/DELETE 等请求方法。
 * 支持 HTTP/1.1 和 HTTP/2 协议，自动协议协商 (h2c/h2)。
 */

import std.overflow.*
import std.collection.{ArrayList, HashMap}
import std.collection.concurrent.ConcurrentHashMap
import std.sync.Mutex
import http_lib.buffer.ByteBuffer
import http_lib.core.*
import http_lib.message.*
import http_lib.message.{generateMultipartBoundary, buildMultipartBody, MultipartField}
import http_lib.connection.{Connection, TcpConnection, TlsConnection, TlsConfig, TlsException}
import http_lib.http2.{Http2Connection, Http2FrameHeader, HTTP2_CLIENT_PREFACE_BYTES}
import http_lib.utils.{ParsedUrl, base64EncodeString, formUrlEncode, containsIgnoreCaseBytes as utilsContainsIgnoreCaseBytes, findHeaderEnd}

/**
 * 请求执行接口 — 允许可插拔的传输层实现。
 *
 * 实现包括 HttpTransport（默认），可用于模拟、测试或自定义传输层。
 */
public interface RequestExecutor {
    func execute(request: HttpRequest): HttpResponse
}

/**
 * HTTP 客户端 configuration.
 */
public class HttpClientConfig {
    public var connectTimeout: Duration = Duration.second * 30
    public var readTimeout: Duration = Duration.second * 30
    public var writeTimeout: Duration = Duration.second * 30
    public var maxResponseHeaderBytes: Int64 = 65536
    public var followRedirects: Bool = true
    public var maxRedirects: Int64 = 10
    public var tlsConfig: TlsConfig = TlsConfig.default()
    public var connectionPoolEnabled: Bool = true
    public var maxConnectionsPerHost: Int64 = 5
    public var connectionIdleTimeout: Duration = Duration.second * 60
    public var cookieJarEnabled: Bool = true
    public var continueTimeout: Duration = Duration.second * 1
    public var enableExpectContinue: Bool = false
    public var authCredentials: ?HttpAuthCredentials = None
    public var enableHttp2: Bool = true
    public var dialer: ?(String, UInt16, Bool) -> Connection = None  // 自定义连接函数 
    public var transportDialer: ?(String, UInt16, Bool) -> Connection = None  // HttpTransport 的自定义连接器
    // 从响应读取的最大主体大小（0 = 无限制）。
    // 防止大响应导致内存耗尽。
    public var maxResponseBodyBytes: Int64 = 0
    // 重定向策略钩子。若设置，在每次重定向前调用。
    // 返回相同请求以跟随重定向，返回不同请求或抛异常以停止。
    public var checkRedirect: ?(HttpRequest, HttpResponse) -> HttpRequest = None
    // 客户端诊断跟踪钩子 
    public var trace: ?ClientTrace = None
    // 连接合并检查器（RFC 9113 9.1.1）
    public var coalesceChecker: ?(String, String) -> Bool = None

    public init() {}
}

/**
 * UseLastResponseError 可被 checkRedirect 钩子抛出，以表示
 * 客户端应返回当前（重定向）响应而不跟随重定向。
 * 
 * UseLastResponseError 模式。
 */
public class UseLastResponseError <: HttpException {
    public init() {
        super("http_lib: use last response")
    }
}

/**
 * HTTP 认证凭据，用于自动设置 Authorization 头。
 */
public enum HttpAuthScheme <: ToString {
    | Basic
    | Bearer
    | Digest

    public func toString(): String {
        match (this) {
            case Basic => "Basic"
            case Bearer => "Bearer"
            case Digest => "Digest"
        }
    }
}

public class HttpAuthCredentials {
    public let scheme: HttpAuthScheme
    public let credentials: String
    // Digest 认证参数（RFC 7616）
    public var digestUsername: ?String = None
    public var digestPassword: ?String = None
    public var digestRealm: ?String = None
    public var digestNonce: ?String = None
    public var digestUri: ?String = None
    public var digestMethod: String = "GET"
    public var digestOpaque: ?String = None
    public var digestQop: ?String = None
    public var digestAlgorithm: ?String = None

    public init(scheme: HttpAuthScheme, credentials: String) {
        this.scheme = scheme
        this.credentials = credentials
    }

    /**
     * 从用户名和密码创建 Basic 认证凭据。
     * 将 "username:password" 以 base64 编码。
     */
    public static func basic(username: String, password: String): HttpAuthCredentials {
        let combined = "${username}:${password}"
        let encoded = base64EncodeString(combined)
        HttpAuthCredentials(HttpAuthScheme.Basic, encoded)
    }

    /**
     * 创建 Bearer 令牌认证凭据。
     */
    public static func bearer(token: String): HttpAuthCredentials {
        HttpAuthCredentials(HttpAuthScheme.Bearer, token)
    }

    /**
     * 创建 Digest 认证凭据（RFC 7616）。
     * 参数被存储，Authorization 头值使用现有
     * digest 认证基础设施构建。
     */
    public static func digest(
        username: String,
        password: String,
        realm: String,
        nonce: String,
        uri: String,
        method!: String = "GET",
        opaque!: ?String = None,
        qop!: ?String = None,
        algorithm!: ?String = None
    ): HttpAuthCredentials {
        let creds = HttpAuthCredentials(HttpAuthScheme.Digest, "")
        creds.digestUsername = Some(username)
        creds.digestPassword = Some(password)
        creds.digestRealm = Some(realm)
        creds.digestNonce = Some(nonce)
        creds.digestUri = Some(uri)
        creds.digestMethod = method
        creds.digestOpaque = opaque
        creds.digestQop = qop
        creds.digestAlgorithm = algorithm
        creds
    }

    public func toHeaderValue(): String {
        match (scheme) {
            case HttpAuthScheme.Digest => buildDigestHeader()
            case _ => "${scheme} ${credentials}"
        }
    }

    /**
     * 构建 Digest Authorization 头值（RFC 7616）。
     * Delegates to the shared 摘要认证 infrastructure.
     */
    private func buildDigestHeader(): String {
        let username = match (digestUsername) { case Some(v) => v case None => "" }
        let password = match (digestPassword) { case Some(v) => v case None => "" }
        let realm = match (digestRealm) { case Some(v) => v case None => "" }
        let nonce = match (digestNonce) { case Some(v) => v case None => "" }
        let uri = match (digestUri) { case Some(v) => v case None => "" }
        buildDigestAuthHeader(username, password, realm, nonce, digestMethod, uri,
            opaque: digestOpaque, qop: digestQop, algorithm: digestAlgorithm)
    }
}

/**
 * HTTP 客户端，支持 HTTP 和 HTTPS。
 *
 * 用法：
 *   let client = HttpClient()
 *   let resp = client.get("https://api.example.com/data")
 *   let body = resp.bodyAsString()
 */
public class HttpClient {
    private var config: HttpClientConfig
    private var connectionPool: ConnectionPool
    private var cookieJar: HttpClientCookieJar
    private var h2Connections: ConcurrentHashMap<String, Http2Connection>
    private var h2Mu: Mutex

    public init(config!: HttpClientConfig = HttpClientConfig()) {
        this.config = config
        this.connectionPool = ConnectionPool(
            maxPerHost: config.maxConnectionsPerHost,
            idleTimeout: config.connectionIdleTimeout
        )
        this.cookieJar = HttpClientCookieJar()
        this.h2Connections = ConcurrentHashMap<String, Http2Connection>()
        this.h2Mu = Mutex()
    }

    // ---- 便捷方法 ----

    public func get(url: String): HttpResponse {
        let request = HttpRequestBuilder().get().withUrl(url).build()
        send(request)
    }

    public func post(url: String, body!: Array<UInt8> = []): HttpResponse {
        let builder = HttpRequestBuilder().post().withUrl(url)
        if (body.size > 0) { builder.withBody(body) }
        send(builder.build())
    }

    public func postJson(url: String, json: String): HttpResponse {
        let req = HttpRequestBuilder().post().withUrl(url).withJson(json).build()
        send(req)
    }

    public func postForm(url: String, form: HashMap<String, String>): HttpResponse {
        let req = HttpRequestBuilder().post().withUrl(url).withForm(form).build()
        send(req)
    }

    public func put(url: String, body!: Array<UInt8> = []): HttpResponse {
        let builder = HttpRequestBuilder().put().withUrl(url)
        if (body.size > 0) { builder.withBody(body) }
        send(builder.build())
    }

    public func delete(url: String): HttpResponse {
        let request = HttpRequestBuilder().delete().withUrl(url).build()
        send(request)
    }

    /**
     * 发送 HEAD 请求。
     */
    public func head(url: String): HttpResponse {
        let request = HttpRequestBuilder().head().withUrl(url).build()
        send(request)
    }

    /**
     * 发送 OPTIONS 请求。
     */
    public func options(url: String): HttpResponse {
        let request = HttpRequestBuilder().options().withUrl(url).build()
        send(request)
    }

    /**
     * 发送 PATCH 请求，可选附带主体。
     */
    public func patch(url: String, body!: Array<UInt8> = []): HttpResponse {
        let builder = HttpRequestBuilder().patch().withUrl(url)
        if (body.size > 0) { builder.withBody(body) }
        send(builder.build())
    }

    /**
     * 关闭传输层中所有空闲连接。
     */
    public func cleanIdleConnections(): Unit {
        connectionPool.closeIdle()
    }

    /**
     * 发送 HTTP 请求并以流式方式读取响应。
     *
     * 与 send() 不同，sendStream() 在解析完响应头后立即返回，
     * 底层连接保持打开状态，调用方可通过返回的 StreamedHttpResponse
     * 增量读取响应体。适用于 SSE、大文件下载等流式处理场景。
     *
     * 注意：调用后必须调用 StreamedHttpResponse.close() 释放连接。
     *
     * 用法：
     *   let resp = client.sendStream(request)
     *   while (true) {
     *       let line = resp.readLine()
     *       if (line.size == 0) { break }
     *       // 处理 line
     *   }
     *   resp.close()
     */
    public func sendStream(request: HttpRequest): StreamedHttpResponse {
        // 使用 HttpTransport 处理连接管理和代理
        let transport = buildTransportFromConfig()
        transport.executeStream(request)
    }

    /**
     * 从 HttpClientConfig 构建 HttpTransport。
     */
    private func buildTransportFromConfig(): HttpTransport {
        let transport = HttpTransport()
        transport.connectTimeout = config.connectTimeout
        transport.tlsTimeout = config.connectTimeout
        transport.responseTimeout = config.readTimeout
        transport.disableKeepAlive = !config.connectionPoolEnabled
        transport.maxConnectionsPerHost = config.maxConnectionsPerHost
        transport.idleConnectionTimeout = config.connectionIdleTimeout
        transport.tlsConfig = config.tlsConfig
        transport.dialer = config.transportDialer
        transport.forceHttp2 = config.enableHttp2
        transport
    }

    // ---- 核心 HTTP 发送 ----

    /**
     * Send an HTTP 请求, following redirects per config.
     */
    public func send(request: HttpRequest): HttpResponse {
        var currentReq = request
        var redirectCount: Int64 = 0

        while (true) {
            let response = sendSingle(currentReq)
            if (!config.followRedirects || !isRedirect(response.status)) {
                return response
            }
            redirectCount++
            if (redirectCount > config.maxRedirects) {
                throw RedirectLimitExceededException(config.maxRedirects)
            }

            // 若已配置则调用 checkRedirect 策略钩子
            match (config.checkRedirect) {
                case Some(cr) =>
                    try {
                        let nextReq = cr(currentReq, response)
                        if (nextReq.url != currentReq.url || nextReq.method != currentReq.method) {
                            // checkRedirect 返回了不同的请求 —— 停止跟随
                            return response
                        }
                    } catch (e: UseLastResponseError) {
                        // checkRedirect 抛出了 UseLastResponseError —— 返回当前响应
                        // 不跟随重定向（UseLastResponseError）
                        return response
                    } catch (_: Exception) {
                        // checkRedirect 抛出异常 —— 停止跟随
                        return response
                    }
                case None => ()
            }

            let location = match (response.headers.get("location")) {
                case Some(l) => l
                case None => return response
            }

            let nextUrl = resolveRedirectUrl(currentReq.url, location)
            currentReq = buildRedirectRequest(currentReq, response.status, nextUrl)
        }
        throw RedirectLimitExceededException(config.maxRedirects)
    }

    /**
     * Send a single HTTP 请求 without following redirects.
     * 若启用，自动将 HTTPS 连接升级到 HTTP/2。
     */
    public func sendSingle(request: HttpRequest): HttpResponse {
        let parsedUrl = ParsedUrl.parse(request.url)
        let host = parsedUrl.host
        let port = parsedUrl.port
        let isSecure = parsedUrl.isSecure
        let path = parsedUrl.path

        // 首先尝试已有 HTTP/2 连接（包括 h2c 和经合并的连接）
        if (config.enableHttp2) {
            let h2Key = if (isSecure) { "${host}:${port}" } else { "h2c:${host}:${port}" }
            match (h2Connections.get(h2Key)) {
                case Some(h2conn) =>
                    if (h2conn.isConnected()) {
                        return sendHttp2(h2conn, request, host, port, isSecure)
                    }
                    h2Connections.remove(h2Key)
                case None => ()
            }
            if (isSecure) {
                match (findCoalescedH2Connection(host, port)) {
                    case Some((coalescedConn, coalescedKey)) =>
                        h2Connections[h2Key] = coalescedConn
                        return sendHttp2(coalescedConn, request, host, port, isSecure)
                    case None => ()
                }
            }
        }

        // 首先尝试从连接池借用
        var fromPool = false
        let connection = if (config.connectionPoolEnabled) {
            match (connectionPool.borrow(host, port, isSecure)) {
                case Some(c) => fromPool = true; c
                case None => connect(host, port, isSecure)
            }
        } else {
            connect(host, port, isSecure)
        }

        // 触发 gotConnectionHook 跟踪钩子
        match (config.trace) {
            case Some(t) =>
                match (t.gotConnectionHook) {
                    case Some(cb) => cb(fromPool)
                    case None => ()
                }
            case None => ()
        }

        var reusable = false
        try {
            // 为新 HTTPS 连接尝试 HTTP/2 升级（TLS ALPN）
            if (config.enableHttp2 && isSecure) {
                let h2Key = "${host}:${port}"
                let h2conn = tryUpgradeToHttp2(connection, host, port)
                match (h2conn) {
                    case Some(h2c) =>
                        var finalH2Conn = h2c
                        synchronized(h2Mu) {
                            match (h2Connections.get(h2Key)) {
                                case Some(existing) =>
                                    try { h2c.close() } catch (_: Exception) {}
                                    finalH2Conn = existing
                                case None =>
                                    h2Connections[h2Key] = h2c
                            }
                        }
                        return sendHttp2(finalH2Conn, request, host, port, isSecure)
                    case None => ()
                }
            }
            // 为新明文连接尝试直接 h2c（RFC 9113 3.4）
            if (config.enableHttp2 && !isSecure) {
                let h2cKey = "h2c:${host}:${port}"
                let h2conn = tryDirectH2c(connection, host, port)
                match (h2conn) {
                    case Some(h2c) =>
                        var finalH2Conn = h2c
                        synchronized(h2Mu) {
                            match (h2Connections.get(h2cKey)) {
                                case Some(existing) =>
                                    try { h2c.close() } catch (_: Exception) {}
                                    finalH2Conn = existing
                                case None =>
                                    h2Connections[h2cKey] = h2c
                            }
                        }
                        return sendHttp2(finalH2Conn, request, host, port, isSecure)
                    case None => ()
                }
            }

            let fullUrl = if (path.startsWith("/")) { path } else { "/${path}" }
            let wireReq = HttpRequest(method: request.method, url: fullUrl, version: request.version,
                headers: request.headers, body: request.body)

            if (wireReq.headers.get("host").isNone()) {
                wireReq.headers.set("Host", host)
            }
            if (wireReq.headers.get("user-agent").isNone()) {
                wireReq.headers.set("User-Agent", "http_lib/0.1")
            }
            // HTTP/1.0 默认 Connection: close；HTTP/1.1 默认 Keep-Alive。
            // 仅在尚未设置时设置 Connection 头部。
            // HTTP 客户端传输层连接处理。
            if (wireReq.headers.get("connection").isNone()) {
                if (!wireReq.version.supportsPersistentConnection()) {
                    wireReq.headers.set("Connection", "close")
                }
            }
            if (wireReq.headers.get("accept").isNone()) {
                wireReq.headers.set("Accept", "*/*")
            }
            if (wireReq.headers.get("accept-encoding").isNone()) {
                wireReq.headers.set("Accept-Encoding", "gzip, deflate")
            }
            match (config.authCredentials) {
                case Some(creds) =>
                    if (wireReq.headers.get("authorization").isNone()) {
                        wireReq.headers.set("Authorization", creds.toHeaderValue())
                    }
                case None => ()
            }
            let bodyLen = wireReq.body.getLimit()
            // 检查用户是否需要分块传输编码
            let useChunked = match (wireReq.headers.get("transfer-encoding")) {
                case Some(te) =>
                    let teBytes = unsafe { te.rawData() }
                    let chunkedBytes = unsafe { "chunked".rawData() }
                    utilsContainsIgnoreCaseBytes(teBytes, chunkedBytes)
                case None => false
            }
            if (bodyLen > 0 && wireReq.headers.get("content-length").isNone() && !useChunked) {
                wireReq.headers.set("Content-Length", "${bodyLen}")
            }

            if (config.enableExpectContinue && bodyLen > 1024 && wireReq.headers.get("expect").isNone()) {
                wireReq.headers.set("Expect", "100-continue")
            }

            if (config.cookieJarEnabled) {
                cookieJar.applyCookies(host, path, isSecure, wireReq)
            }

            // 检查 Expect: 100-continue — 先发送头部，等待 100 Continue，
            // 然后发送主体。根据 RFC 7231 第 5.1.1 节。
            let hasExpectContinue = match (wireReq.headers.get("expect")) {
                case Some(ev) =>
                    let evBytes = unsafe { ev.rawData() }
                    let needle = unsafe { "100-continue".rawData() }
                    utilsContainsIgnoreCaseBytes(evBytes, needle)
                case None => false
            }
            let hasBody = wireReq.body.getLimit() > 0

            if (hasExpectContinue && hasBody) {
                // 先发送不带主体的头部
                let headersOnly = buildHeadersOnlyRequest(wireReq)
                connection.write(headersOnly)

                // 根据 RFC 7231 §5.1.1：客户端应等待 100 (Continue) 响应
                // 使用 continueTimeout 避免无限等待。超时后继续发送主体（RFC 允许此行为）。
                connection.setReadTimeout(config.continueTimeout)
                let interimResp: ?HttpResponse = try {
                    Some(readResponse(connection))
                } catch (_: Exception) {
                    None
                }
                connection.setReadTimeout(config.readTimeout)

                match (interimResp) {
                    case Some(ir) =>
                        if (ir.status.code == 100) {
                            // 服务器允许继续 — 发送主体
                            if (useChunked) {
                                writeChunkedBody(connection, wireReq)
                            } else {
                                let bodyBytes = wireReq.bodyAsBytes()
                                if (bodyBytes.size > 0) {
                                    connection.write(bodyBytes)
                                }
                            }
                            // 现在读取最终响应
                            let finalResp = readResponse(connection)

                            if (config.cookieJarEnabled) {
                                cookieJar.extractCookies(host, path, isSecure, finalResp)
                            }

                            reusable = if (config.connectionPoolEnabled) {
                                finalResp.isKeepAlive() && connection.canReuseTransport()
                            } else { false }

                            return finalResp
                        } else if (ir.status.code == 417) {
                            // RFC 7231 §6.5.14：417 Expectation Failed
                            if (config.cookieJarEnabled) {
                                cookieJar.extractCookies(host, path, isSecure, ir)
                            }
                            reusable = false
                            try { connection.close() } catch (_: Exception) {}
                            throw HttpException("Expectation failed: server does not support 100-continue")
                        } else {
                            // 服务器拒绝或发送了最终响应
                            if (config.cookieJarEnabled) {
                                cookieJar.extractCookies(host, path, isSecure, ir)
                            }
                            reusable = if (config.connectionPoolEnabled) {
                                ir.isKeepAlive() && connection.canReuseTransport()
                            } else { false }
                            return ir
                        }
                    case None =>
                        // 超时（无响应）：根据 RFC 7231 §5.1.1 继续发送主体
                        if (useChunked) {
                            writeChunkedBody(connection, wireReq)
                        } else {
                            let bodyBytes = wireReq.bodyAsBytes()
                            if (bodyBytes.size > 0) {
                                connection.write(bodyBytes)
                            }
                        }
                        let finalResp = readResponse(connection)

                        if (config.cookieJarEnabled) {
                            cookieJar.extractCookies(host, path, isSecure, finalResp)
                        }

                        reusable = if (config.connectionPoolEnabled) {
                            finalResp.isKeepAlive() && connection.canReuseTransport()
                        } else { false }

                        return finalResp
                }
            }

            if (useChunked) {
                // 写入不带主体的请求行 + 头部
                let headersPart = buildHeadersOnlyRequest(wireReq)
                connection.write(headersPart)
                // 使用分块编码写入主体
                writeChunkedBody(connection, wireReq)
            } else {
                let requestBytes = wireReq.toBytes()
                connection.write(requestBytes)
            }
            // 触发 wroteRequestHook 追踪钩子
            match (config.trace) {
                case Some(t) =>
                    match (t.wroteRequestHook) {
                        case Some(cb) => cb()
                        case None => ()
                    }
                case None => ()
            }

            // 在读取响应前触发 gotFirstResponseByteHook 追踪钩子
            match (config.trace) {
                case Some(t) =>
                    match (t.gotFirstResponseByteHook) {
                        case Some(cb) => cb()
                        case None => ()
                    }
                case None => ()
            }

            let response = readResponse(connection)

            if (config.cookieJarEnabled) {
                cookieJar.extractCookies(host, path, isSecure, response)
            }

            // 摘要认证自动重试（RFC 7616）：收到 401 且带有 WWW-Authenticate: Digest 时，
            // 自动构建 Authorization 头部并重试请求一次。
            if (response.status.code == 401) {
                match (config.authCredentials) {
                    case Some(creds) =>
                        match (creds.scheme) {
                            case HttpAuthScheme.Digest =>
                                match (response.headers.get("www-authenticate")) {
                                    case Some(challenge) =>
                                        let params = parseDigestChallenge(challenge)
                                        if (params.size > 0) {
                                            let realm = match (params.get("realm")) { case Some(v) => v case None => "" }
                                            let nonce = match (params.get("nonce")) { case Some(v) => v case None => "" }
                                            let qop = params.get("qop")
                                            let opaque = params.get("opaque")
                                            let algorithm = params.get("algorithm")
                                            if (realm.size > 0 && nonce.size > 0) {
                                                let username = match (creds.digestUsername) { case Some(v) => v case None => "" }
                                                let password = match (creds.digestPassword) { case Some(v) => v case None => "" }
                                                let authHeader = buildDigestAuthHeader(
                                                    username, password, realm, nonce,
                                                    request.method.toString(), path,
                                                    opaque: opaque, qop: qop, algorithm: algorithm
                                                )
                                                wireReq.headers.set("Authorization", authHeader)
                                                if (useChunked) {
                                                    let headersPart = buildHeadersOnlyRequest(wireReq)
                                                    connection.write(headersPart)
                                                    writeChunkedBody(connection, wireReq)
                                                } else {
                                                    let requestBytes = wireReq.toBytes()
                                                    connection.write(requestBytes)
                                                }
                                                let retryResp = readResponse(connection)
                                                if (config.cookieJarEnabled) {
                                                    cookieJar.extractCookies(host, path, isSecure, retryResp)
                                                }
                                                reusable = if (config.connectionPoolEnabled) {
                                                    retryResp.isKeepAlive() && connection.canReuseTransport()
                                                } else { false }
                                                return retryResp
                                            }
                                        }
                                    case None => ()
                                }
                            case _ => ()
                        }
                    case None => ()
                }
            }

            reusable = if (config.connectionPoolEnabled) {
                response.isKeepAlive() && connection.canReuseTransport()
            } else {
                false
            }

            response
        } catch (e: Exception) {
            reusable = false
            throw e
        } finally {
            if (config.connectionPoolEnabled) {
                connectionPool.release(host, port, isSecure, connection, reusable)
            } else {
                try { connection.close() } catch (_: Exception) {}
            }
        }
    }

    /**
     * 尝试将连接升级到 HTTP/2。
     * 发送 HTTP/2 前言并等待 SETTINGS 帧。
     * 成功时返回 Some(Http2Connection)，失败时返回 None 以回退到 HTTP/1.1。
     */
    private func tryUpgradeToHttp2(conn: Connection, host: String, port: UInt16): ?Http2Connection {
        // RFC 7540 §3.3 / RFC 7301: 客户端只能在 TLS ALPN 协商为 "h2" 时发送 HTTP/2 preface。
        // 若不检查协商结果而盲目发送 preface，服务器（未协商 h2）会把 preface 当作
        // 非法 HTTP/1.1 数据解析失败并强制关闭连接，表现为 Windows 10054
        // "An existing connection was forcibly closed by the remote host."。
        let negotiatedProtocol = match (conn.connectionState()) {
            case Some(state) => state.negotiatedProtocol
            case None => ""
        }
        if (negotiatedProtocol != "h2") {
            return None
        }
        try {
            conn.write(HTTP2_CLIENT_PREFACE_BYTES)
            conn.flush()
            // 窥视响应 — 如果是 SETTINGS 帧，则使用 HTTP/2
            // SETTINGS 帧头：length(3) + type=4 + flags + streamId=0 = 9 字节
            let peekBuf = Array<UInt8>(9, repeat: 0)
            let n = conn.read(peekBuf)
            if (n < 9) { return None }
            // 检查是否为 SETTINGS 帧（type == 4）
            if (peekBuf[3] != 4) { return None }
            // 是 HTTP/2 — 创建连接并完成握手
            let frameHeader = Http2FrameHeader.parse(peekBuf)
            let h2conn = Http2Connection(conn, isServer: false)
            // 提供我们已经读取的 SETTINGS 帧头
            // 为简化起见，仅完成握手
            let payloadLen = frameHeader.payloadLength
            if (payloadLen > 0) {
                let payload = Array<UInt8>(payloadLen, repeat: 0)
                let pn = conn.read(payload)
                if (pn < payloadLen) { return None }
                // 处理设置
            }
            // 发送我们的 SETTINGS
            h2conn.connect()
            return Some(h2conn)
        } catch (_: Exception) {
            None
        }
    }

    /**
     * 尝试通过直接发送连接序言建立 h2c 明文连接（RFC 9113 3.4）。
     */
    private func tryDirectH2c(conn: Connection, host: String, port: UInt16): ?Http2Connection {
        try {
            conn.write(HTTP2_CLIENT_PREFACE_BYTES)
            conn.flush()
            let peekBuf = Array<UInt8>(9, repeat: 0)
            let n = conn.read(peekBuf)
            if (n < 9) { return None }
            if (peekBuf[3] != 4) { return None }
            let frameHeader = Http2FrameHeader.parse(peekBuf)
            let h2conn = Http2Connection(conn, isServer: false)
            let payloadLen = frameHeader.payloadLength
            if (payloadLen > 0) {
                let payload = Array<UInt8>(payloadLen, repeat: 0)
                let pn = conn.read(payload)
                if (pn < payloadLen) { return None }
            }
            h2conn.connect()
            return Some(h2conn)
        } catch (_: Exception) {
            None
        }
    }

    /**
     * 查找可合并的 HTTP/2 连接（RFC 9113 9.1.1）。
     *
     * 合并策略（按优先级）：
     * 1. ORIGIN 帧（RFC 8336）：若服务器声明了对目标 origin 的权威性，可复用连接。
     * 2. coalesceChecker 回调：若用户提供了自定义检查器，使用之。
     * 3. 主机名/端口精确匹配：回退策略。
     */

private func findCoalescedH2Connection(targetHost: String, targetPort: UInt16): ?(Http2Connection, String) {
        let targetAuthorityLower = "${targetHost}:${targetPort}"
        for ((key, h2conn) in h2Connections) {
            if (!h2conn.isConnected()) { continue }
            // 策略 1：ORIGIN 帧权威性声明（RFC 8336 §4）
            let origins = h2conn.getPeerOrigins()
            for (origin in origins) {
                // origin 格式为 "https://host:port" 或 "https://host"
                if (origin.contains(targetAuthorityLower) || origin.contains(targetHost)) {
                    return Some((h2conn, key))
                }
            }
            // 策略 2：用户自定义 coalesceChecker
            match (config.coalesceChecker) {
                case Some(checker) =>
                    let colonIdx = key.lastIndexOf(":")
                    match (colonIdx) {
                        case Some(ci) =>
                            let existingHost = key[..ci]
                            let existingPortStr = key[ci + 1..]
                            if (existingPortStr == "${targetPort}" && checker(existingHost, targetHost)) {
                                return Some((h2conn, key))
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
        None
    }

    /**
     * Send a request over an HTTP/2 连接.
     */
    private func sendHttp2(h2conn: Http2Connection, request: HttpRequest, host: String, port: UInt16, isSecure: Bool): HttpResponse {
        // 必要时构建完整 URL
        var req = request
        let h2path = ParsedUrl.parse(request.url).path
        let fullPath = if (h2path.startsWith("/")) { h2path } else { "/${h2path}" }
        if (request.url != fullPath) {
            req = HttpRequest(method: request.method, url: fullPath, version: HttpVersion.HTTP_2_0,
                headers: request.headers, body: request.body)
        }

        // 缺失时设置 host 头部
        if (req.headers.get("host").isNone()) {
            req.headers.set("Host", host)
        }

        // 应用 Cookie
        if (config.cookieJarEnabled) {
            cookieJar.applyCookies(host, fullPath, isSecure, req)
        }

        let streamId = h2conn.sendRequest(req)
        let response = h2conn.recvResponse(streamId)

        // 从响应中提取 Cookie
        if (config.cookieJarEnabled) {
            cookieJar.extractCookies(host, fullPath, isSecure, response)
        }

        response
    }

    // ---- 重定向辅助函数 ----

    /**
     * 检查状态码是否为重定向（3xx，排除 304）。
     */
    private static func isRedirect(status: HttpStatus): Bool {
        status.isRedirection() && status.code != 304
    }

    /**
     * 解析相对于原始 URL 的可能相对重定向 URL。
     */
    private static func resolveRedirectUrl(originalUrl: String, location: String): String {
        if (location.startsWith("http://") || location.startsWith("https://")) {
            location
        } else if (location.startsWith("/")) {
            // 绝对路径：替换原始 URL 的路径部分
            let parsedRedirect = ParsedUrl.parse(originalUrl)
            let host = parsedRedirect.host
            let port = parsedRedirect.port
            let isSecure = parsedRedirect.isSecure
            let scheme = if (isSecure) { "https" } else { "http" }
            let defaultPorts = if (isSecure) { 443 } else { 80 }
            if (port == UInt16(defaultPorts)) {
                "${scheme}://${host}${location}"
            } else {
                "${scheme}://${host}:${port}${location}"
            }
        } else {
            // 相对路径：基于当前路径解析
            let parsedRedirect = ParsedUrl.parse(originalUrl)
            let host = parsedRedirect.host
            let port = parsedRedirect.port
            let isSecure = parsedRedirect.isSecure
            let currentPath = parsedRedirect.path
            let scheme = if (isSecure) { "https" } else { "http" }
            // 解析相对路径段
            let resolvedPath = resolveRelativePath(currentPath, location)
            let defaultPorts = if (isSecure) { 443 } else { 80 }
            if (port == UInt16(defaultPorts)) {
                "${scheme}://${host}${resolvedPath}"
            } else {
                "${scheme}://${host}:${port}${resolvedPath}"
            }
        }
    }

    /**
     * 基于基础路径解析相对路径。
     */
    private static func resolveRelativePath(basePath: String, relative: String): String {
        // 找到 basePath 的目录部分（去掉最后一个段）
        var base = if (basePath.endsWith("/")) { basePath } else {
            let lastSlash = basePath.lastIndexOf("/")
            if (let Some(idx) <- lastSlash) { basePath[..idx + 1] } else { "/" }
        }
        // 去掉开头的 "./" 段
        var rel = relative
        while (rel.startsWith("./")) {
            rel = rel[2..]
        }
        // 处理 "../" 段
        while (rel.startsWith("../")) {
            rel = rel[3..]
            // 向上级目录
            if (base.endsWith("/") && base.size > 1) {
                let withoutTrailing = base[..base.size - 1]
                let parentSlash = withoutTrailing.lastIndexOf("/")
                base = if (let Some(idx) <- parentSlash) { withoutTrailing[..idx + 1] } else { "/" }
            }
        }
        base + rel
    }

    /**
     * 基于 RFC 7231 语义构建重定向请求。
     */
    private static func buildRedirectRequest(
        original: HttpRequest,
        status: HttpStatus,
        newUrl: String
    ): HttpRequest {
        let code = status.code
        var redirectReq: HttpRequest

        // 303：始终切换到 GET
        if (code == 303) {
            redirectReq = HttpRequest(method: HttpMethod.GET, url: newUrl)
        } else if (code == 301 || code == 302) {
            // 301/302：历史上非 GET/HEAD 切换到 GET
            if (original.method == HttpMethod.HEAD) {
                redirectReq = HttpRequest(method: HttpMethod.HEAD, url: newUrl)
            } else {
                redirectReq = HttpRequest(method: HttpMethod.GET, url: newUrl)
            }
        } else if (code == 307 || code == 308) {
            // 307/308：保留原始方法和主体
            redirectReq = HttpRequest(method: original.method, url: newUrl, headers: original.headers, body: original.body)
        } else {
            // 默认：切换到 GET
            redirectReq = HttpRequest(method: HttpMethod.GET, url: newUrl)
        }

        // 安全：跨域重定向时剥离敏感响应头
        if (_isCrossDomainRedirect(original.url, newUrl)) {
            redirectReq.headers.remove("authorization")
            redirectReq.headers.remove("cookie")
            redirectReq.headers.remove("proxy-authorization")
        }

        // 更新新 URL 的 Host 头部
        let host = ParsedUrl.parse(newUrl).host
        redirectReq.headers.set("Host", host)
        redirectReq
    }

    /**
     * 检查重定向是否更改了主机/域名。
     * 跨域重定向不应携带敏感头部。
     */
    private static func _isCrossDomainRedirect(originalUrl: String, newUrl: String): Bool {
        let origHost = ParsedUrl.parse(originalUrl).host
        let newHost = ParsedUrl.parse(newUrl).host
        // 简单主机比较；子域名变更视为跨域
        // （保守策略）
        origHost != newHost
    }

    /**
     * 创建 HTTP/1.1 管道（RFC 7230 §6.3.2）。
     * 在单个持久连接上发送多个请求，然后按顺序读取响应。
     *
     * 用法：
     *   let p = client.pipeline("https://example.com")
     *   p.send(HttpRequest(method: HttpMethod.GET, url: "/a"))
     *   p.send(HttpRequest(method: HttpMethod.GET, url: "/b"))
     *   let r1 = p.recv()  // 按 FIFO 顺序读取
     *   let r2 = p.recv()
     *   p.close()
     *
     * @param baseUrl 目标主机 URL
     * @return Pipeline 实例
     */
    public func pipeline(baseUrl: String): Pipeline {
        let t = buildTransportFromConfig()
        Pipeline(t, baseUrl)
    }

    /**
     * 批量管道请求。
     * 在单个连接上发送所有请求，然后读取所有响应。
     * 比依次调用 execute() 更高效（减少连接建立开销）。
     *
     * @param requests 同一主机的 HTTP 请求列表
     * @return 按发送顺序排列的 HTTP 响应列表
     */
    public func pipelineBatch(requests: ArrayList<HttpRequest>): ArrayList<HttpResponse> {
        if (requests.size == 0) { return ArrayList<HttpResponse>() }
        let t = buildTransportFromConfig()
        t.pipeline(requests)
    }


    public func close(): Unit {
        connectionPool.closeAll()
        cookieJar.clear()
        for ((_, h2conn) in h2Connections) {
            try { h2conn.close() } catch (_: Exception) {}
        }
        h2Connections = ConcurrentHashMap<String, Http2Connection>()
    }

    // ---- 传输层 ----

    private func connect(host: String, port: UInt16, isSecure: Bool): Connection {
        // 使用自定义拨号器（如果已配置）
        match (config.dialer) {
            case Some(dial) => return dial(host, port, isSecure)
            case None => ()
        }
        let addr = "${host}:${port}"
        // 触发追踪钩子
        match (config.trace) {
            case Some(t) =>
                match (t.connectStartHook) {
                    case Some(cb) => cb("tcp", addr)
                    case None => ()
                }
            case None => ()
        }
        let result: Connection
        try {
            if (isSecure) {
                match (config.trace) {
                    case Some(t) =>
                        match (t.tlsHandshakeStartHook) {
                            case Some(cb) => cb()
                            case None => ()
                        }
                    case None => ()
                }
                let tcpConn = TcpConnection.connect(host, port,
                    connectTimeout: config.connectTimeout,
                    readTimeout: config.readTimeout,
                    writeTimeout: config.writeTimeout)
                // 触发 TCP 部分的 connectDoneHook
                match (config.trace) {
                    case Some(t) =>
                        match (t.connectDoneHook) {
                            case Some(cb) => cb("tcp", addr, "")
                            case None => ()
                        }
                    case None => ()
                }
                // 关键修复：禁用 HTTP/2 时，TLS ALPN 只协商 http/1.1。
                // 若仍使用默认 nextProtos（["h2","http/1.1"]），服务器会协商出 "h2"，
                // 但客户端实际发送 HTTP/1.1 请求，服务器（如 DeepSeek API）解析
                // HTTP/1.1 字节流失败后直接强制关闭连接，报 10054
                // "An existing connection was forcibly closed by the remote host"。
                let tlsCfg = if (config.enableHttp2) {
                    config.tlsConfig
                } else {
                    let cfg = config.tlsConfig.copy()
                    cfg.nextProtos = ["http/1.1"]
                    cfg
                }
                let tlsConn = TlsConnection(tcpConn, host, tlsCfg)
                let tlsErr = try {
                    tlsConn.handshake()
                    ""
                } catch (e: Exception) {
                    e.message
                }
                match (config.trace) {
                    case Some(t) =>
                        match (t.tlsHandshakeDoneHook) {
                            case Some(cb) =>
                                let cs = match (tlsConn.connectionState()) {
                                    case Some(s) => s.cipherSuite
                                    case None => ""
                                }
                                cb("TLS 1.2", cs, tlsErr)
                            case None => ()
                        }
                    case None => ()
                }
                if (tlsErr.size > 0) {
                    throw TlsException("TLS 握手 failed: ${tlsErr}")
                }
                result = tlsConn
            } else {
                let conn = TcpConnection.connect(host, port,
                    connectTimeout: config.connectTimeout,
                    readTimeout: config.readTimeout,
                    writeTimeout: config.writeTimeout)
                match (config.trace) {
                    case Some(t) =>
                        match (t.connectDoneHook) {
                            case Some(cb) => cb("tcp", addr, "")
                            case None => ()
                        }
                    case None => ()
                }
                result = conn
            }
        } catch (e: Exception) {
            // 如果连接失败，触发带错误的 connectDoneHook
            match (config.trace) {
                case Some(t) =>
                    match (t.connectDoneHook) {
                        case Some(cb) => cb("tcp", addr, e.message)
                        case None => ()
                    }
                case None => ()
            }
            throw e
        }
        result
    }

    private func readResponse(conn: Connection): HttpResponse {
        let buffer = ByteBuffer(capacity: 4096)
        let scratch = Array<UInt8>(4096, repeat: 0)
        var headerEnd: Int64 = -1
        var totalRead: Int64 = 0

        while (headerEnd < 0) {
            let n = conn.read(scratch)
            if (n <= 0) {
                throw ProtocolException("connection closed by server")
            }
            buffer.write(scratch, 0, n)
            totalRead = totalRead.wrappingAdd(n)
            if (totalRead > config.maxResponseHeaderBytes) {
                throw ProtocolException("response headers too large")
            }
            let data = buffer.getArray()
            headerEnd = findHeaderEnd(data, totalRead)
        }

        let data = buffer.getArray()
        let response = HttpResponseParser.parse(data[0..totalRead])
        let bodyStart = headerEnd

        let isChunked = match (response.headers.get("transfer-encoding")) {
            case Some(te) =>
                let teBytes = unsafe { te.rawData() }
                let chunkedBytes = unsafe { "chunked".rawData() }
                utilsContainsIgnoreCaseBytes(teBytes, chunkedBytes)
            case None => false
        }

        if (isChunked) {
            let prefetched = readPrefetchedBody(data, totalRead, bodyStart)
            let readerFn = {buf => conn.read(buf)}
            // 读取所有剩余分块数据，然后用 decodeWithTrailers 解析
            let extra = readAllFromConn(conn)
            let combinedSize = prefetched.size + extra.size
            let combined = Array<UInt8>(combinedSize, repeat: 0)
            var ci: Int64 = 0
            while (ci < prefetched.size) { combined[ci] = prefetched[ci]; ci = ci + 1 }
            var ei: Int64 = 0
            while (ei < extra.size) { combined[prefetched.size + ei] = extra[ei]; ei = ei + 1 }
            let result = ChunkedDecoder.decodeWithTrailers(combined)
            response.body = ByteBuffer.fromOwned(result.data)
            if (!result.trailers.isEmpty()) {
                response.trailers = result.trailers
            }
        } else {
            match (response.headers.get("content-length")) {
                case Some(cl) =>
                    let contentLength = parseContentLength(cl)
                    // 强制 maxResponseBodyBytes 限制
                    if (config.maxResponseBodyBytes > 0 && contentLength > config.maxResponseBodyBytes) {
                        throw ProtocolException("response body exceeds max size of ${config.maxResponseBodyBytes} bytes")
                    }
                    let currentBody = totalRead - bodyStart
                    let remaining = contentLength - currentBody
                    if (remaining > 0) {
                        let moreData = readExact(conn, remaining)
                        response.body.write(moreData)
                    }
                case None => ()
            }
        }
        // 读取主体后强制执行 maxResponseBodyBytes
        if (config.maxResponseBodyBytes > 0 && response.body.getLimit() > config.maxResponseBodyBytes) {
            throw ProtocolException("response body exceeds max size of ${config.maxResponseBodyBytes} bytes")
        }
        // 必要时自动解压缩
        match (response.headers.get("content-encoding")) {
            case Some(ce) =>
                if (ce.size > 0 && response.body.getLimit() > 0) {
                    let decompressed = Compression.decompress(response.bodyAsBytes(), ce)
                    let newBody = ByteBuffer(capacity: decompressed.size)
                    newBody.write(decompressed)
                    response.body = newBody
                    response.headers.remove("content-encoding")
                    response.headers.set("Content-Length", "${decompressed.size}")
                }
            case None => ()
        }
        response
    }

    private func readPrefetchedBody(data: Array<UInt8>, totalRead: Int64, bodyStart: Int64): Array<UInt8> {
        if (totalRead > bodyStart) {
            let len = totalRead - bodyStart
            let arr = Array<UInt8>(len, repeat: 0)
            data[bodyStart..bodyStart + len].copyTo(arr, 0, 0, len)
            arr
        } else {
            Array<UInt8>(0, repeat: 0)
        }
    }

    private func readExact(conn: Connection, count: Int64): Array<UInt8> {
        let result = Array<UInt8>(count, repeat: 0)
        var totalRead: Int64 = 0
        let tempBuf = Array<UInt8>(4096, repeat: 0)
        while (totalRead < count) {
            let maxRead = if (count - totalRead < 4096) { count - totalRead } else { 4096 }
            // 直接读取到 result 中，避免 tempBuf 切片问题
            let n = conn.read(result, totalRead, maxRead)
            if (n <= 0) {
                throw ProtocolException("connection closed while reading body")
            }
            totalRead = totalRead.wrappingAdd(n)
        }
        result
    }
}

public class HttpRequestBuilder {
    private var method: HttpMethod = HttpMethod.GET
    private var url: String = "/"
    private var headers: HttpHeaders = HttpHeaders()
    private var body: ByteBuffer = ByteBuffer(capacity: 0)

    public init() {}

    public func get(): HttpRequestBuilder { method = HttpMethod.GET; this }
    public func post(): HttpRequestBuilder { method = HttpMethod.POST; this }
    public func put(): HttpRequestBuilder { method = HttpMethod.PUT; this }
    public func delete(): HttpRequestBuilder { method = HttpMethod.DELETE; this }
    public func patch(): HttpRequestBuilder { method = HttpMethod.PATCH; this }
    public func head(): HttpRequestBuilder { method = HttpMethod.HEAD; this }
    public func options(): HttpRequestBuilder { method = HttpMethod.OPTIONS; this }
    public func connect(): HttpRequestBuilder { method = HttpMethod.CONNECT; this }
    public func trace(): HttpRequestBuilder { method = HttpMethod.TRACE; this }

    public func withUrl(u: String): HttpRequestBuilder {
        url = u
        this
    }

    public func withHeader(name: String, value: String): HttpRequestBuilder {
        headers.add(name, value)
        this
    }

    public func withBody(data: Array<UInt8>): HttpRequestBuilder {
        body = ByteBuffer(capacity: data.size)
        body.write(data)
        headers.set("Content-Length", "${data.size}")
        this
    }

    public func withJson(j: String): HttpRequestBuilder {
        let data = unsafe { j.rawData() }
        body = ByteBuffer(capacity: data.size)
        body.write(data)
        headers.set("Content-Type", "application/json")
        headers.set("Content-Length", "${data.size}")
        this
    }

    public func withForm(form: HashMap<String, String>): HttpRequestBuilder {
        let parts = ArrayList<String>()
        for ((key, value) in form) {
            parts.add("${key}=${formUrlEncode(value)}")
        }
        var encoded = ""
        var first = true
        for (part in parts) {
            if (first) { first = false }
            else { encoded += "&" }
            encoded += part
        }
        let data = unsafe { encoded.rawData() }
        body = ByteBuffer(capacity: data.size)
        body.write(data)
        headers.set("Content-Type", "application/x-www-form-urlencoded")
        headers.set("Content-Length", "${data.size}")
        this
    }

    /**
     * 从字段映射构建 multipart/form-data 主体。
     */
    public func withMultipart(fields: HashMap<String, MultipartField>): HttpRequestBuilder {
        let boundary = generateMultipartBoundary()
        let bodyData = buildMultipartBody(fields, boundary)
        body = ByteBuffer(capacity: bodyData.size)
        body.write(bodyData)
        headers.set("Content-Type", "multipart/form-data; boundary=${boundary}")
        headers.set("Content-Length", "${bodyData.size}")
        this
    }

    /**
     * 向 multipart 主体添加单个文件字段。
     * 重复使用此方法构建 multipart 上传，然后调用 build()。
     */
    public func withFile(name: String, fileName: String, data: Array<UInt8>, contentType!: String = "application/octet-stream"): HttpRequestBuilder {
        let fieldHeaders = HttpHeaders()
        fieldHeaders.set("Content-Type", contentType)
        let field = MultipartField(name, fileName: fileName, headers: fieldHeaders, data: data)

        let boundary = match (headers.get("content-type")) {
            case Some(ct) =>
                match (BodyParser.extractBoundary(ct)) {
                    case Some(b) => b
                    case None => generateMultipartBoundary()
                }
            case None => generateMultipartBoundary()
        }

        // 在 multipart 映射中累积字段
        // 为简化起见，重建整个 multipart 主体
        let fields = HashMap<String, MultipartField>()
        fields[name] = field
        let bodyData = buildMultipartBody(fields, boundary)
        body = ByteBuffer(capacity: bodyData.size)
        body.write(bodyData)
        headers.set("Content-Type", "multipart/form-data; boundary=${boundary}")
        headers.set("Content-Length", "${bodyData.size}")
        this
    }

    public func build(): HttpRequest {
        HttpRequest(method: method, url: url, headers: headers, body: body)
    }
}

/**
 * 为 Expect: 100-continue 构建仅含头部（无主体）的请求。
 * 收到 100 Continue 后将单独发送主体。
 */
private func buildHeadersOnlyRequest(request: HttpRequest): Array<UInt8> {
    let requestLineBytes = unsafe { request.buildRequestLine().rawData() }
    let headerBytes = request.headers.toBytes()
    let total = requestLineBytes.size + headerBytes.size + 2
    let result = Array<UInt8>(total, repeat: 0)
    var offset: Int64 = 0
    requestLineBytes.copyTo(result, 0, offset, requestLineBytes.size)
    offset += requestLineBytes.size
    if (headerBytes.size > 0) {
        headerBytes.copyTo(result, 0, offset, headerBytes.size)
        offset += headerBytes.size
    }
    result[offset] = b'\r'; offset += 1
    result[offset] = b'\n'
    result
}

/**
 * Write request body using 分块传输 encoding (RFC 7230 §4.1).
 */
private func writeChunkedBody(conn: Connection, request: HttpRequest): Unit {
    let bodyBytes = request.bodyAsBytes()
    if (bodyBytes.size == 0) {
        // 写入终止块："0\r\n\r\n"
        let terminator = ChunkedWriter.chunkTerminator()
        conn.write(terminator)
        return
    }
    let chunkedWriter = ChunkedWriter(conn)
    // 对于预缓冲的主体，我们可以将其作为单个块发送，
    // 或拆分为更小的块以进行流式传输。
    let chunkSize: Int64 = 8192  // 8KB 数据块
    var offset: Int64 = 0
    while (offset < bodyBytes.size) {
        let remaining = bodyBytes.size - offset
        let size = if (remaining > chunkSize) { chunkSize } else { remaining }
        let chunk = Array<UInt8>(size, repeat: 0)
        var i: Int64 = 0
        while (i < size) { chunk[i] = bodyBytes[offset + i]; i += 1 }
        chunkedWriter.writeChunk(chunk)
        offset += size
    }
    // 写入终止块
    let terminator = ChunkedWriter.chunkTerminator()
    conn.write(terminator)
    conn.flush()
}

// ---- 便捷函数 ----

// 默认全局客户端实例（惰性初始化）
private var _sharedClient: ?HttpClient = None

public func getSharedClient(): HttpClient {
    match (_sharedClient) {
        case Some(c) => c
        case None =>
            let c = HttpClient()
            _sharedClient = Some(c)
            c
    }
}

/**
 * 发送 GET 请求的便捷函数（使用默认客户端）。
 */
public func httpGet(url: String): HttpResponse {
    getSharedClient().get(url)
}

/**
 * 发送 POST 请求的便捷函数（使用默认客户端）。
 */
public func httpPost(url: String, body!: String = ""): HttpResponse {
    let bodyBytes = unsafe { body.rawData() }
    getSharedClient().post(url, body: bodyBytes)
}

/**
 * 发送 HEAD 请求的便捷函数（使用默认客户端）。
 */
public func httpHead(url: String): HttpResponse {
    getSharedClient().head(url)
}

/**
 * 发送 POST 表单请求的便捷函数（使用默认客户端）。
 * 自动设置 Content-Type: application/x-www-form-urlencoded。
 */
public func httpPostForm(url: String, formData: HashMap<String, String>): HttpResponse {
    getSharedClient().postForm(url, formData)
}


    /**
     * 读取连接上所有剩余数据直到 EOF。
     */
    private func readAllFromConn(conn: Connection): Array<UInt8> {
        let buf = ArrayList<UInt8>()
        let tmp = Array<UInt8>(4096, repeat: 0)
        while (true) {
            let n = conn.read(tmp)
            if (n <= 0) { break }
            var i: Int64 = 0
            while (i < n) { buf.add(tmp[i]); i = i + 1 }
        }
        buf.toArray()
    }
