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

class UnixLoggerAppender <: AsyncLogger {
    private static const LOGGER_NAME = 'unix'
    private UnixLoggerAppender(
        name!: String,
        pattern!: LogPattern,
        level!: LogLevel = LogLevel.INFO,
        output!: OutputStream,
        private let path!: String,
        private let writeTimeout!: ?Duration,
        private let bufSize!: ?Int64
    ){
        super(name, level, pattern, output, '${LOGGER_NAME}:///${path}')
    }
    public init(
        name!: String,
        pattern!: LogPattern,
        level!: LogLevel = LogLevel.INFO,
        path!: String,
        writeTimeout!: ?Duration,
        bufSize!: ?Int64
    ) {
        this(name: name, level: level, pattern: pattern, output: createSocket(path, writeTimeout, bufSize), 
             path: path, writeTimeout: writeTimeout, bufSize: bufSize)
    }
    public func new(name: String): AbstractLogger {
        UnixLoggerAppender(name: name, pattern: super.pattern, level: super.level, output: super.actualOutput, path: path, writeTimeout: writeTimeout, bufSize: bufSize)
    }
    private static func createSocket(path: String, writeTimeout: ?Duration, bufSize: ?Int64) {
        let sock = UnixSocket(path)
        sock.writeTimeout = writeTimeout
        if (let Some(s) <- bufSize) {
            sock.sendBufferSize = s
        }
        sock
    }
    private static let appenderMap = ConcurrentHashMap<UnixLoggerParams, AbstractLogger>()
    public static func register(): Unit {
        UnixLoggerParams.register(LOGGER_NAME, appenderMap)
    }
    protected func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        var sock = (super.actualOutput as UnixSocket).getOrThrow()
        if (sock.isClosed()) {
            sock = createSocket(path, writeTimeout, bufSize)
            super.actualOutput = sock
        }
        super.append(level, message, now, tid, ex)
    }
}
public class UnixLoggerParams <: BaseLoggerParams<UnixLoggerParams> {
    public UnixLoggerParams(
        level: LogLevel,
        pattern: LogPattern,
        private let path: String,
        private let writeTimeout: ?Duration,
        private let bufSize: ?Int64
    ){
        super(level, pattern)
        h = HashBuilder().append(level).append(pattern).append(path).append(writeTimeout).append(bufSize).build()
    }
    public operator func ==(that: UnixLoggerParams): Bool {
        this.h == that.h && this.level == that.level && this.pattern == that.pattern && 
        this.path == that.path && this.writeTimeout == that.writeTimeout && this.bufSize == that.bufSize
    }
    protected static func newParams(appender: String): UnixLoggerParams {
        var path = "/tmp/log/unix.log"
        if (let h <- LoggerConfig.getUnixPath(appender) && !h.isEmpty()) {
            path = h
        }
        let writeTimeout = LoggerConfig.getUnixWriteTimeout(appender)
        let bufSize = LoggerConfig.getUnixBufSize(appender)
        UnixLoggerParams(
            LoggerConfig.getLevelConf(appender), LoggerConfig.getPatternConf(appender),
            path, writeTimeout, bufSize)
    }
    protected func newAppender(name: String): AbstractLogger {
        UnixLoggerAppender(
            name: name,
            level: level,
            pattern: pattern,
            path: path,
            writeTimeout: writeTimeout,
            bufSize: bufSize
        )
    }
}
let _ = UnixLoggerAppender.register()
