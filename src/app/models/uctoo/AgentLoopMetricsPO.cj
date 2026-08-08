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
 * AgentLoopMetricsPO - agent_loop_metrics表持久化对象
 * 
 * 对应数据库表: agent_loop_metrics
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_loop_metrics"]
public class AgentLoopMetricsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['session_id']
    public var sessionId: Option<String> = None<String>

        @ORMField['evaluation_type']
    public var evaluationType: String = ""

        @ORMField['success_rate']
    public var successRate: Float64 = 0.0

        @ORMField['avg_duration_ms']
    public var avgDurationMs: Int64 = 0

        @ORMField['prompt_tokens']
    public var promptTokens: Int64 = 0

        @ORMField['completion_tokens']
    public var completionTokens: Int64 = 0

        @ORMField['total_tokens']
    public var totalTokens: Int64 = 0

        @ORMField['tool_call_count']
    public var toolCallCount: Int64 = 0

        @ORMField['side_effect_count']
    public var sideEffectCount: Int64 = 0

        @ORMField['metrics_detail']
    public var metricsDetail: String = ""

        @ORMField['time_range_start']
    public var timeRangeStart: Option<DateTime> = None<DateTime>

        @ORMField['time_range_end']
    public var timeRangeEnd: Option<DateTime> = None<DateTime>

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
                agentId: String,
                sessionId: Option<String>,
                evaluationType: String,
                successRate: Float64,
                avgDurationMs: Int64,
                promptTokens: Int64,
                completionTokens: Int64,
                totalTokens: Int64,
                toolCallCount: Int64,
                sideEffectCount: Int64,
                metricsDetail: String,
                timeRangeStart: Option<DateTime>,
                timeRangeEnd: Option<DateTime>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.sessionId = sessionId
                this.evaluationType = evaluationType
                this.successRate = successRate
                this.avgDurationMs = avgDurationMs
                this.promptTokens = promptTokens
                this.completionTokens = completionTokens
                this.totalTokens = totalTokens
                this.toolCallCount = toolCallCount
                this.sideEffectCount = sideEffectCount
                this.metricsDetail = metricsDetail
                this.timeRangeStart = timeRangeStart
                this.timeRangeEnd = timeRangeEnd
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
        map.add("session_id", optionToJsonValue(this.sessionId))
        map.add("evaluation_type", this.evaluationType.toJsonValue())
        map.add("success_rate", this.successRate.toJsonValue())
        map.add("avg_duration_ms", this.avgDurationMs.toJsonValue())
        map.add("prompt_tokens", this.promptTokens.toJsonValue())
        map.add("completion_tokens", this.completionTokens.toJsonValue())
        map.add("total_tokens", this.totalTokens.toJsonValue())
        map.add("tool_call_count", this.toolCallCount.toJsonValue())
        map.add("side_effect_count", this.sideEffectCount.toJsonValue())
        map.add("metrics_detail", this.metricsDetail.toJsonValue())
        map.add("time_range_start", optionToJsonValue(this.timeRangeStart))
        map.add("time_range_end", optionToJsonValue(this.timeRangeEnd))
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
