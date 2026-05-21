package magic.app.services.crontab.retry

import std.time.DateTime
import std.core.Duration
import magic.log.LogUtils
import magic.app.models.uctoo.CrontabPO
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult, TriggerType}
import magic.app.services.crontab.executor.CrontabExecutor

public class RetryManager {
    public func executeWithRetry(
        crontab: CrontabPO,
        executor: CrontabExecutor,
        context: CrontabExecutionContext
    ): ExecutionResult {
        let maxRetries = getMaxRetries(crontab)
        if (maxRetries <= 0) {
            return executor.execute(context)
        }

        var result = executor.execute(context)
        if (result.success) {
            return result
        }

        var attempt: Int32 = 1
        let strategy = getStrategy(crontab)

        while (attempt <= maxRetries && !result.success) {
            let delayMs = strategy.calculateDelay(attempt)
            LogUtils.info("RetryManager", "重试第${attempt}次, 延迟${delayMs}ms, 任务=${context.taskName}")

            try {
                sleep(Duration.millisecond * delayMs)
            } catch (_: Exception) {}

            context.triggerType = TriggerType.Retry
            context.retryAttempt = attempt

            result = executor.execute(context)
            attempt++
        }

        if (!result.success && attempt > maxRetries) {
            result.errorOutput = result.errorOutput + " [RETRY_EXHAUSTED]"
            LogUtils.error("RetryManager", "重试耗尽, 任务=${context.taskName}, maxRetries=${maxRetries}")
        }

        return result
    }

    private func getMaxRetries(crontab: CrontabPO): Int32 {
        match (crontab.maxRetries) {
            case Some(r) => r
            case None => 0
        }
    }

    private func getStrategy(crontab: CrontabPO): RetryStrategy {
        let task = crontab.task.toAsciiLower()
        if (task.startsWith("http://") || task.startsWith("https://")) {
            return RetryStrategy.ExponentialBackoff(2000, 2.0)
        }
        return RetryStrategy.FixedDelay(5000)
    }
}
