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
 * {{aggregateClassName}}Plugin - {{name}} 插件聚合入口（plugingen 生成，多表模式）
 *
 * 一个插件名下聚合多张表的 CRUD 装配点：onLoad 循环装配所有表的 Service 并接线 Controller。
 * 三维一体：Service + Skill + Route（聚合 Route = {{aggregateClassName}}Route）。
 * 宿主仅加载本聚合入口（config/plugins.yaml 的 className），各表逻辑经本类分发。
 *
 * 生命周期：onLoad 接线 -> onActivate 生效 -> onDeactivate 停用 -> 清理栈逆序执行。
 */
@PluginAnnotation[name: "{{name}}", version: "1.0.0", dependencies: ""]
public class {{aggregateClassName}}Plugin <: Plugin {
    public init() {}

    public func getName(): String {
        return "{{name}}"
    }

    public func onLoad(context: PluginContext): Unit {
{{onLoadBody}}
    }

    public func onActivate(): Unit {
        LogUtils.info("[{{aggregateClassName}}Plugin] activated")
    }

    public func onDeactivate(): Unit {
        LogUtils.info("[{{aggregateClassName}}Plugin] deactivated")
    }

    public func onUnload(): Unit {
        LogUtils.info("[{{aggregateClassName}}Plugin] unloaded")
    }

//#endregion AutoCreateCode
// ========== 定制开发区域（在此区域添加自定义生命周期逻辑）==========
}
