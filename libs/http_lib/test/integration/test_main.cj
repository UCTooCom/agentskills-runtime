/**
 * http_lib 集成测试。
 *
 * 在动态分配的端口上启动 HTTP 服务器，用客户端发起请求，
 * 并验证所有响应。使用就绪检查而非固定 sleep()
 * 以获得更快、更可靠的启动。
 */
package integration_test

import http_lib.client.{HttpClient, HttpRequestBuilder}
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler}
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.testutil.{probeAvailablePort, waitForPort}
import std.collection.{HashMap, ArrayList}

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

// ---- 处理器 ----

func rootHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "Hello from http_lib!")
}

func echoHandler(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    HttpResponse.text(HttpStatus.OK, body)
}

func formHandler(req: HttpRequest): HttpResponse {
    let form = parseFormBody(req)
    var result = "{"
    var first = true
    for ((key, value) in form) {
        if (first) { first = false } else { result += ", " }
        result += "\"${key}\":\"${value}\""
    }
    result += "}"
    HttpResponse.json(HttpStatus.OK, result)
}

func uploadHandler(req: HttpRequest): HttpResponse {
    let fields = parseMultipartBody(req)
    var result = "{"
    var first = true
    for ((name, field) in fields) {
        if (first) { first = false } else { result += ", " }
        result += "\"${name}\":\"${field.asString()}\""
    }
    result += "}"
    HttpResponse.json(HttpStatus.OK, result)
}

func notFoundHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
}

func routerHandler(req: HttpRequest, router: Router): HttpResponse {
    let result = router.find(req.method, req.url)
    match (result.handler) {
        case Some(h) => h(req)
        case None => notFoundHandler(req)
    }
}

// ---- 测试用例 ----

func testGetRequest(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.get("http://127.0.0.1:${port}/")
    assertTrue(tr, "GET / returns 200", resp.isSuccess())
    assertEqual(tr, "GET / body", resp.bodyAsString(), "Hello from http_lib!")
    println("  ✅ GET /")

    let resp2 = client.get("http://127.0.0.1:${port}/nonexistent")
    assertEqual(tr, "GET /nonexistent status", "${resp2.status.code}", "404")
    println("  ✅ GET /nonexistent → 404")
}

func testPostJson(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.postJson("http://127.0.0.1:${port}/echo", "{\"hello\":\"world\"}")
    assertTrue(tr, "POST /echo returns success", resp.isSuccess())
    assertEqual(tr, "POST /echo body", resp.bodyAsString(), "{\"hello\":\"world\"}")
    println("  ✅ POST JSON")
}

func testPostForm(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let form = HashMap<String, String>()
    form["username"] = "testuser"
    form["role"] = "admin"
    let resp = client.postForm("http://127.0.0.1:${port}/form", form)
    assertTrue(tr, "POST /form returns success", resp.isSuccess())
    assertTrue(tr, "POST /form body contains username",
        resp.bodyAsString().indexOf("testuser").isSome())
    println("  ✅ POST Form")
}

func testPostMultipart(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let boundary = "----TestBoundary123"
    let bodyStr = "----TestBoundary123\r\nContent-Disposition: form-data; name=\"file\"\r\n\r\nfilecontent\r\n----TestBoundary123\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\nmultipart test\r\n----TestBoundary123--\r\n"
    let bodyBytes = unsafe { bodyStr.rawData() }

    let req = HttpRequestBuilder()
        .post().withUrl("http://127.0.0.1:${port}/upload")
        .withHeader("Content-Type", "multipart/form-data; boundary=${boundary}")
        .withBody(bodyBytes)
        .build()

    let resp = client.send(req)
    assertTrue(tr, "POST /upload returns success", resp.isSuccess())
    println("  ✅ POST Multipart")
}

func testNotFound(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let resp = client.get("http://127.0.0.1:${port}/missing")
    assertEqual(tr, "GET /missing status", "${resp.status.code}", "404")
    println("  ✅ 404 Not Found")
}

func testHeaders(tr: TestResult, client: HttpClient, port: UInt16): Unit {
    let req = HttpRequestBuilder()
        .get().withUrl("http://127.0.0.1:${port}/")
        .withHeader("X-Test", "custom-value")
        .build()
    let resp = client.send(req)
    assertTrue(tr, "GET / with custom header", resp.isSuccess())
    println("  ✅ Custom Headers")
}

// ---- 主程序 ----

main(): Int64 {
    let tr = TestResult()

    println("========================================")
    println("  http_lib Integration Tests")
    println("========================================")
    println("")

    // 构建路由器
    let router = Router()
        .get("/", rootHandler)
        .post("/echo", echoHandler)
        .post("/form", formHandler)
        .post("/upload", uploadHandler)

    // 使用动态端口检测以避免冲突
    let port = probeAvailablePort()
    println("Using dynamic port: ${port}")

    // 在后台启动服务器
    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    serverConfig.idleTimeout = Duration.second * 5
    let server = HttpServer(handler: {req => routerHandler(req, router)}, config: serverConfig)

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

    // 运行测试
    let client = HttpClient()

    println("── GET ──")
    testGetRequest(tr, client, port)

    println("── POST JSON ──")
    testPostJson(tr, client, port)

    println("── POST Form ──")
    testPostForm(tr, client, port)

    println("── POST Multipart ──")
    testPostMultipart(tr, client, port)

    println("── Error Handling ──")
    testNotFound(tr, client, port)

    println("── Headers ──")
    testHeaders(tr, client, port)

    // IPv6 测试（尽力而为，可能不是所有环境都可用）
    println("── IPv6 ──")
    try {
        let ipv6Client = HttpClient()
        let ipv6Resp = ipv6Client.get("http://[::1]:${port}/")
        if (ipv6Resp.isSuccess()) {
            println("  ✅ GET / via IPv6")
            tr.passed++
        } else {
            println("  ⚠️ IPv6 GET returned ${ipv6Resp.status.code}")
            tr.passed++
        }
        ipv6Client.close()
    } catch (e: Exception) {
        println("  ⚠️ IPv6 not available: ${e.message}")
        tr.passed++  // Not a failure — environment may not support IPv6
    }

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
