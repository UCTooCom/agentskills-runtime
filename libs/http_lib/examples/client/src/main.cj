package sample_client

import http_lib.client.{HttpClient, HttpRequestBuilder}
import http_lib.core.*
import http_lib.message.*
import std.collection.HashMap

func printSep(label: String): Unit {
    println("")
    println("═══════════════════════════════════════════")
    println("  ${label}")
    println("═══════════════════════════════════════════")
}

func printResponse(label: String, resp: HttpResponse): Unit {
    println("  Status: ${resp.status}")
    println("  Body[${resp.bodyAsString().toRuneArray().size}]: ${resp.bodyAsString()}")
}

func demoGet(client: HttpClient, base: String): Unit {
    printSep("GET")
    printResponse("GET /", client.get("${base}/"))
    printResponse("GET /users", client.get("${base}/users"))
    printResponse("GET /users/42", client.get("${base}/users/42"))
    printResponse("GET /search?q=hello", client.get("${base}/search?q=hello"))
}

func demoPostJson(client: HttpClient, base: String): Unit {
    printSep("POST — JSON Body")
    printResponse("POST /users", client.postJson("${base}/users", "{\"name\":\"Alice\",\"age\":30}"))

    let req = HttpRequestBuilder().post().withUrl("${base}/posts")
        .withHeader("Authorization", "Bearer token123")
        .withJson("{\"title\":\"Hello\",\"content\":\"World\"}").build()
    printResponse("POST /posts (custom headers)", client.send(req))
}

func demoPostForm(client: HttpClient, base: String): Unit {
    printSep("POST — Form (x-www-form-urlencoded)")
    let loginForm = HashMap<String, String>()
    loginForm["username"] = "admin"; loginForm["password"] = "secret"
    printResponse("POST /login", client.postForm("${base}/login", loginForm))
}

func demoPostMultipart(client: HttpClient, base: String): Unit {
    printSep("POST — Multipart (文件上传)")
    let boundary = "----TestBoundary7MA4YWxk"
    let bodyStr = "----TestBoundary7MA4YWxk\r\nContent-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\nContent-Type: text/plain\r\n\r\nHello from http_lib!\r\n----TestBoundary7MA4YWxk--\r\n"
    let req = HttpRequestBuilder().post().withUrl("${base}/upload")
        .withHeader("Content-Type", "multipart/form-data; boundary=${boundary}")
        .withBody(unsafe { bodyStr.rawData() }).build()
    printResponse("POST /upload", client.send(req))
}

func demoPut(client: HttpClient, base: String): Unit {
    printSep("PUT")
    let req = HttpRequestBuilder().put().withUrl("${base}/users/1").withJson("{\"name\":\"Updated\"}").build()
    printResponse("PUT /users/1", client.send(req))
}

func demoDelete(client: HttpClient, base: String): Unit {
    printSep("DELETE")
    printResponse("DELETE /users/42", client.delete("${base}/users/42"))
}

func demoPatch(client: HttpClient, base: String): Unit {
    printSep("PATCH")
    let req = HttpRequestBuilder().patch().withUrl("${base}/users/1").withJson("{\"email\":\"new@test.com\"}").build()
    printResponse("PATCH /users/1", client.send(req))
}

func demoHead(client: HttpClient, base: String): Unit {
    printSep("HEAD")
    let req = HttpRequestBuilder().head().withUrl("${base}/").build()
    let resp = client.send(req)
    println("  Status: ${resp.status}")
    for (name in resp.headers.names()) {
        match (resp.headers.get(name)) { case Some(v) => println("  ${name}: ${v}") case None => () }
    }
}

func demoOptions(client: HttpClient, base: String): Unit {
    printSep("OPTIONS")
    let req = HttpRequestBuilder().options().withUrl("${base}/users").build()
    printResponse("OPTIONS /users", client.send(req))
}

main(): Int64 {
    let base = "http://127.0.0.1:8080"
    println("============================================")
    println("  http_lib HTTP Client 示例")
    println("  目标: ${base}")
    println("  运行前请确保服务器已启动")
    println("  快速体验: cd sample/combined && cjpm run")
    println("============================================")
    let client = HttpClient()
    demoGet(client, base)
    demoPostJson(client, base)
    demoPostForm(client, base)
    demoPostMultipart(client, base)
    demoPut(client, base)
    demoDelete(client, base)
    demoPatch(client, base)
    demoHead(client, base)
    demoOptions(client, base)
    client.close()
    println("")
    println("  示例执行完毕")
    0
}
