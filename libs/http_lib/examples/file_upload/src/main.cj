package sample_file_upload

import std.collection.{HashMap, ArrayList}
import std.fs.*
import http_lib.core.*
import http_lib.message.*
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig, loggingMiddleware}

/**
 * 演示 multipart/form-data 处理的文件上传服务器。
 *
 * 功能：
 * - 通过 multipart/form-data 上传文件
 * - 上传进度信息
 * - HTML 上传表单
 * - 列出已上传文件
 */

var uploadedFiles = ArrayList<HashMap<String, String>>()

func serveUploadForm(req: HttpRequest): HttpResponse {
    var html = "<!DOCTYPE html><html><head><title>File Upload</title><style>body{font-family:sans-serif;max-width:600px;margin:50px auto;padding:20px}h1{color:#333}form{border:2px dashed #ccc;padding:30px;border-radius:8px}input[type=file]{margin:10px 0}input[type=submit]{background:#007bff;color:#fff;border:none;padding:10px 20px;border-radius:4px;cursor:pointer}ul{list-style:none;padding:0}li{padding:10px;border-bottom:1px solid #eee}</style></head><body><h1>📁 File Upload</h1><form method='POST' action='/upload' enctype='multipart/form-data'><input type='file' name='file' required><br><input type='text' name='description' placeholder='Description (optional)'><br><input type='submit' value='Upload'></form><h2>Uploaded Files</h2><ul>"

    for (file in uploadedFiles) {
        let name = match (file.get("name")) { case Some(n) => n case None => "unknown" }
        let size = match (file.get("size")) { case Some(s) => s case None => "0" }
        let desc = match (file.get("description")) { case Some(d) => d case None => "" }
        html += "<li><strong>${name}</strong> (${size} bytes)"
        if (desc.size > 0) { html += " — ${desc}" }
        html += "</li>"
    }

    html += "</ul></body></html>"
    HttpResponse.html(HttpStatus.OK, html)
}

func handleUpload(req: HttpRequest): HttpResponse {
    let fields = parseMultipartBody(req)

    match (fields.get("file")) {
        case Some(fileField) =>
            let fileInfo = HashMap<String, String>()
            fileInfo["name"] = fileField.fileName
            fileInfo["size"] = "${fileField.data.size}"
            fileInfo["type"] = match (fileField.headers.get("content-type")) {
                case Some(ct) => ct
                case None => "application/octet-stream"
            }
            match (fields.get("description")) {
                case Some(descField) =>
                    fileInfo["description"] = descField.asString()
                case None => ()
            }
            uploadedFiles.add(fileInfo)

            // 将文件保存到磁盘
            try {
                let outputPath = Path("./uploads/${fileField.fileName}")
                File.writeTo(outputPath, fileField.data)
                println("[Upload] Saved ${fileField.fileName} (${fileField.data.size} bytes) to ${outputPath}")
            } catch (e: Exception) {
                println("[Upload] Failed to save file: ${e.message}")
            }

            HttpResponse.json(HttpStatus.OK,
                "{\"status\":\"ok\",\"filename\":\"${fileField.fileName}\",\"size\":${fileField.data.size}}")
        case None =>
            HttpResponse.json(HttpStatus.BAD_REQUEST,
                "{\"status\":\"error\",\"message\":\"No file uploaded\"}")
    }
}

func handleStatus(req: HttpRequest): HttpResponse {
    var json = "{\"totalFiles\":${uploadedFiles.size},\"files\":["
    var first = true
    for (file in uploadedFiles) {
        if (first) { first = false } else { json += "," }
        let name = match (file.get("name")) { case Some(n) => n case None => "unknown" }
        let size = match (file.get("size")) { case Some(s) => s case None => "0" }
        json += "{\"name\":\"${name}\",\"size\":${size}}"
    }
    json += "]}"
    HttpResponse.json(HttpStatus.OK, json)
}

main(): Int64 {
    let router = Router()
        .get("/", serveUploadForm)
        .post("/upload", handleUpload)
        .get("/status", handleStatus)

    let handler = router.handler()

    let serverConfig = HttpServerConfig()
    serverConfig.maxBodySize = 104857600  // 100 MB for uploads
    serverConfig.readTimeout = Duration.second * 120
    serverConfig.writeTimeout = Duration.second * 120
    serverConfig.keepAlive = true

    let server = HttpServer(handler: router.handler(), config: serverConfig)

    println("========================================")
    println("  File Upload Server")
    println("  Listening on: http://127.0.0.1:8081")
    println("")
    println("  Open http://127.0.0.1:8081/ in a browser")
    println("  Upload limit: 100 MB")
    println("========================================")

    server.listenAndServe("127.0.0.1", 8081)
    0
}
