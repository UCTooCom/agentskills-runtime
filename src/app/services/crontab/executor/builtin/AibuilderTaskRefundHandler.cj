/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab.executor.builtin

import std.collection.ArrayList
import std.time.DateTime
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult, durationMsBetween}
import magic.app.services.uctoo.{TasksService, PointTransactionsService, MessagesService}
import magic.app.models.uctoo.{TasksPO, MessagesPO}

/**
 * AibuilderTaskRefundHandler - AI Builder 超期任务积分退还处理器
 *
 * 业务场景：
 *   AI Builder 任务发布时会冻结公司积分，任务存在 accept_deadline（承接截止时间）。
 *   如果任务在 accept_deadline 之前未被承接，需要自动退还冻结的积分给公司，
 *   并将任务状态更新为 expired，结算状态更新为 refunded。
 *
 * 执行逻辑：
 *   1. 查询 accept_deadline < NOW() 且 task_status='open' 且 points_frozen > 0 的任务（每次最多100条）
 *   2. 对每个任务执行：
 *      - 调用 PointTransactionsService.refundExpiredTaskPoints 退还积分
 *      - 调用 TasksService.markTaskExpired 更新任务状态为 expired、结算状态为 refunded
 *      - 调用 MessagesService.create 发送消息通知任务创建者
 *   3. 单任务异常通过 try-catch 隔离，不影响其他任务处理
 *
 * 注册方式：
 *   在 SchedulerEngine.initExecutors() 中通过
 *   builtinExecutor.registerBuiltinTask("aibuilder-task-refund", AibuilderTaskRefundHandler()) 注册
 *
 * crontab 任务 URI 格式：
 *   builtin://aibuilder-task-refund
 *
 * 建议 cron 表达式：
 *   0 0 * * * *（每小时整点执行）
 */

/**
 * 单任务处理结果
 */
struct TaskProcessResult {
    TaskProcessResult(let success: Bool, let refundedPoints: Int64, let errorMessage: String) {}
}

public class AibuilderTaskRefundHandler <: BuiltinTaskHandler {

    /// 系统操作者ID（用于积分流水记录的 operatorId 字段）
    private static let SYSTEM_OPERATOR_ID = "system"

    /// 单次处理的最大任务数量（避免长时间阻塞调度线程）
    private static let BATCH_LIMIT: Int64 = 100

    public func handle(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        LogUtils.info("AibuilderTaskRefundHandler", "开始扫描超期未承接任务...")

        var successCount: Int64 = 0
        var failureCount: Int64 = 0
        var totalRefundedPoints: Int64 = 0

        try {
            // 1. 查询超期任务
            let tasksService = TasksService()
            let expiredTasks = tasksService.findExpiredOpenTasks(BATCH_LIMIT)

            if (expiredTasks.size == 0) {
                let duration = durationMsBetween(startTime, DateTime.now())
                LogUtils.info("AibuilderTaskRefundHandler", "未发现超期任务")
                return ExecutionResult.successResult("未发现超期任务", duration, "no_expired_tasks")
            }

            LogUtils.info("AibuilderTaskRefundHandler", "发现${expiredTasks.size}个超期任务，开始处理")

            // 2. 逐个处理（异常隔离）
            for (task in expiredTasks) {
                let result = processSingleTask(task)
                if (result.success) {
                    successCount++
                    totalRefundedPoints = totalRefundedPoints + result.refundedPoints
                } else {
                    failureCount++
                    LogUtils.error("AibuilderTaskRefundHandler",
                        "处理任务失败: taskId=${task.id}, error=${result.errorMessage}")
                }
            }

            // 3. 构建执行结果摘要
            let duration = durationMsBetween(startTime, DateTime.now())
            let summary = "处理完成: 成功${successCount}个, 失败${failureCount}个, 退还积分${totalRefundedPoints}"
            LogUtils.info("AibuilderTaskRefundHandler", summary)

            return ExecutionResult.successResult(summary, duration, "refund_ok")
        } catch (e: Exception) {
            let duration = durationMsBetween(startTime, DateTime.now())
            LogUtils.error("AibuilderTaskRefundHandler", "执行异常: ${e.message}")
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }

    /**
     * 处理单个超期任务：退还积分→更新任务状态→发送通知
     * @param task 超期任务对象
     * @return 处理结果
     */
    private func processSingleTask(task: TasksPO): TaskProcessResult {
        try {
            // 校验必要字段：companyId 是 Option<String>，需要先解包
            let cid = match (task.companyId) {
                case Some(c) => c
                case None => ""
            }
            if (cid.isEmpty()) {
                return TaskProcessResult(false, 0, "任务缺少 companyId")
            }
            if (task.pointsFrozen <= 0) {
                return TaskProcessResult(false, 0, "任务 pointsFrozen<=0")
            }

            // 1. 退还积分给公司
            let pointService = PointTransactionsService()
            let refundedRows = pointService.refundExpiredTaskPoints(
                task.id, cid, task.pointsFrozen, SYSTEM_OPERATOR_ID)
            if (refundedRows <= 0) {
                return TaskProcessResult(false, 0, "退还积分失败，影响行数=0")
            }

            // 2. 更新任务状态：task_status='expired', settlement_status='refunded', points_refunded=pointsFrozen
            let tasksService = TasksService()
            tasksService.markTaskExpired(task.id, task.pointsFrozen)

            // 3. 发送消息通知任务创建者
            sendExpirationNotification(task)

            return TaskProcessResult(true, task.pointsFrozen, "")
        } catch (e: Exception) {
            return TaskProcessResult(false, 0, e.message)
        }
    }

    /**
     * 发送任务超期通知消息
     * 通知对象：任务创建者（task.creator）
     * 通知类型：task_expired
     */
    private func sendExpirationNotification(task: TasksPO): Unit {
        try {
            // creator 字段为 Option<String>，未设置则跳过通知
            match (task.creator) {
                case Some(creatorId) =>
                    if (creatorId.isEmpty()) {
                        return
                    }
                    let messagesService = MessagesService()
                    let msg = MessagesPO()
                    msg.userId = creatorId
                    msg.senderId = Some(SYSTEM_OPERATOR_ID)
                    msg.messageType = "task_expired"
                    msg.title = "任务超期通知"
                    msg.content = "您发布的任务「${task.title}」已超过承接截止时间，系统已自动退还冻结积分${task.pointsFrozen}至公司账户。"
                    msg.msgRelatedType = Some("tasks")
                    msg.relatedId = Some(task.id)
                    msg.isRead = false
                    messagesService.create(msg, SYSTEM_OPERATOR_ID)
                case None =>
                    // 无创建者信息，跳过通知
                    ()
            }
        } catch (e: Exception) {
            // 通知失败不影响主流程
            LogUtils.error("AibuilderTaskRefundHandler",
                "发送超期通知失败: taskId=${task.id}, error=${e.message}")
        }
    }
}
