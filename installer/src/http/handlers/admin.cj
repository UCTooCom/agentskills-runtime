package uc_installer.http.handlers

import http_lib.router.Handler
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.HttpStatus
import uc_installer.core.AppContext
import uc_installer.util.{jstr, jint, jobj, jsonOkCode, jsonErr, bodyText, jsonParse, asObject, jsonStr}
import uc_installer.services.{AdminRepo, DbConn, readEnv, readDbConnectionUrl, parseDatabaseUrl}

/// `POST /setup/create-admin` 处理器（T021 / design.md §4.7）。
///
/// **真路径**：读取 releaseDir/.env 的数据库连接 → 查重 → 落库 uctoo_user → 写后回读校验。
/// 删除 nestJs "返回 admin-<ts> 却不落库" 的假路径（闸口 ②）。
public func createAdminHandler(ctx: AppContext): Handler {
    return { req => doCreateAdmin(ctx, req) }
}

private func doCreateAdmin(ctx: AppContext, req: HttpRequest): HttpResponse {
    // 1) 读取 runtime .env 解析数据库连接
    let envPath = ctx.paths.releaseDir.join(".env")
    let conn = match (readEnv(envPath)) {
        case Some(env) => match (readDbConnectionUrl(env)) {
            case Some(url) => parseDatabaseUrl(url)
            case None => None<DbConn>
        }
        case None => None<DbConn>
    }
    match (conn) {
        case None => return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500,
            "无法读取数据库配置（releaseDir/.env 缺失或缺少 DATABASE_URL/orm_connectionUrl）", jobj())
        case Some(c) =>
            let repo = AdminRepo(c)
            // 2) 解析入参
            let text = bodyText(req)
            let (name, username, email, password) = match (jsonParse(text)) {
                case Some(v) => match (asObject(v)) {
                    case Some(o) => (jsonStr(o, "name", ""), jsonStr(o, "username", ""),
                                     jsonStr(o, "email", ""), jsonStr(o, "password", ""))
                    case None => ("", "", "", "")
                }
                case None => ("", "", "", "")
            }
            // 3) 入参校验（AC-110）
            if (email.isEmpty() || username.isEmpty() || password.isEmpty()) {
                return jsonErr(HttpStatus.BAD_REQUEST, 400,
                    "请填写完整的管理员账号信息（email/username/password）", jobj())
            }
            // name 缺省取 username（§6.2.1）
            let finalName = if (name.isEmpty()) { username } else { name }
            // 4) 唯一性查重（AC-114/115）
            if (repo.existsByEmail(email)) {
                return jsonErr(HttpStatus.BAD_REQUEST, 400, "该邮箱已被注册", jobj())
            }
            if (repo.existsByUsername(username)) {
                return jsonErr(HttpStatus.BAD_REQUEST, 400, "该用户名已被使用", jobj())
            }
            // 5) 真实落库（§4.7.2）
            match (repo.insertAdmin(finalName, username, email, password)) {
                case None => return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "管理员账号写入失败", jobj())
                case Some(row) =>
                    // 6) 写后回读自校验（§4.7.4 / AC-118/119）
                    if (!repo.verifyStoredPassword(row.id, password)) {
                        return jsonErr(HttpStatus.INTERNAL_SERVER_ERROR, 500, "管理员账号写入后校验失败", jobj())
                    }
                    let user = jobj()
                    user.put("id", jint(row.id))
                    user.put("name", jstr(row.name))
                    user.put("username", jstr(row.username))
                    user.put("email", jstr(row.email))
                    let data = jobj()
                    data.put("user", user)   // user 与 code 同级
                    return jsonOkCode(200, "管理员账号创建成功", data)
            }
    }
}
