package http_lib.message

import std.collection.ArrayList
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpStatus, HttpVersion, BodyReadAfterCloseException}
import http_lib.connection.Connection
import http_lib.utils.containsIgnoreCase

public class HttpResponse {
    public var version: HttpVersion
    public var status: HttpStatus
    public var headers: HttpHeaders
    public var body: ByteBuffer
    public var trailers: HttpHeaders = HttpHeaders()
    public var bodyClosed: Bool = false

    public init(
        version!: HttpVersion = HttpVersion.HTTP_1_1,
        status!: HttpStatus = HttpStatus.OK,
        headers!: HttpHeaders = HttpHeaders(),
        body!: ByteBuffer = ByteBuffer(capacity: 0)
    ) {
        this.version = version
        this.status = status
        this.headers = headers
        this.body = body
    }

    public func isSuccess(): Bool {
        status.isSuccess()
    }

    public func isRedirect(): Bool {
        status.isRedirection()
    }

    /**
     * 根据 HTTP 版本和响应头检查连接是否可保持活跃。
     */
    public func isKeepAlive(): Bool {
        if (!version.supportsPersistentConnection()) {
            return false
        }
        match (headers.get("connection")) {
            case Some(v) =>
                let bytes = unsafe { v.rawData() }
                if (containsIgnoreCase(bytes, "close".toRuneArray())) {
                    return false
                }
            case None => ()
        }
        true  // HTTP/1.1 默认 Keep-Alive
    }

    public func bodyAsString(): String {
        if (bodyClosed) { throw BodyReadAfterCloseException() }
        body.toString()
    }

    public func bodyAsBytes(): Array<UInt8> {
        if (bodyClosed) { throw BodyReadAfterCloseException() }
        let size = body.getLimit()
        if (size == 0) { return [] }
        let result = Array<UInt8>(size, repeat: 0)
        body.getArray().copyTo(result, 0, 0, size)
        result
    }

    /**
     * 分块读取响应体数据到 buf 中（流式兼容 API）。
     * 返回读取的字节数，所有数据均已被消费时返回 0。
     * 维护内部读取位置以支持顺序分块读取。
     *
     * 用法（用于 SSE/流式传输的缓冲区逐行读取）：
     *   let buf = Array<UInt8>(4096, repeat: 0)
     *   while (true) {
     *       let n = resp.readBody(buf)
     *       if (n <= 0) { break }
     * // 处理 buf[0..n]
     *   }
     */
    public func readBody(buf: Array<UInt8>): Int64 {
        let data = body.getArray()
        let limit = body.getLimit()
        let available = limit - bodyReadPos
        if (available <= 0) { return 0 }
        let toRead = if (available < buf.size) { available } else { buf.size }
        var i: Int64 = 0
        while (i < toRead) { buf[i] = data[bodyReadPos + i]; i += 1 }
        bodyReadPos += toRead
        toRead
    }

    private var bodyReadPos: Int64 = 0

    /**
     * 从响应体中读取下一行。
     * 处理 \r\n（CRLF）、\r（CR）和 \n（LF）行尾。
     * 返回 Some(line)，无更多数据时返回 None。
     *
     * 返回的行不包含尾部行尾字符。
     *
     * 用法（用于 SSE/流式传输的逐行读取）：
     *   while (true) {
     *       match (resp.readLine()) {
     *           case Some(line) => println(line)
     *           case None => break
     *       }
     *   }
     */
    public func readLine(): ?String {
        let data = body.getArray()
        let limit = body.getLimit()
        if (bodyReadPos >= limit) { return None }

        var lineBuf = ArrayList<UInt8>()
        while (bodyReadPos < limit) {
            let ch = data[bodyReadPos]
            bodyReadPos += 1
            if (ch == b'\n') {
                // LF 行尾 —— 返回累积的行
                return Some(String.fromUtf8(lineBuf.toArray()))
            } else if (ch == b'\r') {
                // CR 或 CRLF —— 向前窥探 LF
                if (bodyReadPos < limit && data[bodyReadPos] == b'\n') {
                    bodyReadPos += 1  // 消耗换行符 LF
                }
                return Some(String.fromUtf8(lineBuf.toArray()))
            }
            lineBuf.add(ch)
        }
        // 返回最后一行（无尾部换行符）
        if (lineBuf.size > 0) {
            Some(String.fromUtf8(lineBuf.toArray()))
        } else {
            None
        }
    }

