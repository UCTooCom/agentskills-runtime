package uc_installer.http.handlers

import http_lib.router.Handler
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.HttpStatus
import uc_installer.core.AppContext
import uc_installer.util.{jstr, jint, jobj, jsonOkCode, jsonErr, bodyText, jsonParse, asObject,
                           jsonStr, jsonOptObj, isSecretKey}
import uc_installer.services.{readEnv, readDbConnectionUrl, parseDatabaseUrl, DbConn,
                               upsertEnv, UpsertEnvOutcome}
import uc_installer.services.{readFileText, writeFileAtomic}
import std.fs.exists
import std.collection.HashMap
import std.convert.Parsable

/// `GET /setup/read-runtime-env` 处理器（T023 / design.md §4.8.3）。
///
/// 未装（缺 releaseDir）→ 500；已装无 .env → **404**；成功返回
/// `{code:200, config, dbConfig, envPath}`（口令全程脱敏为 ***）。
public func readRuntimeEnvHandler(ctx: AppContext): Handler {
    return { _ => doReadRuntimeEnv(ctx) }
}

/// `POST /setup/save-runtime-env` 处理器（T023 / design.md §4.8.3）。
///
/// 行级 in-place 更新 runtime .env；非法键名 → 400（AC-095）。
/// body 支持 `{key,value}` 单键或 `{updates:{k:v,...}}` 批量。
public func saveRuntimeEnvHandler(ctx: AppContext): Handler {
    return { req => doSaveRuntimeEnv(ctx, req) }
}

private func doReadRuntimeEnv(ctx: AppContext): HttpResponse {
    let releaseDir = ctx.paths.releaseDir
    if (!exists(releaseDir)) {
        return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "runtime 尚未安装", jobj())
    }
    let envPath = releaseDir.join(".env")
    if (!exists(envPath)) {
        return jsonErr(HttpStatus.NOT_FOUND, 404, "runtime 已安装但未找到 .env 文件", jobj())
    }
    match (readEnv(envPath)) {
        case None => return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "读取 .env 失败", jobj())
        case Some(env) =>
            let dbConn = match (readDbConnectionUrl(env)) {
                case Some(url) => parseDatabaseUrl(url)
                case None => None<DbConn>
            }
            let config = jobj()
            for ((k, v) in env) {
                if (isSecretKey(k)) {
                    config.put(k, jstr("***"))
                } else {
                    config.put(k, jstr(v))
                }
            }
            let dbConfig = jobj()
            match (dbConn) {
                case Some(c) =>
                    dbConfig.put("host", jstr(c.host))
                    dbConfig.put("port", jint(Int64.parse(c.port.toString())))
                    dbConfig.put("database", jstr(c.database))
                    dbConfig.put("user", jstr(c.user))
                    dbConfig.put("password", jstr("***"))
                case None => ()
            }
            let data = jobj()
            data.put("config", config)
            data.put("dbConfig", dbConfig)
            data.put("envPath", jstr(envPath.toString()))
            return jsonOkCode(200, "已读取运行环境配置", data)
    }
}

private func doSaveRuntimeEnv(ctx: AppContext, req: HttpRequest): HttpResponse {
    let envPath = ctx.paths.releaseDir.join(".env")
    if (!exists(envPath)) {
        return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "runtime 尚未安装或缺少 .env 文件", jobj())
    }
    let text = bodyText(req)
    match (parseEnvUpdates(text)) {
        case None => return jsonErr(HttpStatus.BAD_REQUEST, 400,
            "请提供要更新的配置（updates 对象或 key/value）", jobj())
        case Some(updates) =>
            var content = readFileText(envPath)
            for ((k, v) in updates) {
                match (upsertEnv(content, k, v)) {
                    case UpsertEnvOutcome.Updated(next) => content = next
                    case UpsertEnvOutcome.InvalidKey =>
                        return jsonErr(HttpStatus.BAD_REQUEST, 400, "非法的配置键名：${k}", jobj())
                }
            }
            if (!writeFileAtomic(envPath, content)) {
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "写入 .env 失败", jobj())
            }
            return jsonOkCode(200, "配置已更新", jobj())
    }
}

private func parseEnvUpdates(text: String): Option<HashMap<String, String>> {
    match (jsonParse(text)) {
        case Some(v) => match (asObject(v)) {
            case Some(o) =>
                let out = HashMap<String, String>()
                // 批量：updates 对象
                match (jsonOptObj(o, "updates")) {
                    case Some(u) =>
                        for ((k, _) in u.getFields()) {
                            let s = jsonStr(u, k, "")
                            if (!s.isEmpty()) { out.add(k, s) }
                        }
                        if (!out.isEmpty()) { return Some(out) }
                    case None => ()
                }
                // 单键：key/value
                let key = jsonStr(o, "key", "")
                let value = jsonStr(o, "value", "")
                if (!key.isEmpty() && !value.isEmpty()) {
                    out.add(key, value)
                    return Some(out)
                }
                return None<HashMap<String, String>>
            case None => return None<HashMap<String, String>>
        }
        case None => return None<HashMap<String, String>>
    }
}
