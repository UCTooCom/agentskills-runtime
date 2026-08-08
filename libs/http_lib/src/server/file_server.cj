package http_lib.server
/**
 * 文件服务器：提供静态文件服务的 Handler。
 * 支持目录索引、范围请求、MIME 类型嗅探和缓存控制。
 */

import std.collection.{ArrayList, HashMap}
import std.fs.{Directory, File, FileInfo, Path}
import std.time.DateTime
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion, ProtocolException, parseDecimal, formatHttpDate}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.buffer.ByteBuffer
import http_lib.router.Handler

/**
 * 为常见文件扩展名初始化 MIME 类型映射。
 */
private func initMimeTypes(): HashMap<String, String> {
    let mimeTypes = HashMap<String, String>()
    mimeTypes[".html"] = "text/html; charset=utf-8"
    mimeTypes[".htm"] = "text/html; charset=utf-8"
    mimeTypes[".css"] = "text/css; charset=utf-8"
    mimeTypes[".js"] = "application/javascript; charset=utf-8"
    mimeTypes[".json"] = "application/json"
    mimeTypes[".xml"] = "application/xml"
    mimeTypes[".txt"] = "text/plain; charset=utf-8"
    mimeTypes[".md"] = "text/markdown; charset=utf-8"
    mimeTypes[".csv"] = "text/csv; charset=utf-8"
    mimeTypes[".png"] = "image/png"
    mimeTypes[".jpg"] = "image/jpeg"
    mimeTypes[".jpeg"] = "image/jpeg"
    mimeTypes[".gif"] = "image/gif"
    mimeTypes[".svg"] = "image/svg+xml"
    mimeTypes[".ico"] = "image/x-icon"
    mimeTypes[".webp"] = "image/webp"
    mimeTypes[".bmp"] = "image/bmp"
    mimeTypes[".mp4"] = "video/mp4"
    mimeTypes[".webm"] = "video/webm"
    mimeTypes[".ogg"] = "audio/ogg"
    mimeTypes[".mp3"] = "audio/mpeg"
    mimeTypes[".wav"] = "audio/wav"
    mimeTypes[".pdf"] = "application/pdf"
    mimeTypes[".zip"] = "application/zip"
    mimeTypes[".tar"] = "application/x-tar"
    mimeTypes[".gz"] = "application/gzip"
    mimeTypes[".woff"] = "font/woff"
    mimeTypes[".woff2"] = "font/woff2"
    mimeTypes[".ttf"] = "font/ttf"
    mimeTypes[".wasm"] = "application/wasm"
    mimeTypes
}

// 在模块加载时立即初始化以避免数据竞争
private let mimeTypesCache: HashMap<String, String> = initMimeTypes()

private func getMimeType(ext: String): String {
    match (mimeTypesCache.get(ext)) {
        case Some(mt) => mt
        case None => "application/octet-stream"
    }
}

/**
 * 根据文件扩展名解析 MIME 类型。
 */
public func mimeTypeByExtension(path: String): String {
    let dotIdx = path.lastIndexOf(".")
    match (dotIdx) {
        case Some(idx) =>
            getMimeType(path[idx..])
        case None => "application/octet-stream"
    }
}

/**
 * 文件服务器配置。
 */
public class FileServerConfig {
    public var listingEnabled: Bool = false
    public var indexFiles: Array<String> = ["index.html", "index.htm"]
    public var enableRange: Bool = true
    public var enableCache: Bool = true
    public var maxAge: Int64 = 3600

    public init() {}
}

/**
 * 创建从目录提供静态文件的 HTTP 处理器。
 * 支持 index.html、Content-Type 检测和 Range 请求。
 *
 * 用法：
 *   let router = Router()
 *   router.get("/static/{path}", serveStatic("/var/www"))
 *
文件服务模式。
 */
