/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines Logger class.
 */

package logcj.logger

/**
 * Logger class, recording and outputting logs.
 */
public class Logger {
    // Logger name.
    private var name: String
    private var manager: LoggerManager

    public init(name: String, manager: LoggerManager) {
        this.name = name
        this.manager = manager
    }

    public func getName(): String {
        return this.name
    }

    /**
     * Entry for writing logs.
     *
     * @param level log level.
     * @param msg log information.
     */
    public func log(level: LogLevel, msg: String): Unit {
        // Currently, the method of obtaining the file name and line number is not available. Wait for the SDK to provide the method.
        let src = ""
        if(manager.getLoggerNameArr().contains(this.name)) {
            var rec = LogRecord(this.name, level, DateTime.now(), src, msg, Thread.currentThread.id)
            // Consider whether thread processing needs to be started.
            doLog(level, rec)
        } else {
            var rootRecord = LogRecord("root", level, DateTime.now(), src, msg, Thread.currentThread.id)
            appendLog(level, rootRecord, manager.getRootLogger())
        }
    }

    /**
     * Writing Logs.
     *
     * @param level log level.
     * @param rec log record.
     */
    private func doLog(level: LogLevel, rec: LogRecord): Unit {
        // If there are logs other than root in the configuration, to Print.
        var values: HashMap<String, LoggerAppenderReference> = manager.getLoggerArr()
        appendLog(level, rec, values[this.name])
    }

    /**
     * Append log.
     *
     * @param level log level.
     * @param rec log record.
     * @param appenderRef log appender-ref.
     */
    private func appendLog(level: LogLevel, rec: LogRecord, appenderRef: LoggerAppenderReference): Unit {
        if (appenderRef.getAppenderList().size == 0) {
            return
        }

        if (level >= appenderRef.getLevel()) {
            var i: Int64 = 0
            while (i < appenderRef.getAppenderList().size) {
                var appender: LoggerAppender = appenderRef.getAppenderList().get(i).getOrThrow()
                appender.logWrite(rec)
                i++
            }
        }
    }

    // 在所有日志写完后结束文件写入
    public func closeWriteFile(): Unit {
        var values: HashMap<String, LoggerAppenderReference> = manager.getLoggerArr()
        var appenderRef = values[this.name]
        if (appenderRef.getAppenderList().size == 0) {
            return
        }

        var i: Int64 = 0
        while (i < appenderRef.getAppenderList().size) {
            var appender: LoggerAppender = appenderRef.getAppenderList().get(i).getOrThrow()
            appender.close()
            i++
        }
    }

    /**
     * Print critical log.
     *
     * @param msg log information.
     */
    public func off(msg: String): Unit {
        log(OFF, msg)
    }

    /**
     * Print fatal log.
     *
     * @param msg log information.
     */
    public func fatal(msg: String): Unit {
        log(FATAL, msg)
    }

    /**
     * Print error log.
     *
     * @param msg log information.
     */
    public func error(msg: String): Unit {
        log(ERROR, msg)
    }

    /**
     * Print warn log.
     *
     * @param msg log information.
     */
    public func warn(msg: String): Unit {
        log(WARN, msg)
    }

    /**
     * Print info log.
     *
     * @param msg log inoformation.
     */
    public func info(msg: String): Unit {
        log(INFO, msg)
    }

    /**
     * Print debug log.
     *
     * @param msg log inoformation.
     */
    public func debug(msg: String): Unit {
        log(DEBUG, msg)
    }

    /**
     * Print trace log.
     *
     * @param msg log information.
     */
    public func trace(msg: String): Unit {
        log(TRACE, msg)
    }

    /**
     * Print fine log.
     *
     * @param msg log information.
     */
    public func all(msg: String): Unit {
        log(ALL, msg)
    }
}
