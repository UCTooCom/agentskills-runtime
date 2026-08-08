package sample_file_server

import http_lib.server.{HttpServer, HttpServerConfig, FileServerConfig, serveStatic}
import http_lib.router.Router
import http_lib.core.HttpStatus
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * 静态文件服务器示例。
 *
 * 演示 FileServer 功能：
 * - 从本地目录提供静态文件
 * - 通过文件扩展名自动检测 Content-Type
 * - 支持 Range 请求（部分内容）
 * - 对目录回退到 index.html
 *
 * 用法：
 * cjpm run
 * # 打开 http://localhost:8080/index.html
 */
main(): Int64 {
    println("=== Static File Server Demo ===")
    println("")

    let router = Router()

    // 从 "./www" 目录提供静态文件
    // 文件可通过 /static/ 访问
    // 支持：MIME 类型检测、Range 请求、缓存
    let fileConfig = FileServerConfig()
    fileConfig.enableCache = true
    fileConfig.maxAge = 7200  // 2 hours

    // 从根目录提供静态文件（/{path} 为通配路由，覆盖所有路径）
    router.get("/{path}", serveStatic("./www", config: fileConfig))

    // 根目录的回退
    router.get("/", {req =>
        HttpResponse.redirect("/index.html")
    })

    println("Starting file server on http://localhost:8080...")
    println("  /index.html  - Main page")
    println("  /static/css/ - CSS files")
    println("  /static/js/  - JavaScript files")
    println("  /images/     - Image files")
    println("")
    println("Create a 'www' directory with your static files to serve them.")
    println("")

    let config = HttpServerConfig()
    let server = HttpServer(handler: router.handler(), config: config)
    server.listenAndServe("0.0.0.0", 8080)

    0
}
