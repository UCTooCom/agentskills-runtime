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
 * SmsLogPO - sms_log表持久化对象
 * 
 * 对应数据库表: sms_log
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["sms_log"]
public class SmsLogPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['event']
    public var event: String = ""

        @ORMField['mobile']
    public var mobile: Option<String> = None<String>

        @ORMField['code']
    public var code: String = ""

        @ORMField['times']
    public var times: Int32 = 0

        @ORMField['ip']
    public var ip: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['email']
    public var email: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                event: String,
                mobile: Option<String>,
                code: String,
                times: Int32,
                ip: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                email: Option<String>
    ) {
                this.id = id
                this.event = event
                this.mobile = mobile
                this.code = code
                this.times = times
                this.ip = ip
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.email = email
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("event", this.event.toJsonValue())
        map.add("mobile", optionToJsonValue(this.mobile))
        map.add("code", this.code.toJsonValue())
        map.add("times", this.times.toJsonValue())
        map.add("ip", optionToJsonValue(this.ip))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("email", optionToJsonValue(this.email))
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
