/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LoggerAppender interface.
 */

package logcj.appender

/**
 * The main interfaces of the log component.
 */
public interface LoggerAppender {
    /**
     * Initialize logger appender.
     *
     * @param pattern log format.
     * @param property appender properties.
     */
    func initAppender(pattern: String, property: ArrayList<AppenderProperty>): Unit

    /**
     * Start print.
     */
    func start(): Unit

    /**
     * Writing logs.
     *
     * @param rec log recording.
     */
    func logWrite(rec: LogRecord): Unit

    /**
     * End print.
     */
    func close(): Unit
}
