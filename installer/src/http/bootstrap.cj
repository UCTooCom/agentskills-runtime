package uc_installer.http

import std.fs.{File, OpenMode, Path}
import std.env.getWorkingDirectory
import std.net.TcpServerSocket
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.core.HttpStatus
import uc_installer.cli.{CliArgs, EXIT_GENERIC, EXIT_ARGS}
import uc_installer.core.{InstallPaths, StateStore, resolve, AppContext}
import uc_installer.util.{Logger, Log, LogLevel, ensureDir}

/// 启动 HTTP 引导服务（T015 接入点）。
///
/// 启动时序（design.md §4.2.1）：
///   1. 解析 installRoot（默认 = 工作目录）+ 派生路径 → 2. 打开状态仓库
///   → 3. 初始化日志 → 4. 探测端口占用 → 5. 注册路由 → 6. listenAndServe。
/// 全过程无网络、无子进程、无 DB 连接，冷启动 ≤3s（AC-006）。
///
/// 默认仅回环监听（AC-016）；端口取自 --port（默认 3000）。
/// listenAndServe 为阻塞循环；正常情况不会返回，仅在异常时返回退出码。
public func runBootstrap(args: CliArgs): Int64 {
    // T011（C-D1）：无参启动即 HTTP 引导服务，与 --no-serve（不监听端口）语义矛盾，
    // 按"不冒充成功"原则提前报错退出，而非静默忽略该开关。
    if (args.noServe) {
        eprintln("错误：无参启动即 HTTP 引导服务，与 --no-serve（不监听端口）矛盾")
        return EXIT_ARGS
    }
    let cwd = getWorkingDirectory().toString()
    let installRoot = Path(cwd)
    let devSourceDir = installRoot.join("dev")
    let mediaDir = installRoot.join("media")
    let paths = resolve(installRoot, devSourceDir, mediaDir)

    // 确保 assetsDir 等目录存在（静态向导从这里取文件）
    ensureDir(paths.assetsDir)
    ensureDir(paths.releaseDir)

    let logger = Logger(installRoot.join("logs/installer.log").toString(), minLevel: LogLevel.INFO)
    Log.set(logger)

    let store = StateStore.open(paths.stateFile)
    let ctx = AppContext(args: args, paths: paths, state: store, log: logger)

    // 端口占用预检（一次 TcpServerSocket 试绑），命中占用则如实降级报错
    if (!probePortFree(args.port)) {
        logger.error("端口 ${args.port} 已被占用，无法启动引导服务")
        return EXIT_GENERIC
    }

    let router = buildRouter(paths, ctx)

    // HttpServer 组装（签名取证：libs/http_lib/.../server.cj:112-130）
    let cfg = HttpServerConfig()
    cfg.concurrent = true
    cfg.readTimeout = Duration.second * 30
    cfg.serverName = "ucInstaller/1.0"
    let server = HttpServer(handler: router.handler(), config: cfg)

    // 监听成功后写端口标记文件（AC-040）
    try {
        let pf = File(paths.portFile.toString(), OpenMode.Write)
        pf.write("${args.port}".toArray())
        pf.close()
    } catch (e: Exception) {
        logger.warn("写端口标记文件失败: ${e.message}")
    }

    logger.info("引导服务启动：http://127.0.0.1:${args.port}/ （仅回环）")
    try {
        server.listenAndServe("127.0.0.1", UInt16(args.port))
        return 0
    } catch (e: Exception) {
        logger.error("HTTP 服务异常退出: ${e.message}")
        return EXIT_GENERIC
    }
}

/// 端口空闲探测：尝试绑定一次，成功即释放视为空闲。
func probePortFree(port: Int64): Bool {
    try {
        let sock = TcpServerSocket(bindAt: UInt16(port))
        sock.bind()
        sock.close()
        return true
    } catch (_: Exception) {
        return false
    }
}
