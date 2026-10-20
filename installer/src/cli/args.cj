package uc_installer.cli

import std.collection.ArrayList
import std.convert.Parsable

/// 全局参数 + 子命令 token。
/// 设计依据：tasks.md T003（AC-001、AC-117~120）。
public class CliArgs {
    // 全局开关
    public var json: Bool = false
    public var truthful: Bool = false
    public var offline: Bool = false
    public var force: Bool = false
    public var rollback: Bool = false
    public var withDevkit: Bool = false
    public var devkitOnly: Bool = false
    public var autoExit: Bool = false
    public var systemEnv: Bool = false
    public var manage: Bool = false
    // T010：`--version` 元操作（C-D3）：打印与 release/VERSION 一致的版本号。
    public var version: Bool = false
    // T011：`--no-serve` 元操作（C-D1）：执行子命令时不监听任何端口。
    public var noServe: Bool = false
    // 进度输出形态（T053）：空 = 不启用；"ndjson" = 逐事件流式。
    public var progress: String = ""
    // 取值参数
    public var port: Int64 = 3000
    public var sdkPath: String = ""
    public var sourceDir: String = ""
    public var db: String = "uctoo"
    public var user: String = ""
    public var password: String = ""
    // 子命令 token（如 ["devkit","install"] / ["db","export"] / ["seed","apply"]）
    public var command: ArrayList<String> = ArrayList<String>()
    // 解析错误（未知参数等）；非空即表示解析失败
    public var parseError: String = ""
}

/// 解析命令行参数。约定：全局 -- 选项出现在第一个非 -- 参数之前；之后的 token 全部视为子命令。
///
/// 实现说明：这里刻意用 if/else 链而不是 match —— 仓颉的 match 臂若写成多语句块，
/// '=>' 之后的 '{' 会被解析成 lambda 起始（报 expected '=>' in lambda expression），
/// 且分支内需要推进外层下标，不适合改写成 lambda 形态。
public func parseArgs(args: Array<String>): CliArgs {
    let parsed = CliArgs()
    var i = 0
    var commandStarted = false
    while (i < args.size) {
        let a = args[i]
        if (!commandStarted && a.startsWith("--")) {
            i = applyOption(parsed, args, i)
        } else {
            commandStarted = true
            parsed.command.add(a)
            i += 1
        }
    }
    return parsed
}

/// 处理一个全局选项（含取值选项），返回下一个待处理的下标（取值选项会额外消耗一个 token）。
func applyOption(parsed: CliArgs, args: Array<String>, idx: Int64): Int64 {
    let a = args[idx]
    let next = idx + 1
    if (a == "--json") {
        parsed.json = true
    } else if (a == "--truthful") {
        parsed.truthful = true
    } else if (a == "--offline") {
        parsed.offline = true
    } else if (a == "--force") {
        parsed.force = true
    } else if (a == "--rollback") {
        parsed.rollback = true
    } else if (a == "--with-devkit") {
        parsed.withDevkit = true
    } else if (a == "--devkit-only") {
        parsed.devkitOnly = true
    } else if (a == "--auto-exit") {
        parsed.autoExit = true
    } else if (a == "--system-env") {
        parsed.systemEnv = true
    } else if (a == "--manage") {
        parsed.manage = true
    } else if (a == "--version") {
        // T010（C-D3）：元操作，不进入 command，由 main 提前打印版本并退出。
        parsed.version = true
    } else if (a == "--no-serve") {
        // T011（C-D1）：执行子命令时全程不监听端口。
        parsed.noServe = true
    } else if (a.startsWith("--progress=")) {
        // T053：`--progress=ndjson`。用 replace 取值而非下标切片 —— 前缀是纯 ASCII，
        // 但切片下标写错会在非字符边界抛异常，replace 没有这个隐患。
        let v = a.replace("--progress=", "")
        if (v != "ndjson") {
            parsed.parseError = "不支持的 --progress 取值: ${v}（当前仅支持 ndjson）"
            return idx + 1
        }
        parsed.progress = v
    } else if (a == "--help" || a == "-h") {
        parsed.command.add("help")
    } else if (a == "--port") {
        if (hasValue(args, idx)) {
            parsed.port = parseI64(args[next], 3000)
            return next + 1
        }
        parsed.parseError = "缺少 --port 的值"
    } else if (a == "--sdk-path") {
        if (hasValue(args, idx)) {
            parsed.sdkPath = args[next]
            return next + 1
        }
        parsed.parseError = "缺少 --sdk-path 的值"
    } else if (a == "--source-dir") {
        if (hasValue(args, idx)) {
            parsed.sourceDir = args[next]
            return next + 1
        }
        parsed.parseError = "缺少 --source-dir 的值"
    } else if (a == "--db") {
        if (hasValue(args, idx)) {
            parsed.db = args[next]
            return next + 1
        }
        parsed.parseError = "缺少 --db 的值"
    } else if (a == "--user") {
        if (hasValue(args, idx)) {
            parsed.user = args[next]
            return next + 1
        }
        parsed.parseError = "缺少 --user 的值"
    } else if (a == "--password") {
        if (hasValue(args, idx)) {
            parsed.password = args[next]
            return next + 1
        }
        parsed.parseError = "缺少 --password 的值"
    } else {
        parsed.parseError = "未知参数: ${a}（可用 --help 查看用法）"
    }
    return next
}

/// 该选项后面是否还有一个 token 可作为它的值。
func hasValue(args: Array<String>, idx: Int64): Bool {
    return idx + 1 < args.size
}

/// 解析端口等整数参数；失败回退默认值（端口非法不作为致命错误，仅告警由调用方承担）。
public func parseI64(s: String, fallback: Int64): Int64 {
    try {
        return Int64.parse(s)
    } catch (_: Exception) {
        return fallback
    }
}
