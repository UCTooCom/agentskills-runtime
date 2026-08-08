package http_lib.message
/**
 * JSON 请求/响应便捷辅助函数。
 * 简化从 HttpRequest/HttpResponse 中提取 JSON 结构体的操作。
 */

import kaca_json.{JSON, JsonValue}
import std.collection.{ArrayList, HashMap}

/**
 * JSON 辅助工具（封装 kaca_json，用于 HTTP 请求/响应处理）。
 *
 * 用法：
 * // 从请求中解析 JSON 主体
 *   let json = JsonHelper.parse(request.bodyAsString())
 *   let name = json.get("user.name")
 *
 * // 构建 JSON 响应
 *   let obj = JsonHelper.object()
 *   obj.set("status", "ok")
 *   obj.set("code", 200)
 *   let resp = HttpResponse.json(HttpStatus.OK, obj.stringify())
 */
public class JsonHelper {

    /**
     * 将 JSON 字符串解析为 JsonValue。
     */
    public static func parse(json: String): JsonValue {
        JSON.parse(json.toArray())
    }

    /**
     * 将 JSON 字符串解析为 JsonValue。 returning None on parse failure.
     */
    public static func parseOrNull(json: String): ?JsonValue {
        JSON.parseOrNull(json)
    }

    /**
     * 将 JsonValue 序列化为字符串。
     */
    public static func stringify(value: JsonValue): String {
        JSON.stringify(value)
    }

    /**
     * 将 JsonValue 序列化为字符串。with pretty-print indentation.
     */
    public static func stringify(value: JsonValue, indent: Int64): String {
        JSON.stringify(value, indent)
    }

    /**
     * 按 JSON 路径获取值（如 "$.user.name"）。
     */
    public static func path(value: JsonValue, path: String): ArrayList<JsonValue> {
        JSON.path(value, path)
    }

    /**
     * 获取匹配 JSON 路径的第一个值。
     */
    public static func pathFirst(value: JsonValue, path: String): ?JsonValue {
        JSON.pathFirst(value, path)
    }

    /**
     * 创建 JSON null 值。
     */
    public static func nullValue(): JsonValue {
        JsonNull
    }

    /**
     * 创建 JSON 布尔值。
     */
    public static func bool(value: Bool): JsonValue {
        JsonBool(value)
    }

    /**
     * 创建 JSON 数字值。
     */
    public static func number(value: Float64): JsonValue {
        JsonNumber(value)
    }

    /**
     * 创建 JSON 字符串值。
     */
    public static func string(value: String): JsonValue {
        JsonString(value)
    }

    /**
     * 创建空的 JSON 数组。
     */
    public static func array(): ArrayList<JsonValue> {
        ArrayList<JsonValue>()
    }

    /**
     * 从值创建 JSON 数组。
     */
    public static func arrayOf(values: ArrayList<JsonValue>): JsonValue {
        JsonArray(values)
    }

    /**
     * 创建空的 JSON 对象。
     */
    public static func object(): HashMap<String, JsonValue> {
        HashMap<String, JsonValue>()
    }

    /**
     * 从映射创建 JSON 对象。
     */
    public static func objectOf(map: HashMap<String, JsonValue>): JsonValue {
        JsonObject(map)
    }

    // ---- 便捷获取器 ----

    /**
     * 从 JsonValue 安全提取字符串值。
     */
    public static func getString(value: JsonValue): ?String {
        match (value) {
            case JsonString(s) => Some(s)
            case _ => None
        }
    }

    /**
     * 从 JsonValue 安全提取数字值。
     */
    public static func getNumber(value: JsonValue): ?Float64 {
        match (value) {
            case JsonNumber(n) => Some(n)
            case _ => None
        }
    }

    /**
     * 从 JsonValue 安全提取布尔值。
     */
    public static func getBool(value: JsonValue): ?Bool {
        match (value) {
            case JsonBool(b) => Some(b)
            case _ => None
        }
    }
}
