/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.middlewares

import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.core.middleware.Middleware
import magic.log.LogUtils
import std.env.getVariable

/**
 * CORSMiddleware - CORS 跨域支持中间件
 * 
 * 允许前端跨域访问后端 API
 */
public class CORSMiddleware <: Middleware {
    private let frontendUrl: String
    private let isProduction: Bool
    
    public init() {
        // 从环境变量读取配置
        let envOpt = getVariable("NODE_ENV")
        this.isProduction = if (let Some(env) <- envOpt) {
            env == "production"
        } else {
            false
        }
        
        let frontendUrlOpt = getVariable("FRONTEND_URL")
        this.frontendUrl = if (let Some(url) <- frontendUrlOpt) {
            url
        } else {
            "http://localhost:3031"  // 默认前端地址
        }
        
        LogUtils.info("CORSMiddleware initialized: isProduction=${isProduction}, frontendUrl=${frontendUrl}")
    }
    
    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        // 设置 CORS 头
        let allowOrigin = if (isProduction) {
            frontendUrl
        } else {
            "*"  // 开发环境允许所有来源
        }
        
        res.header("Access-Control-Allow-Origin", allowOrigin)
        res.header("Access-Control-Allow-Credentials", "true")
        res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
        res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization, x-lang")
        res.header("Access-Control-Max-Age", "86400")  // 预检请求缓存 24 小时
        
        // 处理 OPTIONS 预检请求
        if (req.method == HttpMethod.OPTIONS) {
            LogUtils.info("CORS: Handling OPTIONS preflight request")
            res.status(200)
            res.send("")
            return
        }
        
        // 继续处理请求
        next()
    }
}
