package uc_installer.util

import stdx.encoding.json.{JsonValue, JsonObject}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.HttpStatus

/// 统一的 HTTP JSON 信封：{ code, message, data }。
///
/// 说明：本模块从 `uc_installer.http` 迁至 `uc_installer.util`，
/// 以避免 handler 子包反向依赖 `uc_installer.http`（循环依赖拒绝构建）。
/// json 小工具（jstr/jint/...）同属本包，直接复用，无需再 import。
///
/// `data` 为位置参数（仓颉不支持默认参数，调用方始终需显式传值，如 `jsonOk("msg", jobj())`）。
/// json 小工具 jstr/jint/... 同属本包，直接复用，无需再 import。
public func envelope(code: Int64, message: String, data: JsonValue): String {
    let o = jobj()
    o.put("code", jint(code))
    o.put("message", jstr(message))
    o.put("data", data)
    return o.toJsonString()
}

/// 成功信封（HTTP 200，业务 code 默认 200）。
public func jsonOk(message: String, data: JsonValue): HttpResponse {
    HttpResponse.json(HttpStatus.OK, envelope(200, message, data))
}

/// 成功信封（显式业务 code，仍走 HTTP 200）。
public func jsonOkCode(code: Int64, message: String, data: JsonValue): HttpResponse {
    HttpResponse.json(HttpStatus.OK, envelope(code, message, data))
}

/// 错误信封：status 为 HTTP 状态码，code 为业务类别码。
public func jsonErr(status: HttpStatus, code: Int64, message: String, data: JsonValue): HttpResponse {
    HttpResponse.json(status, envelope(code, message, data))
}

/// 读取请求体为 UTF-8 字符串（空体返回 ""）。
public func bodyText(req: HttpRequest): String {
    return req.bodyAsString()
}
