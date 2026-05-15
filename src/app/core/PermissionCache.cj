/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core

import std.collection.{HashMap, ArrayList}
import std.sync.Mutex
import std.time.DateTime
import magic.log.LogUtils

public class PermissionCache {
    private static let cache: HashMap<String, CacheEntry> = HashMap<String, CacheEntry>()
    private static let filterCache: HashMap<String, FilterCacheEntry> = HashMap<String, FilterCacheEntry>()
    private static let lock: Mutex = Mutex()

    public static func get(userId: String, entityType: String, entityId: String): Option<Int32> {
        lock.lock()
        try {
            let key = buildKey(userId, entityType, entityId)
            let entry = cache.get(key)
            if (entry.isSome()) {
                let e = entry.getOrThrow()
                if (!e.isExpired()) {
                    return Some(e.permission)
                }
                cache.remove(key)
            }
            return None<Int32>
        } catch (e: Exception) {
            return None<Int32>
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    public static func put(userId: String, entityType: String, entityId: String, permission: Int32): Unit {
        lock.lock()
        try {
            let maxSize = PermissionConfig.getPermissionCacheMaxSize()
            if (cache.size >= maxSize) {
                evictOldest()
            }
            let key = buildKey(userId, entityType, entityId)
            let ttl = PermissionConfig.getPermissionCacheTTL()
            let now = DateTime.now().toUnixTimeStamp().toSeconds()
            cache[key] = CacheEntry(permission, now, now + ttl)
        } catch (e: Exception) {
            LogUtils.error("PermissionCache", "Failed to put cache: ${e.message}")
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    public static func getFilterCache(userId: String, entityType: String): Option<ArrayList<String>> {
        lock.lock()
        try {
            let key = "${userId}:${entityType}:filter"
            let entry = filterCache.get(key)
            if (entry.isSome()) {
                let e = entry.getOrThrow()
                if (!e.isExpired()) {
                    return Some(e.entityIds)
                }
                filterCache.remove(key)
            }
            return None<ArrayList<String>>
        } catch (e: Exception) {
            return None<ArrayList<String>>
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    public static func putFilterCache(userId: String, entityType: String, entityIds: ArrayList<String>): Unit {
        lock.lock()
        try {
            let key = "${userId}:${entityType}:filter"
            let ttl = PermissionConfig.getPermissionCacheTTL()
            let now = DateTime.now().toUnixTimeStamp().toSeconds()
            filterCache[key] = FilterCacheEntry(entityIds, now, now + ttl)
        } catch (e: Exception) {
            LogUtils.error("PermissionCache", "Failed to put filter cache: ${e.message}")
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    public static func invalidate(userId: String, entityType: String, entityId: String): Unit {
        lock.lock()
        try {
            cache.remove(buildKey(userId, entityType, entityId))
            filterCache.remove("${userId}:${entityType}:filter")
        } catch (e: Exception) {
            LogUtils.error("PermissionCache", "Failed to invalidate cache: ${e.message}")
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    public static func invalidateByUserAndEntityType(userId: String, entityType: String): Unit {
        lock.lock()
        try {
            let keysToRemove = ArrayList<String>()
            for ((key, _) in cache) {
                if (key.startsWith("${userId}:${entityType}:")) {
                    keysToRemove.add(key)
                }
            }
            for (key in keysToRemove) {
                cache.remove(key)
            }
            filterCache.remove("${userId}:${entityType}:filter")
        } catch (e: Exception) {
            LogUtils.error("PermissionCache", "Failed to invalidate cache by user: ${e.message}")
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    public static func invalidateByEntity(entityType: String, entityId: String): Unit {
        lock.lock()
        try {
            let keysToRemove = ArrayList<String>()
            for ((key, _) in cache) {
                if (key.contains(":${entityType}:${entityId}")) {
                    keysToRemove.add(key)
                }
            }
            for (key in keysToRemove) {
                cache.remove(key)
            }
            let filterKeysToRemove = ArrayList<String>()
            for ((key, _) in filterCache) {
                if (key.contains(":${entityType}:filter")) {
                    filterKeysToRemove.add(key)
                }
            }
            for (key in filterKeysToRemove) {
                filterCache.remove(key)
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionCache", "Failed to invalidate cache by entity: ${e.message}")
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    public static func clearAll(): Unit {
        lock.lock()
        try {
            cache.clear()
            filterCache.clear()
        } catch (e: Exception) {
            LogUtils.error("PermissionCache", "Failed to clear cache: ${e.message}")
        } finally {
            try { lock.unlock() } catch (_: Exception) {}
        }
    }

    private static func buildKey(userId: String, entityType: String, entityId: String): String {
        return "${userId}:${entityType}:${entityId}"
    }

    private static func evictOldest(): Unit {
        var oldestKey: Option<String> = None<String>
        var oldestTime: Int64 = Int64.Max
        for ((key, entry) in cache) {
            if (entry.createdAt < oldestTime) {
                oldestTime = entry.createdAt
                oldestKey = Some(key)
            }
        }
        if (let Some(key) <- oldestKey) {
            cache.remove(key)
        }
    }
}

class CacheEntry {
    public var permission: Int32
    public var createdAt: Int64
    public var expireTime: Int64

    public init(permission: Int32, createdAt: Int64, expireTime: Int64) {
        this.permission = permission
        this.createdAt = createdAt
        this.expireTime = expireTime
    }

    public func isExpired(): Bool {
        let now = DateTime.now().toUnixTimeStamp().toSeconds()
        return now > expireTime
    }
}

class FilterCacheEntry {
    public var entityIds: ArrayList<String>
    public var createdAt: Int64
    public var expireTime: Int64

    public init(entityIds: ArrayList<String>, createdAt: Int64, expireTime: Int64) {
        this.entityIds = entityIds
        this.createdAt = createdAt
        this.expireTime = expireTime
    }

    public func isExpired(): Bool {
        let now = DateTime.now().toUnixTimeStamp().toSeconds()
        return now > expireTime
    }
}
