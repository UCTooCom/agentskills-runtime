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
 * I18PO - i18表持久化对象
 * 
 * 对应数据库表: i18
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["i18"]
public class I18PO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['key']
    public var key: String = ""

        @ORMField['content']
    public var content: String = ""

        @ORMField['lang_id']
    public var langId: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: Option<DateTime> = None<DateTime>

        @ORMField['updated_at']
    public var updatedAt: Option<DateTime> = None<DateTime>

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                key: String,
                content: String,
                langId: Option<String>,
                creator: Option<String>,
                createdAt: Option<DateTime>,
                updatedAt: Option<DateTime>,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.key = key
                this.content = content
                this.langId = langId
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("key", this.key.toJsonValue())
        map.add("content", this.content.toJsonValue())
        map.add("lang_id", optionToJsonValue(this.langId))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", optionToJsonValue(this.createdAt))
        map.add("updated_at", optionToJsonValue(this.updatedAt))
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