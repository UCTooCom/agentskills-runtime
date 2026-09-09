package magic.app.controllers.uctoo.mcpopen

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.mcp.{McpOpenService, McpCallResult}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import std.collection.{HashMap, ArrayList}

public class McpOpenController {
    private var service: McpOpenService

    public init(service: McpOpenService) {
        this.service = service
    }

    public func handleCall(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求体不能为空\"}")
                return
            }
            let json = JsonValue.fromStr(body)
            if (json is JsonObject) {
                let obj = json.asObject()
                let mcpAlias = extractString(obj, "mcpAlias")
                let tool = extractString(obj, "tool")
                if (mcpAlias.isEmpty() || tool.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少mcpAlias或tool参数\"}")
                    return
                }
                let arguments = extractArguments(obj)
                let result = service.call(mcpAlias, tool, arguments)
                if (result.isError) {
                    res.status(200).json("{\"errno\":\"50001\",\"errmsg\":\"${result.meta.errorMessage}\",\"data\":\"${result.data}\",\"meta\":{\"tool\":\"${result.meta.tool}\",\"durationMs\":${result.meta.durationMs},\"status\":\"${result.meta.status}\"}}")
                } else {
                    res.status(200).json("{\"errno\":\"0\",\"data\":\"${result.data}\",\"meta\":{\"tool\":\"${result.meta.tool}\",\"durationMs\":${result.meta.durationMs},\"status\":\"${result.meta.status}\"}}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求体不是合法JSON对象\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.toString()}\"}")
        }
    }

    public func handleListTools(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let mcpAliasOpt = req.queryParam("alias")
            if (let Some(mcpAlias) <- mcpAliasOpt) {
                let tools = service.listTools(mcpAlias)
                let sb = StringBuilder()
                sb.append("[")
                var first = true
                for (name in tools) {
                    if (!first) {
                        sb.append(",")
                    }
                    sb.append("\"${name}\"")
                    first = false
                }
                sb.append("]")
                res.status(200).json("{\"errno\":\"0\",\"data\":${sb.toString()}}")
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少alias参数\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.toString()}\"}")
        }
    }

    private func extractString(obj: JsonObject, key: String): String {
        let valOpt = obj.get(key)
        if (let Some(v) <- valOpt) {
            if (v is JsonString) {
                return v.asString().getValue()
            }
        }
        return ""
    }

    private func extractArguments(obj: JsonObject): Array<(String, JsonValue)> {
        let argsOpt = obj.get("arguments")
        if (let Some(argsVal) <- argsOpt) {
            if (argsVal is JsonObject) {
                let argsObj = argsVal.asObject()
                let fields = argsObj.getFields()
                let list = ArrayList<(String, JsonValue)>()
                for ((k, v) in fields) {
                    list.add((k, v))
                }
                return list.toArray()
            }
        }
        return []
    }
}