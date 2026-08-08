/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool}
import magic.log.LogUtils

public enum SideEffectType {
    | FileWrite
    | DbInsert
    | DbUpdate
    | DbDelete
    | ApiCall
    | CommandExec
}

public class SideEffectRecord {
    public var id: String = ""
    public var evidenceId: String = ""
    public var effectType: SideEffectType = SideEffectType.FileWrite
    public var target: String = ""
    public var description: String = ""
    public var beforeState: Option<JsonValue> = None<JsonValue>
    public var afterState: Option<JsonValue> = None<JsonValue>
    public var isReversible: Bool = true
    public var rollbackAction: Option<String> = None<String>
    public var timestamp: DateTime = DateTime.now()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", JsonString(this.id))
        map.add("evidence_id", JsonString(this.evidenceId))
        map.add("effect_type", JsonString(sideEffectTypeToString(this.effectType)))
        map.add("target", JsonString(this.target))
        map.add("description", JsonString(this.description))
        if (let Some(before) <- this.beforeState) {
            map.add("before_state", before)
        }
        if (let Some(after) <- this.afterState) {
            map.add("after_state", after)
        }
        map.add("is_reversible", JsonBool(this.isReversible))
        if (let Some(rb) <- this.rollbackAction) {
            map.add("rollback_action", JsonString(rb))
        }
        map.add("timestamp", JsonString(this.timestamp.toString()))
        return JsonObject(map)
    }

    public static func sideEffectTypeToString(t: SideEffectType): String {
        match (t) {
            case SideEffectType.FileWrite => "file_write"
            case SideEffectType.DbInsert => "db_insert"
            case SideEffectType.DbUpdate => "db_update"
            case SideEffectType.DbDelete => "db_delete"
            case SideEffectType.ApiCall => "api_call"
            case SideEffectType.CommandExec => "command_exec"
        }
    }

    public static func parseSideEffectType(s: String): SideEffectType {
        match (s) {
            case "db_insert" => SideEffectType.DbInsert
            case "db_update" => SideEffectType.DbUpdate
            case "db_delete" => SideEffectType.DbDelete
            case "api_call" => SideEffectType.ApiCall
            case "command_exec" => SideEffectType.CommandExec
            case _ => SideEffectType.FileWrite
        }
    }
}

public class SideEffectTracker {
    private var _records: HashMap<String, SideEffectRecord>
    private var _evidenceEffects: HashMap<String, ArrayList<String>>
    private var _counter: Int64 = 0

    public init() {
        _records = HashMap<String, SideEffectRecord>()
        _evidenceEffects = HashMap<String, ArrayList<String>>()
    }

    public func trackFileWrite(evidenceId: String, filePath: String, content: String, beforeContent: Option<String>): String {
        return track(evidenceId, SideEffectType.FileWrite, filePath, "File written: ${filePath}", stringToJson(beforeContent), Some(JsonString(content)), true, Some("restore_file:${filePath}"))
    }

    public func trackDbInsert(evidenceId: String, tableName: String, recordId: String, data: Option<JsonValue>): String {
        return track(evidenceId, SideEffectType.DbInsert, "${tableName}/${recordId}", "DB insert: ${tableName} id=${recordId}", None, data, true, Some("db_delete:${tableName}:${recordId}"))
    }

    public func trackDbUpdate(evidenceId: String, tableName: String, recordId: String, beforeData: Option<JsonValue>, afterData: Option<JsonValue>): String {
        return track(evidenceId, SideEffectType.DbUpdate, "${tableName}/${recordId}", "DB update: ${tableName} id=${recordId}", beforeData, afterData, true, Some("db_update:${tableName}:${recordId}"))
    }

    public func trackDbDelete(evidenceId: String, tableName: String, recordId: String, beforeData: Option<JsonValue>): String {
        return track(evidenceId, SideEffectType.DbDelete, "${tableName}/${recordId}", "DB delete: ${tableName} id=${recordId}", beforeData, None, true, Some("db_insert:${tableName}:${recordId}"))
    }

    public func trackApiCall(evidenceId: String, endpoint: String, request: Option<JsonValue>, response: Option<JsonValue>): String {
        return track(evidenceId, SideEffectType.ApiCall, endpoint, "API call: ${endpoint}", request, response, false, None)
    }

    public func trackCommandExec(evidenceId: String, command: String, output: Option<JsonValue>): String {
        return track(evidenceId, SideEffectType.CommandExec, command, "Command executed: ${command}", None, output, false, None)
    }

    public func getEffectsByEvidence(evidenceId: String): ArrayList<SideEffectRecord> {
        let result = ArrayList<SideEffectRecord>()
        if (let Some(ids) <- _evidenceEffects.get(evidenceId)) {
            for (id in ids) {
                if (let Some(record) <- _records.get(id)) {
                    result.add(record)
                }
            }
        }
        return result
    }

    public func getReversibleEffects(evidenceId: String): ArrayList<SideEffectRecord> {
        let all = getEffectsByEvidence(evidenceId)
        let result = ArrayList<SideEffectRecord>()
        for (record in all) {
            if (record.isReversible) {
                result.add(record)
            }
        }
        return result
    }

    public func getRollbackPlan(evidenceId: String): ArrayList<String> {
        let reversible = getReversibleEffects(evidenceId)
        let plan = ArrayList<String>()
        for (i in 0..reversible.size) {
            let idx = reversible.size - 1 - i
            let record = reversible[idx]
            if (let Some(action) <- record.rollbackAction) {
                plan.add(action)
            }
        }
        return plan
    }

    public func getAllEffects(): ArrayList<SideEffectRecord> {
        let result = ArrayList<SideEffectRecord>()
        for ((_, record) in _records) {
            result.add(record)
        }
        return result
    }

    public func getEffectCount(): Int64 {
        return _counter
    }

    public func clear(): Unit {
        _records.clear()
        _evidenceEffects.clear()
        _counter = 0
    }

    private func track(
        evidenceId: String,
        effectType: SideEffectType,
        target: String,
        description: String,
        beforeState: Option<JsonValue>,
        afterState: Option<JsonValue>,
        isReversible: Bool,
        rollbackAction: Option<String>
    ): String {
        _counter = _counter + 1
        let id = "se_${_counter.toString()}"

        let record = SideEffectRecord()
        record.id = id
        record.evidenceId = evidenceId
        record.effectType = effectType
        record.target = target
        record.description = description
        record.beforeState = beforeState
        record.afterState = afterState
        record.isReversible = isReversible
        record.rollbackAction = rollbackAction
        record.timestamp = DateTime.now()

        _records.add(id, record)

        if (!_evidenceEffects.contains(evidenceId)) {
            _evidenceEffects.add(evidenceId, ArrayList<String>())
        }
        if (let Some(list) <- _evidenceEffects.get(evidenceId)) {
            list.add(id)
        }

        LogUtils.info("[SideEffectTracker] Tracked: ${SideEffectRecord.sideEffectTypeToString(effectType)} -> ${target}")
        return id
    }

    private func stringToJson(opt: Option<String>): Option<JsonValue> {
        if (let Some(s) <- opt) {
            return Some(JsonString(s))
        }
        return None
    }
}