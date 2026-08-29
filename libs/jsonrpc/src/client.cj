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

    public func registerRequestHandler(method: String, handler: RequestCallback): Unit {
        this.requestHandlers.add(method, handler)
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
    
    public func isClosed(): Bool {
        synchronized(this.lock) {
            !this.running
        }
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
        match (this.requestHandlers.get(req.method)) {
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