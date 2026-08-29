/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package plugin_spi

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import std.reflect.TypeInfo

/**
 * PluginSpiLogger - SPI 包日志钩子
 *
 * SPI 包不得依赖宿主 magic.log.LogUtils（依赖方向约束），默认输出到
 * 控制台；宿主 PluginManager 初始化时注入 LogUtils 适配（error/warn/info
 * 三个 sink），使 SPI 内日志汇入宿主日志文件。
 */
public class PluginSpiLogger {
    /// 错误日志 sink（默认控制台输出；宿主注入后走 LogUtils.error）
    public static var errorSink: (String) -> Unit = { msg =>
        println("[plugin-spi][ERROR] ${msg}")
    }

    /// 警告日志 sink（默认控制台输出；宿主注入后走 LogUtils.warn）
    public static var warnSink: (String) -> Unit = { msg =>
        println("[plugin-spi][WARN] ${msg}")
    }

    /// 信息日志 sink（默认静默，避免宿主注入前的启动噪音）
    public static var infoSink: (String) -> Unit = { _ => () }

    public static func error(msg: String): Unit {
        errorSink(msg)
    }

    public static func warn(msg: String): Unit {
        warnSink(msg)
    }

    public static func info(msg: String): Unit {
        infoSink(msg)
    }
}

/**
 * ServiceRegistry - 插件服务注册表契约（interface）
 *
 * v4.0 优化方案 3.2 方案 B（design.md §2.2.2）：ServiceRegistry 从自建 HashMap 注册表
 * 改为委托 fountain BeanFactory 的 interface 契约。plugin-spi 只定义契约（纯接口），
 * 实现层 BeanFactoryServiceRegistry 在宿主 magic.plugin 中引入 fountain 依赖。
 *
 * 方案 B 完整委托 BeanFactory（双轨实现）：
 * 1. 类型安全轨（推荐）：registerBean<T>(name, creator) 委托 BeanFactory.register<T>(creator)，
 *    getService<T>() 委托 BeanFactory.getFirst<T>()——复用 IOC 容器的类型安全+并发控制+生命周期管理
 * 2. 字符串名轨（兼容保留）：register(name, service) 用 HashMap<String, Any> 保存实例引用，
 *    getService(name) 按名查找，listServices/size/unregister 基于此 HashMap 实现
 *
 * 服务命名契约（design.md §2.2.2）：
 * 1. 注册名 = `plugin.{pluginName}.{serviceName}`（前缀隔离，避免与宿主服务命名冲突）
 * 2. 实现类必须实现注册名对应的接口；运行期框架不强校验
 */
public interface ServiceRegistry {
    /**
     * 注册服务（字符串名轨，兼容保留）
     *
     * 幂等拒绝：同名已存在返回 false，不覆盖。
     *
     * 参数：
     *   - name: 服务注册名（应为 plugin.{pluginName}.{serviceName}）
     *   - service: 服务实例
     */
    func register(name: String, service: Any): Bool

    /**
     * 注册服务（类型安全轨，推荐）—— 方案 B 委托 BeanFactory
     *
     * 委托 BeanFactory.register<T>(creator)，复用 IOC 容器的类型安全+并发控制+生命周期管理。
     * 注册的 Bean 可通过 getService<T>() 类型安全查找（委托 BeanFactory.getFirst<T>()）。
     *
     * 参数：
     *   - name: 服务注册名（应为 plugin.{pluginName}.{serviceName}）
     *   - creator: 服务创建闭包（() => T），BeanFactory 用此闭包管理 Bean 生命周期
     *
     * 约束：T <: Object（BeanFactory.register<T> 的 where 约束）
     */
    func registerBean<T>(name: String, creator: () -> T): Bool where T <: Object

    /**
     * 按注册名获取服务（字符串名轨）
     */
    func getService(name: String): Option<Any>

    /**
     * 按类型获取服务（类型安全轨，推荐）—— 方案 B 委托 BeanFactory
     *
     * 委托 BeanFactory.getFirst<T>()，一步到位，无需自建 HashMap<TypeInfo,...>。
     * 查找所有类型匹配的 Bean，返回第一个（按 primary/order 排序）。
     */
    func getService<T>(): Option<T>

    /**
     * 注销服务（返回是否确实移除）
     */
    func unregister(name: String): Bool

    /**
     * 列出全部已注册服务名（按注册顺序）
     */
    func listServices(): Array<String>

    /**
     * 已注册服务数量
     */
    func size(): Int64
}
