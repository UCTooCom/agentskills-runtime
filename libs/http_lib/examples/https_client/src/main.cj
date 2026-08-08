/**
 * HTTPS 客户端（TLS 加密）示例。
 *
 * 演示如何使用 HttpClient 通过 HTTPS 与远程服务器通信：
 *   - TLS 配置与 CA 证书管理
 *   - 证书验证模式
 *   - 请求公共 HTTPS API
 *   - 证书验证错误处理
 *
 * 适用场景：
 *   1）访问生产环境的 HTTPS API
 *   2）连接自签名证书的内部服务
 *   3）需要自定义 CA 证书的企业环境
 */

package sample_https_client

import http_lib.client.{HttpClient, HttpClientConfig}
import http_lib.core.*
import http_lib.message.*
import http_lib.connection.TlsConfig

/**
 * 打印请求响应摘要。
 */
func printResponse(label: String, resp: HttpResponse): Unit {
    println("  [${label}]")
    println("    Status:  ${resp.status}")
    let body = resp.bodyAsString()
    let preview = if (body.size > 120) { body[0..120] + "..." } else { body }
    println("    Body:    ${preview}")
    println("")
}

/**
 * 演示默认 TLS 配置的 HTTPS 请求（使用系统 CA 证书）。
 */
func demoDefaultTls(client: HttpClient): Unit {
    println("━━━ 默认 TLS（系统 CA 证书）━━━")
    println("  尝试访问 https://httpbin.org/get")
    println("  使用系统默认 CA 证书验证服务器身份")
    println("")

    try {
        let resp = client.get("https://httpbin.org/get")
        printResponse("httpbin.org", resp)
    } catch (e: HttpException) {
        println("  ⚠ HTTP 异常: ${e.message}")
        println("  提示：若无法连接，请检查网络或尝试其他 HTTPS 端点")
    } catch (e: Exception) {
        println("  ⚠ 连接异常: ${e.message}")
        println("  提示：https://httpbin.org 可能无法访问，请确认网络连接")
    }
}

/**
 * 演示使用自定义 CA 证书的 HTTPS 请求。
 * 适用于企业内网服务或自签名证书场景。
 */
func demoCustomCa(client: HttpClient, caPath: String): Unit {
    println("━━━ 自定义 CA 证书 ━━━")
    println("  CA 证书路径: ${caPath}")
    println("")

    // 创建带自定义 CA 的 TLS 配置
    let tlsConfig = TlsConfig()
    tlsConfig.caCertPath = caPath
    tlsConfig.verifyPeer = true

    let config = HttpClientConfig()
    config.tlsConfig = tlsConfig
    let customClient = HttpClient(config: config)

    try {
        let resp = customClient.get("https://internal.example.com/api")
        printResponse("内部服务", resp)
    } catch (e: Exception) {
        println("  提示：内部服务示例需要实际的内部 HTTPS 服务")
        println("  可配置自签名 CA 进行测试")
    }
    customClient.close()
}

/**
 * 演示 TLS 证书验证禁用（仅限测试环境）。
 * 注意：生产环境不应禁用证书验证。
 */
func demoInsecureTls(): Unit {
    println("━━━ 不安全的 HTTPS（仅限测试使用）━━━")
    println("  ⚠ 禁用证书验证仅用于开发测试")
    println("")

    let tlsConfig = TlsConfig()
    tlsConfig.verifyPeer = false   // 跳过证书验证
    tlsConfig.verifyHost = false   // 跳过主机名验证

    let config = HttpClientConfig()
    config.tlsConfig = tlsConfig
    let client = HttpClient(config: config)

    try {
        // 尝试连接常见的不安全 HTTPS 端点
        let resp = client.get("https://httpbin.org/get")
        printResponse("httpbin.org (verify disabled)", resp)
    } catch (e: Exception) {
        println("  ⚠ 请求失败: ${e.message}")
    }
    client.close()
}

/**
 * 演示 HTTPS POST 请求与 JSON 交互。
 */
func demoHttpsPost(): Unit {
    println("━━━ HTTPS POST 请求 ━━━")
    println("")

    let client = HttpClient()

    try {
        let resp = client.postJson("https://httpbin.org/post",
            "{\"hello\":\"world\",\"source\":\"http_lib\"}")
        printResponse("POST /post", resp)
    } catch (e: Exception) {
        println("  ⚠ POST 请求失败: ${e.message}")
    }
    client.close()
}

/**
 * 演示带超时和跟随重定向的 HTTPS 请求。
 */
func demoAdvancedOptions(): Unit {
    println("━━━ 高级选项 ━━━")
    println("  自定义超时和重定向策略")
    println("")

    let config = HttpClientConfig()
    config.connectTimeout = Duration.second * 5      // 5 秒连接超时
    config.readTimeout = Duration.second * 15         // 15 秒读取超时
    config.followRedirects = true                     // 跟随重定向
    config.maxRedirects = 3                           // 最多跟随 3 次
    config.tlsConfig = TlsConfig()                    // 默认系统 CA

    let client = HttpClient(config: config)

    try {
        // httpbin.org/redirect/2 会返回两次重定向
        let resp = client.get("https://httpbin.org/redirect/2")
        println("  最终状态: ${resp.status}")
        println("  重定向已自动跟随（共 2 次）")
    } catch (e: Exception) {
        println("  ⚠ 请求失败: ${e.message}")
    }
    client.close()
}

/**
 * 主函数。
 */
main(): Int64 {
    println("╔══════════════════════════════════════════════╗")
    println("║       http_lib HTTPS 客户端示例              ║")
    println("╚══════════════════════════════════════════════╝")
    println("")
    println("本示例展示 HttpClient 的 TLS/HTTPS 功能：")
    println("  1. 默认系统 CA 证书验证")
    println("  2. 自定义 CA 证书配置")
    println("  3. 不安全模式（仅测试用）")
    println("  4. HTTPS POST 请求")
    println("  5. 超时和重定向配置")
    println("")

    // 创建默认客户端
    let defaultClient = HttpClient()

    // 运行演示
    demoDefaultTls(defaultClient)
    demoHttpsPost()
    demoAdvancedOptions()
    demoInsecureTls()

    // 自定义 CA 示例（需要用户指定 CA 路径）
    // demoCustomCa(defaultClient, "/path/to/ca.pem")

    defaultClient.close()

    println("╔══════════════════════════════════════════════╗")
    println("║  示例执行完毕                                  ║")
    println("╚══════════════════════════════════════════════╝")
    0
}
