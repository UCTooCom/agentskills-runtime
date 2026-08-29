/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.ArrayList
import std.reflect.ClassTypeInfo
import magic.app.core.router.Router
import magic.log.LogUtils
import plugin_spi.{ModuleRouteAnnotation, PluginRoute}

/**
 * PluginRouteScanner - 插件路由运行时注册器（双轨路由的插件轨）
 *
 * 在存量 AutoRouteRegistry.registerAllRoutes() 之后调用（design.md §2.8）：
 * 从 PluginHostManager 收集已激活插件声明的 routeClass 全名，逐个执行
 * ClassTypeInfo.get -> findAnnotation<ModuleRouteAnnotation>
 * -> 无参构造实例化 Route -> as PluginRoute -> 反射实例化 Controller
 * -> route.register(router, controller)
 *
 * 反射实现模式与 PluginLoader 一致（f_app/App.cj ClassTypeInfo.get
 * + try-catch 优雅降级先例）；全程 try/catch，单条路由失败记录日志
 * 不阻塞其他路由（PS-T014 验收标准）。
 *
 * v4.0 优化方案 3.8 修正：TypeInfos.get() 返回 TypeInfo（无 constructors 属性），
 * 而 PluginRouteScanner 的 instantiate() 需要 typeInfo.constructors 遍历无参构造。
 * 故此文件保留 ClassTypeInfo.get()。插件路由注册是一次性冷路径操作，
 * TypeInfos.get() 的缓存优势可忽略。
 */
public class PluginRouteScanner {
    public init() {}

    /**
     * 扫描并注册全部插件路由
     *
     * 参数：
     *   - router: 宿主路由器（存量轨已注册完成）
     *   - pluginManager: 插件总控（提供已激活插件的 routeClass 清单）
     */
    public func scanAndRegister(router: Router, pluginManager: PluginHostManager): Unit {
        let routeClasses = pluginManager.routeClassNames()
        if (routeClasses.isEmpty()) {
            LogUtils.info("[PluginRouteScanner] no plugin routes declared, skip")
            return
        }
        LogUtils.info("[PluginRouteScanner] registering plugin routes: total=${routeClasses.size}")
        var success = 0
        for (routeClass in routeClasses) {
            if (this.registerOne(router, routeClass)) {
                success += 1
            }
        }
        LogUtils.info(
            "[PluginRouteScanner] plugin routes registered: success=${success}, failed=${routeClasses.size - success}")
    }

    /**
     * 注册单条插件路由（Route 实例化 -> Controller 实例化 -> register）
     */
    private func registerOne(router: Router, routeClassName: String): Bool {
        // 1. 解析 Route 类型（不存在时优雅降级为失败日志）
        let typeInfo: ClassTypeInfo
        try {
            typeInfo = ClassTypeInfo.get(routeClassName)
        } catch (e: Exception) {
            LogUtils.error("[PluginRouteScanner] route class not found: ${routeClassName} (${e.message})")
            return false
        }

        // 2. 读取 @ModuleRouteAnnotation 声明
        let annotation = typeInfo.findAnnotation<ModuleRouteAnnotation>()
        match (annotation) {
            case None =>
                LogUtils.error(
                    "[PluginRouteScanner] class ${routeClassName} is not annotated with @ModuleRouteAnnotation")
                return false
            case Some(anno) =>
                // 3. 实例化 Route 并转换为 PluginRoute 接口
                match (this.instantiate(routeClassName)) {
                    case None => return false
                    case Some(routeInstance) =>
                        if (let route: PluginRoute <- routeInstance) {
                            // 4. 反射实例化 Controller 并注册路由
                            match (this.instantiate(anno.controllerClass)) {
                                case None => return false
                                case Some(controller) =>
                                    try {
                                        route.register(router, controller)
                                        LogUtils.info(
                                            "[PluginRouteScanner] plugin route registered: ${routeClassName} (basePath=${anno.basePath})")
                                        return true
                                    } catch (e: Exception) {
                                        LogUtils.error(
                                            "[PluginRouteScanner] route register failed: ${routeClassName} (${e.message})")
                                        return false
                                    }
                            }
                        } else {
                            LogUtils.error(
                                "[PluginRouteScanner] class ${routeClassName} does not implement PluginRoute")
                            return false
                        }
                }
        }
    }

    /**
     * 按类全名反射实例化（public 无参构造；失败记日志返回 None）
     */
    private func instantiate(className: String): Option<Any> {
        try {
            let typeInfo = ClassTypeInfo.get(className)
            for (constructor in typeInfo.constructors) {
                if (constructor.parameters.size == 0) {
                    return Some(constructor.apply(Array<Any>()))
                }
            }
            LogUtils.error("[PluginRouteScanner] no public no-arg constructor: ${className}")
            return None
        } catch (e: Exception) {
            LogUtils.error(
                "[PluginRouteScanner] instantiate failed: ${className} (${e.message})")
            return None
        }
    }
}
