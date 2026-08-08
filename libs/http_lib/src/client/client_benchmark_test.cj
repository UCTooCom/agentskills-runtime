package http_lib.client

import http_lib.core.{HttpHeaders, HttpMethod}
import http_lib.message.{HttpRequest, HttpResponse, HttpResponseParser}
import http_lib.connection.MockConnection

/**
 * 请求构建、头序列化、传输层、认证基准测试。
 */
@Test public class RequestBuilderBench {
    @Bench
    public func requestMinimalConstruction(): Unit {
        let _ = HttpRequest(method: HttpMethod.GET, url: "/api/v1/users/123")
    }

    @Bench
    public func requestBuilderGet(): Unit {
        let req = HttpRequestBuilder()
            .get()
            .withUrl("https://api.example.com/v1/data")
            .withHeader("Authorization", "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
            .withHeader("Accept", "application/json")
            .build()
    }

    @Bench
    public func requestBuilderPostJson(): Unit {
        let req = HttpRequestBuilder()
            .post()
            .withUrl("https://api.example.com/v1/users")
            .withHeader("Authorization", "Bearer token123")
            .withJson("{\"name\":\"test\",\"email\":\"test@example.com\"}")
            .build()
    }
}

@Test public class ClientHeaderBench {
    @Bench
    public func headersToBytesClientRequest(): Unit {
        let headers = HttpHeaders()
        headers.set("Host", "api.example.com")
        headers.set("User-Agent", "http_lib/0.1")
        headers.set("Accept", "application/json")
        headers.set("Accept-Encoding", "gzip, deflate")
        headers.set("Authorization", "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
        headers.set("Content-Type", "application/json")
        headers.set("Content-Length", "1024")
        let _ = headers.toBytes()
    }

    @Bench
    public func headersSetGetRoundTrip(): Unit {
        let headers = HttpHeaders()
        headers.set("content-type", "application/json")
        headers.set("CONTENT-LENGTH", "2048")
        headers.set("X-Custom-Header", "test-value")
        let _ = headers.get("Content-Type")
        let _ = headers.get("content-length")
        let _ = headers.get("X-CUSTOM-HEADER")
        headers.contains("CONTENT-TYPE")
    }

    @Bench
    public func headersMultiValueSetCookie(): Unit {
        let headers = HttpHeaders()
        headers.add("Set-Cookie", "session=abc123; Path=/")
        headers.add("Set-Cookie", "theme=dark; Path=/")
        headers.add("Set-Cookie", "lang=en; Path=/")
        headers.add("Set-Cookie", "csrf=xyz789; Path=/")
        let _ = headers.getAll("set-cookie")
        let _ = headers.get("Set-Cookie")
    }
}

@Test public class TransportBench {
    @Bench
    public func responseParseSmall(): Unit {
        let rawResp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 17\r\n\r\n{\"status\":\"ok\"}"
        let rawBytes = unsafe { rawResp.rawData() }
        let resp = HttpResponseParser.parse(rawBytes)
        let _ = resp.bodyAsString()
    }

    @Bench
    public func responseParseManyHeaders(): Unit {
        var rawResp = "HTTP/1.1 200 OK\r\n"
        var j: Int64 = 0
        while (j < 20) {
            rawResp = rawResp + "X-Custom-${j}: value-${j}\r\n"
            j += 1
        }
        rawResp = rawResp + "Content-Length: 5\r\n\r\nhello"
        let rawBytes = unsafe { rawResp.rawData() }
        let resp = HttpResponseParser.parse(rawBytes)
        let _ = resp.headers.names()
    }
}

@Test public class AuthBench {
    @Bench
    public func authBasic(): Unit {
        let creds = HttpAuthCredentials.basic("api-user-1234", "s3cret!pass#word")
        let _ = creds.toHeaderValue()
    }

    @Bench
    public func authBearer(): Unit {
        let creds = HttpAuthCredentials.bearer("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
        let _ = creds.toHeaderValue()
    }
}
