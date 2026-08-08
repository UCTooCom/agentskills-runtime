package http_lib.utils

// 简单断言辅助函数（避免与 http_lib.core 循环依赖）
private func assertTrue(condition: Bool, msg!: String = ""): Unit {
    if (!condition) {
        throw Exception("断言失败: ${msg}")
    }
}

private func assertFalse(condition: Bool, msg!: String = ""): Unit {
    assertTrue(!condition, msg: msg)
}

private func assertEqual(actual: Int64, expected: Int64, msg!: String = ""): Unit {
    if (actual != expected) {
        throw Exception("断言失败: ${msg} 期望 ${expected}，实际为 ${actual}")
    }
}

@Test
public class BytesTest {

    @TestCase
    public func testFindHeaderEnd(): Unit {
        let data = unsafe { "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nbody".rawData() }
        let result = findHeaderEnd(data, data.size)
        assertTrue(result > 0, msg: "应找到头部结束标记")
        assertTrue(result == 45, msg: "头部结束位置为 45")
    }

    @TestCase
    public func testFindHeaderEndNotFound(): Unit {
        let data = unsafe { "无头部结束标记".rawData() }
        let result = findHeaderEnd(data, data.size)
        assertTrue(result == -1, msg: "不应找到头部结束标记")
    }

    @TestCase
    public func testFindHeaderEndWithStart(): Unit {
        let data = unsafe { "忽略\r\n\r\n实际\r\n\r\n标记".rawData() }
        // 从末尾开始查找，应找到第二个 \r\n\r\n
        let result = findHeaderEnd(data, data.size, start: 10)
        assertTrue(result > 0, msg: "从偏移量开始应找到头部结束标记")
    }

    @TestCase
    public func testFindCrlf(): Unit {
        let data = unsafe { "line1\r\nline2".rawData() }
        let result = findCrlf(data, data.size)
        assertEqual(result, 5, msg: "CRLF 在位置 5")
    }

    @TestCase
    public func testFindCrlfNotFound(): Unit {
        let data = unsafe { "无换行".rawData() }
        let result = findCrlf(data, data.size)
        assertTrue(result == -1, msg: "不应找到 CRLF")
    }

    @TestCase
    public func testFindCrlfAt(): Unit {
        let data = unsafe { "ab\r\ndef".rawData() }
        let result = findCrlfAt(data, 1, data.size)
        assertTrue(result == 2, msg: "CRLF 在位置 2")
    }

    @TestCase
    public func testFindCrlfAtNotFound(): Unit {
        let data = unsafe { "abcdef".rawData() }
        let result = findCrlfAt(data, 0, data.size)
        assertTrue(result == -1, msg: "不应找到 CRLF")
    }

    @TestCase
    public func testFindByte(): Unit {
        let data = unsafe { "hello world".rawData() }
        let result = findByte(data, 0, data.size, b'w')
        assertEqual(result, 6, msg: "'w' 在位置 6")
    }

    @TestCase
    public func testFindByteNotFound(): Unit {
        let data = unsafe { "hello".rawData() }
        let result = findByte(data, 0, data.size, b'z')
        assertTrue(result == -1, msg: "未找到 'z'")
    }

    @TestCase
    public func testFindByteAt(): Unit {
        let data = unsafe { "abcdef".rawData() }
        let result = findByteAt(data, 3, data.size, b'e')
        assertEqual(result, 4, msg: "'e' 在位置 4")
    }

    @TestCase
    public func testSkipSpaces(): Unit {
        let data = unsafe { "   abc".rawData() }
        let result = skipSpaces(data, 0, data.size)
        assertEqual(result, 3, msg: "跳过 3 个空格")
    }

    @TestCase
    public func testSkipSpacesNone(): Unit {
        let data = unsafe { "abc".rawData() }
        let result = skipSpaces(data, 0, data.size)
        assertEqual(result, 0, msg: "无空格")
    }

    @TestCase
    public func testSkipSpacesTab(): Unit {
        let data: Array<UInt8> = [b'\t', b'\t', b'a']
        let result = skipSpaces(data, 0, data.size)
        assertEqual(result, 2, msg: "跳过 2 个制表符")
    }

    @TestCase
    public func testTrimEnd(): Unit {
        let data = unsafe { "abc   ".rawData() }
        let result = trimEnd(data, 0, data.size)
        assertEqual(result, 3, msg: "修剪 3 个尾部空格")
    }

    @TestCase
    public func testTrimEndMixed(): Unit {
        let data: Array<UInt8> = [b'a', b'b', b' ', b'\t', b' ']
        let result = trimEnd(data, 0, data.size)
        assertEqual(result, 2, msg: "修剪混合空白")
    }

    @TestCase
    public func testFindBytesAt(): Unit {
        let data = unsafe { "hello world".rawData() }
        let pattern = unsafe { "world".rawData() }
        let result = findBytesAt(data, 0, data.size, pattern)
        assertEqual(result, 6, msg: "模式在位置 6")
    }

    @TestCase
    public func testFindBytesAtNotFound(): Unit {
        let data = unsafe { "hello".rawData() }
        let pattern = unsafe { "xyz".rawData() }
        let result = findBytesAt(data, 0, data.size, pattern)
        assertTrue(result == -1, msg: "未找到模式")
    }

    @TestCase
    public func testFindBytesAtEmptyPattern(): Unit {
        let data = unsafe { "hello".rawData() }
        let result = findBytesAt(data, 0, data.size, [])
        assertTrue(result >= 0, msg: "空模式应返回起始位置")
    }

    @TestCase
    public func testContainsIgnoreCase(): Unit {
        let data = unsafe { "Content-Type: text/html".rawData() }
        let needle = unsafe { "text/html".rawData() }
        let result = containsIgnoreCase(data, 0, data.size, needle)
        assertTrue(result, msg: "应找到大小写不敏感匹配")
    }

    @TestCase
    public func testContainsIgnoreCaseUpper(): Unit {
        let data = unsafe { "CONTENT-TYPE: TEXT/HTML".rawData() }
        let needle = unsafe { "text/html".rawData() }
        let result = containsIgnoreCase(data, 0, data.size, needle)
        assertTrue(result, msg: "应匹配大写内容")
    }

    @TestCase
    public func testContainsIgnoreCasePartial(): Unit {
        let data = unsafe { "Transfer-Encoding: chunked".rawData() }
        let needle = unsafe { "chunked".rawData() }
        let result = containsIgnoreCase(data, 0, data.size, needle)
        assertTrue(result, msg: "应在头部值中找到子字符串")
    }

    @TestCase
    public func testContainsIgnoreCaseNotFound(): Unit {
        let data = unsafe { "hello world".rawData() }
        let needle = unsafe { "xyz".rawData() }
        assertFalse(containsIgnoreCase(data, 0, data.size, needle), msg: "不应找到不存在的模式")
    }
}
