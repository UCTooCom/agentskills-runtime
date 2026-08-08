/**
 * Link Header 解析单元测试。
 */
package http_lib.message

import http_lib.core.{assertTrue, assertFalse}

@Test
internal class LinkHeaderParserTest {
    /**
     * 测试解析单个 Link header。
     */
    @TestCase
    public func testParseSingleLink(): Unit {
        let links = parseLinkHeaders("<https://api.example.com/users?page=2>; rel=\"next\"")
        assertTrue(links.size == 1, message: "should parse one link")

        let link = links[0]
        assertTrue(link.uri == "https://api.example.com/users?page=2", message: "uri mismatch")
        match (link.getRel()) {
            case Some(rel) => assertTrue(rel == "next", message: "rel mismatch")
            case None => assertTrue(false, message: "should have rel")
        }
    }

    /**
     * 测试解析多个 Link header（逗号分隔）。
     */
    @TestCase
    public func testParseMultipleLinks(): Unit {
        let header = "<https://api.example.com/users?page=1>; rel=\"prev\", <https://api.example.com/users?page=3>; rel=\"next\""
        let links = parseLinkHeaders(header)
        assertTrue(links.size == 2, message: "should parse 2 links")

        assertTrue(links[0].uri == "https://api.example.com/users?page=1", message: "first uri")
        match (links[0].getRel()) {
            case Some(rel) => assertTrue(rel == "prev", message: "first rel")
            case None => assertTrue(false, message: "first should have rel")
        }

        assertTrue(links[1].uri == "https://api.example.com/users?page=3", message: "second uri")
        match (links[1].getRel()) {
            case Some(rel) => assertTrue(rel == "next", message: "second rel")
            case None => assertTrue(false, message: "second should have rel")
        }
    }

    /**
     * 测试解析 preload Link header。
     */
    @TestCase
    public func testParsePreloadLink(): Unit {
        let header = "</css/style.css>; rel=preload; as=style"
        let links = parseLinkHeaders(header)
        assertTrue(links.size == 1, message: "should parse preload link")

        let link = links[0]
        assertTrue(link.uri == "/css/style.css", message: "style uri")
        match (link.getRel()) {
            case Some(rel) => assertTrue(rel == "preload", message: "rel = preload")
            case None => assertTrue(false, message: "should have rel")
        }
        match (link.params.get("as")) {
            case Some(asType) => assertTrue(asType == "style", message: "as = style")
            case None => assertTrue(false, message: "should have as")
        }
    }

    /**
     * 测试解析完整的 Link header 带多个参数。
     */
    @TestCase
    public func testParseLinkWithMultipleParams(): Unit {
        let header = "<https://example.com/image.png>; rel=preload; as=image; type=\"image/png\""
        let links = parseLinkHeaders(header)
        assertTrue(links.size == 1, message: "should parse")

        let link = links[0]
        match (link.params.get("type")) {
            case Some(t) => assertTrue(t == "image/png", message: "type param")
            case None => assertTrue(false, message: "should have type")
        }
        match (link.params.get("as")) {
            case Some(asVal) => assertTrue(asVal == "image", message: "as param")
            case None => assertTrue(false, message: "should have as")
        }
    }

    /**
     * 测试解析空字符串。
     */
    @TestCase
    public func testParseEmpty(): Unit {
        let links = parseLinkHeaders("")
        assertTrue(links.size == 0, message: "empty should give 0 links")
    }

    /**
     * 测试 toString 反向构建。
     */
    @TestCase
    public func testToString(): Unit {
        let link = LinkHeader(uri: "/style.css")
        link.params["rel"] = "stylesheet"
        let str = link.toString()
        assertTrue(str.contains("/style.css"), message: "should contain uri")
        assertTrue(str.contains("stylesheet"), message: "should contain rel")
    }
}
