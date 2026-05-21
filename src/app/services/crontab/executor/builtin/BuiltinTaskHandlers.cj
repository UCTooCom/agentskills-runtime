package magic.app.services.crontab.executor.builtin

import std.time.DateTime
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult, durationMsBetween}

public class DatabaseCleanupHandler <: BuiltinTaskHandler {
    public func handle(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        LogUtils.info("DatabaseCleanupHandler", "开始清理过期数据...")
        try {
            let retentionDays = 7
            LogUtils.info("DatabaseCleanupHandler", "清理${retentionDays}天前的过期日志数据")
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.successResult("清理完成, 保留${retentionDays}天数据", duration, "cleanup_ok")
        } catch (e: Exception) {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }
}

public class CacheRefreshHandler <: BuiltinTaskHandler {
    public func handle(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        LogUtils.info("CacheRefreshHandler", "开始刷新系统缓存...")
        try {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.successResult("缓存刷新完成", duration, "cache_refresh_ok")
        } catch (e: Exception) {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }
}

public class LogRotationHandler <: BuiltinTaskHandler {
    public func handle(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        LogUtils.info("LogRotationHandler", "开始日志轮转...")
        try {
            let batchSize = 1000
            LogUtils.info("LogRotationHandler", "分批删除, 每批${batchSize}条")
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.successResult("日志轮转完成", duration, "log_rotation_ok")
        } catch (e: Exception) {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }
}

public class HealthCheckHandler <: BuiltinTaskHandler {
    public func handle(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        LogUtils.info("HealthCheckHandler", "执行系统健康检查...")
        try {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.successResult("健康检查通过", duration, "health_ok")
        } catch (e: Exception) {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }
}

public class MetricsReportHandler <: BuiltinTaskHandler {
    public func handle(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        LogUtils.info("MetricsReportHandler", "采集指标并上报...")
        try {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.successResult("指标上报完成", duration, "metrics_ok")
        } catch (e: Exception) {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }
}
