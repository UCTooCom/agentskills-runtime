/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package f_mvc

/**
 * 枚举的Any类型实际只能处理String ToString InputStream Array<Byte> f_data.ToData这几种类型，
 * 如果是其它类型将会忽略，转而使用HttpStatus的reasonPhrase作为响应体。
 * OK：当前用户登录状态有效且权限正确。
 * SessionNotFound：未找到当前用户的登录状态，可能是用户未登录，也可能是登录状态已过期。
 * InvalidSession：找到了当前用户的登录状态，但是本次访问传递的登录信息无效。
 * SessionError：检查当前用户登录状态时发生错误，可能是服务器内部错误。
 * PrivilegeError：检查当前用户权限时发生错误，可能是服务器内部错误。
 * NoPrivilege：当前用户没有权限访问该资源。
 * 没有HttpStatus参数的构造器表示响应状态码是200
 */
public enum AuthStatus {
    | OK
    | SessionNotFound(HttpStatus, Any)
    | SessionNotFound(Any)
    | InvalidSession(HttpStatus, Any)
    | InvalidSession(Any)
    | SessionError(HttpStatus, Any)
    | SessionError(Any)
    | PrivilegeError(HttpStatus, Any)
    | PrivilegeError(Any)
    | NoPrivilege(HttpStatus, Any)
    | NoPrivilege(Any)

    public prop isOK: Bool {
        get(){
            match(this){
                case OK => true
                case _ => false
            }
        }
    }
}
/**
 * 这个接口的实现类用fountain.bean.macros.@Bean修饰可以实现登录状态与权限检查。
 * 如果应用项目，登录状态和权限都需要检查，务必在一个类中实现，一次调用就都检查了。
 */
public interface AuthHandler {
    /**
     * 检查当前用户登录状态及权限
     * @param ctx 当前请求上下文
     * @param args 处理当前请求的函数参数
     * @return 当前用户登录状态及权限的检查结果
     */
    func check(param: AuthParam): AuthStatus
}
/**
 * ctx: 当前请求上下文
 * path: 当前请求的controller映射路径，不是请求的路径，是controller函数定义的路径
 * args: 当前请求的参数
 * ignoreAuth: 是否忽略登录检查
 * ignorePrivilege: 是否忽略权限检查
 */
public struct AuthParam {
    public AuthParam(
        public let ctx: HttpContext,
        public let path: String,
        public let args: ArrayList<Any>,
        public let ignoreAuth: Bool,
        public let ignorePrivilege: Bool
    ){}
}
/**
 * 登录检查
 */
public interface UserSessionHandler <: AuthHandler {}
/**
 * 权限检查
 */
public interface PrivilegeHandler <: AuthHandler {}

class AuthHandlerProxy <: AuthHandler {
    static let instance = AuthHandlerProxy()
    private init(){}
    private let mutex = Mutex()
    private var noHandlers = true
    private var authHandler = None<AuthHandler>
    private var sessionHandler = None<UserSessionHandler>
    private var privilegeHandler = None<PrivilegeHandler>
    public func check(param: AuthParam): AuthStatus {
        if(noHandlers){
            synchronized(mutex){
                if(noHandlers){
                    for(h in lookupList<AuthHandler>()){
                        if (sessionHandler.isNone() && let sh: UserSessionHandler <- h) {
                            sessionHandler = sh
                        } else if (privilegeHandler.isNone() && let ph: PrivilegeHandler <- h) {
                            privilegeHandler = ph
                        } else if (authHandler.isNone()) {
                            authHandler = h
                        }
                        if(authHandler.isSome()){
                            sessionHandler = None<UserSessionHandler>
                            privilegeHandler = None<PrivilegeHandler>
                            break
                        } else if (sessionHandler.isSome() && privilegeHandler.isSome()) {
                            break
                        }
                    }
                    noHandlers = false
                }
            }
        }
        if (param.ignoreAuth && param.ignorePrivilege) {
            AuthStatus.OK
        } else if (let Some(x) <- authHandler) {
            x.check(param)
        } else if (!param.ignoreAuth && let Some(h) <- sessionHandler && let s <- h.check(param) && s.isOK) {
            s
        } else if (!param.ignorePrivilege && let Some(h) <- privilegeHandler) {
            h.check(param)
        } else {
            AuthStatus.OK
        }
    }
}