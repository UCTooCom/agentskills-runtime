package magic.app.middlewares.permission

import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.core.middleware.Middleware
import magic.app.core.response.APIError
import magic.app.middlewares.auth.JWTPayload
import magic.app.core.PermissionLevel
import magic.app.core.PermissionConfig
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class PermissionMiddleware <: Middleware {
    private var tableName: String
    
    public init(tableName: String) {
        this.tableName = tableName
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        let user = req.getLocals("user")

        if (user is Option<Any>) {
            match (user) {
                case None =>
                    res.status(401).json(APIError("40100", "未认证用户").toJson())
                    return
                
                case Some(u) => handleUser(u, req, res, next)
            }
        }
    }
    
    private func handleUser(u: Any, req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        match (u) {
            case p: JWTPayload =>
                if (!hasPermission(p, tableName, PermissionLevel.READ)) {
                    res.status(403).json(APIError("40301", "权限不足").toJson())
                    return
                }
                next()
            
            case _ =>
                res.status(401).json(APIError("40104", "用户信息格式错误").toJson())
        }
    }
    
    private func hasPermission(user: JWTPayload, tableName: String, level: PermissionLevel): Bool {
        let requiredPermission = "${tableName}:${level.toString()}"

        for (permission in user.permissions) {
            if (permission == requiredPermission || permission == "*:*") {
                return true
            }
        }

        return false
    }
}

public class RowLevelPermissionMiddleware <: Middleware {
    private var defaultTableName: String

    public init() {
        this.defaultTableName = ""
    }

    public init(tableName: String) {
        this.defaultTableName = tableName
    }

    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        if (!PermissionConfig.isRowLevelPermissionEnabled()) {
            next()
            return
        }

        let tableName = extractTableName(req)

        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(tableName)) {
            next()
            return
        }

        let user = req.getLocals("user")

        match (user) {
            case None =>
                next()
            case Some(u) =>
                handleRowLevelUser(u, req, res, next, tableName)
        }
    }

    private func extractTableName(req: HttpRequest): String {
        let path = req.uri.path
        let parts = path.split("/")
        var tableName = defaultTableName
        if (parts.size >= 5) {
            if (parts[1] == "api" && parts[2] == "v1" && parts[3] == "uctoo") {
                tableName = parts[4]
            }
        }
        if (tableName.isEmpty()) {
            tableName = defaultTableName
        }
        return tableName
    }

    private func handleRowLevelUser(u: Any, req: HttpRequest, res: HttpResponse, next: () -> Unit, tableName: String): Unit {
        match (u) {
            case p: JWTPayload =>
                let userId = p.userId
                let entityId = req.pathParam("id")

                if (let Some(id) <- entityId) {
                    let requiredLevel = mapMethodToPermissionLevel(httpMethodToString(req.method))
                    if (!checkRowLevelPermission(userId, tableName, id, requiredLevel)) {
                        res.status(403).json(APIError("40302", "无权访问此数据").toJson())
                        return
                    }
                }

                next()

            case _ =>
                next()
        }
    }
    
    private func mapMethodToPermissionLevel(method: String): PermissionLevel {
        match (method) {
            case "GET" => PermissionLevel.READ
            case "POST" => PermissionLevel.WRITE
            case "PUT" => PermissionLevel.WRITE
            case "PATCH" => PermissionLevel.WRITE
            case "DELETE" => PermissionLevel.WRITE
            case _ => PermissionLevel.READ
        }
    }
    
    private func httpMethodToString(method: HttpMethod): String {
        if (method.level() == HttpMethod.GET.level()) {
            return "GET"
        } else if (method.level() == HttpMethod.POST.level()) {
            return "POST"
        } else if (method.level() == HttpMethod.PUT.level()) {
            return "PUT"
        } else if (method.level() == HttpMethod.PATCH.level()) {
            return "PATCH"
        } else if (method.level() == HttpMethod.DELETE.level()) {
            return "DELETE"
        } else {
            return "ANY"
        }
    }
    
    private func checkRowLevelPermission(userId: String, tableName: String, entityId: String, level: PermissionLevel): Bool {
        try {
            let (hasPermission, reason) = PermissionUtils.checkUserHasPermission(userId, tableName, entityId, level)
            if (!hasPermission) {
                LogUtils.info("RowLevelPermissionMiddleware", "Permission denied: user=${userId}, table=${tableName}, entity=${entityId}, level=${level.toString()}, reason=${reason}")
            }
            return hasPermission
        } catch (e: Exception) {
            LogUtils.error("RowLevelPermissionMiddleware", "Permission check error: ${e.message}")
            return false
        }
    }
}

public class PermissionCheck {
    public var resource: String
    public var action: String
    
    public init(resource: String, action: String) {
        this.resource = resource
        this.action = action
    }
    
    public func check(payload: JWTPayload): Bool {
        let requiredPermission = "${resource}:${action}"
        
        for (permission in payload.permissions) {
            if (permission == requiredPermission || permission == "*:*") {
                return true
            }
            if (permission == "${resource}:*") {
                return true
            }
        }
        
        return false
    }
}
