package magic.app.services.sync

import magic.app.services.sync.model.{SyncResult, SyncBatchResult, TriggerSource, SyncStatusSummary, SyncEntityStatus}
import magic.app.services.sync.status.SyncStatusManager
import magic.log.LogUtils

public class SyncService {
    private let statusManager = SyncStatusManager()

    public init() {}

    public func syncFromFileSystem(entityType: String, sourcePath: String, entityId: String): SyncResult {
        match (SyncManager.instance) {
            case Some(manager) =>
                return manager.syncFromFileSystem(entityType, sourcePath, entityId, TriggerSource.Manual)
            case None =>
                let result = SyncResult()
                result.success = false
                result.entityType = entityType
                result.entityId = entityId
                result.message = "SyncManager not initialized"
                return result
        }
    }

    public func syncToFileSystem(entityType: String, entityId: String): SyncResult {
        match (SyncManager.instance) {
            case Some(manager) =>
                return manager.syncToFileSystem(entityType, entityId, TriggerSource.Manual)
            case None =>
                let result = SyncResult()
                result.success = false
                result.entityType = entityType
                result.entityId = entityId
                result.message = "SyncManager not initialized"
                return result
        }
    }

    public func syncAll(): SyncBatchResult {
        match (SyncManager.instance) {
            case Some(manager) =>
                return manager.syncAll(TriggerSource.Manual)
            case None =>
                let result = SyncBatchResult()
                return result
        }
    }

    public func getAgentStatus(sourcePath: String): Option<SyncEntityStatus> {
        return statusManager.getAgentStatus(sourcePath)
    }

    public func getAgentSkillStatus(sourcePath: String): Option<SyncEntityStatus> {
        return statusManager.getAgentSkillStatus(sourcePath)
    }

    public func getAgentSummary(): SyncStatusSummary {
        return statusManager.getAgentSummary()
    }

    public func getAgentSkillSummary(): SyncStatusSummary {
        return statusManager.getAgentSkillSummary()
    }
}