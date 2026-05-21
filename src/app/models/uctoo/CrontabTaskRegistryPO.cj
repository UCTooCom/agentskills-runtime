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
 * CrontabTaskRegistryPO - crontab_task_registry表持久化对象
 * 
 * 对应数据库表: crontab_task_registry
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["crontab_task_registry"]
public class CrontabTaskRegistryPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['type']
    public var typeVal: String = ""

        @ORMField['prefix']
    public var prefix: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['parameters_template']
    public var parametersTemplate: Option<String> = None<String>

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
                typeVal: String,
                prefix: String,
                name: String,
                description: Option<String>,
                parametersTemplate: Option<String>,
                status: Option<Int32>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.typeVal = typeVal
                this.prefix = prefix
                this.name = name
                this.description = description
                this.parametersTemplate = parametersTemplate
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
        map.add("type", this.typeVal.toJsonValue())
        map.add("prefix", this.prefix.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("description", optionToJsonValue(this.description))
        map.add("parameters_template", optionToJsonValue(this.parametersTemplate))
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
