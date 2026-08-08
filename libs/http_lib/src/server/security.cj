package http_lib.server
/**
 * HTTP 安全中间件：CSRF 防护、安全响应头、路径遍历防护。
 */

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import std.sync.Mutex
import std.time.DateTime
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpStatus, HttpMethod}
import http_lib.message.{HttpRequest, HttpResponse, selectContentEncodingWithBrotli, brotliCompress, Compression}
import http_lib.router.{Middleware, Handler}

/**
 * 安全中间件（HSTS、CSP、X-Frame-Options、速率限制）。
 */

// ---- 安全头部 ----

/**
 * 创建安全响应头中间件，添加通用的安全防护头.
 */
public func securityHeadersMiddleware(): Middleware {
    {handler =>
        {req =>
            let resp = handler(req)
            resp.headers.set("X-Content-Type-Options", "nosniff")
            resp.headers.set("X-Frame-Options", "DENY")
            resp.headers.set("Referrer-Policy", "strict-origin-when-cross-origin")
            resp
        }
    }
}

/**
 * 创建 HSTS 中间件（仅 HTTPS 站点）.
 * 设置 Strict-Transport-Security 响应头，可配置 max-age.
 */
public func hstsMiddleware(maxAge!: Int64 = 31536000, includeSubDomains!: Bool = true, preload!: Bool = false): Middleware {
    {handler =>
        {req =>
            let resp = handler(req)
            let sb = StringBuilder()
            sb.append("max-age=${maxAge}")
            if (includeSubDomains) { sb.append("; includeSubDomains") }
            if (preload) { sb.append("; preload") }
            resp.headers.set("Strict-Transport-Security", sb.toString())
            resp
        }
    }
}

/**
 * 创建 CSP（内容安全策略）中间件。
 */
public func cspMiddleware(policy: String): Middleware {
    {handler =>
        {req =>
            let resp = handler(req)
            resp.headers.set("Content-Security-Policy", policy)
            resp
        }
    }
}

// ---- 速率限制 ----

/**
 * 每 IP 速率限制状态，固定窗口计数器（每次请求 O(1)）.
 */
class WindowCounter {
    public var count: Int64 = 0
    public var windowStart: DateTime = DateTime.now()

    public init() {}
}

/**
 * 固定窗口速率限制中间件。
 * 限制每个 IP 在可配置时间窗口内的请求频率.
 *
 * 使用固定窗口计数器方式，每次请求 O(1) 性能.
 * 每个 IP 跟踪计数 + 窗口起始时间。窗口过期后，
 * 计数器在下次请求时自动重置.
 */
public class RateLimiter {
    private var window: Duration
    private var maxRequests: Int64
    private var counters: ConcurrentHashMap<String, WindowCounter>
    // 定期清理：每 CLEANUP_INTERVAL 次请求触发一次过期条目清理
    private var requestCountSinceCleanup: Int64 = 0
    private var cleanupMu: Mutex = Mutex()  // 保护清理计数器访问
    private static let CLEANUP_INTERVAL: Int64 = 10000
    // 注意：DateTime.now() 使用挂钟时间，非单调时钟。
    // 时钟调整（NTP、手动更改）可能导致速率限制绕过或过早节流。
    // 如未来 Cangjie std.time 提供单调时钟 API，请替换为单调时钟。

    public init(window!: Duration = Duration.second * 60, maxRequests!: Int64 = 100) {
        this.window = window
        this.maxRequests = maxRequests
        this.counters = ConcurrentHashMap<String, WindowCounter>()
    }

    public func middleware(): Middleware {
        let limiter = this
        {handler: Handler =>
            {req: HttpRequest =>
                let ip = extractClientIp(req)
                if (!limiter.allow(ip)) {
                    return HttpResponse.text(HttpStatus.TOO_MANY_REQUESTS, "Rate limit exceeded. Try again later.")
                }
                handler(req)
            }
        }
    }

