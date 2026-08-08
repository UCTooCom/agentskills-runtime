/**
 * Prefer Header 支持（RFC 7240）。
 *
 * Prefer 请求头允许客户端指示服务器偏好的处理方式。
 * 服务器通过 Preference-Applied 响应头指示已应用的偏好。
 *
 * 常用偏好：
 *   - return=minimal: 最小化响应
 *   - return=representation: 完整响应表示
 *   - respond-async: 异步处理
 *   - wait=<seconds>: 等待指定的秒数
 *   - handling=strict: 严格处理
 *   - handling=lenient: 宽松处理
 *
 * @see https://www.rfc-editor.org/rfc/rfc7240
 */
package http_lib.message

import std.collection.HashMap
import std.collection.ArrayList
import std.unicode.*

/**
 * Prefer 请求头解析结果。
 */
public class PreferParams {
    /**
     * 偏好令牌列表。
     * 键为偏好名，值为参数值（若无值为空字符串）。
     */
    public var tokens: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    /**
     * 检查是否包含指定偏好。
     */
    public func has(token: String): Bool {
        match (tokens.get(token)) {
            case Some(_) => true
            case None => false
        }
    }

    /**
     * 获取偏好值。
     */
    public func get(token: String): ?String {
        tokens.get(token)
    }

    /**
     * 检查是否请求最小化响应。
     */
    public func isReturnMinimal(): Bool {
        has("return-minimal")
    }

    /**
     * 检查是否请求完整响应表示。
     */
    public func isReturnRepresentation(): Bool {
        has("return-representation")
    }

    /**
     * 检查是否请求异步处理。
     */
    public func isRespondAsync(): Bool {
        has("respond-async")
    }

    /**
     * 获取 wait 值（秒数）。
     */
    public func getWait(): ?String {
        get("wait")
    }
}

/**
 * 解析 Prefer 请求头。
 *
 * 格式：Prefer: token1=value1, token2, token3=value3
 */
public func parsePreferHeader(headerValue: String): PreferParams {
    let result = PreferParams()
    if (headerValue.isEmpty()) { return result }

    let parts = headerValue.split(",")
    for (part in parts) {
        let trimmed = part.trimAscii()
        if (trimmed.isEmpty()) { continue }

        let eqIdx = trimmed.indexOf("=")
        match (eqIdx) {
            case Some(idx) =>
                let token = trimmed[0..idx].trimAscii()
                let value = trimmed[idx + 1..].trimAscii()
                // 移除引号（如有）
                let q = "\""
                let val = if (value.startsWith(q) && value.endsWith(q)) {
                    if (value.size >= 2) { value[1..value.size - 1] } else { value }
                } else { value }
                if (!token.isEmpty()) {
                    // 标准化：return=minimal → return-minimal
                    let normalized = if (token == "return" && (val == "minimal" || val == "representation")) {
                        normalizeToken(token + "-" + val)
                    } else { token }
                    result.tokens[normalized] = if (normalized == token) { val } else { "" }
                }
            case None =>
                let token = trimmed.trimAscii()
                if (!token.isEmpty()) {
                    result.tokens[token] = ""
                }
        }
    }

    result
}

/**
 * 构建 Preference-Applied 响应头。
 * 服务器通过此头告知客户端已应用的偏好。
 */
public func buildPreferenceApplied(params: PreferParams): String {
    let applied = ArrayList<String>()
    for ((token, value) in params.tokens) {
        if (value.isEmpty()) {
            applied.add(token)
        } else {
            applied.add("${token}=${value}")
        }
    }
    if (applied.size == 0) { return "" }
    let sb = StringBuilder()
    for (i in 0..applied.size) {
        if (i > 0) { sb.append(", ") }
        sb.append(applied[i])
    }
    sb.toString()
}

/**
 * 构建 Prefer 请求头。
 */
public func buildPreferHeader(params: PreferParams): String {
    buildPreferenceApplied(params)
}

/**
 * 标准化偏好令牌。
 * return=minimal → return-minimal
 */
private func normalizeToken(raw: String): String {
    raw
}
