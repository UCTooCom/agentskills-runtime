package http_lib.server

import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Handler

@Test
public class FileServerTest {

    // ---- mimeTypeByExtension 测试 ----

    @TestCase
    public func testMimeTypeByExtensionHtml(): Unit {
        let mime = mimeTypeByExtension("index.html")
        assertTrue(mime == "text/html; charset=utf-8",
            message: "HTML should be text/html")
    }

    @TestCase
    public func testMimeTypeByExtensionJson(): Unit {
        let mime = mimeTypeByExtension("data.json")
        assertTrue(mime == "application/json",
            message: "JSON should be application/json")
    }

    @TestCase
    public func testMimeTypeByExtensionCss(): Unit {
        let mime = mimeTypeByExtension("style.css")
        assertTrue(mime == "text/css; charset=utf-8",
            message: "CSS should be text/css")
    }

    @TestCase
    public func testMimeTypeByExtensionJs(): Unit {
        let mime = mimeTypeByExtension("app.js")
        assertTrue(mime == "application/javascript; charset=utf-8",
            message: "JS should be application/javascript")
    }

    @TestCase
    public func testMimeTypeByExtensionPng(): Unit {
        let mime = mimeTypeByExtension("image.png")
        assertTrue(mime == "image/png", message: "PNG should be image/png")
    }

    @TestCase
    public func testMimeTypeByExtensionJpg(): Unit {
        let mime = mimeTypeByExtension("photo.jpg")
        assertTrue(mime == "image/jpeg", message: "JPG should be image/jpeg")
    }

    @TestCase
    public func testMimeTypeByExtensionJpeg(): Unit {
        let mime = mimeTypeByExtension("photo.jpeg")
        assertTrue(mime == "image/jpeg", message: "JPEG should be image/jpeg")
    }

    @TestCase
    public func testMimeTypeByExtensionGif(): Unit {
        let mime = mimeTypeByExtension("anim.gif")
        assertTrue(mime == "image/gif", message: "GIF should be image/gif")
    }

    @TestCase
    public func testMimeTypeByExtensionSvg(): Unit {
        let mime = mimeTypeByExtension("icon.svg")
        assertTrue(mime == "image/svg+xml", message: "SVG should be image/svg+xml")
    }

    @TestCase
    public func testMimeTypeByExtensionIco(): Unit {
        let mime = mimeTypeByExtension("favicon.ico")
        assertTrue(mime == "image/x-icon", message: "ICO should be image/x-icon")
    }

    @TestCase
    public func testMimeTypeByExtensionWebp(): Unit {
        let mime = mimeTypeByExtension("image.webp")
        assertTrue(mime == "image/webp", message: "WebP should be image/webp")
    }

    @TestCase
    public func testMimeTypeByExtensionBmp(): Unit {
        let mime = mimeTypeByExtension("image.bmp")
        assertTrue(mime == "image/bmp", message: "BMP should be image/bmp")
    }

    @TestCase
    public func testMimeTypeByExtensionMp4(): Unit {
        let mime = mimeTypeByExtension("video.mp4")
        assertTrue(mime == "video/mp4", message: "MP4 should be video/mp4")
    }

    @TestCase
    public func testMimeTypeByExtensionWebm(): Unit {
        let mime = mimeTypeByExtension("video.webm")
        assertTrue(mime == "video/webm", message: "WebM should be video/webm")
    }

    @TestCase
    public func testMimeTypeByExtensionMp3(): Unit {
        let mime = mimeTypeByExtension("audio.mp3")
        assertTrue(mime == "audio/mpeg", message: "MP3 should be audio/mpeg")
    }

    @TestCase
    public func testMimeTypeByExtensionOgg(): Unit {
        let mime = mimeTypeByExtension("audio.ogg")
        assertTrue(mime == "audio/ogg", message: "OGG should be audio/ogg")
    }

    @TestCase
    public func testMimeTypeByExtensionWav(): Unit {
        let mime = mimeTypeByExtension("audio.wav")
        assertTrue(mime == "audio/wav", message: "WAV should be audio/wav")
    }

    @TestCase
    public func testMimeTypeByExtensionPdf(): Unit {
        let mime = mimeTypeByExtension("doc.pdf")
        assertTrue(mime == "application/pdf", message: "PDF should be application/pdf")
    }

    @TestCase
    public func testMimeTypeByExtensionZip(): Unit {
        let mime = mimeTypeByExtension("archive.zip")
        assertTrue(mime == "application/zip", message: "ZIP should be application/zip")
    }

    @TestCase
    public func testMimeTypeByExtensionTar(): Unit {
        let mime = mimeTypeByExtension("archive.tar")
        assertTrue(mime == "application/x-tar", message: "TAR should be application/x-tar")
    }

    @TestCase
    public func testMimeTypeByExtensionGz(): Unit {
        let mime = mimeTypeByExtension("archive.tar.gz")
        assertTrue(mime == "application/gzip", message: "GZ should be application/gzip")
    }

    @TestCase
    public func testMimeTypeByExtensionWoff(): Unit {
        let mime = mimeTypeByExtension("font.woff")
        assertTrue(mime == "font/woff", message: "WOFF should be font/woff")
    }

    @TestCase
    public func testMimeTypeByExtensionWoff2(): Unit {
        let mime = mimeTypeByExtension("font.woff2")
        assertTrue(mime == "font/woff2", message: "WOFF2 should be font/woff2")
    }

    @TestCase
    public func testMimeTypeByExtensionTtf(): Unit {
        let mime = mimeTypeByExtension("font.ttf")
        assertTrue(mime == "font/ttf", message: "TTF should be font/ttf")
    }

