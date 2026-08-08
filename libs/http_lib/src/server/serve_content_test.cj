package http_lib.server

import http_lib.core.{assertTrue, assertFalse, assertEqual, HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class ServeContentTest {

    // ============================================================
    // serveContent 测试
    // ============================================================

    @TestCase
    public func testServeContentBasic200(): Unit {
        let content = "Hello World"
        let data = unsafe { content.rawData() }
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = serveContent(data, req, "text/plain; charset=utf-8")

        assertTrue(resp.status == HttpStatus.OK,
            message: "serveContent should return 200 OK for basic GET")
        let body = resp.bodyAsString()
        assertTrue(body == "Hello World",
            message: "Response body should match input data")
    }

    @TestCase
    public func testServeContentContentType(): Unit {
        let data: Array<UInt8> = [72, 101, 108, 108, 111]
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = serveContent(data, req, "application/json")

        match (resp.headers.get("content-type")) {
            case Some(v) =>
                assertTrue(v == "application/json",
                    message: "Content-Type header should match the supplied contentType")
            case None =>
                assertTrue(false, message: "Content-Type header should be present")
        }
    }

    @TestCase
    public func testServeContentContentLength(): Unit {
        let data = unsafe { "Hello World".rawData() }  // 11 字节
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = serveContent(data, req, "text/plain")

        match (resp.headers.get("content-length")) {
            case Some(v) =>
                assertTrue(v == "11",
                    message: "Content-Length should equal the number of bytes in data")
            case None =>
                assertTrue(false, message: "Content-Length header should be present")
        }
    }

    @TestCase
    public func testServeContentRangeRequest(): Unit {
        let content = "Hello World"
        let data = unsafe { content.rawData() }
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("Range", "bytes=0-4")
        let resp = serveContent(data, req, "text/plain")

        assertTrue(resp.status == HttpStatus.PARTIAL_CONTENT,
            message: "Valid range request should return 206 Partial Content")

        // Content-Range 头部
        match (resp.headers.get("content-range")) {
            case Some(v) =>
                assertTrue(v == "bytes 0-4/11",
                    message: "Content-Range should reflect the served range and total size")
            case None =>
                assertTrue(false, message: "Content-Range header should be present on 206")
        }

        // Content-Length 头部 应与部分主体匹配
        match (resp.headers.get("content-length")) {
            case Some(v) =>
                assertTrue(v == "5",
                    message: "Content-Length should be the partial body size")
            case None =>
                assertTrue(false, message: "Content-Length header should be present")
        }

        // 主体应为请求的范围
        let body = resp.bodyAsString()
        assertTrue(body == "Hello",
            message: "Body should contain the requested byte range 'Hello'")
    }

    @TestCase
    public func testServeContentHeadRequest(): Unit {
        let data = unsafe { "Hello World".rawData() }
        let req = HttpRequest(method: HttpMethod.HEAD, url: "/")
        let resp = serveContent(data, req, "text/plain; charset=utf-8")

        assertTrue(resp.status == HttpStatus.OK,
            message: "HEAD request should return 200 OK")

        // HEAD 请求主体必须为空（根据 RFC 7231 第 4.3.2 节不传输主体）
        assertTrue(resp.body.getLimit() == 0,
            message: "HEAD response should have an empty body (0 bytes)")

        // 头部仍必须存在（与 GET 相同但不含主体）
        match (resp.headers.get("content-length")) {
            case Some(v) =>
                assertTrue(v == "11",
                    message: "Content-Length should still be present on HEAD response")
            case None =>
                assertTrue(false, message: "Content-Length should be present on HEAD")
        }

        match (resp.headers.get("content-type")) {
            case Some(v) =>
                assertTrue(v == "text/plain; charset=utf-8",
                    message: "Content-Type should still be present on HEAD response")
            case None =>
                assertTrue(false, message: "Content-Type should be present on HEAD")
        }

        // Accept-Ranges 也应存在
        match (resp.headers.get("accept-ranges")) {
            case Some(v) =>
                assertTrue(v == "bytes",
                    message: "Accept-Ranges should be present on HEAD response")
            case None =>
                assertTrue(false, message: "Accept-Ranges should be present on HEAD")
        }
    }

    // ============================================================
    // serveFileDownload 测试
    // ============================================================

    @TestCase
    public func testServeFileDownloadBasic(): Unit {
        let data: Array<UInt8> = [72, 101, 108, 108, 111]  // "Hello" 测试数据
        let resp = serveFileDownload(data, "test.txt", contentType: "text/plain")

        assertTrue(resp.status == HttpStatus.OK,
            message: "serveFileDownload should return 200 OK")

        // Content-Type 头部
        match (resp.headers.get("content-type")) {
            case Some(v) =>
                assertTrue(v == "text/plain",
                    message: "Content-Type should match the supplied contentType")
            case None =>
                assertTrue(false, message: "Content-Type header should be present")
        }

        // Content-Length 头部
        match (resp.headers.get("content-length")) {
            case Some(v) =>
                assertTrue(v == "5",
                    message: "Content-Length should match data size")
            case None =>
                assertTrue(false, message: "Content-Length header should be present")
        }

        // Content-Disposition 头部
        match (resp.headers.get("content-disposition")) {
            case Some(v) =>
                assertTrue(v == "attachment; filename=\"test.txt\"",
                    message: "Content-Disposition should be set for file download")
            case None =>
                assertTrue(false, message: "Content-Disposition header should be present")
        }

        // 主体
        let body = resp.bodyAsString()
        assertTrue(body == "Hello",
            message: "Response body should match input data")
    }

    @TestCase
    public func testServeFileDownloadContentDisposition(): Unit {
        let data = unsafe { "PDF content here".rawData() }
        let resp = serveFileDownload(data, "report.pdf")

        // 默认内容类型应为 application/octet-stream
        match (resp.headers.get("content-type")) {
            case Some(v) =>
                assertTrue(v == "application/octet-stream",
                    message: "Default Content-Type should be application/octet-stream")
            case None =>
                assertTrue(false, message: "Content-Type header should be present")
        }

        // Content-Disposition 头部 应包含文件名
        match (resp.headers.get("content-disposition")) {
            case Some(v) =>
                assertTrue(v == "attachment; filename=\"report.pdf\"",
                    message: "Content-Disposition should include the given filename")
            case None =>
                assertTrue(false, message: "Content-Disposition header should be present")
        }

        // Content-Length 头部
        match (resp.headers.get("content-length")) {
            case Some(v) =>
                assertTrue(v == "${data.size}",
                    message: "Content-Length should match data size")
            case None =>
                assertTrue(false, message: "Content-Length header should be present")
        }

        // 验证 200 OK
        assertTrue(resp.status == HttpStatus.OK,
            message: "serveFileDownload should return 200 OK")
    }
}
