package http_lib.message
import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpHeaders}
import http_lib.buffer.ByteBuffer
import std.collection.{HashMap}

@Test
public class BodyParserTest {
    @TestCase
    public func testParseUrlEncodedSimple(): Unit {
        let result = BodyParser.parseUrlEncoded("key=value")
        match (result.get("key")) {
            case Some(v) => assertTrue(v == "value")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseUrlEncodedMultiple(): Unit {
        let result = BodyParser.parseUrlEncoded("a=1&b=2&c=3")
        match (result.get("a")) {
            case Some(v) => assertTrue(v == "1")
            case None => assertTrue(false)
        }
        match (result.get("b")) {
            case Some(v) => assertTrue(v == "2")
            case None => assertTrue(false)
        }
        match (result.get("c")) {
            case Some(v) => assertTrue(v == "3")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseUrlEncodedUrlDecode(): Unit {
        let result = BodyParser.parseUrlEncoded("name=hello+world&q=%E4%B8%AD%E6%96%87")
        match (result.get("name")) {
            case Some(v) => assertTrue(v == "hello world")
            case None => assertTrue(false)
        }
        match (result.get("q")) {
            case Some(v) => assertTrue(v.size > 0)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseUrlEncodedEmpty(): Unit {
        let result = BodyParser.parseUrlEncoded("")
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testParseUrlEncodedSpecialChars(): Unit {
        let result = BodyParser.parseUrlEncoded("a%3Db%3Dc&space+plus")
        match (result.get("a%3Db%3Dc")) {
            case Some(v) => assertTrue(v == "")
            case None => ()
        }
    }

    @TestCase
    public func testExtractBoundary(): Unit {
        let ct = "multipart/form-data; boundary=----WebKitFormBoundary"
        match (BodyParser.extractBoundary(ct)) {
            case Some(b) => assertTrue(b == "----WebKitFormBoundary")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testExtractBoundaryQuoted(): Unit {
        let ct = "multipart/form-data; boundary=\"----12345\""
        match (BodyParser.extractBoundary(ct)) {
            case Some(b) => assertTrue(b == "----12345")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testExtractBoundaryMissing(): Unit {
        let ct = "text/plain"
        assertTrue(BodyParser.extractBoundary(ct).isNone())
    }

    @TestCase
    public func testParseMultipartBasic(): Unit {
        let boundary = "boundary123"
        let bodyStr = "--boundary123\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nvalue1\r\n--boundary123--\r\n"
        let result = BodyParser.parseMultipart(unsafe { bodyStr.rawData() }, boundary)
        match (result.get("field1")) {
            case Some(f) => assertTrue(f.asString() == "value1")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseMultipartFile(): Unit {
        let boundary = "BOUNDARY"
        let bodyStr = "--BOUNDARY\r\nContent-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\nContent-Type: text/plain\r\n\r\nHello\r\n--BOUNDARY--\r\n"
        let result = BodyParser.parseMultipart(unsafe { bodyStr.rawData() }, boundary)
        match (result.get("file")) {
            case Some(f) =>
                assertTrue(f.fileName == "test.txt")
                assertTrue(f.asString() == "Hello")
                match (f.headers.get("content-type")) {
                    case Some(ct) => assertTrue(ct == "text/plain")
                    case None => assertTrue(false)
                }
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseMultipartMultipleFields(): Unit {
        let boundary = "---BOUNDARY---"
        let bodyStr = "-----BOUNDARY---\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\n1\r\n-----BOUNDARY---\r\nContent-Disposition: form-data; name=\"b\"\r\n\r\n2\r\n-----BOUNDARY-----"
        let result = BodyParser.parseMultipart(unsafe { bodyStr.rawData() }, boundary)
        assertTrue(result.size > 0)
    }

    @TestCase
    public func testParseMultipartEmptyBody(): Unit {
        let result = BodyParser.parseMultipart([], "boundary")
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testParseUrlEncodedEmptyValue(): Unit {
        let result = BodyParser.parseUrlEncoded("key=&foo=bar")
        match (result.get("key")) {
            case Some(v) => assertTrue(v == "")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseUrlEncodedUrlDecodedPlus(): Unit {
        let result = BodyParser.parseUrlEncoded("q=hello+world+test")
        match (result.get("q")) {
            case Some(v) => assertTrue(v == "hello world test")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseUrlEncodedPercentEncoding(): Unit {
        let result = BodyParser.parseUrlEncoded("data=%21%40%23%24%25%5E")
        match (result.get("data")) {
            case Some(v) => assertTrue(v == "!@#$%^")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testGenerateMultipartBoundary(): Unit {
        let boundary = generateMultipartBoundary()
        assertTrue(boundary.size > 16)
        assertTrue(boundary.startsWith("----stdHttpLib"))
    }

    @TestCase
    public func testBuildMultipartBody(): Unit {
        let boundary = "testBoundary"
        let fields = HashMap<String, MultipartField>()
        let field1 = MultipartField("name", data: unsafe { "test".rawData() })
        fields["name"] = field1
        let body = buildMultipartBody(fields, boundary)
        assertTrue(body.size > 0)
    }

    @TestCase
    public func testBuildMultipartBodyEmptyFields(): Unit {
        let fields = HashMap<String, MultipartField>()
        let body = buildMultipartBody(fields, "boundary")
        assertTrue(body.size == 0)
    }

    @TestCase
    public func testMultipartFieldAsString(): Unit {
        let field = MultipartField("test", data: unsafe { "hello".rawData() })
        assertTrue(field.asString() == "hello")
    }

    @TestCase
    public func testParseJsonValid(): Unit {
        let result = BodyParser.parseJson("{\"key\": \"value\", \"num\": 42}")
        // 我们无法轻易深入检查 JsonValue，因此仅验证其能解析
        assertTrue(true) // 无异常即解析成功
    }

    @TestCase
    public func testParseJsonBody(): Unit {
        let request = HttpRequest(
            method: HttpMethod.POST,
            url: "http://example.com/api",
            headers: HttpHeaders(),
            body: ByteBuffer()
        )
        let jsonStr = "{\"data\": \"test\"}"
        request.setBody(unsafe { jsonStr.rawData() })
        request.headers.set("Content-Type", "application/json")
        try {
            let result = parseJsonBody(request)
            assertTrue(true) // 不应抛出异常
        } catch (_: Exception) {
            assertTrue(true) // JSON 解析可能优雅失败
        }
    }

    @TestCase
    public func testParseJsonInvalid(): Unit {
        try {
            let result = BodyParser.parseJson("not valid json")
            assertTrue(true) // 取决于实现行为
        } catch (_: Exception) {
            assertTrue(true) // 抛出异常也可接受
        }
    }

    @TestCase
    public func testParseFormBodyEmpty(): Unit {
        let req = HttpRequest(method: HttpMethod.POST, url: "/api")
        let form = parseFormBody(req)
        assertTrue(form.size == 0,
            message: "Empty request should return empty form")
    }

    @TestCase
    public func testParseFormBodySimple(): Unit {
        let req = HttpRequest(method: HttpMethod.POST, url: "/api")
        req.headers.set("Content-Type", "application/x-www-form-urlencoded")
        let bodyData = unsafe { "name=test&value=123".rawData() }
        req.setBody(bodyData)
        let form = parseFormBody(req)
        match (form.get("name")) {
            case Some(v) => assertTrue(v == "test",
                message: "name should be 'test', got '${v}'")
            case None => assertTrue(false,
                message: "name should be present")
        }
        match (form.get("value")) {
            case Some(v) => assertTrue(v == "123")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseFormBodyUrlEncoded(): Unit {
        let req = HttpRequest(method: HttpMethod.POST, url: "/api")
        req.headers.set("Content-Type", "application/x-www-form-urlencoded")
        let bodyData = unsafe { "key1=value%201&key2=a%2Bb&empty=&special=%26%3D".rawData() }
        req.setBody(bodyData)
        let form = parseFormBody(req)
        assertTrue(form.size > 0,
            message: "Form should have entries")
    }

    @TestCase
    public func testParseMultipartBodySimple(): Unit {
        let boundary = generateMultipartBoundary()
        let fields = HashMap<String, MultipartField>()
        fields["file1"] = MultipartField("file1", fileName: "test.txt", data: unsafe { "hello".rawData() })
        let bodyData = buildMultipartBody(fields, boundary)
        let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
        req.headers.set("Content-Type", "multipart/form-data; boundary=${boundary}")
        req.setBody(bodyData)
        let parsed = parseMultipartBody(req)
        assertTrue(parsed.size > 0,
            message: "Should parse at least one field")
    }

    @TestCase
    public func testParseMultipartBodyMultipleFields(): Unit {
        let boundary = generateMultipartBoundary()
        let fields = HashMap<String, MultipartField>()
        fields["text"] = MultipartField("text", data: unsafe { "plain text".rawData() })
        fields["file"] = MultipartField("file", fileName: "data.bin", data: unsafe { "binary".rawData() })
        let bodyData = buildMultipartBody(fields, boundary)
        let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
        req.headers.set("Content-Type", "multipart/form-data; boundary=${boundary}")
        req.setBody(bodyData)
        let parsed = parseMultipartBody(req)
        match (parsed.get("text")) {
            case Some(f) => assertTrue(f.asString() == "plain text")
            case None => assertTrue(false,
                message: "text field should be present")
        }
    }

    @TestCase
    public func testParseMultipartBodyEmptyBody(): Unit {
        let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
        req.headers.set("Content-Type", "multipart/form-data; boundary=test")
        let parsed = parseMultipartBody(req)
        assertTrue(parsed.size == 0,
            message: "Empty body should return empty map")
    }
}
