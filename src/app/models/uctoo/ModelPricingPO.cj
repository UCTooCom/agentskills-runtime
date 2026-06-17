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
 * ModelPricingPO - model_pricing表持久化对象
 * 
 * 对应数据库表: model_pricing
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["model_pricing"]
public class ModelPricingPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['provider']
    public var provider: String = ""

        @ORMField['model']
    public var model: String = ""

        @ORMField['model_id']
    public var modelId: String = ""

        @ORMField['rate_prompt_per_million']
    public var ratePromptPerMillion: Float64 = 0.0

        @ORMField['rate_completion_per_million']
    public var rateCompletionPerMillion: Float64 = 0.0

        @ORMField['rate_currency']
    public var rateCurrency: String = ""

        @ORMField['rate_unit']
    public var rateUnit: String = ""

        @ORMField['is_active']
    public var isActive: Bool = false

        @ORMField['effective_from']
    public var effectiveFrom: String = ""

        @ORMField['effective_to']
    public var effectiveTo: Option<String> = None<String>

        @ORMField['source']
    public var source: String = ""

        @ORMField['remark']
    public var remark: Option<String> = None<String>

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
                provider: String,
                model: String,
                modelId: String,
                ratePromptPerMillion: Float64,
                rateCompletionPerMillion: Float64,
                rateCurrency: String,
                rateUnit: String,
                isActive: Bool,
                effectiveFrom: String,
                effectiveTo: Option<String>,
                source: String,
                remark: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.provider = provider
                this.model = model
                this.modelId = modelId
                this.ratePromptPerMillion = ratePromptPerMillion
                this.rateCompletionPerMillion = rateCompletionPerMillion
                this.rateCurrency = rateCurrency
                this.rateUnit = rateUnit
                this.isActive = isActive
                this.effectiveFrom = effectiveFrom
                this.effectiveTo = effectiveTo
                this.source = source
                this.remark = remark
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("provider", this.provider.toJsonValue())
        map.add("model", this.model.toJsonValue())
        map.add("model_id", this.modelId.toJsonValue())
        map.add("rate_prompt_per_million", this.ratePromptPerMillion.toJsonValue())
        map.add("rate_completion_per_million", this.rateCompletionPerMillion.toJsonValue())
        map.add("rate_currency", this.rateCurrency.toJsonValue())
        map.add("rate_unit", this.rateUnit.toJsonValue())
        map.add("is_active", this.isActive.toJsonValue())
        map.add("effective_from", this.effectiveFrom.toJsonValue())
        map.add("effective_to", optionToJsonValue(this.effectiveTo))
        map.add("source", this.source.toJsonValue())
        map.add("remark", optionToJsonValue(this.remark))
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
