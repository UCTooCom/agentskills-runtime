/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package plugin_spi

import std.reflect.Annotation

/**
 * ModuleRouteAnnotation - 插件路由声明注解（@ModuleRoute）
 *
 * 插件轨路由的声明载体（design.md §2.8 双轨路由）：PluginRouteScanner
 * 在存量 AutoRouteRegistry 注册完成后，按本注解反射实例化 Route 类与
 * Controller 类并追加注册（只追加，不修改存量注册）。
 *
 * 语法参照存量 @AutoRoute（@Annotation + const init + let 字段模式）。
 *
 * PS-T017 迁移说明：自 magic.plugin 迁入 SPI。注解字段全为 String，
 * 零宿主依赖；PluginRoute 接口的 router 参数为 Any 承载（SPI 不得依赖
 * 宿主 Router 类型），Route 实现内部转换为目标 Router 类型。
 *
 * 使用示例：
 * ```cangjie
 * @ModuleRouteAnnotation[
 *     basePath: "/api/v1/plugins/doc-helper",
 *     table: "doc",
 *     database: "uctoo",
 *     controllerClass: "magic.plugins.doc_helper.DocHelperController"
 * ]
 * public class DocHelperRoute <: PluginRoute {
 *     public func register(router: Any, controller: Any): Unit { ... }
 * }
 * ```
 */
@Annotation
public class ModuleRouteAnnotation {
    /// 路由前缀，如 "/api/v1/plugins/doc-helper"
    public let basePath: String

    /// 数据库表名（信息性，供审计/市场展示）
    public let table: String

    /// 数据库名，如 "uctoo"
    public let database: String

    /// 控制器全限定类名（PluginRouteScanner 反射实例化用）
    public let controllerClass: String

    public const init(
        basePath!: String,
        table!: String,
        database!: String,
        controllerClass!: String
    ) {
        this.basePath = basePath
        this.table = table
        this.database = database
        this.controllerClass = controllerClass
    }
}

/**
 * PluginRoute - 插件路由统一接口
 *
 * PluginRouteScanner 反射实例化 Route 类后按本接口调用 register；
 * controller 为注解 controllerClass 反射实例化的控制器（Any 承载，
 * 由具体 Route 实现内转换为目标控制器类型，转换失败记日志不注册）。
 *
 * router 同样为 Any 承载（宿主 Router 类型不进 SPI）；实现内转换：
 * `if (let r: Router <- router) { ... }`，转换失败记日志。
 */
public interface PluginRoute {
    /// 注册该插件模块的全部路由（只追加，不修改存量注册）
    func register(router: Any, controller: Any): Unit
}
