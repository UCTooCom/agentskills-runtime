package http_lib.client

import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import std.sync.Mutex
import std.env.getVariable
import std.unicode.*
import http_lib.core.*
import http_lib.buffer.ByteBuffer
import http_lib.message.{HttpRequest, HttpResponse, HttpResponseParser, ChunkedDecoder, Compression}
import http_lib.utils.{ParsedUrl, findHeaderEnd, findCrlf, containsIgnoreCase}
import http_lib.connection.{Connection, TcpConnection, TlsConnection, TlsConfig}
import http_lib.http2.{Http2Connection, Http2FrameHeader, HTTP2_CLIENT_PREFACE_BYTES}
import std.collection.concurrent.ConcurrentHashMap
/**
 * HTTP 传输层（代理支持、超时配置、连接池）。
 *
 * 传输层。处理连接管理、代理隧道、
 * 超时配置以及请求执行，位于
 * 比 HttpClient 更低层的传输层。
 *
 * 用法：
 *   let transport = HttpTransport()
 *   transport.proxyUrl = Some("http://proxy:8080")
 *   transport.disableKeepAlive = true
 *   let resp = transport.execute(request)
 */

/**
 * Hop-by-hop 头部列表（RFC 7230 §6.1）。
 * 这些头部在代理转发时必须移除，不传递给下一跳。
 */
private let HOP_BY_HOP_HEADERS: Array<String> = [
    "Connection",
    "Keep-Alive",
    "Proxy-Authenticate",
    "Proxy-Authorization",
    "TE",
    "Trailer",
    "Transfer-Encoding",
    "Upgrade",
]

/**
 * 从 HttpHeaders 中移除所有 Hop-by-hop 头部。
 * 代理转发请求或响应时调用，防止跳跳头传递到下一跳。
 *
 * @param headers 要清理的头部集合（会被原地修改）
 */
public func removeHopByHopHeaders(headers: HttpHeaders): Unit {
    for (name in HOP_BY_HOP_HEADERS) {
        if (headers.contains(name)) {
            headers.remove(name)
        }
    }
    // 同时处理 Connection 头中声明的逐跳头
    match (headers.get("connection")) {
        case Some(connValue) =>
            let parts = connValue.split(",")
            for (part in parts) {
                let trimmed = part.trimAscii()
                if (trimmed.size > 0 && headers.contains(trimmed)) {
                    headers.remove(trimmed)
                }
            }
        case None => ()
    }
}


public class HttpTransport {
    // ---- 代理 ----
    public var proxyUrl: ?String = None
    public var proxyConnectHeader: HttpHeaders = HttpHeaders()

    // ---- 连接限制 ----
    public var maxIdleConnections: Int64 = 100
    public var maxIdleConnectionsPerHost: Int64 = 5
    public var maxConnectionsPerHost: Int64 = 10
    public var idleConnectionTimeout: Duration = Duration.second * 90

    // ---- 超时 ----
    public var connectTimeout: Duration = Duration.second * 30
    public var tlsTimeout: Duration = Duration.second * 10
    public var responseTimeout: Duration = Duration.second * 60
    public var continueTimeout: Duration = Duration.second * 1

    // ---- 标志 ----
    public var disableKeepAlive: Bool = false
    public var disableAutoDecompress: Bool = false
    public var forceHttp2: Bool = true

    // ---- TLS 连接 ----
    public var tlsConfig: TlsConfig = TlsConfig.default()

    /**
     * 返回实际用于建连的 TLS 配置。
     * 未启用 HTTP/2（forceHttp2=false）时，ALPN 只协商 "http/1.1"，
     * 避免服务器协商出 "h2" 后客户端却发送 HTTP/1.1 请求而被强制断连
     * （Windows 10054 "An existing connection was forcibly closed"）。
     */
    internal func effectiveTlsConfig(): TlsConfig {
        if (forceHttp2) {
            tlsConfig
        } else {
            let cfg = tlsConfig.copy()
            cfg.nextProtos = ["http/1.1"]
            cfg
        }
    }

    // ---- 自定义拨号器 ----
    public var dialer: ?(String, UInt16, Bool) -> Connection = None

    private var h2Connections: ConcurrentHashMap<String, Http2Connection> = ConcurrentHashMap<String, Http2Connection>()
    // ALT-SVC 缓存（RFC 7838）
    private var altSvcCache: HashMap<String, ArrayList<(String, Array<UInt8>)>> = HashMap<String, ArrayList<(String, Array<UInt8>)>>()
    // ---- 内部 ----
    private var idleConnectionPool: HashMap<String, ArrayList<PooledConnection>>
    private var activeConnectionCount: HashMap<String, Int64>
    private var noProxyPatterns: ArrayList<String>
    private var connMu: Mutex

    public init() {
        this.idleConnectionPool = HashMap<String, ArrayList<PooledConnection>>()
        this.activeConnectionCount = HashMap<String, Int64>()
        this.noProxyPatterns = ArrayList<String>()
        this.connMu = Mutex()
        // 从环境变量自动检测代理
        detectProxy()
    }

