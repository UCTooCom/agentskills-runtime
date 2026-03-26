package magic.app.middlewares.auth

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.middleware.Middleware
import magic.app.core.response.APIError
import std.collection.ArrayList

public class JWTAuthMiddleware <: Middleware {
    private var secretKey: String
    
    public init(secretKey: String) {
        this.secretKey = secretKey
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        let authHeader = req.header("Authorization")

        match (authHeader) {
            case Some(token) => {
                =>
                if (!token.startsWith("Bearer ")) {
                    res.status(401).json(APIError("40102", "认证令牌格式错误").toJson())
                    return
                }

                let jwtToken = token[7..]
                let payload = verifyToken(jwtToken)

                match (payload) {
                    case Some(p) => {
                        =>
                        req.setLocals("user", p)
                        next()
                    }
                    case None => {
                        =>
                        res.status(401).json(APIError("40103", "认证令牌无效或已过期").toJson())
                    }
                }
            }
            case None => {
                =>
                res.status(401).json(APIError("40101", "未提供认证令牌").toJson())
            }
        }
    }
    
    private func verifyToken(token: String): ?JWTPayload {
        return None<JWTPayload>
    }
}

public class JWTPayload {
    public var userId: String = ""
    public var username: String = ""
    public var roles: ArrayList<String> = ArrayList<String>()
    public var permissions: ArrayList<String> = ArrayList<String>()
    public var exp: Int64 = 0
    
    public init() {}
}
