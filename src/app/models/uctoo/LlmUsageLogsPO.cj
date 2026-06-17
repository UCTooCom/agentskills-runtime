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
 * LlmUsageLogsPO - llm_usage_logs表持久化对象
 * 
 * 对应数据库表: llm_usage_logs
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["llm_usage_logs"]
public class LlmUsageLogsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: Option<String> = None<String>

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

        @ORMField['provider']
    public var provider: String = ""

        @ORMField['model']
    public var model: String = ""

        @ORMField['model_id']
    public var modelId: String = ""

        @ORMField['prompt_tokens']
    public var promptTokens: Int64 = 0

        @ORMField['completion_tokens']
    public var completionTokens: Int64 = 0

        @ORMField['total_tokens']
    public var totalTokens: Int64 = 0

        @ORMField['time_cost_ms']
    public var timeCostMs: Int32 = 0

        @ORMField['request_type']
    public var requestType: String = ""

        @ORMField['is_streaming']
    public var isStreaming: Bool = false

        @ORMField['tool_calls_count']
    public var toolCallsCount: Int32 = 0

        @ORMField['user_id']
    public var userId: Option<String> = None<String>

        @ORMField['session_id']
    public var sessionId: Option<String> = None<String>

        @ORMField['cost_amount']
    public var costAmount: Float64 = 0.0

        @ORMField['cost_currency']
    public var costCurrency: String = ""

        @ORMField['rate_prompt']
    public var ratePrompt: Float64 = 0.0

        @ORMField['rate_completion']
    public var rateCompletion: Float64 = 0.0

        @ORMField['request_id']
    public var requestId: Option<String> = None<String>

        @ORMField['error_message']
    public var errorMessage: Option<String> = None<String>

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
                agentId: Option<String>,
                taskId: Option<String>,
                provider: String,
                model: String,
                modelId: String,
                promptTokens: Int64,
                completionTokens: Int64,
                totalTokens: Int64,
                timeCostMs: Int32,
                requestType: String,
                isStreaming: Bool,
                toolCallsCount: Int32,
                userId: Option<String>,
                sessionId: Option<String>,
                costAmount: Float64,
                costCurrency: String,
                ratePrompt: Float64,
                rateCompletion: Float64,
                requestId: Option<String>,
                errorMessage: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.taskId = taskId
                this.provider = provider
                this.model = model
                this.modelId = modelId
                this.promptTokens = promptTokens
                this.completionTokens = completionTokens
                this.totalTokens = totalTokens
                this.timeCostMs = timeCostMs
                this.requestType = requestType
                this.isStreaming = isStreaming
                this.toolCallsCount = toolCallsCount
                this.userId = userId
                this.sessionId = sessionId
                this.costAmount = costAmount
                this.costCurrency = costCurrency
                this.ratePrompt = ratePrompt
                this.rateCompletion = rateCompletion
                this.requestId = requestId
                this.errorMessage = errorMessage
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("agent_id", optionToJsonValue(this.agentId))
        map.add("task_id", optionToJsonValue(this.taskId))
        map.add("provider", this.provider.toJsonValue())
        map.add("model", this.model.toJsonValue())
        map.add("model_id", this.modelId.toJsonValue())
        map.add("prompt_tokens", this.promptTokens.toJsonValue())
        map.add("completion_tokens", this.completionTokens.toJsonValue())
        map.add("total_tokens", this.totalTokens.toJsonValue())
        map.add("time_cost_ms", this.timeCostMs.toJsonValue())
        map.add("request_type", this.requestType.toJsonValue())
        map.add("is_streaming", this.isStreaming.toJsonValue())
        map.add("tool_calls_count", this.toolCallsCount.toJsonValue())
        map.add("user_id", optionToJsonValue(this.userId))
        map.add("session_id", optionToJsonValue(this.sessionId))
        map.add("cost_amount", this.costAmount.toJsonValue())
        map.add("cost_currency", this.costCurrency.toJsonValue())
        map.add("rate_prompt", this.ratePrompt.toJsonValue())
        map.add("rate_completion", this.rateCompletion.toJsonValue())
        map.add("request_id", optionToJsonValue(this.requestId))
        map.add("error_message", optionToJsonValue(this.errorMessage))
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
