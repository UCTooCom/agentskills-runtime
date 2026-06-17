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
 * EventHandlersPO - event_handlers表持久化对象
 * 
 * 对应数据库表: event_handlers
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["event_handlers"]
public class EventHandlersPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['event_type']
    public var eventType: String = ""

        @ORMField['handler_name']
    public var handlerName: String = ""

        @ORMField['handler_class']
    public var handlerClass: String = ""

        @ORMField['status']
    public var status: String = ""

        @ORMField['config']
    public var config: String = ""

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
                eventType: String,
                handlerName: String,
                handlerClass: String,
                status: String,
                config: String,
                description: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.eventType = eventType
                this.handlerName = handlerName
                this.handlerClass = handlerClass
                this.status = status
                this.config = config
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
        map.add("event_type", this.eventType.toJsonValue())
        map.add("handler_name", this.handlerName.toJsonValue())
        map.add("handler_class", this.handlerClass.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("config", this.config.toJsonValue())
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
