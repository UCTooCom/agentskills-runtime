package uc_installer.serve

// ============================================================================
// `ucInstaller.exe serve --manage`（任务 T056；REQ-RNI-107 / AC-271）。
//
// ===================== 为什么必须有这个模式（铁律） =====================
//
// **启停必须由运行系统之外的管控者提供** —— 没有任何进程能可靠地"停止并重启自己"。
// 安装器本来就 spawn runtime、天然是父进程，所以管控者只能是它。
// 反过来，让 runtime 自己宣称"可自行停止并重启"是自举，进程一旦停止就没机会执行
// 重启的那一行代码。
//
// 本模式**只挂载运维端点、不做安装流程**：
//   - 不调 `core/orchestrator.resume()`，不会推进 S0~S8；
//   - 路由表与引导服务完全一致（同一份 `http/routes.cj buildRouter`），
//     所以 web-admin 管理页拿到的仍是 `start-runtime` / `stop-runtime` / `restart-runtime`。
//
// `用毕即退`（保留"零常驻"卖点）：
//   - 默认阻塞在服务端口上，由人工 Ctrl-C / 结束进程退出；
//   - 带 `--auto-exit` 时另起一个观察协程：一旦**观测到 runtime 从可达变为不可达**
//     （说明管控动作已生效，runtime 已被停止），安装器即以退出码 0 结束自身。
//     ⚠️ 必须先观测到"可达"才认账 —— 否则 runtime 压根没起时会被误判成"已停止"。
// ============================================================================

import std.fs.{File, OpenMode, Path}
import std.env.exit
import std.net.TcpServerSocket
import std.time.DateTime
import http_lib.server.{HttpServer, HttpServerConfig}
import uc_installer.cli.{CliArgs, EXIT_OK, EXIT_GENERIC, EXIT_ARGS}
import uc_installer.core.{AppContext, RUNTIME_HEALTH_PORT}
import uc_installer.http.buildRouter
import uc_installer.cmd.buildContext
import uc_installer.platform.isLocalPortReachable

/// `--auto-exit` 观察协程的最大轮数（2s 一轮 ≈ 1 小时；超时即停止观察，不再退出）。
private let WATCH_MAX_ROUNDS: Int64 = 1800

/// 启动运维管控服务（阻塞）。
public func runServeManage(args: CliArgs): Int64 {
    let ctx = buildContext(args)
    let paths = ctx.paths

    // T011（C-D1）：serve --manage 本身即运维管控 HTTP 服务，与 --no-serve（不监听端口）
    // 语义矛盾，按"不冒充成功"原则提前报错退出。
    if (args.noServe) {
        ctx.log.error("serve --manage 是运维管控 HTTP 服务，与 --no-serve（不监听端口）矛盾")
        return EXIT_ARGS
    }

    if (!args.manage) {
        ctx.log.error("serve 子命令必须带 --manage（运维管控模式），否则请用无参启动走安装引导流程")
        return EXIT_GENERIC
    }

    if (!probePortFree(args.port)) {
        ctx.log.error("端口 ${args.port} 已被占用，无法启动运维管控服务")
        return EXIT_GENERIC
    }

    let router = buildRouter(paths, ctx)

    let cfg = HttpServerConfig()
    cfg.concurrent = true
    cfg.readTimeout = Duration.second * 30
    cfg.serverName = "ucInstaller-manage/1.0"
    let server = HttpServer(handler: router.handler(), config: cfg)

    try {
        let pf = File(paths.portFile.toString(), OpenMode.Write)
        pf.write("${args.port}".toArray())
        pf.close()
    } catch (e: Exception) {
        ctx.log.warn("写端口标记文件失败: ${e.message}")
    }

    ctx.log.info("运维管控服务启动：http://127.0.0.1:${args.port}/ （仅回环；不执行安装流程）")

    if (args.autoExit) {
        startAutoExitWatcher(ctx, args)
    }

    try {
        server.listenAndServe("127.0.0.1", UInt16(args.port))
        return EXIT_OK
    } catch (e: Exception) {
        ctx.log.error("运维管控服务异常退出: ${e.message}")
        return EXIT_GENERIC
    }
}

/// `--auto-exit` 观察协程：runtime 由可达变为不可达 ⇒ 安装器退出（退出码 0）。
///
/// 闭包内所有可变状态都在闭包**内部**声明 —— 仓颉不允许闭包捕获外层的 `var`，
/// 捕获只读的 `let`（此处是 healthPort / interval / logger）没有问题。
private func startAutoExitWatcher(ctx: AppContext, args: CliArgs): Unit {
    let healthPort = RUNTIME_HEALTH_PORT
    let interval = Duration.second * 2
    let logger = ctx.log
    let _watcher = spawn {
        var seenUp = false
        var rounds: Int64 = 0
        while (rounds < WATCH_MAX_ROUNDS) {
            if (isLocalPortReachable(healthPort)) {
                seenUp = true
            } else if (seenUp) {
                // 观测到过"在跑"，现在是"不在跑" ⇒ 管控动作已生效，用毕即退。
                // AC-128 同源要求：退出时**不停止 runtime**（它已经被停止了），
                // 保留全部安装产物、环境文件与状态文件 —— 这里不做任何清理。
                logger.info("runtime 已停止（端口 ${healthPort} 不可达），--auto-exit 生效，管控者退出")
                exit(EXIT_OK)
            }
            sleep(interval)
            rounds = rounds + 1
        }
        logger.warn("--auto-exit 观察超时（${WATCH_MAX_ROUNDS} 轮）仍未观测到 runtime 停止，停止观察")
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