    @TestCase
    public func testMimeTypeByExtensionWasm(): Unit {
        let mime = mimeTypeByExtension("module.wasm")
        assertTrue(mime == "application/wasm", message: "WASM should be application/wasm")
    }

    @TestCase
    public func testMimeTypeByExtensionXml(): Unit {
        let mime = mimeTypeByExtension("data.xml")
        assertTrue(mime == "application/xml", message: "XML should be application/xml")
    }

    @TestCase
    public func testMimeTypeByExtensionTxt(): Unit {
        let mime = mimeTypeByExtension("readme.txt")
        assertTrue(mime == "text/plain; charset=utf-8", message: "TXT should be text/plain")
    }

    @TestCase
    public func testMimeTypeByExtensionMd(): Unit {
        let mime = mimeTypeByExtension("readme.md")
        assertTrue(mime == "text/markdown; charset=utf-8", message: "MD should be text/markdown")
    }

    @TestCase
    public func testMimeTypeByExtensionCsv(): Unit {
        let mime = mimeTypeByExtension("data.csv")
        assertTrue(mime == "text/csv; charset=utf-8", message: "CSV should be text/csv")
    }

    @TestCase
    public func testMimeTypeByExtensionHtm(): Unit {
        let mime = mimeTypeByExtension("index.htm")
        assertTrue(mime == "text/html; charset=utf-8", message: "HTM should be text/html")
    }

    @TestCase
    public func testMimeTypeByExtensionUnknown(): Unit {
        let mime = mimeTypeByExtension("file.xyz")
        assertTrue(mime == "application/octet-stream",
            message: "Unknown extension should be octet-stream")
    }

    @TestCase
    public func testMimeTypeByExtensionNoExtension(): Unit {
        let mime = mimeTypeByExtension("README")
        assertTrue(mime == "application/octet-stream",
            message: "No extension should be octet-stream")
    }

    @TestCase
    public func testMimeTypeByExtensionFullPath(): Unit {
        let mime = mimeTypeByExtension("/var/www/images/photo.jpg")
        assertTrue(mime == "image/jpeg", message: "Full path should resolve extension")
    }

    @TestCase
    public func testMimeTypeByExtensionDotfileWithSlash(): Unit {
        let mime = mimeTypeByExtension("/var/www/.hidden/config")
        assertTrue(mime == "application/octet-stream",
            message: "Dotfile path with no extension should be octet-stream")
    }

    @TestCase
    public func testMimeTypeByExtensionMultipleDots(): Unit {
        let mime = mimeTypeByExtension("archive.tar.gz")
        assertTrue(mime == "application/gzip",
            message: "Multiple dots should use last extension")
    }

    // ---- FileServerConfig 测试 ----

    @TestCase
    public func testFileServerConfigDefaults(): Unit {
        let config = FileServerConfig()
        assertFalse(config.listingEnabled, message: "listingEnabled should default to false")
        assertTrue(config.indexFiles.size >= 1, message: "Should have at least one index file")
        assertTrue(config.enableRange, message: "enableRange should default to true")
        assertTrue(config.enableCache, message: "enableCache should default to true")
        assertTrue(config.maxAge == 3600, message: "maxAge should default to 3600")
    }

    @TestCase
    public func testFileServerConfigCustomMaxAge(): Unit {
        let config = FileServerConfig()
        config.maxAge = 7200
        assertTrue(config.maxAge == 7200, message: "maxAge should be settable")
    }

    @TestCase
    public func testFileServerConfigDisableCache(): Unit {
        let config = FileServerConfig()
        config.enableCache = false
        assertFalse(config.enableCache, message: "cache should be disableable")
    }

    @TestCase
    public func testFileServerConfigDisableRange(): Unit {
        let config = FileServerConfig()
        config.enableRange = false
        assertFalse(config.enableRange, message: "range should be disableable")
    }

    @TestCase
    public func testFileServerConfigCustomIndexFiles(): Unit {
        let config = FileServerConfig()
        config.indexFiles = ["default.html"]
        assertTrue(config.indexFiles.size == 1 && config.indexFiles[0] == "default.html",
            message: "index files should be configurable")
    }

    @TestCase
    public func testFileServerConfigListingEnabled(): Unit {
        let config = FileServerConfig()
        config.listingEnabled = true
        assertTrue(config.listingEnabled, message: "listingEnabled should be settable")
    }

    // ---- serveStatic 测试 ----

    @TestCase
    public func testServeStaticFileNotFound(): Unit {
        let handler = serveStatic("/tmp/nonexistent_http_lib")
        let req = HttpRequest(method: HttpMethod.GET, url: "/missing.html")
        let resp = handler(req)
        assertTrue(resp.status.code == 404,
            message: "Non-existent file should return 404")
    }

    @TestCase
    public func testServeStaticEmptyRoot(): Unit {
        let handler = serveStatic("")
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = handler(req)
        assertTrue(resp.status.code == 404,
            message: "Empty root should return 404")
    }

    @TestCase
    public func testSanitizePathPreventsTraversal(): Unit {
        let handler = serveStatic("/tmp")
        let req = HttpRequest(method: HttpMethod.GET, url: "/../../../etc/passwd")
        let resp = handler(req)
        // 不应返回文件内容；应为 404 或安全
        assertTrue(resp.status.code == 404,
            message: "Path traversal should be blocked")
    }

    @TestCase
    public func testServeStaticWithCustomConfig(): Unit {
        let config = FileServerConfig()
        config.enableCache = false
        config.enableRange = false
        let handler = serveStatic("/tmp/nonexistent_dir", config: config)
        let req = HttpRequest(method: HttpMethod.GET, url: "/test.txt")
        let resp = handler(req)
        assertTrue(resp.status.code == 404,
            message: "serveStatic with custom config should handle 404")
    }
}
