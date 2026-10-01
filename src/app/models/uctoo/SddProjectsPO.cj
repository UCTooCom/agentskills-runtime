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
 * SddProjectsPO - sdd_projects表持久化对象
 * 
 * 对应数据库表: sdd_projects
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["sdd_projects"]
public class SddProjectsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['feature_name']
    public var featureName: String = ""

        @ORMField['title']
    public var title: Option<String> = None<String>

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

        @ORMField['current_stage']
    public var currentStage: String = ""

        @ORMField['status']
    public var status: String = ""

        @ORMField['enable_research']
    public var enableResearch: Bool = false

        @ORMField['round']
    public var round: Int32 = 0

        @ORMField['payload']
    public var payload: String = ""

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['owner_user_id']
    public var ownerUserId: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                featureName: String,
                title: Option<String>,
                taskId: Option<String>,
                currentStage: String,
                status: String,
                enableResearch: Bool,
                round: Int32,
                payload: String,
                creator: Option<String>,
                ownerUserId: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.featureName = featureName
                this.title = title
                this.taskId = taskId
                this.currentStage = currentStage
                this.status = status
                this.enableResearch = enableResearch
                this.round = round
                this.payload = payload
                this.creator = creator
                this.ownerUserId = ownerUserId
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("feature_name", this.featureName.toJsonValue())
        map.add("title", optionToJsonValue(this.title))
        map.add("task_id", optionToJsonValue(this.taskId))
        map.add("current_stage", this.currentStage.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("enable_research", this.enableResearch.toJsonValue())
        map.add("round", this.round.toJsonValue())
        map.add("payload", this.payload.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("owner_user_id", optionToJsonValue(this.ownerUserId))
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
