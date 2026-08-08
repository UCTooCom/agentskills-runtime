package http_lib.router

import http_lib.core.{HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * 路由查找性能基准测试。
 * Router 在构造函数中初始化一次，基准测试方法只做查找操作。
 */
@Test public class RouterBench {
    private var router: Router
    private var paramRouter: Router
    private var catchAllRouter: Router
    private var methodRouter: Router

    public init() {
        this.router = Router()
        router.get("/api/v1/resource", {req => HttpResponse.text(HttpStatus.OK, "ok")})

        this.paramRouter = Router()
        paramRouter.get("/api/v1/users/:id/posts/:postId", {req => HttpResponse.text(HttpStatus.OK, "ok")})

        this.catchAllRouter = Router()
        catchAllRouter.get("/static/*path", {req => HttpResponse.text(HttpStatus.OK, "static")})
        catchAllRouter.get("/docs/*path", {req => HttpResponse.text(HttpStatus.OK, "docs")})

        this.methodRouter = Router()
        methodRouter.get("/resource", {req => HttpResponse.empty(HttpStatus.OK)})
        methodRouter.post("/resource", {req => HttpResponse.empty(HttpStatus.OK)})
        methodRouter.options("/resource", {req => HttpResponse.empty(HttpStatus.OK)})
    }

    @Bench
    public func staticLookup(): Unit {
        let _ = router.find(HttpMethod.GET, "/api/v1/resource")
    }

    @Bench
    public func paramLookup(): Unit {
        let _ = paramRouter.find(HttpMethod.GET, "/api/v1/users/123/posts/456")
    }

    @Bench
    public func catchAllLookup(): Unit {
        let _ = catchAllRouter.find(HttpMethod.GET, "/static/css/main.css")
    }

    @Bench
    public func allowedMethods(): Unit {
        let _ = methodRouter.allowedMethodsForPath("/resource")
    }
}