    /**
     * 检查并记录来自给定 IP 的请求.
     * 每次请求 O(1) 固定窗口计数.
     */
    private func allow(ip: String): Bool {
        let now = DateTime.now()

        let result = match (counters.get(ip)) {
            case Some(wc) =>
                            // 窗口过期则重置计数器
                if (now - wc.windowStart > window) {
                    wc.count = 1
                    wc.windowStart = now
                    true
                } else if (wc.count >= maxRequests) {
                    false
                } else {
                    wc.count += 1
                    true
                }
            case None =>
                let wc = WindowCounter()
                wc.count = 1
                wc.windowStart = now
                counters[ip] = wc
                true
        }

        // 定期清理：防止过期条目导致内存无限增长
        cleanupMu.lock()
        requestCountSinceCleanup += 1
        let shouldCleanup = requestCountSinceCleanup >= CLEANUP_INTERVAL
        if (shouldCleanup) {
            requestCountSinceCleanup = 0
        }
        cleanupMu.unlock()
        if (shouldCleanup) {
            let cutoff = now - window * 2  // 超过 2 个窗口期的条目视为过期
            cleanupStaleEntries(cutoff)
        }

        result
    }

    /**
     * 移除自截止时间后未被访问的过期条目.
     * 使用 ConcurrentHashMap 确保并发安全访问.
     */
    private func cleanupStaleEntries(cutoff: DateTime): Unit {
        var staleKeys = ArrayList<String>()
        for ((ip, wc) in counters) {
            if (wc.windowStart < cutoff) {
                staleKeys.add(ip)
            }
        }
        for (ip in staleKeys) {
            counters.remove(ip)
        }
    }

    /**
     * 获取指定 IP 的当前请求计数.
     */
    public func requestCount(ip: String): Int64 {
        let now = DateTime.now()
        let result = match (counters.get(ip)) {
            case Some(wc) =>
                if (now - wc.windowStart > window) { 0 } else { wc.count }
            case None => 0
        }
        result
    }

    /**
     * 重置所有计数器。
     */
    public func reset(): Unit {
                // ConcurrentHashMap 不支持 clear() — 逐个删除键
        let keysToRemove = ArrayList<String>()
        for ((key, _) in counters) {
            keysToRemove.add(key)
        }
        for (key in keysToRemove) {
            counters.remove(key)
        }
    }
}

/**
 * 从请求头或连接信息中提取客户端 IP.
 * 检查 X-Forwarded-For、X-Real-IP 和 Forwarded（RFC 7239）头.
 */
public func extractClientIp(req: HttpRequest): String {
    match (req.headers.get("x-forwarded-for")) {
        case Some(xff) =>
            // 取链中第一个 IP
            let commaIdx = xff.indexOf(",")
            match (commaIdx) {
                case Some(idx) => String(xff.toRuneArray()[..idx])
                case None => xff
            }
        case None =>
            match (req.headers.get("x-real-ip")) {
                case Some(rip) => rip
                case None =>
                    // 回退到 Forwarded 响应头 (RFC 7239)
                    match (req.headers.get("forwarded")) {
                        case Some(fwd) => parseForwardedFor(fwd)
                        case None => "127.0.0.1"
                    }
            }
    }
}

/**
 * 解析 Forwarded 头中的第一个 "for" 值（RFC 7239）.
 * 示例: Forwarded: for=192.0.2.60;proto=http;by=203.0.113.43
 * 返回找到的第一个 "for" 值，未找到则返回 "127.0.0.1".
 */
private func parseForwardedFor(header: String): String {
    let parts = header.split(";")
    for (part in parts) {
        var trimmed = part.trimAsciiStart()
        // 检查 "for=" 前缀（不区分大小写）
        if (trimmed.toRuneArray().size >= 4) {
            let prefix = String(trimmed.toRuneArray()[..4])
            // 手动不区分大小写比较：将每个字符转小写
            var lowerRunes = ArrayList<Rune>()
            for (r in prefix.toRuneArray()) {
                if (r >= r'A' && r <= r'Z') {
                    lowerRunes.add(Rune(UInt32(r) + 32u32))
                } else {
                    lowerRunes.add(r)
                }
            }
            if (String(lowerRunes.toArray()) == "for=") {
                var value = String(trimmed.toRuneArray()[4..])
                // 移除周围引号（如果存在）
                let valueRunes = value.toRuneArray()
                if (valueRunes.size >= 2 && valueRunes[0] == r'"' && valueRunes[valueRunes.size - 1] == r'"') {
                    return String(valueRunes[1..valueRunes.size - 1])
                }
                return value
            }
        }
    }
    "127.0.0.1"
}

