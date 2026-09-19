/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */

/**
 * LrtPluginExecutor（long-running-task / §4 数据驱动桥 / 双驱动收口）
 *
 * ## 为什么需要这个执行器
 *
 * 长程任务的 crontab 原来写 `task = "agent_execution://<agentId>"`，由
 * `AgentExecutionExecutor` 消费。但该执行器在收敛退出时**无条件**执行
 * `updateTaskStatus(..., Some(2))`（见 `AgentExecutionExecutor.cj:126`），
 * 于是宿主 CRON 链路把任务置为「已完成」——而 spec 5.6.1 规则 7 要求
 * 「未经用户确认不得置为已完成」，插件侧 `LrtExecutor` 的两段式
 * （只置 `awaiting_review=true` + 推 `review_required`）**被旁路**。
 *
 * 收口方案（用户定夺，2026-09-15，方案 1）：**long-running 类 crontab 改派
 * L3 插件路由，不再走 `agent_execution://`**。本执行器即 scheme = `lrt` 的出口。
 *
 * ## 职责边界
 *
 * - **只做触发**：把 crontab 的一次 tick 转成一次插件 RPC 调用
 *   （`LrtPluginClient.execute` → 插件 `lrt-execute` → `LrtExecutor.runTask`）。
 * - **不碰任务状态**：`agent_tasks.status` 的迁移完全由插件按两段式负责。
 *   宿主在这里**刻意不写 status**，这正是本执行器存在的意义。
 * - **不阻塞调度线程**：`runTask` 是一次完整收敛循环（可能远超 RPC 超时
 *   `LRT_INVOKE_TIMEOUT=60s`），故用 `spawn` 派发后立即返回「已触发」，
 *   真实结果由插件经事件（`lrt_event`）与 `crontab_log` 对外可见。
 *   —— 与 `LongTaskApiService.submitTask` 的「立即触发首回合」同一策略。
 *
 * ## 重叠触发的防护（两层，缺一不可）
 *
 * 1. **调度层**：本类对应的 crontab 记录写 `concurrentable = false`，
 *    `SchedulerEngine.triggerTask` 会用内存态 `runningTasks` 跳过重叠 tick
 *    （`SchedulerEngine.cj:226`）。进程重启该内存态自然清空，不存在陈旧锁。
 * 2. **插件层**：`LrtExecutor` 用 `payload.executing` 咨询锁 + 陈旧锁自愈
 *    （超过 `maxTaskDurationMs` 视为上轮崩溃遗留并接管）。
 *
 * 故本类被重复调用是**安全**的：插件侧幂等（检查点续跑 + 终态短路）。
 *
 * ## parameters 契约
 *
 * crontab.parameters 为 JSON 字符串（宿主 `CrontabPO.parameters` 同构）：
 * `{"taskId":"<uuid>","userId":"<uuid>"}`
 * —— `taskId` 供插件定位 `agent_tasks`；`userId` 供插件行级权限使用。
 * 缺 `taskId` 时本类直接返回失败（无法定位任务，继续调用没有意义）。
 */

package magic.app.services.crontab.executor

import std.collection.ArrayList
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonKind}
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.app.services.lrt.LrtPluginClient
import f_base.Result

public class LrtPluginExecutor <: CrontabExecutor {
    /**
     * URI scheme。与 `ExecutorRegistry.parseScheme` 的 `lrt://` 分支、
     * `LongTaskApiService.submitTask` / `LrtTriggerBridge.ensureTrigger`
     * 写入的 task URI **必须一致**，改一处要同步三处。
     */
    public prop scheme: String {
        get() { "lrt" }
    }

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        // 路径段保留 agentId（与 crontab 的 task URI 约定一致，便于既有查询按 agentId 反查）；
        // 真正驱动插件用的是 parameters 里的 taskId。
        let agentId = ExecutorRegistry.parsePath(context.taskUri)
        let (taskId, userId) = LrtPluginExecutor.parseParameters(context.parameters)

