/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.log

import magic.core.message.Message
import magic.core.message.MessageList
import magic.config.Config
import magic.utils.exists

import std.fs.{File, OpenMode, Directory, Path, FileInfo, remove}
import std.console.Console
import std.collection.{HashMap, ArrayList}
import std.io.OutputStream
import std.core.Duration
import std.time.DateTime
import std.convert.*
import std.env.getVariable

import stdx.log.LogLevel

@When[cjc_version < "1.0.0"]
import std.log.SimpleLogger

@When[cjc_version >= "1.0.0"]
import stdx.logger.SimpleLogger

@When[cjc_version >= "1.0.0"]
private func buildSimpleLogger(output: OutputStream): SimpleLogger {
    let logger = SimpleLogger(output)
    logger.level = match (Config.logLevel.toAsciiLower()) {
        case "trace" => LogLevel.TRACE
        case "debug" => LogLevel.DEBUG
        case "info" => LogLevel.INFO
        case "warn" => LogLevel.WARN
        case "error" => LogLevel.ERROR
        case _ => LogLevel.INFO
    }
    return logger
}

@When[ohos != "true"]
struct LogUtilsImpl {
    private static var _LOGGER: Option<SimpleLogger> = None
    private static var CURR_LOG_FILE: String = Config.logFile
    /// §11.3 磁盘水位告警出口：(message, usedBytes, limitBytes) -> Unit。
    /// 由组合根（main.cj）注入为 LrtEventBridge.pushMonitorAlert，避免 magic.log
    /// 反向依赖桥接层造成包环（桥接层已 import magic.log.LogUtils）。
    private static var _watermarkAlerter: Option<(String, Int64, Int64) -> Unit> = None
    /// 水位阈值缺省值：1 GiB
    private static let DEFAULT_WATERMARK_BYTES: Int64 = 1073741824

    /// §11.3：注入磁盘水位告警出口（组合根调用）
    public static func setWatermarkAlerter(f: (String, Int64, Int64) -> Unit): Unit {
        LogUtilsImpl._watermarkAlerter = f
    }

    private static prop LOGGER: SimpleLogger {
        get() {
            // Log file is changed
            if (Config.logFile != CURR_LOG_FILE) {
                let logger = buildLogger()
                _LOGGER = logger
                return logger
            }
            match (_LOGGER) {
                case Some(logger) =>
                    return logger
                case None =>
                    let logger = buildLogger()
                    _LOGGER = logger
                    return logger
            }
        }
    }

    private static func buildLogger(): SimpleLogger {
        let logger = if (Config.logFile == "stdout") {
            buildSimpleLogger(Console.stdOut)
        } else if (Config.logFile == "stderr") {
            buildSimpleLogger(Console.stdErr)
        } else {
            // Ch0.3：文件模式。默认启用带时间戳文件名 + Append，避免覆盖历史日志。
            let effectivePath = if (Config.logFileTimestamped) {
                resolveTimestampedPath(Config.logFile)
            } else {
                Config.logFile
            }
            let path = Path(effectivePath)
            if (!exists(path.parent)) {
                Directory.create(path.parent, recursive: true)
            }
            // Ch0.3：OpenMode.Append —— 同一次运行内的多次 buildLogger 不截断已有内容
            let file = File(path, OpenMode.Append)
            maintainCurrentPointer(Config.logFile, effectivePath)
            purgeExpiredLogs(Config.logFile)
            // §11.3 磁盘水位告警：清理后再探一次，超阈值即告警（不影响启动）
            checkDiskWatermark(Config.logFile)
            buildSimpleLogger(file)
        }
        CURR_LOG_FILE = Config.logFile
        return logger
    }

    // ── Ch0.3 日志可回溯改造辅助 ───────────────────────────────────

    /// 生成带时间戳的日志路径：`<dir>/<basename>-<yyyyMMdd>-<HHmmss>.log`
    /// 同秒重启（例如快速连续重启）时追加 `-1` / `-2` 后缀，避免覆盖。
    private static func resolveTimestampedPath(configured: String): String {
        let p = Path(configured)
        let dir = p.parent.toString()
        // 用 Path.fileNameWithoutExtension 取代手写剥扩展名（避免 ".gitignore" 等边界坑）
        let stem = p.fileNameWithoutExtension
        let ts = DateTime.now().format("yyyyMMdd-HHmmss")
        let base = joinPath(dir, "${stem}-${ts}")
        var candidate = "${base}.log"
        var seq = 1
        while (exists(candidate) && seq <= 100) {
            candidate = "${base}-${seq}.log"
            seq++
        }
        return candidate
    }

