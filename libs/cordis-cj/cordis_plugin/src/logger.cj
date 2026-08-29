package ystyle::cordis_plugin

import ystyle::cordis_core.LogLevel

/**
 * 命名日志器（docs/cordis-comparison.md §4 命名 Logger，对齐 Cordis `ctx.logger(name)`）
 *
 * `ctx.logger("db")` 返回本对象：所有日志经宿主 log 通知，带 logger 名称，
 * 宿主侧可按来源区分（如 "[db] info: ..."）。
 *
 * ```cangjie
 * let logger = ctx.logger("db")
 * logger.info("connected")        // host 收到 LogParams(INFO, "connected", logger="db")
 * logger.debug("query ${sql}")
 * ```
 */
public class PluginLogger {
    public let name: String
    private let send: (String, String, String) -> Unit   // (name, level, message)

    internal init(name: String, send: (String, String, String) -> Unit) {
        this.name = name
        this.send = send
    }

    public func trace(message: String): Unit {
        this.send(this.name, LogLevel.TRACE, message)
    }

    public func debug(message: String): Unit {
        this.send(this.name, LogLevel.DEBUG, message)
    }

    public func info(message: String): Unit {
        this.send(this.name, LogLevel.INFO, message)
    }

    public func warn(message: String): Unit {
        this.send(this.name, LogLevel.WARN, message)
    }

    public func error(message: String): Unit {
        this.send(this.name, LogLevel.ERROR, message)
    }
}
