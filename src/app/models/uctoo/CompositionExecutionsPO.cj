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
 * CompositionExecutionsPO - composition_executions表持久化对象
 * 
 * 对应数据库表: composition_executions
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["composition_executions"]
public class CompositionExecutionsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['composition_id']
    public var compositionId: String = ""

        @ORMField['status']
    public var status: String = ""

        @ORMField['step_results']
    public var stepResults: Option<String> = None<String>

        @ORMField['final_output']
    public var finalOutput: Option<String> = None<String>

        @ORMField['cache_hits']
    public var cacheHits: Int32 = 0

        @ORMField['duration_ms']
    public var durationMs: Option<Int32> = None<Int32>

        @ORMField['creator']
    public var creator: String = ""

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['completed_at']
    public var completedAt: Option<DateTime> = None<DateTime>

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                compositionId: String,
                status: String,
                stepResults: Option<String>,
                finalOutput: Option<String>,
                cacheHits: Int32,
                durationMs: Option<Int32>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                completedAt: Option<DateTime>,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.compositionId = compositionId
                this.status = status
                this.stepResults = stepResults
                this.finalOutput = finalOutput
                this.cacheHits = cacheHits
                this.durationMs = durationMs
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.completedAt = completedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("composition_id", this.compositionId.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("step_results", optionToJsonValue(this.stepResults))
        map.add("final_output", optionToJsonValue(this.finalOutput))
        map.add("cache_hits", this.cacheHits.toJsonValue())
        map.add("duration_ms", optionToJsonValue(this.durationMs))
        map.add("creator", this.creator.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("completed_at", optionToJsonValue(this.completedAt))
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