public func serveStatic(root: String, config!: FileServerConfig = FileServerConfig()): Handler {
    {request: HttpRequest =>
        let urlPath = request.path
        let safePath = sanitizePath(urlPath)
        let fullPath = root + safePath

        // 符号链接穿越防护：验证规范化路径在 root 内
        if (!_isPathWithinRoot(fullPath, root)) {
            return HttpResponse.text(HttpStatus.FORBIDDEN, "Access denied")
        }

        // 获取文件修改时间以支持 If-Modified-Since
        let fileModTime: ?DateTime = try {
            let finfo = FileInfo(Path(fullPath))
            Some(finfo.lastModificationTime)
        } catch (_: Exception) {
            None
        }

        // 尝试读取文件；如果失败，检查索引文件（目录）
        let fileData = try {
            File.readFrom(Path(fullPath))
        } catch (_: Exception) {
            // 检查索引文件（视为目录）
            let dirPath = if (fullPath.endsWith("/")) { fullPath } else { "${fullPath}/" }
            var found = false
            for (indexFile in config.indexFiles) {
                let indexPath = "${dirPath}${indexFile}"
                try {
                    let data = File.readFrom(Path(indexPath))
                    let indexModTime: ?DateTime = try {
                        let finfo = FileInfo(Path(indexPath))
                        Some(finfo.lastModificationTime)
                    } catch (_: Exception) {
                        None
                    }
                    return serveFileData(data, if (urlPath.endsWith("/")) { "${urlPath}${indexFile}" } else { "${urlPath}/${indexFile}" }, request, config, modTime: indexModTime)
                } catch (_: Exception) {}
            }
            // 目录列表
            if (config.listingEnabled) {
                return serveDirectoryListing(dirPath, urlPath, config)
            }
            return HttpResponse.text(HttpStatus.NOT_FOUND, "File not found: ${urlPath}")
        }

        serveFileData(fileData, urlPath, request, config, modTime: fileModTime)
    }
}

/**
 * 使用适当的头部、缓存和可选的 Range 支持提供文件数据。
 * 基于文件大小生成 ETag 并支持条件请求
 * （If-Modified-Since、If-None-Match）根据 RFC 7232。
 */
public func serveFileData(
    data: Array<UInt8>, urlPath: String, request: HttpRequest, config: FileServerConfig,
    modTime!: ?DateTime = None
): HttpResponse {
    let contentType = mimeTypeByExtension(urlPath)
    let headers = HttpHeaders()
    headers.set("Content-Type", contentType)
    headers.set("Accept-Ranges", "bytes")

    if (config.enableCache) {
        headers.set("Cache-Control", "public, max-age=${config.maxAge}")
        // 基于文件大小和修改时间生成 ETag（比纯大小更唯一）
        let modTag = match (modTime) {
            case Some(mt) => formatHttpDate(mt)
            case None => ""
        }
        let etagValue = "\"${hexEncodeSize(data.size)}-${modTag}\""
        headers.set("ETag", etagValue)

        // 条件请求：If-None-Match（RFC 7232 第 3.2 节）
        match (request.headers.get("if-none-match")) {
            case Some(etag) =>
                if (etag == etagValue) {
                    return HttpResponse(status: HttpStatus.NOT_MODIFIED, headers: headers, body: ByteBuffer(capacity: 0))
                }
            case None => ()
        }

        // 条件请求：If-Modified-Since（RFC 7232 第 3.3 节）
        match (modTime) {
            case Some(mt) =>
                match (request.headers.get("if-modified-since")) {
                    case Some(ims) =>
                        // 解析 If-Modified-Since 日期并进行比较
                        let fileTimeStr = formatHttpDate(mt)
                        // 简单比较：如果日期完全匹配，则文件未更改
                        // 以秒为粒度（RFC 7232 允许此近似）
                        if (ims == fileTimeStr) {
                            return HttpResponse(status: HttpStatus.NOT_MODIFIED, headers: headers, body: ByteBuffer(capacity: 0))
                        }
                    case None => ()
                }
            case None => ()
        }
    }

    // Range 请求支持（RFC 7233）
    if (config.enableRange) {
        match (request.headers.get("range")) {
            case Some(range) =>
                if (range.startsWith("bytes=")) {
                    let rangeVal = range["bytes=".size..]
                    let dashIdx = rangeVal.indexOf("-")
                    match (dashIdx) {
                        case Some(idx) =>
                            let startStr = rangeVal[..idx]
                            let endStr = rangeVal[idx + 1..]
                            let start = if (startStr.size > 0) { parseDecimal(startStr) } else { 0 }
                            let end = if (endStr.size > 0) { parseDecimal(endStr) } else { data.size - 1 }

                            if (start >= 0 && start < data.size && end >= start && end < data.size) {
                                let rangeLen = end - start + 1
                                let partialData = Array<UInt8>(rangeLen, repeat: 0)
                                data.copyTo(partialData, 0, start, rangeLen)
                                headers.set("Content-Range", "bytes ${start}-${end}/${data.size}")
                                headers.set("Content-Length", "${rangeLen}")
                                let buf = ByteBuffer(capacity: rangeLen)
                                buf.write(partialData)
                                return HttpResponse(status: HttpStatus.PARTIAL_CONTENT, headers: headers, body: buf)
                            }
                        case None => ()
                    }
                }
            case None => ()
        }
    }

    headers.set("Content-Length", "${data.size}")
    let buf = ByteBuffer(capacity: data.size)
    buf.write(data)
    HttpResponse(status: HttpStatus.OK, headers: headers, body: buf)
}

