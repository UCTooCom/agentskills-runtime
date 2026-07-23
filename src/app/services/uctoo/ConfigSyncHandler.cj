/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.ConfigPO
import magic.app.dao.uctoo.ConfigDAO
import magic.log.LogUtils

public class SyncDetail {
    public var envKey: String = ""
    public var envValue: String = ""
    public var dbValue: String = ""
    public var syncAction: String = ""
    public var success: Bool = true
    public var errorMessage: Option<String> = None<String>

    public init() {}
}

public class SyncResult {
    public var totalCount: Int32 = 0
    public var successCount: Int32 = 0
    public var failedCount: Int32 = 0
    public var details: ArrayList<SyncDetail> = ArrayList<SyncDetail>()

    public init() {}
}

public class ConfigSyncHandler {
    private let envFileService = EnvFileService()

    public init() {}

    public func startupSync(): SyncResult {
        let result = SyncResult()
        eprintln("=== [ConfigSync] startupSync() ENTERED ===")
        try {
            let envPath = envFileService.getEnvFilePath()
            eprintln("=== [ConfigSync] envPath = ${envPath} ===")
            LogUtils.info("ConfigSyncHandler", "Startup sync: checking .env file at: ${envPath}")
            let fileExists = envFileService.envFileExists(envPath)
            eprintln("=== [ConfigSync] envFileExists = ${fileExists} ===")
            if (!fileExists) {
                LogUtils.warn("ConfigSyncHandler", ".env file not found: ${envPath}")
                return result
            }
            let envValues = envFileService.readAllEnvValues(envPath)
            eprintln("=== [ConfigSync] readAllEnvValues returned ${envValues.size} items ===")
            LogUtils.info("ConfigSyncHandler", "Read ${envValues.size} config items from .env file")
            eprintln("=== [ConfigSync] getting ORM.executor() ===")
            let executor = ORM.executor()
            eprintln("=== [ConfigSync] ORM.executor() obtained ===")

            var processedCount = 0
            for ((key, value) in envValues) {
                processedCount++
                if (processedCount <= 5) {
                    let displayVal = if (value.size > 30) { value[0..30] + "..." } else { value }
                    eprintln("=== [ConfigSync] processing #${processedCount}: key=${key}, value=${displayVal} ===")
                }
                let detail = SyncDetail()
                detail.envKey = key
                detail.envValue = value
                result.totalCount++

                try {
                    let existing = executor.findConfigByEnvKey(key)
                    match (existing) {
                        case Some(entity) =>
                            detail.dbValue = entity.value.getOrThrow()
                            detail.syncAction = "update"
                            let resolvedValue = resolveConflict(key, value, detail.dbValue)
                            entity.value = Some(resolvedValue)
                            entity.lastSyncedAt = Some(DateTime.now())
                            executor.updateConfig(entity)
                            detail.success = true
                            result.successCount++
                        case None =>
                            detail.dbValue = ""
                            detail.syncAction = "insert"
                            let newEntity = ConfigPO()
                            newEntity.name = key
                            newEntity.key = key
                            newEntity.envKey = Some(key)
                            newEntity.value = Some(value)
                            newEntity.configGroup = Some("other")
                            newEntity.configType = Some("string")
                            newEntity.isSensitive = Some(false)
                            newEntity.editable = Some(true)
                            newEntity.displayOrder = Some(Int32(0))
                            newEntity.status = 1
                            newEntity.lastSyncedAt = Some(DateTime.now())
                            let insertId = executor.insertConfig(newEntity)
                            eprintln("=== [ConfigSync] insertConfig for ${key}, returned id=${insertId} ===")
                            detail.success = true
                            result.successCount++
                    }
                } catch (e: Exception) {
                    eprintln("=== [ConfigSync] ERROR for key=${key}: ${e.message} ===")
                    detail.success = false
                    detail.errorMessage = Some(e.message)
                    result.failedCount++
                }
                result.details.add(detail)
            }
            eprintln("=== [ConfigSync] Startup sync completed: ${result.successCount}/${result.totalCount} succeeded, ${result.failedCount} failed ===")
            LogUtils.info("ConfigSyncHandler", "Startup sync completed: ${result.successCount}/${result.totalCount} succeeded")
        } catch (e: Exception) {
            eprintln("=== [ConfigSync] FATAL ERROR: ${e.message} ===")
            LogUtils.error("ConfigSyncHandler", "Startup sync failed: ${e.message}")
        }
        result
    }

