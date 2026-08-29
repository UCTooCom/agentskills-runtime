package ystyle::jsonrpc

import jsonvalue.*
import stdx.encoding.json.stream.*
import std.deriving.*

@Derive[ToString]
public enum RequestId <: JsonSerializable & JsonDeserializable<RequestId> & Hashable & Equatable<RequestId> {
    | Int(Int64)
    | String(String)

    public func toJson(w: JsonWriter): Unit {
        match (this) {
            case RequestId.Int(i) => w.writeValue(i)
            case RequestId.String(s) => w.writeValue(s)
        }
    }

    public static func fromJson(r: JsonReader): RequestId {
        while (let Some(v) <- r.peek()) {
            match (v) {
                case JsonNumber => return RequestId.Int(r.readValue<Int64>())
                case JsonString => return RequestId.String(r.readValue<String>())
                case _ => r.skip()
            }
        }
        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid RequestId: expected number or string")
    }

    public func hashCode(): Int64 {
        match (this) {
            case RequestId.Int(i) => i
            case RequestId.String(s) => s.hashCode()
        }
    }

    public operator func ==(other: RequestId): Bool {
        match (this) {
            case RequestId.Int(i) => match (other) {
                case RequestId.Int(j) => i == j
                case _ => false
            }
            case RequestId.String(s) => match (other) {
                case RequestId.String(t) => s == t
                case _ => false
            }
        }
    }
}

@Derive[ToString]
public class Request <: JsonSerializable & JsonDeserializable<Request> {
    public let jsonrpc: String = "2.0"
    public let id: RequestId
    public let method: String
    public let params: ?JsonValue

    public init(id: RequestId, method: String, params!: ?JsonValue = None) {
        this.id = id
        this.method = method
        this.params = params
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("jsonrpc").writeValue(this.jsonrpc)
        w.writeName("id")
        this.id.toJson(w)
        w.writeName("method").writeValue(this.method)
        if (let Some(p) <- this.params) {
            w.writeName("params")
            p.toJson(w)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): Request {
        r.startObject()
        var id: ?RequestId = None
        var method: ?String = None
        var params: ?JsonValue = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "jsonrpc" =>
                    let version = r.readValue<String>()
                    if (version != "2.0") {
                        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid jsonrpc version: ${version}")
                    }
                case "id" => id = RequestId.fromJson(r)
                case "method" => method = r.readValue<String>()
                case "params" => params = JsonValue.fromJson(r)
                case _ => r.skip()
            }
        }
        r.endObject()
        Request(id.getOrThrow(), method.getOrThrow(), params: params)
    }
}

@Derive[ToString]
public class Response <: JsonSerializable & JsonDeserializable<Response> {
    public let jsonrpc: String = "2.0"
    public let id: ?RequestId
    public let result: ?JsonValue
    public let error: ?JsonRpcError

    public init(id!: ?RequestId = None, result!: ?JsonValue = None, error!: ?JsonRpcError = None) {
        if (result.isSome() && error.isSome()) {
            throw Exception("Response cannot have both result and error")
        }
        if (result.isNone() && error.isNone()) {
            throw Exception("Response must have either result or error")
        }
        this.id = id
        this.result = result
        this.error = error
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("jsonrpc").writeValue(this.jsonrpc)
        w.writeName("id")
        match (this.id) {
            case Some(id) => id.toJson(w)
            case None => w.writeNullValue()
        }
        if (let Some(r) <- this.result) {
            w.writeName("result")
            r.toJson(w)
        }
        if (let Some(e) <- this.error) {
            w.writeName("error")
            e.toJson(w)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): Response {
        r.startObject()
        var id: ?RequestId = None
        var result: ?JsonValue = None
        var error: ?JsonRpcError = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "jsonrpc" =>
                    let version = r.readValue<String>()
                    if (version != "2.0") {
                        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid jsonrpc version: ${version}")
                    }
                case "id" =>
                    if (r.peek().getOrThrow() == JsonToken.JsonNull) {
                        r.skip()
                        id = None
                    } else {
                        id = RequestId.fromJson(r)
                    }
                case "result" => result = JsonValue.fromJson(r)
                case "error" => error = JsonRpcError.fromJson(r)
                case _ => r.skip()
            }
        }
        r.endObject()
        Response(id: id, result: result, error: error)
    }
}

@Derive[ToString]
public class Notification <: JsonSerializable & JsonDeserializable<Notification> {
    public let jsonrpc: String = "2.0"
    public let method: String
    public let params: ?JsonValue

    public init(method: String, params!: ?JsonValue = None) {
        this.method = method
        this.params = params
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("jsonrpc").writeValue(this.jsonrpc)
        w.writeName("method").writeValue(this.method)
        if (let Some(p) <- this.params) {
            w.writeName("params")
            p.toJson(w)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): Notification {
        r.startObject()
        var method: ?String = None
        var params: ?JsonValue = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "jsonrpc" =>
                    let version = r.readValue<String>()
                    if (version != "2.0") {
                        throw JsonRpcException(ErrorCodes.INVALID_REQUEST, "Invalid jsonrpc version: ${version}")
                    }
                case "method" => method = r.readValue<String>()
                case "params" => params = JsonValue.fromJson(r)
                case _ => r.skip()
            }
        }
        r.endObject()
        Notification(method.getOrThrow(), params: params)
    }
}

@Derive[ToString]
public class JsonRpcError <: JsonSerializable & JsonDeserializable<JsonRpcError> {
    public let code: Int64
    public let message: String
    public let data: ?JsonValue

    public init(code: Int64, message: String, data!: ?JsonValue = None) {
        this.code = code
        this.message = message
        this.data = data
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("code").writeValue(this.code)
        w.writeName("message").writeValue(this.message)
        if (let Some(d) <- this.data) {
            w.writeName("data")
            d.toJson(w)
        }
        w.endObject()
    }

    public static func fromJson(r: JsonReader): JsonRpcError {
        r.startObject()
        var code: ?Int64 = None
        var message: ?String = None
        var data: ?JsonValue = None
        while (r.peek() != EndObject) {
            match (r.readName()) {
                case "code" => code = r.readValue<Int64>()
                case "message" => message = r.readValue<String>()
                case "data" => data = JsonValue.fromJson(r)
                case _ => r.skip()
            }
        }
        r.endObject()
        JsonRpcError(code.getOrThrow(), message.getOrThrow(), data: data)
    }
}

public class ErrorCodes {
    public static let PARSE_ERROR: Int64 = -32700
    public static let INVALID_REQUEST: Int64 = -32600
    public static let METHOD_NOT_FOUND: Int64 = -32601
    public static let INVALID_PARAMS: Int64 = -32602
    public static let INTERNAL_ERROR: Int64 = -32603
}
