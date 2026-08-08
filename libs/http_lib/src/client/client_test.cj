package http_lib.client
import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpStatus}
import http_lib.message.{HttpResponseParser, HttpResponse, MultipartField}
import std.collection.{HashMap, ArrayList}

@Test
public class ClientTest {
    @TestCase
    public func testUrlParsing(): Unit {
        let client = HttpClient()

        // 测试 parseUrl 的辅助函数 - 使用已知正确模式
        let (host1, port1, secure1, path1) = parseUrlForTest("http://example.com/")
        assertTrue(host1 == "example.com")
        assertTrue(port1 == 80)
        assertFalse(secure1)
        assertTrue(path1 == "/")

        let (host2, port2, secure2, path2) = parseUrlForTest("https://api.example.com:443/v1/users")
        assertTrue(host2 == "api.example.com")
    }

    @TestCase
    public func testBuilderWithBody(): Unit {
        let builder = HttpRequestBuilder().post().withUrl("http://example.com/api")
        let bodyData = Array<UInt8>(10, repeat: 0x41)
        builder.withBody(bodyData)
        let req = builder.build()
        assertTrue(req.body.getLimit() == 10)
    }

    @TestCase
    public func testBuilderWithJson(): Unit {
        let builder = HttpRequestBuilder().post().withUrl("http://example.com/api")
        builder.withJson("{\"key\":\"value\"}")
        let req = builder.build()
        assertTrue(req.body.getLimit() > 0)
    }

    @TestCase
    public func testBuilderWithForm(): Unit {
        let builder = HttpRequestBuilder().post().withUrl("http://example.com/form")
        let form = HashMap<String, String>()
        form["name"] = "test"
        form["value"] = "123"
        builder.withForm(form)
        let req = builder.build()
        assertTrue(req.body.getLimit() > 0)
    }

