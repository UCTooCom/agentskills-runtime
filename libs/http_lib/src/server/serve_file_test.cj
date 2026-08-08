package http_lib.server

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * serveFile 和 serveFileDownload 函数的测试。
ServeFile 测试模式。
 */
@Test
public class ServeFileTest {

    /**
     * serveFile 对不存在的文件返回 404。
     */
    @TestCase
    public func testServeFileNotFound(): Unit {
        let handler = serveFile("/nonexistent")
        let req = HttpRequest(method: HttpMethod.GET, url: "/test.txt")
        let resp = handler(req)
        assertTrue(resp.status.code == 404u16, message: "Expected 404 for non-existent file")
    }

    /**
     * serveFileDownload 返回正确的头部和主体。
     */
    @TestCase
    public func testServeFileDownload(): Unit {
        let data: Array<UInt8> = [0x48, 0x65, 0x6c, 0x6c, 0x6f]
        let resp = serveFileDownload(data, "hello.txt", contentType: "text/plain")

        assertTrue(resp.status.code == 200u16)
        match (resp.headers.get("Content-Type")) {
            case Some(ct) => assertTrue(ct == "text/plain", message: "Wrong Content-Type")
            case None => assertTrue(false, message: "Missing Content-Type")
        }
        match (resp.headers.get("Content-Disposition")) {
            case Some(cd) => assertTrue(cd == "attachment; filename=\"hello.txt\"", message: "Wrong Content-Disposition")
            case None => assertTrue(false, message: "Missing Content-Disposition")
        }
        match (resp.headers.get("Content-Length")) {
            case Some(cl) => assertTrue(cl == "5", message: "Wrong Content-Length")
            case None => assertTrue(false, message: "Missing Content-Length")
        }
        let body = resp.bodyAsString()
        assertTrue(body == "Hello", message: "Unexpected body")
    }

    /**
     * serveFileDownload 默认内容类型。
     */
    @TestCase
    public func testServeFileDownloadDefaultContentType(): Unit {
        let data: Array<UInt8> = [0x48, 0x69]
        let resp = serveFileDownload(data, "file.bin")
        match (resp.headers.get("Content-Type")) {
            case Some(ct) => assertTrue(ct == "application/octet-stream", message: "Wrong default Content-Type")
            case None => assertTrue(false, message: "Missing Content-Type")
        }
    }

    /**
     * serveFileData 使用空主体。
     */
    @TestCase
    public func testServeFileDataEmpty(): Unit {
        let data: Array<UInt8> = []
        let resp = serveFileDownload(data, "empty.txt")
        match (resp.headers.get("Content-Length")) {
            case Some(cl) => assertTrue(cl == "0", message: "Expected Content-Length 0")
            case None => assertTrue(false, message: "Missing Content-Length")
        }
        let body = resp.bodyAsBytes()
        assertTrue(body.size == 0, message: "Expected empty body")
    }

    /**
     * serveFileDownload 忽略 range 头部返回完整内容。
     */
    @TestCase
    public func testServeFileDownloadIgnoresRange(): Unit {
        let data: Array<UInt8> = [0x41, 0x42, 0x43, 0x44, 0x45]
        let resp = serveFileDownload(data, "test.txt")
        assertTrue(resp.status.code == 200u16, message: "Expected 200")
        let body = resp.bodyAsBytes()
        assertTrue(body.size == 5, message: "Expected full content (5 bytes)")
    }

    /**
     * serveFile 按扩展名的 MIME 类型检测。
     */
    @TestCase
    public func testServeFileMimeTypes(): Unit {
        assertTrue(mimeTypeByExtension("file.html") == "text/html; charset=utf-8", message: "Wrong .html mime")
        assertTrue(mimeTypeByExtension("file.json") == "application/json", message: "Wrong .json mime")
        assertTrue(mimeTypeByExtension("file.css") == "text/css; charset=utf-8", message: "Wrong .css mime")
        assertTrue(mimeTypeByExtension("file.js") == "application/javascript; charset=utf-8", message: "Wrong .js mime")
        assertTrue(mimeTypeByExtension("file.png") == "image/png", message: "Wrong .png mime")
        assertTrue(mimeTypeByExtension("file.jpg") == "image/jpeg", message: "Wrong .jpg mime")
        assertTrue(mimeTypeByExtension("file.pdf") == "application/pdf", message: "Wrong .pdf mime")
        assertTrue(mimeTypeByExtension("file.unknown") == "application/octet-stream", message: "Wrong unknown mime")
    }

    /**
     * serveFile 对空根路径返回 404。
     */
    @TestCase
    public func testServeFileEmptyRoot(): Unit {
        let handler = serveFile("")
        let req = HttpRequest(method: HttpMethod.GET, url: "/test.txt")
        let resp = handler(req)
        assertTrue(resp.status.code == 404u16, message: "Expected 404 for empty root")
    }
}
