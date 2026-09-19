/*
 * LrtCheckpointStore（long-running-task / Ch4.1 / spec 5.8）
 * 回合检查点的保存与恢复，落 `agent_contexts` 表。
 *
 * ── 为什么插件要自己存，而不是复用宿主 CheckpointManager ──────────────────
 * 宿主 `CheckpointManager` 是宿主进程内的服务对象，L3 插件是**独立进程**
 * （mode: process，宿主经 stdio 拉起），拿不到宿主的对象实例；
 * 插件访问宿主能力的唯一通道是 `ctx.invoke("host.x", ...)`，目前 5 个 host service
 * 里没有暴露检查点能力。而 `agent_contexts` 已在 plugin.yaml 的 tableWhitelist 中，
 * 因此这里经 `host.db` 直接读写同一张表——**与宿主共用一张表、同一套 metadata 约定**，
 * 不另起炉灶（避免"插件一套检查点、宿主一套检查点"，恢复时谁也不知道读哪边）。
 *
 * ── metadata 字段名沿用宿主约定（camelCase）──────────────────────────────
 * CheckpointManager 写的是 { taskId, chatRound, savedAt }；本类保持完全一致，
 * 使得宿主侧的 `listCheckpoints(agentId)` 与本类的 `loadLatest` 能互相读懂对方写的数据。
 *
 * ── 恢复语义 ─────────────────────────────────────────────────────────────
 * 恢复不是"从头再来"：从检查点里取出 chatRound，收敛循环从该轮次继续。
 * 取不到时返回 Null，调用方按"首轮"处理——恢复失败要能被感知，但不能阻断执行。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.time.DateTime
// roundOf() 用到 Int64.tryParse：它是 std.convert 对 Parsable 的扩展，
// 必须显式 import 这个继承接口，否则 cjc 报 "undeclared identifier 'tryParse'"。
import std.convert.Parsable

public class LrtCheckpointStore {
    /**
     * 保存一个回合检查点。
     *
     * @param contextJson 需要随检查点带走的上下文（进度、中间结果、payload 摘要等）
     */
    public static func save(
        taskId: String,
        agentId: String,
        round: Int64,
        contextJson: JsonValue,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (agentId.isEmpty()) {
            return LrtPersistService.errResult(40002, "agent_id 不能为空（检查点按 agent 维度索引）")
        }
        let meta = HashMap<String, JsonValue>()
        meta["taskId"] = JsonValue.String(taskId)
        meta["chatRound"] = JsonValue.String(round.toString())
        meta["savedAt"] = JsonValue.String("${DateTime.now()}")

        let dataMap = HashMap<String, JsonValue>()
        dataMap["agent_id"] = JsonValue.String(agentId)
        dataMap["messages"] = JsonValue.String(contextJson.stringify())
        dataMap["metadata"] = JsonValue.String(JsonValue.from(meta).stringify())
        return LrtPersistService.insert(LrtPersistService.TABLE_AGENT_CONTEXTS, dataMap, userId, permArr)
    }

    /**
     * 取本任务最新的检查点。
     *
     * 按 agent_id 查（表上没有 task_id 列），再在 metadata 里筛 taskId——
     * 同一 agent 可能并发跑多个任务，只按 agent 取会拿到别的任务的检查点，
     * 恢复后上下文错位，比不恢复更难排查。
     *
     * 找不到返回 JsonValue.Null；metadata 解析失败的行直接跳过（脏数据不该拖垮恢复）。
     */
    public static func loadLatest(
        taskId: String,
        agentId: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): JsonValue {
        if (agentId.isEmpty()) {
            return JsonValue.Null
        }
        let rows = LrtPersistService.queryMany(
            LrtPersistService.TABLE_AGENT_CONTEXTS,
            "agent_id = '${agentId}' AND deleted_at IS NULL",
            userId, permArr, 50
        )
        for (r in rows) {
            let metaText = LrtCheckpointStore.strOf(r, "metadata")
            if (metaText.isEmpty()) {
                continue
            }
            try {
                let meta = JsonValue.parse(metaText)
                if (LrtCheckpointStore.strOf(meta, "taskId") == taskId) {
                    return r
                }
            } catch (e: Exception) {
                eprintln("[lrt-checkpoint] metadata 解析失败，跳过该检查点: ${e.message}")
            }
        }
        return JsonValue.Null
    }

    /// 从检查点里取出轮次（用于断点续跑）；取不到返回 0
    public static func roundOf(checkpoint: JsonValue): Int64 {
        let metaText = LrtCheckpointStore.strOf(checkpoint, "metadata")
        if (metaText.isEmpty()) {
            return 0
        }
        try {
            let meta = JsonValue.parse(metaText)
            let raw = LrtCheckpointStore.strOf(meta, "chatRound")
            if (raw.isEmpty()) {
                return 0
            }
            match (Int64.tryParse(raw)) {
                case Some(v) => return v
                case None => return 0
            }
        } catch (e: Exception) {
            return 0
        }
    }

    /// 取出检查点里保存的上下文对象（不是 JSON 文本）
    public static func contextOf(checkpoint: JsonValue): JsonValue {
        let text = LrtCheckpointStore.strOf(checkpoint, "messages")
        if (text.isEmpty()) {
            return JsonValue.Null
        }
        try {
            return JsonValue.parse(text)
        } catch (e: Exception) {
            eprintln("[lrt-checkpoint] messages 解析失败: ${e.message}")
            return JsonValue.Null
        }
    }

    /// 保存结果是否为错误响应（host.db 的错误形如 { errno: <非0>, errmsg }）
    public static func isErr(v: JsonValue): Bool {
        match (v.get("errno", JsonValue.Null)) {
            case JsonValue.Number(n) => return Int64(n) != 0
            case _ => return false
        }
    }

    private static func strOf(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => return s
            case _ => return ""
        }
    }
}
