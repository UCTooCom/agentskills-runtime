/**
 * LLM 流式客户端示例
 *
 * 演示从 LLM API（如 OpenAI 兼容的流式聊天补全）
 * 消费服务器发送事件（SSE）。
 *
 * 使用 HttpResponse.readLine() 处理每个 SSE 事件行。
 * SSE 格式：
 * data: {"choices":[{"delta":{"content":"Hello"}}]}
 * data: [DONE]
 *
 * 用法：cjpm build && ./target/release/bin/main
 */
package sample_llm_stream_client

import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
import http_lib.core.*
import http_lib.message.{HttpRequest, HttpResponse, JsonHelper}

main() {
    println("LLM Streaming Client Sample")
    println("============================")
    println("")
    println("This sample demonstrates how to consume SSE streaming")
    println("responses from an LLM API using readLine().")
    println("")
    println("To use with a real API, update the URL and API key below.")
    println("")

    // 示例：与 OpenAI 兼容的流式聊天补全
    let apiUrl = "http://localhost:8080/v1/chat/completions"  // Replace with your API
    let apiKey = "sk-your-api-key"  // Replace with your key

    let requestBody = "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":true}"

    let req = HttpRequestBuilder()
        .post().withUrl(apiUrl)
        .withHeader("Authorization", "Bearer ${apiKey}")
        .withHeader("Content-Type", "application/json")
        .withBody(unsafe { requestBody.rawData() })
        .build()

    let config = HttpClientConfig()
    config.readTimeout = Duration.second * 120  // LLM responses can be slow
    config.followRedirects = false

    let client = HttpClient(config: config)

    println("Sending streaming request...")
    println("")

    try {
        let resp = client.send(req)
        if (resp.isSuccess()) {
            println("Status: ${resp.status.code} ${resp.status.reasonPhrase}")
            println("")
            println("--- Response Stream ---")

            // readLine() 处理 SSE 流的每一行。
            // 对于分块响应，主体会增量解码。
            var line = resp.readLine()
            while (line.isSome()) {
        let text = line.getOrThrow()
                if (text.startsWith("data: ")) {
                    let data = text["data: ".size..]
                    if (data == "[DONE]") {
                        println("--- Stream Complete ---")
                        break
                    }
                    // 从 SSE 数据事件解析 JSON delta
                    try {
                        let json = JsonHelper.parse(data)
                        match (JsonHelper.pathFirst(json, "choices.0.delta.content")) {
                            case Some(content) =>
                                match (JsonHelper.getString(content)) {
                                    case Some(text) => print(text)
                                    case None => ()
                                }
                            case None => ()
                        }
                    } catch (_: Exception) {
                        // 非 JSON 数据行
                    }
                }
                line = resp.readLine()
            }
            println("")
        } else {
            println("Error: ${resp.status.code} ${resp.bodyAsString()}")
        }
    } catch (e: Exception) {
        println("Connection failed: ${e.message}")
        println("Make sure your API endpoint is accessible.")
    }

    client.close()
    0
}
