package http_lib.core

@Test
public class MethodTest {
    @TestCase
    public func testToString(): Unit {
        assertTrue(HttpMethod.GET.toString() == "GET")
        assertTrue(HttpMethod.POST.toString() == "POST")
        assertTrue(HttpMethod.PUT.toString() == "PUT")
        assertTrue(HttpMethod.DELETE.toString() == "DELETE")
        assertTrue(HttpMethod.HEAD.toString() == "HEAD")
        assertTrue(HttpMethod.OPTIONS.toString() == "OPTIONS")
        assertTrue(HttpMethod.PATCH.toString() == "PATCH")
        assertTrue(HttpMethod.TRACE.toString() == "TRACE")
        assertTrue(HttpMethod.CONNECT.toString() == "CONNECT")
    }

    @TestCase
    public func testParse(): Unit {
        match (HttpMethod.parse("GET")) {
            case Some(m) => assertTrue(m == HttpMethod.GET)
            case None => assertTrue(false)
        }
        match (HttpMethod.parse("POST")) {
            case Some(m) => assertTrue(m == HttpMethod.POST)
            case None => assertTrue(false)
        }
        match (HttpMethod.parse("DELETE")) {
            case Some(m) => assertTrue(m == HttpMethod.DELETE)
            case None => assertTrue(false)
        }
        assertTrue(HttpMethod.parse("UNKNOWN").isNone())
    }

    @TestCase
    public func testHashCode(): Unit {
        // @Derive[Hashable] 的哈希码由实现定义；
        // 测试一致性而非具体值。
        assertTrue(HttpMethod.GET.hashCode() == HttpMethod.GET.hashCode())
        assertTrue(HttpMethod.GET.hashCode() != HttpMethod.POST.hashCode())
        assertTrue(HttpMethod.POST.hashCode() == HttpMethod.POST.hashCode())
    }

    @TestCase
    public func testEquality(): Unit {
        assertTrue(HttpMethod.GET == HttpMethod.GET)
        assertTrue(HttpMethod.GET != HttpMethod.POST)
    }
}
