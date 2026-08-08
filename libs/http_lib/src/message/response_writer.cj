package http_lib.message

import std.collection.{HashMap, ArrayList}
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpStatus, HttpVersion, currentHttpDate, ProtocolException}
import http_lib.connection.Connection
import std.net.TcpSocket
import std.time.DateTime

/**
 * 流式 HTTP 响应写入器，支持分块传输编码。
 *
 * 允许处理器使用分块传输编码增量地写入响应数据。
 *
 * 两种操作模式：
 *   - 分块（默认）：通过 Transfer-Encoding: chunked 以分块形式写入数据。
 *     支持通过 addTrailer() 添加尾部字段。
 *   - Content-Length：若在首次写入前设置了 Content-Length 响应头，
 *     则禁用分块编码，直接写入数据。
 *
 * 与 server.ResponseBuilder 的关系：
 *   - 这是**流式** ResponseBuilder，直接向网络连接（Connection）写入：
 *     首次 write() 时刷新响应头，后续增量写入数据。
 *   - server.ResponseBuilder 是独立的类，包装了 message.InMemoryResponseBuilder，
 *     用于在发送前完全在内存中构建响应。它不是本类的包装器。
 *   - 需要真正流式传输时使用本类（分块编码、SSE、大载荷）。
 *   - 需要在内存中构建完整响应时使用 message.InMemoryResponseBuilder
 *     或 server.ResponseBuilder（测试、中间件检查、小载荷）。
 *
 * 用法：
 *   let w = ResponseBuilder(conn)
 *   w.writeHeader(HttpStatus.OK)
 *   w.write("chunk1 data")
 *   w.write("chunk2 data")
 *   w.addTrailer("X-Checksum", "abc123")
 *   w.finish()
 *
 * 状态行和响应头在首次调用 write() 时写入，
 * 因此可以在 writeHeader() 之后、首次数据写入之前继续设置响应头。
 */
public class ResponseBuilder {
    private var conn: Connection
    private var status: HttpStatus
    private var headers: HttpHeaders
    private var statusWritten: Bool
    private var useChunked: Bool
    private var chunkedWriter: ?ChunkedWriter
    private var trailers: HttpHeaders
    private var serverName: String
    private var rawSocket: ?TcpSocket  // 用于 ConnectionController 支持
    public var suppressBody: Bool = false  // 根据 RFC 7231 §4.3.2：HEAD 响应必须没有响应体

    public init(
        conn: Connection,
        status!: HttpStatus = HttpStatus.OK,
        serverName!: String = "http_lib/0.1",
        rawSocket!: ?TcpSocket = None,
        suppressBody!: Bool = false
    ) {
        this.conn = conn
        this.status = status
        this.headers = HttpHeaders()
        this.statusWritten = false
        this.useChunked = true  // 默认使用分块编码；如果设置了 Content-Length 则自动禁用
        this.chunkedWriter = None
        this.trailers = HttpHeaders()
        this.serverName = serverName
        this.rawSocket = rawSocket
        this.suppressBody = suppressBody
    }

    /**
     * 发送 103 Early Hints（RFC 8297）初步响应头。
     *
     * 在最终响应之前发送，允许客户端在服务器生成响应时
     * 预连接或预加载关键资源（如 CSS、JS、图片）。
     *
     * 必须在 writeHeader() 或首次 write() 之前调用。
     * 可以多次调用以发送多组提示头。
     *
     * 用法：
     *   let hints = HttpHeaders()
     *   hints.set("Link", "</style.css>; rel=preload; as=style")
     *   rw.writeEarlyHints(hints)
     *
     * 注意：只有 HTTP/1.1 和更新版本支持信息性响应（1xx）。
     * 调用此方法不影响后续正常响应写入流程。
     */
    public func writeEarlyHints(headers: HttpHeaders): Unit {
        if (statusWritten) { return }
        // 构建 103 响应
        let statusLine = "HTTP/1.1 103 Early Hints\r\n"
        conn.write(unsafe { statusLine.rawData() })
        let headerBytes = headers.toBytes()
        if (headerBytes.size > 0) {
            conn.write(headerBytes)
        }
        conn.write(unsafe { "\r\n".rawData() })
        conn.flush()
    }

    /**
     * 设置响应状态码（必须在首次写入前调用）。
     */
    public func setStatus(s: HttpStatus): Unit {
        if (!statusWritten) {
            status = s
        }
    }

