package http_lib.server
/**
 * SSE（Server-Sent Events）写入器。
 * 通过流式响应发送事件到客户端（text/event-stream）。
 */

import std.sync.AtomicBool
import http_lib.buffer.ByteBuffer
import http_lib.message.HttpResponse
import http_lib.core.HttpHeaders
import http_lib.connection.Connection

/**
 * SSE（Server-Sent Events）流式事件写入器。
 *
 * 包装 HttpResponse 以支持 SSE 流式传输（W3C SSE 规范）。
 * 每个事件通过 flush() 立即写入连接。
 * SSE（Server-Sent Events）写入器。
 * data: <text>\n\n
 * event: <type>\ndata: <text>\n\n
 * id: <id>\ndata: <text>\n\n
 *
 * 用法：
 *   let sseWriter = SSEWriter(response, connection)
 * sseWriter.sendData("hello")
 * sseWriter.sendEvent("message", "hello world", id: "42")
 * sseWriter.close()
 */
public class SSEWriter {
    private var resp: HttpResponse
    private var closed: AtomicBool = AtomicBool(false)
    private var lastEventId: String = ""
    private var conn: Connection

    /**
     * 创建包装 HttpResponse 和 Connection 的新 SSEWriter。
     * 响应的 Content-Type 设置为 text/event-stream。
     * 提供底层连接以便事件立即写入。
     */
    public init(resp: HttpResponse, conn: Connection) {
        this.resp = resp
        this.conn = conn
        resp.headers.set("Content-Type", "text/event-stream")
        resp.headers.set("Cache-Control", "no-cache")
        resp.headers.set("Connection", "keep-alive")
    }

    /**
     * 立即向连接写入原始字节。
     */
    private func writeBytes(data: Array<UInt8>): Unit {
        if (closed.load()) { return }
        try {
            conn.write(data)
        } catch (e: Exception) {
            closed.store(true)
        }
    }

    /**
     * 发送带可选事件类型和 ID 的 SSE 事件。
     *
     * @param event  事件类型（如 "message"、"update"）
     * @param data   事件数据载荷
     * @param id     可选事件 ID（用于 Last-Event-ID 跟踪）
     */
    public func sendEvent(event: String, data: String, id!: String = ""): Unit {
        if (closed.load()) { return }

        // 预计算总大小以避免重新分配
        var estimatedSize: Int64 = 1  // 末尾的 '\n'
        if (id.size > 0) {
            estimatedSize += id.size + 4  // "id: ${id}\n" 事件 ID 行
        }
        if (event.size > 0) {
            estimatedSize += event.size + 7  // "event: ${event}\n" 事件类型行
        }
        let dataLines = data.split("\n")
        for (line in dataLines) {
            estimatedSize += line.size + 6  // "data: ${line}\n" 数据行
        }

        let buf = ByteBuffer(capacity: estimatedSize)

        // 事件 ID
        if (id.size > 0) {
            buf.writeString("id: ${id}\n")
            lastEventId = id
        }

        // 事件类型
        if (event.size > 0) {
            buf.writeString("event: ${event}\n")
        }

        // 数据 — 根据 SSE 规范按换行符分割
        for (line in dataLines) {
            buf.writeString("data: ${line}\n")
        }

        // 空行以终止事件
        buf.writeByte(b'\n')

        writeBytes(buf.toArray())
    }

    /**
     * 发送纯数据的简单 SSE 事件。
     *
     * @param data  事件数据载荷
     */
    public func sendData(data: String): Unit {
        if (closed.load()) { return }

        let dataLines = data.split("\n")
        var estimatedSize: Int64 = 1  // 末尾的 '\n'
        for (line in dataLines) {
            estimatedSize += line.size + 6  // "data: ${line}\n" 数据行
        }
        let buf = ByteBuffer(capacity: estimatedSize)

        for (line in dataLines) {
            buf.writeString("data: ${line}\n")
        }
        buf.writeByte(b'\n')

        writeBytes(buf.toArray())
    }

    /**
     * 在 SSE 流中发送注释行。
     * 注释以 ":" 开头，被客户端忽略。
     *
     * @param comment  评论文本（不含前导 ":"）
     */
    public func sendComment(comment: String): Unit {
        if (closed.load()) { return }
        let commentBytes = unsafe { (": ${comment}\n").rawData() }
        writeBytes(commentBytes)
    }

    /**
     * 向客户端发送重试指令。
     * 告诉客户端在重连前等待指定的毫秒数。
     *
     * @param ms  重连前等待的毫秒数
     */
    public func sendRetry(ms: Int64): Unit {
        if (closed.load()) { return }
        let retryBytes = unsafe { ("retry: ${ms}\n\n").rawData() }
        writeBytes(retryBytes)
    }

    /**
     * 刷新所有待处理数据到底层连接。
     */
    public func flush(): Unit {
        if (closed.load()) { return }
        try {
            conn.flush()
        } catch (e: Exception) {
            closed.store(true)
        }
    }

    /**
     * 获取 SSE 输出为字符串（流式传输时为空）。
     */
    public func toString(): String {
        ""
    }

    /**
     * 获取 SSE 输出为字节（流式传输时为空）。
     */
    public func toBytes(): Array<UInt8> {
        []
    }

    /**
     * 获取累积数据的大小（流式传输时始终为 0）。
     */
    public prop size: Int64 {
        get() { 0 }
    }

    /**
     * 检查 SSE 流是否已关闭。
     */
    public func isClosed(): Bool { closed.load() }

    /**
     * 关闭 SSE 流。
     * 调用 close() 后，不能再发送数据。
     */
    public func close(): Unit {
        if (closed.load()) { return }
        closed.store(true)
        try {
            conn.flush()
        } catch (_: Exception) {}
    }
}
