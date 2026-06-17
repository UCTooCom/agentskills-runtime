package magic.app.services.sync

import std.collection.ArrayList
import std.time.DateTime
import f_orm.*
import f_orm.sql.Pagination
import magic.app.dao.uctoo.SyncLogDAO
import magic.app.models.uctoo.SyncLogPO
import magic.log.LogUtils

public class SyncLogService {
    public init() {}

    public func createLog(
        entityType: String,
        sourcePath: String,
        operation: String,
        direction: String,
        status: String,
        message: Option<String>,
        errorDetail: Option<String>,
        syncSource: String,
        durationMs: Option<Int32>
    ): String {
        try {
            let po = SyncLogPO()
            po.entityType = entityType
            po.sourcePath = sourcePath
            po.operation = operation
            po.direction = direction
            po.status = status
            po.message = message
            po.errorDetail = errorDetail
            po.syncSource = syncSource
            po.durationMs = durationMs
            po.creator = Some("sync_system")
            po.createdAt = Some(DateTime.now())
            po.updatedAt = Some(DateTime.now())
            let syncLogDAO = ORM.executor() as SyncLogDAO
            if (let Some(dao) <- syncLogDAO) {
                return dao.insertSyncLog(po)
            }
            return ""
        } catch (e: Exception) {
            LogUtils.error("SyncLogService.createLog failed: ${e.message}")
            return ""
        }
    }

    public func getLogById(id: String): Option<SyncLogPO> {
        try {
            let syncLogDAO = ORM.executor() as SyncLogDAO
            if (let Some(dao) <- syncLogDAO) {
                return dao.findSyncLogById(id)
            }
            return None
        } catch (_: Exception) {
            return None
        }
    }

    public func getLogsByEntityType(entityType: String, page: Int64, size: Int64): Pagination<SyncLogPO> {
        try {
            let syncLogDAO = ORM.executor() as SyncLogDAO
            if (let Some(dao) <- syncLogDAO) {
                return dao.findSyncLogByDynamicCondition(
                    "entity_type = '${entityType}'",
                    "created_at DESC",
                    page,
                    size
                )
            }
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        } catch (_: Exception) {
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        }
    }

    public func getLogsBySourcePath(sourcePath: String, page: Int64, size: Int64): Pagination<SyncLogPO> {
        try {
            let syncLogDAO = ORM.executor() as SyncLogDAO
            if (let Some(dao) <- syncLogDAO) {
                return dao.findSyncLogByDynamicCondition(
                    "source_path = '${sourcePath}'",
                    "created_at DESC",
                    page,
                    size
                )
            }
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        } catch (_: Exception) {
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        }
    }

    public func getRecentLogs(page: Int64, size: Int64): Pagination<SyncLogPO> {
        try {
            let syncLogDAO = ORM.executor() as SyncLogDAO
            if (let Some(dao) <- syncLogDAO) {
                return dao.findSyncLogByDynamicCondition(
                    "",
                    "created_at DESC",
                    page,
                    size
                )
            }
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        } catch (_: Exception) {
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        }
    }

    public func getFailedLogs(page: Int64, size: Int64): Pagination<SyncLogPO> {
        try {
            let syncLogDAO = ORM.executor() as SyncLogDAO
            if (let Some(dao) <- syncLogDAO) {
                return dao.findSyncLogByDynamicCondition(
                    "status = 'error'",
                    "created_at DESC",
                    page,
                    size
                )
            }
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        } catch (_: Exception) {
            return Pagination<SyncLogPO>(page: page, size: size, rows: 0, list: ArrayList<SyncLogPO>())
        }
    }
}