    /**
     * 获取响应头的可变引用。
     * 响应头在首次 write() 调用之前可以修改。
     */
    public func header(): HttpHeaders {
        headers
    }

    /**
     * 设置响应头（流式接口）。
     */
    public func setHeader(name: String, value: String): ResponseBuilder {
        if (!statusWritten) {
            headers.set(name, value)
        }
        this
    }

    /**
     * 添加尾部字段，将在最后一个分块后发送。
     * 若 "Trailer" 响应头尚未存在则自动添加。
     * 根据 RFC 7230 §4.1.2，Trailer 响应头必须在响应头段（主体之前）声明。
     * 因此尾部字段只能在 writeHeader() 或首次 write() 调用之前添加。
     */
    public func addTrailer(name: String, value: String): Unit {
        if (statusWritten) {
            // 响应头已发送后无法声明尾部字段
            return
        }
        if (trailers.get("trailer").isNone()) {
            headers.set("Trailer", name)
        } else {
            match (headers.get("trailer")) {
                case Some(existing) =>
                    headers.set("Trailer", "${existing}, ${name}")
                case None => ()
            }
        }
        trailers.add(name, value)
    }

    /**
     * 将状态行和响应头写入连接。
     * 若未显式调用，则在首次 write() 时自动调用。
     */
    public func writeHeader(statusCode: ?HttpStatus): Unit {
        if (statusWritten) { return }
        statusWritten = true

        match (statusCode) {
            case Some(sc) => status = sc
            case None => ()
        }

        // 自动设置响应头
        if (headers.get("date").isNone()) {
            headers.set("Date", currentHttpDate())
        }
        if (headers.get("server").isNone()) {
            headers.set("Server", serverName)
        }
        // 自动检测帧格式：若设置了 Content-Length，则使用 identity 编码
        // 而非分块编码。根据 RFC 7230 §3.3.2，Content-Length 优先于
        // 使用 Transfer-Encoding: chunked（分块传输编码）。
        if (headers.get("content-length").isSome()) {
            useChunked = false
        }
        if (headers.get("transfer-encoding").isNone() && useChunked) {
            headers.set("Transfer-Encoding", "chunked")
        }

        // 写入状态行
        let statusLine = "${HttpVersion.HTTP_1_1.toString()} ${status.code} ${status.reasonPhrase}\r\n"
        conn.write(unsafe { statusLine.rawData() })
        // 写入响应头
        let headerBytes = headers.toBytes()
        if (headerBytes.size > 0) {
            conn.write(headerBytes)
        }
        // 空行分隔符
        conn.write(unsafe { "\r\n".rawData() })

        // 初始化分块写入器（用于需要分块编码的场景）
        if (useChunked) {
            chunkedWriter = Some(ChunkedWriter(conn))
        }
    }

    /**
     * 向响应体写入数据。
     * 若使用分块编码，数据以分块形式写入。
     * 若使用 Content-Length，数据直接写入。
     */
    public func write(data: Array<UInt8>): Int64 {
        if (suppressBody) { return 0 }  // 根据 RFC 7231 §4.3.2：HEAD 必须没有响应体
        if (!statusWritten) {
            writeHeader(None)
        }
        if (data.size == 0) { return 0 }

        if (useChunked) {
            match (chunkedWriter) {
                case Some(cw) =>
                    cw.writeChunk(data)
                    conn.flush()
                    data.size
                case None =>
                    let cw = ChunkedWriter(conn)
                    chunkedWriter = Some(cw)
                    cw.writeChunk(data)
                    conn.flush()
                    data.size
            }
        } else {
            conn.write(data)
            conn.flush()
            data.size
        }
    }

    /**
     * 向响应体写入字符串。
     */
    public func writeString(s: String): Int64 {
        write(unsafe { s.rawData() })
    }

    /**
     * 完成响应：写入最后的空分块和可选尾部字段。
     * 必须在所有数据写入后调用。
     */
    public func finish(): Unit {
        if (!statusWritten) {
            writeHeader(None)
        }
        if (suppressBody) {
            conn.flush()
            return
        }
        if (useChunked) {
            match (chunkedWriter) {
                case Some(cw) =>
                    if (trailers.size > 0) {
                        cw.finish(trailers: trailers)
                    } else {
                        cw.finish(trailers: None)
                    }
                    conn.flush()
                case None => ()
            }
        }
    }

