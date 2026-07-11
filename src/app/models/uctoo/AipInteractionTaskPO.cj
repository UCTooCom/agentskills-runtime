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
 * AipInteractionTaskPO - aip_interaction_task表持久化对象
 * 
 * 对应数据库表: aip_interaction_task
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_interaction_task"]
public class AipInteractionTaskPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['task_id']
    public var taskId: String = ""

        @ORMField['session_id']
    public var sessionId: String = ""

        @ORMField['service_agent_id']
    public var serviceAgentId: String = ""

        @ORMField['service_aic']
    public var serviceAic: String = ""

        @ORMField['state']
    public var state: String = ""

        @ORMField['state_changed_at']
    public var stateChangedAt: Option<DateTime> = None<DateTime>

        @ORMField['artifacts']
    public var artifacts: Option<String> = None<String>

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
                taskId: String,
                sessionId: String,
                serviceAgentId: String,
                serviceAic: String,
                state: String,
                stateChangedAt: Option<DateTime>,
                artifacts: Option<String>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.taskId = taskId
                this.sessionId = sessionId
                this.serviceAgentId = serviceAgentId
                this.serviceAic = serviceAic
                this.state = state
                this.stateChangedAt = stateChangedAt
                this.artifacts = artifacts
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
        map.add("session_id", this.sessionId.toJsonValue())
        map.add("service_agent_id", this.serviceAgentId.toJsonValue())
        map.add("service_aic", this.serviceAic.toJsonValue())
        map.add("state", this.state.toJsonValue())
        map.add("state_changed_at", optionToJsonValue(this.stateChangedAt))
        map.add("artifacts", optionToJsonValue(this.artifacts))
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
