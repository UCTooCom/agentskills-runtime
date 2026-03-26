package magic.app.middlewares.permission

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.middleware.Middleware
import magic.app.core.response.APIError
import magic.app.middlewares.auth.JWTPayload

public enum PermissionLevel {
    | READ
    | WRITE
    | AUTHORIZE
    
    public func toString(): String {
        match (this) {
            case READ => "READ"
            case WRITE => "WRITE"
            case AUTHORIZE => "AUTHORIZE"
        }
    }
}

public class PermissionMiddleware <: Middleware {
    private var tableName: String
    
    public init(tableName: String) {
        this.tableName = tableName
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit) {
        let user = req.getLocals("user")

        if (user is Option<Any>) {
            match (user) {
                case None => {
                    =>
                    res.status(401).json(APIError("40100", "未认证用户").toJson())
                    return
                }
                case Some(u) => {
                    =>
                    match (u) {
                        case p: JWTPayload => {
                            =>
                            if (!hasPermission(p, tableName, PermissionLevel.READ)) {
                                res.status(403).json(APIError("40301", "权限不足").toJson())
                                return
                            }
                            next()
                        }
                        case _ => {
                            =>
                            res.status(401).json(APIError("40104", "用户信息格式错误").toJson())
                        }
                    }
                }
            }
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
    private var tableName: String
    
    public init(tableName: String) {
        this.tableName = tableName
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit) {
        let user = req.getLocals("user")

        if (user is Option<Any>) {
            match (user) {
                case None => {
                    =>
                    res.status(401).json(APIError("40100", "未认证用户").toJson())
                    return
                }
                case Some(u) => {
                    =>
                    match (u) {
                        case p: JWTPayload => {
                            =>
                            let entityId = req.pathParams.get("id")

                            if (let Some(id) <- entityId) {
                                if (!checkRowLevelPermission(p, tableName, id, PermissionLevel.READ)) {
                                    res.status(403).json(APIError("40302", "无权访问此数据").toJson())
                                    return
                                }
                            }

                            next()
                        }
                        case _ => {
                            =>
                            res.status(401).json(APIError("40104", "用户信息格式错误").toJson())
                        }
                    }
                }
            }
        }
    }
    
    private func checkRowLevelPermission(user: JWTPayload, tableName: String, entityId: String, level: PermissionLevel): Bool {
        return true
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
