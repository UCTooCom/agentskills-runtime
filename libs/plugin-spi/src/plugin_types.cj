/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package plugin_spi

import std.collection.{ArrayList, HashMap}

/**
 * 插件生命周期状态
 *
 * 状态机：Pending -> Loading -> Active -> Disposed
 *                \-> Error -> Disposed / Loading(重试)
 *
 * ERROR 态边界约定（design.md §2.1.4）：
 * 仅生命周期钩子异常（onLoad/onActivate）与依赖关系破坏触发 Error；
 * 事件处理器与 Service 调用的业务异常不触发状态迁移（由日志观测）。
 */
public enum PluginState <: ToString {
    | Pending    // 已发现未加载
    | Loading    // 加载中
    | Active     // 已激活
    | Error      // 加载或激活失败（可修复后重试）
    | Disposed   // 已卸载回收

    /// 枚举相等比较（元组 match 实现，参照 zip4cj EncryptionMethod 先例）
    public operator func ==(that: PluginState): Bool {
        return match ((this, that)) {
            case (Pending, Pending) => true
            case (Loading, Loading) => true
            case (Active, Active) => true
            case (Error, Error) => true
            case (Disposed, Disposed) => true
            case _ => false
        }
    }

    public operator func !=(that: PluginState): Bool {
        return !(this == that)
    }

    /// 字符串表示（日志/状态展示用）
    public func toString(): String {
        return match (this) {
            case Pending => "Pending"
            case Loading => "Loading"
            case Active => "Active"
            case Error => "Error"
            case Disposed => "Disposed"
        }
    }
}

/**
 * 插件系统统一错误码
 */
public enum PluginError {
    | DuplicatePlugin(String)      // 同名冲突，携带插件名
    | DependencyMissing(String)    // 依赖缺失，携带"插件名:依赖名"描述
    | AnnotationInvalid(String)    // 注解非法（缺失/字段不一致），携带描述
    | InstantiationFailed(String)  // 反射实例化失败，携带类名与原因
    | NotFound(String)             // 插件不存在，携带插件名
    | ConfigInvalid(String)        // plugins.yaml 解析失败，携带描述
    | LifecycleError(String)       // 生命周期钩子执行失败，携带描述

    /// 人类可读的错误描述
    public func message(): String {
        match (this) {
            case DuplicatePlugin(name) =>
                "duplicate plugin registration: ${name}"
            case DependencyMissing(desc) =>
                "plugin dependency missing: ${desc}"
            case AnnotationInvalid(desc) =>
                "plugin annotation invalid: ${desc}"
            case InstantiationFailed(desc) =>
                "plugin instantiation failed: ${desc}"
            case NotFound(name) =>
                "plugin not found: ${name}"
            case ConfigInvalid(desc) =>
                "plugins.yaml invalid: ${desc}"
            case LifecycleError(desc) =>
                "plugin lifecycle error: ${desc}"
        }
    }
}

/**
 * 注册表快照（用于停用插件后的回滚）
 */
public class RegistrySnapshot {
    /// 快照时刻的插件名列表
    public let pluginNames: Array<String>

    /// 快照时刻的各插件状态
    public let states: HashMap<String, PluginState>

    public init(pluginNames: Array<String>, states: HashMap<String, PluginState>) {
        this.pluginNames = pluginNames
        this.states = states
    }
}

/**
 * 批量加载结果（PluginManager.loadAll 返回值）
 */
public class LoadResult {
    /// 成功激活的插件名
    public let loaded: ArrayList<String>

    /// 加载/激活失败的插件名（含原因）
    public let failed: ArrayList<String>

    /// 跳过的插件（enabled=false 或重复注册）
    public let skipped: ArrayList<String>

    public init() {
        this.loaded = ArrayList<String>()
        this.failed = ArrayList<String>()
        this.skipped = ArrayList<String>()
    }

    /// 是否全部成功（无失败项）
    public func isAllLoaded(): Bool {
        this.failed.isEmpty()
    }

    /// 汇总描述
    public func summary(): String {
        "plugins loaded=${this.loaded.size}, failed=${this.failed.size}, skipped=${this.skipped.size}"
    }
}
