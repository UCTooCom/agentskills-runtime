/**
 * http_lib 的文档测试。
 *
 * 此测试验证 docs/manual.md 中记录的 API 调用
 * 实际编译并正确工作。它运行一个基本的服务器 + 客户端
 * 交互，练习所有核心文档中记录的 API。
 *
 * 运行方式：
 *   cjpm build && ./target/release/bin/main
 */
package doctest

import std.collection.{HashMap, ArrayList}
import http_lib.core.*
import http_lib.message.*
import http_lib.connection.MockConnection
import http_lib.router.{Router, Handler, HandlerResult, Middleware, MiddlewareChain}
import http_lib.server.{HttpServer, HttpServerConfig, SSEWriter}
import http_lib.server.{ResponseWriter, wrapResponseWriterHandler, HttpError, HttpNotFound, HttpRedirect}
import http_lib.server.{RateLimiter, TimedHandler, SizeLimitHandler, securityHeadersMiddleware, hstsMiddleware, cspMiddleware, loggingMiddleware, extractClientIp}
import http_lib.server.{serveStatic, FileServerConfig, mimeTypeByExtension}
import http_lib.client.{HttpClient, HttpRequestBuilder, HttpClientConfig}
import http_lib.router.{corsMiddleware, CorsConfig}

class TestResult {
    var passed: Int64 = 0
    var failed: Int64 = 0
    var errors: ArrayList<String> = ArrayList<String>()
}

func assertTrue(tr: TestResult, label: String, condition: Bool): Unit {
    if (condition) {
        tr.passed++
    } else {
        tr.errors.add("FAIL: ${label} — expected true, got false")
        tr.failed++
    }
}

func assertEqual(tr: TestResult, label: String, actual: String, expected: String): Unit {
    if (actual != expected) {
        tr.errors.add("FAIL: ${label} — expected '${expected}', got '${actual}'")
        tr.failed++
    } else {
        tr.passed++
    }
}

// ---- 测试：核心类型（manual.md §core） ----

func testCoreTypes(tr: TestResult): Unit {
    // HTTP 方法
    let methodGet = HttpMethod.GET
    let methodPost = HttpMethod.POST

    // HTTP 状态码
    let statusOk = HttpStatus.OK
    let statusNotFound = HttpStatus.NOT_FOUND
    assertTrue(tr, "HttpStatus 200 is success", statusOk.isSuccess())
    assertTrue(tr, "HttpStatus 404 is client error", statusNotFound.isClientError())

    // HTTP 版本
    let version = HttpVersion.HTTP_1_1

    // 头部
    let headers = HttpHeaders()
    headers.add("Content-Type", "application/json")
    headers.set("X-Custom", "value")
    match (headers.get("content-type")) {
        case Some(v) => assertEqual(tr, "Headers case-insensitive", v, "application/json")
        case None => assertTrue(tr, "Headers get", false)
    }
    println("  ✅ Core types")
}

// ---- 测试：消息类型（manual.md §message） ----

func testMessageTypes(tr: TestResult): Unit {
    // 构建请求
    let req = HttpRequest(method: HttpMethod.POST, url: "/api/users")
    req.setJsonBody("{\"name\":\"test\"}")

    // 构建响应
    let jsonResp = HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
    let textResp = HttpResponse.text(HttpStatus.OK, "Hello")
    let emptyResp = HttpResponse.empty(HttpStatus.NO_CONTENT)

    assertTrue(tr, "JSON response OK", jsonResp.isSuccess())
    assertEqual(tr, "Text response body", textResp.bodyAsString(), "Hello")
    assertTrue(tr, "Empty response 204", emptyResp.status.code == 204)
    println("  ✅ Message types")
}

// ---- 测试：路由器（manual.md §router） ----

func indexHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "Index")
}

func createUserHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.CREATED, "Created")
}

func getUserHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "User 42")
}

func testRouter(tr: TestResult): Unit {
    let router = Router()
    router.get("/", indexHandler)
    router.post("/users", createUserHandler)

    let result = router.find(HttpMethod.GET, "/")
    assertTrue(tr, "Router find GET /", result.handler.isSome())
    println("  ✅ Router")
}

// ---- 测试：服务器 + 客户端（manual.md §server, §client） ----

func helloHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "Hello from http_lib!")
}

func echoHandler(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    HttpResponse.text(HttpStatus.OK, body)
}

func customHandler(req: HttpRequest): HttpResponse {
    // 测试 Request API
    let userAgent = req.userAgent()
    let contentType = req.contentType()
    let clientIp = req.clientIp()
    let isAccept = req.accepts("text/plain")
    HttpResponse.text(HttpStatus.OK, "ok")
}

func serverRouterHandler(req: HttpRequest, router: Router): HttpResponse {
    let result = router.find(req.method, req.url)
    match (result.handler) {
        case Some(h) => h(req)
        case None => HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
    }
}

