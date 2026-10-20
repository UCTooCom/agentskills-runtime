package uc_installer

import std.collection.ArrayList
import std.core.StringBuilder
import std.env.{exit, getWorkingDirectory}
import std.fs.exists
import uc_installer.services.readFileText
import uc_installer.util.{jobj, jstr}
import uc_installer.cli.{parseArgs, CliArgs}
import uc_installer.cli.{Report, emitReport, failureReport, EXIT_OK, EXIT_ARGS, EXIT_MANUAL}
import uc_installer.cli.runDbExport
import uc_installer.cli.{runSeedApply, runSeedVerify}
import uc_installer.cli.runCheckEnvironment
import uc_installer.cli.{progressRequested, progressConflict, emitStart,
    emitReportEvents, emitDiagnosticsStderr, emitFinal}
import uc_installer.cmd.{runInstall, runRollback, runUninstall,
    runDevkitInstall, runDevkitVerify, runDevkitInit}
import uc_installer.serve.runServeManage
import uc_installer.http.runBootstrap

/// 已知子命令头部白名单（未命中即"未知命令" → exitCode 2；命中但未接入实现 → exitCode 6）。
func knownHead(head: String): Bool {
    return head == "check-environment" || head == "install" || head == "devkit"
        || head == "db" || head == "seed" || head == "rollback" || head == "uninstall"
}

/// 多 token 子命令拼接为报告 command 字段（如 "devkit install"）。
func joinCommand(tokens: ArrayList<String>): String {
    let sb = StringBuilder()
    var i = 0
    while (i < tokens.size) {
        if (i > 0) { sb.append(" ") }
        sb.append(tokens[i])
        i += 1
    }
    return sb.toString()
}

/// 已知但本 Phase 尚未接入实现的子命令 → 以"待人工 / 待实现"如实报告（exitCode 6，不冒充成功）。
func notImplemented(command: String, id: String): Report {
    return failureReport(
        command,
        id,
        "子命令已识别但尚未接入实现",
        "见 specs/RuntimeNativeInstaller/tasks.md 对应任务",
        "补齐该子命令实现，或改用已实现的子命令（ucInstaller.exe --help）",
        EXIT_MANUAL)
}

/// 未知命令 → 参数错误（exitCode 2）+ 修复建议（AC-163）。
func unknownCommand(command: String): Report {
    return failureReport(
        command,
        "command",
        "未知命令: ${command}",
        "合法子命令：check-environment / install / devkit install / db export / seed apply / seed verify / rollback / uninstall",
        "ucInstaller.exe --help 查看用法",
        EXIT_ARGS)
}

/// 读取发行包版本（与 http/handlers/runtime.cj 同口径：版本标在 <cwd>/release/VERSION）。
///
/// 兜底：installer 自身位于 release/bin/ 时取 <cwd>/../VERSION。返回形如
/// `agentskills-runtime 0.0.29` 的首行；找不到返回空串（供调用方决定兜底展示）。
func readInstallerVersion(): String {
    let cwd = getWorkingDirectory()
    let candidates = [
        cwd.join("release").join("VERSION"),
        cwd.join("..").join("VERSION"),
        cwd.join("VERSION")
    ]
    for (c in candidates) {
        if (exists(c)) {
            try {
                // 与 http/handlers/runtime.cj:32 同口径：VERSION 为单行，直接 trimAscii 即可。
                return readFileText(c).trimAscii()
            } catch (_: Exception) {
                // 继续尝试下一个候选
            }
        }
    }
    return ""
}

/// 按解析结果产出报告。抽成独立函数是为了让 report 在声明处即可确定赋值，
/// 避免先声明再在多个分支里赋值（那种写法依赖编译器对不可变局部变量的定赋值判断）。
func dispatch(parsed: CliArgs): Report {
    if (!parsed.parseError.isEmpty()) {
        // 参数错误（AC-163 类别 2）：--json 下错误信息也是 JSON（T003 验收）
        return failureReport(joinCommand(parsed.command), "args", parsed.parseError,
            "合法参数（ucInstaller.exe --help）", "ucInstaller.exe --help", EXIT_ARGS)
    }
    if (parsed.command.isEmpty()) {
        // 无参 = HTTP 引导服务；T015 尚未接入
        return notImplemented("bootstrap", "bootstrap")
    }
    let head = parsed.command[0]
    if (!knownHead(head)) {
        return unknownCommand(joinCommand(parsed.command))
    }
    // check-environment：环境自检（与 HTTP 端点共用 services/envcheck.cj 的实现）。
    if (head == "check-environment") {
        return runCheckEnvironment(parsed)
    }
    // install：驱动 core/orchestrator.cj 的 S0~S8 编排（CLI 为基础，HTTP 仅封装）。
    if (head == "install") {
        return runInstall(parsed)
    }
    // rollback：把 previous/ 下最新备份换回 release/。
    if (head == "rollback") {
        return runRollback(parsed)
    }
    // uninstall：破坏性动作，未带 --force 只报告不执行。
    if (head == "uninstall") {
        return runUninstall(parsed)
    }
    // devkit install / verify / init：与 HTTP 端点共用 services/devkit/* 同一份实现。
    if (head == "devkit") {
        if (parsed.command.size < 2) {
            return unknownCommand(joinCommand(parsed.command))
        }
        match (parsed.command[1]) {
            case "install" => return runDevkitInstall(parsed)
            case "verify" => return runDevkitVerify(parsed)
            case "init" => return runDevkitInit(parsed)
            case _ => return unknownCommand(joinCommand(parsed.command))
        }
    }
    // db export：串 E0~E7 的导出流水线（T045）。
    if (parsed.command.size >= 2 && parsed.command[0] == "db" && parsed.command[1] == "export") {
        return runDbExport(parsed)
    }
    // seed apply / seed verify：串 P0~P4 的导入与校验（T049）。
    if (parsed.command.size >= 2 && parsed.command[0] == "seed" && parsed.command[1] == "apply") {
        return runSeedApply(parsed)
    }
    if (parsed.command.size >= 2 && parsed.command[0] == "seed" && parsed.command[1] == "verify") {
        return runSeedVerify(parsed)
    }
    return notImplemented(joinCommand(parsed.command), head)
}

