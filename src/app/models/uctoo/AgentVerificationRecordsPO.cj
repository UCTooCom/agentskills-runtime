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
 * AgentVerificationRecordsPO - agent_verification_records表持久化对象
 * 
 * 对应数据库表: agent_verification_records
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_verification_records"]
public class AgentVerificationRecordsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['task_id']
    public var taskId: String = ""

        @ORMField['step_name']
    public var stepName: Option<String> = None<String>

        @ORMField['overall_status']
    public var overallStatus: String = ""

        @ORMField['valid_count']
    public var validCount: Int32 = 0

        @ORMField['invalid_count']
    public var invalidCount: Int32 = 0

        @ORMField['partial_count']
    public var partialCount: Int32 = 0

        @ORMField['validation_results']
    public var validationResults: String = ""

        @ORMField['rules_applied']
    public var rulesApplied: String = ""

        @ORMField['evidence_id']
    public var evidenceId: Option<String> = None<String>

        @ORMField['metadata']
    public var metadata: String = ""

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                taskId: String,
                stepName: Option<String>,
                overallStatus: String,
                validCount: Int32,
                invalidCount: Int32,
                partialCount: Int32,
                validationResults: String,
                rulesApplied: String,
                evidenceId: Option<String>,
                metadata: String,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.taskId = taskId
                this.stepName = stepName
                this.overallStatus = overallStatus
                this.validCount = validCount
                this.invalidCount = invalidCount
                this.partialCount = partialCount
                this.validationResults = validationResults
                this.rulesApplied = rulesApplied
                this.evidenceId = evidenceId
                this.metadata = metadata
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("task_id", this.taskId.toJsonValue())
        map.add("step_name", optionToJsonValue(this.stepName))
        map.add("overall_status", this.overallStatus.toJsonValue())
        map.add("valid_count", this.validCount.toJsonValue())
        map.add("invalid_count", this.invalidCount.toJsonValue())
        map.add("partial_count", this.partialCount.toJsonValue())
        map.add("validation_results", this.validationResults.toJsonValue())
        map.add("rules_applied", this.rulesApplied.toJsonValue())
        map.add("evidence_id", optionToJsonValue(this.evidenceId))
        map.add("metadata", this.metadata.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
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