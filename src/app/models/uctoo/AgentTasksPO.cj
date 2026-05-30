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
 * AgentTasksPO - agent_tasks表持久化对象
 * 
 * 对应数据库表: agent_tasks
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_tasks"]
public class AgentTasksPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['parent_task_id']
    public var parentTaskId: Option<String> = None<String>

        @ORMField['status']
    public var status: Option<Int32> = None<Int32>

        @ORMField['priority']
    public var priority: Option<Int32> = None<Int32>

        @ORMField['payload']
    public var payload: Option<String> = None<String>

        @ORMField['result']
    public var result: Option<String> = None<String>

        @ORMField['error_message']
    public var errorMessage: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

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
                agentId: String,
                parentTaskId: Option<String>,
                status: Option<Int32>,
                priority: Option<Int32>,
                payload: Option<String>,
                result: Option<String>,
                errorMessage: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                completedAt: Option<DateTime>,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.parentTaskId = parentTaskId
                this.status = status
                this.priority = priority
                this.payload = payload
                this.result = result
                this.errorMessage = errorMessage
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
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("parent_task_id", optionToJsonValue(this.parentTaskId))
        map.add("status", optionToJsonValue(this.status))
        map.add("priority", optionToJsonValue(this.priority))
        map.add("payload", optionToJsonValue(this.payload))
        map.add("result", optionToJsonValue(this.result))
        map.add("error_message", optionToJsonValue(this.errorMessage))
        map.add("creator", optionToJsonValue(this.creator))
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
