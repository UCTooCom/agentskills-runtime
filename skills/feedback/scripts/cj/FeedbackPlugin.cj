/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.feedback

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.log.LogUtils
import plugin_spi.{Plugin, PluginContext, PluginAnnotation}

/**
 * FeedbackPlugin - feedback 插件入口（plugingen 生成）
 *
 * 三维一体插件的装配点：
 * - Service：onLoad 组装服务实例并经静态接点接线 Controller
 * - Skill：skills/feedback/SKILL.md 经 SkillBridge 自动注册（AI 行为）
 * - Route：FeedbackRoute 经 PluginRouteScanner 反射注册（双轨插件路由）
 *
 * 生命周期：onLoad 接线 -> onActivate 生效 -> onDeactivate 停用 ->
 * 清理栈逆序执行（断开接线，路由降级 503，不删除路由注册）
 */
@PluginAnnotation[name: "feedback", version: "1.0.0", dependencies: ""]
public class FeedbackPlugin <: Plugin {
    public init() {}

    public func getName(): String {
        return "feedback"
    }

    public func onLoad(context: PluginContext): Unit {
        // 组装 Service/Controller（接线点模式：激活注入，停用清空）
        let service = FeedbackService()
        FeedbackController.wiredService = Some(service)
        context.onCleanup({ =>
            FeedbackController.wiredService = None
        })
        LogUtils.info("[FeedbackPlugin] loaded: service wired")
    }

    public func onActivate(): Unit {
        LogUtils.info("[FeedbackPlugin] activated")
    }

    public func onDeactivate(): Unit {
        LogUtils.info("[FeedbackPlugin] deactivated")
    }

    public func onUnload(): Unit {
        LogUtils.info("[FeedbackPlugin] unloaded")
    }

//#endregion AutoCreateCode
// ========== 定制开发区域（在此区域添加自定义生命周期逻辑）==========
}
