/**
 * 摘要认证客户端示例
 *
 * 演示同时支持 MD5 和 SHA-256 的 HTTP 摘要认证（RFC 7616）。
 * 向受保护资源发送请求，解析 WWW-Authenticate 质询，
 * 计算摘要响应，并使用 Authorization 头部重试。
 *
 * 用法：cjpm build && ./target/release/bin/main
 */
package sample_digest_auth_client

import http_lib.client.{HttpClient, HttpRequestBuilder, md5Hex, buildDigestAuthHeader, parseDigestChallenge}
import http_lib.core.{HttpMethod, HttpHeaders, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import std.collection.HashMap

main(): Int64 {
    let client = HttpClient()
    // 模拟的摘要认证流程：
    // 1. 第一次无认证请求 — 服务器返回 401 及 WWW-Authenticate
    // 2. 解析质询并计算响应
    // 3. 使用 Authorization 头部重试

    let url = "https://httpbin.org/digest-auth/auth/user/passwd/MD5"
    let username = "user"
    let password = "passwd"

    println("=== Digest Auth Client ===")
    println("Step 1: Sending initial request to ${url}")

    let req = HttpRequestBuilder().get().withUrl(url).build()
    try {
        let resp = client.send(req)
        if (resp.status.code == 401) {
            match (resp.headers.get("www-authenticate")) {
                case Some(challenge) =>
                    println("Step 2: Received challenge: ${challenge[0..min(challenge.toRuneArray().size, 80)]}...")
                    // 解析质询并构建认证头部
                    let params = parseDigestChallenge(challenge)
                    let realm = match (params.get("realm")) {
                        case Some(r) => r
                        case None => ""
                    }
                    let nonce = match (params.get("nonce")) {
                        case Some(n) => n
                        case None => ""
                    }
                    let authHeader = buildDigestAuthHeader(
                        username, password, realm, nonce,
                        HttpMethod.GET.toString(), "/digest-auth/auth/user/passwd/MD5",
                        qop: Some("auth")
                    )
                    println("Step 3: Retrying with Digest auth header")
                    let authReq = HttpRequestBuilder().get().withUrl(url)
                        .withHeader("Authorization", authHeader).build()
                    let authResp = client.send(authReq)
                    println("Response status: ${authResp.status.code}")
                    if (authResp.status.code == 200) {
                        println("SUCCESS: Digest authentication worked!")
                    }
                case None =>
                    println("No WWW-Authenticate header received")
            }
        } else {
            println("Unexpected response status: ${resp.status.code}")
        }
    } catch (e: Exception) {
        println("Request failed (network may be unavailable): ${e.message}")
    } finally {
        client.close()
    }
    0
}

private func min(a: Int64, b: Int64): Int64 {
    if (a < b) { a } else { b }
}
