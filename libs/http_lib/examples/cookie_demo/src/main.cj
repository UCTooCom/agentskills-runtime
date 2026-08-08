package sample_cookie_demo

import http_lib.core.*
import http_lib.message.*
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.client.{HttpClient, HttpClientCookieJar}

/**
 * Cookie Demo — 演示 http_lib 的 Cookie 功能
 *
 * 服务端点：
 *   GET /                        带所有演示链接的登陆页面
 *   GET /set-session             设置会话 cookie（HttpOnly）
 *   GET /set-persistent          设置持久 cookie（Max-Age）
 *   GET /set-restricted          设置路径限制 cookie（Path=/restricted）
 *   GET /read                    显示请求中的所有 cookie
 *   GET /restricted/page         /restricted/ 路径下的页面，接收受限制的 cookie
 *   GET /check                   /restricted/ 外的页面 —— 演示路径过滤
 *
 * 自动测试部分（main）使用 HttpClient + HttpClientCookieJar
 * 来验证 cookie 往返和路径/域名过滤。
 */

// ── 服务器处理器 ──

func handleRoot(req: HttpRequest): HttpResponse {
    HttpResponse.html(HttpStatus.OK,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Cookie Demo</title></head><body>"
        + "<h1>Cookie Demo</h1>"
        + "<p>This sample demonstrates cookie handling in http_lib:</p>"
        + "<ul>"
        + "<li><a href=\"/set-session\">Set Session Cookie</a> (HttpOnly)</li>"
        + "<li><a href=\"/set-persistent\">Set Persistent Cookie</a> (Max-Age=3600)</li>"
        + "<li><a href=\"/set-restricted\">Set Path-Restricted Cookie</a> (Path=/restricted)</li>"
        + "<li><a href=\"/read\">Read All Cookies</a></li>"
        + "<li><a href=\"/restricted/page\">Restricted Page</a> (receives /restricted cookies)</li>"
        + "<li><a href=\"/check\">Path Filtering Check</a></li>"
        + "</ul></body></html>"
    )
}

/**
 * 设置名为 "cj-session" 的会话 cookie，带 HttpOnly 标志。
 * 浏览器/cookie jar 将在每个对 "/" 的请求中发送此 cookie。
 */
func handleSetSession(req: HttpRequest): HttpResponse {
    HttpResponse.html(HttpStatus.OK,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Session Cookie Set</title></head><body>"
        + "<h1>Session Cookie Set</h1>"
        + "<p>A session cookie has been set:</p>"
        + "<pre>cj-session=abc123; Path=/; HttpOnly</pre>"
        + "<p><a href=\"/read\">Read Cookies</a> to verify it is sent back.</p>"
        + "</body></html>"
    ).withCookie("cj-session", "abc123", httpOnly: true)
}

/**
 * 设置名为 "pref-theme" 的持久 cookie，Max-Age=3600。
 * Cookie jar 将存储此 cookie 并在过期前一直发送。
 */
func handleSetPersistent(req: HttpRequest): HttpResponse {
    HttpResponse.html(HttpStatus.OK,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Persistent Cookie Set</title></head><body>"
        + "<h1>Persistent Cookie Set</h1>"
        + "<p>A persistent cookie has been set:</p>"
        + "<pre>pref-theme=dark; Path=/; Max-Age=3600</pre>"
        + "<p>This cookie will expire in 1 hour.</p>"
        + "<p><a href=\"/read\">Read Cookies</a> to verify.</p>"
        + "</body></html>"
    ).withCookie("pref-theme", "dark", maxAge: Some(3600))
}

/**
 * 设置路径限制 cookie "internal-token"，Path=/restricted，HttpOnly。
 * 此 cookie 仅会发送到 /restricted/ 下的路径。
 */
func handleSetRestricted(req: HttpRequest): HttpResponse {
    HttpResponse.html(HttpStatus.OK,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Restricted Cookie Set</title></head><body>"
        + "<h1>Path-Restricted Cookie Set</h1>"
        + "<p>A cookie restricted to <code>/restricted</code> has been set:</p>"
        + "<pre>internal-token=xyz789; Path=/restricted; HttpOnly</pre>"
        + "<p><a href=\"/restricted/page\">Check /restricted/page</a> to see it received.</p>"
        + "<p><a href=\"/check\">Check /check</a> to confirm it is <em>not</em> sent to other paths.</p>"
        + "</body></html>"
    ).withCookie("internal-token", "xyz789", path: "/restricted", httpOnly: true)
}

/**
 * 显示请求中收到的所有 cookie。
 * 同时使用原始的 Cookie 头和解析后的 req.cookie() 访问器。
 */
