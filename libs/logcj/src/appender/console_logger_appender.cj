/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines ConsoleLoggerAppender class.
 */

package logcj.appender

/**
 * The specific implementation class of LoggerAppender, which enables the console to print logs.
 */
public class ConsoleLoggerAppender <: LoggerAppender {
    private var pattern: String = ""

    /**
     * Initialize console logger appender.
     *
     * @param pattern log format.
     * @param property console appender properties.
     */
    public func initAppender(pattern: String, property: ArrayList<AppenderProperty>): Unit {
        if (pattern.size == 0) {
            this.pattern = "[%T %D %m] [%L] [%I] [%l] (%S) %M"
        } else {
            this.pattern = pattern
        }
    }

    /**
     * Start print.
     */
    public func start(): Unit {}

    /**
     * Formatting and printting logs.
     *
     * @param rec log recording.
     */
    public func logWrite(rec: LogRecord): Unit {
        print(getDefaultPatternConvert().formatLogRecord(pattern, rec).replace("\"", ""))
    }

    /**
     * End print.
     */
    public func close(): Unit {}
}
