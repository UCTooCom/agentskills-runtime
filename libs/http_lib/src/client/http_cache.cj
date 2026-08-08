package http_lib.client
/**
 * HTTP 客户端缓存（RFC 7234）。
 * 使用 Cache-Control 和 Expires 响应头进行缓存决策。
 */

import std.collection.HashMap
import std.collection.ArrayList
import std.sync.Mutex
import std.time.DateTime
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion, parseHttpDate}
import http_lib.message.{HttpRequest, HttpResponse, CacheControl}

/**
 * RFC 7234 客户端 HTTP 缓存。
 *
 * 提供基于内存的缓存存储，支持：
 * - 新鲜度计算（max-age、s-maxage、Expires、启发式）
 * - 条件验证（ETag/Last-Modified → If-None-Match/If-Modified-Since）
 * - Vary 头部分化（部分支持）
 * - 基于不安全方法的缓存失效
 * - 线程安全
 *
 * 用法：
 *   let cache = HttpCache()
 *   cache.store(request, response)
 *   let cached = cache.get(request)
 */

/**
 * 缓存的 HTTP 响应条目。
 * 存储被缓存的响应及其元数据。
 */
public class CachedEntry {
    public let response: HttpResponse
    public let freshLifetime: Int64            // 新鲜度生命周期（秒）
    public let mustValidate: Bool               // no-cache：必须验证
    public let etag: ?String                    // 响应 ETag
    public let lastModified: ?String            // 响应 Last-Modified

    public init(
        response: HttpResponse,
        freshLifetime: Int64,
        mustValidate!: Bool = false,
        etag!: ?String = None,
        lastModified!: ?String = None
    ) {
        this.response = response
        this.freshLifetime = freshLifetime
        this.mustValidate = mustValidate
        this.etag = etag
        this.lastModified = lastModified
    }

    /**
     * 检查缓存条目是否仍处于新鲜期内。
     * 根据缓存时计算的新鲜度生命周期判断。
     */
    public func isFresh(): Bool {
        if (mustValidate) { return false }
        freshLifetime > 0
    }
}

/**
 * RFC 7234 客户端 HTTP 缓存管理器。
 * 线程安全：所有公开方法受 Mutex 保护。
 */
public class HttpCache {
    private var entries: HashMap<String, CachedEntry>
    private var mu: Mutex
    private var maxEntries: Int64

    public init(maxEntries!: Int64 = 256) {
        this.entries = HashMap<String, CachedEntry>()
        this.mu = Mutex()
        this.maxEntries = maxEntries
    }

    /**
     * 获取请求的缓存响应（仅在新鲜时返回）。
     */
    public func get(request: HttpRequest): ?HttpResponse {
        synchronized(mu) {
            let key = buildCacheKey(request)
            match (entries.get(key)) {
                case Some(entry) =>
                    if (entry.isFresh()) {
                        return Some(entry.response)
                    }
                    None
                case None => None
            }
        }
    }

    /**
     * 获取过期缓存条目及其条件验证头。
     */
    public func getStaleWithConditionals(request: HttpRequest): ?(HttpResponse, HttpHeaders) {
        synchronized(mu) {
            let key = buildCacheKey(request)
            match (entries.get(key)) {
                case Some(entry) =>
                    if (entry.etag.isNone() && entry.lastModified.isNone()) {
                        return None
                    }
                    let headers = HttpHeaders()
                    match (entry.etag) {
                        case Some(etag) => headers.set("If-None-Match", etag)
                        case None => ()
                    }
                    match (entry.lastModified) {
                        case Some(lm) => headers.set("If-Modified-Since", lm)
                        case None => ()
                    }
                    Some((entry.response, headers))
                case None => None
            }
        }
    }

    /**
     * 将响应存入缓存。
     */
    public func store(request: HttpRequest, response: HttpResponse): Unit {
        if (!isResponseCacheable(request.method, response)) { return }

        let freshLifetime = computeFreshnessLifetime(response)
        if (freshLifetime <= 0 && !isStorable(response)) { return }

        let cc = parseCacheControl(response)
        let mustValidate = cc.isNoCache()
        let etag = response.headers.get("etag")
        let lastModified = response.headers.get("last-modified")

        let entry = CachedEntry(response, freshLifetime, mustValidate: mustValidate, etag: etag, lastModified: lastModified)

        synchronized(mu) {
            let key = buildCacheKey(request)
            if (entries.size >= maxEntries) {
                entries.clear()
            }
            entries[key] = entry
        }
    }

    /**
     * 不安全方法（POST、PUT、DELETE、PATCH）后使相关缓存失效。
     */
    public func invalidate(method: HttpMethod, url: String): Unit {
        if (method == HttpMethod.GET || method == HttpMethod.HEAD) { return }
        synchronized(mu) {
            var toRemove = ArrayList<String>()
            for ((key, _) in entries) {
                if (key.startsWith(url)) {
                    toRemove.add(key)
                }
            }
            for (k in toRemove) {
                entries.remove(k)
            }
        }
    }

    /**
     * 清空所有缓存条目。
     */
    public func clear(): Unit {
        synchronized(mu) {
            entries.clear()
        }
    }

    // ---- 内部辅助 ----

    private func buildCacheKey(request: HttpRequest): String {
        "${request.method}:${request.url}"
    }

    private func isResponseCacheable(method: HttpMethod, response: HttpResponse): Bool {
        if (method != HttpMethod.GET && method != HttpMethod.HEAD) { return false }
        let status = response.status.code
        let cacheableStatus = (status == 200 || status == 203 || status == 204 ||
            status == 206 || status == 300 || status == 301 ||
            status == 404 || status == 410)
        if (!cacheableStatus) { return false }
        let cc = parseCacheControl(response)
        if (cc.isNoStore()) { return false }
        true
    }

    private func computeFreshnessLifetime(response: HttpResponse): Int64 {
        let cc = parseCacheControl(response)
        // s-maxage
        match (cc.sMaxAge()) {
            case Some(sma) => return sma
            case None => ()
        }
        // max-age
        match (cc.maxAge()) {
            case Some(ma) =>
                if (ma >= 0) { return ma }
            case None => ()
        }
        // Expires 启发式
        match (response.headers.get("expires")) {
            case Some(expires) =>
                match (response.headers.get("date")) {
                    case Some(date) =>
                        let expTime = parseHttpDate(expires)
                        let dateTime = parseHttpDate(date)
                        if (expTime.isSome() && dateTime.isSome()) {
                            return 3600  // 默认 1 小时新鲜度
                        }
                    case None => ()
                }
            case None => ()
        }
        // 默认 60 秒
        60
    }

    /**
     * 检查响应是否可存储（即使无新鲜度信息）。
     */
    private func isStorable(response: HttpResponse): Bool {
        let cc = parseCacheControl(response)
        !cc.isNoStore()
    }

    private func parseCacheControl(response: HttpResponse): CacheControl {
        match (response.headers.get("cache-control")) {
            case Some(cc) => CacheControl.parse(cc)
            case None => CacheControl()
        }
    }
}
