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
 * ModelChannelPO - llm_channel表持久化对象
 *
 * 对应数据库表: llm_channel
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["llm_channel"]
public class ModelChannelPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['code']
    public var code: String = ""

        @ORMField['display_name']
    public var displayName: Option<String> = None<String>

        @ORMField['protocol']
    public var protocol: String = ""

        @ORMField['base_url']
    public var baseUrl: Option<String> = None<String>

        @ORMField['secret_ref']
    public var secretRef: Option<String> = None<String>

        @ORMField['default_model']
    public var defaultModel: Option<String> = None<String>

        @ORMField['capabilities']
    public var capabilities: String = ""

        @ORMField['scopes']
    public var scopes: String = ""

        @ORMField['priority']
    public var priority: Int32 = 0

        @ORMField['status']
    public var status: String = ""

        @ORMField['is_default']
    public var isDefault: Bool = false

        @ORMField['health']
    public var health: String = ""

        @ORMField['probe_at']
    public var probeAt: Option<DateTime> = None<DateTime>

        @ORMField['config']
    public var config: String = ""

        @ORMField['revision']
    public var revision: Int64 = 0

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
                code: String,
                displayName: Option<String>,
                protocol: String,
                baseUrl: Option<String>,
                secretRef: Option<String>,
                defaultModel: Option<String>,
                capabilities: String,
                scopes: String,
                priority: Int32,
                status: String,
                isDefault: Bool,
                health: String,
                probeAt: Option<DateTime>,
                config: String,
                revision: Int64,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.code = code
                this.displayName = displayName
                this.protocol = protocol
                this.baseUrl = baseUrl
                this.secretRef = secretRef
                this.defaultModel = defaultModel
                this.capabilities = capabilities
                this.scopes = scopes
                this.priority = priority
                this.status = status
                this.isDefault = isDefault
                this.health = health
                this.probeAt = probeAt
                this.config = config
                this.revision = revision
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("code", this.code.toJsonValue())
        map.add("display_name", optionToJsonValue(this.displayName))
        map.add("protocol", this.protocol.toJsonValue())
        map.add("base_url", optionToJsonValue(this.baseUrl))
        map.add("secret_ref", optionToJsonValue(this.secretRef))
        map.add("default_model", optionToJsonValue(this.defaultModel))
        map.add("capabilities", this.capabilities.toJsonValue())
        map.add("scopes", this.scopes.toJsonValue())
        map.add("priority", this.priority.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("is_default", this.isDefault.toJsonValue())
        map.add("health", this.health.toJsonValue())
        map.add("probe_at", optionToJsonValue(this.probeAt))
        map.add("config", this.config.toJsonValue())
        map.add("revision", this.revision.toJsonValue())
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
