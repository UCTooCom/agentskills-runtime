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
 * AgentMessagesPO - agent_messages表持久化对象
 * 
 * 对应数据库表: agent_messages
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_messages"]
public class AgentMessagesPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['from_agent_id']
    public var fromAgentId: Option<String> = None<String>

        @ORMField['to_agent_id']
    public var toAgentId: Option<String> = None<String>

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

        @ORMField['message_type']
    public var messageType: String = ""

        @ORMField['content']
    public var content: Option<String> = None<String>

        @ORMField['status']
    public var status: Option<Int32> = None<Int32>

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
                fromAgentId: Option<String>,
                toAgentId: Option<String>,
                taskId: Option<String>,
                messageType: String,
                content: Option<String>,
                status: Option<Int32>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.fromAgentId = fromAgentId
                this.toAgentId = toAgentId
                this.taskId = taskId
                this.messageType = messageType
                this.content = content
                this.status = status
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("from_agent_id", optionToJsonValue(this.fromAgentId))
        map.add("to_agent_id", optionToJsonValue(this.toAgentId))
        map.add("task_id", optionToJsonValue(this.taskId))
        map.add("message_type", this.messageType.toJsonValue())
        map.add("content", optionToJsonValue(this.content))
        map.add("status", optionToJsonValue(this.status))
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
