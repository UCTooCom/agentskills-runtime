/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package skill_{{name}}

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.router.Router
import magic.log.LogUtils
import plugin_spi.{PluginRoute, ModuleRouteAnnotation}

/**
 * {{aggregateClassName}}Route - {{name}} 插件聚合路由（plugingen 生成，多表模式）
 *
 * 声明式路由聚合：本类在 config/plugins.yaml 中作为唯一 routeClass 被 PluginRouteScanner 注册。
 * register() 内部循环装配所有表的 Controller 并委托各表 Route().register(...)
 * 注册其 8 条 V4 CRUD 路由（各表路由逻辑保留在各自的 Route 文件中，便于二次开发）。
 *
 * 各表路由表（遵循 uctoo V4 API 规范）：
 *   POST /api/v1/{{dbName}}/<table>/add
 *   POST /api/v1/{{dbName}}/<table>/edit
 *   POST /api/v1/{{dbName}}/<table>/del
 *   POST /api/v1/{{dbName}}/<table>/empty-recycle-bin
 *   GET  /api/v1/{{dbName}}/<table>/:id
 *   GET  /api/v1/{{dbName}}/<table>/:limit/:page
 *   GET  /api/v1/{{dbName}}/<table>/:limit/:page/:skip
 *   GET  /api/v1/{{dbName}}/<table>/export
 */
@ModuleRouteAnnotation[
    basePath: "/api/v1/{{dbName}}",
    table: "{{name}}",
    database: "{{dbName}}",
    controllerClass: "skill_{{name}}.{{firstControllerClass}}"
]
public class {{aggregateClassName}}Route <: PluginRoute {
    public init() {}

    /// 注册该插件模块的全部路由（循环委托各表 Route 注册，只追加，不修改存量注册）
    ///
    /// router 为 Any 承载（PS-T017：PluginRoute 接口进 SPI，不得依赖宿主
    /// Router 类型），实现内转换为 Router 后逐表注册。
    public func register(router: Any, controller: Any): Unit {
        if (let r: Router <- router) {
{{routeRegisterBody}}
        } else {
            LogUtils.error("[{{aggregateClassName}}Route] router is not Router, skip register")
        }
    }

//#endregion AutoCreateCode
// ========== 定制开发区域（在此区域添加自定义路由）==========
}
