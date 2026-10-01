package ystyle::jsonrpc

import jsonvalue.*
import std.collection.concurrent.*
import std.collection.{HashMap, ArrayList}
import std.sync.*
import std.io.*
import stdx.encoding.json.stream.*

public class PendingRequest {
    public let id: RequestId
    private var response: ?Response = None
    private let lock: Mutex = Mutex()
    private let cond: Condition

    public init(id: RequestId) {
        this.id = id
        this.cond = synchronized(this.lock) {
            this.lock.condition()
        }
    }

    public func setResponse(resp: Response): Unit {
        synchronized(this.lock) {
            this.response = resp
            this.cond.notifyAll()
        }
    }

    public func waitForResponse(timeout!: Duration = 30 * Duration.second): ?Response {
        synchronized(this.lock) {
            while (this.response.isNone()) {
                if (!this.cond.wait(timeout: timeout)) {
                    return None
                }
            }
            this.response
        }
    }

    // 检查响应是否已就绪（非阻塞）
    public func isReady(): Bool {
        synchronized(this.lock) {
            this.response.isSome()
        }
    }

    // 获取已就绪的响应（非阻塞；未就绪返回 None）
    public func getResponse(): ?Response {
        synchronized(this.lock) {
            this.response
        }
    }
}

public type NotificationCallback = (Notification) -> Unit
public type RequestCallback = (Request) -> ?JsonValue

public class JsonRpcClient {
    private let transport: Transport
    private let framing: Framing
    private let pendingRequests: ConcurrentHashMap<RequestId, PendingRequest> = ConcurrentHashMap<RequestId, PendingRequest>()
    private let lock: Mutex = Mutex()
    private var nextId: Int64 = 1
    private var running: Bool = false
    private var receiveThread: ?Future<Unit> = None
    // 通知回调列表（set 覆盖、add 追加；接收循环遍历调用全部）
    private let notificationCbs: ArrayList<NotificationCallback> = ArrayList<NotificationCallback>()
    private let requestHandlers: HashMap<String, RequestCallback> = HashMap<String, RequestCallback>()

    public init(transport: Transport, framing!: Framing = ContentLengthFraming()) {
        this.transport = transport
        this.framing = framing
    }

    /**
     * 设置单个通知回调（覆盖已有回调）
     */
    public func setNotificationCallback(cb: NotificationCallback): Unit {
        synchronized(this.lock) {
            this.notificationCbs.clear()
            this.notificationCbs.add(cb)
        }
    }

    /**
     * 设置多个通知回调（整体覆盖已有回调）
     */
    public func setNotificationCallback(cbs: ArrayList<NotificationCallback>): Unit {
        synchronized(this.lock) {
            this.notificationCbs.clear()
            for (cb in cbs) {
                this.notificationCbs.add(cb)
            }
        }
    }

    /**
     * 追加一个通知回调（保留已有回调）
     */
    public func addNotificationCallback(cb: NotificationCallback): Unit {
        synchronized(this.lock) {
            this.notificationCbs.add(cb)
        }
    }

    /**
     * 注册「插件 → 宿主」请求处理器。
     *
     * 【并发红线】requestHandlers 是普通 HashMap，却被两个线程同时访问：
     * 宿主主线程（registerHostHandlers / CordisHostServices.registerFor）写，
     * 本 client 的 IPC 接收线程（handleIncomingRequest）读。此前完全无锁，
     * HashMap 在并发写 + 扩容时可能进入损坏状态（经典场景是遍历/查找陷入死循环），
     * 这与「启动期偶发、挂死点每次都不一样」的现象高度吻合。故统一用 this.lock 保护。
     */
    public func registerRequestHandler(method: String, handler: RequestCallback): Unit {
        synchronized(this.lock) {
            this.requestHandlers.add(method, handler)
        }
    }

    public func sendResponse(id: RequestId, result: JsonValue): Unit {
        let resp = Response(id: Some(id), result: result)
        let bytes = serializeResponse(resp)
        this.transport.send(this.framing.encode(bytes))
    }

    public func start(): Unit {
        this.running = true
        this.receiveThread = spawn {
            => this.receiveLoop()
        }
    }

    public func call<T, R>(method: String, params!: ?T, timeout!: Duration = 30 * Duration.second): Result<R> 
        where T <: JsonSerializable, R <: JsonDeserializable<R> {
        let id = this.generateId()
        let req = Request(id, method, params: this.toJsonValue(params))
        let bytes = serializeRequest(req)
        let pending = PendingRequest(id)
        this.pendingRequests.add(id, pending)
        this.transport.send(this.framing.encode(bytes))

        match (pending.waitForResponse(timeout: timeout)) {
            case Some(resp) =>
                this.pendingRequests.remove(id)
                if (let Some(result) <- resp.result) {
                    try {
                        Result.Ok(JsonValue.toObject<R>(result))
                    } catch (e: Exception) {
                        Result.Err("Failed to parse result: ${e.message}")
                    }
                } else if (let Some(error) <- resp.error) {
                    Result.Err("[${error.code}] ${error.message}")
                } else {
                    Result.Err("Invalid response")
                }
            case None =>
                this.pendingRequests.remove(id)
                Result.Err("Request timeout")
        }
    }

