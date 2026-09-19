/*
 * LrtExecutor（long-running-task / Ch4）
 * 长程任务回合收敛循环（D-P-H-E）：
 *   plan → [每轮] 验核未校验产物 → 全部通过则完成；有失败则自进化 → 下一轮
 * 产物由宿主 Agent（crontab/WebMCP）产出并经 lrt-verify 落库；本执行器负责
 * 验核收敛与自进化闭环，并回写 agent_tasks.status。
 *
 * status 约定（design §6.1）：1=running 2=completed 4=cancelled 5=paused 6=需人工/失败收敛
 *
 * Ch9.2/9.3 补充：
 * - 每轮把进度写回 `agent_tasks.payload`（completed_steps / total_steps /
 *   current_step / intermediate_result），Ch9.1 的 /progress API 与 progress_update
 *   事件都读这份数据——**两个出口一份数据源**，不做双写；
 * - 每轮向宿主上报 step_start / step_complete|step_failed / progress_update 事件，
 *   终态上报 goal_achieved。上报失败只吞掉，不影响收敛循环。
 *
 * 注意"步"的粒度：这里的 step 指**一轮验核**（round），不是 SOP 的原子步骤。
 * 宿主 Agent 在回合内跑了几步，插件进程看不到；用轮次作为进度单位是当前架构下
 * 唯一可可靠计数的一层。progress 语义因此在 spec 里定义为"已完成轮次/最大轮次"。
 */
package skill_long_running_task

import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.time.DateTime

