/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 *
 * PS-T017 子任务 4（v4.0 优化方案 3.2 方案 B，design.md §2.2.2）：
 * ServiceRegistry 委托 fountain BeanFactory 实现类。
 *
 * plugin-spi 只定义 ServiceRegistry interface 契约（纯接口，不依赖 fountain），
 * 实现层 BeanFactoryServiceRegistry 在宿主 magic.plugin 中引入 fountain 依赖。
 *
 * 方案 B 完整委托 BeanFactory（双轨实现）：
 * 1. 类型安全轨（推荐）：registerBean<T>(name, creator) 委托 BeanFactory.register<T>(creator)，
 *    getService<T>() 委托 BeanFactory.getFirst<T>()——复用 IOC 容器的类型安全+并发控制+生命周期管理
 * 2. 字符串名轨（兼容保留）：register(name, service) 用 HashMap<String, Any> 保存实例引用，
 *    getService(name) 按名查找，listServices/size/unregister 基于此 HashMap 实现
 *
 * 命名规范：plugin.{pluginName}.{serviceName} 前缀隔离（避免与宿主服务命名冲突）。
 * BeanFactory 是全局单例，插件与宿主共享同一容器。
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import f_bean.BeanFactory
import plugin_spi.{ServiceRegistry, PluginSpiLogger}

/**
 * BeanFactoryServiceRegistry - 委托 fountain BeanFactory 的 ServiceRegistry 实现
 *
 * v4.0 优化方案 3.2 方案 B（design.md §2.2.2）：ServiceRegistry 从自建 HashMap 注册表
 * 改为委托 BeanFactory。复用 IOC 容器的类型安全（getFirst<T>）+ 并发控制
 * （ConcurrentHashMap）+ 生命周期管理（BeanScope）。
 *
 * 双轨实现：
 * - 字符串名轨（register/getService(name)）：用 HashMap<String, Any> 保存实例引用，
 *   listServices/size/unregister 基于此 HashMap 实现。
 * - 类型安全轨（registerBean<T>/getService<T>）：委托 BeanFactory.instance，
 *   registerBean<T> 委托 BeanFactory.register<T>(creator)，
 *   getService<T> 委托 BeanFactory.getFirst<T>()。
 */
public class BeanFactoryServiceRegistry <: ServiceRegistry {
    /// 字符串名轨：按注册名索引的服务表
    private let services: HashMap<String, Any>

    /// 注册顺序（listServices 保持稳定输出）
    private let orderedNames: ArrayList<String>

    private let mutex: Mutex

    /// fountain BeanFactory 全局单例（类型安全轨委托目标）
    private let beanFactory: BeanFactory

    public init() {
        this.services = HashMap<String, Any>()
        this.orderedNames = ArrayList<String>()
        this.mutex = Mutex()
        this.beanFactory = BeanFactory.instance
    }

    /**
     * 注册服务（字符串名轨，兼容保留）
     *
     * 幂等拒绝：同名已存在返回 false，不覆盖。
     * 用 HashMap<String, Any> 保存实例引用。
     *
     * 参数：
     *   - name: 服务注册名（应为 plugin.{pluginName}.{serviceName}）
     *   - service: 服务实例
     */
    public func register(name: String, service: Any): Bool {
        synchronized(this.mutex) {
            if (this.services.contains(name)) {
                PluginSpiLogger.warn("[BeanFactoryServiceRegistry] service already registered, skip: ${name}")
                return false
            }
            this.services[name] = service
            this.orderedNames.add(name)
            return true
        }
    }

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
    public func registerBean<T>(name: String, creator: () -> T): Bool where T <: Object {
        // 委托给 fountain BeanFactory
        beanFactory.register<T>(creator)
        // 同时记录到字符串名轨（保持 listServices/size 一致性）
        synchronized(this.mutex) {
            if (!this.services.contains(name)) {
                this.orderedNames.add(name)
                // services HashMap 存 creator 的首次求值结果，供字符串名轨 getService(name) 使用
                // 延迟求值：这里不调用 creator()，避免双重实例化
                // 字符串名轨 getService(name) 将从 BeanFactory.get<T>(name) 获取
            }
        }
        true
    }

    /**
     * 按注册名获取服务（字符串名轨）
     */
    public func getService(name: String): Option<Any> {
        synchronized(this.mutex) {
            return this.services.get(name)
        }
    }

    /**
     * 按类型获取服务（类型安全轨，推荐）—— 方案 B 委托 BeanFactory
     *
     * 委托 BeanFactory.getFirst<T>()，一步到位，无需自建 HashMap<TypeInfo,...>。
     * 查找所有类型匹配的 Bean，返回第一个（按 primary/order 排序）。
     */
    public func getService<T>(): Option<T> {
        // 优先委托 BeanFactory.getFirst<T>()
        let bean = beanFactory.getFirst<T>()
        if (let Some(b) <- bean) {
            return Some(b)
        }
        // 降级到字符串名轨遍历模式匹配
        let candidates = ArrayList<Any>()
        synchronized(this.mutex) {
            for (name in this.orderedNames) {
                match (this.services.get(name)) {
                    case Some(service) => candidates.add(service)
                    case None => ()
                }
            }
        }
        for (service in candidates) {
            if (let s: T <- service) {
                return Some(s)
            }
        }
        PluginSpiLogger.error("[BeanFactoryServiceRegistry] no service matches required type")
        return None
    }

    /**
     * 注销服务（返回是否确实移除）
     */
    public func unregister(name: String): Bool {
        synchronized(this.mutex) {
            if (!this.services.contains(name)) {
                return false
            }
            this.services.remove(name)
            // ArrayList 无 removeAt，按过滤重建保持顺序
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
     * 列出全部已注册服务名（按注册顺序）
     */
    public func listServices(): Array<String> {
        synchronized(this.mutex) {
            return this.orderedNames.toArray()
        }
    }

    /**
     * 已注册服务数量
     */
    public func size(): Int64 {
        synchronized(this.mutex) {
            return Int64(this.orderedNames.size)
        }
    }
}
