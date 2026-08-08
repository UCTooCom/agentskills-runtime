package http_lib.server
/**
 * 静态内容服务辅助函数：从字符串/字节提供内存中内容服务。
 */

import std.time.DateTime
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, formatHttpDate}
import http_lib.message.{
    HttpRequest, HttpResponse, ByteRange,
    parseRange, extractRange, buildContentRange, buildMultipartRanges,
    generateETag,
    httpDatesEqual, httpDateLessOrEqual, httpDateGreater
}

/**
 * ServeContent 将内容字节作为 HTTP 响应提供，支持：
 *
 * - Content-Type 和 Content-Length 头
 * - Accept-Ranges: bytes 用于范围请求（RFC 7233）
 * - 从内容字节生成 ETag
 * - Last-Modified 头（当提供 modTime 时）
 * - 条件请求评估（If-Match、If-None-Match 等，RFC 7232）):
 * - If-Match / If-Unmodified-Since → 412 前置条件失败
 *   - If-None-Match → 304 Not Modified（GET/HEAD）或 412（其他）
 *   - If-Modified-Since → 304 Not Modified（仅 GET/HEAD）
 * - 单个和多个字节范围服务：
 *   - 有效范围 → 206 Partial Content 带 Content-Range
 *   - 多个范围 → 206 Partial Content 带 multipart/byteranges
 *   - 超出范围（非空内容）→ 416 Range Not Satisfiable
 * - If-Range 头：实体标签或修改时间变化时跳过 Range
 * - HEAD 方法：仅返回头部，无主体
 *
 * ServeContent 模式。
 *
 * @param data        要服务的原始内容字节（可为空）
 * @param request     The incoming HTTP 请求
 * @param contentType Content-Type 头的值
 * @param modTime     可选修改时间；提供后设置
 *                    Last-Modified 并启用 If-Modified-Since /
 *                    If-Unmodified-Since / If-Range（日期）评估
 * @return 带适当状态码、头部和主体的 HttpResponse
 *
 * 用法：
 *   let resp = serveContent(fileBytes, request, "text/plain; charset=utf-8",
 * modTime: Some(fileModTime))
 */
