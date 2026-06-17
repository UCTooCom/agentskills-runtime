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
 * UsageQuotasPO - usage_quotas表持久化对象
 * 
 * 对应数据库表: usage_quotas
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["usage_quotas"]
public class UsageQuotasPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['target_type']
    public var targetType: String = ""

        @ORMField['target_id']
    public var targetId: String = ""

        @ORMField['quota_type']
    public var quotaType: String = ""

        @ORMField['quota_limit']
    public var quotaLimit: Float64 = 0.0

        @ORMField['quota_used']
    public var quotaUsed: Float64 = 0.0

        @ORMField['quota_period_start']
    public var quotaPeriodStart: String = ""

        @ORMField['is_hard_limit']
    public var isHardLimit: Bool = false

        @ORMField['alert_threshold']
    public var alertThreshold: Float64 = 0.0

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
                targetType: String,
                targetId: String,
                quotaType: String,
                quotaLimit: Float64,
                quotaUsed: Float64,
                quotaPeriodStart: String,
                isHardLimit: Bool,
                alertThreshold: Float64,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.targetType = targetType
                this.targetId = targetId
                this.quotaType = quotaType
                this.quotaLimit = quotaLimit
                this.quotaUsed = quotaUsed
                this.quotaPeriodStart = quotaPeriodStart
                this.isHardLimit = isHardLimit
                this.alertThreshold = alertThreshold
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("target_type", this.targetType.toJsonValue())
        map.add("target_id", this.targetId.toJsonValue())
        map.add("quota_type", this.quotaType.toJsonValue())
        map.add("quota_limit", this.quotaLimit.toJsonValue())
        map.add("quota_used", this.quotaUsed.toJsonValue())
        map.add("quota_period_start", this.quotaPeriodStart.toJsonValue())
        map.add("is_hard_limit", this.isHardLimit.toJsonValue())
        map.add("alert_threshold", this.alertThreshold.toJsonValue())
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
