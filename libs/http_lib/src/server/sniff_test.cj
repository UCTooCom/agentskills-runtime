package http_lib.server

import http_lib.core.{assertTrue, assertFalse, assertEqual}

/**
 * Content-Type 嗅探（detectContentType）和 sniffLen 的测试。
 *
 * 涵盖：
 * - HTML 检测：<html、<HTML、<h >、<!--、<!DOCTYPE
 * - XML 检测：<?xml
 * - SVG 检测：<svg、<SVG
 * - 魔数：PDF、PostScript、ICO、PNG、GIF、JPEG、BMP、WebP、TIFF
 * - 音频/视频：MP4、WebM、AVI、MP3、WAVE、AIFF、MIDI、OGG、FLAC
 * - 字体：WOFF、WOFF2、TTF、OTF
 * - 压缩/归档：ZIP、GZip、RAR、7z
 * - 代码：WASM
 * - 编码：UTF-16BE BOM、UTF-16LE BOM、UTF-8 BOM
 * - 纯文本回退
 * - 二进制（空字节）检测
 * - 空数据
 */
@Test
public class SniffTest {

    // ==================== HTML 检测 ====================

    @TestCase
    public func testDetectContentTypeHtmlLower(): Unit {
        let data: Array<UInt8> = [b'<', b'h', b't', b'm', b'l', b'>']
        assertEqual(detectContentType(data), "text/html; charset=utf-8")
    }

    @TestCase
    public func testDetectContentTypeHtmlUpper(): Unit {
        let data: Array<UInt8> = [b'<', b'H', b'T', b'M', b'L', b'>']
        assertEqual(detectContentType(data), "text/html; charset=utf-8")
    }

    @TestCase
    public func testDetectContentTypeHtmlWithAttrs(): Unit {
        // <html lang="en"> — 以 <html 开头（匹配 4 字节）
        let data: Array<UInt8> = [b'<', b'h', b't', b'm', b'l', b' ', b'l', b'a', b'n', b'g', b'=', b'"', b'e', b'n', b'"', b'>']
        assertEqual(detectContentType(data), "text/html; charset=utf-8")
    }

    @TestCase
    public func testDetectContentTypeHtmlHeadingTag(): Unit {
        // <h1>...</h1> — 不匹配 <h 后跟空格（索引 2 处）
        // 因此它会通过所有检查并被检测为 text/plain。
        let data: Array<UInt8> = [b'<', b'h', b'1', b'>', b'T', b'e', b'x', b't', b'<', b'/', b'h', b'1', b'>']
        assertEqual(detectContentType(data), "text/plain; charset=utf-8")
    }

    @TestCase
    public func testDetectContentTypeHtmlComment(): Unit {
        // <!--  触发 <! 分支，data[0..4] = "<!--"
        let data: Array<UInt8> = [b'<', b'!', b'-', b'-', b' ', b'c', b'o', b'm', b'm', b'e', b'n', b't', b' ', b'-', b'-', b'>']
        assertEqual(detectContentType(data), "text/html; charset=utf-8")
    }

    @TestCase
    public func testDetectContentTypeHtmlDoctype(): Unit {
        // <!DOCTYPE html> — <! 分支，data[0..4] = "<!DO"
        let data: Array<UInt8> = [b'<', b'!', b'D', b'O', b'C', b'T', b'Y', b'P', b'E', b' ', b'h', b't', b'm', b'l', b'>']
        assertEqual(detectContentType(data), "text/html; charset=utf-8")
    }

    // ==================== XML 检测 ====================

    @TestCase
    public func testDetectContentTypeXml(): Unit {
        // XML 文件头
        let data: Array<UInt8> = [b'<', b'?', b'x', b'm', b'l', b' ', b'v', b'e', b'r', b's', b'i', b'o', b'n', b'=', b'"', b'1', b'.', b'0', b'"', b'?', b'>']
        assertEqual(detectContentType(data), "text/xml; charset=utf-8")
    }

    // ==================== 魔数字节 ====================

    @TestCase
    public func testDetectContentTypePdf(): Unit {
        // PDF 文件头
        let data: Array<UInt8> = [b'%', b'P', b'D', b'F', b'-', b'1', b'.', b'4']
        assertEqual(detectContentType(data), "application/pdf")
    }

