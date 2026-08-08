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
 * AgentGroupMembersPO - agent_group_members表持久化对象
 * 
 * 对应数据库表: agent_group_members
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_group_members"]
public class AgentGroupMembersPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['group_id']
    public var groupId: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['role']
    public var role: String = ""

        @ORMField['parent_agent_id']
    public var parentAgentId: Option<String> = None<String>

        @ORMField['skills']
    public var skills: String = ""

        @ORMField['config']
    public var config: String = ""

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
                groupId: String,
                agentId: String,
                role: String,
                parentAgentId: Option<String>,
                skills: String,
                config: String,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.groupId = groupId
                this.agentId = agentId
                this.role = role
                this.parentAgentId = parentAgentId
                this.skills = skills
                this.config = config
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("group_id", this.groupId.toJsonValue())
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("role", this.role.toJsonValue())
        map.add("parent_agent_id", optionToJsonValue(this.parentAgentId))
        map.add("skills", this.skills.toJsonValue())
        map.add("config", this.config.toJsonValue())
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
