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
 * ModelChannelAuditPO - llm_channel_audit表持久化对象
 *
 * 对应数据库表: llm_channel_audit
 * 遵循UCTOO V4 ORM规范（追加审计日志表，无 updated_at/deleted_at）
 */
@DataAssist[fields]
@QueryMappersGenerator["llm_channel_audit"]
public class ModelChannelAuditPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['channel_id']
    public var channelId: Option<String> = None<String>

        @ORMField['action']
    public var action: String = ""

        @ORMField['before']
    public var before: String = ""

        @ORMField['after']
    public var after: String = ""

        @ORMField['operator']
    public var operatorUser: Option<String> = None<String>

        @ORMField['source']
    public var source: String = ""

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    public init() {}

    public init(
                id: String,
                channelId: Option<String>,
                action: String,
                before: String,
                after: String,
                operatorUser: Option<String>,
                source: String,
                createdAt: DateTime
    ) {
                this.id = id
                this.channelId = channelId
                this.action = action
                this.before = before
                this.after = after
                this.operatorUser = operatorUser
                this.source = source
                this.createdAt = createdAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("channel_id", optionToJsonValue(this.channelId))
        map.add("action", this.action.toJsonValue())
        map.add("before", this.before.toJsonValue())
        map.add("after", this.after.toJsonValue())
        map.add("operator", optionToJsonValue(this.operatorUser))
        map.add("source", this.source.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
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
