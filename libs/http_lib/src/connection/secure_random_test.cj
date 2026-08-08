package http_lib.connection
import http_lib.core.{assertTrue, assertFalse}

@Test public class SecureRandomUnitTest {
    @TestCase public func t01(): Unit { assertTrue(secureRandom32().size==32) }
    @TestCase public func t02(): Unit { let a=secureRandom32();let b=secureRandom32();var same=true;var i:Int64=0;while(i<32){if(a[i]!=b[i]){same=false};i+=1};assertFalse(same) }

    @TestCase public func testSecureRandomCustomSize(): Unit {
        let result = secureRandom(16)
        assertTrue(result.size == 16)
    }

    @TestCase public func testSecureRandomZero(): Unit {
        let result = secureRandom(0)
        assertTrue(result.size == 0)
    }

    @TestCase public func testSecureRandomNegative(): Unit {
        let result = secureRandom(-1)
        assertTrue(result.size == 0)
    }

    @TestCase public func testSecureRandomLarge(): Unit {
        let result = secureRandom(1024)
        assertTrue(result.size == 1024)
    }

    @TestCase public func testSecureRandomNonZero(): Unit {
        let result = secureRandom(64)
        var allZero = true
        var i: Int64 = 0
        while (i < result.size) {
            if (result[i] != 0) { allZero = false }
            i += 1
        }
        assertFalse(allZero)
    }
}
