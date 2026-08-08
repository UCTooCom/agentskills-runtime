package sample_pipeline_demo

import http_lib.core.{HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.client.{HttpClient, HttpClientConfig, HttpTransport}
import std.collection.ArrayList

/**
 * HTTP/1.1 Pipelining 示例。
 *
 * 演示在单个 HTTP/1.1 持久连接上发送多个请求
 * 而不等待响应，然后按顺序读取响应。
 */
main() {
    // ---- 方式一：使用 HttpClient 手动管道 ----
    println("=== Manual Pipeline via HttpClient ===")
    let config = HttpClientConfig()
    config.connectionPoolEnabled = false
    let client = HttpClient(config: config)

    let p = client.pipeline("https://httpbin.org")
    p.send(HttpRequest(method: HttpMethod.GET, url: "/get"))
    p.send(HttpRequest(method: HttpMethod.GET, url: "/ip"))
    p.send(HttpRequest(method: HttpMethod.GET, url: "/user-agent"))

    let r1 = p.recv()
    println("GET /get → ${r1.status.code}")
    let r2 = p.recv()
    println("GET /ip → ${r2.status.code}")
    let r3 = p.recv()
    println("GET /user-agent → ${r3.status.code}")
    p.close()

    // ---- 方式二：批量管道 ----
    println("\n=== Batch Pipeline via HttpTransport ===")
    let transport = HttpTransport()
    let requests = ArrayList<HttpRequest>()
    requests.add(HttpRequest(method: HttpMethod.GET, url: "https://httpbin.org/get"))
    requests.add(HttpRequest(method: HttpMethod.GET, url: "https://httpbin.org/headers"))
    let responses = transport.pipeline(requests)
    for (resp in responses) {
        println("Response: ${resp.status.code}")
    }

    client.close()
}
