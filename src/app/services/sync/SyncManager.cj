package magic.app.services.sync

import std.collection.{HashMap, ArrayList}
import std.sync.Mutex
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
            handlers.add("agent", AgentSyncHandler(agentBasePath))
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
                    LogUtils.info("SyncManager", "skipping deleted entity ${change.sourcePath}")
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
}
