/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.tool.{
    SubAgentDispatcher, SubAgentDispatchRequest, SubAgentDispatchResult,
    AgentAsTool, SubAgentMode, SubAgentContractVerifier, ContractVerdict
}
import magic.app.services.uctoo.{AgentsService, SubAgentInvocationsService}
import magic.app.models.uctoo.{AgentsPO, SubAgentInvocationsPO}
import magic.agent.base.BaseAgent
import magic.core.tool.ToolResponse
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import magic.log.LogUtils

/**
 * 子 agent 真派生派发实现（宿主侧）。
 *
 * 经 DI 注入 SubAgentTool 的函数槽；magic.tool 不反向依赖本包，避免包循环依赖（项目铁律）。
 *
 * 链路（design §2.7.3 / tasks.md T-15）：
 *   解析 agents 表（agent_id 优先，否则 skill_name + name）
 *   → AgentRuntimeBridge.loadFromDatabase 造 Agent
 *   → AgentAsTool(Isolated).invoke
 *   → 派单前后写 sub_agent_invocations（beginInvocation / finishInvocation）
 *
 * 子 agent 定义缺失时立即失败并提示（T-15 红线：禁止静默降级为"主 agent 自己写"）。
 */
public class SubAgentDispatchServiceImpl <: SubAgentDispatcher {
    private let bridge: AgentRuntimeBridge
    private let agentsService: AgentsService
    private let invocationsService: SubAgentInvocationsService

    public init(bridge: AgentRuntimeBridge) {
        this.bridge = bridge
        this.agentsService = AgentsService()
        this.invocationsService = SubAgentInvocationsService()
    }

    public func dispatch(req: SubAgentDispatchRequest): SubAgentDispatchResult {
        let startMs = nowMillis()
        let resolve = resolveAgent(req)
        match (resolve) {
            case Some(resolved) =>
                // BaseAgent/Agent 接口上没有 id 成员（见 magic.core.agent.Agent），
                // 子 agent id 只能来自解析路径本身；capabilities 同理，只能由查表结果带出
                let (agentId, agent, capabilities) = resolved
                let invocationId = beginInvocation(req, agentId)
                try {
                    let tool = AgentAsTool(agent, mode: SubAgentMode.Isolated)
                    var output = runOnce(tool, req.question)
                    var durationMs = nowMillis() - startMs
                    var verdict = SubAgentContractVerifier.verify(output, capabilities)
                    var attempt: Int32 = 1

                    // T-21：契约不过 → 携结构化错误**重派一次**；仍不过 → 转人工闸口（禁无限重试）
                    if (!verdict.passed) {
                        LogUtils.warn("[SubAgentDispatch] 契约校验未过，重派一次: ${verdict.errors}")
                        output = runOnce(tool, buildRetryQuestion(req.question, verdict))
                        durationMs = nowMillis() - startMs
                        verdict = SubAgentContractVerifier.verify(output, capabilities)
                        attempt = 2
                    }

                    if (verdict.passed) {
                        finishInvocation(invocationId, output, durationMs, true, "")
                        recordVerification(invocationId, verdict, attempt)
                        recordCost(invocationId, "")
                        return SubAgentDispatchResult(true, output, "", durationMs)
                    }

                    let err = "contract verification failed (attempt=${attempt}, contract=${verdict.contractType}): ${verdict.errors} -> review_required"
                    LogUtils.error("[SubAgentDispatch] ${err}")
                    finishInvocation(invocationId, output, durationMs, false, err)
                    recordVerification(invocationId, verdict, attempt)
                    recordCost(invocationId, err)
                    return SubAgentDispatchResult(false, output, err, durationMs)
                } catch (ex: Exception) {
                    let durationMs = nowMillis() - startMs
                    let err = "sub-agent execution failed: ${ex.message}"
                    finishInvocation(invocationId, "", durationMs, false, ex.message)
                    recordCost(invocationId, err)
                    return SubAgentDispatchResult(false, "", err, durationMs)
                }
            case None =>
                let msg = "sub-agent not found (name='${req.agentName}', skill='${req.skillName}', id='${req.agentId}'): not registered in agents table"
                LogUtils.error("[SubAgentDispatch] ${msg}")
                return SubAgentDispatchResult(false, "", msg, nowMillis() - startMs)
        }
    }

