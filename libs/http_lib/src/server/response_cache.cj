package http_lib.server
/**
 * 服务端响应缓存中间件。按请求 URI 缓存响应以加速后续请求。
 */

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import std.sync.Mutex
import http_lib.core.parseDecimal
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.{Handler, Middleware, MiddlewareChain}

/**
 * 带过期时间的缓存响应条目。
 */
internal class CacheEntry {
    let response: HttpResponse
    let expiresAt: DateTime

    public init(response!: HttpResponse, ttl!: Duration) {
        this.response = response
        this.expiresAt = DateTime.now() + ttl
    }

    public func isExpired(): Bool {
        DateTime.now() > expiresAt
    }
}

/**
 * 跟踪缓存响应的 Vary 头信息。
 */
internal class VaryInfo {
    let headerNames: Array<String>
    let headerValues: Array<String>

    public init(headerNames!: Array<String>, headerValues!: Array<String>) {
        this.headerNames = headerNames
        this.headerValues = headerValues
    }
}

/**
 * 受 RFC 7234 启发的 GET 请求响应缓存。
 *
 * 提供简单内存缓存，具有以下特性：
 *   - 缓存 GET 请求的响应
 *   - 遵守 maxSize（最大缓存条目数）
 *   - 遵守 ttl（每个条目的生存时间）
 *   - 缓存满时使用 LRU 淘汰
 *   - 支持 Vary 头以进行差异化缓存
 *   - 遵守每个响应的 Cache-Control max-age/s-maxage
 *   - 提供中间件以便与 Router 轻松集成
 *   - 访问时自动淘汰过期条目
 *
 * 用法：
 *   let cache = ResponseCache(maxSize: 100, ttl: Duration.minute * 5)
 *   router.use(cache.middleware())
 */
public class ResponseCache {
    private var store: HashMap<String, CacheEntry>
    private var accessOrder: ArrayList<String>
    private var varyIndex: HashMap<String, ArrayList<String>>
    private var varyInfo: HashMap<String, VaryInfo>
    private var maxSize: Int64
    private var ttl: Duration
    private var mu: Mutex

    /**
     * 创建新的响应缓存。
     *
     * @param maxSize  缓存中最大条目数
     * @param ttl      每个缓存响应的默认生存时间
     */
    public init(maxSize!: Int64 = 1000, ttl!: Duration = Duration.minute * 5) {
        this.store = HashMap<String, CacheEntry>()
        this.accessOrder = ArrayList<String>()
        this.varyIndex = HashMap<String, ArrayList<String>>()
        this.varyInfo = HashMap<String, VaryInfo>()
        this.maxSize = maxSize
        this.ttl = ttl
        this.mu = Mutex()
    }

    /**
     * 在互斥锁保护下执行操作，确保异常时正确解锁。
     */
    private func _withLock<T>(action: () -> T): T {
        mu.lock()
        try {
            let result = action()
            mu.unlock()
            result
        } catch (e: Exception) {
            mu.unlock()
            throw e
        }
    }

    /**
     * 按缓存键查找缓存响应。
     * 若找到且未过期则返回响应的深拷贝，否则返回 None。
     *
     * @param key  缓存键（通常为请求 URL 路径 + 查询）
     * @return 缓存响应（深拷贝），若未找到或过期则返回 None
     */
    public func get(key: String): ?HttpResponse {
        _withLock({ =>
            match (store.get(key)) {
                case Some(entry) =>
                    if (entry.isExpired()) {
                        store.remove(key)
                        removeFromAccessOrder(key)
                        None
                    } else {
                        touch(key)
                        // 深拷贝防止缓存污染
                        Some(deepCopyResponse(entry.response))
                    }
                case None => None
            }
        })
    }

    /**
     * 将响应存储到缓存中。
     * 若缓存已满则淘汰 LRU 条目。
     *
     * @param key      缓存键（通常为请求 URL 路径 + 查询）
     * @param response 要缓存的响应
     */
    public func set(key: String, response: HttpResponse): Unit {
        _withLock({ =>
            if (store.size >= maxSize) {
                evictOneLocked()
            }
            let effectiveTtl = parseResponseMaxAge(response) ?? ttl
            store[key] = CacheEntry(response: deepCopyResponse(response), ttl: effectiveTtl)
            addToAccessOrder(key)
        })
    }

    /**
     * Vary 感知的缓存查找。先检查按 Vary 索引的条目，
     * 若未找到 Vary 匹配则回退到基础键。
     *
     * @param key      基础缓存键（请求 URL）
     * @param request  HTTP 请求 (used for Vary header matching)
     * @return 缓存响应（深拷贝），若未找到或过期则返回 None
     */
    public func getVary(key: String, request: HttpRequest): ?HttpResponse {
        _withLock({ =>
            var result: ?HttpResponse = None

            // 优先检查 Vary 索引条目
            match (varyIndex.get(key)) {
                case Some(varyKeys) =>
                    for (varyKey in varyKeys) {
                        match (store.get(varyKey)) {
                            case Some(entry) =>
                                if (!entry.isExpired()) {
                                    match (varyInfo.get(varyKey)) {
                                        case Some(info) =>
                                            if (matchVaryHeaders(request, info)) {
                                                touch(varyKey)
                                                result = Some(deepCopyResponse(entry.response))
                                                break
                                            }
                                        case None => ()
                                    }
                                }
                            case None => ()
                        }
                    }
                case None => ()
            }

            // 回退到非 Vary 查找
            if (result.isNone()) {
                match (store.get(key)) {
                    case Some(entry) =>
                        if (!entry.isExpired()) {
                            touch(key)
                            result = Some(deepCopyResponse(entry.response))
                        } else {
                            store.remove(key)
                            removeFromAccessOrder(key)
                        }
                    case None => ()
                }
            }
            result
        })
    }