    private static func joinPath(dir: String, name: String): String {
        if (dir.isEmpty() || dir == ".") {
            return name
        }
        return "${dir}/${name}"
    }

    /// 维护 `logs/current-log.txt` 指针文件，指向本次运行的活跃日志。
    /// Windows 上普通用户创建软链常无权限，故统一降级为指针文件（写路径文本）。
    private static func maintainCurrentPointer(configured: String, activePath: String): Unit {
        try {
            let dir = Path(configured).parent.toString()
            if (dir.isEmpty()) {
                return
            }
            let pointerPath = joinPath(dir, "current-log.txt")
            File.writeTo(pointerPath, (activePath + "\n").toArray())
        } catch (_: Exception) {
            // 指针文件只是便利设施，失败不影响日志主体写入
        }
    }

    /// Ch0.3 保留期清理：扫描日志目录，删除文件名时间戳超期且**符合本服务模板**的文件。
    /// 安全约束：只删 `<basename>-<yyyyMMdd>-<HHmmss>[-n].log` 形态的文件，
    /// 不碰用户放在同目录下的其它文件（尤其不能误删 current-log.txt）。
    ///
    /// 时间比较说明：`yyyyMMdd-HHmmss` 是定长、零填充的数字串，其**字典序与时间序一致**，
    /// 因此直接用字符串比较即可，无需解析构造 DateTime（省去异常与边界处理）。
    private static func purgeExpiredLogs(configured: String): Unit {
        if (Config.logRetentionDays <= 0) {
            return
        }
        let p = Path(configured)
        let dir = p.parent.toString()
        if (dir.isEmpty() || !exists(dir)) {
            return
        }
        let prefix = "${p.fileNameWithoutExtension}-"
        let cutoff = (DateTime.now() - Duration.day * Config.logRetentionDays).format("yyyyMMdd-HHmmss")
        try {
            for (entry in Directory.readFrom(dir)) {
                let name = entry.name
                if (!name.startsWith(prefix) || !name.endsWith(".log")) {
                    continue
                }
                match (extractTimestampToken(name, prefix)) {
                    case Some(ts) =>
                        if (ts < cutoff) {
                            try {
                                remove(joinPath(dir, name))
                            } catch (_: Exception) {}
                        }
                    case None => ()
                }
            }
        } catch (_: Exception) {
            // 清理是尽力而为，失败不应阻断启动
        }
    }

    /// §11.3 磁盘水位告警（Ch11.3 / task 1005）：累加本服务日志目录内模板匹配文件的字节数，
    /// 超过水位阈值时告警。
    ///
    /// 阈值来源：环境变量 `LRT_LOG_WATERMARK_BYTES`（字节），缺省 1GiB；<=0 表示关闭。
    /// 出口：LogUtils.warn（日志文件 + stderr）+ 注入的 `_watermarkAlerter`
    /// （组合根挂到宿主 LrtEventBridge，广播 monitor_alert / log_disk_watermark）。
    /// 安全约束：与清理同款模板过滤，只统计本服务产出的 `.log`；
    /// 全程 try/catch —— 水位探测失败只是少了观测，绝不能影响日志与启动。
    private static func checkDiskWatermark(configured: String): Unit {
        try {
            let limit = watermarkBytes()
            if (limit <= 0) {
                return
            }
            let p = Path(configured)
            let dir = p.parent.toString()
            if (dir.isEmpty() || !exists(dir)) {
                return
            }
            let prefix = "${p.fileNameWithoutExtension}-"
            var total: Int64 = 0
            for (entry in Directory.readFrom(dir)) {
                let name = entry.name
                if (!name.startsWith(prefix) || !name.endsWith(".log")) {
                    continue
                }
                total += entry.size
            }
            if (total <= limit) {
                return
            }
            let msg = "日志目录占用 ${total} 字节，超过水位阈值 ${limit} 字节（目录 ${dir}）"
            warn("[log-watermark] ${msg}")
            match (_watermarkAlerter) {
                case Some(alert) =>
                    try {
                        alert(msg, total, limit)
                    } catch (_: Exception) {}
                case None => ()
            }
        } catch (_: Exception) {
            // 探测失败不阻断启动
        }
    }

