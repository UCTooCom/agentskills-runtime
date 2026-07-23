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
 * ConfigPO - config表持久化对象
 * 
 * 对应数据库表: config
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["config"]
public class ConfigPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['parent_id']
    public var parentId: Option<String> = None<String>

        @ORMField['component']
    public var component: String = ""

        @ORMField['key']
    public var key: String = ""

        @ORMField['value']
    public var value: Option<String> = None<String>

        @ORMField['status']
    public var status: Int32 = 0

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['env_key']
    public var envKey: Option<String> = None<String>

        @ORMField['config_group']
    public var configGroup: Option<String> = None<String>

        @ORMField['config_type']
    public var configType: Option<String> = None<String>

        @ORMField['is_sensitive']
    public var isSensitive: Option<Bool> = None<Bool>

        @ORMField['default_value']
    public var defaultValue: Option<String> = None<String>

        @ORMField['validation_rule']
    public var validationRule: Option<String> = None<String>

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['display_order']
    public var displayOrder: Option<Int32> = None<Int32>

        @ORMField['editable']
    public var editable: Option<Bool> = None<Bool>

        @ORMField['last_synced_at']
    public var lastSyncedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                name: String,
                parentId: Option<String>,
                component: String,
                key: String,
                value: Option<String>,
                status: Int32,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                envKey: Option<String>,
                configGroup: Option<String>,
                configType: Option<String>,
                isSensitive: Option<Bool>,
                defaultValue: Option<String>,
                validationRule: Option<String>,
                description: Option<String>,
                displayOrder: Option<Int32>,
                editable: Option<Bool>,
                lastSyncedAt: Option<DateTime>
    ) {
                this.id = id
                this.name = name
                this.parentId = parentId
                this.component = component
                this.key = key
                this.value = value
                this.status = status
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.envKey = envKey
                this.configGroup = configGroup
                this.configType = configType
                this.isSensitive = isSensitive
                this.defaultValue = defaultValue
                this.validationRule = validationRule
                this.description = description
                this.displayOrder = displayOrder
                this.editable = editable
                this.lastSyncedAt = lastSyncedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("parent_id", optionToJsonValue(this.parentId))
        map.add("component", this.component.toJsonValue())
        map.add("key", this.key.toJsonValue())
        map.add("value", optionToJsonValue(this.value))
        map.add("status", this.status.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("env_key", optionToJsonValue(this.envKey))
        map.add("config_group", optionToJsonValue(this.configGroup))
        map.add("config_type", optionToJsonValue(this.configType))
        map.add("is_sensitive", optionToJsonValue(this.isSensitive))
        map.add("default_value", optionToJsonValue(this.defaultValue))
        map.add("validation_rule", optionToJsonValue(this.validationRule))
        map.add("description", optionToJsonValue(this.description))
        map.add("display_order", optionToJsonValue(this.displayOrder))
        map.add("editable", optionToJsonValue(this.editable))
        map.add("last_synced_at", optionToJsonValue(this.lastSyncedAt))
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
