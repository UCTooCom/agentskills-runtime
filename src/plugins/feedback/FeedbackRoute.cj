/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.feedback

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.router.Router
import magic.log.LogUtils
import plugin_spi.{PluginRoute, ModuleRouteAnnotation}

/**
 * FeedbackRoute - 插件路由声明（双轨插件轨，plugingen 生成）
 *
 * 声明式路由：@ModuleRouteAnnotation 携带 basePath/表名/库名/控制器类名，
 * PluginRouteScanner 在存量 AutoRouteRegistry.registerAllRoutes() 之后
 * 反射发现本类并执行 register()（只追加，不修改存量注册）。
 *
 * 路由表（遵循 uctoo V4 API 规范，与宿主轨 AutoRouteConfig 约定一致）：
 *   POST /api/v1/uctoo/feedback/add               创建
 *   POST /api/v1/uctoo/feedback/edit               更新（含批量/恢复）
 *   POST /api/v1/uctoo/feedback/del                删除（含批量，软删/硬删）
 *   POST /api/v1/uctoo/feedback/empty-recycle-bin  清空回收站
 *   GET  /api/v1/uctoo/feedback/:id               单条查询
 *   GET  /api/v1/uctoo/feedback/:limit/:page      分页列表
 *   GET  /api/v1/uctoo/feedback/:limit/:page/:skip 分页列表（带跳过）
 *   GET  /api/v1/uctoo/feedback/export             导出 CSV
 */
@ModuleRouteAnnotation[
    basePath: "/api/v1/uctoo/feedback",
    table: "feedback",
    database: "uctoo",
    controllerClass: "magic.plugins.feedback.FeedbackController"
]
public class FeedbackRoute <: PluginRoute {
    public init() {}

    /// 注册该插件模块的全部路由（只追加，不修改存量注册）
    ///
    /// router 为 Any 承载（PS-T017：PluginRoute 接口进 SPI，不得依赖宿主
    /// Router 类型），实现内转换为 Router 后注册
    public func register(router: Any, controller: Any): Unit {
        if (let r: Router <- router) {
            if (let ctrl: FeedbackController <- controller) {
                let base = "/api/v1/uctoo/feedback"

                // V4 规范：POST /add、/edit、/del
                r.post("${base}/add", { req, res =>
                    ctrl.add(req, res)
                })
                r.post("${base}/edit", { req, res =>
                    ctrl.edit(req, res)
                })
                r.post("${base}/del", { req, res =>
                    ctrl.delete(req, res)
                })
                r.post("${base}/empty-recycle-bin", { req, res =>
                    ctrl.emptyRecycleBin(req, res)
                })

                // 单条查询（UUID 格式与数字不同，放在列表查询之前）
                r.get("${base}/:id", { req, res =>
                    ctrl.getSingle(req, res)
                })

                // 分页列表（带 skip 的必须先注册，避免被 :limit/:page 匹配）
                r.get("${base}/:limit/:page/:skip", { req, res =>
                    ctrl.getManyWithSkip(req, res)
                })
                r.get("${base}/:limit/:page", { req, res =>
                    ctrl.getManyWithPathParams(req, res)
                })

                // 导出功能
                r.get("${base}/export", { req, res =>
                    ctrl.export(req, res)
                })

                LogUtils.info("[FeedbackRoute] routes registered under ${base} (V4: POST /add /edit /del /empty-recycle-bin, GET /:id /:limit/:page/:skip /export)")
            } else {
                LogUtils.error("[FeedbackRoute] controller is not FeedbackController, skip register")
            }
        } else {
            LogUtils.error("[FeedbackRoute] router is not Router, skip register")
        }
    }

//#endregion AutoCreateCode
// ========== 定制开发区域（在此区域添加自定义路由）==========
}
