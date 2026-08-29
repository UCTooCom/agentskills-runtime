/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package skill_{{name}}

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.log.LogUtils
import plugin_spi.{Plugin, PluginContext, PluginAnnotation}

/**
 * {{className}}Plugin - {{name}} 插件入口（plugingen 生成）
 *
 * 三维一体插件的装配点：
 * - Service：onLoad 组装服务实例并经静态接点接线 Controller
 * - Skill：skills/{{name}}/SKILL.md 经 SkillBridge 自动注册（AI 行为）
 * - Route：{{className}}Route 经 PluginRouteScanner 反射注册（双轨插件路由）
 *
 * 生命周期：onLoad 接线 -> onActivate 生效 -> onDeactivate 停用 ->
 * 清理栈逆序执行（断开接线，路由降级 503，不删除路由注册）
 */
@PluginAnnotation[name: "{{name}}", version: "1.0.0", dependencies: ""]
public class {{className}}Plugin <: Plugin {
    public init() {}

    public func getName(): String {
        return "{{name}}"
    }

    public func onLoad(context: PluginContext): Unit {
{{onLoadBody}}
    }

    public func onActivate(): Unit {
        LogUtils.info("[{{className}}Plugin] activated")
    }

    public func onDeactivate(): Unit {
        LogUtils.info("[{{className}}Plugin] deactivated")
    }

    public func onUnload(): Unit {
        LogUtils.info("[{{className}}Plugin] unloaded")
    }

//#endregion AutoCreateCode
// ========== 定制开发区域（在此区域添加自定义生命周期逻辑）==========
}
