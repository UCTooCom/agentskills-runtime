/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_executor

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import magic.agent_group.{ManagerGroup, TeamConfig, TeamMessenger, TeamMessage, MessageType, AgentRole}
import magic.interaction.{ExecutionEvidenceRecorder, SideEffectTracker, AuditHashChain, EvidenceType, ApprovalManager, ApprovalConfig, ApprovalRequest, ApprovalResult, ApprovalStatus, ApprovalType, RollbackManager, RollbackStrategy, RollbackResult, CheckpointManager, CheckpointData}
import magic.skill.CompositeSkillToolManager
import magic.context_verify.{ContextPasser, IncrementalResultPusher, AgentContext}
import magic.log.LogUtils

public class DagTeamOrchestrator {
    private let _scheduler: DagScheduler
    private let _evidenceRecorder: ExecutionEvidenceRecorder
    private let _sideEffectTracker: SideEffectTracker
    private let _hashChain: AuditHashChain
    private var _contextPasser: Option<ContextPasser>
    private var _incrementalPusher: Option<IncrementalResultPusher>
    private var _approvalManager: Option<ApprovalManager>
    private var _rollbackManager: Option<RollbackManager>
    private var _checkpointManager: Option<CheckpointManager>

    public init(skillManager!: CompositeSkillToolManager) {
        _scheduler = DagScheduler(skillManager: skillManager)
        _evidenceRecorder = ExecutionEvidenceRecorder()
        _sideEffectTracker = SideEffectTracker()
        _hashChain = AuditHashChain()
        _contextPasser = None<ContextPasser>
        _incrementalPusher = None<IncrementalResultPusher>
        _approvalManager = None<ApprovalManager>
        _rollbackManager = None<RollbackManager>
        _checkpointManager = None<CheckpointManager>
    }

    public func setContextPasser(contextPasser!: ContextPasser): Unit {
        _contextPasser = Some(contextPasser)
    }

    public func setIncrementalPusher(incrementalPusher!: IncrementalResultPusher): Unit {
        _incrementalPusher = Some(incrementalPusher)
    }

    public func setApprovalManager(approvalManager!: ApprovalManager): Unit {
        _approvalManager = Some(approvalManager)
    }

    public func setRollbackManager(rollbackManager!: RollbackManager): Unit {
        _rollbackManager = Some(rollbackManager)
    }

    public func setCheckpointManager(checkpointManager!: CheckpointManager): Unit {
        _checkpointManager = Some(checkpointManager)
    }

