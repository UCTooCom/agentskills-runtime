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
 * OrchestrationPlansPO - orchestration_plans表持久化对象
 * 
 * 对应数据库表: orchestration_plans
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["orchestration_plans"]
public class OrchestrationPlansPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['status']
    public var status: String = ""

        @ORMField['dag_definition']
    public var dagDefinition: String = ""

        @ORMField['current_step']
    public var currentStep: Option<String> = None<String>

        @ORMField['checkpoint']
    public var checkpoint: Option<String> = None<String>

        @ORMField['result']
    public var result: Option<String> = None<String>

        @ORMField['team_id']
    public var teamId: Option<String> = None<String>

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
                name: String,
                status: String,
                dagDefinition: String,
                currentStep: Option<String>,
                checkpoint: Option<String>,
                result: Option<String>,
                teamId: Option<String>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.name = name
                this.status = status
                this.dagDefinition = dagDefinition
                this.currentStep = currentStep
                this.checkpoint = checkpoint
                this.result = result
                this.teamId = teamId
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("dag_definition", this.dagDefinition.toJsonValue())
        map.add("current_step", optionToJsonValue(this.currentStep))
        map.add("checkpoint", optionToJsonValue(this.checkpoint))
        map.add("result", optionToJsonValue(this.result))
        map.add("team_id", optionToJsonValue(this.teamId))
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
