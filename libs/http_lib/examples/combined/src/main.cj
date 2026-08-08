package sample_combined

import http_lib.client.{HttpClient, HttpRequestBuilder}
import http_lib.core.*
import http_lib.message.*
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig}
import std.collection.HashMap

// ---- 服务器 ----
func handleRoot(req: HttpRequest): HttpResponse { HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}") }
func handleEcho(req: HttpRequest): HttpResponse { let b = req.bodyAsString(); let r = HttpResponse.text(HttpStatus.OK, b); r.headers.set("Content-Type", "text/plain"); r }
func handleLogin(req: HttpRequest): HttpResponse {
    let f = parseFormBody(req); let u = match (f.get("username")) { case Some(x) => x case None => "?" }
    HttpResponse.json(HttpStatus.OK, "{\"token\":\"jwt-${u}\"}")
}
func handleUpload(req: HttpRequest): HttpResponse {
    let f = parseMultipartBody(req); var names = ""; var first = true
    for ((n, _) in f) { if (first) { first = false } else { names += "," }; names += "\"${n}\"" }
    HttpResponse.json(HttpStatus.OK, "{\"uploaded\":true,\"fields\":[${names}]}")
}

// ---- 测试 ----
var passed = 0; var failed = 0
func ok(label: String): Unit { passed++; println("  ✅ ${label}") }
func fail(label: String, msg: String): Unit { failed++; println("  ❌ ${label}: ${msg}") }

func testAll(client: HttpClient, base: String): Unit {
    println("── GET ──")
    if (client.get("${base}/").isSuccess()) { ok("GET /") } else { fail("GET /", "failed") }

    println("── POST JSON ──")
    let r1 = client.postJson("${base}/echo", "{\"hello\":\"world\"}")
    if (r1.isSuccess()) { ok("POST JSON /echo") } else { fail("POST JSON", "${r1.status}") }

    println("── POST Form ──")
    let f = HashMap<String, String>(); f["username"] = "test"; f["password"] = "x"
    let r2 = client.postForm("${base}/login", f)
    if (r2.isSuccess()) { ok("POST Form /login") } else { fail("POST Form", "${r2.status}") }

    println("── POST Multipart ──")
    let boundary = "----BOUNDARY"; let bodyStr = "----BOUNDARY\r\nContent-Disposition: form-data; name=\"file\"\r\n\r\nHello\r\n----BOUNDARY--\r\n"
    let req = HttpRequestBuilder().post().withUrl("${base}/upload").withHeader("Content-Type", "multipart/form-data; boundary=${boundary}").withBody(unsafe { bodyStr.rawData() }).build()
    let r3 = client.send(req)
    if (r3.isSuccess()) { ok("POST Multipart /upload") } else { fail("POST Multipart", "${r3.status}") }

    println("── PUT / PATCH / DELETE ──")
    let r4 = client.send(HttpRequestBuilder().put().withUrl("${base}/echo").withJson("{}").build())
    if (r4.isSuccess()) { ok("PUT /echo") } else { fail("PUT", "${r4.status}") }
    let r5 = client.send(HttpRequestBuilder().patch().withUrl("${base}/echo").withJson("{}").build())
    if (r5.isSuccess()) { ok("PATCH /echo") } else { fail("PATCH", "${r5.status}") }
    let r6 = client.send(HttpRequestBuilder().delete().withUrl("${base}/echo").build())
    if (r6.isSuccess()) { ok("DELETE /echo") } else { fail("DELETE", "${r6.status}") }

    println("── HEAD / OPTIONS ──")
    let r7 = client.send(HttpRequestBuilder().head().withUrl("${base}/").build())
    if (r7.isSuccess()) { ok("HEAD /") } else { fail("HEAD", "${r7.status}") }
    let r8 = client.send(HttpRequestBuilder().options().withUrl("${base}/echo").build())
    if (r8.isSuccess() || r8.status.code == 204) { ok("OPTIONS /echo") } else { fail("OPTIONS", "${r8.status}") }

    println("── 404 ──")
    let r9 = client.get("${base}/nonexistent")
    if (r9.status.code == 404) { ok("404 Not Found") } else { fail("404", "got ${r9.status.code}") }
}

main(): Int64 {
    println("═══════════════════════════════════════════")
    println("  http_lib Combined 示例")
    println("  Server + Client 一键自动化测试")
    println("═══════════════════════════════════════════")

    let router = Router()
        .get("/", handleRoot).post("/echo", handleEcho).put("/echo", handleEcho)
        .patch("/echo", handleEcho).delete("/echo", handleEcho)
        .post("/login", handleLogin).post("/upload", handleUpload)

    // 使用 router.handler() 获取已应用中间件的 Handler
    let server = HttpServer(handler: router.handler())
    spawn { try { server.listenAndServe("127.0.0.1", 9090) } catch (e: Exception) { println("服务器错误: ${e.message}") } }
    sleep(Duration.second)

    println("")
    testAll(HttpClient(), "http://127.0.0.1:9090")

    println("")
    println("═══════════════════════════════════════════")
    println("  结果: ${passed} 通过, ${failed} 失败")
    println("═══════════════════════════════════════════")

    server.close()
    0
}