    /**
     * 从环境变量自动检测代理配置。
     * 按事实标准检查 HTTP_PROXY、HTTPS_PROXY 和 NO_PROXY。
     * 从环境变量检测代理设置。
     */
    private func detectProxy(): Unit {
        try {
            // HTTPS_PROXY 对 HTTPS URL 优先于 HTTP_PROXY
            let httpsProxy = detectEnvVar("HTTPS_PROXY")
            match (httpsProxy) {
                case Some(url) =>
                    proxyUrl = Some(url)
                case None => ()
            }
            // 若未设置 HTTPS_PROXY 则使用 HTTP_PROXY
            match (proxyUrl) {
                case None =>
                    let httpProxy = detectEnvVar("HTTP_PROXY")
                    match (httpProxy) {
                        case Some(url) =>
                            proxyUrl = Some(url)
                        case None => ()
                    }
                case Some(_) => ()
            }
            // 将 NO_PROXY 解析为模式
            let noProxy = detectEnvVar("NO_PROXY")
            match (noProxy) {
                case Some(value) =>
                    parseNoProxy(value)
                case None => ()
            }
        } catch (_: Exception) {}
    }

    /**
     * 将 NO_PROXY 逗号分隔值解析为模式列表。
     * 支持：域名、.domain（子域通配符）、*
     * localhost 始终排除于代理之外。
     */
    private func parseNoProxy(value: String): Unit {
        let parts = value.split(",")
        for (part in parts) {
            let cleanPart = part.trimAscii()
            if (cleanPart.size > 0) {
                noProxyPatterns.add(toLowerStr(cleanPart))
            }
        }
    }

    /**
     * 按 NO_PROXY 规则检查给定主机是否应排除于代理之外。
     * 
     *
     * 匹配规则：
     *   - "*" 匹配所有主机（不代理任何请求）
     *   - ".example.com" 匹配 example.com 的所有子域
     *   - "example.com" 匹配 example.com 及其所有子域
     *   - "localhost"（或任何环回地址）始终被排除
     */
    private func shouldUseProxy(host: String): Bool {
        match (proxyUrl) {
            case None => return false
            case Some(_) => ()
        }
        // localhost 始终跳过代理
        let lowerHost = toLowerStr(host)
        if (lowerHost == "localhost" || lowerHost == "127.0.0.1" || lowerHost == "::1") {
            return false
        }
        for (pattern in noProxyPatterns) {
            if (pattern == "*") {
                return false
            }
            // 模式 ".example.com" 匹配子域
            let patternRunes = pattern.toRuneArray()
            if (patternRunes.size > 0 && patternRunes[0] == r'.') {
                if (lowerHost.endsWith(pattern) || lowerHost == String(patternRunes[1..])) {
                    return false
                }
            } else {
                // 精确匹配或子域匹配
                if (lowerHost == pattern || lowerHost.endsWith(".${pattern}")) {
                    return false
                }
            }
        }
        true
    }

    /**
     * 平台特定的环境变量读取辅助函数。
     * 若环境变量访问不可用则优雅回退。
     */
    private func detectEnvVar(name: String): ?String {
        // 读取环境变量（先尝试大写，再回退到小写）
        match (getVariable(name)) {
            case Some(v) => Some(v)
            case None => getVariable(name.toLower())
        }
    }

