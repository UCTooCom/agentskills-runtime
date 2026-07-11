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
 * AgentsPO - agents表持久化对象
 * 
 * 对应数据库表: agents
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agents"]
public class AgentsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['agent_type']
    public var agentType: String = ""

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['status']
    public var status: Option<Int32> = None<Int32>

        @ORMField['config']
    public var config: Option<String> = None<String>

        @ORMField['system_prompt']
    public var systemPrompt: Option<String> = None<String>

        @ORMField['tools']
    public var tools: Option<String> = None<String>

        @ORMField['model']
    public var model: Option<String> = None<String>

        @ORMField['parent_id']
    public var parentId: Option<String> = None<String>

        @ORMField['user_id']
    public var userId: Option<String> = None<String>

        @ORMField['color']
    public var color: Option<String> = None<String>

        @ORMField['background']
    public var background: Option<Bool> = None<Bool>

        @ORMField['memory_scope']
    public var memoryScope: Option<String> = None<String>

        @ORMField['isolation_mode']
    public var isolationMode: Option<String> = None<String>

        @ORMField['max_turns']
    public var maxTurns: Option<Int32> = None<Int32>

        @ORMField['initial_prompt']
    public var initialPrompt: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['version']
    public var version: Option<String> = None<String>

        @ORMField['author']
    public var author: Option<String> = None<String>

        @ORMField['permissions']
    public var permissions: Option<String> = None<String>

        @ORMField['source_path']
    public var sourcePath: Option<String> = None<String>

        @ORMField['sync_status']
    public var syncStatus: Option<String> = None<String>

        @ORMField['last_sync_at']
    public var lastSyncAt: Option<DateTime> = None<DateTime>

        @ORMField['aic']
    public var aic: Option<String> = None<String>

        @ORMField['identity_status']
    public var identityStatus: String = "none"

        @ORMField['aip_registered_at']
    public var aipRegisteredAt: Option<DateTime> = None<DateTime>

        @ORMField['capabilities']
    public var capabilities: Option<String> = None<String>

        @ORMField['default_input_types']
    public var defaultInputTypes: Option<String> = None<String>

        @ORMField['default_output_types']
    public var defaultOutputTypes: Option<String> = None<String>

        @ORMField['discoverable']
    public var discoverable: Bool = true

    public init() {}

    public init(
                id: String,
                name: String,
                agentType: String,
                description: Option<String>,
                status: Option<Int32>,
                config: Option<String>,
                systemPrompt: Option<String>,
                tools: Option<String>,
                model: Option<String>,
                parentId: Option<String>,
                userId: Option<String>,
                color: Option<String>,
                background: Option<Bool>,
                memoryScope: Option<String>,
                isolationMode: Option<String>,
                maxTurns: Option<Int32>,
                initialPrompt: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                version: Option<String>,
                author: Option<String>,
                permissions: Option<String>,
                sourcePath: Option<String>,
                syncStatus: Option<String>,
                lastSyncAt: Option<DateTime>,
                aic: Option<String>,
                identityStatus: String,
                aipRegisteredAt: Option<DateTime>,
                capabilities: Option<String>,
                defaultInputTypes: Option<String>,
                defaultOutputTypes: Option<String>,
                discoverable: Bool
    ) {
                this.id = id
                this.name = name
                this.agentType = agentType
                this.description = description
                this.status = status
                this.config = config
                this.systemPrompt = systemPrompt
                this.tools = tools
                this.model = model
                this.parentId = parentId
                this.userId = userId
                this.color = color
                this.background = background
                this.memoryScope = memoryScope
                this.isolationMode = isolationMode
                this.maxTurns = maxTurns
                this.initialPrompt = initialPrompt
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.version = version
                this.author = author
                this.permissions = permissions
                this.sourcePath = sourcePath
                this.syncStatus = syncStatus
                this.lastSyncAt = lastSyncAt
                this.aic = aic
                this.identityStatus = identityStatus
                this.aipRegisteredAt = aipRegisteredAt
                this.capabilities = capabilities
                this.defaultInputTypes = defaultInputTypes
                this.defaultOutputTypes = defaultOutputTypes
                this.discoverable = discoverable
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("agent_type", this.agentType.toJsonValue())
        map.add("description", optionToJsonValue(this.description))
        map.add("status", optionToJsonValue(this.status))
        map.add("config", optionToJsonValue(this.config))
        map.add("system_prompt", optionToJsonValue(this.systemPrompt))
        map.add("tools", optionToJsonValue(this.tools))
        map.add("model", optionToJsonValue(this.model))
        map.add("parent_id", optionToJsonValue(this.parentId))
        map.add("user_id", optionToJsonValue(this.userId))
        map.add("color", optionToJsonValue(this.color))
        map.add("background", optionToJsonValue(this.background))
        map.add("memory_scope", optionToJsonValue(this.memoryScope))
        map.add("isolation_mode", optionToJsonValue(this.isolationMode))
        map.add("max_turns", optionToJsonValue(this.maxTurns))
        map.add("initial_prompt", optionToJsonValue(this.initialPrompt))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("version", optionToJsonValue(this.version))
        map.add("author", optionToJsonValue(this.author))
        map.add("permissions", optionToJsonValue(this.permissions))
        map.add("source_path", optionToJsonValue(this.sourcePath))
        map.add("sync_status", optionToJsonValue(this.syncStatus))
        map.add("last_sync_at", optionToJsonValue(this.lastSyncAt))
        map.add("aic", optionToJsonValue(this.aic))
        map.add("identity_status", this.identityStatus.toJsonValue())
        map.add("aip_registered_at", optionToJsonValue(this.aipRegisteredAt))
        map.add("capabilities", optionToJsonValue(this.capabilities))
        map.add("default_input_types", optionToJsonValue(this.defaultInputTypes))
        map.add("default_output_types", optionToJsonValue(this.defaultOutputTypes))
        map.add("discoverable", this.discoverable.toJsonValue())
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
