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
 * AgentGroupsPO - agent_groups表持久化对象
 * 
 * 对应数据库表: agent_groups
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_groups"]
public class AgentGroupsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['group_type']
    public var groupType: String = ""

        @ORMField['leader_id']
    public var leaderId: Option<String> = None<String>

        @ORMField['member_ids']
    public var memberIds: String = ""

        @ORMField['config']
    public var config: String = ""

        @ORMField['status']
    public var status: String = ""

        @ORMField['max_round']
    public var maxRound: Int64 = 0

        @ORMField['description']
    public var description: Option<String> = None<String>

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
                name: String,
                groupType: String,
                leaderId: Option<String>,
                memberIds: String,
                config: String,
                status: String,
                maxRound: Int64,
                description: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.name = name
                this.groupType = groupType
                this.leaderId = leaderId
                this.memberIds = memberIds
                this.config = config
                this.status = status
                this.maxRound = maxRound
                this.description = description
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
        map.add("group_type", this.groupType.toJsonValue())
        map.add("leader_id", optionToJsonValue(this.leaderId))
        map.add("member_ids", this.memberIds.toJsonValue())
        map.add("config", this.config.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("max_round", this.maxRound.toJsonValue())
        map.add("description", optionToJsonValue(this.description))
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