    /// 水位阈值（字节）：`LRT_LOG_WATERMARK_BYTES` 优先，缺省 1GiB。
    private static func watermarkBytes(): Int64 {
        match (getVariable("LRT_LOG_WATERMARK_BYTES")) {
            case Some(s) =>
                if (s.isEmpty()) {
                    return DEFAULT_WATERMARK_BYTES
                }
                match (Int64.tryParse(s)) {
                    case Some(v) => return v
                    case None => return DEFAULT_WATERMARK_BYTES
                }
            case None => return DEFAULT_WATERMARK_BYTES
        }
    }

    /// 从 `<stem>-<yyyyMMdd>-<HHmmss>[-n].log` 提取 `yyyyMMdd-HHmmss` 时间戳令牌。
    /// 不符合模板（长度/字符不对）则返回 None —— 保证只匹配本服务产出的文件。
    private static func extractTimestampToken(name: String, prefix: String): Option<String> {
        if (name.size < prefix.size + 4 + 15) {
            return None
        }
        let body = name[prefix.size..name.size - 4]   // 去掉前缀与 ".log"

        // 情况一：无序号后缀。body 恰为 15 字符且形如 yyyyMMdd-HHmmss
        if (isTimestampShape(body)) {
            return Some(body)
        }
        // 情况二：带 `-n` 序号后缀。截到最后一个 '-' 之前
        // lastIndexOf 返回 Option<Int64>，需先解构出 Int64 才能用于比较/算术/切片
        match (body.lastIndexOf("-")) {
            case Some(idx) =>
                if (idx > 0) {
                    let seqPart = body[idx + 1..body.size]
                    let core = body[0..idx]
                    if (isTimestampShape(core) && isAllDigits(seqPart)) {
                        return Some(core)
                    }
                }
            case None => ()
        }
        return None
    }

    /// 校验 `yyyyMMdd-HHmmss` 形状（第 9 位是 '-'，其余为数字）
    private static func isTimestampShape(s: String): Bool {
        if (s.size != 15) {
            return false
        }
        for (i in 0..s.size) {
            let c = s[i]
            if (i == 8) {
                if (c != b'-') { return false }
            } else if (c < b'0' || c > b'9') {
                return false
            }
        }
        return true
    }

    private static func isAllDigits(s: String): Bool {
        if (s.isEmpty()) {
            return false
        }
        for (i in 0..s.size) {
            let c = s[i]
            if (c < b'0' || c > b'9') {
                return false
            }
        }
        return true
    }


    private static let NAMED_LOGGERS = HashMap<String, SimpleLogger>()

    private static func getNamedLogger(name: String): SimpleLogger {
        if (NAMED_LOGGERS.contains(name)) {
            return NAMED_LOGGERS[name]
        }
        if (!exists(Config.agentLogDir)) {
            Directory.create(Config.agentLogDir, recursive: true)
        }
        let path = Path(Config.agentLogDir).join("${name}.log")
        // Ch0.3（tasks.md 0.3）：原为 OpenMode.Write —— 会截断同名 agent 的历史日志。
        // 长程任务一轮执行跨多个回合，agent 日志是事后回溯的唯一线索，必须追加而非覆盖。
        let file = File(path, OpenMode.Append)
        let logger = buildSimpleLogger(file)
        NAMED_LOGGERS[name] = logger
        return logger
    }

    //------------------------------------------------------------

    public static func trace(msg: String): Unit {
        LOGGER.trace(msg)
    }

    public static func agentTrace(name: String, msg: String): Unit {
        let logger = getNamedLogger(name)
        logger.trace("[${name}] ${msg}")
    }

    //------------------------------------------------------------

    public static func debug(msg: String): Unit {
        LOGGER.debug(msg)
    }

    public static func agentDebug(name: String, msg: String): Unit {
        let logger = getNamedLogger(name)
        logger.debug("[${name}] ${msg}")
    }

    //------------------------------------------------------------

    public static func info(msg: String): Unit {
        LOGGER.info(msg)
    }

    public static func agentInfo(name: String, msg: String): Unit {
        let logger = getNamedLogger(name)
        logger.info("[${name}] ${msg}")
    }

    //------------------------------------------------------------

    public static func warn(msg: String): Unit {
        LOGGER.warn(msg)
    }

    public static func agentWarn(name: String, msg: String): Unit {
        let logger = getNamedLogger(name)
        logger.warn("[${name}] ${msg}")
    }

    //------------------------------------------------------------

    public static func error(msg: String): Unit {
        LOGGER.error(msg)
    }

    public static func agentError(name: String, msg: String): Unit {
        let logger = getNamedLogger(name)
        logger.error("[${name}] ${msg}")
    }
}
