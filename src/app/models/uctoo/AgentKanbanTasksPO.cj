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
 * AgentKanbanTasksPO - agent_kanban_tasks表持久化对象
 * 
 * 对应数据库表: agent_kanban_tasks
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_kanban_tasks"]
public class AgentKanbanTasksPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['title']
    public var title: String = ""

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['state']
    public var state: String = ""

        @ORMField['assignee']
    public var assignee: Option<String> = None<String>

        @ORMField['priority']
    public var priority: Int32 = 0

        @ORMField['parent_task_id']
    public var parentTaskId: Option<String> = None<String>

        @ORMField['sub_task_ids']
    public var subTaskIds: String = ""

        @ORMField['dependencies']
    public var dependencies: String = ""

        @ORMField['result']
    public var result: Option<String> = None<String>

        @ORMField['agent_id']
    public var agentId: Option<String> = None<String>

        @ORMField['session_id']
    public var sessionId: Option<String> = None<String>

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
                title: String,
                description: Option<String>,
                state: String,
                assignee: Option<String>,
                priority: Int32,
                parentTaskId: Option<String>,
                subTaskIds: String,
                dependencies: String,
                result: Option<String>,
                agentId: Option<String>,
                sessionId: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.title = title
                this.description = description
                this.state = state
                this.assignee = assignee
                this.priority = priority
                this.parentTaskId = parentTaskId
                this.subTaskIds = subTaskIds
                this.dependencies = dependencies
                this.result = result
                this.agentId = agentId
                this.sessionId = sessionId
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("title", this.title.toJsonValue())
        map.add("description", optionToJsonValue(this.description))
        map.add("state", this.state.toJsonValue())
        map.add("assignee", optionToJsonValue(this.assignee))
        map.add("priority", this.priority.toJsonValue())
        map.add("parent_task_id", optionToJsonValue(this.parentTaskId))
        map.add("sub_task_ids", this.subTaskIds.toJsonValue())
        map.add("dependencies", this.dependencies.toJsonValue())
        map.add("result", optionToJsonValue(this.result))
        map.add("agent_id", optionToJsonValue(this.agentId))
        map.add("session_id", optionToJsonValue(this.sessionId))
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
