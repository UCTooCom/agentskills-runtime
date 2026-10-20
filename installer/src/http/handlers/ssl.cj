package uc_installer.http.handlers

import http_lib.router.Handler
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.HttpStatus
import uc_installer.core.AppContext
import uc_installer.util.{ensureDir, jstr, jobj, jsonOkCode, jsonErr, bodyText, jsonParse, asObject, jsonStr}
import uc_installer.services.{generateSelfSigned, saveSsl, SslResult}
import uc_installer.services.{readFileText, removeFileIfExists}
import std.fs.{Path, exists}
import std.time.DateTime

/// `POST /setup/generate-ssl` 处理器（T024 / design.md §4.8.1）。
///
/// openssl 单路径生成自签证书；**失败即明确错误+指引，不写任何证书文件**（AC-097）。
/// 生成到临时目录，读取内容回传后清理残骸（不写入 releaseDir/ssl）。
public func generateSslHandler(ctx: AppContext): Handler {
    return { req => doGenerateSsl(ctx, req) }
}

/// `POST /setup/save-ssl` 处理器（T024 / design.md §4.8.2）。
///
/// 把客户端提交的 crt/key 写入 releaseDir/ssl/server.{crt,key}，覆盖前备份、失败回滚。
public func saveSslHandler(ctx: AppContext): Handler {
    return { req => doSaveSsl(ctx, req) }
}

private func doGenerateSsl(ctx: AppContext, req: HttpRequest): HttpResponse {
    let domain = match (jsonParse(bodyText(req))) {
        case Some(v) => match (asObject(v)) {
            case Some(o) => jsonStr(o, "domain", "")
            case None => ""
        }
        case None => ""
    }
    if (domain.isEmpty()) {
        return jsonErr(HttpStatus.BAD_REQUEST, 400, "请提供证书域名（domain）", jobj())
    }
    let ts = DateTime.now().toString().replace(":", "-").replace(" ", "_")
    let tmp = ctx.paths.installRoot.join(".ssl-tmp-${ts}")
    ensureDir(tmp)
    match (generateSelfSigned(domain, tmp)) {
        case SslResult.Ok =>
            let crt = readFileText(tmp.join("server.crt"))
            let key = readFileText(tmp.join("server.key"))
            removeFileIfExists(tmp.join("server.crt"))
            removeFileIfExists(tmp.join("server.key"))
            let data = jobj()
            data.put("crt", jstr(crt))
            data.put("key", jstr(key))
            return jsonOkCode(200, "证书已生成", data)
        case SslResult.Failed(msg) =>
            removeFileIfExists(tmp.join("server.crt"))
            removeFileIfExists(tmp.join("server.key"))
            return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "证书生成失败：${msg}", jobj())
    }
}

private func doSaveSsl(ctx: AppContext, req: HttpRequest): HttpResponse {
    let (crt, key) = match (jsonParse(bodyText(req))) {
        case Some(v) => match (asObject(v)) {
            case Some(o) => (jsonStr(o, "crt", ""), jsonStr(o, "key", ""))
            case None => ("", "")
        }
        case None => ("", "")
    }
    if (crt.isEmpty() || key.isEmpty()) {
        return jsonErr(HttpStatus.BAD_REQUEST, 400, "请提供证书内容（crt/key）", jobj())
    }
    match (saveSsl(ctx.paths.releaseDir, crt, key)) {
        case SslResult.Ok => return jsonOkCode(200, "证书已保存", jobj())
        case SslResult.Failed(msg) => return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500,
            "证书保存失败：${msg}", jobj())
    }
}