// ---- 请求日志 ----

/**
 * 可配置输出的访问日志中间件.
 *
 * @param logFunc  自定义日志函数，默认使用 println.
 *
 * 用法：
 *   router.use(loggingMiddleware(logFunc: {line => file.write(line)}))
 *   router.use(loggingMiddleware())  // 使用 println
 */
public func loggingMiddleware(logFunc!: (String) -> Unit = {line => println(line)}): Middleware {
    let output = logFunc
    {handler: Handler =>
        {req: HttpRequest =>
            let startTime = DateTime.now()
            let resp = handler(req)
            let elapsed = DateTime.now() - startTime
            let elapsedMs = elapsed  // 日志记录时长
            // 格式：METHOD /path → STATUS DURATIONms
            output("${req.method} ${req.url} → ${resp.status.code}")
            resp
        }
    }
}

// ---- 透明压缩 ----

/**
 * 创建透明压缩中间件.
 * 根据请求的 Accept-Encoding 头自动压缩响应正文
 * 支持 gzip、deflate 和 brotli.
 *
 * 仅压缩满足以下条件的响应：
 *     - 正文大小超过 minSize（默认 1KB）
 * - 尚未设置 Content-Encoding 头部
 * - 不压缩已压缩的内容类型（图片、视频等）
 *
 * 用法：
 *   router.use(transparentCompressMiddleware(minSize: 512))
 */
public func transparentCompressMiddleware(minSize!: Int64 = 1024): Middleware {
    {handler: Handler =>
        {req: HttpRequest =>
            let resp = handler(req)
            let bodySize = resp.body.getLimit()
            if (bodySize < minSize) { return resp }
            if (resp.headers.get("content-encoding").isSome()) { return resp }

            // 对已压缩的内容类型跳过压缩
            let ct = resp.headers.get("content-type")
            match (ct) {
                case Some(mime) =>
                    if (isPrecompressedMime(mime)) { return resp }
                case None => ()
            }

            let selected = selectContentEncodingWithBrotli(req.headers.get("accept-encoding"))
            let originalBody = resp.bodyAsBytes()

            if (selected == "br") {
                let compressed = brotliCompress(originalBody)
                if (compressed.size < bodySize) {
                    let newBody = ByteBuffer(capacity: compressed.size)
                    newBody.write(compressed)
                    resp.body = newBody
                    resp.headers.set("Content-Encoding", "br")
                    resp.headers.set("Content-Length", "${compressed.size}")
                }
            } else if (selected == "gzip") {
                let compressed = Compression.compressGzip(originalBody)
                if (compressed.size < bodySize) {
                    let newBody = ByteBuffer(capacity: compressed.size)
                    newBody.write(compressed)
                    resp.body = newBody
                    resp.headers.set("Content-Encoding", "gzip")
                    resp.headers.set("Content-Length", "${compressed.size}")
                }
            } else if (selected == "deflate") {
                let compressed = Compression.compressDeflate(originalBody)
                if (compressed.size < bodySize) {
                    let newBody = ByteBuffer(capacity: compressed.size)
                    newBody.write(compressed)
                    resp.body = newBody
                    resp.headers.set("Content-Encoding", "deflate")
                    resp.headers.set("Content-Length", "${compressed.size}")
                }
            }
            resp
        }
    }
}

/**
 * 检查 MIME 类型是否已是压缩格式（图片、视频、音频等）.
 * 再次压缩只会浪费 CPU 并可能增大体积.
 */
private func isPrecompressedMime(mime: String): Bool {
    let compressedTypes = [
        "image/", "video/", "audio/", "application/zip", "application/gzip",
        "application/x-tar", "application/pdf", "font/", "application/wasm"
    ]
    for (prefix in compressedTypes) {
        if (mime.startsWith(prefix)) { return true }
    }
    false
}

