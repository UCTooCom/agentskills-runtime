package http_lib.core

import std.deriving.*

/**
 * HTTP 方法枚举（RFC 7231 和 RFC 5789）。
 *
 * 支持所有标准 HTTP 方法：GET、HEAD、POST、PUT、DELETE、CONNECT、OPTIONS、TRACE、PATCH。
 * 提供 toString() 序列化为标准大写方法名，以及 parse() 从字符串反序列化。
 */
@Derive[Hashable, Equatable]
public enum HttpMethod <: ToString {
    | GET
    | HEAD
    | POST
    | PUT
    | DELETE
    | CONNECT
    | OPTIONS
    | TRACE
    | PATCH

/**
 * 返回 HTTP 方法的大写名称（如 "GET"）。
 * 用于请求行序列化。
 */
    public func toString(): String {
        match (this) {
            case GET => "GET"
            case HEAD => "HEAD"
            case POST => "POST"
            case PUT => "PUT"
            case DELETE => "DELETE"
            case CONNECT => "CONNECT"
            case OPTIONS => "OPTIONS"
            case TRACE => "TRACE"
            case PATCH => "PATCH"
        }
    }

/**
 * 从字符串解析 HTTP 方法（大小写敏感）。
 * 输入必须为大写形式。解析失败返回 None。
 */
    public static func parse(method: String): Option<HttpMethod> {
        if (method == "GET") { Some(GET) }
        else if (method == "HEAD") { Some(HEAD) }
        else if (method == "POST") { Some(POST) }
        else if (method == "PUT") { Some(PUT) }
        else if (method == "DELETE") { Some(DELETE) }
        else if (method == "CONNECT") { Some(CONNECT) }
        else if (method == "OPTIONS") { Some(OPTIONS) }
        else if (method == "TRACE") { Some(TRACE) }
        else if (method == "PATCH") { Some(PATCH) }
        else { None }
    }
}
