/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab.executor


import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.app.services.uctoo.UsageQuotasService
import magic.app.models.uctoo.UsageQuotasPO
import magic.log.LogUtils
import std.time.DateTime
import std.core.Duration
import std.collection.ArrayList

public class QuotaResetExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "quota_reset" }
    }

    private let quotasService = UsageQuotasService()

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()

        try {
            let (quotas, total) = quotasService.getListWithFilter(1, 10000, "", "")
            var resetCount: Int64 = 0
            let now = DateTime.now()

            for (quota in quotas) {
                if (quota.deletedAt.isSome()) {
                    continue
                }

                let periodStart = quota.quotaPeriodStart
                if (periodStart.isEmpty()) {
                    continue
                }

                var shouldReset = false
                let quotaType = quota.quotaType

                if (quotaType.startsWith("daily_")) {
                    shouldReset = _isPeriodExpired(periodStart, now, Duration.day)
                } else if (quotaType.startsWith("monthly_")) {
                    shouldReset = _isPeriodExpired(periodStart, now, Duration.day * 30)
                } else if (quotaType.startsWith("weekly_")) {
                    shouldReset = _isPeriodExpired(periodStart, now, Duration.day * 7)
                }

                if (shouldReset) {
                    quota.quotaUsed = 0.0
                    quota.quotaPeriodStart = now.toString()
                    quota.updatedAt = now

                    try {
                        quotasService.update(quota.id, quota)
                        resetCount = resetCount + 1
                        LogUtils.info("Reset quota: ${quota.id} (${quota.targetType}/${quota.targetId}/${quotaType})")
                    } catch (ex: Exception) {
                        LogUtils.error("Failed to reset quota ${quota.id}: ${ex.message}")
                    }
                }
            }

            let duration = _calcDuration(startTime)
            let output = "Reset ${resetCount} quotas out of ${total} total"
            return ExecutionResult.successResult(output, duration, output)
        } catch (e: Exception) {
            let duration = _calcDuration(startTime)
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }

    public func validate(taskUri: String): Bool {
        let path = ExecutorRegistry.parsePath(taskUri)
        path.size > 0
    }

    private func _isPeriodExpired(periodStartStr: String, now: DateTime, periodDuration: Duration): Bool {
        try {
            let periodStart = DateTime.parse(periodStartStr)
            let elapsed = now - periodStart
            return elapsed >= periodDuration
        } catch (_: Exception) {
            return true
        }
    }

    private func _calcDuration(startTime: DateTime): Int64 {
        let now = DateTime.now()
        return (now - startTime).toMilliseconds()
    }
}