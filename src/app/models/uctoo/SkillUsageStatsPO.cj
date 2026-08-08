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
 * SkillUsageStatsPO - skill_usage_stats表持久化对象
 * 
 * 对应数据库表: skill_usage_stats
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["skill_usage_stats"]
public class SkillUsageStatsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['skill_name']
    public var skillName: String = ""

        @ORMField['use_count']
    public var useCount: Int64 = 0

        @ORMField['view_count']
    public var viewCount: Int64 = 0

        @ORMField['modify_count']
    public var modifyCount: Int64 = 0

        @ORMField['success_count']
    public var successCount: Int64 = 0

        @ORMField['failure_count']
    public var failureCount: Int64 = 0

        @ORMField['state']
    public var state: String = ""

        @ORMField['avg_execution_time_ms']
    public var avgExecutionTimeMs: Float64 = 0.0

        @ORMField['user_rating']
    public var userRating: Float64 = 0.0

        @ORMField['last_used_at']
    public var lastUsedAt: Option<DateTime> = None<DateTime>

        @ORMField['stats_detail']
    public var statsDetail: String = ""

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
                skillName: String,
                useCount: Int64,
                viewCount: Int64,
                modifyCount: Int64,
                successCount: Int64,
                failureCount: Int64,
                state: String,
                avgExecutionTimeMs: Float64,
                userRating: Float64,
                lastUsedAt: Option<DateTime>,
                statsDetail: String,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.skillName = skillName
                this.useCount = useCount
                this.viewCount = viewCount
                this.modifyCount = modifyCount
                this.successCount = successCount
                this.failureCount = failureCount
                this.state = state
                this.avgExecutionTimeMs = avgExecutionTimeMs
                this.userRating = userRating
                this.lastUsedAt = lastUsedAt
                this.statsDetail = statsDetail
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("skill_name", this.skillName.toJsonValue())
        map.add("use_count", this.useCount.toJsonValue())
        map.add("view_count", this.viewCount.toJsonValue())
        map.add("modify_count", this.modifyCount.toJsonValue())
        map.add("success_count", this.successCount.toJsonValue())
        map.add("failure_count", this.failureCount.toJsonValue())
        map.add("state", this.state.toJsonValue())
        map.add("avg_execution_time_ms", this.avgExecutionTimeMs.toJsonValue())
        map.add("user_rating", this.userRating.toJsonValue())
        map.add("last_used_at", optionToJsonValue(this.lastUsedAt))
        map.add("stats_detail", this.statsDetail.toJsonValue())
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