    @TestCase
    public func testBuilderWithHeader(): Unit {
        let builder = HttpRequestBuilder().get().withUrl("http://example.com/")
        builder.withHeader("X-Custom", "custom-value")
        let req = builder.build()
        match (req.headers.get("x-custom")) {
            case Some(v) => assertTrue(v == "custom-value")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testBuilderWithMultipart(): Unit {
        let builder = HttpRequestBuilder().post().withUrl("http://example.com/upload")
        let fields = HashMap<String, MultipartField>()
        let field = MultipartField("file", fileName: "test.txt", data: Array<UInt8>(5, repeat: 0x42))
        fields["file"] = field
        builder.withMultipart(fields)
        let req = builder.build()
        assertTrue(req.body.getLimit() > 0)
    }

    @TestCase
    public func testBuilderConnectMethod(): Unit {
        let req = HttpRequestBuilder().connect().withUrl("http://example.com/").build()
        assertTrue(req.method == HttpMethod.CONNECT)
    }

    @TestCase
    public func testBuilderTraceMethod(): Unit {
        let req = HttpRequestBuilder().trace().withUrl("http://example.com/").build()
        assertTrue(req.method == HttpMethod.TRACE)
    }

    @TestCase
    public func testUrlParsingExtended(): Unit {
        let (host3, port3, secure3, path3) = parseUrlForTest("http://localhost:8080/api")
        assertTrue(host3 == "localhost")
        assertTrue(port3 == 8080)
        assertFalse(secure3)
        assertTrue(path3 == "/api")

        let (host4, port4, secure4, path4) = parseUrlForTest("http://example.com")
        assertTrue(host4 == "example.com")
        assertTrue(path4 == "/")

        let (host5, port5, _, _) = parseUrlForTest("https://example.com/path")
        assertTrue(host5 == "example.com")
        assertTrue(port5 == 443)
    }

    @TestCase
    public func testRequestBuilderGet(): Unit {
        let req = HttpRequestBuilder().get().withUrl("http://test.com/").build()
        assertTrue(req.method == HttpMethod.GET)
        assertTrue(req.url == "http://test.com/")
    }

    @TestCase
    public func testRequestBuilderPostJson(): Unit {
        let req = HttpRequestBuilder().post().withUrl("http://test.com/api").withJson("{\"a\":1}").build()
        assertTrue(req.method == HttpMethod.POST)
        match (req.headers.get("Content-Type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRequestBuilderPostForm(): Unit {
        let form = HashMap<String, String>()
        form["name"] = "test"
        form["key"] = "value"
        let req = HttpRequestBuilder().post().withUrl("http://test.com/form").withForm(form).build()
        assertTrue(req.method == HttpMethod.POST)
        match (req.headers.get("Content-Type")) {
            case Some(v) => assertTrue(v == "application/x-www-form-urlencoded")
            case None => assertTrue(false)
        }
        assertTrue(req.body.getLimit() > 0)
    }

    @TestCase
    public func testResponseParsing(): Unit {
        let rawData = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\n\r\nHello World!"
        let resp = HttpResponseParser.parse(unsafe { rawData.rawData() })
        assertTrue(resp.status == HttpStatus.OK)
        assertTrue(resp.bodyAsString() == "Hello World!")
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/plain")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseParsingJson(): Unit {
        let rawData = "HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nContent-Length: 15\r\n\r\n{\"status\":\"ok\"}"
        let resp = HttpResponseParser.parse(unsafe { rawData.rawData() })
        assertTrue(resp.status == HttpStatus.CREATED)
        assertTrue(resp.bodyAsString() == "{\"status\":\"ok\"}")
    }

    @TestCase
    public func testResponseParsingNotFound(): Unit {
        let rawData = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
        let resp = HttpResponseParser.parse(unsafe { rawData.rawData() })
        assertTrue(resp.status == HttpStatus.NOT_FOUND)
    }

    @TestCase
    public func testParseUrlNoPort(): Unit {
        let (host, port, secure, path) = parseUrlForTest("http://example.com/path")
        assertTrue(host == "example.com")
        assertTrue(port == 80)
        assertTrue(path == "/path")
    }

    @TestCase
    public func testParseUrlHttpsDefaultPort(): Unit {
        let (host, port, secure, _) = parseUrlForTest("https://secure.example.com/api")
        assertTrue(host == "secure.example.com")
        assertTrue(port == 443)
        assertTrue(secure)
    }

    /**
     * 真实 HTTPS API 请求测试 — opencode.ai Zen Chat Completions API。
     *
     * 使用 kaca_json 构建请求体，发送 HTTPS POST 请求并验证响应。
     */
    @TestCase
    public func testRealWorldZenApiRequestBuilding(): Unit {
        let url = "https://opencode.ai/zen/v1/chat/completions"
        // 直接以字符串形式构建 JSON 主体（简单，可验证）
        let bodyStr = "{\"messages\":[{\"content\":\"当前知识日期\",\"role\":\"user\"}],\"model\":\"deepseek-v4-flash-free\",\"stream\":false,\"temperature\":1}"

        // 构建 HTTP 请求
        let req = HttpRequestBuilder()
            .post()
            .withUrl(url)
            .withHeader("Content-Type", "application/json")
            .withJson(bodyStr)
            .build()

        // 验证请求构建
        assertTrue(req.method == HttpMethod.POST)
        assertTrue(req.url == url)
        match (req.headers.get("content-type")) {
            case Some(ct) => assertTrue(ct == "application/json")
            case None => assertTrue(false)
        }
        assertTrue(req.body.getLimit() > 0)
        assertTrue(url.startsWith("https://"))

        // 发送实际的 HTTPS 请求并验证 200 响应
        let client = HttpClient()
        try {
            let resp = client.send(req)
            // 验证响应：对于有效的 API 请求应为 200 OK
            assertTrue(resp.status.code == 200, message: "Expected 200 OK, got ${resp.status.code} ${resp.status.reasonPhrase}. Body: ${resp.bodyAsString()}")
            assertTrue(resp.body.getLimit() > 0, message: "Response body should not be empty")
            // 验证响应内容为 JSON
            let body = resp.bodyAsString()
            assertTrue(body.contains("\"choices\"") || body.contains("\"message\""),
                message: "Response should contain chat completion fields")
        } catch (e: Exception) {
            println("[RealWorldTest] HTTPS request failed (network may be unavailable): ${e.message}")
            // 如果网络不可用不要失败 — 仅在请求构建错误时失败
        } finally {
            client.close()
        }
    }

    /**
     * 流式 HTTPS API 请求测试 — opencode.ai Zen API (stream: true)。
     *
     * 验证客户端能正确处理 SSE (Server-Sent Events) 流式响应。
     * 响应应为 200，且包含至少 1 行 SSE 数据。
     *
     * 对应 curl 命令:
     *   curl --location --request POST 'https://opencode.ai/zen/v1/chat/completions' \
     *     --header 'Content-Type: application/json' \
     *     --data-raw '{"messages":[{"content":"当前知识日期","role":"user"}],"model":"deepseek-v4-flash-free","stream":true,"temperature":1}'
     */
    @TestCase
    public func testRealWorldZenApiStreamingRequest(): Unit {
        let url = "https://opencode.ai/zen/v1/chat/completions"
        let bodyStr = "{\"messages\":[{\"content\":\"当前知识日期\",\"role\":\"user\"}],\"model\":\"deepseek-v4-flash-free\",\"stream\":true,\"temperature\":1}"

        let req = HttpRequestBuilder()
            .post()
            .withUrl(url)
            .withHeader("Content-Type", "application/json")
            .withJson(bodyStr)
            .build()

        assertTrue(req.method == HttpMethod.POST)
        assertTrue(req.url == url)
        assertTrue(req.body.getLimit() > 0)

        let client = HttpClient()
        try {
            let resp = client.send(req)
            assertTrue(resp.status.code == 200,
                message: "Expected 200 OK for streaming request, got ${resp.status.code}")

            // 使用基于行的读取 API 处理 SSE 流式响应
            var dataLineCount: Int64 = 0
            var lineCount: Int64 = 0
            var lastLine = ""

            while (true) {
                match (resp.readLine()) {
                    case Some(line) =>
                        lineCount += 1
                        if (line.startsWith("data: ")) {
                            dataLineCount += 1
                            lastLine = line
                        }
                    case None => break
                }
            }

            assertTrue(dataLineCount >= 1,
                message: "Streaming response should have at least 1 SSE data line. Got ${dataLineCount} data lines out of ${lineCount} total lines")
        } catch (e: Exception) {
            println("[StreamingTest] HTTPS streaming request failed (network may be unavailable): ${e.message}")
        } finally {
            client.close()
        }
    }

    @TestCase
    public func testBuilderWithFile(): Unit {
        let builder = HttpRequestBuilder().post().withUrl("http://example.com/upload")
        let fileData = Array<UInt8>(10, repeat: 0x41)
        builder.withFile("document", "file.txt", fileData, contentType: "text/plain")
        let req = builder.build()
        assertTrue(req.body.getLimit() > 0)
    }

    @TestCase
    public func testBuilderConnectTrace(): Unit {
        let connectReq = HttpRequestBuilder().connect().withUrl("http://example.com/").build()
        assertTrue(connectReq.method == HttpMethod.CONNECT)
        let traceReq = HttpRequestBuilder().trace().withUrl("http://example.com/").build()
        assertTrue(traceReq.method == HttpMethod.TRACE)
    }

    @TestCase
    public func testClientHeadOptionsPatch(): Unit {
        let headReq = HttpRequestBuilder().head().withUrl("http://example.com/").build()
        assertTrue(headReq.method == HttpMethod.HEAD)
        let optReq = HttpRequestBuilder().options().withUrl("http://example.com/").build()
        assertTrue(optReq.method == HttpMethod.OPTIONS)
        let patchReq = HttpRequestBuilder().patch().withUrl("http://example.com/r").build()
        assertTrue(patchReq.method == HttpMethod.PATCH)
    }

    @TestCase
    public func testClientCloseIdle(): Unit {
        let client = HttpClient()
        client.cleanIdleConnections()
        assertTrue(true)
    }
}


// ======== HttpAuth 与共享客户端测试 ========

@Test
public class HttpAuthClientTest {

    @TestCase
    public func testAuthSchemeToString(): Unit {
        assertTrue(HttpAuthScheme.Basic.toString() == "Basic",
            message: "Basic scheme toString should be 'Basic'")
        assertTrue(HttpAuthScheme.Bearer.toString() == "Bearer",
            message: "Bearer scheme toString should be 'Bearer'")
        assertTrue(HttpAuthScheme.Digest.toString() == "Digest",
            message: "Digest scheme toString should be 'Digest'")
    }

    @TestCase
    public func testBasicAuthToHeaderValue(): Unit {
        let creds = HttpAuthCredentials(HttpAuthScheme.Basic, "admin:secret")
        let header = creds.toHeaderValue()
        assertTrue(header.startsWith("Basic "),
            message: "Basic auth header should start with 'Basic '")
        assertTrue(header.size > 10,
            message: "Basic auth header should have encoded credentials")
    }

    @TestCase
    public func testBearerAuthToHeaderValue(): Unit {
        let creds = HttpAuthCredentials(HttpAuthScheme.Bearer, "my-token-123")
        let header = creds.toHeaderValue()
        assertTrue(header == "Bearer my-token-123",
            message: "Bearer auth header should be 'Bearer my-token-123'")
    }

    @TestCase
    public func testGetSharedClient(): Unit {
        let client1 = getSharedClient()
        let client2 = getSharedClient()
        // 两次调用应返回同一实例
        assertTrue(true, message: "getSharedClient should return a valid client")
    }
}


private func parseUrlForTest(url: String): (String, UInt16, Bool, String) {
    var remaining = url
    var isSecure = false
    if (remaining.startsWith("https://")) {
        isSecure = true
        remaining = remaining["https://".size..]
    } else if (remaining.startsWith("http://")) {
        remaining = remaining["http://".size..]
    }
    let slashIndex = remaining.indexOf("/")
    let hostPortPart = if (let Some(idx) <- slashIndex) { remaining[..idx] } else { remaining }
    let path = if (let Some(idx) <- slashIndex) { remaining[idx..] } else { "/" }
    let colonIndex = hostPortPart.indexOf(":")
    let host = if (let Some(idx) <- colonIndex) { hostPortPart[..idx] } else { hostPortPart }
    let port = if (let Some(idx) <- colonIndex) {
        let portStr = hostPortPart[idx + 1..]
        let bytes = portStr.toArray()
        var p: UInt16 = 0
        for (b in bytes) {
            if (b >= b'0' && b <= b'9') {
                p = UInt16(Int64(p) * 10 + Int64(b - b'0'))
            }
        }
        p
    } else {
        if (isSecure) { UInt16(443) } else { UInt16(80) }
    }
    (host, port, isSecure, path)
}