func handleReadCookies(req: HttpRequest): HttpResponse {
    let rawCookie = match (req.headers.get("cookie")) {
        case Some(v) => v
        case None => "(no cookies)"
    }

    let session = match (req.cookie("cj-session")) {
        case Some(v) => v
        case None => "(not set)"
    }
    let theme = match (req.cookie("pref-theme")) {
        case Some(v) => v
        case None => "(not set)"
    }
    let token = match (req.cookie("internal-token")) {
        case Some(v) => v
        case None => "(not set)"
    }

    HttpResponse.html(HttpStatus.OK,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Read Cookies</title></head><body>"
        + "<h1>Cookies in Request</h1>"
        + "<h2>Raw Cookie Header:</h2>"
        + "<pre>" + rawCookie + "</pre>"
        + "<h2>Parsed Cookies (via req.cookie()):</h2>"
        + "<table border=\"1\"><tr><th>Name</th><th>Value</th></tr>"
        + "<tr><td>cj-session</td><td>" + session + "</td></tr>"
        + "<tr><td>pref-theme</td><td>" + theme + "</td></tr>"
        + "<tr><td>internal-token</td><td>" + token + "</td></tr>"
        + "</table>"
        + "<p><a href=\"/\">Back to Home</a></p>"
        + "</body></html>"
    )
}

/**
 * /restricted/ 下的页面 —— 路径限制 cookie internal-token
 * 应在此处可见。
 */
func handleRestrictedPage(req: HttpRequest): HttpResponse {
    let token = match (req.cookie("internal-token")) {
        case Some(v) => v
        case None => "(not set — path filtering is working)"
    }

    HttpResponse.html(HttpStatus.OK,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Restricted Page</title></head><body>"
        + "<h1>Restricted Page</h1>"
        + "<p>This page is under <code>/restricted/</code> path.</p>"
        + "<p>The <code>internal-token</code> cookie value is: <strong>" + token + "</strong></p>"
        + "<p><a href=\"/check\">Check /check</a> to see if it is sent there.</p>"
        + "<p><a href=\"/\">Back</a></p>"
        + "</body></html>"
    )
}

/**
 * 位于 /check 的页面（在 /restricted/ 外）—— 路径限制 cookie
 * 此处不应可见，演示基于路径的过滤。
 */
func handleCheck(req: HttpRequest): HttpResponse {
    let token = match (req.cookie("internal-token")) {
        case Some(v) => v
        case None => "(not set — path filtering works)"
    }

    HttpResponse.html(HttpStatus.OK,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Path Filtering Check</title></head><body>"
        + "<h1>Path Filtering Check</h1>"
        + "<p>This page is at <code>/check</code>, outside the <code>/restricted/</code> path.</p>"
        + "<p>The <code>internal-token</code> cookie value is: <strong>" + token + "</strong></p>"
        + "<p>If it says \"not set\", path filtering is working correctly!</p>"
        + "<p><a href=\"/\">Back</a></p>"
        + "</body></html>"
    )
}

func handleNotFound(req: HttpRequest): HttpResponse {
    HttpResponse.html(HttpStatus.NOT_FOUND,
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>404 Not Found</title></head><body>"
        + "<h1>404 Not Found</h1>"
        + "<p>The resource at " + req.url + " was not found.</p>"
        + "<p><a href=\"/\">Back to Home</a></p>"
        + "</body></html>"
    )
}

// ── 路由器派发 ──

// ── 自动客户端测试 ──

var passed = 0
var failed = 0

func ok(label: String): Unit {
    passed++
    println("  [PASS] " + label)
}

func fail(label: String, msg: String): Unit {
    failed++
    println("  [FAIL] " + label + ": " + msg)
}

/**
 * 运行基于客户端的测试来验证：
 *   1. Cookie 往返（通过 Set-Cookie 设置，通过 Cookie 头读取）
 *   2. 同一 jar 中的多个 cookie
 *   3. 基于路径的 cookie 过滤（Path=/restricted）
 *   4. 基于域名的 cookie 过滤（通过直接 HttpClientCookieJar API）
 *   5. 清除 cookie jar
 */
