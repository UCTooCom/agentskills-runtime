/*
 * LrtMonitorService（long-running-task / §11.3）
 * 关键指标监控：维护近 N 次任务完成的滑动窗口，计算四类比率/延迟指标，
 * 任一指标超阈值即经 LrtAlertService 告警。
 *
 * 监控的四类指标（spec §11.3 1003）：
 *   1. task_failure_rate         —— 窗口内 outcome != "completed" 的占比
 *   2. round_timeout_rate       —— 窗口内 outcome == "round_timeout" 的占比
 *   3. checkpoint_latency       —— 窗口内检查点保存平均延迟（ms，实测）
 *   4. progress_latency         —— 窗口内单轮平均耗时（ms，作为进度通知延迟代理指标）
 *
 * 设计要点：
 * - 滑动窗口为进程内 best-effort 统计：进程重启即清零，不做持久化。
 *   监控是观测面，丢几个样本不影响任务。
 * - 阈值统一来自 LrtConfig（plugin.yaml config / LRT_MONITOR_* 环境变量），
 *   单一事实来源，不在此硬编码。
 * - 冷却（cooldown）：同一指标 5 分钟内只告警一次，避免窗口滑动时连续刷屏。
 * - 样本数 < 2 时不告警：比率在小样本下无意义。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.time.DateTime

/// 一次任务完成的采样点（进程内滑动窗口元素）
public class LrtMonitorSample {
    public let outcome: String
    public let checkpointLatencyMs: Int64
    public let progressLatencyMs: Int64

    public init(outcome: String, checkpointLatencyMs: Int64, progressLatencyMs: Int64) {
        this.outcome = outcome
        this.checkpointLatencyMs = checkpointLatencyMs
        this.progressLatencyMs = progressLatencyMs
    }
}

public class LrtMonitorService {
    private static var samples: ArrayList<LrtMonitorSample> = ArrayList<LrtMonitorSample>()
    private static var lastAlertAt: HashMap<String, Int64> = HashMap<String, Int64>()
    /// 同一指标的最小告警间隔（毫秒）：5 分钟
    private static let COOLDOWN_MS: Int64 = 300000

    /**
     * 记录一次任务终态，更新滑动窗口并做阈值判定。
     * outcome 由调用方归并为三类之一：completed / round_timeout / failed（其余非完成态）。
     */
    public static func recordTaskOutcome(
        taskId: String, sessionId: String, agentId: String, traceId: String,
        outcome: String, checkpointLatencyMs: Int64, progressLatencyMs: Int64,
        userId: String, permArr: ArrayList<JsonValue>
    ): Unit {
        if (!LrtConfig.monitorEnabled()) {
            return
        }
        LrtMonitorService.samples.add(LrtMonitorSample(outcome, checkpointLatencyMs, progressLatencyMs))
        let cap = LrtConfig.monitorWindowSize()
        while (cap > 0 && LrtMonitorService.samples.size > cap) {
            // ArrayList 无 removeAt；remove 的下标是命名参数 at:（std.collection.class.arraylist.remove）
            LrtMonitorService.samples.remove(at: 0)
        }

        let total = LrtMonitorService.samples.size
        if (total < 2) {
            // 样本不足，比率无统计意义
            return
        }

        var failed = 0
        var roundTimeout = 0
        var cpSum = 0
        var progSum = 0
        for (x in LrtMonitorService.samples) {
            if (x.outcome != "completed") {
                failed++
            }
            if (x.outcome == "round_timeout") {
                roundTimeout++
            }
            cpSum += x.checkpointLatencyMs
            progSum += x.progressLatencyMs
        }
        let failureRate = Float64(failed) / Float64(total)
        let roundTimeoutRate = Float64(roundTimeout) / Float64(total)
        let avgCp = Float64(cpSum) / Float64(total)
        let avgProg = Float64(progSum) / Float64(total)

        LrtMonitorService.evaluate(
            "task_failure_rate", failureRate, LrtConfig.monitorFailureRate(),
            taskId, sessionId, agentId, traceId, total,
            "窗口内 ${failed}/${total} 个任务未成功完成", userId, permArr
        )
        LrtMonitorService.evaluate(
            "round_timeout_rate", roundTimeoutRate, LrtConfig.monitorRoundTimeoutRate(),
            taskId, sessionId, agentId, traceId, total,
            "窗口内 ${roundTimeout}/${total} 个任务因回合超时中止", userId, permArr
        )
        LrtMonitorService.evaluate(
            "checkpoint_latency", avgCp, Float64(LrtConfig.monitorCheckpointLatencyMs()),
            taskId, sessionId, agentId, traceId, total,
            "平均检查点保存延迟 ${Int64(avgCp)}ms 超出阈值", userId, permArr
        )
        LrtMonitorService.evaluate(
            "progress_latency", avgProg, Float64(LrtConfig.monitorProgressLatencyMs()),
            taskId, sessionId, agentId, traceId, total,
            "平均单轮进度延迟（单轮耗时代理）${Int64(avgProg)}ms 超出阈值", userId, permArr
        )
    }

    private static func evaluate(
        metric: String, value: Float64, threshold: Float64,
        taskId: String, sessionId: String, agentId: String, traceId: String,
        window: Int64, message: String,
        userId: String, permArr: ArrayList<JsonValue>
    ): Unit {
        if (value <= threshold) {
            return
        }
        if (LrtMonitorService.inCooldown(metric)) {
            return
        }
        // HashMap 无 put：写入用 add(key, value)（std.collection.class.hashmap.add）
        LrtMonitorService.lastAlertAt.add(metric, LrtMonitorService.nowMs())
        LrtAlertService.fire(
            taskId, sessionId, agentId, traceId, metric, value, threshold,
            "warning", message, window, userId, permArr
        )
    }

    private static func inCooldown(metric: String): Bool {
        match (LrtMonitorService.lastAlertAt.get(metric)) {
            case Some(last) => return (LrtMonitorService.nowMs() - last) < LrtMonitorService.COOLDOWN_MS
            case None => return false
        }
    }

    private static func nowMs(): Int64 {
        (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }
}