    /**
     * Vary 感知的缓存存储。若响应有 Vary 头，
     * 缓存键会附加请求的头值。
     *
     * @param key      基础缓存键（请求 URL）
     * @param request  HTTP 请求 (provides header values for Vary matching)
     * @param response 要缓存的响应
     */
    public func setVary(key: String, request: HttpRequest, response: HttpResponse): Unit {
        // 检查响应是否有 Vary 头
        match (response.headers.get("vary")) {
            case Some(varyValue) =>
                if (varyValue == "*") {
                    // "*" 表示对所有内容变化 —— 跳过缓存
                    return
                }
                let varyHeaders = parseVaryHeader(varyValue)
                let fullKey = buildVaryKey(key, request, varyHeaders)

                // 收集请求的 Vary 头值以供后续匹配
                let headerValues = ArrayList<String>()
                for (vh in varyHeaders) {
                    match (request.headers.get(vh)) {
                        case Some(val) => headerValues.add(val)
                        case None => headerValues.add("")
                    }
                }

                _withLock({ =>
                    if (store.size >= maxSize) {
                        evictOneLocked()
                    }
                    let effectiveTtl = parseResponseMaxAge(response) ?? ttl
                    store[fullKey] = CacheEntry(response: deepCopyResponse(response), ttl: effectiveTtl)
                    varyInfo[fullKey] = VaryInfo(headerNames: varyHeaders, headerValues: headerValues.toArray())
                    // 在 Vary 索引中跟踪以支持反向查找
                    match (varyIndex.get(key)) {
                        case Some(keys) =>
                            keys.add(fullKey)
                        case None =>
                            let newList = ArrayList<String>()
                            newList.add(fullKey)
                            varyIndex[key] = newList
                    }
                    addToAccessOrder(fullKey)
                })

            case None =>
                // 无 Vary 头 —— 使用常规存储
                set(key, response)
        }
    }

    /**
     * 从缓存中移除特定条目及其关联的
     * Vary 索引条目。
     *
     * @param key  要移除的缓存键
     */
    public func remove(key: String): Unit {
        _withLock({ =>
            store.remove(key)
            removeFromAccessOrder(key)
            varyInfo.remove(key)
            varyIndex.remove(key)
        })
    }

    /**
     * 清空缓存中的所有条目。
     */
    public func clear(): Unit {
        _withLock({ =>
            store = HashMap<String, CacheEntry>()
            accessOrder = ArrayList<String>()
            varyIndex = HashMap<String, ArrayList<String>>()
            varyInfo = HashMap<String, VaryInfo>()
        })
    }

    /**
     * 返回缓存中的条目数量。
     */
    public prop size: Int64 {
        get() {
            _withLock({ => store.size })
        }
    }

    /**
     * 创建缓存 GET 响应的中间件。
     *
     * 该中间件将：
     *   - 仅缓存 GET 请求
     *   - 仅缓存 200 OK 响应
     *   - 在缓存响应上设置 X-Cache 头（HIT/MISS）
     *   - 支持基于 Vary 头的差异化缓存
     *   - 遵守 Cache-Control: no-cache / no-store
     *
     * @return 中间件函数
     */
    public func middleware(): Middleware {
        let cache = this
        {next: Handler =>
            {req: HttpRequest =>
                // 仅缓存 GET 请求
                if (req.method != HttpMethod.GET) {
                    return next(req)
                }

                // 若请求有 Cache-Control: no-cache 则跳过
                match (req.headers.get("cache-control")) {
                    case Some(v) =>
                        if (v.contains("no-cache")) {
                            return next(req)
                        }
                    case None => ()
                }

                let cacheKey = req.url

                // 检查带 Vary 支持的缓存
                match (cache.getVary(cacheKey, req)) {
                    case Some(cachedResp) =>
                        cachedResp.headers.set("X-Cache", "HIT")
                        cachedResp
                    case None =>
                        let response = next(req)

                        // 仅缓存成功响应
                        if (response.status.code == 200u16) {
                            // 检查响应是否有 Cache-Control: no-store
                            var shouldCache = true
                            match (response.headers.get("cache-control")) {
                                case Some(v) =>
                                    if (v.contains("no-store")) {
                                        shouldCache = false
                                    }
                                case None => ()
                            }
                            if (shouldCache) {
                                cache.setVary(cacheKey, req, response)
                                response.headers.set("X-Cache", "MISS")
                            }
                        }
                        response
                }
            }
        }
    }