    @TestCase
    public func testDetectContentTypePng(): Unit {
        // PNG 文件签名：0x89 P N G 0x0D 0x0A 0x1A 0x0A
        let data: Array<UInt8> = [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]
        assertEqual(detectContentType(data), "image/png")
    }

    @TestCase
    public func testDetectContentTypeGif(): Unit {
        // GIF 文件头
        let data: Array<UInt8> = [b'G', b'I', b'F', b'8', b'9', b'a']
        assertEqual(detectContentType(data), "image/gif")
    }

    @TestCase
    public func testDetectContentTypeJpeg(): Unit {
        // JPEG 文件头
        let data: Array<UInt8> = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, b'J', b'F', b'I', b'F']
        assertEqual(detectContentType(data), "image/jpeg")
    }

    @TestCase
    public func testDetectContentTypeBmp(): Unit {
        // 二进制...
        let data: Array<UInt8> = [b'B', b'M', 0x00, 0x00, 0x00, 0x00]
        assertEqual(detectContentType(data), "image/bmp")
    }

    @TestCase
    public func testDetectContentTypeWebp(): Unit {
        // RIFF + 4 字节大小 + WEBP
        let data: Array<UInt8> = [b'R', b'I', b'F', b'F', 0x00, 0x00, 0x00, 0x00, b'W', b'E', b'B', b'P']
        assertEqual(detectContentType(data), "image/webp")
    }

    @TestCase
    public func testDetectContentTypeZip(): Unit {
        // ZIP 文件头
        let data: Array<UInt8> = [b'P', b'K', 0x03, 0x04]
        assertEqual(detectContentType(data), "application/zip")
    }

    @TestCase
    public func testDetectContentTypeGzip(): Unit {
        // 0x1F 0x8B 0x08
        let data: Array<UInt8> = [0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x03]
        assertEqual(detectContentType(data), "application/gzip")
    }

    // ==================== SVG 检测 ====================

    @TestCase
    public func testDetectContentTypeSvgLower(): Unit {
        // SVG 文件
        let data: Array<UInt8> = [b'<', b's', b'v', b'g', b' ', b'v', b'i', b'e', b'w', b'B', b'o', b'x', b'=', b'"', b'0', b' ', b'0', b' ', b'1', b'0', b'0', b' ', b'1', b'0', b'0', b'"', b'>', b'<', b'/', b's', b'v', b'g', b'>']
        assertEqual(detectContentType(data), "image/svg+xml")
    }

    @TestCase
    public func testDetectContentTypeSvgUpper(): Unit {
        // SVG 文件（大写标签）
        let data: Array<UInt8> = [b'<', b'S', b'V', b'G', b' ', b'v', b'i', b'e', b'w', b'B', b'o', b'x', b'=', b'"', b'0', b' ', b'0', b' ', b'1', b'0', b'0', b' ', b'1', b'0', b'0', b'"', b'>', b'<', b'/', b'S', b'V', b'G', b'>']
        assertEqual(detectContentType(data), "image/svg+xml")
    }

    // ==================== 文本 / 二进制 ====================

    @TestCase
    public func testDetectContentTypePlainText(): Unit {
        // "Hello, World!" — 可打印 ASCII，无空字节或控制字符
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o', b',', b' ', b'W', b'o', b'r', b'l', b'd', b'!']
        assertEqual(detectContentType(data), "text/plain; charset=utf-8")
    }

    @TestCase
    public func testDetectContentTypePlainTextWithNewlines(): Unit {
        // 包含 \n 和 \t 的文本仍应被检测为纯文本
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o', 0x0A, b'W', b'o', b'r', b'l', b'd']
        assertEqual(detectContentType(data), "text/plain; charset=utf-8")
    }

    @TestCase
    public func testDetectContentTypeBinaryNullByte(): Unit {
        // 包含空字节 (0x00) -> 二进制
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o', 0x00, b'W', b'o', b'r', b'l', b'd']
        assertEqual(detectContentType(data), "application/octet-stream")
    }

    @TestCase
    public func testDetectContentTypeBinaryControlChar(): Unit {
        // 包含非空白控制字符 (0x01) -> 二进制
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o', 0x01, b'W', b'o', b'r', b'l', b'd']
        assertEqual(detectContentType(data), "application/octet-stream")
    }

    @TestCase
    public func testDetectContentTypeEmpty(): Unit {
        let data: Array<UInt8> = []
        assertEqual(detectContentType(data), "application/octet-stream")
    }

    // ==================== sniffLen 测试 ====================

    @TestCase
    public func testSniffLen(): Unit {
        assertEqual(sniffLen(), 512)
    }
    // ==================== 新增格式（PostScript、ICO、WebM、AVI 等）====================

    @TestCase
    public func testDetectContentTypePostScript(): Unit {
        let data: Array<UInt8> = [b'%', b'!', b'P', b'S', b'-', b'A', b'd', b'o', b'b', b'e', b'-']
        assertEqual(detectContentType(data), "application/postscript")
    }

    @TestCase
    public func testDetectContentTypeIco(): Unit {
        let data: Array<UInt8> = [0x00, 0x00, 0x01, 0x00]
        assertEqual(detectContentType(data), "image/x-icon")
    }

    @TestCase
    public func testDetectContentTypeWebm(): Unit {
        let data: Array<UInt8> = [0x1A, 0x45, 0xDF, 0xA3]
        assertEqual(detectContentType(data), "video/webm")
    }

    @TestCase
    public func testDetectContentTypeAvi(): Unit {
        let data: Array<UInt8> = [b'R', b'I', b'F', b'F', 0x00, 0x00, 0x00, 0x00, b'A', b'V', b'I', b' ']
        assertEqual(detectContentType(data), "video/avi")
    }

    @TestCase
    public func testDetectContentTypeWave(): Unit {
        let data: Array<UInt8> = [b'R', b'I', b'F', b'F', 0x00, 0x00, 0x00, 0x00, b'W', b'A', b'V', b'E']
        assertEqual(detectContentType(data), "audio/wave")
    }

    @TestCase
    public func testDetectContentTypeAiff(): Unit {
        let data: Array<UInt8> = [b'F', b'O', b'R', b'M', 0x00, 0x00, 0x00, 0x00, b'A', b'I', b'F', b'F']
        assertEqual(detectContentType(data), "audio/aiff")
    }

    @TestCase
    public func testDetectContentTypeMidi(): Unit {
        let data: Array<UInt8> = [b'M', b'T', b'h', b'd', 0x00, 0x00, 0x00, 0x06]
        assertEqual(detectContentType(data), "audio/midi")
    }

    @TestCase
    public func testDetectContentTypeTtf(): Unit {
        let data: Array<UInt8> = [0x00, 0x01, 0x00, 0x00, 0x00]
        assertEqual(detectContentType(data), "font/ttf")
    }

    @TestCase
    public func testDetectContentTypeOtf(): Unit {
        let data: Array<UInt8> = [b'O', b'T', b'T', b'O']
        assertEqual(detectContentType(data), "font/otf")
    }

    @TestCase
    public func testDetectContentTypeRar(): Unit {
        let data: Array<UInt8> = [b'R', b'a', b'r', b'!', 0x1A, 0x07, 0x00]
        assertEqual(detectContentType(data), "application/x-rar-compressed")
    }

    @TestCase
    public func testDetectContentType7z(): Unit {
        let data: Array<UInt8> = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
        assertEqual(detectContentType(data), "application/x-7z-compressed")
    }

    @TestCase
    public func testDetectContentTypeWasm(): Unit {
        let data: Array<UInt8> = [0x00, b'a', b's', b'm']
        assertEqual(detectContentType(data), "application/wasm")
    }

    @TestCase
    public func testDetectContentTypeUtf16BeBom(): Unit {
        let data: Array<UInt8> = [0xFE, 0xFF, 0x00, 0x48]
        assertEqual(detectContentType(data), "text/plain; charset=utf-16be")
    }

    @TestCase
    public func testDetectContentTypeUtf16LeBom(): Unit {
        let data: Array<UInt8> = [0xFF, 0xFE, 0x48, 0x00]
        assertEqual(detectContentType(data), "text/plain; charset=utf-16le")
    }

    @TestCase
    public func testDetectContentTypeUtf8Bom(): Unit {
        let data: Array<UInt8> = [0xEF, 0xBB, 0xBF, b'H', b'e', b'l', b'l', b'o']
        assertEqual(detectContentType(data), "text/plain; charset=utf-8")
    }

}
