/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonNull, JsonArray}
import magic.log.LogUtils

public class CheckpointData {
    public var planId: String = ""
    public var completedSteps: ArrayList<String> = ArrayList<String>()
    public var stepOutputs: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    public var sideEffectIds: HashMap<String, ArrayList<String>> = HashMap<String, ArrayList<String>>()
    public var savedAt: DateTime = DateTime.now()
    public var version: Int64 = 1

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("plan_id", JsonString(this.planId))

        var stepsArr = ArrayList<JsonValue>()
        for (s in this.completedSteps) {
            stepsArr.add(JsonString(s))
        }
        map.add("completed_steps", JsonArray(stepsArr))

        var outputsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.stepOutputs) {
            outputsMap.add(k, v)
        }
        map.add("step_outputs", JsonObject(outputsMap))

        var effectsMap = HashMap<String, JsonValue>()
        for ((k, ids) in this.sideEffectIds) {
            var idsArr = ArrayList<JsonValue>()
            for (id in ids) {
                idsArr.add(JsonString(id))
            }
            effectsMap.add(k, JsonArray(idsArr))
        }
        map.add("side_effect_ids", JsonObject(effectsMap))

        map.add("saved_at", JsonString(this.savedAt.toString()))
        map.add("version", JsonInt(this.version))
        JsonObject(map)
    }

    public static func fromJsonValue(json: JsonValue): Option<CheckpointData> {
        if (!(json is JsonObject)) { return None<CheckpointData> }
        let obj = json.asObject()
        let data = CheckpointData()

        if (let Some(val) <- obj.get("plan_id")) {
            if (val is JsonString) { data.planId = val.asString().getValue() }
        }

        if (let Some(val) <- obj.get("completed_steps")) {
            if (val is JsonArray) {
                for (item in val.asArray().getItems()) {
                    if (item is JsonString) { data.completedSteps.add(item.asString().getValue()) }
                }
            }
        }

        if (let Some(val) <- obj.get("step_outputs")) {
            if (val is JsonObject) {
                for ((k, v) in val.asObject().getFields()) {
                    data.stepOutputs.add(k, v)
                }
            }
        }

        if (let Some(val) <- obj.get("side_effect_ids")) {
            if (val is JsonObject) {
                for ((k, v) in val.asObject().getFields()) {
                    if (v is JsonArray) {
                        let ids = ArrayList<String>()
                        for (item in v.asArray().getItems()) {
                            if (item is JsonString) { ids.add(item.asString().getValue()) }
                        }
                        data.sideEffectIds.add(k, ids)
                    }
                }
            }
        }

        if (let Some(val) <- obj.get("version")) {
            if (val is JsonInt) { data.version = val.asInt().getValue() }
        }

        Some(data)
    }
}

public class CheckpointManager {
    private let _readCheckpoint: (String) -> Option<String>
    private let _writeCheckpoint: (String, String) -> Bool
    private let _clearCheckpointField: (String) -> Bool
    private var _cache: HashMap<String, CheckpointData>

    public init(readCheckpoint!: (String) -> Option<String>, writeCheckpoint!: (String, String) -> Bool, clearCheckpointField!: (String) -> Bool) {
        _readCheckpoint = readCheckpoint
        _writeCheckpoint = writeCheckpoint
        _clearCheckpointField = clearCheckpointField
        _cache = HashMap<String, CheckpointData>()
    }

    public func saveCheckpoint(planId: String, completedSteps: ArrayList<String>, stepOutputs: HashMap<String, JsonValue>): Bool {
        LogUtils.info("[CheckpointManager] Saving checkpoint: planId=${planId}")

        var data = CheckpointData()
        if (let Some(cached) <- _cache.get(planId)) {
            data = cached
            data.version = data.version + 1
        } else {
            data.planId = planId
        }

        for (s in completedSteps) {
            var found = false
            for (existing in data.completedSteps) {
                if (existing == s) { found = true; break }
            }
            if (!found) { data.completedSteps.add(s) }
        }

        for ((k, v) in stepOutputs) {
            data.stepOutputs.add(k, v)
        }

        data.savedAt = DateTime.now()

        let jsonStr = data.toJsonValue().toString()
        let success = _writeCheckpoint(planId, jsonStr)

        if (success) {
            _cache.add(planId, data)
            LogUtils.info("[CheckpointManager] Checkpoint saved: planId=${planId}, steps=${data.completedSteps.size.toString()}, version=${data.version.toString()}")
        } else {
            LogUtils.error("[CheckpointManager] Failed to save checkpoint: planId=${planId}")
        }

        success
    }

    public func loadCheckpoint(planId: String): Option<CheckpointData> {
        if (let Some(cached) <- _cache.get(planId)) {
            return Some(cached)
        }

        let jsonStrOpt = _readCheckpoint(planId)
        if (let Some(jsonStr) <- jsonStrOpt) {
            try {
                let json = JsonValue.fromStr(jsonStr)
                if (let Some(data) <- CheckpointData.fromJsonValue(json)) {
                    _cache.add(planId, data)
                    LogUtils.info("[CheckpointManager] Checkpoint loaded: planId=${planId}")
                    return Some(data)
                }
            } catch (_: Exception) {
                LogUtils.error("[CheckpointManager] Failed to parse checkpoint JSON")
            }
        }

        None<CheckpointData>
    }

    public func recoverFromCheckpoint(planId: String): Bool {
        LogUtils.info("[CheckpointManager] Recovering from checkpoint: planId=${planId}")

        let dataOpt = loadCheckpoint(planId)
        if (dataOpt.isNone()) {
            LogUtils.error("[CheckpointManager] No checkpoint found for planId=${planId}")
            return false
        }

        let data = dataOpt.getOrThrow()
        LogUtils.info("[CheckpointManager] Recovery plan: ${data.completedSteps.size.toString()} completed steps will be skipped")
        true
    }

    public func clearCheckpoint(planId: String): Bool {
        _cache.remove(planId)
        let success = _clearCheckpointField(planId)
        if (success) {
            LogUtils.info("[CheckpointManager] Checkpoint cleared: planId=${planId}")
        }
        success
    }

    public func getCompletedSteps(planId: String): ArrayList<String> {
        if (let Some(data) <- loadCheckpoint(planId)) {
            return data.completedSteps
        }
        ArrayList<String>()
    }

    public func isStepCompleted(planId: String, stepName: String): Bool {
        if (let Some(data) <- loadCheckpoint(planId)) {
            for (s in data.completedSteps) {
                if (s == stepName) { return true }
            }
        }
        false
    }
}