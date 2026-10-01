package magic.app.services.sync

import std.collection.{HashMap, ArrayList}
import std.sync.Mutex
import std.fs.exists
import magic.app.services.sync.model.{SyncResult, SyncBatchResult, SyncDirection, TriggerSource, FileChange, ChangeType, SyncStatus}
import magic.app.services.sync.context.SyncContext
import magic.app.services.sync.handler.{SyncHandler, AgentSyncHandler, AgentSkillSyncHandler}
import magic.app.services.sync.infrastructure.TopologySorter
import magic.app.services.sync.retry.RetryManager
import magic.app.services.sync.resolver.ConflictResolver
import magic.log.LogUtils

public class SyncManager {
    private static var instance_: Option<SyncManager> = None
    private let mutex = Mutex()
    private let handlers = HashMap<String, SyncHandler>()
    private let retryManager = RetryManager()
    private let conflictResolver = ConflictResolver()
    private let topologySorter = TopologySorter()
    private var initialized = false

    public init() {}

    public static prop instance: Option<SyncManager> {
        get() { instance_ }
    }

    public static func initialize(agentBasePath: String, skillBasePath: String): SyncManager {
        let manager = SyncManager()
        manager.setupHandlers(agentBasePath, skillBasePath)
        instance_ = Some(manager)
        return manager
    }

    public func setupHandlers(agentBasePath: String, skillBasePath: String): Unit {
        mutex.lock()
        try {
            // 路径存在性校验日志
            if (!exists(agentBasePath)) {
                LogUtils.warn("SyncManager: agentBasePath does not exist: ${agentBasePath} - agent sync will be empty")
            } else {
                LogUtils.info("SyncManager: agentBasePath exists: ${agentBasePath}")
            }
            if (!exists(skillBasePath)) {
                LogUtils.warn("SyncManager: skillBasePath does not exist: ${skillBasePath} - agent_skill sync will be empty")
            } else {
                LogUtils.info("SyncManager: skillBasePath exists: ${skillBasePath}")
            }
            // agent 同步也要扫技能目录：技能内 bundled 子 agent（skills/<skill>/agents/）同属"声明即注册"
            handlers.add("agent", AgentSyncHandler(agentBasePath, skillBasePath: skillBasePath))
            handlers.add("agent_skill", AgentSkillSyncHandler(skillBasePath))
            initialized = true
            LogUtils.info("SyncManager: handlers initialized - agent[${agentBasePath}], agent_skill[${skillBasePath}]")
        } finally {
            mutex.unlock()
        }
    }

    public func syncFromFileSystem(entityType: String, sourcePath: String, entityId: String, trigger: TriggerSource): SyncResult {
        match (handlers.get(entityType)) {
            case Some(handler) =>
                // 如果 sourcePath 为空，扫描整个目录并同步所有文件
                if (sourcePath.isEmpty()) {
                    let changes = handler.detectChanges()
                    if (changes.isEmpty()) {
                        return SyncResult(false, entityType, entityId, SyncStatus.Error, "No files found in base path: ${handler.basePath}")
                    }
                    // 同步第一个文件（测试场景）
                    let firstChange = changes[0]
                    let context = SyncContext(trigger, SyncDirection.FileSystemToDB, entityType, firstChange.sourcePath)
                    SyncContext.enter(context)
                    try {
                        return retryManager.executeWithRetry(entityType, firstChange.sourcePath, { => handler.syncFromFileSystem(firstChange.sourcePath, context) })
                    } finally {
                        SyncContext.exit()
                    }
                }
                let context = SyncContext(trigger, SyncDirection.FileSystemToDB, entityType, entityId)
                SyncContext.enter(context)
                try {
                    return retryManager.executeWithRetry(entityType, entityId, { => handler.syncFromFileSystem(sourcePath, context) })
                } finally {
                    SyncContext.exit()
                }
            case None =>
                return SyncResult(false, entityType, entityId, SyncStatus.Error, "No handler found for entity type: ${entityType}")
        }
    }

    public func syncToFileSystem(entityType: String, entityId: String, trigger: TriggerSource): SyncResult {
        match (handlers.get(entityType)) {
            case Some(handler) =>
                let context = SyncContext(trigger, SyncDirection.DBToFileSystem, entityType, entityId)
                SyncContext.enter(context)
                try {
                    return retryManager.executeWithRetry(entityType, entityId, { => handler.syncToFileSystem(entityId, context) })
                } finally {
                    SyncContext.exit()
                }
            case None =>
                return SyncResult(false, entityType, entityId, SyncStatus.Error, "No handler found for entity type: ${entityType}")
        }
    }

    public func syncAll(trigger: TriggerSource): SyncBatchResult {
        let result = SyncBatchResult()
        let handlerList = ArrayList<SyncHandler>()
        for ((_, handler) in handlers.iterator()) {
            handlerList.add(handler)
        }
        let sortedHandlers = TopologySorter.sort(handlerList.toArray())
        for (handler in sortedHandlers) {
            let et = handler.entityType
            let changes = handler.detectChanges()
            for (change in changes) {
                result.totalCount++
                if (let ChangeType.Deleted <- change.changeType) {
                    // 删除即下线（2026-09-28）：此前一律跳过，导致"删声明文件即下线"只说了一半
                    // ——文件删了、库里行还在，子 agent 仍可被派单。
                    // 仅 agent 实体做**软删**（置 deleted_at），其他实体类型维持跳过：
                    // 软删也只对有明确 source_path 的记录生效，不做物理删除。
                    SyncManager.offlineDeletedAgent(handler, change.sourcePath)
                    continue
                }
                let syncResult = syncFromFileSystem(et, change.sourcePath, change.sourcePath, trigger)
                result.details.add(syncResult)
                if (syncResult.success) {
                    result.successCount++
                } else {
                    result.failedCount++
                }
            }
        }
        LogUtils.info("SyncManager: syncAll completed - total:${result.totalCount}, success:${result.successCount}, failed:${result.failedCount}")
        return result
    }

    public func getHandler(entityType: String): Option<SyncHandler> {
        handlers.get(entityType)
    }

    public func getRegisteredEntityTypes(): Array<String> {
        handlers.keys().toArray()
    }

    private func getHandlerDependencies(): HashMap<String, Array<String>> {
        let deps = HashMap<String, Array<String>>()
        for ((key, handler) in handlers.iterator()) {
            deps.add(key, handler.dependencies)
        }
        return deps
    }

    /**
     * 文件被删时的下线处理：只对 agent 生效（软删），其余实体类型维持"跳过"。
     *
     * 用 `as` 安全向下转型取 `AgentSyncHandler`（先例 `PermissionUtils.cj`），
     * 而不是给 SyncHandler 接口加方法——接口改动会波及所有 handler，
     * 而"删除下线"目前只有 agent 有明确语义。
     */
    private static func offlineDeletedAgent(handler: SyncHandler, sourcePath: String): Unit {
        let opt = handler as AgentSyncHandler
        match (opt) {
            case Some(h) =>
                try {
                    if (h.offlineBySourcePath(sourcePath)) {
                        LogUtils.info("SyncManager", "deleted entity 已下线(软删) ${sourcePath}")
                    } else {
                        LogUtils.info("SyncManager", "deleted entity 无需下线（库里无对应行） ${sourcePath}")
                    }
                } catch (e: Exception) {
                    LogUtils.warn("SyncManager", "deleted entity 下线失败（忽略）: ${sourcePath}, ${e.message}")
                }
            case None =>
                LogUtils.info("SyncManager", "skipping deleted entity ${sourcePath}（该类型未实现下线）")
        }
    }
}
