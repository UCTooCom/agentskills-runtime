package uc_installer.cmd

// ============================================================================
// CLI 通道的进程级上下文构造 + 报告项辅助（`uc_installer.cmd` 包）。
//
// ===================== 为什么单开一个包，而不放在 `src/cli/` =====================
//
// `install` / `devkit install` / `rollback` / `uninstall` 这四个子命令要驱动
// `core/orchestrator.cj` 与 `services/devkit/*`，而它们的入口形参是
// `uc_installer.core.AppContext`。本工程已存在依赖边 **`core → cli`**
// （`core/ctx.cj` 用 `uc_installer.cli.CliArgs`），仓颉的编译单元是 package，
// 跨包反向 import 即 cyclic dependency、直接拒绝构建。
//
// 因此「既能拿到 `cli` 的报告骨架、又能拿到 `core` 的 AppContext」的入口层
// 只能是一个**新的叶子包**：`cmd → {cli, core, services, util}`。
// 它不引入任何新边（没有任何既有包依赖 cmd），不构成环。
//
// 分层语义不受影响：本包**只做「能力 → §4.11.1 报告形态」的翻译**，
// 能力本体仍在 `core/`（编排、自退役）与 `services/devkit/`（组件安装、自检、初始化），
// 与 HTTP handler 共用同一份实现 —— 这正是 design §4.2.4 的要求（CLI 为基础）。
// ============================================================================

import std.fs.Path
import std.env.getWorkingDirectory
import uc_installer.cli.{CliArgs, Report, ReportItem, addItem, addStep}
import uc_installer.core.{AppContext, resolve}
import uc_installer.core.StateStore
import uc_installer.util.{Logger, Log, LogLevel, ensureDir}

/// 构造进程级上下文（与 `http/bootstrap.cj` **同一套口径**：installRoot = 当前工作目录）。
///
/// `--source-dir` 覆盖 DevKit 源码目录（与 HTTP 端 `devkit/install` 的 `sourceDir` 同义），
/// 缺省为 `<installRoot>/dev`。
public func buildContext(parsed: CliArgs): AppContext {
    let installRoot = Path(getWorkingDirectory().toString())
    let devSourceDir = if (parsed.sourceDir.isEmpty()) {
        installRoot.join("dev")
    } else {
        Path(parsed.sourceDir)
    }
    let mediaDir = installRoot.join("media")
    let paths = resolve(installRoot, devSourceDir, mediaDir)

    ensureDir(paths.assetsDir)
    ensureDir(paths.releaseDir)

    let logger = Logger(installRoot.join("logs/installer.log").toString(), minLevel: LogLevel.INFO)
    Log.set(logger)
    let store = StateStore.open(paths.stateFile)
    return AppContext(args: parsed, paths: paths, state: store, log: logger)
}

/// 报告项辅助：统一走 `addItem`（内部维护 ok / exitCode）。
///
/// 与 `cli/seed_cmd.cj` 的同名辅助语义一致；因仓颉 `func` 不带 `public` 时
/// 只在**本包**可见，跨包拿不到，故在 `cmd` 包内重声明一份（不是逻辑复制，
/// 逻辑仍然只有 `addItem` 一处）。
public func addCheck(report: Report, id: String, status: String, actual: String,
                     expected: String, fix: String, code: Int64): Unit {
    let it = ReportItem()
    it.id = id
    it.status = status
    it.actual = actual
    it.expected = expected
    it.fix = fix
    it.code = code
    addItem(report, it)
}

/// 步骤项辅助（steps[]）。
public func addStepWith(report: Report, id: String, status: String, actual: String,
                        code: Int64): Unit {
    let it = ReportItem()
    it.id = id
    it.status = status
    it.actual = actual
    it.code = code
    addStep(report, it)
}
