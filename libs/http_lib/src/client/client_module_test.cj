package http_lib.client

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.buffer.ByteBuffer
import std.collection.HashMap

@Test
public class CookieJarTest {

    @TestCase
    public func testCookieJarInit(): Unit {
        let jar = HttpClientCookieJar()
        assertTrue(true)  // 初始化不崩溃
    }

    @TestCase
    public func testExtractCookies(): Unit {
        let jar = HttpClientCookieJar()
        let headers = HttpHeaders()
        headers.add("Set-Cookie", "session=abc123; Path=/")
        headers.add("Set-Cookie", "theme=dark; Path=/")
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers)

        jar.extractCookies("example.com", "/", false, resp)
        let cookieHeader = jar.getCookieHeader("example.com", "/", false)
        assertTrue(cookieHeader.size > 0)
    }

    @TestCase
    public func testExtractNoCookies(): Unit {
        let jar = HttpClientCookieJar()
        let resp = HttpResponse(status: HttpStatus.OK)
        jar.extractCookies("example.com", "/", false, resp)
        let cookieHeader = jar.getCookieHeader("example.com", "/", false)
        assertTrue(cookieHeader == "")
    }

    @TestCase
    public func testApplyCookies(): Unit {
        let jar = HttpClientCookieJar()
        let headers = HttpHeaders()
        headers.add("Set-Cookie", "token=xyz789; Path=/")
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers)
        jar.extractCookies("test.com", "/", false, resp)

        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        jar.applyCookies("test.com", "/", false, req)
        match (req.headers.get("cookie")) {
            case Some(v) => assertTrue(v.contains("token=xyz789"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testClear(): Unit {
        let jar = HttpClientCookieJar()
        let headers = HttpHeaders()
        headers.add("Set-Cookie", "x=y; Path=/")
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers)
        jar.extractCookies("example.com", "/", false, resp)
        jar.clear()
        let cookieHeader = jar.getCookieHeader("example.com", "/", false)
        assertTrue(cookieHeader == "")
    }

    @TestCase
    public func testSecureCookieNotSentOverHttp(): Unit {
        let jar = HttpClientCookieJar()
        let headers = HttpHeaders()
        headers.add("Set-Cookie", "secret=top; Secure; Path=/")
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers)
        jar.extractCookies("secure.com", "/", true, resp)

        // 不应通过 HTTP 发送（不安全）
        let cookieHttp = jar.getCookieHeader("secure.com", "/", false)
        assertTrue(cookieHttp == "")
    }
}

@Test
public class HttpAuthTest {

    @TestCase
    public func testBasicAuthCredentials(): Unit {
        let creds = HttpAuthCredentials.basic("user", "pass")
        let headerValue = creds.toHeaderValue()
        assertTrue(headerValue.startsWith("Basic "))
    }

    @TestCase
    public func testBearerAuthCredentials(): Unit {
        let creds = HttpAuthCredentials.bearer("mytoken123")
        let headerValue = creds.toHeaderValue()
        assertTrue(headerValue == "Bearer mytoken123")
    }

    @TestCase
    public func testAuthSchemeToString(): Unit {
        assertTrue(HttpAuthScheme.Basic.toString() == "Basic")
        assertTrue(HttpAuthScheme.Bearer.toString() == "Bearer")
    }
}

@Test
public class HttpClientNewMethodsTest {

    @TestCase
    public func testHeadMethodBuilder(): Unit {
        let builder = HttpRequestBuilder().head().withUrl("http://example.com/")
        let req = builder.build()
        assertTrue(req.method == HttpMethod.HEAD)
        assertTrue(req.url == "http://example.com/")
    }

    @TestCase
    public func testOptionsMethodBuilder(): Unit {
        let builder = HttpRequestBuilder().options().withUrl("http://example.com/")
        let req = builder.build()
        assertTrue(req.method == HttpMethod.OPTIONS)
    }

    @TestCase
    public func testPatchMethodBuilder(): Unit {
        let builder = HttpRequestBuilder().patch().withUrl("http://example.com/resource")
        let req = builder.build()
        assertTrue(req.method == HttpMethod.PATCH)
    }

    @TestCase
    public func testCloseIdleConnections(): Unit {
        // 验证方法可调用且不会崩溃
        let client = HttpClient()
        client.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testClientClose(): Unit {
        let client = HttpClient()
        client.close()
        assertTrue(true)
    }
}
