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
 * MessagesPO - messages表持久化对象
 * 
 * 对应数据库表: messages
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["messages"]
public class MessagesPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['user_id']
    public var userId: String = ""

        @ORMField['sender_id']
    public var senderId: Option<String> = None<String>

        @ORMField['message_type']
    public var messageType: String = ""

        @ORMField['title']
    public var title: String = ""

        @ORMField['content']
    public var content: String = ""

        @ORMField['msg_related_type']
    public var msgRelatedType: Option<String> = None<String>

        @ORMField['related_id']
    public var relatedId: Option<String> = None<String>

        @ORMField['is_read']
    public var isRead: Bool = false

        @ORMField['read_at']
    public var readAt: Option<DateTime> = None<DateTime>

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
                userId: String,
                senderId: Option<String>,
                messageType: String,
                title: String,
                content: String,
                msgRelatedType: Option<String>,
                relatedId: Option<String>,
                isRead: Bool,
                readAt: Option<DateTime>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.userId = userId
                this.senderId = senderId
                this.messageType = messageType
                this.title = title
                this.content = content
                this.msgRelatedType = msgRelatedType
                this.relatedId = relatedId
                this.isRead = isRead
                this.readAt = readAt
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("user_id", this.userId.toJsonValue())
        map.add("sender_id", optionToJsonValue(this.senderId))
        map.add("message_type", this.messageType.toJsonValue())
        map.add("title", this.title.toJsonValue())
        map.add("content", this.content.toJsonValue())
        map.add("msg_related_type", optionToJsonValue(this.msgRelatedType))
        map.add("related_id", optionToJsonValue(this.relatedId))
        map.add("is_read", this.isRead.toJsonValue())
        map.add("read_at", optionToJsonValue(this.readAt))
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
