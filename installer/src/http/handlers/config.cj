package uc_installer.http.handlers

import http_lib.router.Handler
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.HttpStatus
import uc_installer.core.AppContext
import uc_installer.util.{jstr, jint, jobj, jsonOkCode, jsonErr, bodyText, jsonParse, asObject,
                           jsonStr, jsonInt, jsonOptObj, isSecretKey, jbool}
import stdx.encoding.json.JsonObject
import uc_installer.services.{AdminRepo, DbConn}
import uc_installer.services.{writeFileAtomic, readFileText}
import uc_installer.platform.isPortFree
import std.fs.exists
import std.convert.Parsable

/// `POST /setup/save-config` 处理器（T019 / design.md §4.2.3 #3）。
///
/// 持久化安装配置到 `<installRoot>/.install-config.json`（**不写 runtime .env**，AC-060）。
/// 必填：顶层 `port` 与 `db.{host,port,database,user,password}`；缺失 → 400。
public func saveConfigHandler(ctx: AppContext): Handler {
    return { req => doSaveConfig(ctx, req) }
}

/// `GET /setup/load-config` 处理器（T019 / design.md §4.2.3 #4）。
///
/// 读失败仍返回 200，并回显已保存配置（口令脱敏）。
public func loadConfigHandler(ctx: AppContext): Handler {
    return { _ => doLoadConfig(ctx) }
}

/// `POST /setup/test-config` 处理器（T019 / design.md §4.2.3 #5）。
///
/// 用 AdminRepo 直连校验 DB（SELECT 1）+ net.cj 校验端口空闲；
/// 默认 200 带 `probe{reachable,detail}`；`--truthful` 下不可达 → 500。
public func testConfigHandler(ctx: AppContext): Handler {
    return { req => doTestConfig(ctx, req) }
}

// ===================== 实现 =====================

private func parseConfigBody(req: HttpRequest): Option<(Int64, DbConn, Int64, JsonObject)> {
    let text = bodyText(req)
    match (jsonParse(text)) {
        case Some(v) => match (asObject(v)) {
            case Some(root) =>
                let port = jsonInt(root, "port", 0)
                if (port <= 0 || port > 65535) {
                    return None
                }
                match (jsonOptObj(root, "db")) {
                    case Some(dbObj) =>
                        let host = jsonStr(dbObj, "host", "")
                        let dbPort = jsonInt(dbObj, "port", 5432)
                        let database = jsonStr(dbObj, "database", "")
                        let user = jsonStr(dbObj, "user", "")
                        let password = jsonStr(dbObj, "password", "")
                        if (host.isEmpty() || database.isEmpty() || user.isEmpty() || password.isEmpty()) {
                            return None
                        }
                        let conn = DbConn(host, toU16(dbPort, 5432), database, user, password)
                        return Some((port, conn, dbPort, root))
                    case None => return None
                }
            case None => return None
        }
        case None => return None
    }
}

private func toU16(n: Int64, fallback: UInt16): UInt16 {
    try {
        return UInt16.parse(n.toString())
    } catch (_: Exception) {
        return fallback
    }
}

private func doSaveConfig(ctx: AppContext, req: HttpRequest): HttpResponse {
    match (parseConfigBody(req)) {
        case None => return jsonErr(HttpStatus.BAD_REQUEST, 400,
            "请填写完整的安装配置（port 与 db.host/port/database/user/password）", jobj())
        case Some((port, conn, dbPort, root)) =>
            if (!writeFileAtomic(ctx.paths.configFile, root.toJsonString())) {
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "配置写入失败", jobj())
            }
            let data = jobj()
            data.put("port", jint(port))
            let db = jobj()
            db.put("host", jstr(conn.host))
            db.put("port", jint(dbPort))
            db.put("database", jstr(conn.database))
            db.put("user", jstr(conn.user))
            db.put("password", jstr("***"))   // 脱敏，不回显明文口令
            data.put("db", db)
            return jsonOkCode(200, "配置已保存", data)
    }
}

private func doLoadConfig(ctx: AppContext): HttpResponse {
    let p = ctx.paths.configFile
    let data = jobj()
    if (!exists(p)) {
        data.put("config", jobj())
        return jsonOkCode(200, "尚未保存配置", data)
    }
    let text = readFileText(p)
    match (jsonParse(text)) {
        case Some(v) => match (asObject(v)) {
            case Some(root) =>
                data.put("config", maskSecrets(root))
                return jsonOkCode(200, "已读取已保存配置", data)
            case None =>
                data.put("config", jobj())
                return jsonOkCode(200, "配置文件损坏，已忽略", data)
        }
        case None =>
            data.put("config", jobj())
            return jsonOkCode(200, "配置解析失败，已忽略", data)
    }
}

private func doTestConfig(ctx: AppContext, req: HttpRequest): HttpResponse {
    match (parseConfigBody(req)) {
        case None => return jsonErr(HttpStatus.BAD_REQUEST, 400,
            "请填写完整的安装配置（port 与 db.host/port/database/user/password）", jobj())
        case Some((port, conn, _, _)) =>
            let (dbOk, detail) = testDbConnection(conn, "")
            let portFree = isPortFree(port)
            let reachable = dbOk && portFree
            let method = if (dbOk) { "pgsql-direct" } else { "none" }
            let d = jobj()
            d.put("method", jstr(method))
            d.put("reachable", jbool(reachable))
            d.put("dbReachable", jbool(dbOk))
            d.put("portFree", jbool(portFree))
            d.put("detail", jstr(detail))
            if (!reachable && ctx.args.truthful) {
                return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "配置校验未通过", d)
            }
            return jsonOkCode(200, "配置校验完成", d)
    }
}

private func testDbConnection(conn: DbConn, detail: String): (Bool, String) {
    try {
        let repo = AdminRepo(conn)
        let ok = repo.ping()
        if (ok) {
            return (true, detail + "数据库连接成功")
        }
        return (false, detail + "数据库连接失败：ping 返回 false")
    } catch (e: Exception) {
        return (false, detail + "数据库连接异常：${e.message}")
    }
}

private func maskSecrets(o: JsonObject): JsonObject {
    let out = jobj()
    for ((k, v) in o.getFields()) {
        if (isSecretKey(k)) {
            out.put(k, jstr("***"))
        } else {
            out.put(k, v)
        }
    }
    return out
}
