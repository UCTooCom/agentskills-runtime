/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LogRecord class.
 */

package logcj.utils

/**
 * Log recording model class.
 */
public class LogRecord {
    // Tag name, which class or file printed
    private var tagName: String = ""

    // Log level, default value: INFO.
    private var level: LogLevel = DEFAULT_LOG_LEVEL

    // Time when the log record is created.
    private var createdTime: DateTime

    // Log source, which is used to print log location information,for example, the line where the code is located.
    private var source: String = ""

    // Log information, which is printed.
    private var message: String = ""

    // Log information, Thread id
    private var threadId: Int64 = -1

    /**
     * Constructor, initialize variables.
     *
     * @param tagName tag name.
     * @param level log level.
     * @param createdTime create time.
     * @param source source.
     * @param message message.
     */
    public init(tagName: String, level: LogLevel, createdTime: DateTime, source: String, message: String, threadId: Int64) {
        this.tagName = tagName
        this.level = level
        this.createdTime = createdTime
        this.source = source
        this.message = message
        this.threadId = threadId
    }

    /**
     * Constructor, initialize variables.
     *
     * @param createdTime create time.
     */
    public init(createdTime: DateTime) {
        this.createdTime = createdTime
    }

    public func getTagName(): String {
        return this.tagName
    }

    public func getLevel(): LogLevel {
        return this.level
    }

    public func getSource(): String {
        return this.source
    }

    public func getMessage(): String {
        return this.message
    }

    public func getCreatedTime(): DateTime {
        return this.createdTime
    }

    public func getThreadId(): Int64 {
        return this.threadId
    }
}