    /**
     * 将响应体读取位置重置到开头。
     * 允许重新读取响应体。
     */
    public func resetRead(): Unit {
        bodyReadPos = 0
    }

    public func buildStatusLine(): String {
        "${version.toString()} ${status.code} ${status.reasonPhrase}\r\n"
    }

    public func toBytes(): Array<UInt8> {
        let statusLineBytes = unsafe { buildStatusLine().rawData() }
        let headerBytes = headers.toBytes()
        let bodyLen = body.getLimit()
        let total = statusLineBytes.size + headerBytes.size + 2 + bodyLen
        let result = Array<UInt8>(total, repeat: 0)
        var offset: Int64 = 0

        statusLineBytes.copyTo(result, 0, offset, statusLineBytes.size)
        offset += statusLineBytes.size

        if (headerBytes.size > 0) {
            headerBytes.copyTo(result, 0, offset, headerBytes.size)
            offset += headerBytes.size
        }

        // \r\n 分隔符
        result[offset] = b'\r'; offset++
        result[offset] = b'\n'; offset++

        if (bodyLen > 0) {
            body.getArray().copyTo(result, 0, offset, bodyLen)
        }

        result
    }

    /**
     * 将此响应直接写入连接，无需构建完整的内存字节数组。
     * 这避免了 toBytes() 的双重分配
     * 对于大响应，将状态行、头部和主体
     * 顺序写入连接。
     *
    * 返回写入的总字节数。
    */
    /**
     * 关闭响应主体。关闭后调用 bodyAsString()/bodyAsBytes() 将抛出 BodyReadAfterCloseException。
     */
    public func bodyClose(): Unit {
        bodyClosed = true
    }

   public func writeTo(conn: Connection): Int64 {
       // 收集所有部分并在一次调用中写入以最小化系统调用
       let parts = ArrayList<Array<UInt8>>()
       parts.add(unsafe { buildStatusLine().rawData() })
       let headerBytes = headers.toBytes()
       if (headerBytes.size > 0) { parts.add(headerBytes) }
       parts.add(unsafe { "\r\n".rawData() })
        // 检查是否使用分块传输编码，处理响应体和 trailer
        let bodyLen = body.getLimit()
        let isChunked = isTransferEncodingChunked()
        if (isChunked) {
            let rawBody = body.getArray()[0..bodyLen]
            let chunkedBody = ChunkedWriter.encodeChunked(rawBody)
            if (trailers.size > 0) {
                // 去掉 encodeChunked 末尾的 \r\n（chunkTerminator 的最后 2 字节），
                // 替换为 trailer 头 + 结束空行
                let trimmedLen = chunkedBody.size - 2
                parts.add(chunkedBody[0..trimmedLen])
                let trailerBytes = trailers.toBytes()
                if (trailerBytes.size > 0) { parts.add(trailerBytes) }
                parts.add(unsafe { "\r\n".rawData() })
            } else {
                parts.add(chunkedBody)
            }
        } else if (bodyLen > 0) {
            parts.add(body.getArray()[0..bodyLen])
        }
        // 计算总量并拼接到单个缓冲区
        var total: Int64 = 0
        for (p in parts) { total += p.size }
        let combined = Array<UInt8>(total, repeat: 0)
        var offset: Int64 = 0
        for (p in parts) {
            if (p.size > 0) { p.copyTo(combined, 0, offset, p.size); offset += p.size }
        }
        if (combined.size > 0) { conn.write(combined) }
        conn.flush()
        total
    }

