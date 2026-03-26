/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.tool

import magic.app.services.uctoo.OperateLogService
import magic.app.models.uctoo.OperateLogPO
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt}

/**
 * ToolAuditService - 工具审计服务
 * 
 * 集成数据库审计，将工具调用记录到operate_log表
 */
public class ToolAuditService {
    private let operateLogService: OperateLogService
    
    public init(operateLogService: OperateLogService) {
        this.operateLogService = operateLogService
    }
    
    /**
     * 记录工具调用审计（异步）
     * 
     * @param userId 用户ID
     * @param toolName 工具名称
     * @param args 工具参数
     * @param success 是否成功
     * @param resultSize 结果大小
     * @param durationMs 执行时长(毫秒)
     * @param errorMessage 错误信息
     * @param source 调用来源 (cli/http/internal)
     * @param ip 客户端IP
     * @param permissionPath 工具权限路径
     */
    public func auditToolCall(
        userId: String,
        toolName: String,
        args: HashMap<String, JsonValue>,
        success: Bool,
        resultSize: Int64,
        durationMs: Int64,
        errorMessage: ?String,
        source: String,
        ip: String,
        permissionPath: String
    ): Unit {
        // 异步写入审计日志
        spawn {
            => 
            try {
                // 构建审计参数JSON
                let paramsJson = buildAuditParams(args, success, resultSize, durationMs, errorMessage)
                
                // 创建operate_log记录
                let operateLog = OperateLogPO()
                operateLog.module = "tool"
                operateLog.operate = toolName
                operateLog.route = permissionPath
                operateLog.params = paramsJson
                operateLog.ip = ip
                operateLog.method = source
                operateLog.creator = if (userId.isEmpty()) { None<String> } else { Some<String>(userId) }
                operateLog.createdAt = DateTime.now()
                operateLog.updatedAt = DateTime.now()
                operateLog.deletedAt = None<DateTime>
                
                // 写入数据库
                let result = operateLogService.create(operateLog)
                if (result.success) {
                    if (let Some(log) <- result.data) {
                        LogUtils.debug("[ToolAuditService] Audit log created: ${log.id}")
                    }
                } else {
                    LogUtils.error("[ToolAuditService] Failed to create audit log")
                }
            } catch (e: Exception) {
                LogUtils.error("[ToolAuditService] Exception: ${e.message}")
            }
        }
    }
    
    /**
     * 构建审计参数JSON
     */
    private func buildAuditParams(
        args: HashMap<String, JsonValue>,
        success: Bool,
        resultSize: Int64,
        durationMs: Int64,
        errorMessage: ?String
    ): String {
        let params = JsonObject()
        
        // 记录工具参数
        let argsObj = JsonObject()
        for ((key, value) in args) {
            argsObj.put(key, value)
        }
        params.put("args", argsObj)
        
        // 记录结果摘要
        let resultObj = JsonObject()
        resultObj.put("success", JsonBool(success))
        resultObj.put("size", JsonInt(resultSize))
        resultObj.put("durationMs", JsonInt(durationMs))
        params.put("result", resultObj)
        
        // 记录错误信息
        if (let Some(err) <- errorMessage) {
            params.put("error", JsonString(err))
        }
        
        params.toJsonString()
    }
    
    /**
     * 查询用户工具调用历史
     * 
     * @param userId 用户ID
     * @param page 页码
     * @param limit 每页数量
     * @return 操作日志列表
     */
    public func getUserToolHistory(
        userId: String,
        page: Int64,
        limit: Int64
    ): ArrayList<OperateLogPO> {
        // TODO: 实现按用户和模块查询
        // operateLogService.findByCreatorAndModule(userId, "tool", page, limit)
        ArrayList<OperateLogPO>()
    }
    
    /**
     * 查询工具调用统计
     * 
     * @param startTime 开始时间
     * @param endTime 结束时间
     * @return 统计结果
     */
    public func getToolCallStats(
        startTime: DateTime,
        endTime: DateTime
    ): HashMap<String, Int64> {
        // TODO: 实现按时间范围统计
        // operateLogService.countByModuleAndTimeRange("tool", startTime, endTime)
        HashMap<String, Int64>()
    }
}