    public func call(method: String, timeout!: Duration = 30 * Duration.second): Result<JsonValue> {
        this.call<JsonValue, JsonValue>(method, params: None, timeout: timeout)
    }

    public func notify<T>(method: String, params!: ?T): Unit where T <: JsonSerializable {
        let notif = Notification(method, params: this.toJsonValue(params))
        let bytes = serializeNotification(notif)
        this.transport.send(this.framing.encode(bytes))
    }

    public func notify(method: String): Unit {
        this.notify<JsonValue>(method, params: None)
    }

    public func close(): Unit {
        synchronized(this.lock) {
            this.running = false
        }
        this.transport.close()
        if (let Some(thread) <- this.receiveThread) {
            thread.cancel()
        }
    }
    
    /**
     * 探测连接是否已关闭（崩溃检测用）。
     *
     * 【死锁红线】本方法必须**永不阻塞**，原因（2026-10-01 启动挂死实测）：
     * 它是存活探测，会被宿主线程在启动关键路径上高频调用
     * （PluginHost.reconcileDesired 的 healCrashed、awaitActive 的 G 点）。
     * 宿主主线程一旦在这里等 client.lock 等不到，整个 runtime 就起不来。
     * 因此改为 tryLock：拿不到锁就返回「还活着」这个保守值（不触发误重启），
     * 绝不等待。注意仓颉 Mutex 是可重入锁，同一线程重复 tryLock 仍会成功。
     */
    public func isClosed(): Bool {
        if (!this.lock.tryLock()) {
            return false
        }
        let closed = !this.running
        this.lock.unlock()
        closed
    }
    
    private func generateId(): RequestId {
        synchronized(this.lock) {
            let id = this.nextId
            this.nextId++
            RequestId.Int(id)
        }
    }

    private func toJsonValue<T>(params: ?T): ?JsonValue where T <: JsonSerializable {
        match (params) {
            case Some(p) => Some(JsonValue.fromObject(p))
            case None => None
        }
    }

    private func receiveLoop(): Unit {
        let buffer = ByteBuffer()
        while (this.running) {
            match (this.transport.receive()) {
                case Some(data) =>
                    buffer.write(data)
                    while (let Some((body, consumed)) <- this.framing.decode(buffer.bytes())) {
                        this.handleMessage(body)
                        buffer.seek(SeekPosition.Current(consumed))
                    }
                case None => this.running = false
            }
        }
    }

    private func handleMessage(body: Array<Byte>): Unit {
        try {
            match (parseMessage(body)) {
                case Message.SingleResponse(resp) => this.handleResponse(resp)
                case Message.BatchResponse(resps) => for (resp in resps) {
                    this.handleResponse(resp)
                }
                case Message.SingleRequest(req) => this.handleIncomingRequest(req)
                case Message.SingleNotification(notif) =>
                    // 遍历调用全部通知回调（支持多订阅）
                    let cbs = synchronized(this.lock) {
                        ArrayList<NotificationCallback>(this.notificationCbs)
                    }
                    for (cb in cbs) {
                        try {
                            cb(notif)
                        } catch (e: Exception) {
                            ()
                        }
                    }
                case _ => ()
            }
        } catch (e: Exception) {
            ()
        }
    }

    private func handleIncomingRequest(req: Request): Unit {
        // 【并发红线】只在持锁期间**取出** handler，随后立刻解锁再调用。
        // 绝不能持 this.lock 调用 handler：handler 内部会 registerRequestHandler
        // （CordisHostServices.registerFor 在 initialize 回调里注册 host.db 等）
        // 或访问宿主其它锁，持锁调用就是自锁 / AB-BA 死锁。
        let handlerOpt = synchronized(this.lock) {
            this.requestHandlers.get(req.method)
        }
        match (handlerOpt) {
            case Some(handler) =>
                match (handler(req)) {
                    case Some(result) =>
                        let resp = Response(id: Some(req.id), result: result)
                        let bytes = serializeResponse(resp)
                        this.transport.send(this.framing.encode(bytes))
                    case None => ()
                }
            case None =>
                let error = JsonRpcError(-32601, "Method not found: ${req.method}")
                let resp = Response(id: Some(req.id), error: error)
                let bytes = serializeResponse(resp)
                this.transport.send(this.framing.encode(bytes))
        }
    }

    private func handleResponse(resp: Response): Unit {
        match (resp.id) {
            case Some(id) => match (this.pendingRequests.get(id)) {
                case Some(pending) => pending.setResponse(resp)
                case None => ()
            }
            case None => () // error response with no id, ignore
        }
    }
}