package magic.app.services.crontab

import std.sync.AtomicBool
import std.time.DateTime
import std.core.Duration
import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import magic.log.LogUtils
import f_ticktock.{Ticktock, CronCompiler}
import magic.app.models.uctoo.{CrontabPO, CrontabLogPO}
import magic.app.dao.uctoo.{CrontabDAO, CrontabLogDAO, CrontabTaskRegistryDAO}
import magic.app.services.crontab.model.{TriggerType, triggerTypeToString, CrontabExecutionContext, ExecutionResult, SchedulerStatus, durationMsBetween}
import magic.app.services.crontab.executor.{ExecutorRegistry, CrontabExecutor, ScriptExecutor, HttpExecutor, BuiltinExecutor, AgentExecutionExecutor, QuotaResetExecutor}
import magic.app.services.crontab.executor.builtin.{BuiltinTaskHandler, DatabaseCleanupHandler, CacheRefreshHandler, LogRotationHandler, HealthCheckHandler, MetricsReportHandler, AibuilderTaskRefundHandler}
import magic.app.services.crontab.misfire.{MisfireManager, MisfireAction}
import magic.app.services.crontab.retry.RetryManager
import magic.app.services.crontab.log.AsyncLogWriter

public class SchedulerEngine {
    private static var instance_: Option<SchedulerEngine> = None<SchedulerEngine>

    private let executorRegistry = ExecutorRegistry()
    private let misfireManager = MisfireManager()
    private let retryManager = RetryManager()
    private var asyncLogWriter: Option<AsyncLogWriter> = None<AsyncLogWriter>

    private let runningTasks = ConcurrentHashMap<String, DateTime>()
    private let shuttingDown = AtomicBool(false)

    private var ticktock: Option<Ticktock> = None<Ticktock>
    private var crontabDAO: Option<CrontabDAO> = None<CrontabDAO>
    private var crontabLogDAO: Option<CrontabLogDAO> = None<CrontabLogDAO>

    private var totalTaskCount: Int32 = 0
    private var activeTaskCount: Int32 = 0

    private init() {}

    public static func initialize(crontabDAO: CrontabDAO, crontabLogDAO: CrontabLogDAO, crontabTaskRegistryDAO: CrontabTaskRegistryDAO): Unit {
        match (instance_) {
            case Some(_) =>
                LogUtils.info("SchedulerEngine", "调度引擎已初始化, 跳过")
            case None =>
                let engine = SchedulerEngine()
                engine.crontabDAO = Some(crontabDAO)
                engine.crontabLogDAO = Some(crontabLogDAO)

                engine.initExecutors()

                let logWriter = AsyncLogWriter(crontabLogDAO)
                logWriter.start()
                engine.asyncLogWriter = Some(logWriter)

                engine.loadAllActiveTasks()

                instance_ = Some(engine)
                LogUtils.info("SchedulerEngine", "调度引擎初始化成功")
        }
    }

    public static prop instance: Option<SchedulerEngine> {
        get() { instance_ }
    }

    private func initExecutors(): Unit {
        let scriptExecutor = ScriptExecutor()
        let httpExecutor = HttpExecutor()
        let builtinExecutor = BuiltinExecutor()

        builtinExecutor.registerBuiltinTask("database-cleanup", DatabaseCleanupHandler())
        builtinExecutor.registerBuiltinTask("cache-refresh", CacheRefreshHandler())
        builtinExecutor.registerBuiltinTask("log-rotation", LogRotationHandler())
        builtinExecutor.registerBuiltinTask("health-check", HealthCheckHandler())
        builtinExecutor.registerBuiltinTask("metrics-report", MetricsReportHandler())
        builtinExecutor.registerBuiltinTask("aibuilder-task-refund", AibuilderTaskRefundHandler())

        executorRegistry.register("script", scriptExecutor)
        executorRegistry.register("http", httpExecutor)
        executorRegistry.register("builtin", builtinExecutor)
        executorRegistry.register("agent_execution", AgentExecutionExecutor())
        executorRegistry.register("quota_reset", QuotaResetExecutor())
    }