func printUsage(): Unit {
    println("AgentSkills Runtime Installer (ucInstaller)")
    println("")
    println("用法:")
    println("  ucInstaller.exe                  启动 HTTP 安装引导服务（默认 :3000）")
    println("  ucInstaller.exe --json <子命令>   机器可读 JSON 输出（stdout 仅 JSON）")
    println("  ucInstaller.exe --progress=ndjson <子命令>")
    println("                                   流式 NDJSON 进度（与 --json 互斥）")
    println("")
    println("子命令:")
    println("  serve --manage      运维管控模式（只挂运维端点，不推进安装流程）")
    println("  check-environment   环境自检")
    println("  install             安装 runtime")
    println("  devkit install      安装开发套件")
    println("  devkit verify       校验开发套件")
    println("  devkit init         初始化开发套件")
    println("  db export           导出数据库")
    println("  seed apply          应用种子数据")
    println("  seed verify         校验种子数据")
    println("  rollback            回滚到上一版本")
    println("  uninstall           卸载（需 --force 才真正删除）")
    println("")
    println("全局开关: --json --truthful --offline --force --rollback --with-devkit")
    println("          --devkit-only --auto-exit --system-env --manage")
    println("          --version --no-serve")
    println("取值开关: --port <n> --sdk-path <dir> --source-dir <dir> --db <name>")
    println("          --user <u> --password <p>")
    println("")
    println("说明: 上列子命令均已接入实现；未识别或未接入的组合")
    println("      以 exitCode 6（需人工介入 / 待实现）如实报告，不冒充成功。")
}

// 显式标注返回类型 Unit：函数体最后一个表达式是 std.env.exit(...)（返回类型 Nothing），
// 若不标注，编译器会把返回类型推断为 Nothing，而 main 的返回类型只允许 Unit 或整数类型。
main(args: Array<String>): Unit {
    let parsed = parseArgs(args)

    // T010（C-D3）：`--version` 元操作，在 dispatch 之前短路处理，不依赖 AppContext。
    // 与 runtime 的 release/VERSION 同口径（readInstallerVersion 兜底 release/bin/ 场景）。
    // T012（AC-PCI-012）：`--json --version` 输出单行可解析 JSON（stdout 仅 JSON）。
    if (parsed.version) {
        let v = readInstallerVersion()
        // 找不到 VERSION 时的兜底展示（与裸 `--version` 明文分支一致）。
        let ver = if (v.isEmpty()) { "0.0.1 (VERSION file not found)" } else { v }
        if (parsed.json) {
            let o = jobj()
            o.put("version", jstr(ver))
            println(o.toJsonString())
        } else {
            println(ver)
        }
        exit(EXIT_OK)
    }

    // --help / -h：打印用法后退出码 0（help 是人读元操作，不走 --json 契约）
    if (parsed.command.size == 1 && parsed.command[0] == "help") {
        printUsage()
        exit(EXIT_OK)
    }

    // 无参 = HTTP 引导服务（T015 接入）。启动后会阻塞在 listenAndServe。
    if (parsed.command.isEmpty()) {
        exit(runBootstrap(parsed))
    }

    // `serve --manage`：运维管控模式（T056）。与引导服务共用路由表但只挂运维端点，
    // 不推进 S0~S8。置于 dispatch 之前，因为它走自己的退出码（服务阻塞/退出码来自 runServeManage）。
    if (parsed.command.size >= 1 && parsed.command[0] == "serve") {
        exit(runServeManage(parsed))
    }

    // --json 与 --progress=ndjson 互斥（AC-265）：同时指定即参数冲突。
    if (progressConflict(parsed)) {
        eprintln("参数冲突：--json 与 --progress=ndjson 互斥，只能二选一")
        exit(EXIT_ARGS)
    }

    let report: Report
    if (progressRequested(parsed)) {
        // T053：逐事件流式 NDJSON。诊断只走 stderr，末行给出终态（AC-264）。
        emitStart(joinCommand(parsed.command))
        report = dispatch(parsed)
        emitReportEvents(report)
        emitDiagnosticsStderr(report)
        emitFinal(report)
    } else {
        report = dispatch(parsed)
    }

    // --truthful 语义：不可达即非成功，禁止静默降级（spec line 516）
    if (parsed.truthful) {
        report.diagnostics.add("truthful 模式已启用：不可达即非成功，禁止静默降级")
    }

    if (!progressRequested(parsed)) {
        emitReport(report, parsed.json)
    }
    exit(report.exitCode)
}
