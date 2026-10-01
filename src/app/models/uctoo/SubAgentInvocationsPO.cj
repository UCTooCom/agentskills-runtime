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
 * SubAgentInvocationsPO - sub_agent_invocations表持久化对象
 * 
 * 对应数据库表: sub_agent_invocations
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["sub_agent_invocations"]
public class SubAgentInvocationsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['parent_task_id']
    public var parentTaskId: Option<String> = None<String>

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['skill_name']
    public var skillName: Option<String> = None<String>

        @ORMField['stage']
    public var stage: Option<String> = None<String>

        @ORMField['mode']
    public var mode: String = ""

        @ORMField['input_json']
    public var inputJson: String = ""

        @ORMField['output_json']
    public var outputJson: Option<String> = None<String>

        @ORMField['status']
    public var status: String = ""

        @ORMField['duration_ms']
    public var durationMs: Option<Int64> = None<Int64>

        @ORMField['error_message']
    public var errorMessage: Option<String> = None<String>

        @ORMField['contract_type']
    public var contractType: Option<String> = None<String>

        @ORMField['verify_passed']
    public var verifyPassed: Option<Bool> = None<Bool>

        @ORMField['verify_errors']
    public var verifyErrors: Option<String> = None<String>

        @ORMField['attempt']
    public var attempt: Int32 = 0

        @ORMField['prompt_tokens']
    public var promptTokens: Int64 = 0

        @ORMField['completion_tokens']
    public var completionTokens: Int64 = 0

        @ORMField['total_tokens']
    public var totalTokens: Int64 = 0

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
                parentTaskId: Option<String>,
                taskId: Option<String>,
                agentId: String,
                skillName: Option<String>,
                stage: Option<String>,
                mode: String,
                inputJson: String,
                outputJson: Option<String>,
                status: String,
                durationMs: Option<Int64>,
                errorMessage: Option<String>,
                contractType: Option<String>,
                verifyPassed: Option<Bool>,
                verifyErrors: Option<String>,
                attempt: Int32,
                promptTokens: Int64,
                completionTokens: Int64,
                totalTokens: Int64,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.parentTaskId = parentTaskId
                this.taskId = taskId
                this.agentId = agentId
                this.skillName = skillName
                this.stage = stage
                this.mode = mode
                this.inputJson = inputJson
                this.outputJson = outputJson
                this.status = status
                this.durationMs = durationMs
                this.errorMessage = errorMessage
                this.contractType = contractType
                this.verifyPassed = verifyPassed
                this.verifyErrors = verifyErrors
                this.attempt = attempt
                this.promptTokens = promptTokens
                this.completionTokens = completionTokens
                this.totalTokens = totalTokens
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("parent_task_id", optionToJsonValue(this.parentTaskId))
        map.add("task_id", optionToJsonValue(this.taskId))
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("skill_name", optionToJsonValue(this.skillName))
        map.add("stage", optionToJsonValue(this.stage))
        map.add("mode", this.mode.toJsonValue())
        map.add("input_json", this.inputJson.toJsonValue())
        map.add("output_json", optionToJsonValue(this.outputJson))
        map.add("status", this.status.toJsonValue())
        map.add("duration_ms", optionToJsonValue(this.durationMs))
        map.add("error_message", optionToJsonValue(this.errorMessage))
        map.add("contract_type", optionToJsonValue(this.contractType))
        map.add("verify_passed", optionToJsonValue(this.verifyPassed))
        map.add("verify_errors", optionToJsonValue(this.verifyErrors))
        map.add("attempt", this.attempt.toJsonValue())
        map.add("prompt_tokens", this.promptTokens.toJsonValue())
        map.add("completion_tokens", this.completionTokens.toJsonValue())
        map.add("total_tokens", this.totalTokens.toJsonValue())
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
