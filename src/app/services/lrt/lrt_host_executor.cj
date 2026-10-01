/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */

/**
 * LrtHostExecutor（long-running-task · 根因 D · **宿主侧执行者**）
 *
 * ## 为什么要有这个类
 *
 * 长程任务此前的分工是：宿主只"触发"，插件只"验核"——**没有任何一方真正干活**。
 * 链路实测（2026-09-22，`problem-analysis-20260922-lrt-one-round.md` 根因 D）：
 *
 * - 宿主 `src/app/services/lrt/` 只有「建任务 / 建调度 / 转发插件」三件事，
 *   没有任何跑 Agent 的代码；`LrtPluginExecutor` 的类注释也明写"只做触发"。
 * - 插件是 L3 独立进程，宿主只注册了 `host.db/log/cache/mcp/event/db_schema_lookup`，
 *   **没有 `host.ai`**，插件既调不了模型也唤不起宿主 Agent。
 * - 于是 `LrtExecutor.runTask` 每回合只能查 `pendingArtifacts()`，为空即
 *   `outcome="no_artifacts_yet"` 直接 break —— 表现就是"每 5 分钟空转一次"。
 *
 * 结论：**产物生产者在本架构下无人负责**。修调度只解决"有没有被唤起"，
 * 解决不了"唤起后干什么"。故按定夺采用**方案 1：宿主侧补执行者**——
 * 宿主本就持有模型、工具与 Agent 对象，成本最低，且不破坏进程隔离。
 *
 * ## 职责边界（重要，勿越界）
 *
 * - **只做"执行一个回合"，不做编排**。编排仍在 COMPOSITION.yaml（插件侧 D-P-H-E
 *   收敛循环），本类不读 COMPOSITION、不决定轮次上限、不做自进化。
 *   这与 `SKILL.md:144`「不要在宿主侧另起一套编排」不冲突：那是编排，这是执行者。
 * - **不写 `agent_tasks.status`**。特别**不得置 2（已完成）**——spec 5.6.1 规则 7
 *   要求未经用户确认不得交付，`LrtPluginExecutor` 存在的初衷就是不碰状态
 *   （见 `LrtPluginExecutor` 类注释）。状态迁移仍由插件按两段式负责。
 * - **只写 `long_running_task_artifact` 与 `payload` 的只读型留痕键**
 *   （`host_round` / `host_round_at` / `host_last_artifacts`），
 *   不碰插件用于进度判定的 `completed_steps` / `intermediate_result` 等键，避免双写。
 *
 * ## 一个回合做什么
 *
 * 1. 读 `agent_tasks`（goal / status / payload），终态或待评审则跳过；
 * 2. `AgentRuntimeBridge.loadFromDatabase(agentId)` 取回 Agent，
 *    从 `CheckpointManager` 恢复上一回合对话（断点续跑，不是从头再来）；
 * 3. `agent.chat(...)` 跑**一个回合**（Agent 内部的 ReAct 多步由内核自己完成）；
 * 4. 把本回合产出落盘为**可验核的产物文件**，并登记进 `long_running_task_artifact`
 *    （`verification_status='pending'`，交给插件验核）；
 * 5. 回写检查点 + payload 留痕。
 *
 * 之后仍照旧调 `LrtPluginClient.execute` 让插件验核——顺序是**先干活，再验核**。
 *
 * ## 幂等与并发
 *
 * - 轮次号由"产出目录里已有 `round-*.md` 的数量 + 1"推出，不依赖数据库计数，
 *   进程重启 / 检查点丢失都不会把轮次归零重跑。
 * - `payload.executing` 是插件侧的咨询锁；为真且未过陈旧阈值时本类**主动跳过**，
 *   避免与正在跑的回合抢同一个 Agent（宿主这一跳比插件那跳更早、更省一次 LLM）。
 *
 * ## 开关
 *
 * - `LRT_HOST_ROUND_ENABLED=0` 关闭（回到"只验核"的旧行为，便于 A/B 与回滚）。
 * - `LRT_ROUND_OUTPUT_DIR` 覆盖回合产物根目录（默认
 *   `<runtime>/skills/long-running-task/output/rounds/<taskId>`）。
 */

package magic.app.services.lrt

import std.collection.{ArrayList, concurrent.ConcurrentHashMap}
import std.env.{getWorkingDirectory, getVariable}
import std.fs.{Directory, File, exists}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt}
import magic.log.LogUtils
import magic.app.core.database.DbSerialLock
import magic.app.models.uctoo.AgentTasksPO
import magic.app.services.bridge.{AgentRuntimeBridge, CheckpointManager, LrtEventBridge}
import magic.app.services.uctoo.AgentTasksService
import magic.core.agent.{AgentRequest, AgentResponseStatus}
import magic.core.message.Conversation
import f_base.Result
import f_orm.*

