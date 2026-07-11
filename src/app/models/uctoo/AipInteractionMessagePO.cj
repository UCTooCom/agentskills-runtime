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
 * AipInteractionMessagePO - aip_interaction_message表持久化对象
 * 
 * 对应数据库表: aip_interaction_message
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_interaction_message"]
public class AipInteractionMessagePO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['message_id']
    public var messageId: String = ""

        @ORMField['session_id']
    public var sessionId: String = ""

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

        @ORMField['sender_role']
    public var senderRole: String = ""

        @ORMField['sender_aic']
    public var senderAic: String = ""

        @ORMField['artifact']
    public var artifact: Option<String> = None<String>

        @ORMField['final']
    public var final: Option<Bool> = None<Bool>

        @ORMField['chunk_index']
    public var chunkIndex: Option<Int32> = None<Int32>

        @ORMField['last_chunk']
    public var lastChunk: Option<Bool> = None<Bool>

        @ORMField['data_items']
    public var dataItems: String = ""

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
                messageId: String,
                sessionId: String,
                taskId: Option<String>,
                senderRole: String,
                senderAic: String,
                artifact: Option<String>,
                final: Option<Bool>,
                chunkIndex: Option<Int32>,
                lastChunk: Option<Bool>,
                dataItems: String,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.messageId = messageId
                this.sessionId = sessionId
                this.taskId = taskId
                this.senderRole = senderRole
                this.senderAic = senderAic
                this.artifact = artifact
                this.final = final
                this.chunkIndex = chunkIndex
                this.lastChunk = lastChunk
                this.dataItems = dataItems
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("message_id", this.messageId.toJsonValue())
        map.add("session_id", this.sessionId.toJsonValue())
        map.add("task_id", optionToJsonValue(this.taskId))
        map.add("sender_role", this.senderRole.toJsonValue())
        map.add("sender_aic", this.senderAic.toJsonValue())
        map.add("artifact", optionToJsonValue(this.artifact))
        map.add("final", optionToJsonValue(this.final))
        map.add("chunk_index", optionToJsonValue(this.chunkIndex))
        map.add("last_chunk", optionToJsonValue(this.lastChunk))
        map.add("data_items", this.dataItems.toJsonValue())
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
