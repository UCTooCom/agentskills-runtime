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
 * - crontab_id 经 resolveCrontabId 从 crontab 表定位：优先按 name='lrt-<taskId>'
 *   （宿主 submitTask 建）/ name='lrt-plugin-<taskId>'（插件自建）精确匹配，
 *   未命中才回落 task='lrt://<agentId>'。2026-09-22 修复前只按后者查询，
 *   同一 agent 的多个长程任务会串到同一个调度行上。
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
        agentId: String, userId: String, permArr: ArrayList<JsonValue>, taskId!: String = ""
    ): String {
        if (agentId.isEmpty()) {
            return ""
        }
        // [修复 2026-09-22] 优先按 taskId 精确定位，避免跨任务串台。
        // 原实现只查 task='lrt://<agentId>'：同一 agent 的所有长程任务共用该 URI，
        // 于是**首个**调度行会被后续所有任务复用。实测（2026-09-22 10:14）新任务
        // 6bb80c3a 复用了旧任务 a298ea47 的调度行 888071ce —— 其 parameters.taskId
        // 仍是旧任务，既让 crontab_log 挂到别人名下，也会让已收敛的旧任务被周期反复唤起。
        // 宿主 submitTask 建的行名为 `lrt-<taskId>`；插件自建的行名为 `lrt-plugin-<taskId>`。
        if (!taskId.isEmpty()) {
            let byHost = LrtTraceLog.crontabIdByWhere("name = 'lrt-${taskId}'", userId, permArr)
            if (!byHost.isEmpty()) {
                return byHost
            }
            let byPlugin = LrtTraceLog.crontabIdByWhere("name = 'lrt-plugin-${taskId}'", userId, permArr)
            if (!byPlugin.isEmpty()) {
                return byPlugin
            }
        }
        // 兜底沿用旧口径（按 agentId URI），保证历史行为不回退
        return LrtTraceLog.crontabIdByWhere("task = 'lrt://${agentId}'", userId, permArr)
    }

    /// 按 where 条件取 crontab.id；未命中返回空串。
    private static func crontabIdByWhere(
        whereClause: String, userId: String, permArr: ArrayList<JsonValue>
    ): String {
        let row = LrtPersistService.queryOne("crontab", whereClause, userId, permArr)
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

    // ── §11.3 四类关键决策的 JSONL 行日志（tasks.md 1000）──────────────────
    //
    // 为什么额外要 JSONL：plan / replan / degradation / decision 四类此前只落
    // 「payload 字段 / 表列」，那只能事后查库，无法被日志采集器按行抓取与流式
    // 归集。本组函数补的就是这条「可被按行抓取」的出口。
    //
    // 为什么走 stderr 而不是 stdout（硬约束，勿改）：本插件是 L3 进程轨，
    // stdout 被 stdio RPC 通道独占，往 stdout 打印任何内容都会破坏 JSON-RPC
    // 报文边界，导致宿主解析失败。stderr 由宿主捕获后并入宿主日志，采集器按
    // 前缀 `[lrt-jsonl] ` 过滤即可拿到干净的 JSONL 流。
    //
    // 输出格式：单行 JSON，字段固定 ts/type/trace_id/task_id/agent_id/round，
    // 其余由调用方以 fields 传入。best-effort：序列化异常只丢弃本行，不抛。

    /// 四类决策的枚举值（用字符串常量而非 enum，避免与既有 JsonValue 互转再添一层）
    public static let JSONL_TYPE_PLAN: String = "plan"
    public static let JSONL_TYPE_REPLAN: String = "replan"
    public static let JSONL_TYPE_DEGRADATION: String = "degradation"
    public static let JSONL_TYPE_DECISION: String = "decision"

    /// 输出一条决策类 JSONL 行到 stderr。开关关闭时直接返回（零开销）。
    /// fields 由调用方填业务字段（如子目标数、降级前后方案、决策选择项等）。
    ///
    /// 参数名用 `kind` 而非 type：type 是仓颉关键字，直接作形参名会报
    /// "expected a argument name after '(' in parameter list, found keyword 'type'"。
    /// 调用方一律按位置传参，故改名不影响任何调用点。
    public static func emitJsonl(
        kind: String, taskId: String, agentId: String, traceId: String,
        round: Int64, fields: HashMap<String, JsonValue>
    ): Unit {
        if (!LrtConfig.decisionJsonlEnabled()) {
            return
        }
        try {
            let m = HashMap<String, JsonValue>()
            m["ts"] = JsonValue.String(LrtTraceLog.nowText())
            m["type"] = JsonValue.String(kind)
            m["trace_id"] = JsonValue.String(traceId)
            m["task_id"] = JsonValue.String(taskId)
            m["agent_id"] = JsonValue.String(agentId)
            m["round"] = JsonValue.Number(Float64(round))
            // HashMap 无 putAll：逐条 add（见 std.collection.class.hashmap.add）
            for ((k, v) in fields) {
                m[k] = v
            }
            eprintln("[lrt-jsonl] ${JsonValue.from(m).stringify()}")
        } catch (e: Exception) {
            eprintln("[lrt-trace] jsonl 输出失败（已丢弃本行，不阻断）: ${e}")
        }
    }

    /// 无额外业务字段时的决策行（fields 为空 Map）。
    ///
    /// 刻意独立命名而不用同名重载：与 lrt_artifact_verifier.cj 的
    /// verifyWithRemediation / verifyThenDegrade 保持同一惯例——本工程内
    /// 多形态 API 一律显式命名，不依赖重载解析，避免形参隐式转换带来的歧义。
    public static func emitJsonlPlain(
        kind: String, taskId: String, agentId: String, traceId: String, round: Int64
    ): Unit {
        LrtTraceLog.emitJsonl(kind, taskId, agentId, traceId, round, HashMap<String, JsonValue>())
    }

    private static func nowText(): String {
        "${DateTime.now().format("yyyy-MM-dd HH:mm:ss")}"
    }
}
