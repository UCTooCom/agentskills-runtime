/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonNull, JsonArray}
import magic.log.LogUtils

public enum RollbackStrategy {
    | FullRollback | PartialRollback | MarkFailed
}

public class RollbackPlan {
    public var planId: String = ""
    public var strategy: RollbackStrategy = RollbackStrategy.FullRollback
    public var sideEffects: ArrayList<SideEffectRecord> = ArrayList<SideEffectRecord>()
    public var rollbackActions: ArrayList<String> = ArrayList<String>()
    public var estimatedImpact: String = ""

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("plan_id", JsonString(this.planId))
        map.add("strategy", JsonString(rollbackStrategyToString(this.strategy)))
        var effectsArr = ArrayList<JsonValue>()
        for (e in this.sideEffects) {
            effectsArr.add(e.toJsonValue())
        }
        map.add("side_effects", JsonArray(effectsArr))
        var actionsArr = ArrayList<JsonValue>()
        for (a in this.rollbackActions) {
            actionsArr.add(JsonString(a))
        }
        map.add("rollback_actions", JsonArray(actionsArr))
        map.add("estimated_impact", JsonString(this.estimatedImpact))
        JsonObject(map)
    }

    public static func rollbackStrategyToString(s: RollbackStrategy): String {
        match (s) {
            case RollbackStrategy.FullRollback => "full_rollback"
            case RollbackStrategy.PartialRollback => "partial_rollback"
            case RollbackStrategy.MarkFailed => "mark_failed"
        }
    }
}

public class RollbackResult {
    public var planId: String = ""
    public var strategy: RollbackStrategy = RollbackStrategy.FullRollback
    public var totalSideEffects: Int64 = 0
    public var rolledBack: Int64 = 0
    public var failed: Int64 = 0
    public var skipped: Int64 = 0
    public var rollbackEvidences: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("plan_id", JsonString(this.planId))
        map.add("strategy", JsonString(RollbackPlan.rollbackStrategyToString(this.strategy)))
        map.add("total_side_effects", JsonInt(this.totalSideEffects))
        map.add("rolled_back", JsonInt(this.rolledBack))
        map.add("failed", JsonInt(this.failed))
        map.add("skipped", JsonInt(this.skipped))
        var evidencesArr = ArrayList<JsonValue>()
        for (e in this.rollbackEvidences) {
            evidencesArr.add(JsonString(e))
        }
        map.add("rollback_evidences", JsonArray(evidencesArr))
        JsonObject(map)
    }
}

public class RollbackManager {
    private let _sideEffectTracker: SideEffectTracker
    private let _evidenceRecorder: ExecutionEvidenceRecorder
    private let _rollbackExecutor: (SideEffectRecord) -> Bool
    private let _recordEvidence: (String, String, String, Option<JsonValue>) -> String

    private var _lastRollbackResult: Option<RollbackResult>

    public init(sideEffectTracker!: SideEffectTracker, evidenceRecorder!: ExecutionEvidenceRecorder, rollbackExecutor!: (SideEffectRecord) -> Bool, recordEvidence!: (String, String, String, Option<JsonValue>) -> String) {
        _sideEffectTracker = sideEffectTracker
        _evidenceRecorder = evidenceRecorder
        _rollbackExecutor = rollbackExecutor
        _recordEvidence = recordEvidence
        _lastRollbackResult = None<RollbackResult>
    }

    public func createRollbackPlan(planId: String, strategy: RollbackStrategy): Option<RollbackPlan> {
        LogUtils.info("[RollbackManager] Creating rollback plan: planId=${planId}, strategy=${RollbackPlan.rollbackStrategyToString(strategy)}")

        let allEffects = _sideEffectTracker.getAllEffects()
        if (allEffects.size == 0) {
            LogUtils.info("[RollbackManager] No side effects found for rollback")
            return None<RollbackPlan>
        }

        let plan = RollbackPlan()
        plan.planId = planId
        plan.strategy = strategy

        match (strategy) {
            case RollbackStrategy.FullRollback =>
                for (i in 0..allEffects.size) {
                    let idx = allEffects.size - 1 - i
                    let effect = allEffects[idx]
                    plan.sideEffects.add(effect)
                    if (effect.isReversible) {
                        if (let Some(action) <- effect.rollbackAction) {
                            plan.rollbackActions.add(action)
                        }
                    }
                }
                plan.estimatedImpact = "All ${allEffects.size.toString()} side effects will be rolled back in reverse order"
            case RollbackStrategy.PartialRollback =>
                for (i in 0..allEffects.size) {
                    let idx = allEffects.size - 1 - i
                    let effect = allEffects[idx]
                    if (effect.isReversible) {
                        plan.sideEffects.add(effect)
                        if (let Some(action) <- effect.rollbackAction) {
                            plan.rollbackActions.add(action)
                        }
                    }
                }
                plan.estimatedImpact = "Only reversible side effects (${plan.sideEffects.size.toString()}) will be rolled back"
            case RollbackStrategy.MarkFailed =>
                plan.estimatedImpact = "No rollback will be performed, steps marked as failed"
        }


        LogUtils.info("[RollbackManager] Rollback plan created: ${plan.sideEffects.size.toString()} effects, ${plan.rollbackActions.size.toString()} actions")
        return Some(plan)
    }

    public func executeRollback(planId: String, strategy: RollbackStrategy): Option<RollbackResult> {
        LogUtils.info("[RollbackManager] Executing rollback: planId=${planId}")

        let planOpt = createRollbackPlan(planId, strategy)
        if (planOpt.isNone()) {
            LogUtils.error("[RollbackManager] Failed to create rollback plan")
            return None<RollbackResult>
        }

        let plan = planOpt.getOrThrow()
        let result = RollbackResult()
        result.planId = planId
        result.strategy = strategy
        result.totalSideEffects = Int64(plan.sideEffects.size)

        match (strategy) {
            case RollbackStrategy.MarkFailed =>
                result.skipped = result.totalSideEffects
                LogUtils.info("[RollbackManager] MarkFailed strategy: skipping rollback")
                return Some(result)
            case _ => ()
        }

        for (effect in plan.sideEffects) {
            if (!effect.isReversible) {
                result.skipped = result.skipped + 1
                continue
            }

            let success = _rollbackExecutor(effect)
            if (success) {
                result.rolledBack = result.rolledBack + 1
                let evidenceId = _recordEvidence(planId, "rollback", "Rolled back: ${effect.description}", Some(effect.toJsonValue()))
                result.rollbackEvidences.add(evidenceId)
                LogUtils.info("[RollbackManager] Rolled back: ${effect.description}")
            } else {
                result.failed = result.failed + 1
                LogUtils.error("[RollbackManager] Rollback failed: ${effect.description}")
            }
        }

        LogUtils.info("[RollbackManager] Rollback complete: rolledBack=${result.rolledBack}, failed=${result.failed}, skipped=${result.skipped}")
        _lastRollbackResult = Some(result)
        return Some(result)
    }

    public func rollbackSideEffect(effect: SideEffectRecord): Bool {
        if (!effect.isReversible) {
            LogUtils.info("[RollbackManager] Side effect not reversible: ${effect.description}")
            return false
        }
        _rollbackExecutor(effect)
    }

    public func getRollbackStatus(planId: String): Option<RollbackResult> {
        if (let Some(result) <- _lastRollbackResult) {
            if (result.planId == planId) {
                return Some(result)
            }
        }
        None<RollbackResult>
    }
}