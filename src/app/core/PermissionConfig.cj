/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core

import magic.config.{Config as AppConfig}
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import std.convert.Parsable
import std.env.getVariables

public class PermissionConfig {
    private static var globalEnabled: Bool = true
    private static var cacheTTL: Int64 = 300
    private static var cacheMaxSize: Int64 = 10000
    private static let tableLevelPermissions: HashMap<String, Bool> = HashMap<String, Bool>()
    private static var initialized: Bool = false

    public static func isRowLevelPermissionEnabled(): Bool {
        ensureInitialized()
        return globalEnabled
    }

    public static func isRowLevelPermissionEnabledForTable(entityType: String): Bool {
        ensureInitialized()
        let tableConfig = tableLevelPermissions.get(entityType)
        if (tableConfig.isSome()) {
            return tableConfig.getOrThrow()
        }
        return globalEnabled
    }

    public static func getPermissionCacheTTL(): Int64 {
        ensureInitialized()
        return cacheTTL
    }

    public static func getPermissionCacheMaxSize(): Int64 {
        ensureInitialized()
        return cacheMaxSize
    }

    public static func refreshConfig(): Unit {
        initialized = false
        tableLevelPermissions.clear()
        ensureInitialized()
    }

    private static func ensureInitialized(): Unit {
        if (initialized) {
            return
        }

        let enabledStr = AppConfig.env["ROW_LEVEL_PERMISSION_ENABLED"]
        if (let Some(v) <- enabledStr) {
            globalEnabled = v == "true"
        } else {
            globalEnabled = true
        }

        let ttlStr = AppConfig.env["PERMISSION_CACHE_TTL"]
        if (let Some(v) <- ttlStr) {
            let parsed = Int64.parse(v)
            if (parsed > 0) {
                cacheTTL = parsed
            } else {
                LogUtils.error("PermissionConfig", "Invalid PERMISSION_CACHE_TTL value: ${v}, using default 300")
                cacheTTL = 300
            }
        } else {
            cacheTTL = 300
        }

        let maxSizeStr = AppConfig.env["PERMISSION_CACHE_MAX_SIZE"]
        if (let Some(v) <- maxSizeStr) {
            let parsed = Int64.parse(v)
            if (parsed > 0) {
                cacheMaxSize = parsed
            } else {
                cacheMaxSize = 10000
            }
        } else {
            cacheMaxSize = 10000
        }

        loadTableLevelPermissions()

        initialized = true
    }

    private static func loadTableLevelPermissions(): Unit {
        let allVars = getVariables()
        for ((key, value) in allVars) {
            if (key.startsWith("ROW_LEVEL_PERMISSION_") && key != "ROW_LEVEL_PERMISSION_ENABLED") {
                let tableName = key.removePrefix("ROW_LEVEL_PERMISSION_")
                tableLevelPermissions[tableName] = value == "true"
            }
        }
    }
}
