package http_lib.message

import std.collection.{HashMap, ArrayList}
import http_lib.buffer.ByteBuffer
import http_lib.connection.Connection
import http_lib.core.{HttpHeaders, HttpMethod, HttpVersion, ProtocolException, RequestContext, BodyReadAfterCloseException}

public class HttpRequest {
    public var method: HttpMethod
    public var url: String
    public var version: HttpVersion
    public var headers: HttpHeaders
    public var body: ByteBuffer
    public var trailers: HttpHeaders = HttpHeaders()
    /**
     * 客户端是否通过 TE: trailers 声明愿意接收尾部头（RFC 7230 §4.3）。
     */
    public var acceptsTrailers: Bool = false
    /**
     * 底层连接，由 HTTP 服务器在分派请求时设置，
     * 将请求传递给处理器。允许处理器对协议升级执行直接 I/O
     * （WebSocket 等）。
     *
     * 处理器在尝试劫持前应检查此字段：
     *   match (req.connection) {
     *     case Some(conn) => /* 劫持可用 */
     *     case None => /* 无劫持支持 */
     *   }
     */
    public var connection: ?Connection = None
    /**
     * 处理器成功劫持后设置为 true，
     * underlying connection. Tells the HTTP 服务器 to stop managing
     * 连接 — 处理器已取得所有权。
     */
    public var takenOver: Bool = false
    /**
     * 标记主体是否已关闭。关闭后再次读取将抛出 BodyReadAfterCloseException。
     */
    public var bodyClosed: Bool = false
    /**
     * 路由器提取的路径参数（例如 /users/:id 中的 :id）。
     * 由 Router.handler() 在分派到路由处理器前设置。
     */
    public var pathParams: HashMap<String, String> = HashMap<String, String>()
    /**
     * 请求路径（不包含查询字符串的 URL），
     * HTTP 服务器 or client when parsing the request.
     */
    public var path: String = "/"
    /**
     * 每请求上下文，用于取消、截止时间和值传递。
     * 由服务器在分发前设置，处理器可以检查 ctx.isExpired()
     * 检测超时，通过 ctx.getValue() 获取请求作用域的数据。
     */
    public var ctx: RequestContext = RequestContext()
    /**
     * 延迟主体读取器。设置后，bodyAsBytes() 和 bodyAsString() 将
     * 在首次访问时从此连接读取，而非使用预缓冲的主体。
     * 这使得流式上传成为可能，无需将整个请求主体缓冲在内存中。
     *
     * 由服务器内部设置。处理器应使用 bodyAsBytes()
     * 或流式 readBody() 方法。
     */
    public var bodyRemaining: Int64 = -1  // -1 表示不延迟读取；>= 0 表示从连接读取的字节数
    public var bodyReadFromStream: Bool = false
    public var metadata: ?Any = None

    public init(
        method!: HttpMethod = HttpMethod.GET,
        url!: String = "/",
        version!: HttpVersion = HttpVersion.HTTP_1_1,
        headers!: HttpHeaders = HttpHeaders(),
        body!: ByteBuffer = ByteBuffer(capacity: 0)
    ) {
        this.method = method
        this.url = url
        this.version = version
        this.headers = headers
        this.body = body
        // 自动从 URL 提取路径（去除查询字符串）
        this.path = match (url.indexOf("?")) {
            case Some(idx) => url[..idx]
            case None => url
        }
    }

    public func addHeader(name: String, value: String): HttpRequest {
        headers.add(name, value)
        this
    }

    public func setHeader(name: String, value: String): HttpRequest {
        headers.set(name, value)
        this
    }

    public func setBody(data: Array<UInt8>): HttpRequest {
        body = ByteBuffer(capacity: data.size)
        body.write(data)
        headers.set("Content-Length", "${data.size}")
        this
    }

    public func setJsonBody(json: String): HttpRequest {
        let jsonData = unsafe { json.rawData() }
        body = ByteBuffer(capacity: jsonData.size)
        body.write(jsonData)
        headers.set("Content-Length", "${jsonData.size}")
        headers.set("Content-Type", "application/json")
        this
    }

    public func bodyAsString(): String {
        if (bodyClosed) { throw BodyReadAfterCloseException() }
        ensureBodyRead()
        body.toString()
    }

    public func bodyAsBytes(): Array<UInt8> {
        if (bodyClosed) { throw BodyReadAfterCloseException() }
        ensureBodyRead()
        let size = body.getLimit()
        if (size == 0) { return [] }
        let result = Array<UInt8>(size, repeat: 0)
        body.getArray().copyTo(result, 0, 0, size)
        result
    }

    /**
     * 确保已从连接中完全读取请求主体。
     * 在首次访问 bodyAsBytes()/bodyAsString() 时延迟调用，
     * 使不读取主体的处理器无需付出缓冲成本。
     */
    private func ensureBodyRead(): Unit {
        if (bodyReadFromStream) { return }
        if (bodyRemaining < 0) {
            bodyReadFromStream = true
            return
        }
        match (connection) {
            case Some(conn) =>
                let toRead = bodyRemaining - body.getLimit()
                if (toRead > 0) {
                    let tempBuf = Array<UInt8>(4096, repeat: 0)
                    var bodyRead: Int64 = 0
                    let bodyBytes = Array<UInt8>(toRead, repeat: 0)
                    while (bodyRead < toRead) {
                        let maxRead = if (toRead - bodyRead < 4096) { toRead - bodyRead } else { 4096 }
                        let n = conn.read(tempBuf, 0, maxRead)
                        if (n <= 0) {
                            throw ProtocolException("connection closed while reading body")
                        }
                        tempBuf[0..n].copyTo(bodyBytes, bodyRead, 0, n)
                        bodyRead += n
                    }
                    body.write(bodyBytes)
                }
                bodyReadFromStream = true
                bodyRemaining = -1
            case None => ()
        }
    }

    /**
     * 从连接中增量流式读取主体数据。
     * 将最多 buf.size 个字节读入 buf。返回读取的字节数。
     * 所有主体数据均已读取完毕时返回 0。
     *
     * 这是 bodyAsBytes() 的流式替代方案。用于大文件上传，
     * 避免将整个主体缓冲在内存中。
     */
    public func readBody(buf: Array<UInt8>): Int64 {
        if (bodyClosed) { throw BodyReadAfterCloseException() }
        if (bodyReadFromStream) {
            // 已完全缓冲 — 从缓冲区读取
            let remaining = body.getLimit() - body.getPosition()
            if (remaining <= 0) { return 0 }
    /**
     * 关闭请求主体。若尚有未读取数据，则排空。
     * 关闭后调用 bodyAsBytes()/bodyAsString()/readBody() 将抛出 BodyReadAfterCloseException。
     */
            let toRead = if (buf.size < remaining) { buf.size } else { remaining }
            var i: Int64 = 0
            while (i < toRead) {
                match (body.readByte()) {
                    case Some(b) => buf[i] = b; i += 1
                    case None => break
                }
            }
            return i
        }
        // 直接从连接流式读取
        match (connection) {
            case Some(conn) =>
                let n = conn.read(buf)
                if (n <= 0) {
                    bodyReadFromStream = true
                    bodyRemaining = -1
                    return 0
                }
                body.write(buf, 0, n)
                // 检查是否已读取所有内容
                if (bodyRemaining > 0 && body.getLimit() >= bodyRemaining) {
                    bodyReadFromStream = true
                    bodyRemaining = -1
                }
                return n
            case None => 0
        }
    }

    /**
     * 关闭请求主体。若尚有未读取数据，则排空。
     * 关闭后调用 bodyAsBytes()/bodyAsString()/readBody() 将抛出 BodyReadAfterCloseException。
     */
    public func bodyClose(): Unit {
        bodyClosed = true
        if (bodyRemaining > 0) {
            match (connection) {
                case Some(conn) =>
                    var remaining = bodyRemaining
                    let tmp = Array<UInt8>(4096, repeat: 0)
                    while (remaining > 0) {
                        let n = conn.read(tmp)
                        if (n <= 0) { break }
                        remaining -= n
                    }
                case None => ()
            }
        }
        bodyRemaining = -1
        bodyReadFromStream = true
    }


    /**
     * 从 URL 解析并返回查询字符串参数。
     */
    public func queryParams(): HashMap<String, String> {
        let result = HashMap<String, String>()
        match (url.indexOf("?")) {
            case Some(idx) =>
                let runes = url.toRuneArray()
                var i = idx + 1
                var currentKey = ArrayList<Rune>()
                var currentValue = ArrayList<Rune>()
                var inValue = false
                while (i < runes.size) {
                    let r = runes[i]
                    if (r == r'&') {
                        let key = String(currentKey.toArray())
                        let value = String(currentValue.toArray())
                        if (key.size > 0) {
                            result[urlDecodeQS(key)] = urlDecodeQS(value)
                        }
                        currentKey = ArrayList<Rune>()
                        currentValue = ArrayList<Rune>()
                        inValue = false
                    } else if (r == r'=' && !inValue) {
                        inValue = true
                    } else {
                        if (inValue) { currentValue.add(r) } else { currentKey.add(r) }
                    }
                    i += 1
                }
                // 最后一对
                if (currentKey.size > 0) {
                    let key = String(currentKey.toArray())
                    let value = String(currentValue.toArray())
                    result[urlDecodeQS(key)] = urlDecodeQS(value)
                }
            case None => ()
        }
        result
    }

    private static func urlDecodeQS(s: String): String {
        let runes = s.toRuneArray()
        let result = ArrayList<Rune>()
        var i: Int64 = 0
        while (i < runes.size) {
            if (runes[i] == r'+') {
                result.add(r' ')
                i += 1
            } else if (runes[i] == r'%' && i + 2 < runes.size) {
                let high = hexValQS(runes[i + 1])
                let low = hexValQS(runes[i + 2])
                if (high >= 0 && low >= 0) {
                    let byte: UInt8 = UInt8((high << 4) | low)
                    let bytes = [byte]
                    let decoded = String.fromUtf8(bytes)  // 安全：校验 UTF-8 编码
                    let drunes = decoded.toRuneArray()
                    if (drunes.size > 0) {
                        result.add(drunes[0])
                    }
                    i += 3
                } else {
                    result.add(runes[i])
                    i += 1
                }
            } else {
                result.add(runes[i])
                i += 1
            }
        }
        String(result.toArray())
    }

    private static func hexValQS(v: Rune): Int64 {
        if (v >= r'0' && v <= r'9') {
            let raw = UInt32(v)
            Int64(raw - 48)
        } else if (v >= r'A' && v <= r'F') {
            let raw = UInt32(v)
            Int64(raw - 65) + 10
        } else if (v >= r'a' && v <= r'f') {
            let raw = UInt32(v)
            Int64(raw - 97) + 10
        } else { -1 }
    }

    public func buildRequestLine(): String {
        "${method.toString()} ${url} ${version.toString()}\r\n"
    }

    // ---- 便捷方法 ----

    /**
     * 按名称获取查询参数的值。
     * 如果参数不存在则返回 None。
     */
    public func queryParam(name: String): ?String {
        let params = queryParams()
        params.get(name)
    }

    /**
     * 获取 User-Agent 头部值。
     */
    public func userAgent(): String {
        match (headers.get("user-agent")) {
            case Some(v) => v
            case None => ""
        }
    }

    /**
     * 获取 Referer 头部值。
     */
    public func referer(): String {
        match (headers.get("referer")) {
            case Some(v) => v
            case None => ""
        }
    }

    /**
     * 获取 Content-Type 头部值。
     */
    public func contentType(): String {
        match (headers.get("content-type")) {
            case Some(v) => v
            case None => ""
        }
    }

    /**
     * 从 Cookie 头部按名称获取特定 cookie 的值。
     * 解析 "name1=value1; name2=value2" 格式。
     */
    public func cookie(name: String): ?String {
        match (headers.get("cookie")) {
            case Some(cookieHeader) =>
                let parts = cookieHeader.split(";")
                for (part in parts) {
                    let trimmed = part.trimAscii()
                    let eqIdx = trimmed.indexOf("=")
                    match (eqIdx) {
                        case Some(idx) =>
                            let key = trimmed[..idx]
                            let value = trimmed[idx + 1..]
                            if (key == name) { return Some(value) }
                        case None => ()
                    }
                }
                None
            case None => None
        }
    }

    /**
     * 从 Authorization 头部解析 Basic 认证凭据。
     * 如果存在 Basic 认证则返回 Some(用户名)，否则返回 None。
     * 使用 basicAuthPassword() 获取密码。
     */
    public func basicAuth(): ?String {
        match (headers.get("authorization")) {
            case Some(auth) =>
                if (auth.startsWith("Basic ")) {
                    let encoded = auth["Basic ".size..]
                    let decoded = decodeBasicAuth(encoded)
                    let colonIdx = decoded.indexOf(":")
                    match (colonIdx) {
                        case Some(idx) =>
                            Some(decoded[..idx])
                        case None => None
                    }
                } else { None }
            case None => None
        }
    }

    /**
     * 从 Basic 认证凭据获取密码。
     */
    public func basicAuthPassword(): ?String {
        match (headers.get("authorization")) {
            case Some(auth) =>
                if (auth.startsWith("Basic ")) {
                    let encoded = auth["Basic ".size..]
                    let decoded = decodeBasicAuth(encoded)
                    let colonIdx = decoded.indexOf(":")
                    match (colonIdx) {
                        case Some(idx) =>
                            if (idx + 1 < decoded.size) { Some(decoded[idx + 1..]) } else { Some("") }
                        case None => None
                    }
                } else { None }
            case None => None
        }
    }

    /**
     * 检查请求是否接受给定的内容类型。
     */
    public func accepts(contentType: String): Bool {
        match (headers.get("accept")) {
            case Some(accept) =>
                accept.contains(contentType) || accept.contains("*/*") || accept.contains("${contentType.split("/")[0]}/*")
            case None => true  // 无 Accept 头部表示接受任何类型
        }
    }

    /**
     * 从常见代理头部或连接获取客户端 IP 地址。
     */
    public func clientIp(): String {
        match (headers.get("x-forwarded-for")) {
            case Some(xff) =>
                let commaIdx = xff.indexOf(",")
                match (commaIdx) {
                    case Some(idx) => String(xff.toRuneArray()[..idx])
                    case None => xff
                }
            case None =>
                match (headers.get("x-real-ip")) {
                    case Some(rip) => rip
                    case None => "127.0.0.1"
                }
        }
    }

    private static func decodeBasicAuth(encoded: String): String {
        // 简易 Base64 解码（Basic 认证用）
        let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let runes = encoded.toRuneArray()
        var result = ArrayList<Rune>()
        var i: Int64 = 0
        while (i + 3 < runes.size) {
            let c1 = charIndex(table, runes[i])
            let c2 = if (runes[i + 1] != r'=') { charIndex(table, runes[i + 1]) } else { Int64(0) }
            let c3 = if (runes[i + 2] != r'=') { charIndex(table, runes[i + 2]) } else { Int64(0) }
            let c4 = if (runes[i + 3] != r'=') { charIndex(table, runes[i + 3]) } else { Int64(0) }
            let triple = (c1 << 18) | (c2 << 12) | (c3 << 6) | c4
            result.add(Rune((triple >> 16) & 0xff))
            if (runes[i + 2] != r'=') { result.add(Rune((triple >> 8) & 0xff)) }
            if (runes[i + 3] != r'=') { result.add(Rune(triple & 0xff)) }
            i += 4
        }
        // 处理不足 4 字符的尾部（格式错误的 Base64，忽略）
        String(result.toArray())
    }

    private static func charIndex(table: String, c: Rune): Int64 {
        if (c == r'=') { return 0 }
        var i: Int64 = 0
        while (i < 64) {
            if (table[i..i + 1].toRuneArray()[0] == c) { return i }
            i += 1
        }
        0
    }

    public func toBytes(): Array<UInt8> {
        let requestLineBytes = unsafe { buildRequestLine().rawData() }
        let headerBytes = headers.toBytes()
        let bodyLen = body.getLimit()
        let total = requestLineBytes.size + headerBytes.size + 2 + bodyLen
        let result = Array<UInt8>(total, repeat: 0)
        var offset: Int64 = 0

        requestLineBytes.copyTo(result, 0, offset, requestLineBytes.size)
        offset += requestLineBytes.size

        if (headerBytes.size > 0) {
            headerBytes.copyTo(result, 0, offset, headerBytes.size)
            offset += headerBytes.size
        }

        // \r\n 头部和主体之间的分隔符
        result[offset] = b'\r'; offset++
        result[offset] = b'\n'; offset++

        if (bodyLen > 0) {
            body.getArray().copyTo(result, 0, offset, bodyLen)
        }

        result
    }
}
