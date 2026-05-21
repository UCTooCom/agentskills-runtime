package magic.app.core.middleware

import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.services.uctoo.OperateLogService
import std.collection.HashMap
import std.unicode.*
import std.convert.Parsable

/**
 * 操作日志中间件
 * 自动记录所有API请求的操作日志
 *
 * operate 列根据路由路径推断更有意义的操作类型：
 * - 认证类路由：signin->login, signup->register, logout->logout
 * - CRUD 路由：根据路径最后一段推断：add->create, edit->update, del->delete
 * - 分页查询：limit/page -> list
 * - 单条查询：id -> read
 * - 其他情况使用 HTTP 方法
 */
public class OperateLogMiddleware <: Middleware {

    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        let method = getMethodString(req.method)
        let path = req.uri.path
        let ip = getClientIp(req)
        let params = getRequestParams(req)

        let userId = req.getLocals("userId")
        var creator: ?String = None<String>
        if (let Some(u) <- userId) {
            let sOpt = u as String
            if (let Some(s) <- sOpt) {
                creator = Some(s)
            }
        }

        next()

        let operate = inferOperateFromPath(req.method, path)
        OperateLogService.recordApiLog(operate, path, params, ip, method, creator)
    }
    
    private func getClientIp(req: HttpRequest): String {
        let xForwardedFor = req.header("X-Forwarded-For")
        if (let Some(ipStr) <- xForwardedFor) {
            let parts = ipStr.split(",")
            if (parts.size > 0) {
                return parts[0].trimAscii()
            }
            return ipStr
        }
        
        let xRealIp = req.header("X-Real-IP")
        if (let Some(ipStr) <- xRealIp) {
            return ipStr
        }
        
        return "unknown"
    }
    
    private func getRequestParams(req: HttpRequest): String {
        let params = HashMap<String, String>()
        
        let keys = req.queryParams.keys()
        for (key in keys) {
            if (let Some(v) <- req.queryParams.get(key)) {
                params.add(key, v)
            }
        }
        
        if (req.body.size > 0) {
            params.add("_body", req.body)
        }
        
        var result = "{"
        var first = true
        for (key in params.keys()) {
            if (!first) {
                result = result + ","
            }
            first = false
            if (let Some(v) <- params.get(key)) {
                result = result + "\"${key}\":\"${v}\""
            }
        }
        result = result + "}"
        return result
    }
    
    private func getMethodString(method: HttpMethod): String {
        match (method) {
            case HttpMethod.GET => "GET"
            case HttpMethod.POST => "POST"
            case HttpMethod.PUT => "PUT"
            case HttpMethod.DELETE => "DELETE"
            case HttpMethod.PATCH => "PATCH"
            case HttpMethod.HEAD => "HEAD"
            case HttpMethod.OPTIONS => "OPTIONS"
        }
    }
    
    private func inferOperateFromPath(method: HttpMethod, path: String): String {
        let lastSegment = getLastPathSegment(path)
        match (method) {
            case HttpMethod.POST => inferPostOperate(lastSegment, path)
            case HttpMethod.GET => inferGetOperate(lastSegment, path)
            case HttpMethod.PUT => "update"
            case HttpMethod.DELETE => "delete"
            case _ => getMethodString(method).toLower()
        }
    }

    private func getLastPathSegment(path: String): String {
        let parts = path.split("/")
        if (parts.size > 0) {
            return parts[parts.size - 1]
        }
        return ""
    }

    private func inferPostOperate(lastSegment: String, path: String): String {
        match (lastSegment) {
            case "signin" => "login"
            case "signup" => "register"
            case "logout" => "logout"
            case "resetpassword" => "resetPassword"
            case "add" => "create"
            case "edit" => "update"
            case "del" => "delete"
            case "empty-recycle-bin" => "emptyRecycleBin"
            case "export" => "export"
            case "load-db-info" => "loadDbInfo"
            case "get-db-table-list" => "getDbTableList"
            case "generateCrud" => "generateCrud"
            case "generate-all-crud" => "generateAllCrud"
            case "authorize" => "authorize"
            case "revoke" => "revoke"
            case "getUserMenuTree" => "getUserMenuTree"
            case "getAllMenuTree" => "getAllMenuTree"
            case "getLangById" => "getLangById"
            case "format" => "format"
            case _ => if (path.contains("/uctoo/")) {
                lastSegment
            } else {
                getActionFromPath(path)
            }
        }
    }

    private func inferGetOperate(lastSegment: String, path: String): String {
        if (lastSegment == "list" || lastSegment == "all") {
            return "list"
        }
        if (isNumericString(lastSegment)) {
            return "read"
        }
        if (lastSegment.contains(":")) {
            return "read"
        }
        match (lastSegment) {
            case "export" => "export"
            case "me" => "getCurrentUser"
            case "checktoken" => "checkToken"
            case "info" => "info"
            case "list" => "list"
            case _ => if (path.contains("/uctoo/")) {
                lastSegment
            } else {
                "read"
            }
        }
    }

    private func isNumericString(s: String): Bool {
        if (s.isEmpty()) {
            return false
        }
        try {
            let _ = Int64.parse(s)
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private func getActionFromPath(path: String): String {
        let segments = path.split("/")
        var i = segments.size - 1
        while (i >= 0) {
            let segment = segments[i]
            if (segment != "api" && segment != "v1" && segment != "uctoo") {
                return segment
            }
            i = i - 1
        }
        return "unknown"
    }
}