        if (taskId.isEmpty()) {
            let msg = "lrt 触发缺少 taskId: uri=${context.taskUri}, parameters=${context.parameters}"
            LogUtils.error("LrtPluginExecutor", msg)
            return ExecutionResult.failureResult(msg, LrtPluginExecutor.calcDuration(startTime), -1)
        }

        LogUtils.info(
            "LrtPluginExecutor",
            "触发长程任务插件执行: taskId=${taskId}, agentId=${agentId}, crontabId=${context.crontabId}"
        )

        // 异步派发：runTask 是一整轮收敛循环，不能让它把调度线程占住（详见类注释）。
        let dispatchedTaskId = taskId
        let dispatchedUserId = userId
        spawn { =>
            try {
                match (LrtPluginClient.execute(dispatchedTaskId, dispatchedUserId, ArrayList<String>())) {
                    case Ok(v) =>
                        LogUtils.info(
                            "LrtPluginExecutor",
                            "插件执行返回: taskId=${dispatchedTaskId}, result=${LrtPluginExecutor.head(v.stringify())}"
                        )
                    case Err(e) =>
                        LogUtils.warn(
                            "LrtPluginExecutor",
                            "插件执行失败: taskId=${dispatchedTaskId}, reason=${e}"
                        )
                    case _ =>
                        LogUtils.warn("LrtPluginExecutor", "插件执行无结果: taskId=${dispatchedTaskId}")
                }
            } catch (e: Exception) {
                LogUtils.error(
                    "LrtPluginExecutor",
                    "插件执行异常: taskId=${dispatchedTaskId}, error=${e.message}"
                )
            }
        }

        let summary = "已触发插件执行 taskId=${taskId}"
        ExecutionResult.successResult(summary, LrtPluginExecutor.calcDuration(startTime), summary)
    }

    public func validate(taskUri: String): Bool {
        // 与 AgentExecutionExecutor.validate 同口径：路径段（agentId）非空即可。
        // taskId 的校验在 execute 内做（validate 只拿得到 URI，拿不到 parameters）。
        let path = ExecutorRegistry.parsePath(taskUri)
        path.size > 0 && path.size <= 36
    }

    /// 解析 parameters（JSON 字符串）里的 taskId / userId。
    /// 解析失败一律回落空串，由调用方判空并给出明确错误——不抛异常。
    private static func parseParameters(parameters: String): (String, String) {
        var taskId = ""
        var userId = ""
        if (parameters.isEmpty()) {
            return (taskId, userId)
        }
        try {
            let parsed = JsonValue.fromStr(parameters)
            if (parsed is JsonObject) {
                let obj = parsed.asObject()
                taskId = LrtPluginExecutor.stringField(obj, "taskId")
                userId = LrtPluginExecutor.stringField(obj, "userId")
            }
        } catch (_: Exception) {
            // 保持空串：parameters 是宿主自己写的，解析失败说明数据被人工改坏，
            // 此时"当作没有 taskId"比抛异常更符合调度器对执行器的期待（返回失败而非崩溃）。
        }
        (taskId, userId)
    }

    /// 取 JSON 对象里的字符串字段（非字符串/缺失一律空串）
    private static func stringField(obj: JsonObject, key: String): String {
        let v = obj.get(key)
        if (v.isNone()) {
            return ""
        }
        let jv = v.getOrThrow()
        match (jv.kind()) {
            case JsonKind.JsString => jv.asString().getValue()
            case _ => ""
        }
    }

    /// 结果摘要截断（避免把整段 JSON 灌进 crontab_log.result_summary）
    private static func head(s: String): String {
        if (s.size <= 200) {
            return s
        }
        s[0..200]
    }

    private static func calcDuration(startTime: DateTime): Int64 {
        try {
            (DateTime.now() - startTime).toMilliseconds()
        } catch (_: Exception) {
            0
        }
    }
}
