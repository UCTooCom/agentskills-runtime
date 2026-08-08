package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class Utf8ToolsTests {
    @TestCase
    public func testByteBuilderAppend() {
        let bb = ByteBuilder(4)
        bb.append(0x48); bb.append(0x69)
        @Assert(bb.build(), "Hi")
    }

    @TestCase
    public func testByteBuilderAppendAll() {
        let bb = ByteBuilder(4)
        bb.appendAll(stringToBytes("abc"))
        @Assert(bb.build(), "abc")
    }

    @TestCase
    public func testByteBuilderAppendString() {
        let bb = ByteBuilder(4)
        bb.appendString("hello")
        @Assert(bb.build(), "hello")
    }

    @TestCase
    public func testByteBuilderAppendRune() {
        let bb = ByteBuilder(8)
        bb.appendRune(r'A')
        @Assert(bb.build(), "A")
    }

    @TestCase
    public func testByteBuilderAppendCodePoint() {
        let bb = ByteBuilder(8)
        bb.appendCodePoint(0x24)
        @Assert(bb.build(), "$")
    }

    @TestCase
    public func testByteBuilderAppendBytes() {
        let bb = ByteBuilder(8)
        bb.appendBytes(stringToBytes("world"), 0, 5)
        @Assert(bb.build(), "world")
    }

    @TestCase
    public func testByteBuilderGetBytes() {
        let bb = ByteBuilder(4)
        bb.append(0x41); bb.append(0x42)
        @Assert(bb.getBytes().size, 2)
    }

    @TestCase
    public func testByteBuilderClear() {
        let bb = ByteBuilder(4)
        bb.appendString("data"); bb.clear()
        @Assert(bb.build(), "")
    }

    @TestCase
    public func testByteBuilderGetSize() {
        let bb = ByteBuilder(4)
        bb.appendString("test")
        @Assert(bb.getSize(), 4)
    }

    @TestCase
    public func testByteBuilderGrowth() {
        let bb = ByteBuilder(2)
        bb.appendString("hello world!")
        @Assert(bb.build(), "hello world!")
    }

    // stringToBytes
    @TestCase
    public func testStringToBytes() {
        let bytes = stringToBytes("ABC")
        @Assert(bytes.size, 3)
        @Assert(Int64(bytes[0]), 0x41)
    }

    @TestCase
    public func testStringToBytesEmpty() {
        @Assert(stringToBytes("").size, 0)
    }

    // utf8DecodeByte
    @TestCase
    public func testUtf8DecodeAscii() {
        let (r, len) = utf8DecodeByte(stringToBytes("A"), 0)
        @Assert(len, 1)
        @Assert(Int64(UInt32(r)), 0x41)
    }

    @TestCase
    public func testUtf8DecodeTwoByte() {
        let bytes = stringToBytes("\u{00E9}")
        let (_, len) = utf8DecodeByte(bytes, 0)
        @Assert(len, 2)
    }

    // utf8EncodeCodePoint
    @TestCase
    public func testUtf8EncodeAscii() {
        @Assert(utf8EncodeCodePoint(0x41).size, 1)
    }

    @TestCase
    public func testUtf8EncodeTwoByte() {
        @Assert(utf8EncodeCodePoint(0x00E9).size, 2)
    }

    // byteToHexValue
    @TestCase
    public func testByteToHexValue() {
        @Assert(byteToHexValue(0x30), 0)
        @Assert(byteToHexValue(0x39), 9)
        @Assert(byteToHexValue(0x41), 10)
        @Assert(byteToHexValue(0x66), 15)
        @Assert(byteToHexValue(0x7A), -1)
    }

    // parseHexCodePoint
    @TestCase
    public func testParseHexCodePoint() {
        let (cp, valid) = parseHexCodePoint(stringToBytes("0041"), 0)
        @Assert(valid)
        @Assert(cp, 0x41)
    }

    @TestCase
    public func testParseHexCodePointInvalid() {
        let (_, valid) = parseHexCodePoint(stringToBytes("ZZZZ"), 0)
        @Assert(!valid)
    }

    @TestCase
    public func testParseHexCodePointMax() {
        let (cp, valid) = parseHexCodePoint(stringToBytes("FFFF"), 0)
        @Assert(valid)
        @Assert(cp, 0xFFFF)
    }

    // Surrogates
    @TestCase
    public func testSurrogates() {
        @Assert(isHighSurrogate(0xD800))
        @Assert(isHighSurrogate(0xDBFF))
        @Assert(!isHighSurrogate(0xDC00))
        @Assert(isLowSurrogate(0xDC00))
        @Assert(!isLowSurrogate(0xD800))
        @Assert(combineSurrogatePair(0xD83D, 0xDE00), 0x1F600)
    }

    // Char classification
    @TestCase
    public func testIsDigitByte() {
        @Assert(isDigitByte(0x30))
        @Assert(isDigitByte(0x39))
        @Assert(!isDigitByte(0x41))
    }

    @TestCase
    public func testIsWhitespaceByte() {
        @Assert(isWhitespaceByte(0x20))
        @Assert(isWhitespaceByte(0x09))
        @Assert(isWhitespaceByte(0x0A))
        @Assert(!isWhitespaceByte(0x41))
    }

    @TestCase
    public func testIsHexDigitByte() {
        @Assert(isHexDigitByte(0x30))
        @Assert(isHexDigitByte(0x41))
        @Assert(isHexDigitByte(0x66))
        @Assert(!isHexDigitByte(0x47))
    }

    @TestCase
    public func testIsIdentifierStartByte() {
        @Assert(isIdentifierStartByte(0x41))
        @Assert(isIdentifierStartByte(0x5F))
        @Assert(!isIdentifierStartByte(0x30))
    }

    @TestCase
    public func testNeedsEscapeInString() {
        @Assert(needsEscapeInString(0x22))
        @Assert(!needsEscapeInString(0x5C))
        @Assert(!needsEscapeInString(0x41))
    }

    // decodeEscapeChar
    @TestCase
    public func testDecodeEscapeChar() {
        match (decodeEscapeChar(0x6E)) {
            case EscapeResult.Char(c) => @Assert(Int64(UInt32(c)), 0x0A)
            case _ => @Assert(false)
        }
    }

    @TestCase
    public func testDecodeEscapeCharUnicode() {
        match (decodeEscapeChar(0x75)) {
            case EscapeResult.Unicode => @Assert(true)
            case _ => @Assert(false)
        }
    }

    @TestCase
    public func testDecodeEscapeCharInvalid() {
        match (decodeEscapeChar(0x7A)) {
            case EscapeResult.Invalid => @Assert(true)
            case _ => @Assert(false)
        }
    }

    // JsonError
    @TestCase
    public func testJsonError() {
        let err = JsonError(JsonErrorCode.UnexpectedToken, "bad", 1, 5, "ctx")
        @Assert(err.errMsg == "bad")
        @Assert(err.line, 1)
        @Assert(err.column, 5)
        let s = err.toString()
        @Assert(s.contains("Unexpected token"))
    }

    @TestCase
    public func testJsonTypeError() {
        let err = JsonTypeError("Expected string")
        @Assert(err.errMsg, "Expected string")
    }

    // Error helper functions
    @TestCase
    public func testLexerError() {
        let err = lexerError("lex", 2, 3)
        @Assert(err.line, 2)
        @Assert(err.column, 3)
    }

    @TestCase
    public func testParseError() {
        let err = parseError("parse", 4, 5)
        @Assert(err.line, 4)
    }

    @TestCase
    public func testNumberError() {
        let err = numberError("num", 6)
        @Assert(err.errMsg, "num")
    }

    // Number parser
    @TestCase
    public func testParseJsonNumberBytes() {
        let bytes = stringToBytes("42")
        @Assert(parseJsonNumberBytes(bytes, 0, 2), 42.0)
    }

    @TestCase
    public func testParseJsonNumberBytesNegative() {
        let bytes = stringToBytes("-3.14")
        @Assert(parseJsonNumberBytes(bytes, 0, 5), -3.14)
    }

    @TestCase
    public func testParseJsonNumberBytesScientific() {
        let bytes = stringToBytes("2.5e3")
        @Assert(parseJsonNumberBytes(bytes, 0, 5), 2500.0)
    }

    @TestCase
    public func testParseJsonNumberBytesZero() {
        let bytes = stringToBytes("0")
        @Assert(parseJsonNumberBytes(bytes, 0, 1), 0.0)
    }

    @TestCase
    public func testParseJson5NumberText() {
        @Assert(parseJson5NumberText("255"), 255.0)
    }

    @TestCase
    public func testParseJson5NumberTextHex() {
        @Assert(parseJson5NumberText("0xFF"), 255.0)
    }

    @TestCase
    public func testParseJson5NumberTextInfinity() {
        @Assert(parseJson5NumberText("Infinity") > 1e308)
    }

    @TestCase
    public func testParseJson5NumberTextNaN() {
        let n = parseJson5NumberText("NaN")
        @Assert(n != n)
    }

    // POW10_TABLE
    @TestCase
    public func testPow10Table() {
        @Assert(POW10_TABLE[0], 1.0)
        @Assert(POW10_TABLE[3], 1000.0)
    }

    // isIdentifierPartByte
    @TestCase
    public func testIsIdentifierPartByte() {
        @Assert(isIdentifierPartByte(0x41))
        @Assert(isIdentifierPartByte(0x30))
        @Assert(!isIdentifierPartByte(0x2E))
    }

    // needsEscapeInString non-escape chars
    @TestCase
    public func testNeedsEscapeNegative() {
        @Assert(!needsEscapeInString(0x41))
        let notEscape = needsEscapeInString(0x20)
        @Assert(notEscape == false)
    }
}