    public func dualWrite(envKey: String, value: String): SyncResult {
        let result = SyncResult()
        result.totalCount = 1
        let detail = SyncDetail()
        detail.envKey = envKey
        detail.envValue = value
        detail.syncAction = "dualWrite"

        try {
            let envPath = envFileService.getEnvFilePath()
            let writeOk = envFileService.writeEnvKeyValue(envPath, envKey, value)
            if (!writeOk) {
                detail.success = false
                detail.errorMessage = Some("Failed to write .env file")
                result.failedCount = 1
                result.details.add(detail)
                return result
            }

            let executor = ORM.executor()
            let existing = executor.findConfigByEnvKey(envKey)
            match (existing) {
                case Some(entity) =>
                    detail.dbValue = entity.value.getOrThrow()
                    entity.value = Some(value)
                    entity.lastSyncedAt = Some(DateTime.now())
                    executor.updateConfig(entity)
                case None =>
                    let newEntity = ConfigPO()
                    newEntity.name = envKey
                    newEntity.key = envKey
                    newEntity.envKey = Some(envKey)
                    newEntity.value = Some(value)
                    newEntity.configGroup = Some("other")
                    newEntity.configType = Some("string")
                    newEntity.isSensitive = Some(false)
                    newEntity.editable = Some(true)
                    newEntity.displayOrder = Some(Int32(0))
                    newEntity.status = 1
                    newEntity.lastSyncedAt = Some(DateTime.now())
                    executor.insertConfig(newEntity)
            }
            detail.success = true
            result.successCount = 1
        } catch (e: Exception) {
            detail.success = false
            detail.errorMessage = Some(e.message)
            result.failedCount = 1
        }
        result.details.add(detail)
        result
    }

    public func scheduledSync(): SyncResult {
        let result = SyncResult()
        try {
            let envPath = envFileService.getEnvFilePath()
            if (!envFileService.envFileExists(envPath)) {
                return result
            }
            let envValues = envFileService.readAllEnvValues(envPath)
            let executor = ORM.executor()
            let dbConfigs = executor.findAllEnvConfigs()
            let dbMap = HashMap<String, String>()
            for (config in dbConfigs) {
                match (config.envKey) {
                    case Some(k) =>
                        match (config.value) {
                            case Some(v) => dbMap.add(k, v)
                            case None => ()
                        }
                    case None => ()
                }
            }

            for ((key, envValue) in envValues) {
                let dbValue = dbMap.get(key) ?? ""
                if (envValue != dbValue) {
                    let detail = SyncDetail()
                    detail.envKey = key
                    detail.envValue = envValue
                    detail.dbValue = dbValue
                    detail.syncAction = "scheduledUpdate"
                    result.totalCount++

                    try {
                        let resolvedValue = resolveConflict(key, envValue, dbValue)
                        let existing = executor.findConfigByEnvKey(key)
                        match (existing) {
                            case Some(entity) =>
                                entity.value = Some(resolvedValue)
                                entity.lastSyncedAt = Some(DateTime.now())
                                executor.updateConfig(entity)
                            case None =>
                                let newEntity = ConfigPO()
                                newEntity.name = key
                                newEntity.key = key
                                newEntity.envKey = Some(key)
                                newEntity.value = Some(resolvedValue)
                                newEntity.configGroup = Some("other")
                                newEntity.configType = Some("string")
                                newEntity.isSensitive = Some(false)
                                newEntity.editable = Some(true)
                                newEntity.displayOrder = Some(Int32(0))
                                newEntity.status = 1
                                newEntity.lastSyncedAt = Some(DateTime.now())
                                executor.insertConfig(newEntity)
                        }
                        detail.success = true
                        result.successCount++
                    } catch (e: Exception) {
                        detail.success = false
                        detail.errorMessage = Some(e.message)
                        result.failedCount++
                    }
                    result.details.add(detail)
                }
            }
            if (result.totalCount > 0) {
                LogUtils.info("ConfigSyncHandler", "Scheduled sync: ${result.successCount}/${result.totalCount} updated")
            }
        } catch (e: Exception) {
            LogUtils.error("ConfigSyncHandler", "Scheduled sync failed: ${e.message}")
        }
        result
    }

    public func manualSyncFromEnv(): SyncResult {
        startupSync()
    }

    public func resolveConflict(envKey: String, envValue: String, dbValue: String): String {
        envValue
    }
}