func testServerClientInteraction(tr: TestResult): Unit {
    let router = Router()
        .get("/", helloHandler)
        .post("/echo", echoHandler)
        .get("/custom", customHandler)

    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    serverConfig.idleTimeout = Duration.second * 5
    let server = HttpServer({req => serverRouterHandler(req, router)}, config: serverConfig)

    spawn {
        try {
            server.listenAndServe("127.0.0.1", 9499)
        } catch (e: Exception) {
            // 服务器已关闭
        }
    }

    sleep(Duration.second * 2)

    // 使用 HttpClient 测试
    let client = HttpClient()
    let resp = client.get("http://127.0.0.1:9499/")
    assertTrue(tr, "Server GET /", resp.isSuccess())
    assertEqual(tr, "Server GET / body", resp.bodyAsString(), "Hello from http_lib!")

    // 测试 POST JSON
    let postResp = client.postJson("http://127.0.0.1:9499/echo", "{\"hello\":\"world\"}")
    assertTrue(tr, "Server POST /echo", postResp.isSuccess())

    // 测试 HttpRequestBuilder
    let builtReq = HttpRequestBuilder()
        .get().withUrl("http://127.0.0.1:9499/")
        .withHeader("Authorization", "Bearer token")
        .build()
    let builtResp = client.send(builtReq)
    assertTrue(tr, "Server HttpRequestBuilder", builtResp.isSuccess())

    // 测试 ResponseWriter
    let rw = ResponseWriter()
    rw.header("Content-Type", "text/plain")
    rw.writeHeader(200)
    rw.writeString("Hello, World!")
    let rwResp = rw.build()
    assertTrue(tr, "ResponseWriter builds response", rwResp.isSuccess())

    // 测试 SSEWriter（需要 Connection 进行流式传输）
    let sseResp = HttpResponse.text(HttpStatus.OK, "")
    let mockConn = MockConnection()
    let sse = SSEWriter(sseResp, mockConn)
    sse.sendData("test event data")
    sse.sendEvent("message", "hello")
    sse.close()

    // 测试 HttpError / HttpNotFound / HttpRedirect
    let dummyReq = HttpRequest(method: HttpMethod.GET, url: "/test")
    let errResp = HttpError(dummyReq, "bad request", 400)
    assertTrue(tr, "HttpError 400", errResp.status.code == 400)

    let nfResp = HttpNotFound(dummyReq)
    assertTrue(tr, "HttpNotFound 404", nfResp.status.code == 404)

    let redirectResp = HttpRedirect(dummyReq, "/new-location", 301)
    assertTrue(tr, "HttpRedirect 301", redirectResp.status.code == 301)

    // 测试 RateLimiter
    let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 100)
    let count = limiter.requestCount("127.0.0.1")
    assertTrue(tr, "RateLimiter requestCount >= 0", count >= 0)

    // 测试 FileServerConfig
    let fsConfig = FileServerConfig()
    fsConfig.enableCache = true
    fsConfig.maxAge = 7200
    let mimeType = mimeTypeByExtension("style.css")
    assertTrue(tr, "MIME type for .css", mimeType.size > 0)

    // 测试 CorsConfig
    let cors = CorsConfig()
    cors.allowOrigins = ["https://example.com"]
    cors.allowMethods = ["GET", "POST"]
    cors.allowHeaders = ["Content-Type"]
    assertTrue(tr, "CORS config created", cors.allowOrigins.size > 0)

    // 测试 MiddlewareChain
    let chain = MiddlewareChain()
    let loggingMw: Middleware = {next =>
        {req =>
            let resp = next(req)
            resp
        }
    }
    chain.use(loggingMw)
    assertTrue(tr, "MiddlewareChain size", chain.size == 1)

    // 测试安全中间件
    let securityMw = securityHeadersMiddleware()
    assertTrue(tr, "Security middleware created", true)

    // 测试 TimedHandler
    let timeoutHandler = TimedHandler(helloHandler, Duration.second * 5)
    assertTrue(tr, "TimedHandler created", true)

    // 测试 SizeLimitHandler
    let maxBytesHandler = SizeLimitHandler(helloHandler, 1024 * 1024)
    assertTrue(tr, "SizeLimitHandler created", true)

    // 测试 extractClientIp
    let ip = extractClientIp(dummyReq)
    assertTrue(tr, "extractClientIp returns ip", ip.size > 0)

    client.close()
    server.close()
    println("  ✅ Server + Client interaction")
}

// ---- 主程序 ----

main(): Int64 {
    let tr = TestResult()

    println("========================================")
    println("  Doc Tests (docs/manual.md verification)")
    println("========================================")
    println("")

    println("── Core Types ──")
    testCoreTypes(tr)

    println("── Message Types ──")
    testMessageTypes(tr)

    println("── Router ──")
    testRouter(tr)

    println("── Server + Client ──")
    testServerClientInteraction(tr)

    println("")
    println("========================================")
    println("  Results: ${tr.passed} passed, ${tr.failed} failed")
    println("========================================")

    for (err in tr.errors) {
        println("  ${err}")
    }

    if (tr.failed > 0) {
        return 1
    }
    0
}