public class LrtExecutor {
    /// 执行长程任务收敛循环
    public static func runTask(
        taskId: String,
        agentId: String,
        goal: String,
        userId: String,
        permArr: ArrayList<JsonValue>,
        maxRounds: Int64,
        isRoot!: Bool = true
    ): JsonValue {
        if (taskId.isEmpty()) {
            return LrtPersistService.errResult(40002, "task_id 不能为空")
        }
        // Ch4.1：轮次与时长的上限统一读 plugin.yaml 的 config 段（可由 LRT_* 环境变量覆盖）。
        // 入参 maxRounds 显式给定时优先（调用方明确要少跑几轮的场景），
        // 未给 / 给 0 才回落配置——避免「配置改了但代码里还有一处硬编码 30」。
        let effectiveMaxRounds = if (maxRounds > 0) { maxRounds } else { LrtConfig.maxRounds() }
        let roundBudgetMs = LrtConfig.maxRoundDurationMs()
        // 0. 解出会话/追踪上下文（供事件上报）
        //    从 payload 里取而不是表字段：agent_tasks 没有 session_id/trace_id 列，
        //    而这两个值是"某次提交的上下文"，天然属于 payload。
        //    缺失时为空串——宿主 LrtEventBridge 在空 sessionId 下只走 WebSocket 广播，
        //    空 traceId 则不写该字段，都是定义好的降级路径。
        let taskRow = LrtPersistService.queryOne(
            LrtPersistService.TABLE_AGENT_TASKS, "id = '${taskId}'", userId, permArr
        )
        let sessionId = LrtExecutor.extractPayloadString(taskRow, "session_id")
        let traceId = LrtExecutor.extractPayloadString(taskRow, "trace_id")
        // §4.2 / §11.3：解析 crontab_id 供轨迹落库（best-effort，解析不到回落 taskId）
        let crontabId = LrtTraceLog.resolveCrontabId(agentId, userId, permArr)
        // §4 数据驱动桥：确保宿主侧存在触发 LrtPluginExecutor 的 crontab 记录
        // （scheme = lrt://，2026-09-15 起由 agent_execution:// 变更而来），
        // 使宿主 SchedulerEngine 持续按 cron 反向驱动本任务的多步循环。
        // 幂等（resolveCrontabId 复用既有记录，未命中才插入），best-effort。
        let triggerId = LrtTriggerBridge.ensureTrigger(agentId, taskId, "", userId, permArr)
        eprintln("[lrt-executor] 数据驱动桥：crontab 触发记录 id=${triggerId}")
        let runStartMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        // 任务开始即落一条 crontab_log 轨迹（best-effort，失败不影响收敛循环）
        LrtTraceLog.emitStep(taskId, crontabId, traceId, 0, "task:start", 1, 0, "runTask entered", userId, permArr)
        // §4.3 并发控制：concurrentable=false（默认）时，同一任务的新触发不与前一次重叠。
        // 用 payload.executing 作为咨询锁；**并带陈旧锁自愈**——锁龄超过 maxTaskDurationMs
        // 视为上一轮崩溃遗留（进程/宿主异常退出时锁不会被清），本次直接接管，
        // 避免任务被一把永久锁卡死（原实现无此保护，见 review 偏差 #2）。
        // concurrentable 现读 plugin.yaml 的 config.concurrentable（LRT_CONCURRENTABLE 可覆盖），
        // 不再从 crontab 列读 —— 给用户一个可配置开关。
        // 局限：跨进程不保证互斥（插件为单进程，多副本部署下需外部锁）。
        if (isRoot) {
            let concurrentable = LrtExecutor.isConcurrentable()
            let executing = LrtExecutor.extractPayloadBool(taskRow, "executing")
            let lockStale = LrtExecutor.isExecutingLockStale(taskRow)
            if (!concurrentable && executing && !lockStale) {
                eprintln("[lrt-executor] 并发被禁止且前序执行未完成，跳过本次触发（task=${taskId}）")
                let skip = HashMap<String, JsonValue>()
                skip["errno"] = JsonValue.Number(0.0)
                skip["errmsg"] = JsonValue.String("ok")
                skip["outcome"] = JsonValue.String("concurrency_skipped")
                skip["task_id"] = JsonValue.String(taskId)
                return JsonValue.from(skip)
            }
            if (executing && lockStale) {
                eprintln("[lrt-executor] 检测到陈旧并发锁（锁龄超过 maxTaskDurationMs），本次接管执行（task=${taskId}）")
            }
            LrtExecutor.setExecutingLock(taskId, true, userId, permArr)
        }
        // 关键产出物清单（终检用）。为空表示本任务未声明必达产物，终检跳过。
        let requiredArtifacts = LrtExecutor.extractPayloadStringArray(taskRow, "required_artifacts")

        // Ch4.1 检查点恢复：从断点续跑，而不是从头再来。
        // 取不到检查点时 startRound 保持 0（首轮），这是定义好的降级路径而非错误。
        let checkpoint = LrtCheckpointStore.loadLatest(taskId, agentId, userId, permArr)
        var startRound: Int64 = 0
        match (checkpoint) {
            case JsonValue.Map(_) =>
                startRound = LrtCheckpointStore.roundOf(checkpoint)
                eprintln("[lrt-executor] 命中检查点，从 round ${startRound} 续跑（task=${taskId}）")
            case _ =>
                eprintln("[lrt-executor] 无可用检查点，从首轮开始（task=${taskId}）")
        }

        // 1. 规划（若提供了 goal 且尚未规划）
        if (!goal.isEmpty()) {
            LrtPlanner.plan(goal, taskId, userId, permArr)
        }
        LrtPersistService.updateTaskStatus(taskId, 1, userId, permArr)

        var round: Int64 = startRound
        var outcome = "no_artifacts_yet"
        // §5.4.1 规则 3：进度里要带"预估剩余时间"。用**已跑轮次实测均值**外推——
        // 每轮成本取决于本轮验核/进化的工作量，无法静态估计，均值是唯一有依据的估计源。
        // 只在 runTask 内累计，不落库：估算值跨进程重启后失效本就该重算。
        var roundsDurationMs: Int64 = 0
        var completedRounds: Int64 = 0
        // §11.3 监控埋点：记录最近一次检查点保存耗时（ms）。0 表示本任务未走到保存点。
        var checkpointSaveLatencyMs: Int64 = 0
        let limit: Int64 = 200
        // 恢复点已达上限：直接交人工，不要让循环空转一圈后假装"等待产出"
        if (round >= effectiveMaxRounds) {
            outcome = "need_human"
        }
        // 步骤总数：以上限轮次为分母，前端能显示"第 N/30 轮"而不是干等
        let totalSteps = if (effectiveMaxRounds > 0) { effectiveMaxRounds } else { 1 }

        while (round < effectiveMaxRounds) {
            round = round + 1
            let roundStartMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()

            LrtEventEmitter.stepStart(taskId, sessionId, agentId, "round-${round}", round, totalSteps, traceId)

            // 2. 验核所有未校验产物
            let pending = LrtExecutor.pendingArtifacts(taskId, userId, permArr, limit)
            if (pending.size == 0) {
                // 没有待验核产物：若之前已有产物且都已通过则完成；否则等待宿主产出
                if (LrtExecutor.countArtifacts(taskId, userId, permArr, "verification_status = 'passed'") > 0) {
                    outcome = "completed"
                    break
                }
                outcome = "no_artifacts_yet"
                break
            }
            for (art in pending) {
                let path = LrtExecutor.extractString(art, "artifact_path")
                let atype = LrtExecutor.extractString(art, "artifact_type")
                LrtVerifier.verify(path, atype, taskId, agentId, userId, permArr, goal)
            }

            // 3. 统计失败 / 通过
            let failed = LrtExecutor.countArtifacts(taskId, userId, permArr, "verification_status = 'failed'")
            let passed = LrtExecutor.countArtifacts(taskId, userId, permArr, "verification_status = 'passed'")

            let durationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - roundStartMs
            // 先累计再判超时：超时那一轮同样是"已跑过的一轮"，计入均价才不至于长期偏乐观
            roundsDurationMs = roundsDurationMs + durationMs
            completedRounds = completedRounds + 1
            let summary = "round ${round}: passed=${passed}, failed=${failed}"
            // §4.2 / §11.3：每轮结构化轨迹落 crontab_log（best-effort，失败不影响收敛循环）
            LrtTraceLog.emitRound(taskId, crontabId, traceId, round, 1, durationMs, summary, userId, permArr)

            // Ch4.1 回合超时：超预算就收手。**置 status=6 而不是 0**——
            // 0 是"待处理"，会让任务被当成新任务重新派发、丢掉整段回合上下文（spec 6.1 禁止状态倒退）。
            if (durationMs > roundBudgetMs) {
                // 超时必须先落检查点：下一次调度要从这里接着跑，
                // 没有检查点的"超时"等于把已经跑完的几轮全丢掉。
                let timeoutCtx = HashMap<String, JsonValue>()
                timeoutCtx["round"] = JsonValue.Number(Float64(round))
                timeoutCtx["passed"] = JsonValue.Number(Float64(passed))
                timeoutCtx["failed"] = JsonValue.Number(Float64(failed))
                timeoutCtx["summary"] = JsonValue.String("round ${round} 超时中止")
                timeoutCtx["goal"] = JsonValue.String(goal)
                let timeoutCp = LrtCheckpointStore.save(taskId, agentId, round, JsonValue.from(timeoutCtx), userId, permArr)
                if (!LrtCheckpointStore.isErr(timeoutCp)) {
                    LrtEventEmitter.checkpointSaved(taskId, sessionId, agentId, "", round, traceId)
                } else {
                    eprintln("[lrt-executor] 超时检查点保存失败: ${timeoutCp.stringify()}")
                }
                let timeoutPatch = HashMap<String, JsonValue>()
                timeoutPatch["current_step"] = JsonValue.String("round-${round}")
                timeoutPatch["intermediate_result"] = JsonValue.String("round ${round} 超时中止：${durationMs}ms > ${roundBudgetMs}ms")
                LrtPersistService.patchTaskPayload(taskId, timeoutPatch, userId, permArr)
                LrtEventEmitter.stepFailed(
                    taskId, sessionId, agentId, "round-${round}", round,
                    "回合超时（${durationMs}ms，上限 ${roundBudgetMs}ms）", round, false, traceId
                )
                outcome = "round_timeout"
                break
            }

            // Ch9.3：进度写回 payload（Ch9.1 /progress 与 progress_update 事件共用此数据）
            let patch = HashMap<String, JsonValue>()
            patch["completed_steps"] = JsonValue.Number(Float64(round))
            patch["total_steps"] = JsonValue.Number(Float64(totalSteps))
            patch["current_step"] = JsonValue.String("round-${round}")
            patch["intermediate_result"] = JsonValue.String(summary)
            LrtPersistService.patchTaskPayload(taskId, patch, userId, permArr)

            // Ch9.2：步骤完成事件（带派生 progressPercent，由宿主侧计算）
            LrtEventEmitter.stepComplete(
                taskId, sessionId, agentId, "round-${round}", round, totalSteps,
                durationMs, summary, traceId
            )
            // estimatedRemaining 由已跑轮次均值外推（spec 5.4.1 规则 3）。
            // 数据不足（尚无完整轮次）或已无剩余轮次时传 None，宿主侧输出 null 而不是 0——
            // 0 会被前端读成"马上完成"，比"未知"更有害。
            let estimatedRemainingMs = LrtExecutor.estimateRemainingMs(
                roundsDurationMs, completedRounds, totalSteps - round
            )
            LrtEventEmitter.progressUpdate(
                taskId, sessionId, agentId, round, totalSteps,
                "round-${round}", estimatedRemainingMs, summary, traceId
            )

            // Ch4.1 检查点：每回合保存一次（spec 5.8）。
            // 保存失败只记日志并继续执行——检查点是"可恢复性"保障，
            // 不该因为存不下检查点就让正在跑的长程任务当场失败。
            let cpContext = HashMap<String, JsonValue>()
            cpContext["round"] = JsonValue.Number(Float64(round))
            cpContext["passed"] = JsonValue.Number(Float64(passed))
            cpContext["failed"] = JsonValue.Number(Float64(failed))
            cpContext["summary"] = JsonValue.String(summary)
            cpContext["goal"] = JsonValue.String(goal)
            let cpSaveStartMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            let cpResult = LrtCheckpointStore.save(taskId, agentId, round, JsonValue.from(cpContext), userId, permArr)
            checkpointSaveLatencyMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - cpSaveStartMs
            if (LrtCheckpointStore.isErr(cpResult)) {
                eprintln("[lrt-executor] 检查点保存失败（继续执行）: ${cpResult.stringify()}")
            } else {
                LrtEventEmitter.checkpointSaved(taskId, sessionId, agentId, "", round, traceId)
            }

            if (failed == 0 && passed > 0) {
                outcome = "completed"
                break
            }
            if (failed > 0 && round < effectiveMaxRounds) {
                // 4. 自进化：以失败产物上下文驱动 evolve
                //    传 taskId：让环节 1 能采集本任务的产物验核分布作为实测证据，
                //    而不是只靠拼出来的文本上下文去猜根因。
                let ctx = LrtExecutor.buildEvolutionContext(taskId, userId, permArr)
                LrtEventEmitter.stepFailed(
                    taskId, sessionId, agentId, "round-${round}", round,
                    "存在 ${failed} 个验核失败产物", round, true, traceId
                )

                // 4.0.0 补执行（spec 5.6.3 / Ch6.1）：验核失败先标记需要重新产出的产物到
                //       payload.rework_artifacts，宿主 Agent 下一轮读取此标记重新产出。
                //       补执行后仍失败则由下面的降级链处理。次序：补执行 → 降级 → 自进化。
                LrtExecutor.markReworkArtifacts(taskId, userId, permArr)

                // 4.0 降级策略链（Ch4.2 / tasks.md #244）：self-evolution 之前先走
                //     cli_execute → builtin_tool → llm → template 四环节。
                //     次序是有意的：自进化解决**根因**（下一轮别再犯），
                //     降级解决**当下**（这一轮还有没有救）。先救当下再改根因。
                //     降级成功不代表任务完成——结果里 degraded=true / applied=<环名>
                //     必须写进 payload，让下游知道这一步不是按原计划跑通的。
                let acceptance = ArrayList<String>()
                acceptance.add("round ${round} 的 ${failed} 个失败产物需在后续回合重新产出并通过验核")
                acceptance.add("产物文件非空且与其 artifact_type 对应的校验项全部通过")
                if (passed > 0) {
                    acceptance.add("已通过的 ${passed} 个产物不得被回滚")
                }
                let degradation = LrtDegradation.run(
                    taskId, round, "round ${round} 存在 ${failed} 个验核失败产物",
                    acceptance, userId, permArr, traceId
                )
                let degradePatch = HashMap<String, JsonValue>()
                degradePatch["last_degradation"] = degradation
                LrtPersistService.patchTaskPayload(taskId, degradePatch, userId, permArr)
                match (degradation.get("errno", JsonValue.Null)) {
                    case JsonValue.Number(n) =>
                        if (Int64(n) == 0) {
                            eprintln("[lrt-executor] round ${round} 经降级环节 '${degradation.get("applied", JsonValue.Null)}' 恢复（已标记 degraded）")
                        } else {
                            eprintln("[lrt-executor] round ${round} 降级链耗尽：${degradation.get("errmsg", JsonValue.Null)}")
                        }
                    case _ => ()
                }

                // 第 7 个参数 taskId 是命名参数（仓颉语法要求带默认值的参数必须是命名参数），
                // 因此必须按名传值，不能写成第 7 个普通位置实参。
                LrtSelfEvolution.evolve(agentId, round, ctx, "long-running-task", userId, permArr, taskId: taskId)
                // 继续下一轮（宿主 Agent 应基于进化结果产出修正后的产物）
            } else if (failed > 0) {
                LrtEventEmitter.stepFailed(
                    taskId, sessionId, agentId, "round-${round}", round,
                    "已达最大轮次仍有 ${failed} 个失败产物", round, false, traceId
                )
                outcome = "need_human"
                break
            }
        }

        // 4.5 终检（Ch6.1 / spec 5.14）：生成最终 answer 前确认关键产出物真的都在
        //     缺失时不宣称完成，置 status=6 交人工——"少了一个文件也算完成"是
        //     长程任务里最容易被接受、事后最难追责的一类失败。
        if (outcome == "completed" && requiredArtifacts.size > 0) {
            let check = LrtArtifactVerifier.finalCheck(requiredArtifacts, goal)
            var allPresent = true
            match (check.get("all_present", JsonValue.Boolean(true))) {
                case JsonValue.Boolean(b) => allPresent = b
                case _ => allPresent = true
            }
            if (!allPresent) {
                outcome = "missing_artifacts"
                let missingCount = LrtExecutor.numOf(check, "missing_count")
                LrtEventEmitter.stepFailed(
                    taskId, sessionId, agentId, "final-check", round,
                    "终检：${missingCount} 个关键产出物缺失或不可用", round, false, traceId
                )
                let finalPatch = HashMap<String, JsonValue>()
                finalPatch["final_check"] = check
                LrtPersistService.patchTaskPayload(taskId, finalPatch, userId, permArr)
            }
        }

        // 5. 回写最终状态
        if (outcome == "completed") {
            // spec 5.6.1 规则 7：禁止在用户未确认前将产物合并/部署。
            // 故完成时不直接置 status=2，而是标记 awaiting_review=true，
            // 推送 review_required 事件，等用户经 lrt-deliver 确认后才置 status=2。
            let reviewPatch = HashMap<String, JsonValue>()
            reviewPatch["awaiting_review"] = JsonValue.Boolean(true)
            LrtPersistService.patchTaskPayload(taskId, reviewPatch, userId, permArr)
            let passedFinal = LrtExecutor.countArtifacts(taskId, userId, permArr, "verification_status = 'passed'")
            LrtEventEmitter.goalAchieved(
                taskId, sessionId, agentId, 1.0, passedFinal,
                "任务完成：${passedFinal} 个产物全部通过验核", traceId
            )
            LrtEventEmitter.reviewRequired(
                taskId, sessionId, agentId, 1.0, passedFinal,
                "任务完成：${passedFinal} 个产物全部通过验核，请确认交付", goal, traceId
            )
        } else if (outcome == "need_human" || outcome == "round_timeout" || outcome == "missing_artifacts") {
            LrtPersistService.updateTaskStatus(taskId, 6, userId, permArr)
        }
        // no_artifacts_yet：保持 running(1)，等待宿主产出

        // §4.3 释放并发咨询锁（仅根任务持有）
        if (isRoot) {
            LrtExecutor.setExecutingLock(taskId, false, userId, permArr)
        }

        // §4.3 子任务派发 + 结果聚合（仅根任务触发，子任务以 isRoot=false 驱动，避免递归）
        if (isRoot) {
            let kids = LrtExecutor.childTasks(taskId, userId, permArr)
            if (kids.size > 0) {
                LrtExecutor.dispatchSubTasks(taskId, agentId, userId, permArr, traceId, sessionId)
                LrtExecutor.aggregateSubTaskResults(taskId, userId, permArr)
            }
        }

        // §4.2 / §11.3：任务级轨迹落 crontab_log（best-effort，覆盖最终 outcome，供 /trace 归并时间线）
        let totalMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - runStartMs
        let finalStatus: Int64 = if (outcome == "completed") { 1 } else { 0 }
        LrtTraceLog.emitStep(
            taskId, crontabId, traceId, round, "task:${outcome}", finalStatus, totalMs,
            "outcome=${outcome}, round=${round}", userId, permArr
        )

        // §11.3 监控埋点（Ch11.3 / task 1003）：把本次任务终态喂给进程内滑动窗口，
        // 由 LrtMonitorService 计算失败率/超时率/平均检查点与单轮延迟，超阈值经
        // LrtAlertService 告警（事件 + 结构化日志 + stderr）。
        // 说明：
        // - `no_artifacts_yet` 是"宿主尚未产出产物、任务继续 running"的非终态轮询，
        //   记进去会把正常等待统计成失败 → 只记录真正的终态。
        // - 调度器对同一任务的重复触发可能产生重复样本（completed 类不会触发告警，
        //   不影响告警正确性）；监控是观测面，进程内 best-effort，不做持久化去重。
        if (outcome != "no_artifacts_yet") {
            let progressLatencyMs = if (round > 0) { totalMs / round } else { totalMs }
            let monitorOutcome = if (outcome == "completed") {
                "completed"
            } else if (outcome == "round_timeout") {
                "round_timeout"
            } else {
                "failed"
            }
            LrtMonitorService.recordTaskOutcome(
                taskId, sessionId, agentId, traceId,
                monitorOutcome, checkpointSaveLatencyMs, progressLatencyMs,
                userId, permArr
            )
        }

        let response = HashMap<String, JsonValue>()
        response["errno"] = JsonValue.Number(0.0)
        response["errmsg"] = JsonValue.String("ok")
        response["outcome"] = JsonValue.String(outcome)
        response["round"] = JsonValue.Number(Float64(round))
        response["task_id"] = JsonValue.String(taskId)
        return JsonValue.from(response)
    }