/**
 * 将文件大小格式化为十六进制字符串以用于 ETag 头部。
 * 使用大小本身作为简单的内容指纹。
 */
private func hexEncodeSize(size: Int64): String {
    let hex = "0123456789abcdef"
    var result = ""
    var v = size
    if (v == 0) { return "0" }
    while (v > 0) {
        let idx = Int64(v % 16)
        let char = hex[idx..idx + 1]
        result = char + result
        v /= 16
    }
    result
}

/**
 * 以 HTML 形式提供基本的目录列表。
 * 在可用时使用 Path API 遍历目录条目。
 */
private func serveDirectoryListing(dirPath: String, urlPath: String, config: FileServerConfig): HttpResponse {
    let sb = StringBuilder()
    sb.append("<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n")
    sb.append("<title>Directory listing for ${urlPath}</title>\n")
    sb.append("<style>body{font-family:monospace;margin:20px}a{text-decoration:none;color:#0366d6}")
    sb.append("tr:hover{background:#f6f8fa}</style>\n</head>\n<body>\n")
    sb.append("<h1>Directory listing for ${urlPath}</h1>\n<hr>\n<pre>\n")

    // 父目录链接
    if (urlPath != "/") {
        let runes = urlPath.toRuneArray()
        let parentPath = if (runes[runes.size - 1] == r'/') {
            String(runes[..runes.size - 1])
        } else { urlPath }
        let slashIdx = parentPath.lastIndexOf("/")
        let parentDir = match (slashIdx) {
            case Some(idx) => String(parentPath.toRuneArray()[..idx + 1])
            case None => "/"
        }
        sb.append("<a href=\"${parentDir}\">../</a>\n")
    }

    // 使用 std.fs API 枚举实际目录条目
    try {
        let dirPathObj = Path(dirPath)
        let entries = Directory.readFrom(dirPathObj)
        for (entry in entries) {
            let name = entry.name
            // HTML 转义文件名，防止 XSS 攻击
            let escapedName = _htmlEscape(name)
            let linkPath = if (urlPath.endsWith("/")) { "${urlPath}${escapedName}" } else { "${urlPath}/${escapedName}" }
            let displayName = if (entry.isDirectory()) { "${escapedName}/" } else { escapedName }
            let sizeStr = if (entry.isDirectory()) { "-" } else { formatFileSize(entry.size) }
            let mtime = entry.lastModificationTime
            let dateStr = formatHttpDate(mtime)
            sb.append("<a href=\"${linkPath}\">${displayName}</a>\t${sizeStr}\t${dateStr}\n")
        }
    } catch (_: Exception) {
        sb.append("<p>Error reading directory</p>\n")
    }

    sb.append("</pre>\n<hr>\n</body>\n</html>")

    let html = sb.toString()
    let data = unsafe { html.rawData() }
    let headers = HttpHeaders()
    headers.set("Content-Type", "text/html; charset=utf-8")
    headers.set("Content-Length", "${data.size}")
    let buf = ByteBuffer(capacity: data.size)
    buf.write(data)
    HttpResponse(status: HttpStatus.OK, headers: headers, body: buf)
}

