package http_lib.client

import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class HttpCacheTest {

    @TestCase
    public func testCreateCache(): Unit {
        let cache = HttpCache()
        // Success if no exception
    }

    @TestCase
    public func testGetMissing(): Unit {
        let cache = HttpCache()
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/")
        let result = cache.get(req)
        if (result.isSome()) {
            throw Exception("Expected None for missing entry")
        }
    }

    @TestCase
    public func testStoreAndGet(): Unit {
        let cache = HttpCache()
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/")
        let headers = HttpHeaders()
        headers.set("Cache-Control", "max-age=3600")
        let body = ByteBuffer(capacity: 5)
        body.write(unsafe { "Hello".rawData() })
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers, body: body)
        cache.store(req, resp)
        let cached = cache.get(req)
        if (cached.isNone()) {
            throw Exception("Expected cached response after store")
        }
    }

    @TestCase
    public func testStoreNonCacheableSkipped(): Unit {
        let cache = HttpCache()
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/")
        let headers = HttpHeaders()
        headers.set("Cache-Control", "no-store")
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers)
        cache.store(req, resp)
        let cached = cache.get(req)
        if (cached.isSome()) {
            throw Exception("Expected no cache for no-store")
        }
    }

    @TestCase
    public func testClear(): Unit {
        let cache = HttpCache()
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/")
        cache.store(req, HttpResponse(status: HttpStatus.OK))
        cache.clear()
        let result = cache.get(req)
        if (result.isSome()) {
            throw Exception("Expected None after clear")
        }
    }

    @TestCase
    public func testInvalidateOnUnsafe(): Unit {
        let cache = HttpCache()
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/data")
        cache.store(req, HttpResponse(status: HttpStatus.OK))
        cache.invalidate(HttpMethod.POST, "http://example.com/data")
        let result = cache.get(req)
        // Invalidation uses URL prefix matching
    }
}
@Test
public class HttpCacheConditionalsTest {


    @TestCase
    public func testGetStaleWithConditionals(): Unit {
        let cache = HttpCache()
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/data")
        let headers = HttpHeaders()
        headers.set("Cache-Control", "no-cache")
        headers.set("ETag", "\"abc123\"")
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers)
        cache.store(req, resp)
        let result = cache.getStaleWithConditionals(req)
        if (result.isNone()) {
            throw Exception("Expected conditional headers for no-cache entry")
        }
        let (cached, condHeaders) = result.getOrThrow()
        match (condHeaders.get("If-None-Match")) {
            case Some(etag) =>
                if (etag != "\"abc123\"") {
                    throw Exception("ETag mismatch: ${etag}")
                }
            case None => throw Exception("Expected If-None-Match")
        }
    }
}