    // ── 内部查询辅助 ──────────────────────────────────────────────

    private static func pendingArtifacts(taskId: String, userId: String, permArr: ArrayList<JsonValue>, limit: Int64): Array<JsonValue> {
        let whereClause = "task_id = '${taskId}' AND (verification_status IS NULL OR verification_status = 'pending') AND deleted_at IS NULL"
        return LrtPersistService.queryMany(LrtPersistService.TABLE_ARTIFACT, whereClause, userId, permArr, limit)
    }

    private static func countArtifacts(taskId: String, userId: String, permArr: ArrayList<JsonValue>, statusWhere: String): Int64 {
        let whereClause = "task_id = '${taskId}' AND ${statusWhere} AND deleted_at IS NULL"
        let rows = LrtPersistService.queryMany(LrtPersistService.TABLE_ARTIFACT, whereClause, userId, permArr, 1000)
        return Int64(rows.size)
    }

    private static func buildEvolutionContext(taskId: String, userId: String, permArr: ArrayList<JsonValue>): String {
        let rows = LrtPersistService.queryMany(
            LrtPersistService.TABLE_ARTIFACT,
            "task_id = '${taskId}' AND verification_status = 'failed' AND deleted_at IS NULL",
            userId, permArr, 50
        )
        let sb = StringBuilder()
        for (art in rows) {
            let path = LrtExecutor.extractString(art, "artifact_path")
            let summary = LrtExecutor.extractNestedString(art, "verification_result", "summary")
            sb.append("- 产物 ${path} 验核失败: ${summary}\n")
        }
        return if (sb.size > 0) { sb.toString() } else { "存在失败产物但无摘要" }
    }