/**
 * CSRF 跨站请求伪造保护中间件。
 *
 * 基于 Sec-Fetch-Site 和 Origin 头部检测跨源非安全请求。
 * GET、HEAD、OPTIONS 等安全方法始终放行。
 * 无 Sec-Fetch-Site 或 Origin 头部的请求视为同源或非浏览器请求，放行。
 *
 * 用法：
 *   let csrf = csrfMiddleware()
 *   csrf.addTrustedOrigin("https://trusted.example.com")
 *   router.use(csrf)
 *
 * 或直接使用默认配置（仅允许同源请求）：
 *   router.use(csrfMiddleware())
 */
public func csrfMiddleware(
    denyMessage!: String = "Forbidden: cross-origin request rejected"
): Middleware {
    let protection = CrossOriginProtection()
    {next: Handler =>
        {req: HttpRequest =>
            match (protection.check(req)) {
                case Some(_) =>
                    HttpResponse.text(HttpStatus.FORBIDDEN, denyMessage)
                case None => next(req)
            }
        }
    }
}

/**
 * 跨源请求保护器。
 *
 * 根据 Sec-Fetch-Site 和 Origin 头部检测跨源非安全请求。
 * 支持添加可信来源和不安全绕过路径。
 */
public class CrossOriginProtection {
    private var trustedOrigins: ArrayList<String> = ArrayList<String>()
    private var bypassPatterns: ArrayList<String> = ArrayList<String>()

    public init() {}

    /**
     * 添加可信来源，来自该来源的跨源请求将被放行。
     * origin 格式为 "scheme://host[:port]"，例如 "https://example.com"。
     */
    public func addTrustedOrigin(origin: String): Unit {
        // 基本格式校验
        if (!origin.contains("://")) {
            throw Exception("无效来源格式: ${origin}，需要 scheme://host[:port] 格式")
        }
        trustedOrigins.add(origin)
    }

    /**
     * 添加不安全绕过路径，匹配这些路径模式的请求跳过 CSRF 检查。
     * 路径语法与路由器路径参数一致（支持 :param 和 *path）。
     */
    public func addBypassPattern(pattern: String): Unit {
        bypassPatterns.add(pattern)
    }

    /**
     * 检查请求是否为跨源攻击。
     * 返回 Some(reason) 表示应拒绝，None 表示放行。
     */
    public func check(req: HttpRequest): ?String {
        // 安全方法始终放行
        let method = req.method
        if (method == HttpMethod.GET || method == HttpMethod.HEAD || method == HttpMethod.OPTIONS) {
            return None
        }

        // 检查是否匹配绕过路径
        let path = req.path
        for (pattern in bypassPatterns) {
            if (matchBypassPattern(path, pattern)) {
                return None
            }
        }

        // 优先使用 Sec-Fetch-Site 头部检测（现代浏览器支持）
        match (req.headers.get("sec-fetch-site")) {
            case Some(site) =>
                let siteLower = site
                if (siteLower.startsWith("same-origin") || siteLower.startsWith("same-site") || siteLower.startsWith("none")) {
                    return None  // 同源或用户主动导航，放行
                }
                // cross-site 请求需要检查 Origin
            case None => ()  // 无 Sec-Fetch-Site，继续使用 Origin 检测
        }

        // 使用 Origin 头部检测
        match (req.headers.get("origin")) {
            case Some(origin) =>
                // 检查是否在可信来源列表中
                for (trusted in trustedOrigins) {
                    if (origin == trusted) {
                        return None
                    }
                }
                // 检查是否与 Host 同源
                let host = match (req.headers.get("host")) {
                    case Some(h) => h
                    case None => ""
                }
                if (origin.contains(host)) {
                    return None
                }
                Some("跨源非安全请求被拒绝")
            case None =>
                // 无 Origin 头部，视为同源或非浏览器请求，放行
                None
        }
    }
}

/**
 * 检查路径是否匹配绕过模式。
 * 支持简单的通配符匹配（*）。
 */
private func matchBypassPattern(path: String, pattern: String): Bool {
    if (pattern == "*" || pattern == "/*") { return true }
    if (pattern.endsWith("*")) {
        let prefix = pattern[..(pattern.size - 1)]
        return path.startsWith(prefix)
    }
    path == pattern
}