    /**
     * 返回 (子 agent 的 agents 表 id, Agent 实例, capabilities 文本)。
     *
     * BaseAgent 上既无 id 也无 capabilities（见 magic.core.agent.Agent 接口），
     * 两者都只能从**解析路径**上带出——显式指定 id 时补查一次表，按名查表时直接取 po。
     * capabilities 是 T-21 契约规则的来源，取不到时留空串（校验器会降级为 contract_absent）。
     */
    private func resolveAgent(req: SubAgentDispatchRequest): Option<(String, BaseAgent, String)> {
        try {
            if (!req.agentId.isEmpty()) {
                let r = bridge.loadFromDatabase(req.agentId, userId: req.userId)
                if (r.success) {
                    if (let Some(a) <- r.data) {
                        return (req.agentId, a, capabilitiesById(req.agentId))
                    }
                }
                return None
            }
            // T-20（REQ-SDD-011）：按 name 解析时 **bundledAgents 优先** —— 同名记录中先取
            // 归属当前技能（skill_name 命中）的那条，未命中再回退全局子 agent，最后才用首条。
            // 与 T-19 加载期探测同一批声明文件（同步落库时已按路径写入 skill_name）。
            let filter = "{\"name\":{\"equals\":\"${req.agentName}\"}}"
            let (list, _) = agentsService.getListWithFilter(1, 50, "", filter)
            if (let Some(po) <- pickBundledFirst(list, req.skillName)) {
                let r = bridge.loadFromDatabase(po.id, userId: req.userId)
                if (r.success) {
                    if (let Some(a) <- r.data) {
                        return (po.id, a, capabilitiesOfPo(po))
                    }
                }
            }
            return None
        } catch (ex: Exception) {
            LogUtils.error("[SubAgentDispatch] resolveAgent failed: ${ex.message}")
            return None
        }
    }

    /// 按 id 补查 capabilities（显式指定 agent 的场景没有现成的 po）
    private func capabilitiesById(agentId: String): String {
        try {
            let r = agentsService.getById(agentId)
            if (r.success) {
                if (let Some(po) <- r.data) {
                    return capabilitiesOfPo(po)
                }
            }
        } catch (ex: Exception) {
            LogUtils.warn("[SubAgentDispatch] 读取 capabilities 失败（按无契约处理）: ${ex.message}")
        }
        return ""
    }

    private func capabilitiesOfPo(po: AgentsPO): String {
        match (po.capabilities) {
            case Some(c) => c
            case None => ""
        }
    }

    /**
     * 同名 agent 多条时按 T-20 顺序挑选：① 归属当前技能的（bundledAgents 语义）→
     * ② 未归属任何技能的全局子 agent → ③ 首条。空列表返回 None。
     */
    private func pickBundledFirst(list: ArrayList<AgentsPO>, skillName: String): Option<AgentsPO> {
        if (list.size == 0) {
            return None<AgentsPO>
        }
        if (!skillName.isEmpty()) {
            for (po in list) {
                if (let Some(sn) <- po.skillName) {
                    if (sn == skillName) {
                        return Some(po)
                    }
                }
            }
        }
        for (po in list) {
            if (po.skillName.isNone()) {
                return Some(po)
            }
        }
        return Some(list[0])
    }

