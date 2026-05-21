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
 * CrontabLogPO - crontab_log表持久化对象
 * 
 * 对应数据库表: crontab_log
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["crontab_log"]
public class CrontabLogPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['crontab_id']
    public var crontabId: String = ""

        @ORMField['used_time']
    public var usedTime: Int32 = 0

        @ORMField['error_message']
    public var errorMessage: String = ""

        @ORMField['status']
    public var status: Int32 = 0

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['start_time']
    public var startTime: Option<DateTime> = None<DateTime>

        @ORMField['end_time']
    public var endTime: Option<DateTime> = None<DateTime>

        @ORMField['trigger_type']
    public var triggerType: Option<String> = None<String>

        @ORMField['retry_attempt']
    public var retryAttempt: Option<Int32> = None<Int32>

        @ORMField['executor_type']
    public var executorType: Option<String> = None<String>

        @ORMField['result_summary']
    public var resultSummary: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                crontabId: String,
                usedTime: Int32,
                errorMessage: String,
                status: Int32,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                startTime: Option<DateTime>,
                endTime: Option<DateTime>,
                triggerType: Option<String>,
                retryAttempt: Option<Int32>,
                executorType: Option<String>,
                resultSummary: Option<String>
    ) {
                this.id = id
                this.crontabId = crontabId
                this.usedTime = usedTime
                this.errorMessage = errorMessage
                this.status = status
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.startTime = startTime
                this.endTime = endTime
                this.triggerType = triggerType
                this.retryAttempt = retryAttempt
                this.executorType = executorType
                this.resultSummary = resultSummary
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("crontab_id", this.crontabId.toJsonValue())
        map.add("used_time", this.usedTime.toJsonValue())
        map.add("error_message", this.errorMessage.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("start_time", optionToJsonValue(this.startTime))
        map.add("end_time", optionToJsonValue(this.endTime))
        map.add("trigger_type", optionToJsonValue(this.triggerType))
        map.add("retry_attempt", optionToJsonValue(this.retryAttempt))
        map.add("executor_type", optionToJsonValue(this.executorType))
        map.add("result_summary", optionToJsonValue(this.resultSummary))
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
