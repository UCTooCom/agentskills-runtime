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
 * AipInteractionSessionPO - aip_interaction_session表持久化对象
 * 
 * 对应数据库表: aip_interaction_session
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_interaction_session"]
public class AipInteractionSessionPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['session_id']
    public var sessionId: String = ""

        @ORMField['requester_agent_id']
    public var requesterAgentId: String = ""

        @ORMField['requester_aic']
    public var requesterAic: String = ""

        @ORMField['interaction_mode']
    public var interactionMode: String = ""

        @ORMField['receivers']
    public var receivers: String = ""

        @ORMField['context']
    public var context: Option<String> = None<String>

        @ORMField['session_status']
    public var sessionStatus: String = ""

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
                sessionId: String,
                requesterAgentId: String,
                requesterAic: String,
                interactionMode: String,
                receivers: String,
                context: Option<String>,
                sessionStatus: String,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.sessionId = sessionId
                this.requesterAgentId = requesterAgentId
                this.requesterAic = requesterAic
                this.interactionMode = interactionMode
                this.receivers = receivers
                this.context = context
                this.sessionStatus = sessionStatus
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("session_id", this.sessionId.toJsonValue())
        map.add("requester_agent_id", this.requesterAgentId.toJsonValue())
        map.add("requester_aic", this.requesterAic.toJsonValue())
        map.add("interaction_mode", this.interactionMode.toJsonValue())
        map.add("receivers", this.receivers.toJsonValue())
        map.add("context", optionToJsonValue(this.context))
        map.add("session_status", this.sessionStatus.toJsonValue())
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
