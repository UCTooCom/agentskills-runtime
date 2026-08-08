package sample_chunked_upload

import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
import http_lib.core.{HttpStatus, HttpHeaders}
import http_lib.message.{HttpRequest, HttpResponse, ChunkedWriter}

/**
 * 分块上传示例。
 *
 * 演示使用分块传输编码发送请求主体，
 * 适用于流式传输大型或未知大小的上传。
 */
main(): Int64 {
    println("=== Chunked Upload Demo ===")
    println("")

    // 使用分块传输编码构建请求
    // 客户端在以下情况自动使用分块编码：
    // - 主体较大且未预设 Content-Length
    // - 或流式传输主体数据时

    let client = HttpClient()

    // 方法 1：使用流式主体的 Builder 模式
    println("Method 1: Streaming chunked upload via builder")
    let req = HttpRequestBuilder()
        .post()
        .withUrl("https://httpbin.org/post")
        .withHeader("Transfer-Encoding", "chunked")
        .withHeader("Content-Type", "application/octet-stream")
        .build()
    // 注意：对于真正的流式传输，使用带流式主体读取器的 HttpTransport

    // 方法 2：预先构建的分块主体
    println("Method 2: Pre-buffered chunked body")
    let msg = unsafe { "Hello, this is a chunked message!".rawData() }
    let chunkedData = ChunkedWriter.encodeChunked(msg)

    let req2 = HttpRequestBuilder()
        .post()
        .withUrl("https://httpbin.org/post")
        .withBody(chunkedData)
        .withHeader("Transfer-Encoding", "chunked")
        .build()

    let resp = client.send(req2)
    println("Response: ${resp.status}")
    println("Body size: ${resp.bodyAsString().size} bytes")

    client.close()
    println("")
    println("Done.")
    0
}
