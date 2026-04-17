/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.error

//#region AutoCreateCode

import magic.app.core.http.HttpResponse
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import std.collection.{HashMap, ArrayList}

/**
 * ErrorHandler - 错误处理工具类
 * 
 * 提供通用的HTTP错误响应构建方法,所有表的Controller层都可使用
 * 
 * 设计原则:
 * 1. 将错误处理逻辑从Controller层提取到公共工具类
 * 2. 所有表的Controller层都可以复用这些方法
 * 3. 统一错误响应格式,提高API一致性
 */
public class ErrorHandler {
    
    /**
     * 构建错误响应
     * 
     * @param statusCode HTTP状态码
     * @param message 错误消息
     * @return HttpResponse 错误响应
     */
    public func buildErrorResponse(statusCode: Int32, message: String): HttpResponse {
        let map = HashMap<String, JsonValue>()
        map.add("error", JsonString(message))
        let body = JsonObject(map)
        
        return HttpResponse()
            .status(statusCode)
            .header("Content-Type", "application/json; charset=utf-8")
            .json(body.toString())
    }
    
    /**
     * 构建400 Bad Request错误响应
     */
    public func badRequest(message: String): HttpResponse {
        return buildErrorResponse(400, message)
    }
    
    /**
     * 构建404 Not Found错误响应
     */
    public func notFound(message: String): HttpResponse {
        return buildErrorResponse(404, message)
    }
    
    /**
     * 构建500 Internal Server Error错误响应
     */
    public func internalServerError(message: String): HttpResponse {
        return buildErrorResponse(500, message)
    }
    
    /**
     * 构建401 Unauthorized错误响应
     */
    public func unauthorized(message: String): HttpResponse {
        return buildErrorResponse(401, message)
    }
    
    /**
     * 构建403 Forbidden错误响应
     */
    public func forbidden(message: String): HttpResponse {
        return buildErrorResponse(403, message)
    }
    
    /**
     * 构建验证错误响应
     * 
     * @param errors 验证错误列表
     * @return HttpResponse 验证错误响应
     */
    public func validationError(errors: ArrayList<String>): HttpResponse {
        var errorMessages = ""
        let size = errors.size
        for (i in 0..size) {
            if (i > 0) {
                errorMessages = errorMessages + "; "
            }
            errorMessages = errorMessages + errors[i]
        }
        
        return badRequest("Validation failed: ${errorMessages}")
    }
    
    /**
     * 构建资源不存在错误响应
     * 
     * @param resourceType 资源类型
     * @param id 资源ID
     * @return HttpResponse 资源不存在错误响应
     */
    public func resourceNotFound(resourceType: String, id: String): HttpResponse {
        return notFound("${resourceType} with id '${id}' not found")
    }
    
    /**
     * 构建数据库操作错误响应
     * 
     * @param operation 操作名称
     * @param error 错误详情
     * @return HttpResponse 数据库操作错误响应
     */
    public func databaseError(operation: String, error: String): HttpResponse {
        return internalServerError("Database operation '${operation}' failed: ${error}")
    }
    
//#endregion AutoCreateCode
}