    /**
     * RoundTrip 执行单个 HTTP 事务并返回响应。
     * 按 RFC 7230，请求主体（若有）会被完全消费。
     */
    public func execute(request: HttpRequest): HttpResponse {
        let parsedUrl = ParsedUrl.parse(request.url)
        let host = parsedUrl.host
        let port = parsedUrl.port
        let isSecure = parsedUrl.isSecure
        let path = parsedUrl.path

        // 连接错误时对幂等请求重试一次 
        let isIdempotent = _isIdempotentMethod(request.method)
        let maxRetries: Int64 = if (isIdempotent) { 1 } else { 0 }
        var retryCount: Int64 = 0
        var lastError: ?Exception = None

        while (true) {

        // 判断是否使用代理
        let useProxy = proxyUrl.isSome()
        // 检查 NO_PROXY —— 对排除的主机跳过代理
        let finalUseProxy = useProxy && shouldUseProxy(host)
        let proxyParsed: ?ParsedUrl = if (finalUseProxy) {
            let proxyStr = match (proxyUrl) {
                case Some(p) => p
                case None => ""
            }
            Some(ParsedUrl.parse(proxyStr))
        } else { None }
        let proxyHost = match (proxyParsed) { case Some(p) => p.host case None => "" }
        let proxyPort = match (proxyParsed) { case Some(p) => p.port case None => UInt16(0) }
        let connectHost = if (finalUseProxy) { proxyHost } else { host }
        let connectPort = if (finalUseProxy) { proxyPort } else { port }

        // 对于 HTTPS 经代理的连接，池键必须包含目标主机，
        // 因为 CONNECT 隧道绑定到特定目标。
        let isProxyTunnel = finalUseProxy && isSecure
        let poolKeySuffix = if (isProxyTunnel) {
            ":${host}:${port}"
        } else { "" }
        let poolKey = "${connectHost}:${connectPort}:${isSecure && !finalUseProxy}${poolKeySuffix}"
        // 原子地检查并递增活跃连接数，防止并发请求
        // 针对同一主机时的数据竞争。
        synchronized(connMu) {
            let activeCount = match (activeConnectionCount.get(poolKey)) {
                case Some(c) => c
                case None => Int64(0)
            }
            if (activeCount >= maxConnectionsPerHost) {
                throw HttpException("max connections per host (${maxConnectionsPerHost}) reached for ${connectHost}")
            }
            activeConnectionCount[poolKey] = activeCount + 1
        }

        // 对于 CONNECT 代理（HTTPS 经代理）：始终创建新的 TCP 连接
        // 到代理，建立 CONNECT 隧道，然后升级到 TLS。
        let connection = if (isProxyTunnel) {
            let tcpConn = TcpConnection.connect(connectHost, connectPort,
                connectTimeout: connectTimeout,
                readTimeout: responseTimeout,
                writeTimeout: connectTimeout)
            connectProxyTunnel(tcpConn, host, port)
            let tlsConn = TlsConnection(tcpConn, host, effectiveTlsConfig())
            tlsConn.setReadTimeout(responseTimeout)
            tlsConn.handshake()
            tlsConn
        } else {
            match (getIdleConnection(connectHost, connectPort, isSecure && !finalUseProxy, poolKeySuffix)) {
                case Some(conn) => conn
                case None => connectDirect(connectHost, connectPort, isSecure && !finalUseProxy)
            }
        }


        // 尝试 HTTP/2（若已启用且非代理隧道）
        if (forceHttp2 && !isProxyTunnel) {
            let h2Key = if (isSecure) { "${host}:${port}" } else { "h2c:${host}:${port}" }
            match (h2Connections.get(h2Key)) {
                case Some(h2conn) =>
                    if (h2conn.isConnected()) {
                        let h2resp = sendViaH2(h2conn, request, host, port, path, isSecure)
                        synchronized(connMu) {
                            match (activeConnectionCount.get(poolKey)) {
                                case Some(c) =>
                                    if (c <= 1) { activeConnectionCount.remove(poolKey) }
                                    else { activeConnectionCount[poolKey] = c - 1 }
                                case None => ()
                            }
                        }
                        return h2resp
                    }
                    h2Connections.remove(h2Key)
                case None => ()
            }
            // 尝试在新连接上升级/直接 H2
            var h2conn: ?Http2Connection = None
            if (isSecure) {
                h2conn = tryUpgradeToHttp2(connection, host, port)
            } else {
                h2conn = tryDirectH2c(connection, host, port)
            }
            match (h2conn) {
                case Some(h2c) =>
                    var finalH2 = h2c
                    synchronized(connMu) {
                        match (h2Connections.get(h2Key)) {
                            case Some(existing) =>
                                try { h2c.close() } catch (_: Exception) {}
                                finalH2 = existing
                            case None =>
                                h2Connections[h2Key] = h2c
                        }
                    }
                    let h2resp = sendViaH2(finalH2, request, host, port, path, isSecure)
                    synchronized(connMu) {
                        match (activeConnectionCount.get(poolKey)) {
                            case Some(c) =>
                                if (c <= 1) { activeConnectionCount.remove(poolKey) }
                                else { activeConnectionCount[poolKey] = c - 1 }
                            case None => ()
                        }
                    }
                    return h2resp
                case None => ()
            }
        }
        // 对于 HTTP 经代理：使用完整 URL 作为路径
        let effectivePath = if (finalUseProxy && !isSecure) {
            request.url
        } else {
            path
        }

        var reusable = false
        try {
            let wireReq = buildWireRequest(request, host, effectivePath)
            let bodyBytes = wireReq.bodyAsBytes()

            // 检查 Expect: 100-continue
            let hasExpect = match (wireReq.headers.get("expect")) {
                case Some(ev) =>
                    let evLower = toLowerStr(ev)
                    evLower.contains("100-continue")
                case None => false
            }

            if (hasExpect && bodyBytes.size > 0) {
                let headersOnly = buildHeadersOnlyReq(wireReq)
                connection.write(headersOnly)
                try {
                    connection.setReadTimeout(continueTimeout)
                    let interimResp = readTransportResponse(connection)
                    connection.setReadTimeout(responseTimeout)
                    if (interimResp.status.code != 100) {
                        return interimResp
                    }
                } catch (_: Exception) {
                    connection.setReadTimeout(responseTimeout)
                }
                connection.write(bodyBytes)
            } else {
                let fullReq = wireReq.toBytes()
                connection.write(fullReq)
            }

            connection.setReadTimeout(responseTimeout)
            let response = readTransportResponse(connection)

            reusable = if (!disableKeepAlive && !isProxyTunnel) {
                response.isKeepAlive() && connection.canReuseTransport()
            } else { false }

            // 如需要则解压缩
            if (!disableAutoDecompress) {
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
            }

            response
        } catch (e: Exception) {
            lastError = Some(e)
            if (retryCount < maxRetries && _isRetriableError(e)) {
                retryCount += 1
                continue  // 重试请求
            }
            reusable = false
            throw e
        } finally {
            synchronized(connMu) {
                match (activeConnectionCount.get(poolKey)) {
                    case Some(c) =>
                        if (c <= 1) { activeConnectionCount.remove(poolKey) }
                        else { activeConnectionCount[poolKey] = c - 1 }
                    case None => ()
                }
            }
            if (reusable) {
                returnToPool(connectHost, connectPort, isSecure && !finalUseProxy, connection, poolKeySuffix)
            } else {
                try { connection.close() } catch (_: Exception) {}
            }
        }
        }  // 结束重试循环

        // 不可达 —— 循环总是返回或抛出异常
        throw HttpException("execute: unexpected end of retry loop")
    }

    /**
     * 检查 HTTP 方法是否幂等（可安全重试）。
     * 按 RFC 7231：GET、HEAD、OPTIONS、TRACE 是安全的；PUT、DELETE 是幂等的。
     * POST、CONNECT、PATCH 不会自动重试。
     */
    private static func _isIdempotentMethod(method: HttpMethod): Bool {
        method == HttpMethod.GET || method == HttpMethod.HEAD ||
        method == HttpMethod.OPTIONS || method == HttpMethod.TRACE ||
        method == HttpMethod.PUT || method == HttpMethod.DELETE
    }

