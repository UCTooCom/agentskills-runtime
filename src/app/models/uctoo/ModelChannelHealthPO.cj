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
 * ModelChannelHealthPO - llm_channel_health表持久化对象
 *
 * 对应数据库表: llm_channel_health
 * 遵循UCTOO V4 ORM规范（追加日志表，无软删/updated_at）
 */
@DataAssist[fields]
@QueryMappersGenerator["llm_channel_health"]
public class ModelChannelHealthPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['channel_id']
    public var channelId: String = ""

        @ORMField['model_id']
    public var modelId: Option<String> = None<String>

        @ORMField['ok']
    public var ok: Bool = false

        @ORMField['latency_ms']
    public var latencyMs: Int32 = 0

        @ORMField['error_code']
    public var errorCode: Option<String> = None<String>

        @ORMField['error_message']
    public var errorMessage: Option<String> = None<String>

        @ORMField['checked_at']
    public var checkedAt: DateTime = DateTime.now()

    public init() {}

    public init(
                id: String,
                channelId: String,
                modelId: Option<String>,
                ok: Bool,
                latencyMs: Int32,
                errorCode: Option<String>,
                errorMessage: Option<String>,
                checkedAt: DateTime
    ) {
                this.id = id
                this.channelId = channelId
                this.modelId = modelId
                this.ok = ok
                this.latencyMs = latencyMs
                this.errorCode = errorCode
                this.errorMessage = errorMessage
                this.checkedAt = checkedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("channel_id", this.channelId.toJsonValue())
        map.add("model_id", optionToJsonValue(this.modelId))
        map.add("ok", this.ok.toJsonValue())
        map.add("latency_ms", this.latencyMs.toJsonValue())
        map.add("error_code", optionToJsonValue(this.errorCode))
        map.add("error_message", optionToJsonValue(this.errorMessage))
        map.add("checked_at", this.checkedAt.toJsonValue())
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
