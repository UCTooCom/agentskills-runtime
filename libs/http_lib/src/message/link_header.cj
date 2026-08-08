/**
 * Link Header 解析（RFC 5988）。
 *
 * 提供 Link header 的解析和构建功能。
 * Link header 用于在 HTTP 响应中传达资源之间的关系，
 * 如分页导航（rel="next"/"prev"）、预加载资源
 * （rel="preload"/"preconnect"）等。
 *
 * 格式：<uri>; rel=type; param=value
 *
 * @see https://www.rfc-editor.org/rfc/rfc5988
 */
package http_lib.message

import std.collection.HashMap
import std.collection.ArrayList

/**
 * 单个 Link 头部的解析结果。
 */
public class LinkHeader {
    /**
     * 链接目标的 URI。
     */
    public var uri: String = ""

    /**
     * 链接参数（rel、type、hreflang、media、title 等）。
     */
    public var params: HashMap<String, String> = HashMap<String, String>()

    public init(uri!: String = "", params!: HashMap<String, String> = HashMap<String, String>()) {
        this.uri = uri
        this.params = params
    }

    /**
     * 获取 rel 参数值。
     */
    public func getRel(): ?String {
        params.get("rel")
    }

    /**
     * 获取 type 参数值。
     */
    public func getType(): ?String {
        params.get("type")
    }

    /**
     * 转换为字符串（反向构建）。
     */
    public func toString(): String {
        let sb = StringBuilder()
       sb.append("<${uri}>")
        for ((key, value) in params) {
            sb.append("; ")
            sb.append(key)
            sb.append("=\"")
            sb.append(value)
            sb.append("\"")
        }
        sb.toString()
    }
}

/**
 * 解析 Link header 字符串。
 * 支持多个链接用逗号分隔。
 */
public func parseLinkHeaders(headerValue: String): ArrayList<LinkHeader> {
    let result = ArrayList<LinkHeader>()
    if (headerValue.isEmpty()) { return result }

    // 解析每个 <uri>; param=value 片段
    var i: Int64 = 0
    let len = headerValue.size

    while (i < len) {
        // 跳过空白和逗号
        while (i < len && (headerValue[i] == b' ' || headerValue[i] == b'\t' || headerValue[i] == b',')) {
            i += 1
        }
        if (i >= len) { break }

        // 查找 <uri>
        if (headerValue[i] != b'<') { break }
        i += 1
        let uriStart = i
        while (i < len && headerValue[i] != b'>') { i += 1 }
        if (i >= len) { break }
        let uri = headerValue[uriStart..i]
        i += 1  // 跳过 >

        let link = LinkHeader(uri: uri)

        // 解析参数
        while (i < len) {
            // 跳过空白和分号
            while (i < len && (headerValue[i] == b' ' || headerValue[i] == b'\t' || headerValue[i] == b';')) {
                i += 1
            }
            if (i >= len || headerValue[i] == b'<' || headerValue[i] == b',') {
                break
            }

            // 读取参数名
            let nameStart = i
            while (i < len && headerValue[i] != b'=' && headerValue[i] != b' ' && headerValue[i] != b'\t' && headerValue[i] != b';' && headerValue[i] != b',') {
                i += 1
            }
            if (nameStart == i) { break }
            let paramName = headerValue[nameStart..i]

            // 跳过 =
            if (i < len && headerValue[i] == b'=') {
                i += 1
            } else {
                // 无值参数
                link.params[paramName] = ""
                continue
            }

            // 读取参数值
            var paramValue = ""
            if (i < len && headerValue[i] == b'"') {
                // 引号值
                i += 1
                let valStart = i
                while (i < len && headerValue[i] != b'"') { i += 1 }
                paramValue = headerValue[valStart..i]
                if (i < len) { i += 1 }
            } else {
                // 无引号值
                let valStart = i
                while (i < len && headerValue[i] != b' ' && headerValue[i] != b'\t' && headerValue[i] != b';' && headerValue[i] != b',') {
                    i += 1
                }
                paramValue = headerValue[valStart..i]
            }
            link.params[paramName] = paramValue
        }

        result.add(link)
    }

    result
}

/**
 * 构建 Link header 值。
 */
   public func buildLinkHeader(uri: String, rel: String, params!: HashMap<String, String> = HashMap<String, String>()): String {
       let link = LinkHeader(uri: uri)
       link.params["rel"] = rel
    for ((key, value) in params) {
       link.params[key] = value
    }
    link.toString()
}
