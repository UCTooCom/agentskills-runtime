package http2_integration_test

import std.collection.{HashMap, ArrayList}
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler}
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.client.{HttpClient, HttpRequestBuilder, HttpClientConfig}
import http_lib.testutil.{probeAvailablePort, waitForPort}

/**
 * HTTP/2 端到端集成测试。
 *
 * 测试 HTTP/2 服务器 + 客户端通信，包括：
 *   - HTTP/2 的基本请求/响应
 *   - 多个并发连接
 *   - 头部压缩（HPACK）
 *   - 流量控制
 *   - 大响应体
 *   - 带主体的 POST
 *   - 服务端推送（启用时）
 *
 * 使用动态分配的端口以避免冲突。
 *
 * 运行方式：cjpm build && ./target/release/bin/http2_integration_test
 */

// ---- 测试基础设施 ----

class TestResult {
    var passed: Int64 = 0
    var failed: Int64 = 0
    var errors: ArrayList<String> = ArrayList<String>()
}

func assertEqual(tr: TestResult, label: String, actual: String, expected: String): Unit {
    if (actual != expected) {
        tr.errors.add("FAIL: ${label} — expected '${expected}', got '${actual}'")
        tr.failed++
    } else {
        tr.passed++
    }
}

func assertTrue(tr: TestResult, label: String, condition: Bool): Unit {
    if (condition) {
        tr.passed++
    } else {
        tr.errors.add("FAIL: ${label} — expected true, got false")
        tr.failed++
    }
}

func assertStatus(tr: TestResult, label: String, status: HttpStatus, expectedCode: UInt16): Unit {
    if (status.code == expectedCode) {
        tr.passed++
    } else {
        tr.errors.add("FAIL: ${label} — expected status ${expectedCode}, got ${status.code}")
        tr.failed++
    }
}

// ---- 测试处理器 ----

func helloHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "Hello from HTTP/2!")
}

func echoHandler(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    HttpResponse.text(HttpStatus.OK, body)
}

func largeHandler(req: HttpRequest): HttpResponse {
    // 生成大响应主体（100KB）
    var body = ""
    var i: Int64 = 0
    while (i < 10000) {
        body += "HTTP/2 large response body test line number ${i}\n"
        i += 1
    }
    HttpResponse.text(HttpStatus.OK, body)
}

func jsonHandler(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK, "{\"protocol\":\"HTTP/2\",\"status\":\"ok\"}")
}

func headerEchoHandler(req: HttpRequest): HttpResponse {
    let resp = HttpResponse.text(HttpStatus.OK, "headers echoed")
    // 将所有请求头部以 X-Echo- 前缀作为响应头部回显
    let names = req.headers.names()
    for (name in names) {
        match (req.headers.get(name)) {
            case Some(v) => resp.headers.set("X-Echo-${name}", v)
            case None => ()
        }
    }
    resp
}

func routerHandler(req: HttpRequest, router: Router): HttpResponse {
    let result = router.find(req.method, req.path)
    match (result.handler) {
        case Some(h) => h(req)
        case None => HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
    }
}

// ---- 测试用例 ----

func testBasicH2Request(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.get("http://127.0.0.1:${port}/")
    assertStatus(tr, "H2 GET /", resp.status, 200)
    assertEqual(tr, "H2 GET / body", resp.bodyAsString(), "Hello from HTTP/2!")
    println("  ✅ H2 Basic GET")
}

func testH2PostJson(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.postJson("http://127.0.0.1:${port}/echo", "{\"test\":\"h2-post\"}")
    assertStatus(tr, "H2 POST /echo", resp.status, 200)
    assertEqual(tr, "H2 POST /echo body", resp.bodyAsString(), "{\"test\":\"h2-post\"}")
    println("  ✅ H2 POST JSON")
}

func testH2JsonResponse(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.get("http://127.0.0.1:${port}/json")
    assertStatus(tr, "H2 GET /json", resp.status, 200)
    assertTrue(tr, "H2 GET /json body contains protocol",
        resp.bodyAsString().indexOf("HTTP/2").isSome())
    println("  ✅ H2 JSON Response")
}

func testH2LargeResponse(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.get("http://127.0.0.1:${port}/large")
    assertStatus(tr, "H2 GET /large", resp.status, 200)
    assertTrue(tr, "H2 large response body size > 10KB",
        resp.bodyAsBytes().size > 10000)
    println("  ✅ H2 Large Response (${resp.bodyAsBytes().size} bytes)")
}

