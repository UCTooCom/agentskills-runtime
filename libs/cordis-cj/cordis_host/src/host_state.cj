package ystyle::cordis_host

import ystyle::cordis_core.PluginEntry
import std.collection.{HashMap, ArrayList}
import std.sync.Mutex

/**
 * 宿主全局状态（docs/design-impl.md §2.3）
 */
public class HostState {
    public let lock: Mutex = Mutex()
    // id -> 期望条目（来自 TOML，enabled=true）
    public var desired: HashMap<String, PluginEntry> = HashMap<String, PluginEntry>()
    // id -> 存活实例
    public var actual: HashMap<String, PluginInstance> = HashMap<String, PluginInstance>()
    // serviceKey -> 提供者插件 id
    public var serviceIndex: HashMap<String, String> = HashMap<String, String>()
    // undo_id -> (serviceKey, providerId) 便于 dispose 时清理 serviceIndex
    public var undoMap: HashMap<String, (String, String)> = HashMap<String, (String, String)>()

    public init() {}

    public func addDesired(entry: PluginEntry): Unit {
        synchronized(this.lock) {
            this.desired[entry.id] = entry
        }
    }

    public func removeDesired(id: String): Unit {
        synchronized(this.lock) {
            this.desired.remove(id)
        }
    }

    public func addInstance(instance: PluginInstance): Unit {
        synchronized(this.lock) {
            this.actual[instance.entry.id] = instance
        }
    }

    public func removeInstance(id: String): Unit {
        synchronized(this.lock) {
            this.actual.remove(id)
        }
    }

    public func getInstance(id: String): ?PluginInstance {
        synchronized(this.lock) {
            if (this.actual.contains(id)) {
                this.actual[id]
            } else {
                None
            }
        }
    }

    public func hasService(key: String): Bool {
        synchronized(this.lock) {
            this.serviceIndex.contains(key)
        }
    }

    /**
     * 记录服务提供（插件 provide 成功时）
     * @return 分配的 undo_id
     */
    public func registerService(key: String, providerId: String, undoId: String): Unit {
        synchronized(this.lock) {
            this.serviceIndex[key] = providerId
            this.undoMap[undoId] = (key, providerId)
        }
    }

    /**
     * 撤销服务（dispose 时）
     * @return 是否成功撤销
     */
    public func unregisterService(undoId: String): Bool {
        synchronized(this.lock) {
            if (this.undoMap.contains(undoId)) {
                let (key, providerId) = this.undoMap[undoId]
                if (this.serviceIndex.get(key) == Some(providerId)) {
                    this.serviceIndex.remove(key)
                }
                this.undoMap.remove(undoId)
                true
            } else {
                false
            }
        }
    }

    /**
     * 移除某插件提供的全部服务（插件退出时清理）
     */
    public func clearServicesByProvider(providerId: String): Unit {
        synchronized(this.lock) {
            let staleKeys = ArrayList<String>()
            for ((key, pid) in this.serviceIndex) {
                if (pid == providerId) {
                    staleKeys.add(key)
                }
            }
            for (key in staleKeys) {
                this.serviceIndex.remove(key)
            }
            let staleUndos = ArrayList<String>()
            for ((undoId, kv) in this.undoMap) {
                if (kv[1] == providerId) {
                    staleUndos.add(undoId)
                }
            }
            for (undoId in staleUndos) {
                this.undoMap.remove(undoId)
            }
        }
    }

    /**
     * 获取某插件的全部 provide Key（用于崩溃恢复时重建）
     */
    public func servicesOf(providerId: String): ArrayList<String> {
        synchronized(this.lock) {
            let result = ArrayList<String>()
            for ((key, pid) in this.serviceIndex) {
                if (pid == providerId) {
                    result.add(key)
                }
            }
            result
        }
    }

    /**
     * 依赖变更通知辅助：返回 inject 了指定服务 Key 的所有存活实例
     * （docs/cordis-comparison.md §4 依赖变更通知）
     * 使用插件 initialize 握手时上报的依赖（instance.injects）
     */
    public func dependentsOf(key: String): ArrayList<PluginInstance> {
        synchronized(this.lock) {
            let result = ArrayList<PluginInstance>()
            for ((id, instance) in this.actual) {
                if (instance.injects.contains(key)) {
                    result.add(instance)
                }
            }
            result
        }
    }
}
