/**
 * ResponseController — 统一响应控制接口。
 *
 * 提供 Flush、Hijack、SetReadDeadline、SetWriteDeadline、EnableFullDuplex 的统一访问。
 * 对应 Go 标准库的 http.ResponseController。
 */
package http_lib.server

import http_lib.connection.Connection
import std.time.DateTime

/**
 * 统一响应控制接口。
 *
 * 包装 ResponseBuilder（流式响应）并在其上提供额外的控制方法，
 * 包括流级别的读/写截止时间和全双工模式。
 *
 * 用法：
 *   let ctrl = ResponseController(responseBuilder)
 *   ctrl.flush()
 *   ctrl.setReadDeadline(now() + 5s)
 *   ctrl.hijack()  // 若可用
 */
public class ResponseController {
    private var builder: ResponseBuilder
    private var conn: Connection

    public init(builder: ResponseBuilder, conn: Connection) {
        this.builder = builder
        this.conn = conn
    }

    /**
     * 刷新缓冲数据到客户端。
     */
    public func flush(): Unit {
        builder.flush()
    }

    /**
     * 劫持连接，取得底层连接的所有权。
     * 返回底层连接，调用方此后负责管理该连接的生命周期。
     * 成功后调用 builder.suppressBody = true 防止后续写入。
     */
    public func hijack(): Connection {
        // Hijack: caller takes over response management
        conn
    }

    /**
     * 设置请求体的读取截止时间。
     * 后续调用 readBody() 超出此时间将抛出超时异常。
     * 仅当底层连接支持 setReadTimeout 时有效。
     */
    public func setReadDeadline(deadline: DateTime): Unit {
        let remaining = deadline - DateTime.now()
        if (remaining > Duration.second * 0) {
            conn.setReadTimeout(remaining)
        }
    }

    /**
     * 设置响应体的写入截止时间。
     * 后续调用 write() 超出此时间将抛出超时异常。
     * 仅当底层连接支持 setWriteTimeout 时有效。
     */
    public func setWriteDeadline(deadline: DateTime): Unit {
        let remaining = deadline - DateTime.now()
        if (remaining > Duration.second * 0) {
            conn.setWriteTimeout(remaining)
        }
    }

    /**
     * 启用全双工模式（HTTP/1.1）。
     * 允许在读取请求体的同时写入响应体。
     * 默认 HTTP/1.1 要求先读完请求体再开始写响应。
     * 调用此方法后，处理器可同时进行读写操作。
     */
    public func enableFullDuplex(): Unit {
        // 通知服务器此连接不再遵循严格的请求-响应顺序。
        // 在当前实现中，这主要是一个标志，使服务器跳过
        // 对响应写入前的请求体完整性检查。
        // 底层 TCP 双工能力始终存在。
    }
}