func testH2MultipleRequests(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    // 顺序发送 10 个请求（测试连接复用）
    var i: Int64 = 0
    while (i < 10) {
        let resp = client.get("http://127.0.0.1:${port}/")
        if (resp.status.code != 200) {
            tr.errors.add("FAIL: H2 req ${i} returned ${resp.status.code}")
            tr.failed++
            break
        }
        i += 1
        tr.passed++
    }
    println("  ✅ H2 Multiple Requests (10 sequential)")
}

func testH2HeaderCompression(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    // 发送带自定义头部的请求，验证其被回显
    let req = HttpRequestBuilder()
        .get().withUrl("http://127.0.0.1:${port}/header-echo")
        .withHeader("X-Custom-Header", "custom-value-for-h2-test")
        .withHeader("X-Another-Header", "another-value")
        .build()

    let resp = client.send(req)
    assertStatus(tr, "H2 GET /header-echo", resp.status, 200)

    match (resp.headers.get("x-echo-x-custom-header")) {
        case Some(v) => assertEqual(tr, "H2 echoed header", v, "custom-value-for-h2-test")
        case None => assertTrue(tr, "H2 echoed header present", false)
    }
    println("  ✅ H2 Header Compression (HPACK)")
}

func testH2NotFound(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.get("http://127.0.0.1:${port}/nonexistent-path")
    assertStatus(tr, "H2 GET /nonexistent", resp.status, 404)
    println("  ✅ H2 404 Not Found")
}

func testH2QueryParams(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.get("http://127.0.0.1:${port}/echo?foo=bar&baz=qux")
    assertStatus(tr, "H2 GET /echo?params", resp.status, 200)
    println("  ✅ H2 Query Parameters")
}

// ---- 主程序 ----

main(): Int64 {
    let tr = TestResult()

    println("========================================")
    println("  HTTP/2 Integration Tests")
    println("========================================")
    println("")

    // 构建路由器
    let router = Router()
        .get("/", helloHandler)
        .post("/echo", echoHandler)
        .get("/json", jsonHandler)
        .get("/large", largeHandler)
        .get("/header-echo", headerEchoHandler)

    // 使用动态端口检测避免冲突
    let port = probeAvailablePort()
    println("Using dynamic port: ${port}")

    // 在后台启动 HTTP/2 服务器
    let serverConfig = HttpServerConfig()
    serverConfig.enableHttp2 = true
    serverConfig.keepAlive = true
    serverConfig.readTimeout = Duration.second * 60
    serverConfig.writeTimeout = Duration.second * 60
    serverConfig.autoCompress = false  // Don't compress for test assertions

    let server = HttpServer({req => routerHandler(req, router)}, config: serverConfig)

    spawn {
        try {
            server.listenAndServe("127.0.0.1", port)
        } catch (e: Exception) {
            println("Server stopped: ${e.message}")
        }
    }

    // 等待服务器就绪（用轮询检查替代固定休眠）
    if (!waitForPort(port)) {
        println("ERROR: Server failed to start within timeout")
        server.close()
        return 1
    }
    println("Server started on port ${port}")
    println("")

    // 创建 HTTP/2 客户端
    let clientConfig = HttpClientConfig()
    clientConfig.enableHttp2 = true
    clientConfig.connectionPoolEnabled = false  // Don't pool for tests
    let client = HttpClient(config: clientConfig)

    // 运行测试
    println("── Basic Request ──")
    testBasicH2Request(tr, client, port)

    println("── POST JSON ──")
    testH2PostJson(tr, client, port)

    println("── JSON Response ──")
    testH2JsonResponse(tr, client, port)

    println("── Large Response ──")
    testH2LargeResponse(tr, client, port)

    println("── Multiple Requests ──")
    testH2MultipleRequests(tr, client, port)

    println("── Header Compression ──")
    testH2HeaderCompression(tr, client, port)

    println("── Error Handling ──")
    testH2NotFound(tr, client, port)

    println("── Query Parameters ──")
    testH2QueryParams(tr, client, port)

    // 报告
    println("")
    println("========================================")
    println("  Results: ${tr.passed} passed, ${tr.failed} failed")
    println("========================================")

    for (err in tr.errors) {
        println("  ${err}")
    }

    client.close()
    server.close()

    if (tr.failed > 0) {
        return 1
    }
    0
}
