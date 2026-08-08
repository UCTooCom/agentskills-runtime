package http_lib.utils

/**
 * 工具函数性能基准测试。
 * Base64、十六进制、字符串比较、URL编码、字节搜索等操作。
 */
@Test public class Base64Bench {
    @Bench
    public func base64EncodeBytesSmall(): Unit {
        let data = unsafe { "Hello, World!".rawData() }
        let _ = base64EncodeBytes(data)
    }

    @Bench
    public func base64EncodeBytesMedium(): Unit {
        let data = Array<UInt8>(1024, repeat: 0x42)
        let _ = base64EncodeBytes(data)
    }

    @Bench
    public func base64DecodeBytes(): Unit {
        let _ = base64DecodeString("SGVsbG8sIFdvcmxkIQ==")
    }

    @Bench
    public func base64EncodeString(): Unit {
        let _ = base64EncodeString("https://api.example.com/v1/users/12345/profile")
    }
}

@Test public class UrlParserBench {
    @Bench
    public func parseSimpleHttp(): Unit {
        let _ = ParsedUrl.parse("http://example.com/path")
    }

    @Bench
    public func parseSimpleHttps(): Unit {
        let _ = ParsedUrl.parse("https://api.example.com/v1/users/12345/profile")
    }

    @Bench
    public func parseWithPort(): Unit {
        let _ = ParsedUrl.parse("https://example.com:8080/path")
    }

    @Bench
    public func parseWithAuth(): Unit {
        let _ = ParsedUrl.parse("https://user:password@example.com/path")
    }

    @Bench
    public func parseIpv6(): Unit {
        let _ = ParsedUrl.parse("https://[::1]:8080/path")
    }

    @Bench
    public func parseRootPath(): Unit {
        let _ = ParsedUrl.parse("http://example.com/")
    }

    @Bench
    public func parseNoPath(): Unit {
        let _ = ParsedUrl.parse("http://example.com")
    }
}

@Test public class StringCompareBench {
    @Bench
    public func equalsIgnoreCaseBytesRunes(): Unit {
        let a = unsafe { "Content-Type".rawData() }
        let b = "content-type".toRuneArray()
        let _ = equalsIgnoreCaseBytesRunes(a, b)
    }

    @Bench
    public func equalsIgnoreCaseBytesShort(): Unit {
        let a = unsafe { "Content-Type".rawData() }
        let b = unsafe { "content-type".rawData() }
        let _ = equalsIgnoreCaseBytes(a, b)
    }

    @Bench
    public func equalsIgnoreCaseBytesLong(): Unit {
        let a = unsafe { "application/json; charset=utf-8".rawData() }
        let b = unsafe { "Application/JSON; Charset=UTF-8".rawData() }
        let _ = equalsIgnoreCaseBytes(a, b)
    }

    @Bench
    public func containsIgnoreCaseBytesFound(): Unit {
        let data = unsafe { "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".rawData() }
        let needle = unsafe { "XHTML".rawData() }
        let _ = containsIgnoreCaseBytes(data, needle)
    }

    @Bench
    public func containsIgnoreCaseBytesNotFound(): Unit {
        let data = unsafe { "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".rawData() }
        let needle = unsafe { "json".rawData() }
        let _ = containsIgnoreCaseBytes(data, needle)
    }

    @Bench
    public func arraysEqualTrue(): Unit {
        let a = unsafe { "application/json".rawData() }
        let b = unsafe { "application/json".rawData() }
        let _ = arraysEqual(a, b)
    }

    @Bench
    public func startsWithIgnoreCaseTrue(): Unit {
        let data = unsafe { "text/html; charset=utf-8".rawData() }
        let prefix = unsafe { "TEXT/HTML".rawData() }
        let _ = startsWithIgnoreCase(data, prefix)
    }
}

@Test public class AsciiTransformBench {
    @Bench
    public func asciiToLowerNormal(): Unit {
        let _ = asciiToLower("Content-Type: Application/JSON; Charset=UTF-8")
    }

    @Bench
    public func asciiTrimSpaces(): Unit {
        let _ = asciiTrim("   application/json   ")
    }

    @Bench
    public func formUrlEncodeNormal(): Unit {
        let _ = formUrlEncode("name=John Doe&email=john@example.com&message=Hello World")
    }
}

@Test public class HexBench {
    @Bench
    public func hexEncodeSmall(): Unit {
        let data = unsafe { "Hello, World!".rawData() }
        let _ = hexEncode(data)
    }

    @Bench
    public func hexEncodeMedium(): Unit {
        let data = Array<UInt8>(256, repeat: 0xAB)
        let _ = hexEncode(data)
    }

    @Bench
    public func hexDecode(): Unit {
        let _ = hexDecode("48656c6c6f2c20576f726c6421")
    }

    @Bench
    public func toHex32Value(): Unit {
        let _ = toHex32(0xdeadbeefu32)
    }

    @Bench
    public func toHex64Value(): Unit {
        let _ = toHex64(0x3eadbeefcafebabe)
    }

    @Bench
    public func byteToHexCharFn(): Unit {
        let _ = byteToHexChar(0xABu8)
    }

    @Bench
    public func byteToHexCharUpperFn(): Unit {
        let _ = byteToHexCharUpper(0xABu8)
    }
}

@Test public class ByteSearchBench {
    @Bench
    public func findHeaderEndNormal(): Unit {
        let data = unsafe { "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: 42\r\n\r\nbody".rawData() }
        let _ = findHeaderEnd(data, data.size, start: 0)
    }

    @Bench
    public func findCrlfNormal(): Unit {
        let data = unsafe { "Content-Type: text/html\r\nContent-Length: 42\r\n".rawData() }
        let _ = findCrlf(data, data.size, start: 0)
    }

    @Bench
    public func findByteNormal(): Unit {
        let data = unsafe { "GET /api/v1/users HTTP/1.1\r\n".rawData() }
        let _ = findByte(data, 0, data.size, b' ')
    }

    @Bench
    public func skipSpacesNormal(): Unit {
        let data = unsafe { "   \t  \t application/json".rawData() }
        let _ = skipSpaces(data, 0, data.size)
    }

    @Bench
    public func findBytesAtNormal(): Unit {
        let data = unsafe { "GET /api/v1/users/12345/profile HTTP/1.1\r\n".rawData() }
        let pattern = unsafe { "/api/v1".rawData() }
        let _ = findBytesAt(data, 0, data.size, pattern)
    }
}

@Test public class ParseBench {
    @Bench
    public func parsePortStringNormal(): Unit {
        let _ = parsePortString("8080")
    }

    @Bench
    public func copyBytesSmall(): Unit {
        let src = Array<UInt8>(128, repeat: 0x42)
        let dest = Array<UInt8>(128, repeat: 0)
        copyBytes(src, 0, dest, 0, 128)
    }

    @Bench
    public func stringToBytesConv(): Unit {
        let _ = stringToBytes("GET /api/v1/users HTTP/1.1")
    }

    @Bench
    public func bytesToStringConv(): Unit {
        let data = unsafe { "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<body></body>".rawData() }
        let _ = bytesToString(data)
    }
}
