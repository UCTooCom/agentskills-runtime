/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.llm_usage

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.uctoo.LlmUsageLogsService
import magic.app.models.uctoo.LlmUsageLogsPO
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.{ArrayList, HashMap}
import std.time.DateTime

public class BillingReportController {
    private let usageService = LlmUsageLogsService()

    public func dailyReport(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let now = DateTime.now()
            let (records, _) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")

            let dailyMap = HashMap<String, DailySummary>()
            for (po in records) {
                let createdAt = po.createdAt
                let dayKey = createdAt.toString()[0..10]

                match (dailyMap.get(dayKey)) {
                    case Some(summary) =>
                        summary.promptTokens = summary.promptTokens + po.promptTokens
                        summary.completionTokens = summary.completionTokens + po.completionTokens
                        summary.totalTokens = summary.totalTokens + po.totalTokens
                        summary.totalCost = summary.totalCost + po.costAmount
                        summary.callCount = summary.callCount + 1
                    case None =>
                        let summary = DailySummary()
                        summary.date = dayKey
                        summary.promptTokens = po.promptTokens
                        summary.completionTokens = po.completionTokens
                        summary.totalTokens = po.totalTokens
                        summary.totalCost = po.costAmount
                        summary.callCount = 1
                        dailyMap.add(dayKey, summary)
                }
            }

            let reportArray = JsonArray()
            for ((_, s) in dailyMap) {
                let obj = JsonObject()
                obj.put("date", JsonString(s.date))
                obj.put("promptTokens", JsonInt(s.promptTokens))
                obj.put("completionTokens", JsonInt(s.completionTokens))
                obj.put("totalTokens", JsonInt(s.totalTokens))
                obj.put("totalCost", JsonFloat(s.totalCost))
                obj.put("callCount", JsonInt(s.callCount))
                reportArray.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", reportArray)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("BillingReport dailyReport error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func monthlyReport(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (records, _) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")

            let monthlyMap = HashMap<String, DailySummary>()
            for (po in records) {
                let createdAt = po.createdAt
                let monthKey = createdAt.toString()[0..7]

                match (monthlyMap.get(monthKey)) {
                    case Some(summary) =>
                        summary.promptTokens = summary.promptTokens + po.promptTokens
                        summary.completionTokens = summary.completionTokens + po.completionTokens
                        summary.totalTokens = summary.totalTokens + po.totalTokens
                        summary.totalCost = summary.totalCost + po.costAmount
                        summary.callCount = summary.callCount + 1
                    case None =>
                        let summary = DailySummary()
                        summary.date = monthKey
                        summary.promptTokens = po.promptTokens
                        summary.completionTokens = po.completionTokens
                        summary.totalTokens = po.totalTokens
                        summary.totalCost = po.costAmount
                        summary.callCount = 1
                        monthlyMap.add(monthKey, summary)
                }
            }

            let reportArray = JsonArray()
            for ((_, s) in monthlyMap) {
                let obj = JsonObject()
                obj.put("month", JsonString(s.date))
                obj.put("promptTokens", JsonInt(s.promptTokens))
                obj.put("completionTokens", JsonInt(s.completionTokens))
                obj.put("totalTokens", JsonInt(s.totalTokens))
                obj.put("totalCost", JsonFloat(s.totalCost))
                obj.put("callCount", JsonInt(s.callCount))
                reportArray.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", reportArray)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("BillingReport monthlyReport error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func exportCsv(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (records, _) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")

            let sb = StringBuilder()
            sb.append("id,agent_id,provider,model,prompt_tokens,completion_tokens,total_tokens,cost_amount,created_at\n")

            for (po in records) {
                let agentIdStr = match (po.agentId) { case Some(a) => a; case None => "" }
                sb.append("${po.id},${agentIdStr},${po.provider},${po.model},${po.promptTokens},${po.completionTokens},${po.totalTokens},${po.costAmount},${po.createdAt.toString()}\n")
            }

            res.status(200).header("Content-Type", "text/csv").header("Content-Disposition", "attachment; filename=billing_report.csv").send(sb.toString())
        } catch (e: Exception) {
            LogUtils.error("BillingReport exportCsv error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func _pad2(n: Int64): String {
        if (n < 10) { "0${n}" } else { "${n}" }
    }
}

class DailySummary {
    public var date: String = ""
    public var promptTokens: Int64 = 0
    public var completionTokens: Int64 = 0
    public var totalTokens: Int64 = 0
    public var totalCost: Float64 = 0.0
    public var callCount: Int64 = 0
}
