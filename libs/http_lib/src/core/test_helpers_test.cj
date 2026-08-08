/**
 * 测试辅助函数（assertEqual / assertTrue / assertFalse）的单元测试。
 *
 * 验证这些断言函数在条件满足时通过，在不满足时正确抛出异常。
 */
package http_lib.core

@Test
public class TestHelpersTest {

    @TestCase
    public func testAssertEqualStringPass(): Unit {
        assertEqual("hello", "hello")
        assertTrue(true)
    }

    @TestCase
    public func testAssertEqualStringFail(): Unit {
        var caught = false
        try {
            assertEqual("hello", "world")
        } catch (_: Exception) {
            caught = true
        }
        assertTrue(caught)
    }

    @TestCase
    public func testAssertEqualInt64Pass(): Unit {
        assertEqual(42, 42)
        assertTrue(true)
    }

    @TestCase
    public func testAssertEqualInt64Fail(): Unit {
        var caught = false
        try {
            assertEqual(42, 0)
        } catch (_: Exception) {
            caught = true
        }
        assertTrue(caught)
    }

    @TestCase
    public func testAssertTruePass(): Unit {
        assertTrue(true)
        assertTrue(true)
    }

    @TestCase
    public func testAssertTrueFail(): Unit {
        var caught = false
        try {
            assertTrue(false)
        } catch (_: Exception) {
            caught = true
        }
        assertTrue(caught)
    }

    @TestCase
    public func testAssertFalsePass(): Unit {
        assertFalse(false)
        assertTrue(true)
    }

    @TestCase
    public func testAssertFalseFail(): Unit {
        var caught = false
        try {
            assertFalse(true)
        } catch (_: Exception) {
            caught = true
        }
        assertTrue(caught)
    }

    @TestCase
    public func testAssertEqualStringCustomMessage(): Unit {
        var caught = false
        try {
            assertEqual("a", "b", message: "custom message")
        } catch (_: Exception) {
            caught = true
        }
        assertTrue(caught)
    }

    @TestCase
    public func testAssertTrueCustomMessage(): Unit {
        var caught = false
        try {
            assertTrue(false, message: "should be true")
        } catch (_: Exception) {
            caught = true
        }
        assertTrue(caught)
    }
}