    /**
     * 检查错误是否可重试（瞬态网络错误）。
     * 连接拒绝、重置、超时 —— 重试。协议错误 —— 不重试。
     *
     * 使用异常消息前缀匹配，因为仓颉的 `is` 操作符可能
     * 在跨包异常类型解析时可能产生歧义。
     */
    private static func _isRetriableError(e: Exception): Bool {
        let msg = e.message
        // ConnectionException 和 TimeoutException 消息以这些模式开头
        msg.startsWith("Failed to connect") || msg.startsWith("Operation timed out")
    }

    /**
     * 关闭池中所有空闲连接。
     */
    public func cleanIdleConnections(): Unit {
        connMu.lock()
        let now = DateTime.now()
        let emptyKeys = ArrayList<String>()
        for ((key, conns) in idleConnectionPool) {
            var i = conns.size - 1
            while (i >= 0) {
                let pooled = conns[i]
                if (now - pooled.lastUsed > idleConnectionTimeout || !pooled.connection.canReuseTransport()) {
                    try { pooled.connection.close() } catch (_: Exception) {}
                    conns.remove(i..i + 1)
                }
                i -= 1
            }
            if (conns.size == 0) { emptyKeys.add(key) }
        }
        for (key in emptyKeys) { idleConnectionPool.remove(key) }
        connMu.unlock()
    }

    // ---- HTTP/2 支持 ----

