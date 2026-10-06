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
 * ModelChannelModelPO - llm_channel_model表持久化对象
 *
 * 对应数据库表: llm_channel_model
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["llm_channel_model"]
public class ModelChannelModelPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['channel_id']
    public var channelId: String = ""

        @ORMField['model_id']
    public var modelId: String = ""

        @ORMField['display_name']
    public var displayName: Option<String> = None<String>

        @ORMField['capabilities']
    public var capabilities: String = ""

        @ORMField['context_len']
    public var contextLen: Int32 = 0

        @ORMField['max_output']
    public var maxOutput: Int32 = 0

        @ORMField['pricing_ref']
    public var pricingRef: Option<String> = None<String>

        @ORMField['status']
    public var status: String = ""

        @ORMField['probed_at']
    public var probedAt: Option<DateTime> = None<DateTime>

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
                channelId: String,
                modelId: String,
                displayName: Option<String>,
                capabilities: String,
                contextLen: Int32,
                maxOutput: Int32,
                pricingRef: Option<String>,
                status: String,
                probedAt: Option<DateTime>,
                revision: Int64,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.channelId = channelId
                this.modelId = modelId
                this.displayName = displayName
                this.capabilities = capabilities
                this.contextLen = contextLen
                this.maxOutput = maxOutput
                this.pricingRef = pricingRef
                this.status = status
                this.probedAt = probedAt
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
        map.add("channel_id", this.channelId.toJsonValue())
        map.add("model_id", this.modelId.toJsonValue())
        map.add("display_name", optionToJsonValue(this.displayName))
        map.add("capabilities", this.capabilities.toJsonValue())
        map.add("context_len", this.contextLen.toJsonValue())
        map.add("max_output", this.maxOutput.toJsonValue())
        map.add("pricing_ref", optionToJsonValue(this.pricingRef))
        map.add("status", this.status.toJsonValue())
        map.add("probed_at", optionToJsonValue(this.probedAt))
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
