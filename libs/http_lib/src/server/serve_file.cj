package http_lib.server
/**
 * 文件服务核心：文件读取、范围请求处理和 Content-Type 确定。
 */

/**
 * 静态文件服务工具函数。
 * 提供文件内容读取和 HTTP 响应构造，
 * 支持 Content-Type 自动检测、目录索引文件（index.html）、
 * Range 请求（断点续传）。
 */

import std.fs.{File, Path}
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Handler

/**
 * 将单个文件作为 HTTP 响应返回。
 * ServeFile。
 *
 * 根据文件扩展名和 Content-Length 设置 Content-Type。
 *
 * 用法：
 *   router.get("/files/{path}", serveFile("/var/www"))
 * // 或独立使用：
 *   let resp = serveFileContent("hello.txt", unsafe { "Hello".rawData() })
 */
public func serveFile(root: String): Handler {
    {req: HttpRequest =>
        let urlPath = req.path
        let safePath = sanitizePath(urlPath)
        let fullPath = root + safePath
        try {
            let data = File.readFrom(Path(fullPath))
            let config = FileServerConfig()
            serveFileData(data, safePath, req, config)
        } catch (_: Exception) {
            HttpResponse.text(HttpStatus.NOT_FOUND, "File not found: ${urlPath}")
        }
    }
}

/**
 * 以 Content-Disposition 文件下载方式提供原始字节。
 */
public func serveFileDownload(data: Array<UInt8>, filename: String, contentType!: String = "application/octet-stream"): HttpResponse {
    let headers = HttpHeaders()
    headers.set("Content-Type", contentType)
    headers.set("Content-Length", "${data.size}")
    headers.set("Content-Disposition", "attachment; filename=\"${filename}\"")
    let body = ByteBuffer(capacity: data.size)
    body.write(data)
    HttpResponse(status: HttpStatus.OK, headers: headers, body: body)
}