    /**
     * 补执行标记（spec 5.6.3 / Ch6.1）。
     *
     * 收集验核失败的产物路径，写入 payload.rework_artifacts。
     * 宿主 Agent 下一轮读取此标记后重新产出对应产物。
     * 补执行后仍失败则由降级策略链（LrtDegradation）处理。
     */
    private static func markReworkArtifacts(taskId: String, userId: String, permArr: ArrayList<JsonValue>): Unit {
        let failedArtifacts = LrtPersistService.queryMany(
            LrtPersistService.TABLE_ARTIFACT,
            "task_id = '${taskId}' AND verification_status = 'failed' AND deleted_at IS NULL",
            userId, permArr, 200
        )
        let reworkList = ArrayList<JsonValue>()
        for (art in failedArtifacts) {
            let path = LrtExecutor.extractString(art, "artifact_path")
            if (!path.isEmpty()) {
                reworkList.add(JsonValue.String(path))
            }
        }
        if (reworkList.size > 0) {
            let patch = HashMap<String, JsonValue>()
            patch["rework_artifacts"] = JsonValue.from(reworkList)
            LrtPersistService.patchTaskPayload(taskId, patch, userId, permArr)
            eprintln("[lrt-executor] 标记 ${reworkList.size} 个失败产物待补执行（task=${taskId}）")
        }
    }

