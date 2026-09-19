/*
 * LrtTraceLog（long-running-task / Ch4.2 / §11.3）
 * 把执行器每轮 / 每步的结构化轨迹写入 crontab_log，使 /trace 接口能把
 * 「宿主调度日志 + 插件内每轮执行轨迹」归并为一条时间线（tasks.md §4.2 / 11.3）。
 *
 * 设计要点：
 * - crontab_log 原生列没有 trace_id / task_id / round / step，故把结构化信息塞进
 *   result_summary（TEXT，JSON）；其余列按语义落：crontab_id=调度归属、used_time=耗时(ms)、
 *   status=1/0、executor_type='lrt'、trigger_type='manual'、start_time/end_time=当前时刻。
 * - 写入为**尽力而为**（best-effort）：任何异常只 eprintln 吞掉，绝不中断收敛循环。
 *   轨迹日志是可观测性增强，不能因为它的失败让长程任务本身失败。
 * - crontab_id 经 resolveCrontabId 从 crontab 表按 task='lrt://<agentId>'
 *   解析；解析不到时回落到 taskId（agent_tasks.id 即 uuid），确保 NOT NULL 约束可满足。
 *   （2026-09-15 起 scheme 由 agent_execution:// 改为 lrt://，见 LrtTriggerBridge）
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.time.DateTime

public class LrtTraceLog {
    /// 轨迹落库表
    public static let TABLE_CRONTAB_LOG: String = "crontab_log"

    /// 解析本 agent 的 crontab_id（调度归属）。解析不到返回空串，由调用方回落 taskId。
    public static func resolveCrontabId(
        agentId: String, userId: String, permArr: ArrayList<JsonValue>
    ): String {
        if (agentId.isEmpty()) {
            return ""
        }
        let row = LrtPersistService.queryOne(
            "crontab", "task = 'lrt://${agentId}'", userId, permArr
        )
        match (row) {
            case JsonValue.Map(f) =>
                match (f.get("id")) {
                    case Some(JsonValue.String(s)) => return s
                    case _ => ()
                }
            case _ => ()
        }
        return ""
    }

    /// 通用写入：把一条结构化轨迹落 crontab_log。best-effort。
    /// status: 1=成功 0=失败。step 为步骤名（如 "round:3" / "task:completed"）。
    public static func emit(
        taskId: String, crontabId: String, traceId: String,
        round: Int64, step: String, status: Int64,
        durationMs: Int64, summary: String,
        userId: String, permArr: ArrayList<JsonValue>
    ): Unit {
        var cid = crontabId
        if (cid.isEmpty()) {
            cid = taskId
        }
        let nowStr = "${DateTime.now().format("yyyy-MM-dd HH:mm:ss")}"
        let dataMap = HashMap<String, JsonValue>()
        dataMap["crontab_id"] = JsonValue.String(cid)
        dataMap["used_time"] = JsonValue.Number(Float64(durationMs))
        dataMap["error_message"] = JsonValue.String("")
        dataMap["status"] = JsonValue.Number(if (status == 0) { 0.0 } else { 1.0 })
        dataMap["start_time"] = JsonValue.String(nowStr)
        dataMap["end_time"] = JsonValue.String(nowStr)
        dataMap["trigger_type"] = JsonValue.String("manual")
        dataMap["executor_type"] = JsonValue.String("lrt")
        // 结构化信息：trace_id / task_id / round / step / status / duration_ms / message 全部进 result_summary
        let sMap = HashMap<String, JsonValue>()
        sMap["trace_id"] = JsonValue.String(traceId)
        sMap["task_id"] = JsonValue.String(taskId)
        sMap["round"] = JsonValue.Number(Float64(round))
        sMap["step"] = JsonValue.String(step)
        sMap["status"] = JsonValue.Number(Float64(status))
        sMap["duration_ms"] = JsonValue.Number(Float64(durationMs))
        sMap["message"] = JsonValue.String(summary)
        dataMap["result_summary"] = JsonValue.from(sMap)
        try {
            LrtPersistService.insert(LrtTraceLog.TABLE_CRONTAB_LOG, dataMap, userId, permArr)
        } catch (e: Exception) {
            eprintln("[lrt-trace] crontab_log 写入失败（非致命，忽略）: ${e}")
        }
    }

    /// 每轮轨迹（round 粒度）
    public static func emitRound(
        taskId: String, crontabId: String, traceId: String,
        round: Int64, status: Int64, durationMs: Int64, summary: String,
        userId: String, permArr: ArrayList<JsonValue>
    ): Unit {
        LrtTraceLog.emit(
            taskId, crontabId, traceId, round, "round:${round}", status, durationMs, summary, userId, permArr
        )
    }

    /// 任务级轨迹（step 粒度，如 task:start / task:completed / task:need_human）
    public static func emitStep(
        taskId: String, crontabId: String, traceId: String,
        round: Int64, step: String, status: Int64, durationMs: Int64, summary: String,
        userId: String, permArr: ArrayList<JsonValue>
    ): Unit {
        LrtTraceLog.emit(
            taskId, crontabId, traceId, round, step, status, durationMs, summary, userId, permArr
        )
    }

    /// 监控告警结构化日志（§11.3）。与轨迹同表（crontab_log，step=monitor_alert），
    /// /trace 归并时间线时能与 task:*/round:* 连贯呈现。
    public static func emitAlert(
        taskId: String, agentId: String, traceId: String,
        metric: String, value: Float64, threshold: Float64,
        level: String, message: String, window: Int64,
        userId: String, permArr: ArrayList<JsonValue>
    ): Unit {
        let dataMap = HashMap<String, JsonValue>()
        let cid = if (taskId.isEmpty()) { agentId } else { taskId }
        dataMap["crontab_id"] = JsonValue.String(if (cid.isEmpty()) { "monitor" } else { cid })
        dataMap["used_time"] = JsonValue.Number(0.0)
        dataMap["error_message"] = JsonValue.String("")
        dataMap["status"] = JsonValue.Number(1.0)
        let nowStr = "${DateTime.now().format("yyyy-MM-dd HH:mm:ss")}"
        dataMap["start_time"] = JsonValue.String(nowStr)
        dataMap["end_time"] = JsonValue.String(nowStr)
        dataMap["trigger_type"] = JsonValue.String("monitor")
        dataMap["executor_type"] = JsonValue.String("lrt")
        let sMap = HashMap<String, JsonValue>()
        sMap["trace_id"] = JsonValue.String(traceId)
        sMap["task_id"] = JsonValue.String(taskId)
        sMap["step"] = JsonValue.String("monitor_alert")
        sMap["metric"] = JsonValue.String(metric)
        sMap["value"] = JsonValue.Number(value)
        sMap["threshold"] = JsonValue.Number(threshold)
        sMap["level"] = JsonValue.String(level)
        sMap["window"] = JsonValue.Number(Float64(window))
        sMap["message"] = JsonValue.String(message)
        dataMap["result_summary"] = JsonValue.from(sMap)
        try {
            LrtPersistService.insert(LrtTraceLog.TABLE_CRONTAB_LOG, dataMap, userId, permArr)
        } catch (e: Exception) {
            eprintln("[lrt-trace] monitor_alert 写入失败（非致命，忽略）: ${e}")
        }
    }
}
