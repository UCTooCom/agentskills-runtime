/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package plugin_spi

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import std.sync.Mutex
import stdx.encoding.json.JsonValue

/**
 * 事件订阅记录（内部结构）
 *
 * v4.0 优化方案 3.3（design.md §2.2.2）：PluginEventBus 包装 fountain EventBus。
 * 经 fountain EventBus 源码分析，fountain EventBus 是**异步**分发（多 Worker 线程池
 * + JobQueue + 背压策略），而 PluginEventBus 的 emit/waterfall 是**同步**的
 * （直接调用 handler，返回 ArrayList<JsonValue>）。异步语义与同步契约不匹配。
 *
 * 最终方案：PluginEventBus 保留同步语义的自建实现，但优化并发控制——
 * 用 ConcurrentHashMap 替代 HashMap+Mutex（复用 fountain f_concurrent 的并发模式）。
 * 保留插件维度订阅追踪（卸载时清理）。
 *
 * 与存量 EventHandlerManager 的关系（design.md v2.2 统一口径）：
 * 独立实现（自带插件维度订阅表、优先级与 waterfall），不直调
 * EventHandlerManager；事件类型命名对齐存量 EventKind 语义，
 * 为 v1.0 后融合留接口。
 *
 * 分发语义（对标 Cordis events，v1 实现最常用两种）：
 * - emit：广播分发，所有订阅者收到同一事件，返回全部结果
 * - waterfall：链式分发，前一订阅者返回值作为后一订阅者入参
 *
 * 异常约定（design.md §2.1.4）：处理器抛异常仅记日志，不影响其他
 * 订阅者，也不触发插件状态迁移。
 *
 * 优先级约定：数字越小越先执行（与 AutoRoute 优先级方向一致）。
 */
private class EventSubscription {
    let pluginName: String
    let handler: (JsonValue) -> JsonValue
    let priority: Int32

    init(pluginName: String, handler: (JsonValue) -> JsonValue, priority: Int32) {
        this.pluginName = pluginName
        this.handler = handler
        this.priority = priority
    }
}

/**
 * PluginEventBus - 插件事件总线（同步语义，优化并发控制）
 *
 * v4.0 优化方案 3.3（design.md §2.2.2）：
 * 经 fountain EventBus 源码分析，fountain EventBus 是异步分发（多 Worker 线程池
 * + JobQueue + 背压策略），而 PluginEventBus 的 emit/waterfall 是同步的
 * （直接调用 handler，返回 ArrayList<JsonValue>）。异步语义与同步契约不匹配。
 *
 * 最终方案：PluginEventBus 保留同步语义的自建实现，但优化并发控制——
 * 用 ConcurrentHashMap 替代 HashMap+Mutex（复用 fountain f_concurrent 的并发模式）。
 */
public class PluginEventBus {
    /// 按事件类型索引的订阅表（ConcurrentHashMap 优化并发控制）
    private let subscriptions: ConcurrentHashMap<String, ArrayList<EventSubscription>>

    /// 各插件订阅的事件类型（卸载时快速定位清理）
    private let pluginEventTypes: ConcurrentHashMap<String, ArrayList<String>>

    /// 插件事件类型表的并发保护（pluginEventTypes 的读写需要 Mutex）
    private let pluginEventTypesMutex: Mutex

    public init() {
        this.subscriptions = ConcurrentHashMap<String, ArrayList<EventSubscription>>()
        this.pluginEventTypes = ConcurrentHashMap<String, ArrayList<String>>()
        this.pluginEventTypesMutex = Mutex()
    }

