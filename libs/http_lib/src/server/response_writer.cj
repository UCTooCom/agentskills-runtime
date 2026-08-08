package http_lib.server

import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse, InMemoryResponseBuilder, HttpError as msgHttpError, HttpNotFound as msgHttpNotFound, HttpRedirect as msgHttpRedirect, wrapHandler, StreamFlusher as msgStreamStreamFlusher}
import http_lib.buffer.ByteBuffer
import http_lib.router.Handler

/**
 * InMemoryResponseBuilder 别名（向后兼容）。
 *
 * 与 message.ResponseBuilder 的关系：
 * - 此类包装了 message.InMemoryResponseBuilder 用于构建响应
 * 发送前完全在内存中。它缓冲状态、头部和主体
 * 在内存中直到 build() 生成最终的 HttpResponse。
 * - message.ResponseBuilder（在同一包中）是一个**独立的**类，它
 * 直接以流式/分块编码写入网络 Connection。
 * 它是此内存写入器的流式对应物。
 * - 对于测试、检查/修改响应的中间件等场景使用此类
 * 适配旧式处理器，以及内存缓冲可接受的小有效载荷场景
 * 是可接受的。
 * - 对于大有效载荷、分块编码、SSE 等场景使用 message.ResponseBuilder
 * 或任何需要流式传输到客户端的场景。
 *
 * 保留用于与使用旧版 API 的现有代码向后兼容
 * server.ResponseBuilder。新代码应使用 message.InMemoryResponseBuilder
 * 或直接使用 message.ResponseBuilder。
 */
public class ResponseBuilder {
    private var inner: InMemoryResponseBuilder

    public init() {
        this.inner = InMemoryResponseBuilder()
    }

    public func writeHeader(statusCode: Int64): Unit { inner.writeHeader(statusCode) }
    public func hasHeaderWritten(): Bool { inner.hasHeaderWritten() }
    public func header(key: String, value: String): Unit { inner.header(key, value) }
    public func write(data: Array<UInt8>): Unit { inner.write(data) }
    public func writeString(s: String): Unit { inner.writeString(s) }
    public func flush(): Unit { inner.flush() }
    public func build(): HttpResponse { inner.build() }
}

/**
 * StreamFlusher 接口从 message 包重新导出。
 */
public interface StreamFlusher {
    func flush(): Unit
}

/**
 * 将 (HttpRequest, server.ResponseBuilder) -> Unit 处理函数
 * 转换为标准的 (HttpRequest) -> HttpResponse 处理器。
 */
public func wrapResponseBuilderHandler(handler: (HttpRequest, ResponseBuilder) -> Unit): Handler {
    {req: HttpRequest =>
        let rw = ResponseBuilder()
        handler(req, rw)
        if (!rw.hasHeaderWritten()) {
            rw.writeHeader(200)
        }
        rw.build()
    }
}

// ---- HTTP 辅助函数（委托给 message 包）----

public func HttpError(req: HttpRequest, message: String, statusCode: Int64): HttpResponse {
    msgHttpError(req, message, statusCode)
}

public func HttpNotFound(req: HttpRequest): HttpResponse {
    msgHttpNotFound(req)
}

public func HttpRedirect(req: HttpRequest, url: String, statusCode: Int64): HttpResponse {
    msgHttpRedirect(req, url, statusCode)
}

public func NotFoundResponder(): Handler {
    {req => msgHttpNotFound(req) }
}

public func RedirectResponder(url: String, statusCode: Int64): Handler {
    {req => msgHttpRedirect(req, url, statusCode) }
}