   /**
     * 检查响应头是否包含 Transfer-Encoding: chunked。
     * 用于 writeTo() 中判断是否需要分块编码输出。
     */
    private func isTransferEncodingChunked(): Bool {
        match (headers.get("transfer-encoding")) {
            case Some(te) =>
                containsIgnoreCase(unsafe { te.rawData() }, "chunked".toRuneArray())
            case None => false
        }
    }

    /**
     * 创建带 JSON 主体和 Content-Type: application/json 的响应。
     */
    public static func json(status: HttpStatus, json: String): HttpResponse {
        let data = unsafe { json.rawData() }
        let buf = ByteBuffer.fromOwned(data)
        let headers = HttpHeaders()
        headers.set("Content-Type", "application/json")
        headers.set("Content-Length", data.size.toString())
        HttpResponse(status: status, headers: headers, body: buf)
    }

    /**
     * 创建带纯文本主体的响应。
     */
    public static func text(status: HttpStatus, text: String): HttpResponse {
        let data = unsafe { text.rawData() }
        let buf = ByteBuffer.fromOwned(data)
        let headers = HttpHeaders()
        headers.set("Content-Type", "text/plain; charset=utf-8")
        headers.set("Content-Length", data.size.toString())
        HttpResponse(status: status, headers: headers, body: buf)
    }

    /**
     * 创建空响应（无主体）。
     */
    public static func empty(status: HttpStatus): HttpResponse {
        HttpResponse(status: status)
    }

    /**
     * 创建带 Content-Type: text/html; charset=utf-8 的 HTML 响应。
     */
    public static func html(status: HttpStatus, html: String): HttpResponse {
        let data = unsafe { html.rawData() }
        let buf = ByteBuffer.fromOwned(data)
        let headers = HttpHeaders()
        headers.set("Content-Type", "text/html; charset=utf-8")
        headers.set("Content-Length", data.size.toString())
        HttpResponse(status: status, headers: headers, body: buf)
    }

    /**
     * 创建带 Location 头部的重定向响应。
     */
    public static func redirect(url: String, status!: HttpStatus = HttpStatus.FOUND): HttpResponse {
        let headers = HttpHeaders()
        headers.set("Location", url)
        HttpResponse(status: status, headers: headers)
    }

    /**
     * Create a response with 分块传输 encoding (streaming body).
     * 如果提供了 trailerNames，根据 RFC 7230 第 4.4 节声明 Trailer 头部。
     */
    public static func chunked(status: HttpStatus, trailerNames!: ?Array<String> = None): HttpResponse {
        let headers = HttpHeaders()
        headers.set("Transfer-Encoding", "chunked")
        match (trailerNames) {
            case Some(names) =>
                if (names.size > 0) {
                    var trailerValue = ""
                    var first = true
                    for (name in names) {
                        if (first) { first = false } else { trailerValue += ", " }
                        trailerValue += name
                    }
                    headers.set("Trailer", trailerValue)
                }
            case None => ()
        }
        HttpResponse(status: status, headers: headers)
    }

    /**
     * 创建带 Content-Type 头部和原始字节主体的响应。
     */
    public static func bytes(status: HttpStatus, contentType: String, data: Array<UInt8>): HttpResponse {
        let buf = ByteBuffer.fromOwned(data)
        let headers = HttpHeaders()
        headers.set("Content-Type", contentType)
        headers.set("Content-Length", data.size.toString())
        HttpResponse(status: status, headers: headers, body: buf)
    }

    /**
     * 在此响应上设置 Set-Cookie 头部。流式风格。
     */
    public func withCookie(name: String, value: String, path!: String = "/", maxAge!: ?Int64 = None, httpOnly!: Bool = false, secure!: Bool = false, sameSite!: ?String = None): HttpResponse {
        var cookie = "${name}=${value}; Path=${path}"
        match (maxAge) {
            case Some(age) => cookie += "; Max-Age=${age}"
            case None => ()
        }
        if (httpOnly) { cookie += "; HttpOnly" }
        if (secure) { cookie += "; Secure" }
        match (sameSite) {
            case Some(ss) => cookie += "; SameSite=${ss}"
            case None => ()
        }
        headers.add("Set-Cookie", cookie)
        this
    }
}