    /**
     * 将缓冲数据刷新到连接。
     */
    public func flush(): Unit {
        conn.flush()
    }

    /**
     * 设置读取截止时间。
     * 到达截止时间后，从底层连接读取将返回超时错误。
     * 零值表示不设限制。
     */
    public func setReadDeadline(deadline: DateTime): Unit {
        let now = DateTime.now()
        if (deadline <= now) {
            conn.setReadTimeout(Duration.second * 0)
        } else {
            conn.setReadTimeout(deadline - now)
        }
    }

    /**
     * 设置写入截止时间。
     * 到达截止时间后，向底层连接写入将返回超时错误。
     * 零值表示不设限制。
     */
    public func setWriteDeadline(deadline: DateTime): Unit {
        let now = DateTime.now()
        if (deadline <= now) {
            conn.setWriteTimeout(Duration.second * 0)
        } else {
            conn.setWriteTimeout(deadline - now)
        }
    }

    /**
     * 劫持底层 TCP 连接。
     * 实现连接劫持接口。
     * 返回原始 TcpSocket 用于协议升级（WebSocket、h2c 等）。
     * 如果没有可用原始套接字则抛出异常（例如 TLS 包装的连接）。
     */
    public func takeover(): TcpSocket {
        match (rawSocket) {
            case Some(s) => s
            case None => throw ProtocolException("connection does not support takeover")
        }
    }
}

// ---- 流式处理器类型 ----

/**
 * 流式处理器类型：接收请求和 ResponseBuilder，
 * 用于增量写入响应。
 *
 * 用法：
 *   let handler: StreamingHandler = {req, w =>
 *       w.setStatus(HttpStatus.OK)
 *       w.setHeader("Content-Type", "text/plain")
 *       w.write("data chunk 1")
 *       w.write("data chunk 2")
 *       w.finish()
 *   }
 */
public type StreamingHandler = (HttpRequest, ResponseBuilder) -> Unit


/**
 * 包装标准 Handler 以支持流式输出。
 * 处理器构建 HttpResponse，然后通过 ResponseBuilder 发送。
 *
 * 用法：let streamingFn = wrapHandler(myHandler)
 */
public func wrapHandler(handler: (HttpRequest) -> HttpResponse): StreamingHandler {
    {req: HttpRequest, w: ResponseBuilder =>
        let resp = handler(req)
        // 先复制响应头（必须在 writeHeader 之前设置，否则会被静默忽略）
        let names = resp.headers.names()
        for (name in names) {
            if (name == "transfer-encoding" || name == "content-length" || name == "date") {
                continue
            }
            match (resp.headers.get(name)) {
                case Some(v) => w.setHeader(name, v)
                case None => ()
            }
        }
        // 写入状态行
        w.writeHeader(resp.status)
        // 写入响应体
        let bodyBytes = resp.bodyAsBytes()
        if (bodyBytes.size > 0) {
            w.write(bodyBytes)
        }
        w.finish()
    }
}

/**
 * ConnectionController 接口允许处理器接管 TCP 连接。
 *
 * 成功劫持后，处理器完全接管连接所有权，
 * 用于协议升级，如 WebSocket 和 HTTP/2 h2c。
 *
 * 使用方式：检查 ResponseBuilder 是否实现 ConnectionController，然后调用 takeover()。
 */
/**
 * StreamFlusher 接口允许处理器将缓冲数据刷新到客户端。
 * 用于流式处理器立即推送缓冲数据。
 */
public interface StreamFlusher {
    func flush(): Unit
}

public interface ConnectionController {
    /**
     * 获取底层 TCP 连接，用于直接 I/O。
     * 返回用于直接 I/O 的原始 TcpSocket。
     * 调用 Hijack 后，调用方拥有该连接的所有权。
     */
    func takeover(): TcpSocket
}

// ---- 内存响应写入器（用于向后兼容和测试） ----

/**
 * InMemoryResponseBuilder 在内存中累积响应数据，可以
 * 生成 HttpResponse。适用于测试、需要检查/修改响应的中间件，
 * 以及适配旧式处理器。
 *
 * 这是流式 ResponseBuilder 的内存缓冲对应物。
 */
public class InMemoryResponseBuilder {
    private var status: Int64 = 200
    private var headers: HttpHeaders = HttpHeaders()
    private var bodyParts: ArrayList<Array<UInt8>> = ArrayList<Array<UInt8>>()
    private var headerWritten: Bool = false
    private var bodyWritten: Bool = false

