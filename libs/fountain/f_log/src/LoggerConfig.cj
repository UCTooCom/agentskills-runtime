/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_log

import std.sync.AtomicReference
import std.convert.Parsable
import stdx.log.LogLevel
import f_config.Config
import f_data.*
import f_log.exception.LogException

/**
 *
 */
public class LoggerConfig {
    //所有的appender配置项都是fountain_logger_appender_${appenderName}_${confItem}
    //confItem 可以是level pattern 等，还可以有Appender特有配置项
    private static const confPrefix = "logger"
    public static const appender = "appender"
    private static let filter_ = AtomicReference<Box<LogFilter>>(Box(DummyLogFilter.instance))

    private init() {
    }
    static init() {
        Config.refresher(confPrefix, LoggerFactory.refresh)
    }
    public static mut prop filter: LogFilter {
        get(){
            filter_.load().value
        }
        set(value){
            filter_.store(Box(value))
        }
    } 
    public static func createFacade(name: String): LoggerAppenderFacade {
        LoggerAppenderCreator.create(name)
    }

    public static func getString(appender: String, item: String): Option<String> {
        Config.getString("${confPrefix}_${appender}_${item}")
    }
    public static func getAppenders(kind: String): Array<String> {
        if (let Some(appenders) <- getString(appender, kind)) {
            appenders.split(",")
        } else {
            []
        }
    }
    private static func appenderKeyPart(appender: String) {
        '${LoggerConfig.appender}_${appender}'
    }
    public static func getLevelConf(appender: String): LogLevel {
        if (let Some(level) <- getString(appenderKeyPart(appender), "level")) {
            return convertLevel(level)
        }
        return LogLevel.INFO
    }
    public static func getPatternConf(appender: String): LogPattern {
        if (let Some(p) <- getString(appenderKeyPart(appender), "pattern")) {
            return LogPattern(p)
        }
        return LogPattern.default
    }
    public static func getLogFilePath(appender: String): String {
        getString(appenderKeyPart(appender), "path") ?? ''
    }
    public static func getLogFileRotateDuration(appender: String): String {
        getString(appenderKeyPart(appender), "rotateDuration") ?? "DAY"
    }
    public static func getLogFileRotateSize(appender: String): String {
        getString(appenderKeyPart(appender), "rotateSize") ?? "${Int64.Max}"
    }
    public static func getLogFileCompressFormat(appender: String): String {
        getString(appenderKeyPart(appender), "compressFormat") ?? ""
    }
    public static func getLogFileMMap(appender: String): Bool {
        Bool.parse((getString(appenderKeyPart(appender), "mmap") ?? 'false').trimAscii().toAsciiLower())
    }
    public static func getTcpHost(appender: String): String {
        getString(appenderKeyPart(appender), "host") ?? ""
    }
    public static func getTcpPort(appender: String): String {
        getString(appenderKeyPart(appender), "port") ?? ""
    }
    public static func getUdpHost(appender: String): String {
        getString(appenderKeyPart(appender), "host") ?? ""
    }
    public static func getUdpPort(appender: String): String {
        getString(appenderKeyPart(appender), "port") ?? ""
    }
    public static func getAsyncBufSize(): Int64 {
        Config.getData<Int64>("loggerAsyncBufsize") ?? 1024
    }
    public static func getAsyncTimeout(): Duration {
        if (let Some(d) <- Config.getString("loggerAsyncTimeout")) {
            Duration.tryParse(d).getOrThrow {LogException("illegal async timeout duration ${d}")}
        } else {
            Duration.Max
        }
    }
    public static func getAsyncTimeoutPolicy(): AsyncTimeoutPolicy {
        if (let Some(p) <- Config.getString("loggerAsyncTimeoutPolicy")) {
            match (p.toAsciiLower()) {
                case "discard" => Discard
                case "abort" => Abort
                case _ => AlwaysWaiting
            }
        } else {
            Discard
        }
    }
    public static func getUdpSendTimeout(appender: String): ?Duration {
        if (let Some(d) <- getString(appenderKeyPart(appender), "sendTimeout")) {
            Duration
                .tryParse(d)
                .getOrThrow {LogException("${d} is an illegal duration string for ${appender} udp sendTimeout")}
        } else {
            None<Duration>
        }
    }
    public static func getUnixWriteTimeout(appender: String): ?Duration {
        if (let Some(d) <- getString(appenderKeyPart(appender), "writeTimeout")) {
            Duration
                .tryParse(d)
                .getOrThrow {LogException("${d} is an illegal duration string for ${appender} unix writeTimeout")}
        } else {
            None<Duration>
        }
    }
    public static func getUnixPath(appender: String): String {
        getString(appenderKeyPart(appender), "path") ?? ""
    }
    public static func getTcpSendBufSize(appender: String): ?Int64 {
        if (let Some(s) <- getString(appenderKeyPart(appender), "bufSize")) {
            Int64
                .tryParse(s)
                .getOrThrow {LogException("${s} is an illegal duration string for ${appender} tcp sendBufSize")}
        } else {
            None<Int64>
        }
    }
    public static func getUnixBufSize(appender: String): ?Int64 {
        if (let Some(s) <- getString(appenderKeyPart(appender), "bufSize")) {
            Int64
                .tryParse(s)
                .getOrThrow {LogException("${s} is an illegal duration string for ${appender} unix sendBufSize")}
        } else {
            None<Int64>
        }
    }
    private static func convertLevel(level: String): LogLevel {
        match (level.toAsciiUpper()) {
            case "OFF" => LogLevel.OFF
            case "ERROR" => LogLevel.ERROR
            case "WARN" => LogLevel.WARN
            case "INFO" => LogLevel.INFO
            case "DEBUG" => LogLevel.DEBUG
            case "TRACE" => LogLevel.TRACE
            case "ALL" => LogLevel.ALL
            case _ => LogLevel.INFO
        }
    }
}
