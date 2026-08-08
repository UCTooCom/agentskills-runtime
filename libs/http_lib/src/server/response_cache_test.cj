package http_lib.server

import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class ResponseCacheTest {

    private func makeResponse(body: String): HttpResponse {
        HttpResponse.text(HttpStatus.OK, body)
    }

    @TestCase
    public func testGetAndSet(): Unit {
        let cache = ResponseCache()
        let resp = makeResponse("hello")
        cache.set("/test", resp)

        match (cache.get("/test")) {
            case Some(cached) =>
                assertTrue(cached.bodyAsString() == "hello")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testCacheMiss(): Unit {
        let cache = ResponseCache()
        let result = cache.get("/nonexistent")
        assertTrue(result.isNone())
    }

    @TestCase
    public func testRemove(): Unit {
        let cache = ResponseCache()
        cache.set("/test", makeResponse("data"))
        assertTrue(cache.get("/test").isSome())

        cache.remove("/test")
        assertTrue(cache.get("/test").isNone())
    }

    @TestCase
    public func testClear(): Unit {
        let cache = ResponseCache()
        cache.set("/a", makeResponse("A"))
        cache.set("/b", makeResponse("B"))
        assertTrue(cache.size == 2)

        cache.clear()
        assertTrue(cache.size == 0)
    }

    @TestCase
    public func testSizeLimit(): Unit {
        let cache = ResponseCache(maxSize: 3, ttl: Duration.hour * 1)
        cache.set("/1", makeResponse("1"))
        cache.set("/2", makeResponse("2"))
        cache.set("/3", makeResponse("3"))
        assertTrue(cache.size == 3)

        // 添加第 4 个应淘汰一个
        cache.set("/4", makeResponse("4"))
        assertTrue(cache.size == 3)
    }

    @TestCase
    public func testOverwriteSameKey(): Unit {
        let cache = ResponseCache()
        cache.set("/key", makeResponse("old"))
        cache.set("/key", makeResponse("new"))

        match (cache.get("/key")) {
            case Some(cached) =>
                assertTrue(cached.bodyAsString() == "new")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testMultipleKeys(): Unit {
        let cache = ResponseCache()
        cache.set("/a", makeResponse("A"))
        cache.set("/b", makeResponse("B"))
        cache.set("/c", makeResponse("C"))
        assertTrue(cache.size == 3)
    }

    @TestCase
    public func testDefaultConfig(): Unit {
        let cache = ResponseCache()
        assertTrue(cache.size == 0)
    }

    @TestCase
    public func testTTLExpiry(): Unit {
        // 使用非常短的 TTL（0 秒 = 立即过期）
        let cache = ResponseCache(ttl: Duration.second * 0)
        cache.set("/soon", makeResponse("expires soon"))
        sleep(Duration.millisecond * 10)

        // 现在应已过期
        let result = cache.get("/soon")
        assertTrue(result.isNone())
    }

    @TestCase
    public func testMiddlewareReturnsNextForNonGet(): Unit {
        let cache = ResponseCache()
        let middleware = cache.middleware()

        // 创建返回特定响应的测试处理器
        let handler: (HttpRequest) -> HttpResponse = {req =>
            HttpResponse.text(HttpStatus.OK, "not cached")
        }

        let wrappedHandler = middleware(handler)

        // 创建 POST 请求（不应缓存）
        let req = HttpRequest(method: HttpMethod.POST, url: "/test")
        let resp = wrappedHandler(req)
        assertTrue(resp.bodyAsString() == "not cached")

        // 缓存应为空（POST 响应不缓存）
        assertTrue(cache.get("/test").isNone())
    }

    @TestCase
    public func testMiddlewareCachesGet(): Unit {
        let cache = ResponseCache()
        let middleware = cache.middleware()

        let callCount = ArrayList<Int64>()
        callCount.add(0)
        let handler: (HttpRequest) -> HttpResponse = {req =>
            callCount[0] = callCount[0] + 1
            HttpResponse.text(HttpStatus.OK, "cached response")
        }

        let wrappedHandler = middleware(handler)

        // 第一次调用——应未命中缓存
        let req = HttpRequest(method: HttpMethod.GET, url: "/cached")
        let resp1 = wrappedHandler(req)
        assertTrue(resp1.bodyAsString() == "cached response")
        assertTrue(callCount[0] == 1)

        // 第二次调用——应命中缓存
        let resp2 = wrappedHandler(req)
        assertTrue(resp2.bodyAsString() == "cached response")
        assertTrue(callCount[0] == 1)  // 处理器不会再次被调用

        // 检查 X-Cache 头部
        match (resp2.headers.get("x-cache")) {
            case Some(v) => assertTrue(v == "HIT")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testMiddlewareOnlyCaches200(): Unit {
        let cache = ResponseCache()
        let middleware = cache.middleware()

        let handler: (HttpRequest) -> HttpResponse = {req =>
            HttpResponse.text(HttpStatus.NOT_FOUND, "not found")
        }

        let wrappedHandler = middleware(handler)

        // 第一次调用——404 不应被缓存
        let req = HttpRequest(method: HttpMethod.GET, url: "/notfound")
        let resp1 = wrappedHandler(req)
        assertTrue(resp1.status.code == 404u16)

        // 第二次调用——应再次未命中缓存
        let resp2 = wrappedHandler(req)
        assertTrue(resp2.status.code == 404u16)
    }
}
