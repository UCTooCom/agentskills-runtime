package http_lib.core

import std.deriving.*

/**
 * HTTP 协议版本枚举。
 * 支持 HTTP/1.0、HTTP/1.1、HTTP/2（h2）和 HTTP/3（h3）。
 * 提供 toString 格式化为标准版本字符串（如 "HTTP/1.1"），
 * 以及 compareTo 方法用于版本优先级比较。
 */
@Derive[Hashable, Equatable]
public enum HttpVersion <: ToString {
    | HTTP_1_0
    | HTTP_1_1
    | HTTP_2_0
    | HTTP_3_0

    /**
     * 返回 HTTP 版本字符串（如 "HTTP/1.1"）。
     */
    public func toString(): String {
        match (this) {
            case HTTP_1_0 => "HTTP/1.0"
            case HTTP_1_1 => "HTTP/1.1"
            case HTTP_2_0 => "HTTP/2.0"
            case HTTP_3_0 => "HTTP/3.0"
        }
    }

    /**
     * 从字符串解析 HTTP 版本。支持 "HTTP/2" 和 "HTTP/2.0"。
     */
    public static func parse(version: String): Option<HttpVersion> {
        if (version == "HTTP/1.0") { Some(HTTP_1_0) }
        else if (version == "HTTP/1.1") { Some(HTTP_1_1) }
        else if (version == "HTTP/2.0" || version == "HTTP/2") { Some(HTTP_2_0) }
        else if (version == "HTTP/3.0" || version == "HTTP/3") { Some(HTTP_3_0) }
        else { None }
    }

    /**
     * 判断是否支持持久连接（HTTP/1.1 及以上）。
     */
    public func supportsPersistentConnection(): Bool {
        match (this) {
            case HTTP_1_0 => false
            case _ => true
        }
    }
}
