/**
 * Prefer Header 支持单元测试。
 */
package http_lib.message

import http_lib.core.{assertTrue, assertFalse}

@Test
public class PreferHeaderTest {
    /**
     * 测试解析 return=minimal。
     */
    @TestCase
    public func testParseReturnMinimal(): Unit {
        let params = parsePreferHeader("return=minimal")
        assertTrue(params.isReturnMinimal(), message: "should be return=minimal")
        assertTrue(!params.isReturnRepresentation(), message: "should not be return=representation")
    }

    /**
     * 测试解析 respond-async。
     */
    @TestCase
    public func testParseRespondAsync(): Unit {
        let params = parsePreferHeader("respond-async")
        assertTrue(params.isRespondAsync(), message: "should be respond-async")
    }

    /**
     * 测试解析 wait 参数。
     */
    @TestCase
    public func testParseWait(): Unit {
        let params = parsePreferHeader("wait=10")
        match (params.getWait()) {
            case Some(w) => assertTrue(w == "10", message: "wait = 10")
            case None => assertTrue(false, message: "should have wait")
        }
    }

    /**
     * 测试解析多个偏好。
     */
    @TestCase
    public func testParseMultipleTokens(): Unit {
        let params = parsePreferHeader("return=minimal, wait=30")
        assertTrue(params.isReturnMinimal(), message: "return=minimal")
        match (params.getWait()) {
            case Some(w) => assertTrue(w == "30", message: "wait = 30")
            case None => assertTrue(false, message: "should have wait")
        }
    }

    /**
     * 测试解析空字符串。
     */
    @TestCase
    public func testParseEmpty(): Unit {
        let params = parsePreferHeader("")
        assertTrue(!params.isReturnMinimal(), message: "empty should not have tokens")
        assertTrue(!params.isRespondAsync(), message: "empty should not have respond-async")
    }

    /**
     * 测试构建 Preference-Applied。
     */
    @TestCase
    public func testBuildPreferenceApplied(): Unit {
        let params = PreferParams()
        params.tokens["respond-async"] = ""
        params.tokens["wait"] = "10"

        let header = buildPreferenceApplied(params)
        assertTrue(header.contains("respond-async"), message: "should contain respond-async")
        assertTrue(header.contains("wait"), message: "should contain wait")
    }

    /**
     * 测试解析 return=representation。
     */
    @TestCase
    public func testParseReturnRepresentation(): Unit {
        let params = parsePreferHeader("return=representation")
        assertTrue(params.isReturnRepresentation(), message: "should be return=representation")
        assertTrue(!params.isReturnMinimal(), message: "should not be return=minimal")
    }

    /**
     * 测试解析带引号的值。
     */
    @TestCase
    public func testParseQuotedValue(): Unit {
        // 标准 prefer 头不常用引号，但兼容解析
        let params = parsePreferHeader("wait=\"30\"")
        match (params.getWait()) {
            case Some(w) => assertTrue(w == "30", message: "quoted wait = 30")
            case None => assertTrue(false, message: "should have quoted wait")
        }
    }
}
