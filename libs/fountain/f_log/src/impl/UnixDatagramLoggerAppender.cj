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
package f_log.impl

class UnixDatagramLoggerAppender <: AsyncLogger {
    private static const LOGGER_NAME = 'unixDatagram'
    private UnixDatagramLoggerAppender(
        name!: String,
        pattern!: LogPattern,
        level!: LogLevel = LogLevel.INFO,
        output!: OutputStream,
        private let path!: String,
        private let sendTimeout!: ?Duration,
        private let bufSize!: ?Int64 = None
    ) {
        super(name, level, pattern, output, '${LOGGER_NAME}:///${path}')
    }
    public init(
        name!: String,
        pattern!: LogPattern,
        level!: LogLevel = LogLevel.INFO,
        path!: String,
        sendTimeout!: ?Duration,
        bufSize!: ?Int64 = None
    ) {
        this(name: name, level: level, pattern: pattern, output: createSocket(path, sendTimeout, bufSize), path: path, sendTimeout: sendTimeout, bufSize: bufSize)
    }
    private static func createSocket(path: String, sendTimeout: ?Duration, bufSize: ?Int64) {
        let sock = UnixDatagramOutputStream(path, sendTimeout: sendTimeout, bufSize: bufSize)
        sock
    }
    public func new(name: String): AbstractLogger {
        UnixDatagramLoggerAppender(name: name, pattern: super.pattern, level: super.level, output: super.actualOutput, path: path, sendTimeout: sendTimeout, bufSize: bufSize)
    }
    private static let appenderMap = ConcurrentHashMap<UnixDatagramLoggerParams, AbstractLogger>()
    public static func register(): Unit {
        UnixDatagramLoggerParams.register(LOGGER_NAME, appenderMap)
    }
    protected func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        var sock = (super.actualOutput as UnixDatagramOutputStream).getOrThrow()
        if (sock.isClosed()) {
            sock = createSocket(path, sendTimeout, bufSize)
            super.actualOutput = sock
        }
        super.append(level, message, now, tid, ex)
    }
}
public class UnixDatagramLoggerParams <: BaseLoggerParams<UnixDatagramLoggerParams>{
    public UnixDatagramLoggerParams(
        level: LogLevel,
        pattern: LogPattern,
        private let path: String,
        private let sendTimeout: ?Duration,
        private let bufSize: ?Int64
    ){
        super(level, pattern)
        h = HashBuilder().append(level).append(pattern).append(path).append(sendTimeout).append(bufSize).build()
    }
    public operator func ==(that: UnixDatagramLoggerParams): Bool {
        this.h == that.h && this.level == that.level && this.pattern == that.pattern && 
        this.path == that.path && this.sendTimeout == that.sendTimeout && this.bufSize == that.bufSize
    }
    protected static func newParams(appender: String): UnixDatagramLoggerParams {
        var path = "/tmp/log/unixDatagram.log"
        if (let h <- LoggerConfig.getUnixPath(appender) && !h.isEmpty()) {
            path = h
        }
        let sendTimeout = LoggerConfig.getUnixWriteTimeout(appender)
        let bufSize = LoggerConfig.getUnixBufSize(appender)
        UnixDatagramLoggerParams(
            LoggerConfig.getLevelConf(appender), LoggerConfig.getPatternConf(appender),
            path, sendTimeout, bufSize)
    }
    protected func newAppender(name: String): AbstractLogger {
        UnixDatagramLoggerAppender(
            name: name,
            level: level,
            pattern: pattern,
            path: path,
            sendTimeout: sendTimeout,
            bufSize: bufSize
        )
    }
}
let _ = UnixDatagramLoggerAppender.register()
