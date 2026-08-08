/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * ExecutionEvidencesPO - execution_evidences表持久化对象
 * 
 * 对应数据库表: execution_evidences
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["execution_evidences"]
public class ExecutionEvidencesPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['session_id']
    public var sessionId: String = ""

        @ORMField['step_id']
    public var stepId: String = ""

        @ORMField['parent_step_id']
    public var parentStepId: Option<String> = None<String>

        @ORMField['step_type']
    public var stepType: String = ""

        @ORMField['input']
    public var input: String = ""

        @ORMField['output']
    public var output: Option<String> = None<String>

        @ORMField['duration_ms']
    public var durationMs: Option<Int64> = None<Int64>

        @ORMField['side_effects']
    public var sideEffects: Option<String> = None<String>

        @ORMField['hash']
    public var hash: String = ""

        @ORMField['creator']
    public var creator: String = ""

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                agentId: String,
                sessionId: String,
                stepId: String,
                parentStepId: Option<String>,
                stepType: String,
                input: String,
                output: Option<String>,
                durationMs: Option<Int64>,
                sideEffects: Option<String>,
                hash: String,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.sessionId = sessionId
                this.stepId = stepId
                this.parentStepId = parentStepId
                this.stepType = stepType
                this.input = input
                this.output = output
                this.durationMs = durationMs
                this.sideEffects = sideEffects
                this.hash = hash
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("session_id", this.sessionId.toJsonValue())
        map.add("step_id", this.stepId.toJsonValue())
        map.add("parent_step_id", optionToJsonValue(this.parentStepId))
        map.add("step_type", this.stepType.toJsonValue())
        map.add("input", this.input.toJsonValue())
        map.add("output", optionToJsonValue(this.output))
        map.add("duration_ms", optionToJsonValue(this.durationMs))
        map.add("side_effects", optionToJsonValue(this.sideEffects))
        map.add("hash", this.hash.toJsonValue())
        map.add("creator", this.creator.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        return JsonObject(map)
    }

    /// 辅助方法：将 Option<T> 转换为 JsonValue
    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }

    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return this.toJsonValue().toString()
    }

//#endregion AutoCreateCode
}
