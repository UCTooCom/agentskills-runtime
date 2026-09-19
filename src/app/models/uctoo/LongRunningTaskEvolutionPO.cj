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
 * LongRunningTaskEvolutionPO - long_running_task_evolution表持久化对象
 * 
 * 对应数据库表: long_running_task_evolution
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["long_running_task_evolution"]
public class LongRunningTaskEvolutionPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: Option<String> = None<String>

        @ORMField['round']
    public var round: Int32 = 0

        @ORMField['root_cause']
    public var rootCause: Option<String> = None<String>

        @ORMField['optimization_plan']
    public var optimizationPlan: Option<String> = None<String>

        @ORMField['anti_regression']
    public var antiRegression: Option<String> = None<String>

        @ORMField['skill_md_updates']
    public var skillMdUpdates: Option<String> = None<String>

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
                round: Int32,
                rootCause: Option<String>,
                optimizationPlan: Option<String>,
                antiRegression: Option<String>,
                skillMdUpdates: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.round = round
                this.rootCause = rootCause
                this.optimizationPlan = optimizationPlan
                this.antiRegression = antiRegression
                this.skillMdUpdates = skillMdUpdates
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
        map.add("round", this.round.toJsonValue())
        map.add("root_cause", optionToJsonValue(this.rootCause))
        map.add("optimization_plan", optionToJsonValue(this.optimizationPlan))
        map.add("anti_regression", optionToJsonValue(this.antiRegression))
        map.add("skill_md_updates", optionToJsonValue(this.skillMdUpdates))
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