    public func loadAllActiveTasks(): Unit {
        match (crontabDAO) {
            case Some(dao) =>
                try {
                    let ticktockOpt = Ticktock.getInstance(anyway: true)
                    match (ticktockOpt) {
                        case Some(ticktockInstance) =>
                            ticktock = Some<Ticktock>(ticktockInstance)

                            let allTasks = dao.listAllCrontab()
                            var activeCount: Int32 = 0
                            var totalCount: Int32 = 0

                            for (task in allTasks) {
                                if (task.deletedAt != None) { continue }
                                totalCount++

                                if (task.status != 1) { continue }

                                let isOnce = match (task.once) { case Some(v) => v; case None => false }
                                if (isOnce && hasSuccessfulLog(task.id)) { continue }

                                if (!validateCronExpression(task.cron)) {
                                    LogUtils.error("SchedulerEngine", "CRON表达式不合法, 跳过: ${task.name}, cron=${task.cron}")
                                    continue
                                }

                                let taskName = "crontab:${task.id}"
                                let isConcurrentable = match (task.concurrentable) { case Some(v) => v; case None => false }

                                let self = this
                                let taskId = task.id
                                ticktockInstance.addOrReplaceTask(
                                    taskName: taskName,
                                    taskCron: task.cron,
                                    execOnce: isOnce,
                                    concurrenctly: isConcurrentable,
                                    executor: { =>
                                        self.executeTask(taskId)
                                    }
                                )
                                activeCount++
                            }

                            totalTaskCount = totalCount
                            activeTaskCount = activeCount
                            LogUtils.info("SchedulerEngine", "加载任务完成: 总计${totalCount}, 启用${activeCount}")
                        case None =>
                            LogUtils.error("SchedulerEngine", "Ticktock初始化失败")
                    }
                } catch (e: Exception) {
                    LogUtils.error("SchedulerEngine", "加载任务失败: ${e.message}")
                }
            case None =>
                LogUtils.error("SchedulerEngine", "CrontabDAO未初始化")
        }
    }

    public func reloadTask(crontabId: String): Unit {
        match (crontabDAO) {
            case Some(dao) =>
                match (ticktock) {
                    case Some(tk) =>
                        match (dao.findCrontabById(crontabId)) {
                            case Some(task) =>
                                if (task.status == 1 && task.deletedAt == None) {
                                    if (validateCronExpression(task.cron)) {
                                        let taskName = "crontab:${task.id}"
                                        let isConcurrentable = match (task.concurrentable) { case Some(v) => v; case None => false }
                                        let isOnce = match (task.once) { case Some(v) => v; case None => false }
                                        let self = this
                                        let taskId = task.id
                                        tk.addOrReplaceTask(
                                            taskName: taskName,
                                            taskCron: task.cron,
                                            execOnce: isOnce,
                                            concurrenctly: isConcurrentable,
                                            executor: { =>
                                                self.executeTask(taskId)
                                            }
                                        )
                                        LogUtils.info("SchedulerEngine", "重新加载任务: ${task.name}")
                                    }
                                }
                            case None =>
                                LogUtils.error("SchedulerEngine", "任务不存在: ${crontabId}")
                        }
                    case None =>
                        LogUtils.error("SchedulerEngine", "Ticktock未初始化")
                }
            case None =>
                LogUtils.error("SchedulerEngine", "CrontabDAO未初始化")
        }
    }

    public func removeTask(crontabId: String): Unit {
        match (ticktock) {
            case Some(tk) =>
                tk.removeTask("crontab:${crontabId}")
                LogUtils.info("SchedulerEngine", "移除任务: ${crontabId}")
            case None =>
                LogUtils.error("SchedulerEngine", "Ticktock未初始化")
        }
    }

    public func executeTask(crontabId: String): Unit {
        if (shuttingDown.load()) { return }

        triggerTask(crontabId, TriggerType.Cron)
    }