    /**
     * 尝试将 TLS 连接升级到 HTTP/2。
     */
    private func tryUpgradeToHttp2(conn: Connection, host: String, port: UInt16): ?Http2Connection {
        // RFC 7540 §3.3 / RFC 7301: 客户端只能在 TLS ALPN 协商为 "h2" 时发送 HTTP/2 preface。
        // 若不检查协商结果而盲目发送 preface，服务器（未协商 h2）会把 preface 当作
        // 非法 HTTP/1.1 数据解析失败并强制关闭连接，表现为 Windows 10054/10053
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
     * 尝试建立直接 h2c 明文连接（RFC 9113 3.4）。
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
     * 通过 HTTP/2 连接发送请求并返回响应。
     */
    private func sendViaH2(h2conn: Http2Connection, request: HttpRequest, host: String, port: UInt16, path: String, isSecure: Bool): HttpResponse {
        var req = request
        let fullPath = if (path.startsWith("/")) { path } else { "/${path}" }
        if (request.url != fullPath) {
            req = HttpRequest(method: request.method, url: fullPath, version: HttpVersion.HTTP_2_0,
                headers: request.headers, body: request.body)
        }
        if (req.headers.get("host").isNone()) {
            req.headers.set("Host", host)
        }
        let streamId = h2conn.sendRequest(req)
        let response = h2conn.recvResponse(streamId)
        if (response.status.isSuccess()) {
            let peerAltSvc = h2conn.getPeerAltSvc()
            if (peerAltSvc.size > 0) {
                altSvcCache[host] = peerAltSvc
            }
        }
        if (!disableAutoDecompress) {
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
        }
        response
    }

    public func getAltSvcForHost(host: String): ArrayList<(String, Array<UInt8>)> {
        match (altSvcCache.get(host)) {
            case Some(altSvcs) => altSvcs
            case None => ArrayList<(String, Array<UInt8>)>()
        }
    }

    public func getAllAltSvc(): HashMap<String, ArrayList<(String, Array<UInt8>)>> {
        altSvcCache
    }

    public func closeAll(): Unit {
        connMu.lock()
        for ((_, conns) in idleConnectionPool) {
            for (pooled in conns) {
                try { pooled.connection.close() } catch (_: Exception) {}
            }
        }
        idleConnectionPool.clear()
        activeConnectionCount.clear()
        connMu.unlock()
    }

    // ---- 内部辅助函数 ----

    private func getIdleConnection(host: String, port: UInt16, isSecure: Bool, poolKeySuffix: String): ?Connection {
        var result: ?Connection = None
        synchronized(connMu) {
            let key = "${host}:${port}:${isSecure}${poolKeySuffix}"
            match (idleConnectionPool.get(key)) {
                case Some(conns) =>
                    let now = DateTime.now()
                    while (conns.size > 0) {
                        let lastIdx = conns.size - 1
                        let pooled = conns[lastIdx]
                        conns.remove(lastIdx..lastIdx + 1)
                        if (now - pooled.lastUsed > idleConnectionTimeout || !pooled.connection.canReuseTransport()) {
                            try { pooled.connection.close() } catch (_: Exception) {}
                            continue
                        }
                        pooled.touch()
                        result = Some(pooled.connection)
                        break
                    }
                    if (conns.size == 0) { idleConnectionPool.remove(key) }
                case None => ()
            }
        }
        result
    }

    private func returnToPool(host: String, port: UInt16, isSecure: Bool, conn: Connection, poolKeySuffix: String): Unit {
        synchronized(connMu) {
            // 在所有主机上强制执行总 maxIdleConnections
            let totalIdle = totalIdleConnections()
            if (totalIdle >= maxIdleConnections) {
                try { conn.close() } catch (_: Exception) {}
                return
            }
            let key = "${host}:${port}:${isSecure}${poolKeySuffix}"
            match (idleConnectionPool.get(key)) {
                case Some(conns) =>
                    if (conns.size >= maxIdleConnectionsPerHost) {
                        try { conn.close() } catch (_: Exception) {}
                    } else {
                        conns.add(PooledConnection(conn, host, port, isSecure))
                    }
                case None =>
                    let conns = ArrayList<PooledConnection>()
                    conns.add(PooledConnection(conn, host, port, isSecure))
                    idleConnectionPool[key] = conns
            }
        }
    }

    /**
     * 统计所有池中的空闲连接总数。
     * 注意：必须在持有 connMu 时调用（调用者负责）。
     */
    private func totalIdleConnections(): Int64 {
        var total: Int64 = 0
        for ((_, conns) in idleConnectionPool) {
            total += conns.size
        }
        total
    }

    /**
     * 为 HTTPS 目标通过 HTTP 代理建立 CONNECT 隧道。
     * 发送 CONNECT 主机:端口 HTTP/1.1 并读取响应。
     * 根据 RFC 7231 第 4.3.6 节。
     *
     * 在此成功返回后，连接是一个用于代理的原始 TCP 隧道
     * 到目标。调用方必须为 HTTPS 目标升级到 TLS。
     */
    private func connectProxyTunnel(conn: Connection, host: String, port: UInt16): Unit {
        var connectReq = "CONNECT ${host}:${port} HTTP/1.1\r\n"
        connectReq += "Host: ${host}:${port}\r\n"
        // 如果已配置则添加代理认证头部
        for ((name, value) in proxyConnectHeader.entries()) {
            connectReq += "${name}: ${value}\r\n"
        }
        connectReq += "\r\n"

        let connectBytes = unsafe { connectReq.rawData() }
        conn.write(connectBytes)
        conn.flush()

        // 读取代理的响应
        conn.setReadTimeout(responseTimeout)
        let resp = readTransportResponse(conn)

        // 200 表示隧道已建立
        if (resp.status.code != 200) {
            throw HttpException("proxy CONNECT tunnel failed: ${resp.status}")
        }
        // CONNECT 响应没有主体 — 连接现在是原始隧道
    }

    private func connectDirect(host: String, port: UInt16, isSecure: Bool): Connection {
        match (dialer) {
            case Some(dial) => return dial(host, port, isSecure)
            case None => ()
        }
        if (isSecure) {
            let tcpConn = TcpConnection.connect(host, port,
                connectTimeout: connectTimeout,
                readTimeout: responseTimeout,
                writeTimeout: connectTimeout)
            let tlsConn = TlsConnection(tcpConn, host, effectiveTlsConfig())
            tlsConn.handshake()
            tlsConn
        } else {
            TcpConnection.connect(host, port,
                connectTimeout: connectTimeout,
                readTimeout: responseTimeout,
                writeTimeout: connectTimeout)
        }
    }

    public func buildWireRequest(request: HttpRequest, host: String, path: String): HttpRequest {
        let fullUrl = if (path.startsWith("/")) { path } else { "/${path}" }
        let wireReq = HttpRequest(method: request.method, url: fullUrl, version: request.version,
            headers: request.headers, body: request.body)
        if (wireReq.headers.get("host").isNone()) { wireReq.headers.set("Host", host) }
        if (wireReq.headers.get("user-agent").isNone()) { wireReq.headers.set("User-Agent", "http_lib/0.1") }
        if (wireReq.headers.get("connection").isNone()) {
            if (disableKeepAlive || !wireReq.version.supportsPersistentConnection()) {
                wireReq.headers.set("Connection", "close")
            }
        }
        if (wireReq.headers.get("accept").isNone()) { wireReq.headers.set("Accept", "*/*") }
        if (!disableAutoDecompress && wireReq.headers.get("accept-encoding").isNone()) {
            wireReq.headers.set("Accept-Encoding", "gzip, deflate")
        }
        let bodyLen = wireReq.body.getLimit()
        if (bodyLen > 0 && wireReq.headers.get("content-length").isNone()) {
            wireReq.headers.set("Content-Length", "${bodyLen}")
        }
        wireReq
    }

    private func buildHeadersOnlyReq(request: HttpRequest): Array<UInt8> {
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

    public func readTransportResponse(conn: Connection): HttpResponse {
        let buffer = ByteBuffer(capacity: 4096)
        let scratch = Array<UInt8>(4096, repeat: 0)
        var headerEnd: Int64 = -1
        var totalRead: Int64 = 0

        while (headerEnd < 0) {
            let n = conn.read(scratch)
            if (n <= 0) { throw ProtocolException("connection closed by server") }
            buffer.write(scratch, 0, n)
            totalRead += n
            if (totalRead > 65536) { throw ProtocolException("response headers too large") }
            headerEnd = findHeaderEnd(buffer.getArray(), totalRead)
        }

        let data = buffer.getArray()
        let response = HttpResponseParser.parse(data[0..totalRead])
        let bodyStart = headerEnd

        let isChunked = match (response.headers.get("transfer-encoding")) {
            case Some(te) => toLowerStr(te).contains("chunked")
            case None => false
        }

        if (isChunked) {
            let prefetched = if (totalRead > bodyStart) {
                let len = totalRead - bodyStart
                let arr = Array<UInt8>(len, repeat: 0)
                var i: Int64 = 0
                while (i < len) { arr[i] = data[bodyStart + i]; i++ }
                arr
            } else { Array<UInt8>(0, repeat: 0) }
            let readerFn = {buf => conn.read(buf)}
            let decoded = ChunkedDecoder.readStreaming(readerFn, prefetched: prefetched)
            response.body = ByteBuffer.fromOwned(decoded)
        } else {
            match (response.headers.get("content-length")) {
                case Some(cl) =>
                    let contentLength = parseContentLength(cl)
                    let currentBody = totalRead - bodyStart
                    let remaining = contentLength - currentBody
                    if (remaining > 0) {
                        let moreData = readExactFromConn(conn, remaining)
                        response.body.write(moreData)
                    }
                case None =>
                    // 没有 Content-Length 和 Transfer-Encoding: chunked
                    // 根据 RFC 7230 第 3.3 节，当服务器关闭
                    // 连接时，剩余数据即为响应主体。
                    // 这适用于 HTTP/1.0 或 Connection: close 响应。
                    if (!response.isKeepAlive()) {
                        let tmp = Array<UInt8>(4096, repeat: 0)
                        while (true) {
                            let n = conn.read(tmp)
                            if (n <= 0) { break }
                            response.body.write(tmp, 0, n)
                        }
                    }
            }
        }
        response
    }

    private func readExactFromConn(conn: Connection, count: Int64): Array<UInt8> {
        let result = Array<UInt8>(count, repeat: 0)
        var totalRead: Int64 = 0
        let tempBuf = Array<UInt8>(4096, repeat: 0)
        while (totalRead < count) {
            let n = conn.read(tempBuf)
            if (n <= 0) { throw ProtocolException("connection closed while reading body") }
            var j: Int64 = 0
            let toCopy = if (count - totalRead < n) { count - totalRead } else { n }
            while (j < toCopy) { result[totalRead + j] = tempBuf[j]; j++ }
            totalRead += toCopy
        }
        result
    }

    /**
     * 流式执行单个 HTTP 事务，返回 StreamedHttpResponse。
     *
     * 与方法 execute() 不同，executeStream() 在解析完响应头后立即返回，
     * 底层连接保持打开状态，供调用方通过 StreamedHttpResponse 增量读取响应体。
     *
     * 适用于 SSE、大文件下载等需要流式处理的场景。
     * 注意：调用方必须在使用完毕后调用 StreamedHttpResponse.close() 释放连接。
     */
    public func executeStream(request: HttpRequest): StreamedHttpResponse {
        let parsedUrl = ParsedUrl.parse(request.url)
        let host = parsedUrl.host
        let port = parsedUrl.port
        let isSecure = parsedUrl.isSecure
        let path = parsedUrl.path

        // 判断是否使用代理
        let useProxy = proxyUrl.isSome()
        let finalUseProxy = useProxy && shouldUseProxy(host)
        let proxyParsed: ?ParsedUrl = if (finalUseProxy) {
            let proxyStr = match (proxyUrl) {
                case Some(p) => p
                case None => ""
            }
            Some(ParsedUrl.parse(proxyStr))
        } else { None }
        let proxyHost = match (proxyParsed) { case Some(p) => p.host case None => "" }
        let proxyPort = match (proxyParsed) { case Some(p) => p.port case None => UInt16(0) }
        let connectHost = if (finalUseProxy) { proxyHost } else { host }
        let connectPort = if (finalUseProxy) { proxyPort } else { port }
        let isProxyTunnel = finalUseProxy && isSecure
        let poolKeySuffix = if (isProxyTunnel) { ":${host}:${port}" } else { "" }
        let poolKey = "${connectHost}:${connectPort}:${isSecure && !finalUseProxy}${poolKeySuffix}"

        // 为流式连接创建一次性连接（不进入连接池）
        let connection = if (isProxyTunnel) {
            let tcpConn = TcpConnection.connect(connectHost, connectPort,
                connectTimeout: connectTimeout,
                readTimeout: responseTimeout,
                writeTimeout: connectTimeout)
            connectProxyTunnel(tcpConn, host, port)
            let tlsConn = TlsConnection(tcpConn, host, effectiveTlsConfig())
            tlsConn.setReadTimeout(responseTimeout)
            tlsConn.handshake()
            tlsConn
        } else {
            // 尝试从池中获取连接，否则新建
            match (getIdleConnection(connectHost, connectPort, isSecure && !finalUseProxy, poolKeySuffix)) {
                case Some(conn) => conn
                case None => connectDirect(connectHost, connectPort, isSecure && !finalUseProxy)
            }
        }

        // 尝试 HTTP/2（若已启用且非代理隧道）
        if (forceHttp2 && !isProxyTunnel) {
            let h2Key = if (isSecure) { "${host}:${port}" } else { "h2c:${host}:${port}" }
            match (h2Connections.get(h2Key)) {
                case Some(h2conn) =>
                    if (h2conn.isConnected()) {
                        let h2resp = sendViaH2(h2conn, request, host, port, path, isSecure)
                        let bodyBytes = h2resp.bodyAsBytes()
                        return StreamedHttpResponse(conn: connection, version: h2resp.version,
                            status: h2resp.status, headers: h2resp.headers,
                            prefetchedData: bodyBytes)
                    }
                    h2Connections.remove(h2Key)
                case None => ()
            }
            var h2conn: ?Http2Connection = None
            if (isSecure) {
                h2conn = tryUpgradeToHttp2(connection, host, port)
            } else {
                h2conn = tryDirectH2c(connection, host, port)
            }
            match (h2conn) {
                case Some(h2c) =>
                    var finalH2 = h2c
                    synchronized(connMu) {
                        match (h2Connections.get(h2Key)) {
                            case Some(existing) =>
                                try { h2c.close() } catch (_: Exception) {}
                                finalH2 = existing
                            case None =>
                                h2Connections[h2Key] = h2c
                        }
                    }
                    let h2resp = sendViaH2(finalH2, request, host, port, path, isSecure)
                    let bodyBytes = h2resp.bodyAsBytes()
                    return StreamedHttpResponse(conn: connection, version: h2resp.version,
                        status: h2resp.status, headers: h2resp.headers,
                        prefetchedData: bodyBytes)
                case None => ()
            }
        }

        // 对于 HTTP 经代理：使用完整 URL 作为路径
        let effectivePath = if (finalUseProxy && !isSecure) {
            request.url
        } else {
            path
        }

        try {
            let wireReq = buildWireRequest(request, host, effectivePath)
            let bodyBytes = wireReq.bodyAsBytes()

            // 检查 Expect: 100-continue
            let hasExpect = match (wireReq.headers.get("expect")) {
                case Some(ev) =>
                    let evLower = toLowerStr(ev)
                    evLower.contains("100-continue")
                case None => false
            }

            if (hasExpect && bodyBytes.size > 0) {
                let headersOnly = buildHeadersOnlyReq(wireReq)
                connection.write(headersOnly)
                try {
                    connection.setReadTimeout(continueTimeout)
                    let interimResp = readTransportResponse(connection)
                    connection.setReadTimeout(responseTimeout)
                    if (interimResp.status.code != 100) {
                        // 非 100 响应，返回流式包装
                        return buildStreamedResponse(connection, interimResp)
                    }
                } catch (_: Exception) {
                    connection.setReadTimeout(responseTimeout)
                }
                connection.write(bodyBytes)
            } else {
                let fullReq = wireReq.toBytes()
                connection.write(fullReq)
            }

            connection.setReadTimeout(responseTimeout)
            // 流式读取：解析头部即返回，保留连接供增量读取
            let streamedResp = readStreamHeaders(connection)
            streamedResp
        } catch (e: Exception) {
            try { connection.close() } catch (_: Exception) {}
            throw e
        }
    }

    /**
     * 流式读取响应头，不消费响应体。
     * 解析完头部后返回 StreamedHttpResponse，底层连接保持打开。
     */
    private func readStreamHeaders(conn: Connection): StreamedHttpResponse {
        let buffer = ByteBuffer(capacity: 4096)
        let scratch = Array<UInt8>(4096, repeat: 0)
        var headerEnd: Int64 = -1
        var totalRead: Int64 = 0

        while (headerEnd < 0) {
            let n = conn.read(scratch)
            if (n <= 0) { throw ProtocolException("服务器已关闭连接") }
            buffer.write(scratch, 0, n)
            totalRead += n
            if (totalRead > 65536) { throw ProtocolException("响应头过大") }
            headerEnd = findHeaderEnd(buffer.getArray(), totalRead)
        }

        let data = buffer.getArray()
        let response = HttpResponseParser.parse(data[0..totalRead])
        let bodyStart = headerEnd

        // 提取已预读的响应体数据（头部后的剩余字节）
        var prefetched: Array<UInt8> = []
        if (totalRead > bodyStart) {
            let len = totalRead - bodyStart
            let arr = Array<UInt8>(len, repeat: 0)
            var i: Int64 = 0
            while (i < len) { arr[i] = data[bodyStart + i]; i++ }
            prefetched = arr
        }

        StreamedHttpResponse(
            conn: conn,
            version: response.version,
            status: response.status,
            headers: response.headers,
            prefetchedData: prefetched
        )
    }

    /**
     * 从已读取的完整 HttpResponse 构建流式响应。
     * 用于 Expect: 100-continue 路径中非 100 响应的直接返回。
     */
    private func buildStreamedResponse(conn: Connection, resp: HttpResponse): StreamedHttpResponse {
        let bodyBytes = resp.bodyAsBytes()
        let prefetched = bodyBytes

        StreamedHttpResponse(
            conn: conn,
            version: resp.version,
            status: resp.status,
            headers: resp.headers,
            prefetchedData: prefetched
        )
    }



    /**
     * 执行 HTTP/1.1 管道请求（RFC 7230 §6.3.2）。
     * 在单个连接上发送多个请求，然后按顺序读取所有响应。
     *
     * 要求：
     * - 所有请求必须指向同一主机（host:port）
     * - 不支持 HTTP/2 升级（仅 HTTP/1.1）
     * - 不支持通过代理的管道（当前实现限制，未来可扩展）
     *
     * @param requests  同一主机的 HTTP 请求列表
     * @return 按发送顺序排列的 HTTP 响应列表
     * @throws HttpException 连接建立失败或响应格式错误时抛出
     */
    public func pipeline(requests: ArrayList<HttpRequest>): ArrayList<HttpResponse> {
        if (requests.size == 0) {
            return ArrayList<HttpResponse>()
        }

        // 以第一个请求为准建立连接
        let firstReq = requests[0]
        let parsedUrl = ParsedUrl.parse(firstReq.url)
        let host = parsedUrl.host
        let port = parsedUrl.port
        let isSecure = parsedUrl.isSecure
        let path = parsedUrl.path

        // 建立连接（当前仅支持直连，不支持代理隧道）
        let connection = connectDirect(host, port, isSecure)

        // 发送所有请求到连接
        for (req in requests) {
            let wireReq = buildWireRequest(req, host, path)
            let reqBytes = wireReq.toBytes()
            connection.write(reqBytes)
        }
        connection.flush()

        // 按发送顺序读取所有响应
        let responses = ArrayList<HttpResponse>()
        var reqIdx: Int64 = 0
        while (reqIdx < requests.size) {
            let resp = readTransportResponse(connection)

            // 自动解压缩（若启用）
            if (!disableAutoDecompress) {
                match (resp.headers.get("content-encoding")) {
                    case Some(ce) =>
                        if (ce.size > 0 && resp.body.getLimit() > 0) {
                            let decompressed = Compression.decompress(resp.bodyAsBytes(), ce)
                            let newBody = ByteBuffer(capacity: decompressed.size)
                            newBody.write(decompressed)
                            resp.body = newBody
                            resp.headers.remove("content-encoding")
                            resp.headers.set("Content-Length", "${decompressed.size}")
                        }
                    case None => ()
                }
            }

            responses.add(resp)
            reqIdx++
        }

        // 连接使用完毕，关闭
        try {
            connection.close()
        } catch (_: Exception) {}

        responses
    }
}


/**
 * 不区分大小写的 ASCII 字符串比较辅助函数。
 * 将 ASCII 范围内的 A-Z 原地转换为小写。
 * 提取为独立函数以便在
 * NO_PROXY 匹配和其他不区分大小写的比较。
 */
private func toLowerStr(s: String): String {
    let bytes = s.toArray()
    var i: Int64 = 0
    while (i < bytes.size) {
        if (bytes[i] >= b'A' && bytes[i] <= b'Z') { bytes[i] = bytes[i] + 32 }
        i += 1
    }
    unsafe { String.withRawData(bytes) }
}


/**
 * HTTP/1.1 管道连接上下文（RFC 7230 §6.3.2）。
 *
 * 在单个 HTTP/1.1 持久连接上发送多个请求而不等待响应，
 * 然后按顺序读取响应（FIFO）。
 *
 * 用法：
 *   let pipeline = Pipeline(transport, "https://example.com")
 *   pipeline.send(HttpRequest(method: HttpMethod.GET, url: "/resource1"))
 *   pipeline.send(HttpRequest(method: HttpMethod.GET, url: "/resource2"))
 *   let r1 = pipeline.recv()  // 按发送顺序读取响应
 *   let r2 = pipeline.recv()
 *   pipeline.close()
 *
 * 注意：管道仅适用于 HTTP/1.1（Connection: keep-alive）。
 * 不支持 HTTP/2。所有请求必须指向同一主机。
 */
public class Pipeline {
    private var conn: Connection
    private var transport: HttpTransport
    private var host: String
    private var pathPrefix: String
    private var closed: Bool = false
    private var requestCount: Int64 = 0
    private var responseCount: Int64 = 0

    /**
     * 创建管道连接上下文。
     * 自动建立到目标主机的 TCP/TLS 连接。
     *
     * @param transport 用于配置（超时、TLS、压缩设置）的 HttpTransport 实例
     * @param url       目标 URL（用于连接建立）
     * @throws HttpException 连接建立失败时抛出
     */
    public init(transport: HttpTransport, url: String) {
        this.transport = transport
        let parsedUrl = ParsedUrl.parse(url)
        this.host = parsedUrl.host
        this.pathPrefix = parsedUrl.path
        let port = parsedUrl.port
        let isSecure = parsedUrl.isSecure

        // 建立直连（不支持代理隧道）
        this.conn = if (isSecure) {
            let tcpConn = TcpConnection.connect(host, port,
                connectTimeout: transport.connectTimeout,
                readTimeout: transport.responseTimeout,
                writeTimeout: transport.connectTimeout)
            let tlsConn = TlsConnection(tcpConn, host, transport.effectiveTlsConfig())
            tlsConn.setReadTimeout(transport.responseTimeout)
            tlsConn.handshake()
            tlsConn
        } else {
            TcpConnection.connect(host, port,
                connectTimeout: transport.connectTimeout,
                readTimeout: transport.responseTimeout,
                writeTimeout: transport.connectTimeout)
        }
    }

    /**
     * 使用已有连接创建管道上下文（测试用）。
     *
     * @param conn      已建立的连接
     * @param transport 用于配置（超时、压缩设置）的 HttpTransport 实例
     * @param host      目标主机名
     */
    public init(conn: Connection, transport: HttpTransport, host: String) {
        this.conn = conn
        this.transport = transport
        this.host = host
        this.pathPrefix = "/"
    }

    /**
     * 在管道上发送一个 HTTP 请求。
     * 发送后不等待响应，后续应调用 recv() 读取。
     *
     * @param request 要发送的 HTTP 请求
     * @throws Exception 如果管道已关闭
     */
    public func send(request: HttpRequest): Unit {
        if (closed) { throw Exception("Pipeline is closed") }
        let path = if (request.url.startsWith("/")) { request.url } else { "/${request.url}" }
        let wireReq = transport.buildWireRequest(request, host, path)
        conn.write(wireReq.toBytes())
        requestCount++
    }

    /**
     * 从管道读取下一个 HTTP 响应。
     * 必须严格按照 send() 调用顺序读取。
     *
     * @return HTTP 响应
     * @throws Exception 管道已关闭或无待处理请求时抛出
     * @throws ProtocolException 响应格式错误时抛出
     */
    public func recv(): HttpResponse {
        if (closed) { throw Exception("Pipeline is closed") }
        if (responseCount >= requestCount) { throw Exception("No pending requests in pipeline") }
        let resp = transport.readTransportResponse(conn)
        responseCount++
        resp
    }

    /**
     * 关闭管道连接。
     */
    public func close(): Unit {
        if (closed) { return }
        closed = true
        try { conn.close() } catch (_: Exception) {}
    }

    /**
     * 检查管道是否已关闭。
     */
    public func isClosed(): Bool { closed }
}