/// 一个宿主回合的执行结果
public class LrtRoundOutcome {
    public var ok: Bool = false
    /// 人类可读小结（成功写产物数，失败写原因）
    public var summary: String = ""
    /// 本回合轮次号（0 表示未执行）
    public var round: Int64 = 0
    /// 本回合登记进产物表的文件路径
    public var artifacts: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class LrtHostExecutor {
    private static let TAG = "LrtHostExecutor"

    /// 并发锁陈旧阈值（ms）：payload.executing 为真且超过此时长，视为上轮崩溃遗留并接管。
    /// 缺省 30 分钟，可用 LRT_HOST_ROUND_LOCK_STALE_MS 覆盖。
    private static let DEFAULT_LOCK_STALE_MS: Int64 = 1800000

    /// 产物登记时的默认产物类型（verify_artifact.py：doc/report 走"非空 + 规模"校验）
    private static let DEFAULT_ARTIFACT_TYPE = "doc"

    /// 进程内回合互斥：同一 taskId 同时只允许一个回合（含随后的插件验核）在跑。
    /// 调度层 runningTasks 守卫对 spawn 型 LrtPluginExecutor 无效（execute 立即返回即解锁），
    /// 一次 cron tick 曾实测触发 8 个并发 runRound，互相抢 Agent + 把 host.db 打满超时。
    /// 这里用内存锁把并发收敛成串行，陈旧锁（超过阈值）视为上轮崩溃遗留并接管。
    private static let activeRounds = ConcurrentHashMap<String, DateTime>()

    /// 单回合（含插件验核）最大允许时长（ms），超过即视为陈旧锁可接管。默认 30 分钟。
    private static let MAX_ROUND_MS: Int64 = 1800000

    /// 尝试获取某 taskId 的回合锁。成功返回 true；已被他人持有（且未陈旧）返回 false。
    private static func acquireRound(taskId: String): Bool {
        if (taskId.isEmpty()) {
            // 无 taskId 不锁（保守放行，避免把没 id 的调用全挡掉）
            return true
        }
        match (LrtHostExecutor.activeRounds.get(taskId)) {
            case Some(since) =>
                let elapsed = (DateTime.now() - since).toMilliseconds()
                if (elapsed < LrtHostExecutor.MAX_ROUND_MS) {
                    return false
                }
                LrtHostExecutor.activeRounds.remove(taskId)
                LrtHostExecutor.activeRounds.put(taskId, DateTime.now())
                true
            case None =>
                LrtHostExecutor.activeRounds.put(taskId, DateTime.now())
                true
        }
    }

    /// 释放回合锁（务必在 finally 中调用，避免死锁）
    private static func releaseRound(taskId: String): Unit {
        if (!taskId.isEmpty()) {
            LrtHostExecutor.activeRounds.remove(taskId)
        }
    }

    /// 宿主执行者是否启用（默认启用）
    private static func enabled(): Bool {
        LrtHostExecutor.envFlag("LRT_HOST_ROUND_ENABLED", true)
    }

    /**
     * 跑一个宿主回合，随后照旧触发插件验核。
     *
     * 这是宿主侧两个触发点（crontab 的 `LrtPluginExecutor`、提交接口的"立即首回合"）
     * 的统一入口：**先执行、再验核**的顺序只在这里写一遍。
     *
     * 调用方应把它放进 `spawn`——一个回合可能跑很久，不能占住调度线程 / 接口线程。
     */
    public static func runRoundThenDispatch(
        taskId: String,
        agentId: String,
        userId: String,
        creator!: String = "",
        ownerUserId!: String = "",
        crontabId!: String = ""
    ): Unit {
        // 进程内回合锁：同一 taskId 只允许一个回合在跑（根因：8 倍重入风暴）。
        if (!LrtHostExecutor.acquireRound(taskId)) {
            LogUtils.info(
                LrtHostExecutor.TAG,
                "宿主回合重入被拒（已有同 taskId 在执行）: taskId=${taskId}"
            )
            return
        }
        try {
            let outcome = LrtHostExecutor.runRound(
                taskId, agentId, userId,
                creator: creator, ownerUserId: ownerUserId, crontabId: crontabId
            )
            LogUtils.info(
                LrtHostExecutor.TAG,
                "宿主回合结束: taskId=${taskId}, round=${outcome.round}, ok=${outcome.ok}, "
                + "artifacts=${outcome.artifacts.size}, summary=${outcome.summary}"
            )
            // 验核触发（RC-A · 方案 A 队列）：
            // 改为单线程同步调用，不另起 spawn 写共享 stdio —— 之前的 fire-and-forget
            // 在子线程里写宿主↔插件的 stdio 通道，触发 `The stream write error`，
            // 导致收敛循环整轮失败、任务永不收敛、crontab 无限续跑烧光 token。
            // 插件 lrt-execute handler 自身会 spawn 收敛循环并立即返回 "async started"，
            // 故本调用不会阻塞 60s，也不会与插件回呼 host.db 形成嵌套 RPC 死锁
            // （host.client.call 快速返回，插件在自身 spawn 线程里跑 runTask→host.db，
            // 由宿主 stdio server 单线程处理）。
            // 同时把验核请求落 DB 队列 lrt_verify_job 做持久化记录，作为事件驱动触发源。
            LrtHostExecutor.enqueueVerify(taskId, outcome.round, userId, ownerUserId, agentId)
            match (LrtPluginClient.execute(
                taskId, userId, ArrayList<String>(),
                creator: creator, ownerUserId: ownerUserId, agentId: agentId
            )) {
                case Ok(v) =>
                    LogUtils.info(
                        LrtHostExecutor.TAG,
                        "插件验核已触发: taskId=${taskId}, result=${LrtHostExecutor.head(v.stringify())}"
                    )
                case Err(e) =>
                    LogUtils.warn(LrtHostExecutor.TAG, "插件验核触发失败: taskId=${taskId}, reason=${e}")
                case _ =>
                    LogUtils.warn(LrtHostExecutor.TAG, "插件验核无结果: taskId=${taskId}")
            }
        } finally {
            LrtHostExecutor.releaseRound(taskId)
        }
    }

    /**
     * 执行一个回合（不触发插件）。返回 `LrtRoundOutcome`。
     *
     * @param taskId   长程任务 ID（agent_tasks.id）
     * @param agentId  执行该任务的 Agent；为空时回落到任务行的 agent_id
     * @param userId   归属真人（行级权限口径，产物表的 owner_user_id 取此值）
     * @param creator  执行者（agent 绑定的 uctoo_user）；为空时产物表 creator 写 NULL
     */
    public static func runRound(
        taskId: String,
        agentId: String,
        userId: String,
        creator!: String = "",
        ownerUserId!: String = "",
        crontabId!: String = ""
    ): LrtRoundOutcome {
        let out = LrtRoundOutcome()
        if (!LrtHostExecutor.enabled()) {
            out.summary = "宿主侧执行者已关闭（LRT_HOST_ROUND_ENABLED=0），本回合不执行"
            return out
        }
        if (taskId.isEmpty()) {
            out.summary = "task_id 为空，无法执行回合"
            return out
        }

        // ── 1) 读任务（目标 / 状态 / payload）───────────────────────────
        var task = AgentTasksPO()
        match (AgentTasksService().getById(taskId).data) {
            case Some(t) => task = t
            case None =>
                out.summary = "任务不存在: ${taskId}"
                return out
        }
        // status 是 Option<Int32>：match 两分支的整型字面量会被推成 Int64 而与 Int32 无公共父类型，
        // 故用 getOrDefault 让字面量在 Int32 语境下归位（先例见 AipDiscoveryController.cj:158）。
        let status: Int32 = task.status.getOrDefault({ => 0 })
        // 0=pending / 1=running 才继续；2=completed 3=failed 4=cancelled
        // 5=步数耗尽未闭环 6=需人工 —— 均视为终态，不再消耗 Agent 回合。
        if (status >= 2) {
            out.summary = "任务已终态（status=${status}），跳过本回合"
            return out
        }

        let payload = LrtHostExecutor.parsePayload(task.payload)
        if (LrtHostExecutor.boolField(payload, "awaiting_review")) {
            out.summary = "任务待用户评审（payload.awaiting_review=true），暂停执行"
            return out
        }
        // 插件正在跑（且锁未陈旧）→ 主动让位，避免与插件回合抢同一个 Agent
        if (LrtHostExecutor.boolField(payload, "executing")
            && !LrtHostExecutor.lockStale(payload)) {
            out.summary = "插件仍有回合在执行（payload.executing=true 且锁未陈旧），跳过本回合"
            return out
        }

        let effAgentId = if (agentId.isEmpty()) { task.agentId } else { agentId }
        if (effAgentId.isEmpty()) {
            out.summary = "无法确定执行 agent（入参 agentId 与任务 agent_id 均为空）"
            return out
        }
        var goal = LrtHostExecutor.strField(payload, "goal")
        if (goal.isEmpty()) {
            out.summary = "payload.goal 为空，无法确定任务目标（需先经 lrt-plan 规划）"
            return out
        }

        // ── 2) 准备回合目录与轮次号 ───────────────────────────────────
        // 轮次号取"已有 round-*.md 数量 + 1"：不依赖数据库计数，
        // 进程重启 / 检查点丢失都不会把轮次归零、把活重做一遍。
        let roundDir = LrtHostExecutor.roundDirOf(taskId)
        try {
            if (!exists(roundDir)) {
                Directory.create(roundDir, recursive: true)
            }
        } catch (e: Exception) {
            out.summary = "回合产出目录创建失败: ${roundDir}, ${e.message}"
            return out
        }
        // RC-D：轮次号唯一真源改为 payload.host_round + 1（不再数磁盘 round-*.md），
        // 与插件侧 runTask 内部 round 计数同源，消除"重跑第2回合/跳过第4回合"的错位观感。
        let round = LrtHostExecutor.nextRoundFromPayload(payload)
        out.round = round
        // RC-C：宿主回合预算闸。达到上限仍未收敛则转人工评审，不再无限续跑烧 token。
        let maxHostRounds = LrtHostExecutor.maxHostRounds()
        if (round > maxHostRounds) {
            LrtHostExecutor.setAwaitingReview(taskId, payload,
                "宿主回合已达上限 ${maxHostRounds}，转人工评审（taskId=${taskId}）")
            out.summary = "宿主回合已达上限（${maxHostRounds}），转人工评审：taskId=${taskId}"
            return out
        }

        // ── 3) 取回 Agent 并跑一个回合 ────────────────────────────────
        let bridge = AgentRuntimeBridge.instance
        let checkpointManager = CheckpointManager()
        let loadResult = DbSerialLock.withLock({ => bridge.loadFromDatabase(effAgentId, userId: userId) })
        if (!loadResult.success) {
            out.summary = "Agent 加载失败: ${effAgentId}, reason=${loadResult.reason}"
            return out
        }

        var content = ""
        var responseStatus = AgentResponseStatus.Success
        var executed = false
        if (let Some(agent) <- loadResult.data) {
            // 检查点续跑：把上一回合的对话历史灌回 Conversation，避免每回合从头开始
            var conversation: ?Conversation = None
            if (let Some(historyMessages) <- checkpointManager.loadLatestCheckpoint(effAgentId)) {
                if (historyMessages.size > 0) {
                    conversation = Some(Conversation())
                    // RC-B：摘要+最近1回合（双保险灰度）。不再全量重放历史
                    // （O(回合²) token 增长），只重放最近 1 个回合（最后一对消息）
                    // 保证即时连续性，更早的进度由 buildPrompt 注入的 payload 摘要承载。
                    let startIdx = if (historyMessages.size >= 2) { historyMessages.size - 2 } else { 0 }
                    var i = startIdx
                    while (i < historyMessages.size - 1) {
                        if (i + 1 < historyMessages.size) {
                            conversation.getOrThrow().addChatRound(historyMessages[i], historyMessages[i + 1])
                        }
                        i = i + 2
                    }
                }
            }
            let question = LrtHostExecutor.buildPrompt(goal, round, payload, roundDir)
            // lrtTaskId 标记：本次执行属于长程任务回合（ReactExecutor 据此在失败时
            // 使用「任务执行异常中断」文案；普通聊天不带该标记，走对话失败文案）。
            let response = agent.chat(
                AgentRequest(question, conversation: conversation, lrtTaskId: Some(taskId))
            )
            content = response.content
            responseStatus = response.status
            executed = true
            // 检查点：下一回合从这里接着跑。保存失败只记日志——
            // 检查点是"可恢复性"保障，不该因为存不下就让正在跑的长程任务当场失败。
            try {
                let lockKey = if (crontabId.isEmpty()) { taskId } else { crontabId }
                let _ = checkpointManager.saveCheckpoint(effAgentId, response.execution, Some(lockKey))
            } catch (e: Exception) {
                LogUtils.warn(LrtHostExecutor.TAG, "检查点保存失败（继续执行）: ${e.message}")
            }
        } else {
            out.summary = "Agent 数据为空: ${effAgentId}"
            return out
        }

        if (!executed) {
            out.summary = "Agent 未执行（未知原因）: ${effAgentId}"
            return out
        }
        if (responseStatus == AgentResponseStatus.Cancelled) {
            out.summary = "本回合被取消（AgentResponseStatus.Cancelled），不登记产物"
            return out
        }

        // ── 4) 落盘 + 登记产物 ───────────────────────────────────────
        // 空内容不落盘：写一个"空文件"只会让验核判失败并触发无谓自进化，
        // 不如如实报告"本回合没有产出"，由 execute-rounds 的降级链处理。
        if (content.trimAscii().isEmpty()) {
            out.summary = "Agent 本回合返回空内容，未登记产物（round=${round}）"
            LrtHostExecutor.patchPayload(taskId, payload, round, ArrayList<String>())
            return out
        }

        let transcriptPath = LrtHostExecutor.joinPath(roundDir, "round-${round}.md")
        let body = LrtHostExecutor.buildTranscript(taskId, goal, round, content)
        try {
            File.writeTo(transcriptPath, body.toArray())
        } catch (e: Exception) {
            out.summary = "回合产物落盘失败: ${transcriptPath}, ${e.message}"
            return out
        }

        // 产物清单：回合记录本体 + Agent 在回复里用 `ARTIFACTS:` 行声明的真实交付文件
        let registered = ArrayList<String>()
        if (LrtHostExecutor.registerArtifact(
            taskId, transcriptPath, LrtHostExecutor.DEFAULT_ARTIFACT_TYPE, creator, ownerUserId
        )) {
            registered.add(transcriptPath)
        }
        for (declared in LrtHostExecutor.parseDeclaredArtifacts(content)) {
            if (exists(declared) && !LrtHostExecutor.containsPath(registered, declared)) {
                if (LrtHostExecutor.registerArtifact(
                    taskId, declared, LrtHostExecutor.guessArtifactType(declared), creator, ownerUserId
                )) {
                    registered.add(declared)
                }
            }
        }

        LrtHostExecutor.patchPayload(taskId, payload, round, registered)

        // ── 4.1) HTML 产物进对话 ────────────────────────────────────
        // 产物表只存**路径**，对话里看不到内容，用户得自己翻 output 目录。
        // 这里把本回合登记的 .html 报告正文经 SSE lrt_event(artifact_ready) 推给前端，
        // 由 next-remoter 的 HtmlArtifact.vue 渲染成气泡里的 artifact 卡片。
        LrtHostExecutor.pushHtmlArtifactsToChat(taskId, effAgentId, payload, registered)

        out.artifacts = registered
        out.ok = registered.size > 0
        out.summary = if (registered.size > 0) {
            "round ${round} 已产出并登记 ${registered.size} 个产物"
        } else {
            "round ${round} 已执行但产物登记失败"
        }
        out
    }

    // ── 提示词与产出 ──────────────────────────────────────────────────

    /// 回合提示词：给足上下文（目标 / 轮次 / 上回合状态），并要求留下**可验核的落盘产物**。
    private static func buildPrompt(goal: String, round: Int64, payload: JsonObject, roundDir: String): String {
        let sb = StringBuilder()
        sb.append("你是长程任务的执行者。现在执行第 ${round} 个回合。\n\n")
        sb.append("## 任务目标\n${goal}\n\n")
        sb.append("## 本回合要求\n")
        sb.append("1. 围绕目标推进实质性工作，不要只复述计划；\n")
        sb.append("2. 把本回合的**可交付产出**写入目录：${roundDir}\n")
        sb.append("   （检索结果、解题过程、生成的 HTML/代码/报告等，文件名自取）；\n")
        sb.append("3. 在回复末尾另起一行，用 `ARTIFACTS: <绝对路径1>; <绝对路径2>` 列出本回合产出的文件；\n")
        sb.append("4. 若本回合确实无法推进，说明卡点与下一步计划——说明本身也要写进上述目录。\n\n")
        sb.append("## 已完成的进度摘要（避免重放全部历史，节省上下文）\n")
        let completedRounds = LrtHostExecutor.intField(payload, "host_round")
        sb.append("- 已完成回合：${completedRounds}\n")
        let lastArtifacts = LrtHostExecutor.strField(payload, "host_last_artifacts")
        if (!lastArtifacts.isEmpty()) {
            sb.append("- 上一回合产物：${lastArtifacts}\n")
        }
        let intermediate = LrtHostExecutor.strField(payload, "intermediate_result")
        if (!intermediate.isEmpty()) {
            sb.append("- 最近中间结论：${intermediate}\n")
        }
        if (LrtHostExecutor.boolField(payload, "awaiting_review")) {
            sb.append("- 注意：任务曾转人工评审，请优先处理待评审项。\n")
        }
        sb.append("\n请直接开始执行本回合，并在最后给出 </answer> 总结。")
        return sb.toString()
    }

    /// 回合记录文件正文。刻意把 goal 原文写进去：
    /// `LrtVerifier.verify` 会从 goal 抽日期做"旧文件不算完成"的校验，
    /// 正文里没有目标原文就会被判日期不匹配（spec 5.10.1 规则 5）。
    private static func buildTranscript(taskId: String, goal: String, round: Int64, content: String): String {
        let sb = StringBuilder()
        sb.append("# 长程任务回合产出\n\n")
        sb.append("- task_id: ${taskId}\n")
        sb.append("- round: ${round}\n")
        sb.append("- generated_at: ${DateTime.now()}\n\n")
        sb.append("## 任务目标\n\n${goal}\n\n")
        sb.append("## 本回合产出\n\n${content}\n")
        return sb.toString()
    }

    // ── 产物登记 ──────────────────────────────────────────────────────

    /**
     * 把产物登记进 `long_running_task_artifact`（`verification_status='pending'`）。
     *
     * 用参数化 SQL 而不是 DAO：`LongRunningTaskArtifactPO` 没有 `owner_user_id` 字段，
     * 而双身份要求产物表必须写归属者，否则行级权限会让插件（以归属者身份查询）**看不见**
     * 这条产物——那正是"执行者产出了、验核却说没有产物"的隐蔽失败。
     *
     * `owner_user_id` 列由 `sql/incremental/20260921_dual_identity_owner_user_id.sql` 增加；
     * 若目标库尚未执行该 DDL，这里会自动去掉该列重试（宁可少写一个归属，也不能让登记整体失败）。
     */
    private static func registerArtifact(
        taskId: String,
        artifactPath: String,
        artifactType: String,
        creator: String,
        ownerUserId: String
    ): Bool {
        if (taskId.isEmpty() || artifactPath.isEmpty()) {
            return false
        }
        // 幂等：与插件侧 logArtifact 同口径（同一 task + 同一路径只留一条），
        // 否则重试 / 崩溃恢复会让产物表按回合成倍膨胀，进度统计失真。
        if (LrtHostExecutor.artifactExists(taskId, artifactPath)) {
            return true
        }
        let withOwner = !ownerUserId.isEmpty()
        let withCreator = !creator.isEmpty()
        var cols = "task_id, artifact_path, artifact_type, verification_status"
        var vals = "?, ?, ?, ?"
        if (withCreator) {
            cols = cols + ", creator"
            vals = vals + ", ?"
        }
        if (withOwner) {
            cols = cols + ", owner_user_id"
            vals = vals + ", ?"
        }
        let sql = "INSERT INTO long_running_task_artifact (${cols}) VALUES (${vals})"
        try {
            let executor = ORM.executor()
            executor.setSql(sql)
            executor.add(taskId)
            executor.add(artifactPath)
            executor.add(artifactType)
            executor.add("pending")
            if (withCreator) {
                executor.add(creator)
            }
            if (withOwner) {
                executor.add(ownerUserId)
            }
            let affected = executor.update
            if (affected > 0) {
                return true
            }
            LogUtils.warn(LrtHostExecutor.TAG, "产物登记影响行数为 0: ${artifactPath}")
            return false
        } catch (e: Exception) {
            if (withOwner && LrtHostExecutor.isMissingColumn(e.message, "owner_user_id")) {
                LogUtils.warn(
                    LrtHostExecutor.TAG,
                    "产物表缺 owner_user_id 列（DDL 未执行？），按不带归属列重试: ${e.message}"
                )
                return LrtHostExecutor.registerArtifact(taskId, artifactPath, artifactType, creator, "")
            }
            LogUtils.error(LrtHostExecutor.TAG, "产物登记失败: ${artifactPath}, ${e.message}")
            return false
        }
    }

    private static func artifactExists(taskId: String, artifactPath: String): Bool {
        try {
            let executor = ORM.executor()
            // 与 PermissionUtils.checkUserHasPermission 同款：先 add 参数，再 setSql → first
            executor.add(taskId)
            executor.add(artifactPath)
            let cnt = executor.setSql(
                "SELECT COUNT(*) FROM long_running_task_artifact "
                + "WHERE task_id = ? AND artifact_path = ? AND deleted_at IS NULL"
            ).first<Int64>() ?? 0
            return cnt > 0
        } catch (e: Exception) {
            LogUtils.warn(LrtHostExecutor.TAG, "产物存在性查询失败（按不存在处理）: ${e.message}")
            return false
        }
    }

    // ── payload 留痕 ─────────────────────────────────────────────────

    /// 只写 `host_*` 三个只读留痕键，绝不碰插件用于进度判定的键（避免双写互相覆盖）。
    private static func patchPayload(
        taskId: String,
        payload: JsonObject,
        round: Int64,
        artifacts: ArrayList<String>
    ): Unit {
        try {
            payload.put("host_round", JsonInt(round))
            payload.put("host_round_at", JsonString("${DateTime.now()}"))
            var joined = ""
            for (p in artifacts) {
                if (joined.isEmpty()) {
                    joined = p
                } else {
                    joined = joined + ";" + p
                }
            }
            payload.put("host_last_artifacts", JsonString(joined))
            let po = AgentTasksPO()
            po.payload = Some(payload.toString())
            let _ = AgentTasksService().update(taskId, po)
        } catch (e: Exception) {
            LogUtils.warn(LrtHostExecutor.TAG, "payload 留痕失败（不影响本回合）: ${e.message}")
        }
    }

    // ── RC-A / RC-C / RC-D 辅助 ─────────────────────────────────────

    /// RC-D：轮次号唯一真源。取 payload.host_round（插件侧 runTask 也读同键），+1 作为本回合号。
    /// 不再数磁盘 round-*.md，避免与插件侧计数错位造成"重跑/跳过"。
    private static func nextRoundFromPayload(payload: JsonObject): Int64 {
        let last = LrtHostExecutor.intField(payload, "host_round")
        if (last <= 0) { 1 } else { last + 1 }
    }

    /// RC-C：宿主侧回合预算上限（默认 20）。达到上限仍未收敛则转人工评审，不再无限续跑烧 token。
    /// 可用 LRT_MAX_HOST_ROUNDS 覆盖。
    private static func maxHostRounds(): Int64 {
        match (getVariable("LRT_MAX_HOST_ROUNDS")) {
            case Some(v) =>
                let t = v.trimAscii()
                if (!t.isEmpty()) {
                    match (Int64.tryParse(t)) {
                        case Some(n) => if (n > 0) { return n }
                        case None => ()
                    }
                }
            case None => ()
        }
        20
    }

    /// RC-C：置 payload.awaiting_review=1，交棒人工而不是空转到余额耗尽。
    private static func setAwaitingReview(taskId: String, payload: JsonObject, reason: String): Unit {
        try {
            payload.put("awaiting_review", JsonInt(1))
            payload.put("awaiting_review_reason", JsonString(reason))
            let po = AgentTasksPO()
            po.payload = Some(payload.toString())
            let _ = AgentTasksService().update(taskId, po)
        } catch (e: Exception) {
            LogUtils.warn(LrtHostExecutor.TAG, "置 awaiting_review 失败: ${e.message}")
        }
    }

    /// RC-A（方案 A 队列）：把验核请求持久化进 lrt_verify_job，作为事件驱动触发源与审计。
    /// 表由 sql/incremental/ 迁移脚本创建；未执行迁移时插入失败只记日志，不影响本次触发。
    private static func enqueueVerify(taskId: String, round: Int64, userId: String, ownerUserId: String, agentId: String): Unit {
        if (taskId.isEmpty()) { return }
        try {
            let executor = ORM.executor()
            // 双账号身份（creator=执行者 / owner_user_id=归属者）：写入双方，便于委派场景下按
            // 「creator 命中本人 或 owner_user_id 命中本人」做行级权限可见。uuid 列严禁空串（22P02），
            // 故仅在非空时写入，否则回落 NULL。
            var sql = StringBuilder("INSERT INTO lrt_verify_job (task_id, round, status")
            if (!userId.isEmpty()) { sql.append(", creator") }
            if (!ownerUserId.isEmpty()) { sql.append(", owner_user_id") }
            sql.append(") VALUES (?, ?, 'pending'")
            if (!userId.isEmpty()) { sql.append(", ?") }
            if (!ownerUserId.isEmpty()) { sql.append(", ?") }
            sql.append(")")
            executor.setSql(sql.toString())
            executor.add(taskId)
            executor.add(round)
            if (!userId.isEmpty()) { executor.add(userId) }
            if (!ownerUserId.isEmpty()) { executor.add(ownerUserId) }
            let _ = executor.update
        } catch (e: Exception) {
            LogUtils.warn(LrtHostExecutor.TAG, "验核队列写入失败（不影响本次触发）: ${e.message}")
        }
    }

    // ── 小工具 ───────────────────────────────────────────────────────

    private static func parsePayload(raw: Option<String>): JsonObject {
        var obj = JsonObject()
        let text = match (raw) { case Some(s) => s; case None => "" }
        if (text.isEmpty()) {
            return obj
        }
        try {
            let parsed = JsonValue.fromStr(text)
            if (parsed is JsonObject) {
                obj = parsed.asObject()
            }
        } catch (e: Exception) {
            LogUtils.warn(LrtHostExecutor.TAG, "payload 解析失败（按空 payload 处理）: ${e.message}")
        }
        obj
    }

    /// 取字符串字段。
    ///
    /// 不用 `case JsonString(s)` 匹配：`stdx` 的 `JsonValue` 是 **sealed abstract**，
    /// 子类不能直接当模式用（见 src/skill/lrt_composition_runner.cj 同款注释）。
    /// 统一走 `asXxx()` + try/catch——形态不符就回落默认值，与 `LrtPluginExecutor.stringField` 同口径。
    private static func strField(obj: JsonObject, key: String): String {
        var out = ""
        match (obj.get(key)) {
            case Some(v) =>
                try {
                    out = v.asString().getValue()
                } catch (_: Exception) {
                    out = ""
                }
            case None => ()
        }
        out
    }

    /// 取布尔字段（兼容 JSON 布尔与 "true"/"1" 字符串两种写法）
    private static func boolField(obj: JsonObject, key: String): Bool {
        var out = false
        match (obj.get(key)) {
            case Some(v) =>
                var got = false
                try {
                    out = v.asBool().getValue()
                    got = true
                } catch (_: Exception) {
                    got = false
                }
                if (!got) {
                    let s = LrtHostExecutor.strField(obj, key)
                    out = (s == "true" || s == "1")
                }
            case None => ()
        }
        out
    }

    /// 取整数字段（JSON 整数；浮点形态按截断处理）
    private static func intField(obj: JsonObject, key: String): Int64 {
        var out: Int64 = 0
        match (obj.get(key)) {
            case Some(v) =>
                var got = false
                try {
                    out = v.asInt().getValue()
                    got = true
                } catch (_: Exception) {
                    got = false
                }
                if (!got) {
                    try {
                        out = Int64(v.asFloat().getValue())
                    } catch (_: Exception) {
                        out = 0
                    }
                }
            case None => ()
        }
        out
    }

    /// payload.executing 为真且 executing_since 超过阈值 → 视为上轮崩溃遗留（可接管）
    private static func lockStale(obj: JsonObject): Bool {
        let sinceMs = LrtHostExecutor.intField(obj, "executing_since")
        if (sinceMs <= 0) {
            // 缺 executing_since（历史数据）一律视为**不陈旧**，
            // 保持"禁止重叠"语义——与插件侧 LrtExecutor.isExecutingLockStale 同口径。
            return false
        }
        let nowMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        (nowMs - sinceMs) > LrtHostExecutor.lockStaleMs()
    }

    private static func lockStaleMs(): Int64 {
        match (getVariable("LRT_HOST_ROUND_LOCK_STALE_MS")) {
            case Some(v) =>
                let t = v.trimAscii()
                if (!t.isEmpty()) {
                    match (Int64.tryParse(t)) {
                        case Some(n) => return n
                        case None => ()
                    }
                }
            case None => ()
        }
        LrtHostExecutor.DEFAULT_LOCK_STALE_MS
    }

    private static func roundDirOf(taskId: String): String {
        let root = LrtHostExecutor.roundRoot()
        return LrtHostExecutor.joinPath(root, taskId)
    }

    private static func roundRoot(): String {
        match (getVariable("LRT_ROUND_OUTPUT_DIR")) {
            case Some(v) =>
                let t = v.trimAscii()
                if (!t.isEmpty()) {
                    return t
                }
            case None => ()
        }
        LrtHostExecutor.joinPath(
            LrtHostExecutor.joinPath(getWorkingDirectory().toString(), "skills/long-running-task/output"),
            "rounds"
        )
    }

    private static func joinPath(base: String, child: String): String {
        // 统一分隔符：Windows 下 `Path.join` 产出 `\`，而插件侧 verify_artifact.py /
        // LrtArtifactVerifier 都用普通字符串路径，混用不影响，但统一成 `/` 更省心。
        let b = if (base.endsWith("/") || base.endsWith("\\")) {
            base[0..base.size - 1]
        } else {
            base
        }
        b + "/" + child
    }

    private static func nextRound(dir: String): Int64 {
        var n: Int64 = 1
        while (n < 100000) {
            if (!exists(LrtHostExecutor.joinPath(dir, "round-${n}.md"))) {
                return n
            }
            n = n + 1
        }
        n
    }

    /// 解析回复里的 `ARTIFACTS: a; b` 声明行（长程任务的"交付物清单"约定）
    private static func parseDeclaredArtifacts(content: String): ArrayList<String> {
        let out = ArrayList<String>()
        let lines = content.split("\n")
        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.startsWith("ARTIFACTS:")) {
                let rest = trimmed.replace("ARTIFACTS:", "").trimAscii()
                for (p in rest.split(";")) {
                    let one = p.trimAscii()
                    if (!one.isEmpty()) {
                        out.add(one)
                    }
                }
            }
        }
        out
    }

    private static func containsPath(list: ArrayList<String>, path: String): Bool {
        for (p in list) {
            if (p == path) {
                return true
            }
        }
        false
    }

    private static func guessArtifactType(path: String): String {
        if (path.endsWith(".py") || path.endsWith(".js") || path.endsWith(".ts")
            || path.endsWith(".cj") || path.endsWith(".java") || path.endsWith(".go")) {
            return "code"
        }
        if (path.endsWith(".json") || path.endsWith(".csv") || path.endsWith(".yaml")
            || path.endsWith(".yml")) {
            return "data"
        }
        if (path.endsWith(".html") || path.endsWith(".htm") || path.endsWith(".pdf")
            || path.endsWith(".docx") || path.endsWith(".pptx") || path.endsWith(".xlsx")) {
            return "report"
        }
        LrtHostExecutor.DEFAULT_ARTIFACT_TYPE
    }

    /// 单条 HTML 产物允许推送进对话的最大字节数（1 MB）。
    /// 超限只记日志不推送：SSE 单帧塞几 MB 正文会拖慢整条流，
    /// 前端 iframe 的 srcdoc 也扛不住巨型文档。
    private static let MAX_HTML_ARTIFACT_BYTES: Int64 = 1048576

    /// 已推送进对话的 HTML 产物：key=`${taskId}|${path}`，value=推送时的字节数。
    ///
    /// 跨回合去重用。Agent 常在多个回合里重复声明同一个报告路径，而
    /// `registerArtifact` 对"已登记过"的路径同样返回 true（产物表幂等），
    /// 不去重会让聊天区**每回合多一张一模一样的卡片**。
    /// 文件字节数变了才重推（报告被改写，值得再给用户看一次）。
    ///
    /// 只存进程内存：重启后重新推一次可接受（这是展示面，不做持久化）。
    private static let pushedHtmlArtifacts = ConcurrentHashMap<String, Int64>()

    /**
     * 把本回合登记的 HTML 产物推送进对话（SSE `lrt_event`，type=`artifact_ready`）。
     *
     * 只处理 `.html` / `.htm`：`round-N.md` 这类回合记录塞进对话只会刷屏，
     * 报告类产物才是用户想看的。
     *
     * 全程只记日志不上抛——这是**展示面**而非控制面：读不到文件、编码有问题，
     * 都不该让正在跑的回合失败（与 `LrtEventBridge.dispatch` 同款取舍）。
     */
    private static func pushHtmlArtifactsToChat(
        taskId: String,
        agentId: String,
        payload: JsonObject,
        artifacts: ArrayList<String>
    ): Unit {
        // session_id 由提交接口写进 payload（见 LongTaskApiService.buildInitialPayload）。
        // 纯 cron 触发的任务没有会话，事件只能走 WS 广播，前端聊天区收不到，
        // 此时读文件纯属浪费，直接跳过。
        let sessionId = LrtHostExecutor.strField(payload, "session_id")
        if (sessionId.isEmpty()) {
            return
        }
        let traceId = LrtHostExecutor.strField(payload, "trace_id")

        for (p in artifacts) {
            if (!LrtHostExecutor.isHtmlArtifact(p)) {
                continue
            }
            try {
                if (!exists(p)) {
                    continue
                }
                let bytes = File.readFrom(p)
                let size = bytes.size
                if (size <= 0) {
                    continue
                }
                if (size > LrtHostExecutor.MAX_HTML_ARTIFACT_BYTES) {
                    LogUtils.warn(
                        LrtHostExecutor.TAG,
                        "HTML 产物超过推送上限，已跳过: ${p}"
                        + " (${size} > ${LrtHostExecutor.MAX_HTML_ARTIFACT_BYTES} bytes)"
                    )
                    continue
                }
                // 跨回合去重：同一路径且字节数未变 → 已推过，不再重复进对话
                let dedupeKey = "${taskId}|${p}"
                let prevSizeOpt = LrtHostExecutor.pushedHtmlArtifacts.get(dedupeKey)
                if (prevSizeOpt.isSome() && prevSizeOpt.getOrThrow() == size) {
                    continue
                }
                // 产物由 Agent 写出，编码不保证是 UTF-8：先严格解码，失败退回 unchecked。
                // unchecked 不校验、可能出乱码，但总比整条事件丢失强（观测面取舍）。
                // 写法与 ScriptExecutor.decodeOutput 保持一致（已验证可编译）。
                let html = try {
                    String.fromUtf8(bytes)
                } catch (_: Exception) {
                    unsafe { String.fromUtf8Unchecked(bytes) }
                }
                LrtEventBridge.instance.pushArtifactReady(
                    taskId, sessionId, agentId,
                    LrtHostExecutor.basename(p), html, p, traceId
                )
                LrtHostExecutor.pushedHtmlArtifacts.put(dedupeKey, size)
                LogUtils.info(LrtHostExecutor.TAG, "HTML 产物已推送进对话: ${p} (${size} bytes)")
            } catch (e: Exception) {
                LogUtils.warn(LrtHostExecutor.TAG, "HTML 产物推送失败（已忽略）: ${p}, ${e.message}")
            }
        }
    }

    /// 是否是报告类 HTML 产物（大小写不敏感）
    private static func isHtmlArtifact(path: String): Bool {
        let lower = path.toAsciiLower()
        lower.endsWith(".html") || lower.endsWith(".htm")
    }

    /// 取路径最后一段（卡片标题用）。同时兼容 `/` 与 Windows 的 `\`。
    private static func basename(path: String): String {
        let unixParts = path.split("/")
        var last = path
        if (unixParts.size > 0) {
            last = unixParts[unixParts.size - 1]
        }
        let winParts = last.split("\\")
        if (winParts.size > 0) {
            winParts[winParts.size - 1]
        } else {
            last
        }
    }

    private static func envFlag(name: String, dflt: Bool): Bool {
        match (getVariable(name)) {
            case Some(v) =>
                let t = v.trimAscii()
                if (t == "0" || t == "false" || t == "False" || t == "FALSE"
                    || t == "off" || t == "OFF" || t == "no") {
                    return false
                }
                if (t == "1" || t == "true" || t == "True" || t == "TRUE"
                    || t == "on" || t == "ON" || t == "yes") {
                    return true
                }
            case None => ()
        }
        dflt
    }

    private static func isMissingColumn(message: String, column: String): Bool {
        // Postgres 缺失列：SQLSTATE 42703，文案形如
        // `column "owner_user_id" of relation "long_running_task_artifact" does not exist`
        message.contains("42703") || (message.contains(column) && message.contains("does not exist"))
    }

    private static func head(s: String, n!: Int64 = 200): String {
        if (s.size <= n) {
            return s
        }
        s[0..n]
    }
}
