package ystyle::jsonrpc

import gjson.*
import std.collection.*
import std.io.*
import stdx.encoding.json.stream.*

// ── 序列化：流式直连（不经 jsonvalue DOM 中转，单遍写出）──

public func serializeRequest(req: Request): Array<Byte> {
    let buffer = ByteBuffer()
    let writer = JsonWriter(buffer)
    req.toJson(writer)
    writer.flush()
    buffer.flush()
    buffer.bytes()
}

public func deserializeRequest(bytes: Array<Byte>): Request {
    Request.fromJson(JsonReader(ByteBuffer(bytes)))
}

public func serializeResponse(resp: Response): Array<Byte> {
    let buffer = ByteBuffer()
    let writer = JsonWriter(buffer)
    resp.toJson(writer)
    writer.flush()
    buffer.flush()
    buffer.bytes()
}

public func deserializeResponse(bytes: Array<Byte>): Response {
    Response.fromJson(JsonReader(ByteBuffer(bytes)))
}

public func serializeNotification(notif: Notification): Array<Byte> {
    let buffer = ByteBuffer()
    let writer = JsonWriter(buffer)
    notif.toJson(writer)
    writer.flush()
    buffer.flush()
    buffer.bytes()
}

public func deserializeNotification(bytes: Array<Byte>): Notification {
    Notification.fromJson(JsonReader(ByteBuffer(bytes)))
}

public enum Message {
    | SingleRequest(Request)
    | SingleResponse(Response)
    | SingleNotification(Notification)
    | InvalidRequest(JsonRpcError)
    | BatchRequest(ArrayList<Message>)
    | BatchResponse(ArrayList<Response>)
}

// 取首个非空白字符，用于区分对象/数组（避免为取一个字符做整包解析）
private func firstNonWsChar(bytes: Array<Byte>): Byte {
    for (b in bytes) {
        if (b != b' ' && b != b'\t' && b != b'\n' && b != b'\r') {
            return b
        }
    }
    return b'\0'
}

/**
 * 消息解析（gjson 快速分类 + 流式反序列化）：
 * - 先 gjson.ValidBytes 做语法校验（保住 -32700 语义，且比全量 DOM 解析便宜两个数量级）
 * - 顶层浅扫描 method/id/result/error 完成分类，不建 DOM
 * - 命中类型后用现有 JsonReader 流式 fromJson 直连反序列化，params 只解析一次
 *   且只发生在真正需要该消息的时候（未知方法在 server 层快速拒绝，全程零 jsonvalue）
 */
public func parseMessage(bytes: Array<Byte>): Message {
    if (!validBytes(bytes)) {
        throw JsonRpcException(ErrorCodes.PARSE_ERROR, "Parse error")
    }
    match (firstNonWsChar(bytes)) {
        case b'[' => parseBatch(bytes)
        case b'{' => parseSingle(bytes)
        case _ => throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid message: must be object or array")
    }
}

private func parseSingle(bytes: Array<Byte>): Message {
    try {
        if (getBytes(bytes, "method").exists()) {
            if (getBytes(bytes, "id").exists()) {
                Message.SingleRequest(Request.fromJson(JsonReader(ByteBuffer(bytes))))
            } else {
                Message.SingleNotification(Notification.fromJson(JsonReader(ByteBuffer(bytes))))
            }
        } else if (getBytes(bytes, "result").exists() || getBytes(bytes, "error").exists()) {
            Message.SingleResponse(Response.fromJson(JsonReader(ByteBuffer(bytes))))
        } else {
            throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid message: missing method or result/error")
        }
    } catch (e: Exception) {
        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid message: ${e.message}")
    }
}

private func parseBatch(bytes: Array<Byte>): Message {
    // parseBytes().array() 一次扫描取出各元素 raw（不建 DOM），避免逐索引重复全量扫描
    let arr = parseBytes(bytes).array()
    if (arr.size == 0) {
        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Empty batch")
    }
    let first = arr[0]
    if (!first.isObject()) {
        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid batch: first element must be object")
    }
    if (first.get("method").exists()) {
        let items = ArrayList<Message>()
        for (item in arr) {
            try {
                let hasValidVersion = item.get("jsonrpc").string() == "2.0"
                if (!hasValidVersion) {
                    items.add(Message.InvalidRequest(JsonRpcError(ErrorCodes.INVALID_REQUEST, "Invalid jsonrpc version")))
                } else if (item.get("method").exists()) {
                    if (item.get("id").exists()) {
                        items.add(Message.SingleRequest(Request.fromJson(JsonReader(ByteBuffer(item.raw.toArray())))))
                    } else {
                        items.add(Message.SingleNotification(Notification.fromJson(JsonReader(ByteBuffer(item.raw.toArray())))))
                    }
                } else {
                    items.add(Message.InvalidRequest(JsonRpcError(ErrorCodes.INVALID_REQUEST, "Missing method")))
                }
            } catch (e: Exception) {
                items.add(Message.InvalidRequest(JsonRpcError(ErrorCodes.INVALID_REQUEST, "Invalid item: ${e.message}")))
            }
        }
        Message.BatchRequest(items)
    } else if (first.get("result").exists() || first.get("error").exists()) {
        let items = ArrayList<Response>()
        for (item in arr) {
            try {
                items.add(Response.fromJson(JsonReader(ByteBuffer(item.raw.toArray()))))
            } catch (e: Exception) {
                () // skip invalid items in batch response
            }
        }
        Message.BatchResponse(items)
    } else {
        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid batch: first element must have method or result/error")
    }
}