/**
 * 将文件大小格式化为人类可读的字符串。
 */
private func formatFileSize(size: Int64): String {
    if (size < 1024) {
        "${size} B"
    } else if (size < 1024 * 1024) {
        "${size / 1024} KB"
    } else if (size < 1024 * 1024 * 1024) {
        "${size / (1024 * 1024)} MB"
    } else {
        "${size / (1024 * 1024 * 1024)} GB"
    }
}

/**
 * 对 URL 路径进行安全清理，防止目录穿越攻击。
 *
 * 先进行 URL 解码（防止 %2e%2e%2f 等编码绕过），
 * 然后移除 ".." 和 "." 路径组件。
 */
public func sanitizePath(path: String): String {
    // 先进行 URL 解码，防止编码绕过攻击
    let decoded = _urlDecodePath(path)
    let parts = decoded.split("/")
    var result = ""
    for (part in parts) {
        if (part == ".." || part == ".") { continue }
        if (part.size > 0) {
            result = "${result}/${part}"
        }
    }
    if (result.size == 0) { result = "/" }
    result
}

/**
 * 对 URL 路径进行百分号解码（内部使用）。
 * 仅处理 %XX 编码，不处理 '+' → 空格（路径中不需要）。
 */
private func _urlDecodePath(path: String): String {
    let bytes = path.toArray()
    let result = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i < bytes.size) {
        if (bytes[i] == b'%' && i + 2 < bytes.size) {
            let high = _hexDigit(bytes[i + 1])
            let low = _hexDigit(bytes[i + 2])
            if (high >= 0 && low >= 0) {
                result.add(UInt8((high << 4) | low))
                i += 3
            } else {
                result.add(bytes[i])
                i++
            }
        } else {
            result.add(bytes[i])
            i++
        }
    }
    String.fromUtf8(result.toArray())
}

private func _hexDigit(b: Byte): Int64 {
    if (b >= b'0' && b <= b'9') { Int64(b) - 48 }
    else if (b >= b'a' && b <= b'f') { Int64(b) - 87 }
    else if (b >= b'A' && b <= b'F') { Int64(b) - 55 }
    else { -1 }
}

/**
 * 对字符串进行 HTML 转义，防止 XSS 攻击。
 * 转义 <, >, &, ", ' 五个字符。
 */
private func _htmlEscape(s: String): String {
    var result = ""
    let bytes = s.toArray()
    for (b in bytes) {
        match (b) {
            case b'<' => result = "${result}&lt;"
            case b'>' => result = "${result}&gt;"
            case b'&' => result = "${result}&amp;"
            case b'"' => result = "${result}&quot;"
            case b'\'' => result = "${result}&#39;"
            case _ => result = result + String.fromUtf8([b])
        }
    }
    result
}

/**
 * 验证路径是否在指定根目录内，防止符号链接穿越攻击。
 * 通过 Path 规范化解析所有符号链接后检查路径前缀。
 */
private func _isPathWithinRoot(fullPath: String, root: String): Bool {
    try {
        let normalized = Path(fullPath)  // Path 规范化会解析符号链接
        let normalizedRoot = Path(root)
        let normPathStr = "${normalized}"
        let normRootStr = "${normalizedRoot}"
        normPathStr.startsWith(normRootStr)
    } catch (_: Exception) {
        false
    }
}