    // ---- LRU 辅助函数 ----

    /**
     * 通过将键移动到访问顺序列表的末尾来标记为最近访问。
     */
    private func touch(key: String): Unit {
        removeFromAccessOrder(key)
        accessOrder.add(key)
    }

    /**
     * 将键添加到访问顺序列表的末尾（最新位置）。
     */
    private func addToAccessOrder(key: String): Unit {
        accessOrder.add(key)
    }

    /**
     * 按值从访问顺序列表中移除键。
     */
    private func removeFromAccessOrder(key: String): Unit {
        let n = accessOrder.size
        var i: Int64 = 0
        while (i < n) {
            if (accessOrder[i] == key) {
                accessOrder.remove(i..i + 1)
                break
            }
            i++
        }
    }

    /**
     * 从访问顺序列表的前端淘汰最近最少使用的条目。
     * 必须在持有 mu 锁时调用。
     */
    private func evictOneLocked(): Unit {
        if (accessOrder.size > 0) {
            let lruKey = accessOrder[0]
            store.remove(lruKey)
            varyInfo.remove(lruKey)
            accessOrder.remove(0..1)
        }
    }

    // ---- Vary 辅助函数 ----

    /**
     * 将 Vary 头部值解析为头部名称数组。
     */
    private static func parseVaryHeader(varyValue: String): Array<String> {
        let parts = varyValue.split(",")
        let result = ArrayList<String>()
        for (part in parts) {
            let trimmed = part.trimAscii()
            if (trimmed.size > 0) {
                result.add(trimmed)
            }
        }
        result.toArray()
    }

    /**
     * 构建包含请求中 Vary 头部值的缓存键。
     * 使用空字节分隔符区分基础键和 Vary 值。
     */
    private static func buildVaryKey(baseKey: String, request: HttpRequest, varyHeaders: Array<String>): String {
        let sb = StringBuilder()
        sb.append(baseKey)
        for (vh in varyHeaders) {
            sb.append("\0")
            match (request.headers.get(vh)) {
                case Some(val) => sb.append(val)
                case None => ()
            }
        }
        sb.toString()
    }

    /**
     * 检查请求的 Vary 相关头部是否与存储的 Vary 信息匹配。
     * 同时比较头部的存在性和值。
     */
    private static func matchVaryHeaders(request: HttpRequest, info: VaryInfo): Bool {
        let n = info.headerNames.size
        var i: Int64 = 0
        while (i < n) {
            let requestVal = request.headers.get(info.headerNames[i])
            let cachedVal = info.headerValues[i]
            match (requestVal) {
                case Some(val) =>
                    if (val != cachedVal) {
                        return false
                    }
                case None => return false
            }
            i++
        }
        true
    }

    // ---- Cache-Control 辅助函数 ----

    /**
     * 从响应中解析 Cache-Control max-age 或 s-maxage。
     * 如果找到，返回 TTL 作为 Duration，否则返回 None。
     * 对于共享缓存，s-maxage 优先于 max-age（RFC 7234）。
     */
    private static func parseResponseMaxAge(response: HttpResponse): ?Duration {
        match (response.headers.get("cache-control")) {
            case Some(cc) =>
                let directives = cc.split(",")
                // 先检查 s-maxage（对共享缓存优先）
                for (directive in directives) {
                    let trimmed = directive.trimAscii()
                    if (trimmed.startsWith("s-maxage=")) {
                        let valStr = trimmed[9..trimmed.size].trimAscii()
                        return parseMaxAgeValue(valStr)
                    }
                }
                // 回退到 max-age
                for (directive in directives) {
                    let trimmed = directive.trimAscii()
                    if (trimmed.startsWith("max-age=")) {
                        let valStr = trimmed[8..trimmed.size].trimAscii()
                        return parseMaxAgeValue(valStr)
                    }
                }
                None
            case None => None
        }
    }

    /**
     * 将 max-age 值字符串解析为 Duration。
     * 如果值无效或为负数，返回 None。
     */
    private static func parseMaxAgeValue(value: String): ?Duration {
        try {
            let seconds = parseDecimal(value)
            if (seconds >= 0) {
                Some(Duration.second * seconds)
            } else {
                None
            }
        } catch (_: Exception) {
            None
        }
    }
}

/**
 * 创建 HttpResponse 的深拷贝以防止缓存污染。
 * 复制主体字节和所有头部。
 */
private func deepCopyResponse(resp: HttpResponse): HttpResponse {
    // 深拷贝主体字节
    let bodyCopy = ByteBuffer(capacity: resp.body.getLimit())
    bodyCopy.write(resp.body.getArray()[0..resp.body.getLimit()])

    let newHeaders = HttpHeaders()
    let headerNames = resp.headers.names()
    for (name in headerNames) {
        match (resp.headers.get(name)) {
            case Some(v) => newHeaders.set(name, v)
            case None => ()
        }
    }

    HttpResponse(
        version: resp.version,
        status: resp.status,
        headers: newHeaders,
        body: bodyCopy
    )
}

