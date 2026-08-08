/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LoggerAppenderReference class.
 */

package logcj.appender

/**
 * LoggerAppender reference model class.
 */
public class LoggerAppenderReference {
    //Log level default info.
    private var level: LogLevel = DEFAULT_LOG_LEVEL

    //Appender list.
    private var appenderList: ArrayList<LoggerAppender> = ArrayList<LoggerAppender>()

    /**
     * Constructor, initialize variables.
     *
     * @param level log level.
     * @param appender appender list.
     */
    public init(level: LogLevel, appenderList: ArrayList<LoggerAppender>) {
        this.level = level
        this.appenderList = appenderList
    }

    /**
     * No-parameter constructor.
     */
    public init() {}

    public func getAppenderList(): ArrayList<LoggerAppender> {
        return this.appenderList
    }

    public func setAppenderList(appenderList: ArrayList<LoggerAppender>): Unit {
        this.appenderList = appenderList
    }

    public func getLevel(): LogLevel {
        return this.level
    }

    public func setLevel(level: LogLevel): Unit {
        this.level = level
    }

    public func isDebugEnabled(): Bool {
        if (getLevel().levelName() == "DEBUG") {
            return true
        }
        return false
    }

    public func isInfoEnabled(): Bool {
        if (getLevel().levelName() == "INFO") {
            return true
        }
        return false
    }

    public func isErrorEnabled(): Bool {
        if (getLevel().levelName() == "ERROR") {
            return true
        }
        return false
    }

    public func isWarnEnabled(): Bool {
        if (getLevel().levelName() == "WARN") {
            return true
        }
        return false
    }

    public func isTraceEnabled(): Bool {
        if (getLevel().levelName() == "TRACE") {
            return true
        }
        return false
    }

    public func isFatalEnabled(): Bool {
        if (getLevel().levelName() == "FATAL") {
            return true
        }
        return false
    }

    public func isEnabled(level: LogLevel): Bool {
        var levelName = level.levelName()
        if (getLevel().levelName() == levelName) {
            return true
        }
        return false
    }
}
