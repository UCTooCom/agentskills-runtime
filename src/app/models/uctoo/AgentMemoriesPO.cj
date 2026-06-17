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
 * AgentMemoriesPO - agent_memories表持久化对象
 * 
 * 对应数据库表: agent_memories
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_memories"]
public class AgentMemoriesPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['content']
    public var content: String = ""

        @ORMField['embedding_vector']
    public var embeddingVector: Option<String> = None<String>

        @ORMField['scope']
    public var scope: String = ""

        @ORMField['weight']
    public var weight: Float64 = 0.0

        @ORMField['tags']
    public var tags: String = ""

        @ORMField['metadata']
    public var metadata: String = ""

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

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
                agentId: String,
                content: String,
                embeddingVector: Option<String>,
                scope: String,
                weight: Float64,
                tags: String,
                metadata: String,
                taskId: Option<String>,
                sessionId: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.content = content
                this.embeddingVector = embeddingVector
                this.scope = scope
                this.weight = weight
                this.tags = tags
                this.metadata = metadata
                this.taskId = taskId
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
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("content", this.content.toJsonValue())
        map.add("embedding_vector", optionToJsonValue(this.embeddingVector))
        map.add("scope", this.scope.toJsonValue())
        map.add("weight", this.weight.toJsonValue())
        map.add("tags", this.tags.toJsonValue())
        map.add("metadata", this.metadata.toJsonValue())
        map.add("task_id", optionToJsonValue(this.taskId))
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
