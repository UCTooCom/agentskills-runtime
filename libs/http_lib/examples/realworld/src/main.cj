package sample_realworld

import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
import http_lib.core.*
import http_lib.message.*
import http_lib.connection.TlsConfig
import kaca_json.JsonValue
import std.collection.{HashMap, ArrayList}

/**
 * 真实 HTTPS API 请求示例
 *
 * 本示例演示如何使用 http_lib 发起 HTTPS POST 请求，
 * 调用 opencode.ai Zen API 进行 AI 对话。
 *
 * 运行方式: cd sample/realworld && cjpm run
 */

func printSeparator(title: String): Unit {
    println("")
    println("═══════════════════════════════════════════════════════")
    println("  ${title}")
    println("═══════════════════════════════════════════════════════")
}

func printResponse(resp: HttpResponse): Unit {
    println("  HTTP 版本 : ${resp.version}")
    println("  状态码    : ${resp.status}")
    for (name in resp.headers.names()) {
        match (resp.headers.get(name)) {
            case Some(v) => println("  ${name}: ${v}")
            case None => ()
        }
    }
    let body = resp.bodyAsString()
    if (body.size > 0) {
        println("  Body (${body.toRuneArray().size} 字符):")
        // 截断过长的响应体输出
        if (body.toRuneArray().size > 500) {
            println(body[..500] + "...")
        } else {
            println(body)
        }
    }
}

/**
 * 使用 kaca_json 构建请求 JSON 并发起 HTTPS POST。
 */
func callChatAPI(client: HttpClient, url: String, model: String, prompt: String): HttpResponse {
    let msgObj = HashMap<String, JsonValue>()
    msgObj["content"] = JsonValue.JsonString(prompt)
    msgObj["role"] = JsonValue.JsonString("user")
    let messages = ArrayList<JsonValue>()
    messages.add(JsonValue.JsonObject(msgObj))
    let bodyObj = HashMap<String, JsonValue>()
    bodyObj["messages"] = JsonValue.JsonArray(messages)
    bodyObj["model"] = JsonValue.JsonString(model)
    bodyObj["stream"] = JsonValue.JsonBool(false)
    bodyObj["temperature"] = JsonValue.JsonNumber(1.0)
    let requestBody = JsonHelper.stringify(JsonValue.JsonObject(bodyObj))

    let req = HttpRequestBuilder()
        .post()
        .withUrl(url)
        .withHeader("Content-Type", "application/json")
        .withJson(requestBody)
        .build()
    client.send(req)
}

/**
 * 调用 opencode.ai Zen Chat Completions API。
 * 使用 deepseek-v4-flash-free 免费模型。
 */
func demoZenChatCompletions(): Unit {
    printSeparator("真实 HTTPS POST — opencode.ai Zen API")

    let url = "https://opencode.ai/zen/v1/chat/completions"
    let model = "deepseek-v4-flash-free"
    let prompt = "当前知识日期"

    println("  请求 URL : ${url}")
    println("  模型     : ${model}")
    println("  问题     : ${prompt}")
    println("  方法     : POST")
    println("  Content-Type: application/json")
    println("")

    let client = HttpClient()
    try {
        let resp = callChatAPI(client, url, model, prompt)
        printResponse(resp)

        // 尝试解析 JSON 响应
        if (resp.isSuccess()) {
            let body = resp.bodyAsString()
            if (body.size > 0) {
                println("")
                println("  ✓ API 调用成功!")
            }
        } else {
            println("")
            println("  ✗ API 返回非成功状态码: ${resp.status}")
        }
    } catch (e: Exception) {
        println("")
        println("  ✗ 请求失败: ${e.message}")
        println("    提示: 请确保网络连接正常，且 JinguiSSL 依赖已正确安装")
    } finally {
        client.close()
    }
}

/**
 * 演示 GET 请求调用公开 API。
 */
func demoPublicGetAPI(client: HttpClient): Unit {
    printSeparator("公开 GET API 请求")

    let url = "https://httpbin.org/get?hello=world"
    println("  请求 URL : ${url}")
    println("  方法     : GET")
    println("")

    try {
        let resp = client.get(url)
        printResponse(resp)
    } catch (e: Exception) {
        println("  ✗ 请求失败: ${e.message}")
    }
}

/**
 * 演示带认证头的请求（Bearer Token）。
 */
func demoBearerAuth(client: HttpClient): Unit {
    printSeparator("带 Bearer Token 认证的请求")

    // 使用带认证凭据的 HttpClient 配置
    let config = HttpClientConfig()
    config.tlsConfig = TlsConfig.default()
    let authClient = HttpClient(config: config)

    let url = "https://httpbin.org/bearer"
    let req = HttpRequestBuilder()
        .get()
        .withUrl(url)
        .withHeader("Authorization", "Bearer test-token-12345")
        .build()

    println("  请求 URL  : ${url}")
    println("  方法      : GET")
    println("  Auth      : Bearer test-token-12345")
    println("")

    try {
        let resp = authClient.send(req)
        printResponse(resp)
    } catch (e: Exception) {
        println("  ✗ 请求失败: ${e.message}")
    } finally {
        authClient.close()
    }
}

main(): Int64 {
    println("╔═══════════════════════════════════════════════════════╗")
    println("║     http_lib — 真实 HTTPS API 请求示例           ║")
    println("║     演示 Client 对公开 API 的 HTTPS 调用能力         ║")
    println("╚═══════════════════════════════════════════════════════╝")
    println("")
    println("  本示例演示:")
    println("  1. HTTPS POST 请求 (opencode.ai Zen API)")
    println("  2. HTTPS GET  请求 (httpbin.org)")
    println("  3. 带 Bearer Token 认证的请求")
    println("")

    // 示例 1: Zen API
    demoZenChatCompletions()

    // 示例 2 & 3: 公开API测试
    let client = HttpClient()
    demoPublicGetAPI(client)
    demoBearerAuth(client)
    client.close()

    println("")
    println("  所有示例执行完毕。")
    0
}
