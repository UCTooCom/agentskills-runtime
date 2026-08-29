/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package plugin_spi

import std.collection.ArrayList
import stdx.encoding.json.JsonValue

/**
 * PluginSkillBridge - 插件技能注册桥接口
 *
 * 实现留在宿主 magic.plugin.SkillBridge（依赖 SkillManagementService/
 * SkillManager 存量技能管线，SPI 不感知）；插件经 PluginContext.skillBridge
 * 句柄调用。接口面 = SkillBridge 的公共方法（均无宿主类型依赖）。
 */
public interface PluginSkillBridge {
    /// 按插件目录加载技能并注册（返回成功注册的技能数量；无 SKILL.md 返回 0）
    func registerPluginSkills(pluginDir: String, pluginName: String): Int64

    /// 生成插件能力目录条目（AI 可消费的 JSON 描述：{"plugin":..,"skills":[..]}）
    func buildCapabilityCatalog(pluginName: String): JsonValue

    /// 注销插件时清理技能登记（不卸载技能本身，由 SkillManager 全局管理）
    func clearPluginSkills(pluginName: String): Unit
}

/**
 * PluginContext - 插件运行上下文
 *
 * onLoad(context) 阶段注入，持有三合一容器句柄：
 * ServiceRegistry（确定性服务）/ PluginEventBus（事件）/ SkillBridge（技能）
 * 与 plugins.yaml 的参数配置（config）。
 *
 * onCleanup 注册可逆清理回调（cordis effect/disposer 语义），
 * 框架在插件卸载时逆序执行（与 onUnload 钩子之后）。
 */
public class PluginContext {
    /// 插件名
    public let pluginName: String

    /// 服务注册表句柄
    public let serviceRegistry: ServiceRegistry

    /// 事件总线句柄
    public let eventBus: PluginEventBus

    /// 技能桥句柄
    public let skillBridge: PluginSkillBridge

    /// 来自 plugins.yaml 的插件参数（config 节点原样注入）
    public let config: JsonValue

    /// 可逆清理栈（注册顺序记录，执行时逆序）
    private let cleanupStack: ArrayList<() -> Unit>

    public init(
        pluginName: String,
        serviceRegistry: ServiceRegistry,
        eventBus: PluginEventBus,
        skillBridge: PluginSkillBridge,
        config: JsonValue
    ) {
        this.pluginName = pluginName
        this.serviceRegistry = serviceRegistry
        this.eventBus = eventBus
        this.skillBridge = skillBridge
        this.config = config
        this.cleanupStack = ArrayList<() -> Unit>()
    }

    /**
     * 注册确定性服务（转发 ServiceRegistry）
     *
     * 注册名应为服务接口全限定名（服务命名契约见 ServiceRegistry）
     */
    public func registerService(name: String, service: Any): Bool {
        return this.serviceRegistry.register(name, service)
    }

    /**
     * 按注册名获取服务（字符串名轨）
     */
    public func getService(name: String): Option<Any> {
        return this.serviceRegistry.getService(name)
    }

    /**
     * 按类型获取服务（类型安全轨，推荐）
     */
    public func getService<T>(): Option<T> {
        return this.serviceRegistry.getService<T>()
    }

    /**
     * 注册可逆清理回调（框架在插件卸载时逆序执行）
     */
    public func onCleanup(f: () -> Unit): Unit {
        this.cleanupStack.add(f)
    }

    /**
     * 执行清理栈（逆序；单个回调异常不阻断后续清理）
     *
     * 框架内部方法（PS-T017 迁移后由跨包的 PluginManager 调用，故 public；
     * 插件代码不应自行调用）
     */
    public func executeCleanups(): Unit {
        for (i in 0..this.cleanupStack.size) {
            let f = this.cleanupStack[this.cleanupStack.size - 1 - i]
            try {
                f()
            } catch (e: Exception) {
                PluginSpiLogger.error(
                    "[PluginContext] cleanup error, plugin=${this.pluginName}: ${e.message}")
            }
        }
        this.cleanupStack.clear()
    }
}
