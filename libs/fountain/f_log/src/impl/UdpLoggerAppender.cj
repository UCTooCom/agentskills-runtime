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

class UdpLoggerAppender <: AsyncLogger {
    private static const LOGGER_NAME = 'udp'
    private let host: String
    private let port: UInt16
    private let sendTimeout: ?Duration
    private init(
        name!: String,
        level!: LogLevel,
        pattern!: LogPattern,
        host!: String,
        port!: UInt16,
        sendTimeout!: ?Duration,
        output!: OutputStream
    ){
        super(name, level, pattern, output, '${LOGGER_NAME}://${host}:${port}')
        this.host = host
        this.port = port
        this.sendTimeout = sendTimeout
    }
    public init(
        name!: String,
        pattern!: LogPattern,
        level!: LogLevel = LogLevel.INFO,
        host!: String,
        port!: UInt16,
        sendTimeout!: ?Duration
    ) {
        this(name: name, level: level, pattern: pattern, host: host, port: port, sendTimeout: sendTimeout,
              output: createSocket(host, port, sendTimeout: sendTimeout))
    }
    public func new(name: String): AbstractLogger {
        UdpLoggerAppender(name: name, pattern: super.pattern, level: super.level, host: host, port: port, sendTimeout: sendTimeout, output: super.actualOutput)
    }
    private static func createSocket(host: String, port: UInt16, sendTimeout!: ?Duration) {
        let sock = UdpOutputStream(host, port, sendTimeout: sendTimeout)
        sock
    }
    private static let appenderMap = ConcurrentHashMap<UdpLoggerParams, AbstractLogger>()
    public static func register(): Unit {
        UdpLoggerParams.register(LOGGER_NAME, appenderMap)
    }
    protected func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        var sock = (super.actualOutput as UdpOutputStream).getOrThrow()
        if (sock.isClosed()) {
            sock = createSocket(host, port, sendTimeout: sendTimeout)
            super.actualOutput = sock
        }
        super.append(level, message, now, tid, ex)
    }
}
public class UdpLoggerParams <: BaseLoggerParams<UdpLoggerParams> {
    public UdpLoggerParams(
        level: LogLevel,
        pattern: LogPattern,
        protected let host: String,
        protected let port: UInt16,
        protected let sendTimeout: ?Duration
    ){
        super(level, pattern)
        h = HashBuilder().append(level).append(pattern).append(host).append(port).append(sendTimeout).build()
    }
    public operator func ==(that: UdpLoggerParams): Bool {
        this.h == that.h && this.level == that.level && this.pattern == that.pattern && 
        this.host == that.host && this.port == that.port && this.sendTimeout == that.sendTimeout
    }
    protected static func newParams(appender: String): UdpLoggerParams {
        var host = "127.0.0.1"
        var port = 65534u16
        if (let h <- LoggerConfig.getUdpHost(appender) && !h.isEmpty()) {
            host = h
        }
        if (let p <- LoggerConfig.getUdpPort(appender)) {
            port = UInt16.tryParse(p).getOrThrow {
                LogException("param port of SocketLoggerAppender must be a value of UInt16, however it is ${p}")
            }
        } else if (let Some(idx) <- host.indexOf(':')) {
            (host, port) = (host[0..idx].trimAscii(), UInt16.parse(host[idx + 1..].trimAscii()))
        }
        let sendTimeout = LoggerConfig.getUdpSendTimeout(appender)
        UdpLoggerParams(
            LoggerConfig.getLevelConf(appender), LoggerConfig.getPatternConf(appender),
            host, port, sendTimeout)
    }
    protected func newAppender(name: String): AbstractLogger {
        UdpLoggerAppender(
            name: name,
            level: level,
            pattern: pattern,
            host: host,
            port: port,
            sendTimeout: sendTimeout
        )
    }
}
let _ = UdpLoggerAppender.register()