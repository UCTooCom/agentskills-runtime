/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.log.LogUtils
import std.collection.HashMap
import std.time.DateTime
import std.fs.{File, Path, Directory, exists}
@When[cjc_version >= "1.0.0"]
import std.fs.OpenMode
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt, JsonArray}

/**
 * ToolAuditLog - 工具审计日志
 * 
 * 记录工具调用的详细信息，用于审计和追踪
 */
public class ToolAuditLog {
    public let timestamp: DateTime           // 时间戳
    public let userId: String                // 用户ID
    public let toolName: String              // 工具名称
    public let args: JsonObject              // 工具参数
    public let success: Bool                 // 是否成功
    public let resultSize: Int64             // 结果大小
    public let durationMs: Int64             // 执行时长(毫秒)
    public let errorMessage: ?String         // 错误信息
    public let source: String                // 调用来源 (cli/http/internal)
    public let sessionId: ?String            // 会话ID
    
    public init(
        timestamp: DateTime,
        userId: String,
        toolName: String,
        args: JsonObject,
        success: Bool,
        resultSize: Int64,
        durationMs: Int64,
        errorMessage: ?String,
        source: String,
        sessionId: ?String
    ) {
        this.timestamp = timestamp
        this.userId = userId
        this.toolName = toolName
        this.args = args
        this.success = success
        this.resultSize = resultSize
        this.durationMs = durationMs
        this.errorMessage = errorMessage
        this.source = source
        this.sessionId = sessionId
    }
    
    /**
     * 转换为JSON格式
     */
    public func toJson(): JsonObject {
        let obj = JsonObject()
        obj.put("timestamp", JsonString(timestamp.toString()))
        obj.put("userId", JsonString(userId))
        obj.put("toolName", JsonString(toolName))
        obj.put("args", args)
        obj.put("success", JsonBool(success))
        obj.put("resultSize", JsonInt(resultSize))
        obj.put("durationMs", JsonInt(durationMs))
        obj.put("source", JsonString(source))
        
        if (let Some(err) <- errorMessage) {
            obj.put("error", JsonString(err))
        }
        
        if (let Some(sid) <- sessionId) {
            obj.put("sessionId", JsonString(sid))
        }
        
        return obj
    }
    
    /**
     * 转换为JSON字符串
     */
    public func toJsonString(): String {
        toJson().toJsonString()
    }
}

/**
 * ToolAuditLogger - 工具审计日志记录器
 * 
 * 负责将审计日志写入文件
 */
public class ToolAuditLogger {
    private let logFilePath: String
    private let enabled: Bool
    private var logFile: ?File
    
    public init(logFilePath: String, enabled: Bool) {
        this.logFilePath = logFilePath
        this.enabled = enabled
        this.logFile = None
        
        if (enabled) {
            initLogFile()
        }
    }
    
    /**
     * 创建默认配置的审计日志记录器
     * logFilePath: "./logs/tool_audit.log"
     * enabled: true
     */
    public static func create(): ToolAuditLogger {
        ToolAuditLogger("./logs/tool_audit.log", true)
    }
    
    /**
     * 初始化日志文件
     */
    private func initLogFile(): Unit {
        try {
            // 确保日志目录存在
            let logDir = Path(logFilePath).parent
            if (!exists(logDir)) {
                Directory.create(logDir, recursive: true)
            }

            // 打开日志文件(追加模式)
            logFile = File(logFilePath, OpenMode.Append)
            LogUtils.info("[ToolAuditLogger] Audit log initialized: ${logFilePath}")
        } catch (e: Exception) {
            LogUtils.error("[ToolAuditLogger] Failed to initialize audit log: ${e.message}")
        }
    }
    
    /**
     * 记录审计日志
     */
    public func log(auditLog: ToolAuditLog): Unit {
        if (!enabled) {
            return
        }

        try {
            if (let Some(file) <- logFile) {
                let jsonStr = auditLog.toJsonString()
                file.write(jsonStr.toArray())
                file.write("\n".toArray())
                file.flush()
            }
        } catch (e: Exception) {
            LogUtils.error("[ToolAuditLogger] Failed to write audit log: ${e.message}")
        }
    }
    
    /**
     * 记录工具调用(简化接口)
     */
    public func logToolCall(
        userId: String,
        toolName: String,
        args: HashMap<String, JsonValue>,
        success: Bool,
        resultSize: Int64,
        durationMs: Int64
    ): Unit {
        logToolCallWithDetails(userId, toolName, args, success, resultSize, durationMs, None, "internal", None)
    }
    
    /**
     * 记录工具调用(完整接口)
     */
    public func logToolCallWithDetails(
        userId: String,
        toolName: String,
        args: HashMap<String, JsonValue>,
        success: Bool,
        resultSize: Int64,
        durationMs: Int64,
        errorMessage: ?String,
        source: String,
        sessionId: ?String
    ): Unit {
        // 将HashMap转换为JsonObject
        let argsObj = JsonObject()
        for ((key, value) in args) {
            argsObj.put(key, value)
        }
        
        let auditLog = ToolAuditLog(
            DateTime.now(),
            userId,
            toolName,
            argsObj,
            success,
            resultSize,
            durationMs,
            errorMessage,
            source,
            sessionId
        )
        
        log(auditLog)
    }
    
    /**
     * 关闭日志文件
     */
    public func close(): Unit {
        if (let Some(file) <- logFile) {
            try {
                file.close()
            } catch (e: Exception) {
                LogUtils.error("[ToolAuditLogger] Failed to close log file: ${e.message}")
            }
        }
    }
}

/**
 * ToolAuditLoggerSingleton - 审计日志记录器单例
 * 
 * 提供全局访问点
 */
public class ToolAuditLoggerSingleton {
    private static var _instance: ?ToolAuditLogger = None
    
    /**
     * 获取单例实例
     */
    public static func getInstance(): ToolAuditLogger {
        if (let Some(instance) <- _instance) {
            return instance
        }

        // 创建新实例
        let newInstance = ToolAuditLogger("./logs/tool_audit.log", true)
        _instance = Some(newInstance)
        return newInstance
    }
    
    /**
     * 初始化单例(使用自定义配置)
     */
    public static func `init`(logFilePath: String, enabled: Bool): Unit {
        _instance = Some(ToolAuditLogger(logFilePath, enabled))
    }
}
