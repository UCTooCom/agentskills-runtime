package magic.app.controllers.sync

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.sync.{SyncService, SyncLogService}
import magic.log.LogUtils
import std.convert

public class SyncController {
    private let syncService: SyncService
    private let syncLogService: SyncLogService

    public init(syncService: SyncService, syncLogService: SyncLogService) {
        this.syncService = syncService
        this.syncLogService = syncLogService
    }

    public func syncFromFileSystem(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let entityTypeOpt = req.queryParam("entityType")
            let sourcePathOpt = req.queryParam("sourcePath")
            let entityIdOpt = req.queryParam("entityId")

            let entityType = if (let Some(et) <- entityTypeOpt) { et } else { "" }
            let sourcePath = if (let Some(sp) <- sourcePathOpt) { sp } else { "" }
            let entityId = if (let Some(eid) <- entityIdOpt) { eid } else { sourcePath }

            if (entityType.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"entityType is required\"}")
                return
            }
            let result = syncService.syncFromFileSystem(entityType, sourcePath, entityId)
            let msg = if (result.success) { "Sync successful" } else { result.message }
            // 转义 JSON 中的特殊字符
            let escapedMsg = msg.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
            res.status(200).json("{\"success\":${result.success},\"reason\":\"${escapedMsg}\"}")
        } catch (e: Exception) {
            LogUtils.error("SyncController", "syncFromFileSystem: ${e.message}")
            let escapedMsg = e.message.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
            res.status(500).json("{\"success\":false,\"reason\":\"${escapedMsg}\"}")
        }
    }

    public func syncToFileSystem(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let entityTypeOpt = req.pathParam("entityType")
            let entityIdOpt = req.pathParam("entityId")

            let entityType = if (let Some(et) <- entityTypeOpt) { et } else { "" }
            let entityId = if (let Some(eid) <- entityIdOpt) { eid } else { "" }

            if (entityType.isEmpty() || entityId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"entityType and entityId are required\"}")
                return
            }
            let result = syncService.syncToFileSystem(entityType, entityId)
            let msg = if (result.success) { "Sync successful" } else { result.message }
            // 转义 JSON 中的特殊字符
            let escapedMsg = msg.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
            res.status(200).json("{\"success\":${result.success},\"reason\":\"${escapedMsg}\"}")
        } catch (e: Exception) {
            LogUtils.error("SyncController", "syncToFileSystem: ${e.message}")
            let escapedMsg = e.message.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
            res.status(500).json("{\"success\":false,\"reason\":\"${escapedMsg}\"}")
        }
    }

    public func syncAll(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = syncService.syncAll()
            if (result.totalCount == 0) {
                res.status(200).json("{\"success\":false,\"reason\":\"SyncManager not initialized\",\"data\":{\"totalCount\":0,\"successCount\":0,\"failedCount\":0}}")
            } else {
                res.status(200).json("{\"success\":true,\"data\":{\"totalCount\":${result.totalCount},\"successCount\":${result.successCount},\"failedCount\":${result.failedCount}}}")
            }
        } catch (e: Exception) {
            LogUtils.error("SyncController", "syncAll: ${e.message}")
            let escapedMsg = e.message.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
            res.status(500).json("{\"success\":false,\"reason\":\"${escapedMsg}\"}")
        }
    }

    public func getStatus(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let entityTypeOpt = req.pathParam("entityType")
            let sourcePathOpt = req.queryParam("sourcePath")

            let entityType = if (let Some(et) <- entityTypeOpt) { et } else { "" }
            let sourcePath = if (let Some(sp) <- sourcePathOpt) { sp } else { "" }

            if (entityType == "agent") {
                match (syncService.getAgentStatus(sourcePath)) {
                    case Some(status) =>
                        res.status(200).json("{\"success\":true,\"data\":{\"syncStatus\":\"${status.syncStatus}\"}}")
                        return
                    case None => ()
                }
            } else if (entityType == "agent_skill") {
                match (syncService.getAgentSkillStatus(sourcePath)) {
                    case Some(status) =>
                        res.status(200).json("{\"success\":true,\"data\":{\"syncStatus\":\"${status.syncStatus}\"}}")
                        return
                    case None => ()
                }
            }
            res.status(404).json("{\"success\":false,\"reason\":\"Not found\"}")
        } catch (e: Exception) {
            LogUtils.error("SyncController", "getStatus: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"${e.message}\"}")
        }
    }

    public func getSummary(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentSummary = syncService.getAgentSummary()
            let skillSummary = syncService.getAgentSkillSummary()
            res.status(200).json("{\"success\":true,\"data\":{\"agent\":{\"synced\":${agentSummary.syncedCount},\"pending\":${agentSummary.pendingCount},\"failed\":${agentSummary.failedCount}},\"agent_skill\":{\"synced\":${skillSummary.syncedCount},\"pending\":${skillSummary.pendingCount},\"failed\":${skillSummary.failedCount}}}}")
        } catch (e: Exception) {
            LogUtils.error("SyncController", "getSummary: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"${e.message}\"}")
        }
    }

    public func getLogs(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let pageOpt = req.queryParam("page")
            let sizeOpt = req.queryParam("size")
            let entityTypeOpt = req.queryParam("entityType")

            let pageStr = if (let Some(p) <- pageOpt) { p } else { "1" }
            let sizeStr = if (let Some(s) <- sizeOpt) { s } else { "20" }
            let entityType = if (let Some(et) <- entityTypeOpt) { et } else { "" }

            let page = Int64.parse(pageStr)
            let size = Int64.parse(sizeStr)

            let result = if (entityType.isEmpty()) {
                syncLogService.getRecentLogs(page, size)
            } else {
                syncLogService.getLogsByEntityType(entityType, page, size)
            }
            var listJson = ""
            for (log in result.list) {
                if (listJson.isEmpty()) {
                    listJson = log.toJson()
                } else {
                    listJson = listJson + "," + log.toJson()
                }
            }
            res.status(200).json("{\"page\":${result.page},\"size\":${result.size},\"rows\":${result.rows},\"pages\":${result.pages},\"list\":[${listJson}]}")
        } catch (e: Exception) {
            LogUtils.error("SyncController", "getLogs: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"${e.message}\"}")
        }
    }
}
