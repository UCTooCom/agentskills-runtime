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

class TcpLoggerAppender <: AsyncLogger {
    private static const LOGGER_NAME = 'tcp'
    private let host: String
    private let port: UInt16
    private let sendBufSize: ?Int64
    private init(name!: String, 
                 pattern!: LogPattern, 
                 level!: LogLevel, 
                 host!: String, 
                 port!: UInt16, 
                 sendBufSize!: ?Int64,
                 output!: OutputStream){
        super(name, level, pattern, output, '${LOGGER_NAME}://${host}:${port}')
        this.host = host
        this.port = port
        this.sendBufSize = sendBufSize
    }
    public init(
        name!: String,
        pattern!: LogPattern,
        level!: LogLevel = LogLevel.INFO,
        host!: String,
        port!: UInt16,
        sendBufSize!: ?Int64
    ) {
        this(name: name, level: level, pattern: pattern, host: host, port: port, sendBufSize: sendBufSize,
             output: createSocket(host, port, sendBufSize))
    }
    protected func new(name: String): AbstractLogger {
        TcpLoggerAppender(name: name, level: super.level, pattern: super.pattern, host: this.host, port: this.port, 
                          sendBufSize: this.sendBufSize, output: super.actualOutput)
    }
    private static func createSocket(host: String, port: UInt16, sendBufSize: ?Int64) {
        let sock = TcpSocket(host, port)
        sock.keepAlive = SocketKeepAliveConfig()
        if (let Some(s) <- sendBufSize) {
            sock.sendBufferSize = s
        }
        sock
    }
    private static let appenderMap = ConcurrentHashMap<TcpLoggerParams, AbstractLogger>()
    public static func register(): Unit {
        TcpLoggerParams.register(LOGGER_NAME, appenderMap)
    }
    protected func append(level: LogLevel, message: () -> String, now: DateTime, tid: Int64, ex: Option<Exception>): Unit {
        var sock = (super.actualOutput as TcpSocket).getOrThrow()
        if (sock.isClosed()) {
            sock = createSocket(host, port, sendBufSize)
            super.actualOutput = sock
        }
        super.append(level, message, now, tid, ex)
    }
}
public class TcpLoggerParams <: BaseLoggerParams<TcpLoggerParams> {
    public TcpLoggerParams(
        level: LogLevel,
        pattern: LogPattern,
        protected let host: String,
        protected let port: UInt16,
        protected let sendBufSize: ?Int64
    ){
        super(level, pattern)
        h = HashBuilder().append(level).append(pattern).append(host).append(port).append(sendBufSize).build()
    }
    public operator func ==(that: TcpLoggerParams): Bool {
        this.h == that.h && this.level == that.level && this.pattern == that.pattern && 
        this.host == that.host && this.port == that.port && this.sendBufSize == that.sendBufSize
    }
    protected static func newParams(appender: String): TcpLoggerParams {
        var host = "127.0.0.1"
        var port = 65535u16
        if (let h <- LoggerConfig.getTcpHost(appender) && !h.isEmpty()) {
            host = h
        }
        if (let p <- LoggerConfig.getTcpPort(appender) && !p.isEmpty()) {
            port = UInt16.tryParse(p).getOrThrow {
                LogException("param port of SocketLoggerAppender must be a value of UInt16, however it is ${p}")
            }
        } else if (let Some(idx) <- host.indexOf(':')) {
            (host, port) = (host[0..idx].trimAscii(), UInt16.parse(host[idx + 1..].trimAscii()))
        }
        let sendBufSize = LoggerConfig.getTcpSendBufSize(appender)
        TcpLoggerParams(
            LoggerConfig.getLevelConf(appender),LoggerConfig.getPatternConf(appender),
            host, port, sendBufSize)
    }
    protected func newAppender(name: String): AbstractLogger {
        TcpLoggerAppender(
            name: name,
            level: level,
            pattern: pattern,
            host: host,
            port: port,
            sendBufSize: sendBufSize
        )
    }
}
let _ = TcpLoggerAppender.register()
