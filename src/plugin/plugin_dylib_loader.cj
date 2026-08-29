/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 *
 * PS-T012 L2 动态库加载原型（design.md §2.2.2，v4.0 优化方案 3.4）
 *
 * 复用 fountain f_app/App.cj L116-171 的动态库加载管线：
 * 1. PackageInfo.load(去扩展名路径) —— 仓颉标准库，fountain 已验证跨平台可用
 * 2. BeanFactory.afterRegistered() —— 触发 Bean 扫描，@Bean 注解类自动注册
 * 3. beanFactory.getList<Plugin>() —— 批量发现 @Plugin 注解类
 *
 * 与 fountain App.run() 的差异（design.md §3.4）：
 * - 去掉 Directory.walk 全目录扫描，改为按 plugins.yaml 清单精确加载
 * - 加载后按 @PluginAnnotation 注解发现（getList<Plugin>()）而非硬编码类名引导
 *
 * PackageInfo.load 约束（仓颉官方文档，v2.2）：
 * 动态库文件名必须与包名严格一致且不得改名，否则抛
 * "无法找到仓颉动态库模块文件"异常。插件独立 cjpm 包的
 * name = "skill_{name}" 编译产物为 libskill_{name}.so，
 * 加载时传入 "skill_{name}"（去扩展名去掉 lib 前缀）。
 */
package magic.plugin

import std.reflect.PackageInfo
import f_bean.BeanFactory
import f_base.Result
import magic.log.LogUtils
import plugin_spi.{Plugin, PluginError}

/**
 * PluginDylibLoader - L2 动态库加载器
 *
 * 复用 fountain f_app/App.run() 的 PackageInfo.load 管线。
 * 加载动态库后，通过 BeanFactory.afterRegistered() 触发 Bean 扫描，
 * 然后通过 getList<Plugin>() 批量发现 @Plugin 注解类。
 *
 * 约束：PackageInfo.load 按文件名判断包名——动态库文件名必须与包名
 * 严格一致且不得改名（仓颉官方文档注意事项）。
 */
public class PluginDylibLoader {
    private let registry: PluginRegistry

    public init(registry: PluginRegistry) {
        this.registry = registry
    }

    /**
     * 从动态库加载插件
     *
     * 复用 fountain App.run() 的 PackageInfo.load 管线：
     * 1. PackageInfo.load(去扩展名路径) 加载动态库
     * 2. 加载的动态库中的 @Bean 注解类自动注册到 BeanFactory
     * 3. 通过 BeanFactory.getList<Plugin>() 批量发现 @Plugin 注解类
     *
     * 参数：
     *   - libPath: 动态库文件路径（如 "skills/entity/target/release/skill_entity.so"）
     *   - pluginName: 预期加载的插件名（用于查找匹配的 Plugin 实例）
     *
     * 返回：加载成功返回 Plugin 实例，失败返回 PluginError
     *
     * 约束：动态库文件名必须与包名严格一致（PackageInfo.load 要求）
     */
    public func loadFromDylib(libPath: String, pluginName: String): Result<Plugin, PluginError> {
        LogUtils.info("[PluginDylibLoader] loading dylib: ${libPath}, expecting plugin: ${pluginName}")

        // Step 1: 加载动态库（复用 fountain App.run() 的去扩展名 + PackageInfo.load 模式）
        // PackageInfo.load 要求传入去扩展名的路径
        let libPathWithoutExt = removeDylibExtension(libPath)
        try {
            PackageInfo.load(libPathWithoutExt)
        } catch (e: Exception) {
            LogUtils.error("[PluginDylibLoader] failed to load dylib '${libPath}': ${e.message}")
            return Err(PluginError.InstantiationFailed(
                "failed to load dylib '${libPath}': ${e.message}"))
        }

        LogUtils.info("[PluginDylibLoader] dylib loaded: ${libPath}")

        // Step 2: 触发 Bean 扫描（复用 fountain App.run() L140 的 afterRegistered 机制）
        // PackageInfo.load 加载动态库后，其中的 @Bean 注解类自动注册到 BeanFactory，
        // 但需要调用 afterRegistered() 触发 BeanCondition 过滤和 lazy Bean 初始化
        BeanFactory.instance.afterRegistered()

        // Step 3: 通过 BeanFactory.getList<Plugin>() 批量发现 @Plugin 注解类
        let plugin = findPluginByName(pluginName)
        match (plugin) {
            case Some(p) =>
                LogUtils.info("[PluginDylibLoader] plugin found: ${p.getName()}")
                return Ok(p)
            case None =>
                LogUtils.error("[PluginDylibLoader] plugin '${pluginName}' not found in dylib '${libPath}'")
                return Err(PluginError.InstantiationFailed(
                    "plugin '${pluginName}' not found in dylib '${libPath}'"))
        }
    }

    /**
     * 从已加载的动态库中查找指定名称的插件
     *
     * 实现方式（design.md v4.0 优化方案 3.4/3.5）：
     * 1. PackageInfo.load 加载动态库后，其中的 @Bean 注解类自动注册到 BeanFactory
     * 2. 调用 BeanFactory.instance.afterRegistered() 触发 Bean 扫描
     * 3. 通过 BeanFactory.instance.getList<Plugin>() 批量发现 @Plugin 注解类
     * 4. 按 pluginName 匹配返回
     *
     * 注：PS-T012 是原型验证，此处的查找逻辑通过 BeanFactory.getList<Plugin>()
     * 批量发现。后续 PS-T019/PS-T020 会完善卸载和同步机制。
     */
    private func findPluginByName(pluginName: String): Option<Plugin> {
        // 通过 BeanFactory 批量发现 @Plugin 注解类
        let plugins = BeanFactory.instance.getList<Plugin>()
        for (plugin in plugins) {
            if (plugin.getName() == pluginName) {
                return Some(plugin)
            }
        }
        return None
    }

    /**
     * 移除动态库文件扩展名
     *
     * PackageInfo.load 要求传入去扩展名的路径。
     * 支持的扩展名：.so（Linux）、.dll（Windows）、.dylib（macOS）
     */
    private func removeDylibExtension(libPath: String): String {
        // 仓颉动态库文件名格式：lib{包名}.so / lib{包名}.dll / lib{包名}.dylib
        // PackageInfo.load 要求传入去扩展名的路径（含 lib 前缀）
        if (libPath.endsWith(".so")) {
            return libPath[0..libPath.size - 3]
        } else if (libPath.endsWith(".dll")) {
            return libPath[0..libPath.size - 4]
        } else if (libPath.endsWith(".dylib")) {
            return libPath[0..libPath.size - 6]
        }
        // 已经是去扩展名的路径，直接返回
        return libPath
    }

    /**
     * 卸载动态库
     *
     * 注：仓颉的 PackageInfo.load 加载的动态库由仓颉运行时管理，
     * dlclose 由仓颉 GC 自动管理。此方法主要用于清理 PluginRegistry
     * 中对应的插件记录。
     */
    public func unloadDylib(pluginName: String): Bool {
        LogUtils.info("[PluginDylibLoader] unloading plugin: ${pluginName}")
        // 从 PluginRegistry 注销插件（清理工作由 PluginHostManager.deactivate 驱动）
        // 此处仅记录卸载日志，实际清理在 PluginHostManager 层完成
        true
    }
}