public func serveContent(
    data: Array<UInt8>,
    request: HttpRequest,
    contentType: String,
    modTime!: ?DateTime = None
): HttpResponse {
    let totalSize = data.size
    let headers = HttpHeaders()

    // ---- 强制头部 ----
    headers.set("Content-Type", contentType)
    headers.set("Accept-Ranges", "bytes")

    // ---- ETag（强，基于内容哈希） ----
    let etag = generateETag(data)
    headers.set("ETag", etag)

    // ---- 最后修改时间 ----
    let lastModified: ?String = match (modTime) {
        case Some(dt) =>
            let lm = formatHttpDate(dt)
            headers.set("Last-Modified", lm)
            Some(lm)
        case None =>
            None
    }

    // ============================================================
    // 前置条件评估 — RFC 7232 第 6 节
    // ============================================================

    // 1. If-Match（第 3.1 节）：所有当前 ETag 必须匹配
    // 如果任何指定的 ETag 不匹配 → 412 Precondition Failed
    match (request.headers.get("if-match")) {
        case Some(im) =>
            var matched = im == "*"
            if (!matched) {
                matched = im == etag
            }
            if (!matched) {
                return HttpResponse(status: HttpStatus.PRECONDITION_FAILED, headers: headers)
            }
        case None => ()
    }

    // 2. If-Unmodified-Since（第 3.4 节）：
    // 资源自给定日期以来不得被修改
    match (lastModified) {
        case Some(lm) =>
            match (request.headers.get("if-unmodified-since")) {
                case Some(ius) =>
                    // 如果资源在头部日期之后被修改 → 412
                    if (httpDateGreater(lm, ius)) {
                        return HttpResponse(status: HttpStatus.PRECONDITION_FAILED, headers: headers)
                    }
                case None => ()
            }
        case None => ()
    }

    // 3. If-None-Match（第 3.2 节）：
    // ETag 不得匹配；GET/HEAD → 304，其他方法 → 412
    let methodIsGetOrHead = request.method == HttpMethod.GET ||
                            request.method == HttpMethod.HEAD

    match (request.headers.get("if-none-match")) {
        case Some(inm) =>
            var noneMatch = inm == "*"
            if (!noneMatch) {
                noneMatch = inm == etag
            }
            if (noneMatch) {
                if (methodIsGetOrHead) {
                    // RFC 7232 第 4.1 节：在 304 时去掉与主体相关的头部
                    headers.remove("Content-Type")
                    headers.remove("Content-Length")
                    headers.remove("Content-Encoding")
                    return HttpResponse(status: HttpStatus.NOT_MODIFIED, headers: headers)
                }
                return HttpResponse(status: HttpStatus.PRECONDITION_FAILED, headers: headers)
            }
        case None =>
            // 4. If-Modified-Since（第 3.3 节）：
            // 仅当 If-None-Match 不存在时评估（第 6 节步骤 3），
            // 且仅对 GET/HEAD 有意义
            if (methodIsGetOrHead) {
                match (lastModified) {
                    case Some(lm) =>
                        match (request.headers.get("if-modified-since")) {
                            case Some(ims) =>
                                // 如果资源自那以后未被修改 → 304
                                if (httpDateLessOrEqual(lm, ims)) {
                                    headers.remove("Content-Type")
                                    headers.remove("Content-Length")
                                    headers.remove("Content-Encoding")
                                    return HttpResponse(status: HttpStatus.NOT_MODIFIED, headers: headers)
                                }
                            case None => ()
                        }
                    case None => ()
                }
            }
    }

    // ============================================================
    // 范围请求处理 — RFC 7233
    // ============================================================

    // 5. If-Range（RFC 7233 第 3.2 节）：
    // 如果存在且实体已变更，忽略 Range 头部
    // 并以 200 OK 发送完整实体。
    var rangeSpec: ?String = None
    match (request.headers.get("range")) {
        case Some(r) =>
            var processRange = true
            match (request.headers.get("if-range")) {
                case Some(ir) =>
                    if (ir.startsWith("\"") || ir.startsWith("W/\"")) {
                        // ETag 比较（根据 RFC 7233 第 3.2 节的强匹配）
                        processRange = ir == etag
                    } else {
                        // HTTP-date 比较
                        match (lastModified) {
                            case Some(lm) =>
                                processRange = httpDatesEqual(ir, lm)
                            case None =>
                                processRange = false  // 没有可比较的修改时间
                        }
                    }
                case None => ()
            }
            if (processRange) {
                rangeSpec = Some(r)
            }
        case None => ()
    }

    // 6. 解析并提供范围
    match (rangeSpec) {
        case Some(rh) =>
            let ranges = parseRange(rh, totalSize)
            if (ranges.size == 0) {
                // 无有效范围。对于非空内容，范围不
                // 与资源重叠 → 416 Range Not Satisfiable。
                // 对于空内容，忽略 Range 并服务完整
                // 以 200 OK 的空表示。
                if (totalSize > 0) {
                    headers.set("Content-Range", "bytes */${totalSize}")
                    return HttpResponse(status: HttpStatus.RANGE_NOT_SATISFIABLE, headers: headers)
                }
                // 空内容回退到 200 OK
            } else if (ranges.size == 1) {
                // 单字节范围 — RFC 7233 第 4.1 节
                // 必须发送 Content-Range，不得发送 multipart
                let range = ranges[0]
                let partialData = extractRange(data, range)
                let contentRange = buildContentRange(range, totalSize)
                headers.set("Content-Range", contentRange)
                headers.set("Content-Length", "${partialData.size}")
                return respondWithBody(
                    HttpStatus.PARTIAL_CONTENT, headers,
                    partialData, request.method == HttpMethod.HEAD
                )
            } else {
                // 多字节范围 — multipart/byteranges
                let multipartData = buildMultipartRanges(data, ranges, contentType, totalSize)
                let boundary = "stdHttpLibRange"
                headers.set("Content-Type", "multipart/byteranges; boundary=${boundary}")
                headers.set("Content-Length", "${multipartData.size}")
                return respondWithBody(
                    HttpStatus.PARTIAL_CONTENT, headers,
                    multipartData, request.method == HttpMethod.HEAD
                )
            }
        case None => ()
    }

    // ---- 完整内容响应（200 OK） ----
    headers.set("Content-Length", "${totalSize}")
    respondWithBody(HttpStatus.OK, headers, data, request.method == HttpMethod.HEAD)
}

/**
 * 构建最终的 HttpResponse，为 HEAD 请求提供空主体
 * 并为所有其他方法提供给定的主体字节。
 */
private func respondWithBody(
    status: HttpStatus,
    headers: HttpHeaders,
    bodyData: Array<UInt8>,
    isHead: Bool
): HttpResponse {
    if (isHead) {
        HttpResponse(status: status, headers: headers)
    } else {
        let buf = ByteBuffer(capacity: bodyData.size)
        buf.write(bodyData)
        HttpResponse(status: status, headers: headers, body: buf)
    }
}
