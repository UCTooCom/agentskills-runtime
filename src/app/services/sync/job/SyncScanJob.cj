package magic.app.services.sync.job

import f_ticktock.CronTicktockTask
import magic.app.services.sync.SyncManager
import magic.app.services.sync.model.TriggerSource
import magic.log.LogUtils

public class SyncScanJob <: CronTicktockTask {
    public prop name: String {
        get() { "sync-periodic-scan" }
    }

    public prop cron: String {
        get() { "0 0 */5 * * *" }
    }

    public func execute(): Unit {
        LogUtils.info("SyncScanJob", "starting periodic file scan sync")
        try {
            match (SyncManager.instance) {
                case Some(manager) =>
                    let result = manager.syncAll(TriggerSource.SyncSystem)
                    LogUtils.info("SyncScanJob", "completed - total:${result.totalCount}, success:${result.successCount}, failed:${result.failedCount}")
                case None =>
                    LogUtils.warn("SyncScanJob: SyncManager not initialized, skipping")
            }
        } catch (e: Exception) {
            LogUtils.error("SyncScanJob: failed - ${e.message}")
        }
    }
}
