package http_lib.message
/**
 * Cache-Control 头部解析和构建（RFC 7234）。
 * 支持 max-age、no-cache、no-store、must-revalidate 等指令。
 */

import std.collection.{HashMap, ArrayList}
import std.convert.Parsable
import std.unicode.*

/**
 * HTTP Cache-Control 头解析器（RFC 7234）。
 *
 * 从请求和响应头解析 Cache-Control 指令。
 * 支持响应指令（max-age、s-maxage、public、private、
 * no-cache、no-store、must-revalidate、proxy-revalidate 等）和
 * 请求指令（max-age、max-stale、min-fresh、no-cache、no-store 等）。
 * 解析和序列化 Cache-Control 头部（RFC 7234），
 * 包括 max-age、no-cache、no-store、must-revalidate 等指令。
 */

/**
 * 解析后的 Cache-Control 指令键值对。
 * 值以字符串形式存储；使用辅助函数进行类型化访问。
 */
public class CacheControl {
    public var directives: HashMap<String, String>

    public init() {
        this.directives = HashMap<String, String>()
    }

    /**
     * 解析 Cache-Control 头值字符串。
     */
    public static func parse(headerValue: String): CacheControl {
        let cc = CacheControl()
        let runes = headerValue.toRuneArray()
        var pos: Int64 = 0
        while (pos < runes.size) {
            // 跳过前导空白和逗号
            while (pos < runes.size && (runes[pos] == r' ' || runes[pos] == r'\t' || runes[pos] == r',')) { pos += 1 }
            if (pos >= runes.size) { break }

            // 读取指令名称
            var nameStart = pos
            while (pos < runes.size && runes[pos] != r'=' && runes[pos] != r',' && runes[pos] != r' ' && runes[pos] != r'\t') { pos += 1 }
            let name = toLower(String(runes[nameStart..pos]))

            // 检查值
            var value = ""
            while (pos < runes.size && (runes[pos] == r' ' || runes[pos] == r'\t')) { pos += 1 }
            if (pos < runes.size && runes[pos] == r'=') {
                pos += 1
                while (pos < runes.size && (runes[pos] == r' ' || runes[pos] == r'\t')) { pos += 1 }
                if (pos < runes.size && runes[pos] == r'"') {
                    // 带引号的字符串值
                    pos += 1
                    var valueStart = pos
                    while (pos < runes.size && runes[pos] != r'"') { pos += 1 }
                    value = String(runes[valueStart..pos])
                    if (pos < runes.size) { pos += 1 } // 跳过结束引号
                } else {
                    // Token 值
                    var valueStart = pos
                    while (pos < runes.size && runes[pos] != r',' && runes[pos] != r' ' && runes[pos] != r'\t') { pos += 1 }
                    value = String(runes[valueStart..pos])
                }
            }
            cc.directives[name] = value
        }
        cc
    }

    // ---- 类型化访问器 ----

    /**
     * 检查指令是否存在（用于 no-cache、no-store 等布尔指令）。
     */
    public func has(directive: String): Bool {
        directives.contains(toLower(directive))
    }

    /**
     * 以字符串形式获取指令值。
     */
    public func get(directive: String): ?String {
        directives.get(toLower(directive))
    }

    /**
     * 获取 max-age 值（秒）。不存在时返回 None。
     */
    public func maxAge(): ?Int64 {
        match (directives.get("max-age")) {
            case Some(v) =>
                try { Some(parseInt64(v)) } catch (_: Exception) { None }
            case None => None
        }
    }

    /**
     * 获取 s-maxage 值（秒）。不存在时返回 None。
     */
    public func sMaxAge(): ?Int64 {
        match (directives.get("s-maxage")) {
            case Some(v) =>
                try { Some(parseInt64(v)) } catch (_: Exception) { None }
            case None => None
        }
    }

    /**
     * 获取 max-stale 值（秒）。存在但无值时返回 Some(-1)（任意值）。
     */
    public func maxStale(): ?Int64 {
        match (directives.get("max-stale")) {
            case Some(v) =>
                if (v.size == 0) { Some(-1) }
                else { try { Some(parseInt64(v)) } catch (_: Exception) { Some(-1) } }
            case None => None
        }
    }

    /**
     * 获取 min-fresh 值（秒）。
     */
    public func minFresh(): ?Int64 {
        match (directives.get("min-fresh")) {
            case Some(v) =>
                try { Some(parseInt64(v)) } catch (_: Exception) { None }
            case None => None
        }
    }

    /**
     * 获取 private 字段值。存在但无值时返回 Some("")。
     */
    public func privateField(): ?String {
        directives.get("private")
    }

    /**
     * 获取 no-cache 字段值。存在但无值时返回 Some("")。
     */
    public func noCacheField(): ?String {
        directives.get("no-cache")
    }

    // ---- 检查 ----

    public func isPublic(): Bool { has("public") }
    public func isPrivate(): Bool { has("private") }
    public func isNoCache(): Bool { has("no-cache") }
    public func isNoStore(): Bool { has("no-store") }
    public func isNoTransform(): Bool { has("no-transform") }
    public func isMustRevalidate(): Bool { has("must-revalidate") }
    public func isProxyRevalidate(): Bool { has("proxy-revalidate") }
    public func isImmutable(): Bool { has("immutable") }
    public func isStaleWhileRevalidate(): ?Int64 {
        match (directives.get("stale-while-revalidate")) {
            case Some(v) =>
                try { Some(parseInt64(v)) } catch (_: Exception) { None }
            case None => None
        }
    }
    public func isStaleIfError(): ?Int64 {
        match (directives.get("stale-if-error")) {
            case Some(v) =>
                try { Some(parseInt64(v)) } catch (_: Exception) { None }
            case None => None
        }
    }

    /**
     * 从指令构建 Cache-Control 头值字符串。
     */
    public func toString(): String {
        let sb = StringBuilder()
        var first = true
        for ((key, value) in directives) {
            if (first) { first = false } else { sb.append(", ") }
            if (value.size > 0) {
                sb.append("${key}=${value}")
            } else {
                sb.append(key)
            }
        }
        sb.toString()
    }

    /**
     * 便捷方法：基于 Cache-Control 检查响应是否可缓存。
     */
    public func isCacheable(): Bool {
        !isNoStore() && !isPrivate()
    }
}

private func toLower(s: String): String {
    s.toLower()
}

/**
 * 解析正整数字符串为 Int64。使用 std.convert.Int64.parse，溢出时自动抛出异常。
 */
private func parseInt64(s: String): Int64 {
    try {
        Int64.parse(s)
    } catch (_: Exception) {
        0  // 无效数值默认为 0
    }
}