    public func triggerTask(crontabId: String, triggerType: TriggerType): Unit {
        if (shuttingDown.load()) {
            LogUtils.error("SchedulerEngine", "调度引擎关闭中, 拒绝触发: ${crontabId}")
            return
        }

        match (crontabDAO) {
            case Some(dao) =>
                match (dao.findCrontabById(crontabId)) {
                    case Some(crontab) =>
                        let isConcurrentable = match (crontab.concurrentable) { case Some(v) => v; case None => false }
                        if (!isConcurrentable && runningTasks.contains(crontabId)) {
                            LogUtils.info("SchedulerEngine", "任务正在执行, 跳过: ${crontab.name}")
                            writeLogEntry(crontab, 0, "", false, TriggerType.SkippedConcurrent, 0, "", "")
                            return
                        }

                        runningTasks.put(crontabId, DateTime.now())

                        let startTime = DateTime.now()
                        let executorOpt = executorRegistry.getExecutor(crontab.task)

                        match (executorOpt) {
                            case Some(executor) =>
                                if (!executor.validate(crontab.task)) {
                                    LogUtils.error("SchedulerEngine", "任务URI验证失败: ${crontab.task}")
                                    writeLogEntry(crontab, 0, "任务URI验证失败", false, triggerType, 0, "", "")
                                    runningTasks.remove(crontabId)
                                    return
                                }

                                let timeout: Int32 = match (crontab.timeout) { case Some(v) => v; case None => 0 }
                                let maxRetries: Int32 = match (crontab.maxRetries) { case Some(v) => v; case None => 0 }
                                let retryCount: Int32 = match (crontab.retryCount) { case Some(v) => v; case None => 0 }
                                let parameters = match (crontab.parameters) { case Some(v) => v; case None => "{}" }

                                let context = CrontabExecutionContext(
                                    crontabId: crontab.id,
                                    taskName: crontab.name,
                                    taskUri: crontab.task,
                                    parameters: parameters,
                                    timeout: timeout,
                                    triggerType: triggerType,
                                    retryAttempt: retryCount,
                                    maxRetries: maxRetries
                                )

                                let scheme = ExecutorRegistry.parseScheme(crontab.task)
                                let result = retryManager.executeWithRetry(crontab, executor, context)

                                let endTime = DateTime.now()
                                let durationMs = durationMsBetween(startTime, endTime)

                                writeLogEntry(crontab, Int32(durationMs), result.errorOutput, result.success, triggerType, context.retryAttempt, scheme, result.resultSummary)

                                updateExecutionMeta(crontab, endTime, result.success, dao)

                                if (result.success) {
                                    let isOnce = match (crontab.once) { case Some(v) => v; case None => false }
                                    if (isOnce) {
                                        removeTask(crontabId)
                                        LogUtils.info("SchedulerEngine", "一次性任务完成: ${crontab.name}")
                                    }
                                }

                            case None =>
                                LogUtils.error("SchedulerEngine", "未找到执行器: ${crontab.task}")
                                writeLogEntry(crontab, 0, "未找到执行器", false, triggerType, 0, "", "")
                        }

                        runningTasks.remove(crontabId)

                    case None =>
                        LogUtils.error("SchedulerEngine", "任务不存在: ${crontabId}")
                }
            case None =>
                LogUtils.error("SchedulerEngine", "CrontabDAO未初始化")
        }
    }

    private func writeLogEntry(crontab: CrontabPO, usedTime: Int32, errorMessage: String, success: Bool, triggerType: TriggerType, retryAttempt: Int32, executorType: String, resultSummary: String): Unit {
        match (asyncLogWriter) {
            case Some(writer) =>
                let log = CrontabLogPO()
                log.crontabId = crontab.id
                log.usedTime = usedTime
                log.errorMessage = truncateOutput(errorMessage, maxLength: 2000)
                log.status = if (success) { 1 } else { 0 }
                log.startTime = Some(DateTime.now())
                log.triggerType = Some(triggerTypeToString(triggerType))
                log.retryAttempt = Some(retryAttempt)
                log.executorType = Some(executorType)
                log.resultSummary = Some(truncateOutput(resultSummary, maxLength: 500))
                writer.writeLog(log)
            case None =>
                LogUtils.error("SchedulerEngine", "AsyncLogWriter未初始化")
        }
    }

