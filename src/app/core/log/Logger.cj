package magic.app.core.log

import std.time.DateTime
import std.sync.ReentrantMutex
import std.collection.HashMap
import std.collection.ArrayList
import std.console.Console

public enum LogLevel {
    | ALL
    | TRACE
    | DEBUG
    | INFO
    | WARN
    | ERROR
    | FATAL
    | OFF
    
    public func level(): Int64 {
        match (this) {
            case ALL => 0
            case TRACE => 1
            case DEBUG => 2
            case INFO => 3
            case WARN => 4
            case ERROR => 5
            case FATAL => 6
            case OFF => 7
        }
    }

    public static func fromString(level: String): LogLevel {
        match (level) {
            case "ALL" | "all" => ALL
            case "TRACE" | "trace" => TRACE
            case "DEBUG" | "debug" => DEBUG
            case "INFO" | "info" => INFO
            case "WARN" | "warn" | "WARNING" | "warning" => WARN
            case "ERROR" | "error" => ERROR
            case "FATAL" | "fatal" => FATAL
            case "OFF" | "off" => OFF
            case _ => INFO
        }
    }
}

public class LogRecord {
    public var name: String
    public var level: LogLevel
    public var timestamp: DateTime
    public var source: String
    public var message: String
    public var threadId: Int64
    
    public init(
        name: String,
        level: LogLevel,
        timestamp: DateTime,
        source: String,
        message: String,
        threadId: Int64
    ) {
        this.name = name
        this.level = level
        this.timestamp = timestamp
        this.source = source
        this.message = message
        this.threadId = threadId
    }
}

public interface LogAppender {
    func append(record: LogRecord): Unit
    func flush(): Unit
    func close(): Unit
}

public class ConsoleAppender <: LogAppender {
    private var pattern: String = "[%D %T] [%L] [%N] %M"
    
    public init() {}
    
    public init(pattern: String) {
        this.pattern = pattern
    }
    
    public func append(record: LogRecord): Unit {
        let formatted = formatPattern(record)
        println(formatted)
    }
    
    public func flush(): Unit {}
    
    public func close(): Unit {}
    
    private func formatPattern(record: LogRecord): String {
        var result = pattern
        result = result.replace("%D", record.timestamp.format("yyyy-MM-dd"))
        result = result.replace("%T", record.timestamp.format("HH:mm:ss"))
        result = result.replace("%L", levelToString(record.level))
        result = result.replace("%N", record.name)
        result = result.replace("%M", record.message)
        result = result.replace("%I", record.threadId.toString())
        return result
    }
    
    private func levelToString(level: LogLevel): String {
        match (level) {
            case ALL => "ALL"
            case TRACE => "TRACE"
            case DEBUG => "DEBUG"
            case INFO => "INFO"
            case WARN => "WARN"
            case ERROR => "ERROR"
            case FATAL => "FATAL"
            case OFF => "OFF"
        }
    }
}

public class Logger {
    private var name: String
    private var level: LogLevel = LogLevel.INFO
    private var appenders: ArrayList<LogAppender> = ArrayList<LogAppender>()
    private let mutex = ReentrantMutex()
    
    public init(name: String) {
        this.name = name
    }
    
    public func setLevel(level: LogLevel): Logger {
        this.level = level
        return this
    }
    
    public func addAppender(appender: LogAppender): Logger {
        return this
    }
    
    public func getName(): String {
        return name
    }
    
    public func log(level: LogLevel, message: String): Unit {
        if (level.level() < this.level.level()) {
            return
        }
        
        let record = LogRecord(
            name,
            level,
            DateTime.now(),
            "",
            message,
            0
        )
        
        synchronized(mutex) {
            for (appender in appenders) {
                appender.append(record)
            }
        }
    }
    
    public func trace(message: String): Unit {
        log(LogLevel.TRACE, message)
    }
    
    public func debug(message: String): Unit {
        log(LogLevel.DEBUG, message)
    }
    
    public func info(message: String): Unit {
        log(LogLevel.INFO, message)
    }
    
    public func warn(message: String): Unit {
        log(LogLevel.WARN, message)
    }
    
    public func error(message: String): Unit {
        log(LogLevel.ERROR, message)
    }
    
    public func fatal(message: String): Unit {
        log(LogLevel.FATAL, message)
    }
    
    public func error(message: String, ex: Exception): Unit {
        log(LogLevel.ERROR, "${message}: ${ex.message}")
    }
}

public class LoggerFactory {
    private static var instance: ?LoggerFactory = None<LoggerFactory>
    private var loggers: HashMap<String, Logger> = HashMap<String, Logger>()
    private let mutex = ReentrantMutex()
    private var rootLogger: Logger
    
    private init() {
        rootLogger = Logger("root")
        rootLogger.addAppender(ConsoleAppender())
    }
    
    public static func getInstance(): LoggerFactory {
        if (let Some(instance_val) <- instance) {
            return instance_val
        }
        let new_instance = LoggerFactory()
        instance = Some(new_instance)
        return new_instance
    }
    
    public func getLogger(name: String): Logger {
        synchronized(mutex) {
            if (let Some(logger) <- loggers.get(name)) {
                return logger
            }
            
            let logger = Logger(name)
            logger.setLevel(LogLevel.INFO)
            logger.addAppender(ConsoleAppender())
            loggers[name] = logger
            return logger
        }
    }
    
    public func getLogger(name: String, level: LogLevel): Logger {
        let logger = getLogger(name)
        logger.setLevel(level)
        return logger
    }
    
    public func getRootLogger(): Logger {
        return rootLogger
    }
}
