package http_lib.client
/**
 * HTTP 反向代理处理器。
 * 将收到的请求转发到后端服务器，把响应返回给原始客户端。
 */

import std.collection.ArrayList
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion, ProtocolException}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Handler
import http_lib.utils.ParsedUrl

/**
 * 要跳过的逐跳头部列表（RFC 7230 §6.1）。
 * 这些头部应由代理自身管理，不应转发到后端。
 */
private let HOP_BY_HOP_HEADERS: Array<String> = [
    "connection", "keep-alive", "proxy-authenticate",
    "proxy-authorization", "te", "trailer",
    "transfer-encoding", "upgrade"
]

/**
 * ReverseProxy 将传入的 HTTP 请求转发到后端服务器。
 *
 * 实现类似 Go `httputil.ReverseProxy` 的功能，
 * 适用于 API 网关、负载均衡等场景。
 *
 * 用法：
 *   let proxy = ReverseProxy("http://localhost:8080")
 *   proxy.modifyResponse = {req, resp =>
 *       resp.headers.set("X-Proxy", "http_lib")
 *       resp
 *   }
 *   router.get("/api/{path}", reverseProxyHandler(proxy))
 *
 * 特性：
 *   - 自动处理 X-Forwarded-For、X-Forwarded-Proto、X-Forwarded-Host
 *   - 移除逐跳头部
 *   - 自定义 ModifyResponse 钩子
 *   - 自定义 ErrorHandler 钩子
 *   - 连接池复用（通过 HttpClient）
 */
public class ReverseProxy {
    // ---- 配置 ----
    private var target: String          // 后端目标 URL
    private var httpClient: HttpClient  // 用于转发请求的客户端
    private var transport: HttpTransport

    /**
     * 可选的响应修改钩子。
     * 在转发后、返回前调用，用于修改后端响应。
     * 参数为原始请求和从后端接收到的响应。
     * 返回修改后的响应。
     */
    public var modifyResponse: ?(HttpRequest, HttpResponse) -> HttpResponse = None

    /**
     * 可选的错误处理钩子。
     * 当转发请求失败时调用。
     * 参数为原始请求和错误消息。
     * 应返回一个合适的 HTTP 错误响应。
     * 若未设置，默认返回 502 Bad Gateway。
     */
    public var errorHandler: ?(HttpRequest, String) -> HttpResponse = None

    /**
     * 可选的请求重写钩子。
     * 在转发前调用，用于自定义修改转发请求。
     * 参数为转发的请求（已设置 URL 和代理头部）。
     * 返回修改后的请求。
     */
    public var rewrite: ?(HttpRequest) -> HttpRequest = None

    /**
     * 创建指向目标后端的反向代理。
     * @param target 后端服务器 URL，例如 "http://localhost:8080"
     * @param httpClient 可选的自定义 HttpClient，默认使用新创建的客户端
     * @param transport 可选的自定义 HttpTransport，默认使用新建传输层
     */
    public init(
        target: String,
        httpClient!: HttpClient = HttpClient(),
        transport!: HttpTransport = HttpTransport()
    ) {
        this.target = target
        this.httpClient = httpClient
        this.transport = transport
    }

    /**
     * 处理传入请求并将其转发到后端。
     * 这是核心方法，由 Handler 调用。
     */
    public func handle(req: HttpRequest): HttpResponse {
        try {
            // 构建转发请求
            let proxyReq = buildProxyRequest(req)
            // 应用自定义重写钩子
            let finalReq = match (rewrite) {
                case Some(rw) => rw(proxyReq)
                case None => proxyReq
            }
            // 发送到后端
            let backendResp = httpClient.sendSingle(finalReq)
            // 应用自定义响应修改钩子
            match (modifyResponse) {
                case Some(mr) =>
                    try {
                        return mr(req, backendResp)
                    } catch (_: Exception) {
                        return backendResp
                    }
                case None => ()
            }
            backendResp
        } catch (e: Exception) {
            // 转发失败，调用错误处理器
            match (errorHandler) {
                case Some(eh) => eh(req, e.message)
                case None => buildErrorResponse(req, e.message)
            }
        }
    }

    /**
     * 构建转发到后端的请求。
     * 克隆原始请求的方法、头部和主体，
     * 将 URL 替换为目标后端 URL，
     * 设置代理头部，移除逐跳头部。
     */
    private func buildProxyRequest(req: HttpRequest): HttpRequest {
        let targetUrl = resolveTargetUrl(req.url)
        let proxyReq = HttpRequest(method: req.method, url: targetUrl, version: req.version)

        // 复制原始头部（过滤逐跳头部）
        let headerNames = req.headers.names()
        for (name in headerNames) {
            let lowerName = toLower(name)
            if (isHopByHop(lowerName)) { continue }
            match (req.headers.get(name)) {
                case Some(value) => proxyReq.headers.add(name, value)
                case None => ()
            }
        }

        // 复制主体
        if (req.body.getLimit() > 0) {
            proxyReq.body = req.body
        }

        // 设置代理头部
        setXForwardedFor(proxyReq, req)
        setXForwardedProto(proxyReq, req)
        setXForwardedHost(proxyReq, req)
        setForwarded(proxyReq, req)

        proxyReq
    }