    private func updateExecutionMeta(crontab: CrontabPO, endTime: DateTime, success: Bool, dao: CrontabDAO): Unit {
        try {
            crontab.lastExecutedAt = Some(endTime)
            let currentCount: Int32 = match (crontab.execCount) { case Some(v) => v; case None => 0 }
            crontab.execCount = Some(currentCount + 1)

            if (success) {
                crontab.retryCount = Some(0)
            } else {
                let currentRetry: Int32 = match (crontab.retryCount) { case Some(v) => v; case None => 0 }
                crontab.retryCount = Some(currentRetry + 1)
            }

            dao.updateCrontab(crontab)
        } catch (e: Exception) {
            LogUtils.error("SchedulerEngine", "更新执行元数据失败: ${e.message}")
        }
    }

    private func hasSuccessfulLog(crontabId: String): Bool {
        false
    }

    public func validateCronExpression(cron: String): Bool {
        if (cron.size > 100) { return false }
        try {
            let compiler = CronCompiler()
            CronCompiler.compile(cron)
            return true
        } catch (e: Exception) {
            return false
        }
    }

    public func getRunningTasks(): ArrayList<String> {
        let result = ArrayList<String>()
        for ((k, _) in runningTasks) {
            result.add(k)
        }
        result
    }

    public func getStatus(): SchedulerStatus {
        let isRunning = !shuttingDown.load() && (match (ticktock) { case Some(_) => true; case None => false })
        SchedulerStatus(
            isRunning: isRunning,
            totalTasks: totalTaskCount,
            activeTasks: activeTaskCount,
            runningTasks: Int32(runningTasks.size),
            lastTickTime: DateTime.now()
        )
    }

    public func gracefulShutdown(timeout!: Duration = Duration.second * 30): Unit {
        if (shuttingDown.load()) { return }
        shuttingDown.store(true)
        LogUtils.info("SchedulerEngine", "开始优雅关闭...")

        match (ticktock) {
            case Some(tk) =>
                try { tk.shutdown() } catch (_: Exception) {}
            case None =>
                LogUtils.error("SchedulerEngine", "Ticktock未初始化")
        }

        let shutdownStart = DateTime.now()
        var waitMs = Int64(0)
        while (runningTasks.size > 0 && waitMs < timeout.toMilliseconds()) {
            try {
                sleep(Duration.millisecond * 500)
            } catch (_: Exception) {}
            waitMs += 500
        }

        if (runningTasks.size > 0) {
            LogUtils.error("SchedulerEngine", "关闭超时, 强制终止${runningTasks.size}个运行中任务")
        }

        match (asyncLogWriter) {
            case Some(writer) => writer.close()
            case None => LogUtils.error("SchedulerEngine", "AsyncLogWriter未初始化")
        }

        LogUtils.info("SchedulerEngine", "调度引擎已关闭")
    }

    public func sanitizeParameters(params: String): String {
        var result = params
        let sensitiveKeys = ArrayList<String>()
        sensitiveKeys.add("password")
        sensitiveKeys.add("token")
        sensitiveKeys.add("secret")
        sensitiveKeys.add("key")
        sensitiveKeys.add("apikey")
        sensitiveKeys.add("api_key")

        for (key in sensitiveKeys) {
            let patterns = ArrayList<String>()
            patterns.add("\"${key}\":\"")
            patterns.add("\"${key}\": \"")
            for (p in patterns) {
                if (result.contains(p)) {
                    let lower = result.toAsciiLower()
                    if (let Some(idx) <- lower.indexOf(p.toAsciiLower())) {
                        if (idx >= 0) {
                            result = result[0..idx + p.size] + "***\""
                            if (let Some(endIdx) <- result.indexOf("\"", idx + p.size + 4)) {
                                if (endIdx > idx + p.size + 3) {
                                    result = result[0..idx + p.size] + "***\"" + result[endIdx + 1..]
                                }
                            }
                        }
                    }
                }
            }
        }
        result
    }

    private func truncateOutput(output: String, maxLength!: Int64 = 2000): String {
        if (output.size > maxLength) { output[0..maxLength] } else { output }
    }
}
