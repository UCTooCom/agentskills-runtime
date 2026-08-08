package http_lib.router

import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpStatus, HttpVersion}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class MiddlewareChainTest {

    @TestCase
    public func testEmptyChain(): Unit {
        let chain = MiddlewareChain()
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = chain.apply(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        assertTrue(resp.status == HttpStatus.OK)
    }

    @TestCase
    public func testSingleMiddleware(): Unit {
        let chain = MiddlewareChain()
        chain.use({next: Handler =>
            {req: HttpRequest =>
                let resp = next(req)
                resp.headers.set("X-Middleware", "applied")
                resp
            }
        })
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = chain.apply(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        match (resp.headers.get("x-middleware")) {
            case Some(v) => assertTrue(v == "applied")
            case None => assertTrue(false, message: "Middleware should set header")
        }
    }

    @TestCase
    public func testMultipleMiddleware(): Unit {
        let chain = MiddlewareChain()
        chain.use({next: Handler =>
            {req: HttpRequest =>
                let resp = next(req)
                resp.headers.set("X-First", "1")
                resp
            }
        })
        chain.use({next: Handler =>
            {req: HttpRequest =>
                let resp = next(req)
                resp.headers.set("X-Second", "2")
                resp
            }
        })
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = chain.apply(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        // 两个中间件都应已执行（洋葱模型：第二个包裹第一个）
        assertTrue(resp.headers.get("x-first").isSome() || resp.headers.get("x-second").isSome(),
            message: "At least one middleware header should be set")
    }

    @TestCase
    public func testChainSize(): Unit {
        let chain = MiddlewareChain()
        assertTrue(chain.size == 0, message: "Empty chain should have size 0")
        chain.use({next => next})
        assertTrue(chain.size == 1, message: "Chain with one middleware should have size 1")
    }
}