    public func orchestrateWithTeam(config: DagConfig, team: ManagerGroup, input: JsonValue, sessionId: Option<String>): Option<DagScheduleResult> {
        let dagSessionId = "dag_${config.name}_${team.getConfig().name}"

        if (let Some(cpMgr) <- _checkpointManager) {
            if (cpMgr.recoverFromCheckpoint(dagSessionId)) {
                let completedSteps = cpMgr.getCompletedSteps(dagSessionId)
                if (completedSteps.size > 0) {
                    LogUtils.info("[DagTeamOrchestrator] Recovered from checkpoint: ${completedSteps.size.toString()} steps already completed")
                }
            }
        }

        if (let Some(apMgr) <- _approvalManager) {
            if (apMgr.checkApprovalNeeded(config.name, Some(config.toJsonValue()))) {
                let request = ApprovalRequest()
                request.agentId = "DagTeamOrchestrator"
                request.taskId = dagSessionId
                request.approvalType = ApprovalType.HighRiskOperation
                request.content = "DAG orchestration: ${config.name}"
                let approvalOpt = apMgr.requestApproval(request)
                if (approvalOpt.isSome()) {
                    let approval = approvalOpt.getOrThrow()
                    if (isSameApprovalStatus(approval.status, ApprovalStatus.Rejected) || isSameApprovalStatus(approval.status, ApprovalStatus.Timeout)) {
                        LogUtils.info("[DagTeamOrchestrator] Approval rejected/timeout, aborting orchestration")
                        return None<DagScheduleResult>
                    }
                    if (isSameApprovalStatus(approval.status, ApprovalStatus.Pending)) {
                        LogUtils.info("[DagTeamOrchestrator] Approval pending, proceeding with orchestration (async approval)")
                    }
                }
            }
        }

        let evidenceId = _evidenceRecorder.recordStart(
            dagSessionId,
            "DagTeamOrchestrator",
            config.name,
            EvidenceType.AgentExecution,
            Some(input)
        )

        _hashChain.append(evidenceId, config.toJsonValue().toString())

        if (let Some(cp) <- _contextPasser) {
            let rootContext = cp.createContext(config.name, input, HashMap<String, String>())
            cp.broadcastContext("DagTeamOrchestrator", AgentRole.Manager, rootContext)
            LogUtils.info("[DagTeamOrchestrator] Broadcast root context to team: ${team.getConfig().name}")
        }

        let result = _scheduler.schedule(config, input)

        if (let Some(scheduleResult) <- result) {
            let teamMessage = buildTeamMessage(scheduleResult)
            team.getMessenger().broadcast("DagTeamOrchestrator", AgentRole.Manager, teamMessage)
            LogUtils.info("[DagTeamOrchestrator] Broadcast schedule result to team: ${team.getConfig().name}")

            _evidenceRecorder.recordEnd(evidenceId, Some(scheduleResult.toJsonValue()))
            _hashChain.append("${evidenceId}_end", scheduleResult.toJsonValue().toString())

            if (let Some(pusher) <- _incrementalPusher) {
                if (let Some(sid) <- sessionId) {
                    for ((stepName, stepResult) in scheduleResult.stepResults) {
                        pusher.pushIncrementalResult(sid, stepName, StepResult.dagStepStatusToString(stepResult.status), stepResult.output, stepResult.durationMs)
                    }
                }
            }

            if (let Some(cpMgr) <- _checkpointManager) {
                let completedStepNames = ArrayList<String>()
                let stepOutputMap = HashMap<String, JsonValue>()
                for ((stepName, stepResult) in scheduleResult.stepResults) {
                    if (isSameDagStepStatus(stepResult.status, DagStepStatus.Completed)) {
                        completedStepNames.add(stepName)
                    }
                    if (stepResult.output.isSome()) {
                        stepOutputMap.add(stepName, stepResult.output.getOrThrow())
                    }
                }
                cpMgr.saveCheckpoint(dagSessionId, completedStepNames, stepOutputMap)
            }

            if (scheduleResult.failedSteps > 0) {
                if (let Some(rbMgr) <- _rollbackManager) {
                    LogUtils.info("[DagTeamOrchestrator] ${scheduleResult.failedSteps.toString()} steps failed, initiating rollback")
                    rbMgr.executeRollback(dagSessionId, RollbackStrategy.PartialRollback)
                }
            }
        } else {
            _evidenceRecorder.recordError(evidenceId, "DAG scheduling failed")
        }

        return result
    }

    public func dispatchStepToLeader(step: StepConfig, team: ManagerGroup, input: JsonValue, sessionId: Option<String>): StepResult {
        let stepSessionId = "step_${step.name}"

        if (let Some(apMgr) <- _approvalManager) {
            if (apMgr.checkApprovalNeeded(step.name, Some(step.toJsonValue()))) {
                let request = ApprovalRequest()
                request.agentId = "DagTeamOrchestrator"
                request.taskId = stepSessionId
                request.approvalType = ApprovalType.HighRiskOperation
                request.content = "Step execution: ${step.name}"
                let approvalOpt = apMgr.requestApproval(request)
                if (approvalOpt.isSome()) {
                    let approval = approvalOpt.getOrThrow()
                    if (isSameApprovalStatus(approval.status, ApprovalStatus.Rejected) || isSameApprovalStatus(approval.status, ApprovalStatus.Timeout)) {
                        LogUtils.info("[DagTeamOrchestrator] Step approval rejected/timeout: ${step.name}")
                        let skippedResult = StepResult()
                        skippedResult.stepName = step.name
                        skippedResult.status = DagStepStatus.Skipped
                        skippedResult.errorMessage = "Approval rejected"
                        skippedResult.startedAt = Some(DateTime.now())
                        skippedResult.completedAt = Some(DateTime.now())
                        return skippedResult
                    }
                }
            }
        }

        let evidenceId = _evidenceRecorder.recordStart(
            stepSessionId,
            "DagTeamOrchestrator",
            step.name,
            EvidenceType.SkillExecution,
            Some(input)
        )

        let result = StepResult()
        result.stepName = step.name
        result.startedAt = Some(DateTime.now())

        let stepStartTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()

        if (team.getLeaders().size > 0) {
            let leader = team.getLeaders()[0]

            if (let Some(cp) <- _contextPasser) {
                let stepContext = cp.createContext(step.name, input, HashMap<String, String>())
                cp.passContext("DagTeamOrchestrator", leader.name, stepContext)
                LogUtils.info("[DagTeamOrchestrator] Passed context to leader: ${leader.name}")
            }

            try {
                let prompt = buildStepPrompt(step, input)
                let msg = TeamMessage()
                msg.messageType = MessageType.TASK_ASSIGN
                msg.payload = prompt
                team.getMessenger().send("DagTeamOrchestrator", leader.name, msg)

                result.status = DagStepStatus.Completed
                result.output = Some(JsonString(prompt))
                _evidenceRecorder.recordEnd(evidenceId, Some(JsonString(prompt)))
            } catch (ex: Exception) {
                result.status = DagStepStatus.Failed
                result.errorMessage = ex.message
                _evidenceRecorder.recordError(evidenceId, ex.message)
            }
        } else {
            result.status = DagStepStatus.Failed
            result.errorMessage = "No leaders available in team"
            _evidenceRecorder.recordError(evidenceId, "No leaders available")
        }

        result.durationMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - stepStartTime
        result.completedAt = Some(DateTime.now())

        _sideEffectTracker.trackApiCall(evidenceId, "dag_step:${step.name}", Some(input), result.output)
        _hashChain.append("${evidenceId}_step", result.toJsonValue().toString())

        if (let Some(pusher) <- _incrementalPusher) {
            if (let Some(sid) <- sessionId) {
                pusher.pushIncrementalResult(sid, step.name, StepResult.dagStepStatusToString(result.status), result.output, result.durationMs)
            }
        }

        return result
    }

