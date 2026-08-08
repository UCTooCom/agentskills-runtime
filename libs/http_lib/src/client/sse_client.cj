package http_lib.client
/**
 * SSE（Server-Sent Events）客户端。
 * 通过事件流接口消费 SSE 端点的事件推送。
 */

import std.collection.HashMap
import std.convert.Parsable
import std.unicode.*
import http_lib.core.{HttpHeaders, HttpMethod}
import http_lib.message.HttpRequest

/**
 * SSE（Server-Sent Events）事件数据结构。
 */
public class SSEEvent {
    public var eventType: String
    public var data: String
    public var eventId: String
    public var lastEventId: String

    public init(eventType!: String = "message", data!: String = "", eventId!: String = "", lastEventId!: String = "") {
        this.eventType = eventType
        this.data = data
        this.eventId = eventId
        this.lastEventId = lastEventId
    }
}

/**
 * SSE 客户端（EventSource）。
 *
 * 使用 HttpClient 建立 SSE 流式连接并逐行解析服务器推送的事件。
 * 底层采用流式读取，不会一次性缓冲整个响应体。
 *
 * 用法：
 *   let client = SSEClient("http://example.com/events")
 *   client.onMessage = {event => println(event.data)}
 *   client.on("update", {event => println("收到更新: ${event.data}")})
 *   client.connect()
 */
public class SSEClient {
    private var url: String
    private var httpClient: HttpClient
    private var lastEventId: String = ""
    private var retryDelay: Int64 = 3000
    private var connected: Bool = false
    private var stopped: Bool = false

    public var onOpen: ?() -> Unit = None
    public var onMessage: ?(SSEEvent) -> Unit = None
    public var onError: ?(String) -> Unit = None
    public var onEvent: HashMap<String, (SSEEvent) -> Unit> = HashMap<String, (SSEEvent) -> Unit>()

    public init(url: String, httpClient!: HttpClient = getSharedClient()) {
        this.url = url
        this.httpClient = httpClient
    }

    /**
     * 建立 SSE 流式连接。
     * 使用 sendStream() 逐行读取事件，不会一次性缓冲整个响应体。
     */
    public func connect(): Unit {
        if (connected || stopped) { return }
        connected = true
        let request = HttpRequest(method: HttpMethod.GET, url: url)
        request.headers.set("Accept", "text/event-stream")
        request.headers.set("Cache-Control", "no-cache")
        if (lastEventId.size > 0) {
            request.headers.set("Last-Event-ID", lastEventId)
        }
        try {
            let response = httpClient.sendStream(request)
            if (response.status.code != 200u16) {
                match (onError) {
                    case Some(cb) => cb("HTTP ${response.status.code}")
                    case None => ()
                }
                connected = false
                return
            }
            match (onOpen) {
                case Some(cb) => cb()
                case None => ()
            }
            // 流式逐行读取 SSE 事件
            streamEvents(response)
        } catch (e: Exception) {
            match (onError) {
                case Some(cb) => cb("SSE 连接错误: ${e.message}")
                case None => ()
            }
            connected = false
        }
    }

    /**
     * 断开 SSE 连接。
     */
    public func close(): Unit {
        stopped = true
        connected = false
    }

    /**
     * 注册自定义事件类型回调。
     */
    public func on(eventType: String, callback: (SSEEvent) -> Unit): Unit {
        onEvent[eventType] = callback
    }

    /**
     * 从 StreamedHttpResponse 逐行读取并触发 SSE 事件。
     * 使用流式读取，不会一次性将整个响应体缓冲到内存。
     */
    private func streamEvents(response: StreamedHttpResponse): Unit {
        var currentType = "message"
        var currentData = ""
        var currentId = lastEventId

        while (!stopped) {
            try {
                let line = response.readLine()
                if (line.size == 0 && response.isClosed()) {
                    break
                }
                if (line.size == 0) {
                    // 空行 = 事件分隔符
                    if (currentData.size > 0 || currentType != "message") {
                        fireEvent(currentType, currentData, currentId)
                    }
                    currentType = "message"
                    currentData = ""
                    continue
                }
                // SSE 注释行
                if (line.startsWith(":")) {
                    continue
                }
                // 解析 field: value 行
                match (line.indexOf(":")) {
                    case Some(colonPos) =>
                        let fieldName = line[..colonPos].trimAscii()
                        let fieldValue = line[colonPos + 1..]
                        let trimmedValue = trimStartSpace(fieldValue)
                        match (fieldName) {
                            case "event" => currentType = trimmedValue
                            case "data" =>
                                if (currentData.size > 0) { currentData += "\n" }
                                currentData += trimmedValue
                            case "id" =>
                                if (trimmedValue.size > 0) {
                                    currentId = trimmedValue
                                }
                            case "retry" =>
                                try {
                                    let ms = Int64.parse(trimmedValue)
                                    if (ms > 0) { retryDelay = ms }
                                } catch (_: Exception) {}
                            case _ => ()
                        }
                    case None =>
                        let fieldName = line.trimAscii()
                        match (fieldName) {
                            case "event" => currentType = ""
                            case "data" => currentData += "\n"
                            case "id" => currentId = lastEventId
                            case "retry" => ()
                            case _ => ()
                        }
                }
            } catch (_: Exception) {
                break
            }
        }
        // 触发最后一个未完成的事件
        if (currentData.size > 0) {
            fireEvent(currentType, currentData, currentId)
        }
        lastEventId = currentId
        response.close()
        connected = false
    }

    /**
     * 触发事件回调。
     */
    private func fireEvent(eventType: String, data: String, id: String): Unit {
        let event = SSEEvent(eventType: eventType, data: data, eventId: id, lastEventId: lastEventId)
        if (eventType == "message") {
            match (onMessage) {
                case Some(cb) => cb(event)
                case None => ()
            }
        }
        match (onEvent.get(eventType)) {
            case Some(cb) => cb(event)
            case None => ()
        }
    }

    /**
     * 去除字符串开头的一个空格（SSE 规范：冒号后的空格）。
     */
    private func trimStartSpace(s: String): String {
        if (s.size > 0 && s[0] == b' ') {
            return s[1..]
        }
        s
    }
}
