/*
 * LrtTriggerBridge（long-running-task / Ch 新增 / §4 数据驱动桥）
 *
 * 数据驱动跨进程编排：插件经一致 DB API（host.db）在 `crontab` 表写入
 * `task = 'lrt://<agentId>'` 的记录，由宿主 SchedulerEngine 按 cron
 * 周期消费 → 触发宿主 `LrtPluginExecutor` → 回调本插件 `lrt-execute`
 * （JSON-RPC over stdio）反向驱动多步循环控制器。
 *
 * 这是 §4.1「直接对象级不可达，数据驱动等效可达」原则的实体化：
 * 不调用宿主进程内对象，只写一条宿主既有控制器会消费的协调数据，即等效于
 * "插件反向驱动宿主能力"。详见 tasks.md「跨进程协调心智模型」与 MEMORY.md 同名词条。
 *
 * 【scheme 变更（2026-09-15）】原写 `agent_execution://<agentId>`，由宿主
 * `AgentExecutionExecutor` 消费；但该执行器收敛退出时**无条件**置 status=2，
 * 旁路了插件两段式交付（spec 5.6.1 规则 7「未经用户确认不得交付」）。
 * 现改用 `lrt://`，宿主侧由 `LrtPluginExecutor` 承接且**不写 status**。
 *
 * 与宿主 submitTask 同构（long_task_api_service.cj submitTask）：
 *   - name = "lrt-plugin-<taskId>"
 *   - task = "lrt://<agentId>"
 *   - cron 默认每 5 分钟触发（见下方 DEFAULT_CRON 常量，勿在注释里写 cron 字面量：
 *     其步长记号含「斜杠星号」，会提前终止本块注释）
 *   - status = 1（关键：SchedulerEngine 仅 status==1 时注册进 ticktock）
 *   - concurrentable = false（禁止重叠触发）/ once = false / priority = 5
 *   - parameters = {"taskId": "<taskId>", "userId": "<userId>"}
 *     （宿主 LrtPluginExecutor 据此定位 agent_tasks 与做行级权限）
 *
 * 幂等：ensureTrigger 先按 task uri 解析既有记录，命中即复用（不重复插入）；
 * 未命中才插入。removeTrigger 按 task uri 物理删除。
 * 所有写入 best-effort：异常只 eprintln，绝不中断收敛循环（与 LrtTraceLog 同策略）。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}

public class LrtTriggerBridge {
    /// 触发记录所在表
    public static let TABLE_CRONTAB: String = "crontab"
    /// 宿主 SchedulerEngine 仅在 status==1 时把任务注册进 ticktock（见 long_task_api_service.cj:131 注释）
    public static let STATUS_ENABLED: Int64 = 1
    /// 默认 5 分钟轮询，与宿主 submitTask 默认 cron 一致
    public static let DEFAULT_CRON: String = "0 */5 * * * ?"

    /// 确保存在一条触发宿主 LrtPluginExecutor 的 crontab 记录；幂等。
    /// 返回 crontab id（新插入或既有的）；失败/空 agentId 返回 ""。
    public static func ensureTrigger(
        agentId: String, taskId: String, cron: String,
        userId: String, permArr: ArrayList<JsonValue>
    ): String {
        if (agentId.isEmpty()) {
            return ""
        }
        let taskUri = "lrt://${agentId}"
        // 1) 幂等：既有记录直接复用，避免每次 runTask 重复插入一条 crontab
        let existing = LrtTraceLog.resolveCrontabId(agentId, userId, permArr)
        if (!existing.isEmpty()) {
            return existing
        }
        // 2) 插入一条与宿主 submitTask 同构的 crontab 记录
        let effectiveCron = if (cron.isEmpty()) { DEFAULT_CRON } else { cron }
        let dataMap = HashMap<String, JsonValue>()
        dataMap["name"] = JsonValue.String("lrt-plugin-${taskId}")
        dataMap["group_name"] = JsonValue.String("1")
        dataMap["task"] = JsonValue.String(taskUri)
        dataMap["cron"] = JsonValue.String(effectiveCron)
        dataMap["tactics"] = JsonValue.String("")
        dataMap["remark"] = JsonValue.String("long-running-task 插件数据驱动触发（taskId=${taskId}）")
        // 关键：必须显式 status=1，否则 SchedulerEngine 永不注册该任务
        dataMap["status"] = JsonValue.Number(Float64(STATUS_ENABLED))
        // concurrentable=false：禁止重叠触发（调度层 runningTasks 跳过重叠 tick；
        // 插件层另有 payload.executing 咨询锁 + 陈旧锁自愈，见 LrtExecutor.runTask）
        dataMap["concurrentable"] = JsonValue.Boolean(false)
        dataMap["once"] = JsonValue.Boolean(false)
        dataMap["priority"] = JsonValue.Number(5.0)
        // parameters 是 JSON 字符串（与宿主 CrontabPO.parameters 同构），携带 taskId 与 userId
        // 供宿主 LrtPluginExecutor 定位任务与做行级权限。
        dataMap["parameters"] = JsonValue.String("{\"taskId\":\"${taskId}\",\"userId\":\"${userId}\"}")
        // created_at/updated_at 不显式写，沿用 host.db 与其它插件插入一致的处理（DB/f_orm 默认值）
        try {
            let res = LrtPersistService.insert(TABLE_CRONTAB, dataMap, userId, permArr)
            return LrtTriggerBridge.extractId(res)
        } catch (e: Exception) {
            eprintln("[lrt-trigger] 写入 crontab 触发记录失败（非致命，忽略）: ${e}")
            return ""
        }
    }

    /// 移除触发记录（按 task uri 物理删除）。best-effort。
    public static func removeTrigger(
        agentId: String, userId: String, permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (agentId.isEmpty()) {
            return LrtPersistService.errResult(1, "agentId 不能为空")
        }
        let taskUri = "lrt://${LrtTriggerBridge.escapeLiteral(agentId)}"
        try {
            return LrtPersistService.hardDelete(
                TABLE_CRONTAB, "task = '${taskUri}'", userId, permArr
            )
        } catch (e: Exception) {
            eprintln("[lrt-trigger] 移除 crontab 触发记录失败（非致命，忽略）: ${e}")
            return LrtPersistService.errResult(1, "${e}")
        }
    }

    /// 从 host.db 的 insert 响应中提取新记录 id（兼容多种返回形态）。
    private static func extractId(res: JsonValue): String {
        match (res) {
            case JsonValue.Map(f) =>
                match (f.get("id")) {
                    case Some(JsonValue.String(s)) => return s
                    case _ => ()
                }
                match (f.get("rows")) {
                    case Some(JsonValue.Array(rows)) =>
                        if (rows.size > 0) {
                            match (rows[0]) {
                                case JsonValue.Map(r) =>
                                    match (r.get("id")) {
                                        case Some(JsonValue.String(s)) => return s
                                        case _ => ()
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return ""
    }

    /// 转义 SQL 字面量里的单引号（agentId 进 where 子句前防护）。
    private static func escapeLiteral(s: String): String {
        return s.replace("'", "''")
    }
}
