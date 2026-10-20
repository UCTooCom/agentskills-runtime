package uc_installer.util

import std.fs.{File, OpenMode, Path, exists, Directory}
import std.time.DateTime
import std.env.getWorkingDirectory

// 注意：eprintln 属 std.core（默认可见），**不需要也不允许**从 console 包导入它，
// 那样会得到「符号在该包不可访问」的报错。
// 依据：std.core.func.eprintln；工程实证——宿主 8 个文件直接用 eprintln，
// 全都没有任何 console 包 / io 包的 import。

/// 日志级别
public enum LogLevel {
    | DEBUG
    | INFO
    | WARN
    | ERROR

    public func label(): String {
        match (this) {
            case DEBUG => "DEBUG"
            case INFO => "INFO"
            case WARN => "WARN"
            case ERROR => "ERROR"
        }
    }
}

/// 日志器：写入文件（append）+ 标准错误（stderr）。
/// 诊断走 stderr，绝不污染 stdout——保证 --json 模式下 stdout 只有机器可读 JSON。
public class Logger {
    private let file: File
    private let minLevel: LogLevel

    public init(logFilePath: String, minLevel!: LogLevel = LogLevel.INFO) {
        let p = Path(logFilePath)
        let parent = p.parent.toString()
        if (!parent.isEmpty() && !exists(parent)) {
            Directory.create(parent, recursive: true)
        }
        this.file = File(logFilePath, OpenMode.Append)
        this.minLevel = minLevel
    }

    public func debug(msg: String): Unit { this.write(LogLevel.DEBUG, msg) }
    public func info(msg: String): Unit { this.write(LogLevel.INFO, msg) }
    public func warn(msg: String): Unit { this.write(LogLevel.WARN, msg) }
    public func error(msg: String): Unit { this.write(LogLevel.ERROR, msg) }

    private func write(level: LogLevel, msg: String): Unit {
        if (priority(level) < priority(this.minLevel)) {
            return
        }
        let ts = DateTime.now().format("yyyy-MM-dd HH:mm:ss")
        let line = "[${ts}] [${level.label()}] ${redactLine(msg)}"
        try {
            this.file.write("${line}\n".toArray())
        } catch (_: Exception) {
            // 文件写入失败不阻断主流程
        }
        eprintln(line)
    }

    private func priority(l: LogLevel): Int64 {
        match (l) {
            case DEBUG => 0
            case INFO => 1
            case WARN => 2
            case ERROR => 3
        }
    }
}

/// 进程内单例日志访问器：首次调用惰性创建，路径解析到工作目录 logs/installer.log。
public class Log {
    // 注意：仓颉的可选类型是「前置 ?」（写作 ?Logger 或 Option<Logger>）；
    // 后置的 Logger? 是 Rust 语法，编译器会在 '?' 处报 expected ';' or '<NL>'。
    private static var logger: Option<Logger> = None<Logger>

    public static func get(): Logger {
        match (Log.logger) {
            case Some(l) => l
            // match 臂不能写多语句块：'=> 后的 '{' 会被解析成 lambda 起始，
            // 块内第一条 let 就会被当成缺 '=>' 的 lambda 参数列表。故逻辑外提成私有静态函数。
            case None => Log.defaultLogger()
        }
    }

    /// 惰性创建并缓存默认日志器。
    private static func defaultLogger(): Logger {
        let l = Logger(defaultLogPath())
        Log.logger = Some(l)
        return l
    }

    public static func set(l: Logger): Unit {
        Log.logger = Some(l)
    }
}

func defaultLogPath(): String {
    let base = getWorkingDirectory().toString()
    return "${base}/logs/installer.log"
}
