/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LogLevel enumeration class.
 */

package logcj.utils

public let DEFAULT_LOG_LEVEL = LogLevel.INFO

/**
 * Log print level.
 */
public enum LogLevel {
    | ALL // Open log.
    | TRACE // Track information.
    | DEBUG // Debug information
    | INFO // Notification information.
    | WARN // Warning message.
    | ERROR // Error message.
    | FATAL // Critical error. 
    | OFF // Disabling logs.

    /**
     * Get the log level.
     *
     * @return number corresponding to the log level.
     */
    public func level(): Int64 {
        let num = match (this) {
            case ALL => 1
            case TRACE => 2
            case DEBUG => 3
            case INFO => 4
            case WARN => 5
            case ERROR => 6
            case FATAL => 7
            case OFF => 8
        }
        return num
    }

    /**
     * Get the log level name.
     *
     * @return character string corresponding to the log level.
     */
    public func levelName(): String {
        let name = match (this) {
            case ALL => "ALL"
            case TRACE => "TRACE"
            case DEBUG => "DEBUG"
            case INFO => "INFO"
            case WARN => "WARN"
            case ERROR => "ERROR"
            case FATAL => "FATAL"
            case OFF => "OFF"
        }
        return name
    }

    /**
     * reload the >= opreator
     *
     * @param target log level to be compared.
     * @return boolean value for comparing two log levels.
     */
    public operator func >=(target: LogLevel): Bool {
        return this.level() >= target.level()
    }

    /**
     * Get the log level string based on the input parameters.
     *
     * @param lable log level name
     * @return character string corresponding to the log level.
     */
    public static func getLevelByString(lable: String): LogLevel {
        let level = match (lable.toAsciiUpper()) {
            case "ALL" => ALL
            case "TRACE" => TRACE
            case "DEBUG" => DEBUG
            case "INFO" => INFO
            case "WARN" => WARN
            case "ERROR" => ERROR
            case "FATAL" => FATAL
            case "OFF" => OFF
            case _ => DEFAULT_LOG_LEVEL
        }
        return level
    }
}
