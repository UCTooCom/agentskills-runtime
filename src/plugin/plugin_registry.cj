/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import f_base.Result
import magic.log.LogUtils
import plugin_spi.{Plugin, PluginState, PluginError, RegistrySnapshot}

/**
 * PluginRegistry - 插件注册表
 *
 * 记录已加载插件实例与生命周期状态；幂等注册（同名返回已存在实例，
 * 不重复加载）；快照/回滚支撑停用插件后的注册表恢复。
 *
 * 状态迁移由 PluginHostManager 驱动（包内 setState），Registry 只做记录。
 */
public class PluginRegistry {
    private let plugins: HashMap<String, Plugin>
    private let states: HashMap<String, PluginState>
    /// 注册顺序（listAll 稳定输出）
    private let orderedNames: ArrayList<String>
    private let mutex: Mutex

    public init() {
        this.plugins = HashMap<String, Plugin>()
        this.states = HashMap<String, PluginState>()
        this.orderedNames = ArrayList<String>()
        this.mutex = Mutex()
    }

    /**
     * 注册插件（幂等：同名已存在返回 Ok(已存在实例)，不重复加载）
     *
     * 新注册插件初始状态 Pending
     */
    public func register(plugin: Plugin): Result<Plugin, PluginError> {
        let name = plugin.getName()
        if (name.isEmpty()) {
            return Err(PluginError.AnnotationInvalid("plugin name is empty"))
        }
        synchronized(this.mutex) {
            match (this.plugins.get(name)) {
                case Some(existing) =>
                    LogUtils.info("[PluginRegistry] plugin already registered, reuse: ${name}")
                    return Ok(existing)
                case None =>
                    this.plugins[name] = plugin
                    this.states[name] = PluginState.Pending
                    this.orderedNames.add(name)
                    return Ok(plugin)
            }
        }
    }

    /**
     * 按名查询插件实例
     */
    public func get(name: String): Option<Plugin> {
        synchronized(this.mutex) {
            return this.plugins.get(name)
        }
    }

    /**
     * 查询插件当前状态（未注册返回 None）
     */
    public func getState(name: String): Option<PluginState> {
        synchronized(this.mutex) {
            return this.states.get(name)
        }
    }

    /**
     * 按状态过滤插件列表
     */
    public func list(state: PluginState): ArrayList<Plugin> {
        let result = ArrayList<Plugin>()
        synchronized(this.mutex) {
            for (name in this.orderedNames) {
                match (this.states.get(name)) {
                    case Some(s) =>
                        if (s == state) {
                            match (this.plugins.get(name)) {
                                case Some(p) => result.add(p)
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }
        return result
    }

    /**
     * 全量插件列表（按注册顺序）
     */
    public func listAll(): ArrayList<Plugin> {
        let result = ArrayList<Plugin>()
        synchronized(this.mutex) {
            for (name in this.orderedNames) {
                match (this.plugins.get(name)) {
                    case Some(p) => result.add(p)
                    case None => ()
                }
            }
        }
        return result
    }

    /**
     * 注销插件（移除记录，状态置 Disposed）
     *
     * 返回是否确实移除（不存在返回 false）
     */
    public func unregister(name: String): Bool {
        synchronized(this.mutex) {
            if (!this.plugins.contains(name)) {
                return false
            }
            this.plugins.remove(name)
            this.states.remove(name)
            let remaining = ArrayList<String>()
            for (n in this.orderedNames) {
                if (n != name) {
                    remaining.add(n)
                }
            }
            this.orderedNames.clear()
            for (n in remaining) {
                this.orderedNames.add(n)
            }
            return true
        }
    }

    /**
     * 拍摄当前注册表快照
     */
    public func snapshot(): RegistrySnapshot {
        synchronized(this.mutex) {
            let names = this.orderedNames.toArray()
            let stateCopy = HashMap<String, PluginState>()
            for ((name, state) in this.states) {
                stateCopy[name] = state
            }
            return RegistrySnapshot(names, stateCopy)
        }
    }

    /**
     * 回滚到快照：
     * 1. 移除快照之后新注册的插件
     * 2. 快照与当前都存在的插件，状态恢复快照值
     * 3. 快照中有但当前已注销的插件不复活（避免状态与实例不一致）
     */
    public func restore(snapshot: RegistrySnapshot): Bool {
        synchronized(this.mutex) {
            // 移除快照中不存在的插件（快照之后新加载的）
            let toRemove = ArrayList<String>()
            for (name in this.orderedNames) {
                if (!snapshot.pluginNames.contains(name)) {
                    toRemove.add(name)
                }
            }
            for (name in toRemove) {
                this.unregisterLocked(name)
            }
            // 仅恢复"当前仍注册"的插件状态（不复活已注销项）
            for ((name, state) in snapshot.states) {
                if (this.plugins.contains(name)) {
                    this.states[name] = state
                }
            }
            return true
        }
    }

    /**
     * 更新插件状态（包内可见，PluginHostManager 驱动状态机）
     */
    func setState(name: String, state: PluginState): Unit {
        synchronized(this.mutex) {
            this.states[name] = state
        }
    }

    /// 已持锁的注销（restore 内部复用，避免重入死锁）
    private func unregisterLocked(name: String): Unit {
        this.plugins.remove(name)
        this.states.remove(name)
        let remaining = ArrayList<String>()
        for (n in this.orderedNames) {
            if (n != name) {
                remaining.add(n)
            }
        }
        this.orderedNames.clear()
        for (n in remaining) {
            this.orderedNames.add(n)
        }
    }
}