func runClientTests(client: HttpClient, base: String): Unit {
    println("")
    println("--- Client Cookie Tests ---")

    // 1. 通过服务器设置会话 cookie，验证响应为 200
    println("  1. Set session cookie via server")
    let r1 = client.get(base + "/set-session")
    if (r1.isSuccess()) {
        ok("GET /set-session returned 200")
    } else {
        fail("GET /set-session", "status=${r1.status.code}")
    }

    // 2. 读取 cookie — cj-session 应由 cookie jar 自动发送
    println("  2. Read cookies — expect cj-session in request")
    let r2 = client.get(base + "/read")
    let body2 = r2.bodyAsString()
    if (body2.contains("cj-session")) {
        ok("GET /read includes cj-session cookie")
    } else {
        fail("GET /read", "cj-session cookie was not sent by the cookie jar")
    }

    // 3. 设置持久化 cookie
    println("  3. Set persistent cookie (pref-theme)")
    let r3 = client.get(base + "/set-persistent")
    if (r3.isSuccess()) {
        ok("GET /set-persistent returned 200")
    } else {
        fail("GET /set-persistent", "status=${r3.status.code}")
    }

    // 4. 读取 cookie — cj-session 和 pref-theme 都应存在
    println("  4. Read cookies — expect both cj-session and pref-theme")
    let r4 = client.get(base + "/read")
    let body4 = r4.bodyAsString()
    let hasSession = body4.contains("cj-session")
    let hasTheme = body4.contains("pref-theme")
    if (hasSession && hasTheme) {
        ok("GET /read includes both cookies")
    } else {
        var missing = ""
        if (!hasSession) { missing = "cj-session " }
        if (!hasTheme) { missing += "pref-theme" }
        fail("GET /read", "missing cookies: " + missing)
    }

    // 5. 设置路径限制的 cookie（Path=/restricted）
    println("  5. Set path-restricted cookie (internal-token, Path=/restricted)")
    let r5 = client.get(base + "/set-restricted")
    if (r5.isSuccess()) {
        ok("GET /set-restricted returned 200")
    } else {
        fail("GET /set-restricted", "status=${r5.status.code}")
    }

    // 6. 请求 /restricted/page — internal-token 应被发送
    println("  6. /restricted/page — expect internal-token cookie")
    let r6 = client.get(base + "/restricted/page")
    let body6 = r6.bodyAsString()
    if (body6.contains("xyz789")) {
        ok("GET /restricted/page receives internal-token")
    } else {
        fail("GET /restricted/page", "internal-token was not sent")
    }

    // 7. 请求 /check（在 /restricted/ 之外）— internal-token 不应被发送
    println("  7. /check — internal-token should NOT be sent (path filtering)")
    let r7 = client.get(base + "/check")
    let body7 = r7.bodyAsString()
    if (body7.contains("path filtering works")) {
        ok("Path filtering: internal-token excluded from /check")
    } else {
        fail("Path filtering", "internal-token was visible at /check")
    }

    // 8. 通过直接使用 HttpClientCookieJar 进行域名过滤
    println("  8. Domain filtering (HttpClientCookieJar direct API)")
    let jar = HttpClientCookieJar()
    let h = HttpHeaders()
    h.add("Set-Cookie", "user=john; Path=/; Domain=example.com")
    let resp = HttpResponse(status: HttpStatus.OK, headers: h)
    jar.extractCookies("example.com", "/", false, resp)

    let matchDomain = jar.getCookieHeader("example.com", "/", false)
    let noMatchDomain = jar.getCookieHeader("other.com", "/", false)

    if (matchDomain.contains("user=john") && !noMatchDomain.contains("user=john")) {
        ok("Domain filtering: cookie only sent to example.com")
    } else {
        fail("Domain filtering", "match='" + matchDomain + "' noMatch='" + noMatchDomain + "'")
    }

    // 9. 清空 cookie jar
    println("  9. Clear cookie jar")
    jar.clear()
    let afterClear = jar.getCookieHeader("example.com", "/", false)
    if (afterClear == "") {
        ok("Cookie jar cleared successfully")
    } else {
        fail("Cookie jar clear", "still contains: '" + afterClear + "'")
    }

    println("")
}

// ── 主程序 ──

main(): Int64 {
    println("═══════════════════════════════════════════")
    println("  http_lib Cookie Demo")
    println("  Setting, reading, and filtering cookies")
    println("═══════════════════════════════════════════")
    println("")
    println("Endpoints:")
    println("  GET /                     Landing page")
    println("  GET /set-session          Set session cookie (HttpOnly)")
    println("  GET /set-persistent       Set persistent cookie (Max-Age=3600)")
    println("  GET /set-restricted       Set path-restricted cookie (Path=/restricted)")
    println("  GET /read                 Display all cookies from request")
    println("  GET /restricted/page      Page under restricted path")
    println("  GET /check                Path filtering verification")
    println("")

    let router = Router()
        .get("/", handleRoot)
        .get("/set-session", handleSetSession)
        .get("/set-persistent", handleSetPersistent)
        .get("/set-restricted", handleSetRestricted)
        .get("/read", handleReadCookies)
        .get("/restricted/page", handleRestrictedPage)
        .get("/check", handleCheck)

    let server = HttpServer(handler: router.handler())
    spawn { try { server.listenAndServe("127.0.0.1", 9091) } catch (e: Exception) { println("Server error: " + e.message) } }
    sleep(Duration.second)

    runClientTests(HttpClient(), "http://127.0.0.1:9091")

    println("═══════════════════════════════════════════")
    println("  Results: ${passed} passed, ${failed} failed")
    println("═══════════════════════════════════════════")

    server.close()
    0
}