    /**
     * 基于原始请求 URL 和目标后端 URL 解析最终目标 URL。
     */
    private func resolveTargetUrl(originalUrl: String): String {
        let targetParsed = ParsedUrl.parse(target)
        let origParsed = ParsedUrl.parse(originalUrl)

        // 保留原始路径和查询参数，替换主机和端口
        let scheme = if (targetParsed.isSecure) { "https" } else { "http" }
        let hostPort: String = if (targetParsed.port == UInt16(80) && !targetParsed.isSecure) {
            targetParsed.host
        } else if (targetParsed.port == UInt16(443) && targetParsed.isSecure) {
            targetParsed.host
        } else {
            "${targetParsed.host}:${targetParsed.port}"
        }

        "${scheme}://${hostPort}${origParsed.path}"
    }

    /**
     * 设置或追加 X-Forwarded-For 头部。
     */
    private func setXForwardedFor(proxyReq: HttpRequest, req: HttpRequest): Unit {
        let clientIp = extractClientIp(req)
        match (req.headers.get("x-forwarded-for")) {
            case Some(existing) => proxyReq.headers.set("X-Forwarded-For", "${existing}, ${clientIp}")
            case None => proxyReq.headers.set("X-Forwarded-For", clientIp)
        }
    }

    /**
     * 设置 X-Forwarded-Proto 头部（http 或 https）。
     */
    private func setXForwardedProto(proxyReq: HttpRequest, req: HttpRequest): Unit {
        if (proxyReq.headers.get("x-forwarded-proto").isNone()) {
            // 通过检查请求 URL 确定原始协议
            let parsed = ParsedUrl.parse(req.url)
            let proto = if (parsed.isSecure) { "https" } else { "http" }
            proxyReq.headers.set("X-Forwarded-Proto", proto)
        }
    }

    /**
     * 设置 X-Forwarded-Host 头部。
     */
    private func setXForwardedHost(proxyReq: HttpRequest, req: HttpRequest): Unit {
        match (req.headers.get("host")) {
            case Some(host) =>
                if (proxyReq.headers.get("x-forwarded-host").isNone()) {
                    proxyReq.headers.set("X-Forwarded-Host", host)
                }
            case None => ()
        }
    }

    /**
     * 尝试从请求中提取客户端 IP 地址。
     * 优先使用 X-Forwarded-For，其次使用 Connection 信息。
     */
    private static func extractClientIp(req: HttpRequest): String {
        // 优先尝试 Forwarded 头（RFC 7239）
        match (req.headers.get("forwarded")) {
            case Some(fwd) =>
                // 格式: Forwarded: for=<client-ip>;by=<proxy>;host=<host>
                let parts = fwd.split(";")
                for (part in parts) {
                    let trimmed = part.trimAsciiStart().trimAsciiEnd()
                    if (trimmed.startsWith("for=") || trimmed.startsWith("for=")) {
                        return trimmed[4..]
                    }
                }
            case None => ()
        }
        "127.0.0.1"
    }

    /**
     * 设置 RFC 7239 标准化的 Forwarded 头（覆盖旧值）。
     */
    private func setForwarded(proxyReq: HttpRequest, req: HttpRequest): Unit {
        let clientIp = extractClientIp(req)
        let parsed = ParsedUrl.parse(req.url)
        let proto = if (parsed.isSecure) { "https" } else { "http" }
        proxyReq.headers.set("Forwarded", "for=${clientIp};proto=${proto};host=${parsed.host}")
    }

    /**
     * 检查头部名称是否为逐跳头部。
     */
    private static func isHopByHop(name: String): Bool {
        let lowerName = toLower(name)
        for (hop in HOP_BY_HOP_HEADERS) {
            if (lowerName == hop) { return true }
        }
        false
    }

    /**
     * 构建 502 Bad Gateway 错误响应。
     */
    private static func buildErrorResponse(req: HttpRequest, message: String): HttpResponse {
        let headers = HttpHeaders()
        headers.set("Content-Type", "text/plain; charset=utf-8")
        headers.set("X-Content-Type-Options", "nosniff")
        let msg = "502 Bad Gateway: ${message}\n"
        let bodyBytes = unsafe { msg.rawData() }
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        HttpResponse(status: HttpStatus.BAD_GATEWAY, headers: headers, body: body)
    }

    /**
     * 将字符串转换为小写（ASCII）。
     */
    private static func toLower(s: String): String {
        let runes = s.toRuneArray()
        var i: Int64 = 0
        while (i < runes.size) {
            if (runes[i] >= r'A' && runes[i] <= r'Z') {
                runes[i] = Rune(UInt32(runes[i]) + 32)
            }
            i++
        }
        String(runes)
    }
}

/**
 * 将 ReverseProxy 实例转换为 Router Handler。
 * 用法：router.get("/api/{path}", reverseProxyHandler(proxy))
 */
public func reverseProxyHandler(proxy: ReverseProxy): Handler {
    { req: HttpRequest => proxy.handle(req) }
}
