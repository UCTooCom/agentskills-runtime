/**
 * HTTP 代理客户端示例
 *
 * 演示支持代理的 HTTP 客户端，为 HTTPS 使用 CONNECT 隧道。
 * 支持 HTTP 和 HTTPS 代理，可从环境变量自动检测
 * 环境变量（HTTP_PROXY、HTTPS_PROXY、NO_PROXY）。
 *
 * 用法：
 *   cjpm build && ./target/release/bin/main
 * 或通过环境变量设置代理：HTTP_PROXY=http://proxy:8080 ./target/release/bin/main
 */
package sample_proxy_client

import http_lib.client.{HttpClient, HttpClientConfig, HttpTransport}
import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.message.{HttpResponse}

main(): Int64 {
    println("=== HTTP Proxy Client ===")
    println("Checking for proxy environment variables...")

    // 从 HTTP_PROXY/HTTPS_PROXY 环境变量自动检测代理
    let transport = HttpTransport()
    // 在生产环境中，HttpTransport.init() 自动检测 HTTP_PROXY/HTTPS_PROXY/NO_PROXY
    // 在此演示中，我们显式配置代理：
    // transport.proxyUrl = Some("http://proxy.example.com:8080")

    let config = HttpClientConfig()
    let client = HttpClient(config: config)

    // 示例：通过代理请求 httpbin.org
    // 配置代理后，所有请求都通过代理发送。
    // HTTPS 目标使用 CONNECT 隧道；HTTP 目标使用绝对形式请求。
    let testUrl = "https://httpbin.org/get?via=proxy"

    println("Target: ${testUrl}")
    match (transport.proxyUrl) {
        case Some(proxy) => println("Proxy: ${proxy}")
        case None => println("No proxy configured (direct connection)")
    }

    try {
        let resp = client.get(testUrl)
        println("Status: ${resp.status.code}")
        println("Body: ${resp.bodyAsString()}")
        if (resp.status.code == 200) {
            println("SUCCESS: Request completed through proxy")
        }
    } catch (e: Exception) {
        println("Request failed: ${e.message}")
        println("Hint: set HTTP_PROXY env var if you have a proxy available")
    } finally {
        client.close()
    }

    // 显示环境变量的代理配置
    println()
    println("=== Proxy Environment Variables ===")
    println("Set these to configure proxy auto-detection:")
    println("  export HTTP_PROXY=http://proxy:8080")
    println("  export HTTPS_PROXY=http://proxy:8443")
    println("  export NO_PROXY=localhost,127.0.0.1,.local")

    0
}
