package uc_installer.http

import http_lib.router.{Router, Handler, corsMiddleware, CorsConfig}
import http_lib.server.{serveStatic, FileServerConfig}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.{HttpStatus, HttpMethod}
import uc_installer.core.{InstallPaths, AppContext}
import uc_installer.http.handlers.{checkEnvironmentHandler, serviceStatusHandler, logsHandler, startRuntimeHandler, stopRuntimeHandler, restartRuntimeHandler, saveConfigHandler, loadConfigHandler, testConfigHandler, createAdminHandler, checkRuntimeHandler, installRuntimeHandler, readRuntimeEnvHandler, saveRuntimeEnvHandler, generateSslHandler, saveSslHandler, devkitComponentsHandler, devkitInstallHandler, devkitVerifyHandler}
import std.collection.ArrayList

/// 构造完整路由表（T015~T017）：CORS + /healthCheck + 静态向导 + setup 端点表（双前缀）。
///
/// design.md §4.2.2 路由注册：
///   - CORS 默认 allowOrigins=["*"]，并内置 OPTIONS 预检（libs/http_lib/.../cors.cj）。
///   - /healthCheck 响应体严格等于 `success`（AC-023/036/037）。
///   - 静态向导：/ 与 /install.html 等返回主文档（assetsDir 根下 install.html/js/css）。
///   - 19 条 setup 端点 + DevKit 三端点，每端同时挂载 /api/setup/<x> 与 /setup/<x>。
public func buildRouter(paths: InstallPaths, ctx: AppContext): Router {
    let r = Router()

    // CORS：默认 allowOrigins=["*"]，已内置 OPTIONS 预检
    let cors = CorsConfig()
    cors.allowHeaders = ["Content-Type", "Authorization", "Accept", "X-Requested-With"]
    r.use(corsMiddleware(cors))

    // 1) 健康契约：响应体严格等于 success，无引号/无换行/无 JSON 包装
    r.get("/healthCheck", { _ => HttpResponse.text(HttpStatus.OK, "success") })

    // 2) 静态向导（AC-043~045）：/ 与 /install.html 均返回主文档
    let site = serveStatic(paths.assetsDir.toString(), config: FileServerConfig())
    r.get("/", site)
    r.get("/install.html", site)
    r.get("/install.js", site)
    r.get("/install.css", site)

    // 3) setup 端点表：同时挂载 /api/setup/<x> 与 /setup/<x>
    let table = setupTable(ctx)
    for ((m, name, h) in table) {
        r.handle(m, "/api/setup/" + name, h)
        r.handle(m, "/setup/" + name, h)
    }

    return r
}

/// 端点登记表：(HttpMethod, 路径片段, Handler)。
/// T018 check-environment / T019 save|load|test-config / T020 service-status+logs /
/// T021 create-admin / T022 check|install-runtime / T023 read|save-runtime-env /
/// T024 generate|save-ssl / T025 start|stop|restart-runtime。
/// 每条同时挂载 /api/setup/<x> 与 /setup/<x> 双前缀（见 buildRouter）。
public func setupTable(ctx: AppContext): Array<(HttpMethod, String, Handler)> {
    let table = ArrayList<(HttpMethod, String, Handler)>()
    table.add((HttpMethod.GET, "check-environment", checkEnvironmentHandler(ctx)))
    table.add((HttpMethod.GET, "service-status", serviceStatusHandler(ctx)))
    table.add((HttpMethod.GET, "logs", logsHandler(ctx)))
    table.add((HttpMethod.POST, "start-runtime", startRuntimeHandler(ctx)))
    table.add((HttpMethod.POST, "stop-runtime", stopRuntimeHandler(ctx)))
    table.add((HttpMethod.POST, "restart-runtime", restartRuntimeHandler(ctx)))
    // T019 安装配置（落 .install-config.json，不写 runtime .env）
    table.add((HttpMethod.POST, "save-config", saveConfigHandler(ctx)))
    table.add((HttpMethod.GET, "load-config", loadConfigHandler(ctx)))
    table.add((HttpMethod.POST, "test-config", testConfigHandler(ctx)))
    // T021 管理员账号（真路径：读 .env → 查重 → 落库 → 回读校验）
    table.add((HttpMethod.POST, "create-admin", createAdminHandler(ctx)))
    // T022 runtime 检测 / 安装（本地介质优先、幂等）
    table.add((HttpMethod.GET, "check-runtime", checkRuntimeHandler(ctx)))
    table.add((HttpMethod.POST, "install-runtime", installRuntimeHandler(ctx)))
    // T023 runtime .env 读取 / 行级更新
    table.add((HttpMethod.GET, "read-runtime-env", readRuntimeEnvHandler(ctx)))
    table.add((HttpMethod.POST, "save-runtime-env", saveRuntimeEnvHandler(ctx)))
    // T024 SSL 生成 / 保存
    table.add((HttpMethod.POST, "generate-ssl", generateSslHandler(ctx)))
    table.add((HttpMethod.POST, "save-ssl", saveSslHandler(ctx)))
    // T026 DevKit 三端点（M11/M12；design.md §6.1 #18~#20）
    table.add((HttpMethod.GET, "devkit/components", devkitComponentsHandler(ctx)))
    table.add((HttpMethod.POST, "devkit/install", devkitInstallHandler(ctx)))
    table.add((HttpMethod.GET, "devkit/verify", devkitVerifyHandler(ctx)))
    return table.toArray()
}
