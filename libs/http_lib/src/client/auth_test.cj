package http_lib.client

import std.collection.HashMap
import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class HttpAuthDigestTest {

    @TestCase
    public func testMd5Hex(): Unit {
        let input: Array<UInt8> = [b't', b'e', b's', b't']
        let result = md5Hex(input)
        // MD5("test") 哈希值 = 098f6bcd4621d373cade4e832627b4f6
        assertTrue(result == "098f6bcd4621d373cade4e832627b4f6")
    }

    @TestCase
    public func testMd5HexEmpty(): Unit {
        let result = md5Hex([])
        // MD5("") 哈希值 = d41d8cd98f00b204e9800998ecf8427e
        assertTrue(result == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @TestCase
    public func testSha256Hex(): Unit {
        let input: Array<UInt8> = [b't', b'e', b's', b't']
        let result = sha256Hex(input)
        // SHA-256("test") 哈希值 = 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
        assertTrue(result.size == 64)
        // 仅限十六进制字符
        var valid = true
        for (c in result) {
            let code = UInt32(c)
            if (!((code >= 48 && code <= 57) || (code >= 97 && code <= 102))) {
                valid = false
            }
        }
        assertTrue(valid, message: "SHA-256 hex should only contain hex chars, got: ${result}")
    }

    @TestCase
    public func testSha256HexEmpty(): Unit {
        let result = sha256Hex([])
        // SHA-256("") 哈希值 = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        assertTrue(result.size == 64)
    }

    @TestCase
    public func testParseDigestChallenge(): Unit {
        let challenge = "Digest realm=\"testrealm@host.com\", nonce=\"dcd98b7102dd2f0e8b11d0f600bfb0c093\", qop=\"auth\""
        let params = parseDigestChallenge(challenge)
        match (params.get("realm")) {
            case Some(v) => assertTrue(v == "testrealm@host.com")
            case None => assertTrue(false)
        }
        match (params.get("nonce")) {
            case Some(v) => assertTrue(v.contains("dcd98b7102dd2f0e"))
            case None => assertTrue(false)
        }
        match (params.get("qop")) {
            case Some(v) => assertTrue(v == "auth")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseDigestChallengeEmpty(): Unit {
        let params = parseDigestChallenge("")
        assertTrue(params.size == 0)
    }

    @TestCase
    public func testParseDigestChallengeNotDigest(): Unit {
        let params = parseDigestChallenge("Basic realm=\"test\"")
        assertTrue(params.size == 0)  // 不是 Digest 认证质询
    }

    @TestCase
    public func testComputeDigestResponse(): Unit {
        let response = computeDigestResponse(
            "Mufasa", "CircleOfLife",
            "testrealm@host.com", "dcd98b7102dd2f0e8b11d0f600bfb0c093",
            "GET", "/dir/index.html"
        )
        // 应生成 32 字符的十六进制字符串
        assertTrue(response.size == 32)
        // 仅限十六进制字符
        var valid = true
        for (c in response) {
            let code = UInt32(c)
            if (!((code >= 48 && code <= 57) || (code >= 97 && code <= 102))) {
                valid = false
            }
        }
        assertTrue(valid, message: "Digest response should only contain hex chars, got: ${response}")
    }

    @TestCase
    public func testComputeDigestResponseWithQop(): Unit {
        let response = computeDigestResponse(
            "Mufasa", "CircleOfLife",
            "testrealm@host.com", "dcd98b7102dd2f0e8b11d0f600bfb0c093",
            "GET", "/dir/index.html",
            qop: Some("auth"), nc: Some("00000001"), cnonce: Some("0a4f113b")
        )
        assertTrue(response.size == 32)
    }

    @TestCase
    public func testBuildDigestAuthHeader(): Unit {
        let header = buildDigestAuthHeader(
            "Mufasa", "CircleOfLife",
            "testrealm@host.com", "dcd98b7102dd2f0e8b11d0f600bfb0c093",
            "GET", "/dir/index.html"
        )
        assertTrue(header.startsWith("Digest "))
        assertTrue(header.contains("username=\"Mufasa\""))
        assertTrue(header.contains("realm=\"testrealm@host.com\""))
        assertTrue(header.contains("uri=\"/dir/index.html\""))
    }

    @TestCase
    public func testBuildDigestAuthHeaderWithOptionalParams(): Unit {
        let header = buildDigestAuthHeader(
            "user", "pass",
            "realm", "nonce123",
            "GET", "/",
            opaque: Some("opaque-value"), algorithm: Some("MD5")
        )
        assertTrue(header.contains("opaque=\"opaque-value\""))
        assertTrue(header.contains("algorithm=MD5"))
    }
}

@Test
public class HttpClientBuilderEdgeTest {

    @TestCase
    public func testRequestBuilderGet(): Unit {
        let builder = HttpRequestBuilder()
        let req = builder.get().withUrl("https://example.com/api").build()
        assertTrue(req.method == HttpMethod.GET)
        assertTrue(req.url == "https://example.com/api")
    }

    @TestCase
    public func testRequestBuilderPostWithJson(): Unit {
        let builder = HttpRequestBuilder()
        let req = builder.post().withUrl("/api").withJson("{\"key\":\"value\"}").build()
        assertTrue(req.method == HttpMethod.POST)
        match (req.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRequestBuilderPutWithBody(): Unit {
        let data = Array<UInt8>(10, repeat: 0x01)
        let req = HttpRequestBuilder().put().withUrl("/api/data").withBody(data).build()
        assertTrue(req.method == HttpMethod.PUT)
        assertTrue(req.body.getLimit() == 10)
    }

    @TestCase
    public func testRequestBuilderDelete(): Unit {
        let req = HttpRequestBuilder().delete().withUrl("/api/item/1").build()
        assertTrue(req.method == HttpMethod.DELETE)
    }

    @TestCase
    public func testRequestBuilderAllMethods(): Unit {
        let methods = [
            (HttpMethod.GET, HttpRequestBuilder().get()),
            (HttpMethod.POST, HttpRequestBuilder().post()),
            (HttpMethod.PUT, HttpRequestBuilder().put()),
            (HttpMethod.DELETE, HttpRequestBuilder().delete()),
            (HttpMethod.PATCH, HttpRequestBuilder().patch()),
            (HttpMethod.HEAD, HttpRequestBuilder().head()),
            (HttpMethod.OPTIONS, HttpRequestBuilder().options()),
            (HttpMethod.CONNECT, HttpRequestBuilder().connect()),
            (HttpMethod.TRACE, HttpRequestBuilder().trace()),
        ]
        for ((expected, builder) in methods) {
            let req = builder.withUrl("/test").build()
            assertTrue(req.method == expected)
        }
    }

    @TestCase
    public func testRequestBuilderForm(): Unit {
        let form = HashMap<String, String>()
        form["name"] = "John"
        form["age"] = "30"

        let req = HttpRequestBuilder().post().withUrl("/submit").withForm(form).build()
        assertTrue(req.method == HttpMethod.POST)
        match (req.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/x-www-form-urlencoded")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRedirectionToGetOn303(): Unit {
        // 303 始终切换到 GET
        let original = HttpRequest(method: HttpMethod.POST, url: "/submit")
        let result = resolveRedirectTest(original, HttpStatus.SEE_OTHER, "/new-location")
        assertTrue(result.method == HttpMethod.GET)
    }

    @TestCase
    public func testRedirectionPreserveMethod307(): Unit {
        let original = HttpRequest(method: HttpMethod.POST, url: "/submit")
        let result = resolveRedirectTest(original, HttpStatus.TEMPORARY_REDIRECT, "/new-location")
        assertTrue(result.method == HttpMethod.POST)  // 307 状态码保持请求方法不变
    }
}

/**
 * 重定向解析测试辅助函数（从 HttpClient 提取逻辑）。
 */
private func resolveRedirectTest(original: HttpRequest, status: HttpStatus, location: String): HttpRequest {
    let code = status.code
    if (code == 303) {
        return HttpRequest(method: HttpMethod.GET, url: location)
    }
    if (code == 301 || code == 302) {
        if (original.method == HttpMethod.HEAD) {
            return HttpRequest(method: HttpMethod.HEAD, url: location)
        }
        return HttpRequest(method: HttpMethod.GET, url: location)
    }
    if (code == 307 || code == 308) {
        return HttpRequest(method: original.method, url: location, headers: original.headers, body: original.body)
    }
    HttpRequest(method: HttpMethod.GET, url: location)
}


@Test
public class AuthHeaderTest {
    @TestCase
    public func testBuildBasicAuthHeader(): Unit {
        let header = buildBasicAuthHeader("user", "pass")
        if (!header.startsWith("Basic ")) {
            throw Exception("Expected Basic auth header")
        }
    }

    @TestCase
    public func testParseBasicAuthHeader(): Unit {
        let header = buildBasicAuthHeader("admin", "secret")
        match (parseBasicAuthHeader(header)) {
            case Some((user, pass)) =>
                if (user != "admin" || pass != "secret") {
                    throw Exception("Credential mismatch")
                }
            case None => throw Exception("Expected parsed credentials")
        }
    }
}