    public init() {}

    /**
     * 写入状态码和头部。
     * 必须在 write() 之前调用。
     */
    public func writeHeader(statusCode: Int64): Unit {
        if (headerWritten) { return }
        this.status = statusCode
        headerWritten = true
    }

    /**
     * 如果 writeHeader() 已被调用则返回 true。
     */
    public func hasHeaderWritten(): Bool {
        headerWritten
    }

    /**
     * 写入头部键值对。
     */
    public func header(key: String, value: String): Unit {
        headers.set(key, value)
    }

    /**
     * 获取可变头部映射。
     */
    public func getHeaders(): HttpHeaders {
        headers
    }

    /**
     * 将字节追加到响应体。
     */
    public func write(data: Array<UInt8>): Unit {
        if (!headerWritten) {
            writeHeader(200)
        }
        bodyParts.add(data)
        bodyWritten = true
    }

    /**
     * 向响应体写入字符串。
     */
    public func writeString(s: String): Unit {
        write(unsafe { s.rawData() })
    }

    /**
     * Flush 缓冲数据（对内存写入器无操作）。
     */
    public func flush(): Unit {}

    /**
     * 直接将响应写入 Connection 而不拼接
     * 所有主体部分到一个缓冲区。这避免了加倍内存
     * 用于大响应。
     */
    public func writeTo(conn: Connection): HttpResponse {
        if (!headerWritten) {
            writeHeader(200)
        }
        let httpStatus = HttpStatus(UInt16(status))
        let statusLine = "HTTP/1.1 ${status} ${httpStatus.reasonPhrase}\r\n"
        conn.write(unsafe { statusLine.rawData() })
        let headerBytes = headers.toBytes()
        if (headerBytes.size > 0) {
            conn.write(headerBytes)
        }
        conn.write(unsafe { "\r\n".rawData() })
        for (part in bodyParts) {
            conn.write(part)
        }
        conn.flush()
        build()
    }

    /**
     * 从累积的数据构建最终的 HttpResponse。
     */
    public func build(): HttpResponse {
        if (!headerWritten) {
            writeHeader(200)
        }
        var totalSize: Int64 = 0
        for (part in bodyParts) {
            totalSize += part.size
        }
        let combined = Array<UInt8>(totalSize, repeat: 0)
        var offset: Int64 = 0
        for (part in bodyParts) {
            part.copyTo(combined, 0, offset, part.size)
            offset += part.size
        }
        let body = ByteBuffer.fromOwned(combined)
        HttpResponse(status: HttpStatus(UInt16(status)), headers: headers, body: body)
    }
}

// ---- HTTP 辅助函数 ----

/**
 * Error 向请求回复指定的错误消息和 HTTP 状态码。
Error().
 */
public func HttpError(req: HttpRequest, message: String, statusCode: Int64): HttpResponse {
    let headers = HttpHeaders()
    headers.set("Content-Type", "text/plain; charset=utf-8")
    headers.set("X-Content-Type-Options", "nosniff")
    let bodyStr = "${message}\n"
    let bodyData = unsafe { bodyStr.rawData() }
    headers.set("Content-Length", "${bodyData.size}")
    let body = ByteBuffer(capacity: bodyData.size)
    body.write(bodyData)
    HttpResponse(status: HttpStatus(UInt16(statusCode)), headers: headers, body: body)
}

/**
 * NotFound 向请求回复 HTTP 404 未找到错误。
NotFound().
 */
public func HttpNotFound(req: HttpRequest): HttpResponse {
    HttpError(req, "404 page not found", 404)
}

/**
 * Redirect 向请求回复重定向到指定 url。
Redirect().
 */
public func HttpRedirect(req: HttpRequest, url: String, statusCode: Int64): HttpResponse {
    let headers = HttpHeaders()
    headers.set("Location", url)
    headers.set("Content-Type", "text/html; charset=utf-8")
    let bodyStr = "<a href=\"${url}\">${statusCode} Found</a>.\n"
    let bodyData = unsafe { bodyStr.rawData() }
    headers.set("Content-Length", "${bodyData.size}")
    let body = ByteBuffer(capacity: bodyData.size)
    body.write(bodyData)
    HttpResponse(status: HttpStatus(UInt16(statusCode)), headers: headers, body: body)
}