    private static func extractString(json: JsonValue, key: String): String {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.String(s) => s
            case _ => ""
        }
    }

    /**
     * 取任务行的 payload（对象形态）。
     *
     * `payload` 可能是**对象**也可能是 **JSON 文本**，取决于 host.db 驱动的序列化方式。
     * 这里统一归一化为 JsonValue.Map（解析失败给 Null），避免每个读取点各写一遍
     * 两层 match——重复三次以上就会出现"有的地方兼容了、有的没有"的偏斜。
     */
    private static func payloadOf(row: JsonValue): JsonValue {
        let raw = match (row) {
            case JsonValue.Map(fields) => match (fields.get("payload")) {
                case Some(v) => v
                case None => JsonValue.Null
            }
            case _ => JsonValue.Null
        }
        match (raw) {
            case JsonValue.String(s) =>
                try {
                    return JsonValue.parse(s)
                } catch (e: Exception) {
                    return JsonValue.Null
                }
            case _ => return raw
        }
    }

    /**
     * 从 `agent_tasks` 行里取 `payload.<key>` 的字符串值。
     *
     * payload 的两种形态（对象 / JSON 文本）都由上面的 payloadOf 兜住，
     * 宁可多写一跳也不要让 sessionId 静默变成空串——那会导致 SSE 通道整体失效且极难排查。
     */
    private static func extractPayloadString(row: JsonValue, key: String): String {
        let payloadVal = LrtExecutor.payloadOf(row)
        match (payloadVal) {
            case JsonValue.Map(p) =>
                match (p.get(key)) {
                    case Some(JsonValue.String(s)) => return s
                    case _ => ()
                }
            case _ => ()
        }
        ""
    }

    /// 取 `payload.<key>` 的字符串数组（清单为空时返回空列表，终检据此跳过）
    private static func extractPayloadStringArray(row: JsonValue, key: String): ArrayList<String> {
        let result = ArrayList<String>()
        let payloadVal = LrtExecutor.payloadOf(row)
        match (payloadVal) {
            case JsonValue.Map(p) =>
                match (p.get(key)) {
                    case Some(JsonValue.Array(items)) =>
                        for (it in items) {
                            match (it) {
                                case JsonValue.String(s) =>
                                    if (!s.isEmpty()) {
                                        result.add(s)
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return result
    }

    private static func numOf(json: JsonValue, key: String): Int64 {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.Number(n) => return Int64(n)
            case _ => return 0
        }
    }

    private static func extractNestedString(json: JsonValue, objKey: String, leafKey: String): String {
        match (json.get(objKey, JsonValue.Null)) {
            case JsonValue.Map(m) =>
                match (m.get(leafKey)) {
                    case Some(JsonValue.String(s)) => s
                    case _ => ""
                }
            case _ => ""
        }
    }

    // ── §4.2 编排驱动（tasks.md #242）：插件内自驱动整条 COMPOSITION ─────────
    //
    // 迁移动机：LrtCompositionRunner 原在 runtime 侧（src/skill/），与插件是独立进程、无法互调；
    // 现其已迁入插件（lrt_composition_runner.cj），由本方法实例化并驱动 COMPOSITION.yaml
    // 的全部步骤——script 步跑 Python、plugin 步按路由分发到本插件自有处理函数，
    // 从而替换「宿主 Agent 读 COMPOSITION 后逐步走 Python / 调路由」的旧流程。
    //
    // 注意：execute-rounds 这一步仍落到本类的 runTask（验核收敛循环），不形成递归
    // （runTask 不会再调 runComposition）。

    /// 运行整条编排（COMPOSITION.yaml）。由 handleLrtExecute 在异步 spawn 中调用。
    public static func runComposition(
        taskId: String,
        agentId: String,
        goal: String,
        userId: String,
        permArr: ArrayList<JsonValue>,
        maxRounds: Int64,
        traceId: String
    ): JsonValue {
        let skillDir = LrtCompositionRunner.resolveSkillDir()
        // plugin 步分发器：COMPOSITION 的 plugin_route 映射到本插件自有处理函数
        let caller = { route: String, input: HashMap<String, String> =>
            LrtExecutor.dispatchRoute(route, input, taskId, agentId, goal, userId, permArr)
        }
        // builtin_tool 降级后端：经 host.cache 取本任务上一轮好快照顶上（与 lrt_degradation 同源）
        let toolCaller = { name: String, input: HashMap<String, String> =>
            LrtExecutor.builtinToolFallback(name, input, taskId, userId, permArr)
        }
        let runner = LrtCompositionRunner(
            skillDir,
            input: HashMap<String, String>(),
            pluginCaller: Some(caller),
            toolCaller: Some(toolCaller),
            llmCaller: None,
            retryCount: 1
        )
        let result = runner.run(traceId: traceId)
        return LrtExecutor.compositionResultToJson(result)
    }

    /// plugin 步路由分发：把 COMPOSITION 的 plugin_route（HTTP 路径形式）映射到插件处理函数。
    private static func dispatchRoute(
        route: String,
        input: HashMap<String, String>,
        taskId: String,
        agentId: String,
        goal: String,
        userId: String,
        permArr: ArrayList<JsonValue>
    ): String {
        match (route) {
            case "/api/v1/uctoo/long_running_task/lrt-plan" =>
                let g = match (input.get("goal")) { case Some(v) => v; case None => goal }
                return LrtPlanner.plan(g, taskId, userId, permArr).stringify()
            case "/api/v1/uctoo/long_running_task/lrt-execute" =>
                // 回合收敛循环（验核未校验产物 → 通过则完成 / 失败则自进化）
                return LrtExecutor.runTask(taskId, agentId, goal, userId, permArr, LrtConfig.maxRounds()).stringify()
            case "/api/v1/uctoo/long_running_task/lrt-verify" =>
                let apath = match (input.get("artifact_path")) { case Some(v) => v; case None => "" }
                let atype = match (input.get("artifact_type")) { case Some(v) => v; case None => "" }
                let r = LrtVerifier.verify(apath, atype, taskId, agentId, userId, permArr, goal)
                return r.stringify()
            case _ =>
                eprintln("[lrt-executor] dispatchRoute 未知路由 '${route}'，按空产出处理")
                return ""
        }
    }

    /// builtin_tool 降级后端：经 host.cache 取键对应快照。无 ctx / 取不到一律返回空串（降级纪律：不可用就如实失败）。
    private static func builtinToolFallback(name: String, input: HashMap<String, String>, taskId: String, userId: String, permArr: ArrayList<JsonValue>): String {
        match (LrtPersistService.currentCtx()) {
            case None => return ""
            case Some(ctx) =>
                let args = HashMap<String, JsonValue>()
                args["key"] = JsonValue.String("lrt:${taskId}:${name}")
                args["userId"] = JsonValue.String(userId)
                args["permissions"] = JsonValue.from(permArr)
                let res = ctx.invoke("host.cache", "get", JsonValue.from(args))
                return res.stringify()
        }
    }

    /// 把编排结果结构化为 JSON，供 handleLrtExecute 响应与上层上报。
    private static func compositionResultToJson(r: LrtCompositionResult): JsonValue {
        let m = HashMap<String, JsonValue>()
        m["composition"] = JsonValue.from(r.compositionName)
        m["status"] = JsonValue.from(lrtStepStatusToString(r.status))
        m["final_output"] = JsonValue.from(r.finalOutput)
        m["total_duration_ms"] = JsonValue.from(r.totalDurationMs)
        m["cache_hits"] = JsonValue.from(r.cacheHits)
        m["error_message"] = JsonValue.from(r.errorMessage)
        let steps = HashMap<String, JsonValue>()
        for ((k, sr) in r.stepResults) {
            let sm = HashMap<String, JsonValue>()
            sm["status"] = JsonValue.from(lrtStepStatusToString(sr.status))
            sm["output"] = JsonValue.from(sr.output)
            sm["error"] = JsonValue.from(sr.errorMessage)
            sm["duration_ms"] = JsonValue.from(sr.durationMs)
            sm["from_cache"] = JsonValue.from(sr.fromCache)
            steps[k] = JsonValue.from(sm)
        }
        m["steps"] = JsonValue.from(steps)
        return JsonValue.from(m)
    }

    // ── §4.3 子任务派发 / 结果聚合 / 并发控制 ──────────────────────────

    /// 列出某根任务的直接子任务（agent_tasks.parent_task_id = root）。
    private static func childTasks(rootTaskId: String, userId: String, permArr: ArrayList<JsonValue>): Array<JsonValue> {
        let whereClause = "parent_task_id = '${rootTaskId}' AND deleted_at IS NULL"
        return LrtPersistService.queryMany(LrtPersistService.TABLE_AGENT_TASKS, whereClause, userId, permArr, 200)
    }

    /// 派发并执行全部子任务（§4.3）：逐个驱动其收敛循环并回写结果（子任务不再二次规划，避免生成孙任务）。
    /// 子任务在插件进程内由既有 LrtPlanner + LrtExecutor 驱动——不跨进程复用宿主
    /// dag_team_orchestrator 的"子Agent编排"（L3 插件进程拿不到宿主 Agent 对象，
    /// 那是 spec §4.3 原文设想但在本架构下不可达），属如实记录的偏差。
    private static func dispatchSubTasks(
        rootTaskId: String, agentId: String, userId: String,
        permArr: ArrayList<JsonValue>, traceId: String, sessionId: String
    ): Unit {
        let kids = LrtExecutor.childTasks(rootTaskId, userId, permArr)
        for (child in kids) {
            match (child) {
                case JsonValue.Map(row) =>
                    let childId = match (row.get("id")) { case Some(JsonValue.String(s)) => s; case _ => "" }
                    if (childId.isEmpty()) {
                        continue
                    }
                    let subGoal = LrtExecutor.extractPayloadString(child, "sub_goal")
                    LrtEventEmitter.subtaskDispatched(
                        rootTaskId, sessionId, agentId, childId, rootTaskId, subGoal,
                        ArrayList<JsonValue>(), traceId
                    )
                    // 递归保护：子任务以 isRoot=false 驱动，内部不再派发
                    let r = LrtExecutor.runTask(childId, agentId, subGoal, userId, permArr, LrtConfig.maxRounds(), isRoot: false)
                    let outcome = LrtExecutor.extractString(r, "outcome")
                    let patch = HashMap<String, JsonValue>()
                    patch["execution_outcome"] = JsonValue.String(outcome)
                    patch["execution_round"] = LrtExecutor.extractJsonNumber(r, "round")
                    LrtPersistService.patchTaskPayload(childId, patch, userId, permArr)
                    LrtEventEmitter.subtaskCompleted(rootTaskId, sessionId, agentId, childId, 1, outcome, traceId)
                case _ => ()
            }
        }
    }

    /// 聚合子任务结果进根任务 payload（§4.3）：供进度查询与上层决策消费。
    private static func aggregateSubTaskResults(rootTaskId: String, userId: String, permArr: ArrayList<JsonValue>): Unit {
        let kids = LrtExecutor.childTasks(rootTaskId, userId, permArr)
        let summary = ArrayList<JsonValue>()
        var done = Int64(0)
        for (child in kids) {
            match (child) {
                case JsonValue.Map(row) =>
                    let childId = match (row.get("id")) { case Some(JsonValue.String(s)) => s; case _ => "" }
                    let status = match (row.get("status")) { case Some(JsonValue.Number(n)) => Int64(n); case _ => 0 }
                    let subGoal = LrtExecutor.extractPayloadString(child, "sub_goal")
                    let outcome = LrtExecutor.extractPayloadString(child, "execution_outcome")
                    if (outcome == "completed") {
                        done = done + 1
                    }
                    let item = HashMap<String, JsonValue>()
                    item["task_id"] = JsonValue.String(childId)
                    item["sub_goal"] = JsonValue.String(subGoal)
                    item["status"] = JsonValue.Number(Float64(status))
                    item["execution_outcome"] = JsonValue.String(outcome)
                    summary.add(JsonValue.from(item))
                case _ => ()
            }
        }
        let patch = HashMap<String, JsonValue>()
        patch["sub_task_count"] = JsonValue.Number(Float64(Int64(summary.size)))
        patch["sub_task_done"] = JsonValue.Number(Float64(done))
        patch["sub_task_summary"] = JsonValue.from(summary)
        LrtPersistService.patchTaskPayload(rootTaskId, patch, userId, permArr)
    }

    /**
     * 用已跑轮次的实测均值估算剩余时间（spec 5.4.1 规则 3）。
     *
     * 返回 `?Int64`：`None` = "无从估计"（尚无完整轮次 / 已无剩余轮次 / 均值为 0）。
     * 之所以不返回 0：宿主侧 `progress_update` 的 `estimatedRemaining` 会把 0 原样给前端，
     * 前端读成"马上完成"——这是比"未知"更糟的误导。
     *
     * @param totalDurationMs 已完成轮次的累计耗时（ms）
     * @param completedRounds 已完成轮次数（分母）
     * @param remainingRounds 剩余轮次数（totalSteps - round）
     */
    private static func estimateRemainingMs(
        totalDurationMs: Int64,
        completedRounds: Int64,
        remainingRounds: Int64
    ): ?Int64 {
        if (completedRounds <= 0 || remainingRounds <= 0) {
            return None<Int64>
        }
        let avg = totalDurationMs / completedRounds
        if (avg <= 0) {
            return None<Int64>
        }
        return Some(avg * remainingRounds)
    }

    /// concurrentable 读取：现由 plugin.yaml 的 `config.concurrentable`（默认 **false**）决定，
    /// 不再读 crontab 列 —— 后者在参数/环境异常时无从配置，且默认 true 会重叠触发。
    /// 对应 review 偏差 #2「concurrentable 改为可配」。
    private static func isConcurrentable(): Bool {
        LrtConfig.concurrentable()
    }

    /// 进程内并发咨询锁：写入 payload.executing + payload.executing_since（epoch 毫秒）。
    /// executing_since 供 isExecutingLockStale 判定陈旧锁，是「异常退出后能自愈」的关键。
    private static func setExecutingLock(taskId: String, value: Bool, userId: String, permArr: ArrayList<JsonValue>): Unit {
        let patch = HashMap<String, JsonValue>()
        patch["executing"] = JsonValue.Boolean(value)
        patch["executing_since"] = JsonValue.Number(Float64((DateTime.now() - DateTime.UnixEpoch).toMilliseconds()))
        LrtPersistService.patchTaskPayload(taskId, patch, userId, permArr)
    }

    /// 陈旧并发锁判定：payload.executing=true 且 executing_since 距今超过 maxTaskDurationMs，
    /// 视为上一轮异常退出遗留（进程/宿主崩溃时锁不会被清）→ 允许本次接管。
    /// 缺 executing_since（历史数据）一律视为**不陈旧**，保持原有"禁止重叠"语义。
    private static func isExecutingLockStale(row: JsonValue): Bool {
        let sinceMs = LrtExecutor.extractPayloadInt(row, "executing_since")
        if (sinceMs <= 0) {
            return false
        }
        let nowMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        (nowMs - sinceMs) > LrtConfig.maxTaskDurationMs()
    }

    /// 从 payload 里读整数（缺失 / 非数字返回 0）
    private static func extractPayloadInt(row: JsonValue, key: String): Int64 {
        let payloadVal = LrtExecutor.payloadOf(row)
        match (payloadVal) {
            case JsonValue.Map(p) =>
                match (p.get(key)) {
                    case Some(JsonValue.Number(n)) => return Int64(n)
                    case _ => ()
                }
            case _ => ()
        }
        0
    }

    private static func extractPayloadBool(row: JsonValue, key: String): Bool {
        let payloadVal = LrtExecutor.payloadOf(row)
        match (payloadVal) {
            case JsonValue.Map(p) =>
                match (p.get(key)) {
                    case Some(JsonValue.Boolean(b)) => return b
                    case _ => ()
                }
            case _ => ()
        }
        false
    }

    private static func extractJsonNumber(json: JsonValue, key: String): JsonValue {
        match (json.get(key, JsonValue.Null)) {
            case JsonValue.Number(n) => return JsonValue.Number(n)
            case _ => return JsonValue.Null
        }
    }
}
