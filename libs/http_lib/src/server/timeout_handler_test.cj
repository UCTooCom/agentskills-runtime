package http_lib.server

import http_lib.core.{assertTrue, assertFalse}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.{HttpMethod, HttpStatus, HttpVersion, HttpHeaders}
import http_lib.buffer.ByteBuffer
import http_lib.router.Handler

/**
 * TimedHandler 和 SizeLimitHandler 的单元测试。
 */
@Test
public class TimeoutHandlerTest {

    @TestCase
    public func testSizeLimitUnderLimit(): Unit {
        let innerHandler: Handler = {req: HttpRequest =>
            HttpResponse(status: HttpStatus.OK)
        }
        let handler = SizeLimitHandler(innerHandler, 100)
        let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
        let bodyBytes = unsafe { "小请求体".rawData() }
        let body = ByteBuffer(capacity: 100)
        body.write(bodyBytes)
        req.body = body
    let resp = handler(req)
    assertTrue(resp.status.code == 200u16, message: "未超过限制应返回 200")
}

@TestCase
public func testSizeLimitOverLimit(): Unit {
    let innerHandler: Handler = {req: HttpRequest =>
        HttpResponse(status: HttpStatus.OK)
    }
    let handler = SizeLimitHandler(innerHandler, 5)
    let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
    let bodyBytes = unsafe { "超过限制的请求体内容".rawData() }
    assertTrue(bodyBytes.size > 5, message: "测试数据应超过限制")
    let body = ByteBuffer(capacity: bodyBytes.size)
    body.write(bodyBytes)
    req.body = body
    let resp = handler(req)
    assertTrue(resp.status.code == 413u16, message: "超过限制应返回 413")
    assertTrue(resp.status == HttpStatus.PAYLOAD_TOO_LARGE, message: "状态码应为 PAYLOAD_TOO_LARGE")
}

@TestCase
public func testSizeLimitExactLimit(): Unit {
    let innerHandler: Handler = {req: HttpRequest =>
        HttpResponse(status: HttpStatus.OK)
    }
    let handler = SizeLimitHandler(innerHandler, 6)
    let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
    let bodyBytes = unsafe { "123456".rawData() }
    assertTrue(bodyBytes.size == 6, message: "测试数据应等于限制值")
    let body = ByteBuffer(capacity: 10)
    body.write(bodyBytes)
    req.body = body
    let resp = handler(req)
    assertTrue(resp.status.code == 200u16, message: "等于限制应返回 200")
}

@TestCase
public func testSizeLimitEmptyBody(): Unit {
    let innerHandler: Handler = {req: HttpRequest =>
        HttpResponse(status: HttpStatus.NO_CONTENT)
    }
    let handler = SizeLimitHandler(innerHandler, 1024)
    let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
    let body = ByteBuffer(capacity: 10)
    req.body = body
    let resp = handler(req)
    assertTrue(resp.status.code == 204u16, message: "空请求体应正常处理")
}

@TestCase
public func testTimedHandlerFastHandler(): Unit {
    // 快速处理器应在超时前完成
    let innerHandler: Handler = {req: HttpRequest =>
        let bodyBytes = unsafe { "快速响应".rawData() }
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        HttpResponse(status: HttpStatus.OK, body: body)
    }
    let handler = TimedHandler(innerHandler, Duration.second * 5)
    let req = HttpRequest(method: HttpMethod.GET, url: "/fast")
    let resp = handler(req)
    assertTrue(resp.status.code == 200u16, message: "快速处理器应返回 200")
}

    @TestCase
    public func testTimedHandlerCustomMessage(): Unit {
        // 测试自定义超时消息
        let innerHandler: Handler = {req: HttpRequest =>
            HttpResponse(status: HttpStatus.OK)
        }
        let handler = TimedHandler(innerHandler, Duration.second * 5, message: "自定义超时消息")
        let req = HttpRequest(method: HttpMethod.GET, url: "/test")
        let resp = handler(req)
        assertTrue(resp.status.code == 200u16, message: "自定义消息处理器应返回 200")
    }
}
