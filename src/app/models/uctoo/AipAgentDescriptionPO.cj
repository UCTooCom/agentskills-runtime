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
 * AipAgentDescriptionPO - aip_agent_description表持久化对象
 * 
 * 对应数据库表: aip_agent_description
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_agent_description"]
public class AipAgentDescriptionPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_identity_id']
    public var agentIdentityId: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['agent_id_code']
    public var agentIdCode: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['alias']
    public var alias: Option<String> = None<String>

        @ORMField['version']
    public var version: String = ""

        @ORMField['description']
    public var description: String = ""

        @ORMField['icon_address']
    public var iconAddress: Option<String> = None<String>

        @ORMField['provider']
    public var provider: String = ""

        @ORMField['access_address']
    public var accessAddress: Option<String> = None<String>

        @ORMField['access_method']
    public var accessMethod: Option<String> = None<String>

        @ORMField['serving_area']
    public var servingArea: Option<String> = None<String>

        @ORMField['authentication']
    public var authentication: Option<String> = None<String>

        @ORMField['capabilities']
    public var capabilities: String = ""

        @ORMField['default_input_types']
    public var defaultInputTypes: String = ""

        @ORMField['default_output_types']
    public var defaultOutputTypes: String = ""

        @ORMField['skills']
    public var skills: String = ""

        @ORMField['discoverable']
    public var discoverable: Bool = false

        @ORMField['publish_status']
    public var publishStatus: String = ""

        @ORMField['published_at']
    public var publishedAt: Option<DateTime> = None<DateTime>

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
                agentIdentityId: String,
                agentId: String,
                agentIdCode: String,
                name: String,
                alias: Option<String>,
                version: String,
                description: String,
                iconAddress: Option<String>,
                provider: String,
                accessAddress: Option<String>,
                accessMethod: Option<String>,
                servingArea: Option<String>,
                authentication: Option<String>,
                capabilities: String,
                defaultInputTypes: String,
                defaultOutputTypes: String,
                skills: String,
                discoverable: Bool,
                publishStatus: String,
                publishedAt: Option<DateTime>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentIdentityId = agentIdentityId
                this.agentId = agentId
                this.agentIdCode = agentIdCode
                this.name = name
                this.alias = alias
                this.version = version
                this.description = description
                this.iconAddress = iconAddress
                this.provider = provider
                this.accessAddress = accessAddress
                this.accessMethod = accessMethod
                this.servingArea = servingArea
                this.authentication = authentication
                this.capabilities = capabilities
                this.defaultInputTypes = defaultInputTypes
                this.defaultOutputTypes = defaultOutputTypes
                this.skills = skills
                this.discoverable = discoverable
                this.publishStatus = publishStatus
                this.publishedAt = publishedAt
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("agent_identity_id", this.agentIdentityId.toJsonValue())
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("agent_id_code", this.agentIdCode.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("alias", optionToJsonValue(this.alias))
        map.add("version", this.version.toJsonValue())
        map.add("description", this.description.toJsonValue())
        map.add("icon_address", optionToJsonValue(this.iconAddress))
        map.add("provider", this.provider.toJsonValue())
        map.add("access_address", optionToJsonValue(this.accessAddress))
        map.add("access_method", optionToJsonValue(this.accessMethod))
        map.add("serving_area", optionToJsonValue(this.servingArea))
        map.add("authentication", optionToJsonValue(this.authentication))
        map.add("capabilities", this.capabilities.toJsonValue())
        map.add("default_input_types", this.defaultInputTypes.toJsonValue())
        map.add("default_output_types", this.defaultOutputTypes.toJsonValue())
        map.add("skills", this.skills.toJsonValue())
        map.add("discoverable", this.discoverable.toJsonValue())
        map.add("publish_status", this.publishStatus.toJsonValue())
        map.add("published_at", optionToJsonValue(this.publishedAt))
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