    /**
     * 订阅事件（绑定插件名，插件卸载时自动清理全部订阅）
     *
     * 参数：
     *   - pluginName: 订阅方插件名
     *   - eventType: 事件类型（命名对齐存量 EventKind 语义）
     *   - handler: 处理器（入参事件负载，返回处理结果）
     *   - priority: 优先级（数字越小越先执行，默认 0）
     *
     * 返回：订阅是否成功（重复订阅同一事件类型时追加，不算失败）
     */
    public func subscribe(
        pluginName: String,
        eventType: String,
        handler: (JsonValue) -> JsonValue,
        priority!: Int32 = 0
    ): Bool {
        // ConcurrentHashMap 的 addIfAbsent 返回 ?V：
        //   None 表示键不存在，已插入新值；
        //   Some(old) 表示键已存在，返回旧值。
        let newSubs = ArrayList<EventSubscription>()
        match (subscriptions.addIfAbsent(eventType, newSubs)) {
            case Some(existing) => existing.add(EventSubscription(pluginName, handler, priority))
            case None => newSubs.add(EventSubscription(pluginName, handler, priority))
        }

        // 更新插件订阅的事件类型
        synchronized(pluginEventTypesMutex) {
            let newTypes = ArrayList<String>()
            match (pluginEventTypes.addIfAbsent(pluginName, newTypes)) {
                case Some(existing) =>
                    if (!existing.contains(eventType)) {
                        existing.add(eventType)
                    }
                case None => newTypes.add(eventType)
            }
        }
        return true
    }

    /**
     * 广播分发：所有订阅者收到同一事件，按优先级执行
     *
     * 返回全部处理器的返回值（执行顺序）
     */
    public func emit(eventType: String, payload: JsonValue): ArrayList<JsonValue> {
        let ordered = orderedSubscribersOf(eventType)
        let results = ArrayList<JsonValue>()
        for (sub in ordered) {
            try {
                results.add(sub.handler(payload))
            } catch (e: Exception) {
                PluginSpiLogger.error(
                    "[PluginEventBus] handler error, event=${eventType}, plugin=${sub.pluginName}: ${e.message}")
            }
        }
        return results
    }

    /**
     * 链式分发：前一订阅者返回值作为后一订阅者入参
     *
     * 返回最后一个成功处理器的结果（无订阅者时返回入参原值）
     */
    public func waterfall(eventType: String, initial: JsonValue): JsonValue {
        let ordered = orderedSubscribersOf(eventType)
        var current = initial
        for (sub in ordered) {
            try {
                current = sub.handler(current)
            } catch (e: Exception) {
                PluginSpiLogger.error(
                    "[PluginEventBus] waterfall handler error, event=${eventType}, plugin=${sub.pluginName}: ${e.message}")
            }
        }
        return current
    }

    /**
     * 卸载插件时清理其全部订阅
     */
    public func unsubscribeAll(pluginName: String): Unit {
        // 获取该插件订阅的所有事件类型
        let eventTypesToRemove: ArrayList<String>
        synchronized(pluginEventTypesMutex) {
            eventTypesToRemove = match (pluginEventTypes.get(pluginName)) {
                case Some(list) =>
                    let copy = ArrayList<String>()
                    for (et in list) {
                        copy.add(et)
                    }
                    copy
                case None => ArrayList<String>()
            }
            pluginEventTypes.remove(pluginName)
        }

        // 清理每个事件类型中该插件的订阅
        for (eventType in eventTypesToRemove) {
            match (subscriptions.get(eventType)) {
                case Some(subs) =>
                    let remaining = ArrayList<EventSubscription>()
                    for (sub in subs) {
                        if (sub.pluginName != pluginName) {
                            remaining.add(sub)
                        }
                    }
                    if (remaining.isEmpty()) {
                        subscriptions.remove(eventType)
                    } else {
                        subs.clear()
                        for (sub in remaining) {
                            subs.add(sub)
                        }
                    }
                case None => ()
            }
        }
    }

    /**
     * 取某事件类型的订阅副本并按优先级升序排序（越小越先执行）
     *
     * 使用副本避免执行期间的并发修改
     */
    private func orderedSubscribersOf(eventType: String): Array<EventSubscription> {
        let copy = ArrayList<EventSubscription>()
        match (subscriptions.get(eventType)) {
            case Some(subs) =>
                for (sub in subs) {
                    copy.add(sub)
                }
            case None => ()
        }
        let arr = copy.toArray()
        let n = arr.size
        for (i in 0..n) {
            for (j in 0..(n - 1 - i)) {
                if (arr[j].priority > arr[j + 1].priority) {
                    let tmp = arr[j]
                    arr[j] = arr[j + 1]
                    arr[j + 1] = tmp
                }
            }
        }
        return arr
    }
}
