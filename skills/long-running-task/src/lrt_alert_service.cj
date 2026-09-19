/*
 * LrtAlertService（long-running-task / §11.3）
 * 告警出口：把一次阈值突破收敛为「事件 + 结构化日志 + stderr」三路输出。
 *
 * 设计要点：
 * - 事件出口复用 LrtEventEmitter.emitMonitorAlert → host.event → SSE/WS（与 review_required 同源链路），
 *   前端可在事件流里消费 monitor_alert 渲染告警卡片。
 * - 结构化日志复用 LrtTraceLog.emitAlert，落 crontab_log（type=monitor_alert），
 *   与 task:xxx / round:xxx 轨迹同表，/trace 能归并进同一条时间线。
 *   （注意：块注释内不能出现注释结束符字面量，故此处不写通配形式，只引具体样例）
 * - 冷却（cooldown）在 LrtMonitorService 侧控制，本类只负责"发出去"，不重复判断。
 * - 全部 best-effort：任何一步失败只 eprintln，绝不因为告警系统自身故障
 *   影响正在跑的长程任务收敛循环（告警是观测面，不是控制面）。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}

public class LrtAlertService {

    /**
     * 发出一次告警。
     *
     * @param taskId    关联任务 ID（无关联时可为空串）
     * @param sessionId SSE 会话 ID（任务级告警传真实会话；系统级传空串 → 仅 WS 广播）
     * @param agentId   Agent 标识
     * @param traceId   追踪 ID（可为空）
     * @param metric    指标名（task_failure_rate / round_timeout_rate /
     *                  checkpoint_latency / progress_latency / log_disk_watermark）
     * @param value     实测值
     * @param threshold 阈值
     * @param level     告警级别（warning / critical）
     * @param message   人类可读说明
     * @param window    参与统计的样本窗口（比率类指标有意义；瞬时类填 0）
     */
    public static func fire(
        taskId: String, sessionId: String, agentId: String, traceId: String,
        metric: String, value: Float64, threshold: Float64,
        level: String, message: String, window: Int64,
        userId: String, permArr: ArrayList<JsonValue>
    ): Unit {
        // 1. 结构化告警日志（落 crontab_log，与轨迹同表）
        try {
            LrtTraceLog.emitAlert(taskId, agentId, traceId, metric, value, threshold, level, message, window, userId, permArr)
        } catch (e: Exception) {
            eprintln("[lrt-alert] 结构化日志写入失败（已忽略）: ${e}")
        }
        // 2. 事件出口（SSE/WS；失败由 emitter 内部吞掉）
        try {
            LrtEventEmitter.emitMonitorAlert(taskId, sessionId, agentId, traceId, metric, value, threshold, level, message, window)
        } catch (e: Exception) {
            eprintln("[lrt-alert] 事件上报失败（已忽略）: ${e}")
        }
        // 3. stderr 兜底（保证无 SSE 订阅时运维也能在控制台看到）
        eprintln("[lrt-alert][${level}] ${metric}: value=${value} threshold=${threshold} window=${window} :: ${message}")
    }
}