    private func beginInvocation(req: SubAgentDispatchRequest, agentId: String): String {
        let skillNameOpt = if (req.skillName.isEmpty()) { None<String> } else { Some(req.skillName) }
        let parentTaskOpt = if (req.parentTaskId.isEmpty()) { None<String> } else { Some(req.parentTaskId) }
        let taskOpt = if (req.taskId.isEmpty()) { None<String> } else { Some(req.taskId) }
        let stageOpt = if (req.agentName.isEmpty()) { None<String> } else { Some(req.agentName) }
        // 注：beginInvocation 形参未声明为命名参数（无 !），此处必须按位置传参，
        // 顺序固定为 agentId / skillName / stage / mode / inputJson / parentTaskId / taskId / creatorId
        let r = invocationsService.beginInvocation(
            agentId,
            skillNameOpt,
            stageOpt,
            "isolated",
            buildInputJson(req),
            parentTaskOpt,
            taskOpt,
            req.userId
        )
        if (r.success) {
            if (let Some(d) <- r.data) {
                return d.id
            }
        }
        return ""
    }

    private func finishInvocation(invocationId: String, output: String, durationMs: Int64, success: Bool, error: String): Unit {
        if (invocationId.isEmpty()) {
            return
        }
        let outputOpt = if (output.isEmpty()) { None<String> } else { Some(output) }
        let errorOpt = if (error.isEmpty()) { None<String> } else { Some(error) }
        let status = if (success) { "completed" } else { "failed" }
        invocationsService.finishInvocation(invocationId, outputOpt, Some(durationMs), status, errorOpt)
    }

    /// 跑一次子 agent（Isolated：全部上下文靠 question 这一个字段传进去）
    private func runOnce(tool: AgentAsTool, question: String): String {
        let args = HashMap<String, JsonValue>()
        args.add("question", JsonString(question))
        let resp = tool.invoke(args)
        resp.content
    }

    /**
     * 重派的 question：原问题 + 上次校验失败的结构化错误。
     *
     * 关键是把**错在哪**讲清楚（缺哪个章节、哪个占位符没填），否则第二次大概率
     * 原样再错一遍，重派就退化成纯浪费一次调用。
     */
    private func buildRetryQuestion(question: String, verdict: ContractVerdict): String {
        question
            + "\n\n[上一轮回传未通过契约校验，请修正后重出完整内容，不要只回补丁]\n"
            + "未通过项：${verdict.errors}\n"
            + "契约类型：${verdict.contractType}\n"
    }

    /// T-21：回写契约校验结论（contract_type / verify_passed / verify_errors / attempt）
    private func recordVerification(invocationId: String, verdict: ContractVerdict, attempt: Int32): Unit {
        if (invocationId.isEmpty()) {
            return
        }
        invocationsService.recordVerification(
            invocationId, verdict.contractType, verdict.passed, verdict.errors, attempt
        )
    }

    /**
     * T-22：回写本次派单的 token 成本。
     *
     * 现状：`AgentAsTool.invoke` 返回的 ToolResponse 只带 content，**不暴露 ChatUsage**，
     * 拿不到模型 usage。按账本口径**一律记 0 并在 error_message 追加 token_missing**，
     * **禁止用字符数折算冒充实测**——估算值混进成本账本会让横向对比全废。
     * 待 AgentAsTool 暴露 usage 后，此处换成真实值即可，调用方无需改动。
     */
    private func recordCost(invocationId: String, errorMessage: String): Unit {
        if (invocationId.isEmpty()) {
            return
        }
        let marked = if (errorMessage.isEmpty()) { "token_missing" } else { "${errorMessage} | token_missing" }
        invocationsService.recordCost(
            invocationId, 0, 0, 0, Some<String>(marked)
        )
    }

    private func buildInputJson(req: SubAgentDispatchRequest): String {
        let o = JsonObject()
        o.put("question", JsonString(req.question))
        if (!req.inputFiles.isEmpty()) {
            o.put("input_files", JsonString(req.inputFiles))
        }
        if (!req.outputDir.isEmpty()) {
            o.put("output_dir", JsonString(req.outputDir))
        }
        if (!req.languageContext.isEmpty()) {
            o.put("language_context", JsonString(req.languageContext))
        }
        return o.toJsonString()
    }

    private func nowMillis(): Int64 {
        (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }
}
