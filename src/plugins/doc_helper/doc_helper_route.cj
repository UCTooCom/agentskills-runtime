/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.doc_helper

import magic.app.core.router.Router
import magic.log.LogUtils
import plugin_spi.{PluginRoute, ModuleRouteAnnotation}

/**
 * DocHelperRoute - 插件路由声明（PS-T014 双轨插件轨验证示例）
 *
 * 声明式路由：@ModuleRouteAnnotation 携带 basePath/表名/库名/控制器类名，
 * PluginRouteScanner 在存量 AutoRouteRegistry.registerAllRoutes() 之后
 * 反射发现本类并执行 register()（只追加，不修改存量注册）。
 *
 * table/database 为信息性声明（供审计与市场展示），控制器经
 * controllerClass 反射无参构造，服务经 DocHelperController.wiredService 接线
 */
@ModuleRouteAnnotation[
    basePath: "/api/v1/plugins/doc-helper",
    table: "doc_helper",
    database: "uctoo",
    controllerClass: "magic.plugins.doc_helper.DocHelperController"
]
public class DocHelperRoute <: PluginRoute {
    public init() {}

    /// 注册该插件模块的全部路由（只追加，不修改存量注册）
    ///
    /// router 为 Any 承载（PS-T017：PluginRoute 接口进 SPI，不得依赖宿主
    /// Router 类型），实现内转换为 Router 后注册
    public func register(router: Any, controller: Any): Unit {
        if (let r: Router <- router) {
            if (let ctrl: DocHelperController <- controller) {
                r.post("/api/v1/plugins/doc-helper/summary", { req, res =>
                    ctrl.handleSummary(req, res)
                })
                LogUtils.info("[DocHelperRoute] route registered: POST /api/v1/plugins/doc-helper/summary")
            } else {
                LogUtils.error("[DocHelperRoute] controller is not DocHelperController, skip register")
            }
        } else {
            LogUtils.error("[DocHelperRoute] router is not Router, skip register")
        }
    }
}