    public func getEvidenceRecorder(): ExecutionEvidenceRecorder {
        return _evidenceRecorder
    }

    public func getSideEffectTracker(): SideEffectTracker {
        return _sideEffectTracker
    }

    public func getHashChain(): AuditHashChain {
        return _hashChain
    }

    public func getScheduler(): DagScheduler {
        return _scheduler
    }

    public func verifySessionIntegrity(sessionId: String): Option<Bool> {
        return _evidenceRecorder.verifyIntegrity(sessionId)
    }

    private func buildTeamMessage(scheduleResult: DagScheduleResult): TeamMessage {
        var content = "DAG Schedule: ${scheduleResult.planName}\n"
        content = content + "Status: ${StepResult.dagPlanStatusToString(scheduleResult.status)}\n"
        content = content + "Completed: ${scheduleResult.completedSteps.toString()}, Failed: ${scheduleResult.failedSteps.toString()}\n"

        for ((stepName, stepResult) in scheduleResult.stepResults) {
            content = content + "  - ${stepName}: ${StepResult.dagStepStatusToString(stepResult.status)}\n"
        }

        let message = TeamMessage()
        message.messageType = MessageType.STATUS_UPDATE
        message.payload = content

        return message
    }

    private func buildStepPrompt(step: StepConfig, input: JsonValue): String {
        var prompt = "Execute step '${step.name}' using ${step.targetRef}\n"
        if (step.condition.isSome()) {
            prompt = prompt + "Condition: ${step.condition.getOrThrow()}\n"
        }
        prompt = prompt + "Input: ${input.toString()}"
        return prompt
    }

    public static func isSameApprovalStatus(a: ApprovalStatus, b: ApprovalStatus): Bool {
        match (a) {
            case ApprovalStatus.Pending => match (b) { case ApprovalStatus.Pending => true case _ => false }
            case ApprovalStatus.Approved => match (b) { case ApprovalStatus.Approved => true case _ => false }
            case ApprovalStatus.Rejected => match (b) { case ApprovalStatus.Rejected => true case _ => false }
            case ApprovalStatus.Timeout => match (b) { case ApprovalStatus.Timeout => true case _ => false }
            case ApprovalStatus.Cancelled => match (b) { case ApprovalStatus.Cancelled => true case _ => false }
        }
    }

    public static func isSameDagStepStatus(a: DagStepStatus, b: DagStepStatus): Bool {
        match (a) {
            case DagStepStatus.Pending => match (b) { case DagStepStatus.Pending => true case _ => false }
            case DagStepStatus.Ready => match (b) { case DagStepStatus.Ready => true case _ => false }
            case DagStepStatus.Running => match (b) { case DagStepStatus.Running => true case _ => false }
            case DagStepStatus.Completed => match (b) { case DagStepStatus.Completed => true case _ => false }
            case DagStepStatus.Failed => match (b) { case DagStepStatus.Failed => true case _ => false }
            case DagStepStatus.Skipped => match (b) { case DagStepStatus.Skipped => true case _ => false }
        }
    }
}
