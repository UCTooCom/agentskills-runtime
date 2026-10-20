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
        try {
            let envPath = envFileService.getEnvFilePath()
            LogUtils.info("ConfigSyncHandler", "Startup sync: checking .env file at: ${envPath}")
            let fileExists = envFileService.envFileExists(envPath)
            if (!fileExists) {
                LogUtils.warn("ConfigSyncHandler", ".env file not found: ${envPath}")
                return result
            }
            let envValues = envFileService.readAllEnvValues(envPath)
            LogUtils.info("ConfigSyncHandler", "Read ${envValues.size} config items from .env file")
            println("[STARTUP-DIAG][ConfigSync] >>> obtaining ORM.executor()")
            let executor = ORM.executor()
            println("[STARTUP-DIAG][ConfigSync] <<< ORM.executor() obtained")

            var diagIdx: Int32 = 0
            for ((key, value) in envValues) {
                diagIdx++
                println("[STARTUP-DIAG][ConfigSync] [${diagIdx}/${envValues.size}] begin envKey=${key}")
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
                            entity.isSensitive = Some(isSensitiveKey(key))
                            if (isSensitiveKey(key)) {
                                entity.configType = Some("password")
                            }
                            entity.lastSyncedAt = Some(DateTime.now())
                            executor.updateConfig(entity)
                            println("[STARTUP-DIAG][ConfigSync] [${diagIdx}] updateConfig done envKey=${key}")
                            detail.success = true
                            result.successCount++
                        case None =>
                            detail.dbValue = ""
                            detail.syncAction = "insert"
                            let newEntity = ConfigPO()
                            newEntity.name = key
                            newEntity.key = key
                            newEntity.envKey = Some(key)
                            newEntity.value = Some(if (isSensitiveKey(key)) { "***" } else { value })
                            newEntity.configGroup = Some("other")
                            newEntity.configType = Some(if (isSensitiveKey(key)) { "password" } else { "string" })
                            newEntity.isSensitive = Some(isSensitiveKey(key))
                            newEntity.editable = Some(true)
                            newEntity.displayOrder = Some(Int32(0))
                            newEntity.status = 1
                            newEntity.lastSyncedAt = Some(DateTime.now())
                            let insertId = executor.insertConfig(newEntity)
                            println("[STARTUP-DIAG][ConfigSync] [${diagIdx}] insertConfig done envKey=${key}")
                            detail.success = true
                            result.successCount++
                    }
                } catch (e: Exception) {
                    detail.success = false
                    detail.errorMessage = Some(e.message)
                    result.failedCount++
                }
                result.details.add(detail)
                println("[STARTUP-DIAG][ConfigSync] [${diagIdx}] end envKey=${key} success=${detail.success}")
            }
            LogUtils.info("ConfigSyncHandler", "Startup sync completed: ${result.successCount}/${result.totalCount} succeeded")
        } catch (e: Exception) {
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
                    entity.value = Some(if (isSensitiveKey(envKey)) { "***" } else { value })
                    entity.isSensitive = Some(isSensitiveKey(envKey))
                    if (isSensitiveKey(envKey)) {
                        entity.configType = Some("password")
                    }
                    entity.lastSyncedAt = Some(DateTime.now())
                    executor.updateConfig(entity)
                case None =>
                    let newEntity = ConfigPO()
                    newEntity.name = envKey
                    newEntity.key = envKey
                    newEntity.envKey = Some(envKey)
                    newEntity.value = Some(if (isSensitiveKey(envKey)) { "***" } else { value })
                    newEntity.configGroup = Some("other")
                    newEntity.configType = Some(if (isSensitiveKey(envKey)) { "password" } else { "string" })
                    newEntity.isSensitive = Some(isSensitiveKey(envKey))
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
                            entity.isSensitive = Some(isSensitiveKey(key))
                            if (isSensitiveKey(key)) {
                                entity.configType = Some("password")
                            }
                            entity.lastSyncedAt = Some(DateTime.now())
                            executor.updateConfig(entity)
                        case None =>
                            let newEntity = ConfigPO()
                            newEntity.name = key
                            newEntity.key = key
                            newEntity.envKey = Some(key)
                            newEntity.value = Some(resolvedValue)
                            newEntity.configGroup = Some("other")
                            newEntity.configType = Some(if (isSensitiveKey(key)) { "password" } else { "string" })
                            newEntity.isSensitive = Some(isSensitiveKey(key))
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
        // 敏感密钥绝不落明文进 config 表（统一真相源是大模型通道的 llm_channel 表 / 进程环境变量）
        if (isSensitiveKey(envKey)) {
            return "***"
        }
        envValue
    }

    /**
     * 判断是否敏感 key（API key / secret / token / password / 含密钥的 URL 等）。
     * 命中则同步进 config 表时一律掩码为 "***" 且标记 is_sensitive=true，
     * 从源头杜绝「.env 明文 → config 表明文」的泄漏（见 2026-10-14 复盘）。
     */
    private func isSensitiveKey(key: String): Bool {
        let k = key.toAsciiUpper()
        return k.contains("API_KEY") || k.contains("SECRET") || k.contains("PASSWORD") ||
               k.contains("PASSWD") || k.contains("TOKEN") || k.contains("PRIVATE_KEY") ||
               k.contains("ACCESS_KEY") || k.contains("AUTH_CORE") || k.contains("ENCRYPTION_KEY") ||
               k.contains("ENC_KEY") || k.contains("DATABASE_URL") || k.contains("CONNECTION_URL")
    }
}
