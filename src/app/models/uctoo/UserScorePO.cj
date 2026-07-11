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
 * UserScorePO - user_score表持久化对象
 * 
 * 对应数据库表: user_score
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["user_score"]
public class UserScorePO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['user_id']
    public var userId: String = ""

        @ORMField['appid']
    public var appid: Option<String> = None<String>

        @ORMField['from_umodel']
    public var fromUmodel: String = ""

        @ORMField['total_score']
    public var totalScore: Int32 = 0

        @ORMField['team_score']
    public var teamScore: Int32 = 0

        @ORMField['volunteer_score']
    public var volunteerScore: Int32 = 0

        @ORMField['event_score']
    public var eventScore: Int32 = 0

        @ORMField['ext_score']
    public var extScore: Option<String> = None<String>

        @ORMField['medals']
    public var medals: Option<String> = None<String>

        @ORMField['total_times']
    public var totalTimes: Option<Int32> = None<Int32>

        @ORMField['total_medals']
    public var totalMedals: Option<Int32> = None<Int32>

        @ORMField['annual_times']
    public var annualTimes: Option<Int32> = None<Int32>

        @ORMField['annual_medals']
    public var annualMedals: Option<Int32> = None<Int32>

        @ORMField['monthly_times']
    public var monthlyTimes: Option<Int32> = None<Int32>

        @ORMField['monthly_medals']
    public var monthlyMedals: Option<Int32> = None<Int32>

        @ORMField['ext_info']
    public var extInfo: Option<String> = None<String>

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
                appid: Option<String>,
                fromUmodel: String,
                totalScore: Int32,
                teamScore: Int32,
                volunteerScore: Int32,
                eventScore: Int32,
                extScore: Option<String>,
                medals: Option<String>,
                totalTimes: Option<Int32>,
                totalMedals: Option<Int32>,
                annualTimes: Option<Int32>,
                annualMedals: Option<Int32>,
                monthlyTimes: Option<Int32>,
                monthlyMedals: Option<Int32>,
                extInfo: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.userId = userId
                this.appid = appid
                this.fromUmodel = fromUmodel
                this.totalScore = totalScore
                this.teamScore = teamScore
                this.volunteerScore = volunteerScore
                this.eventScore = eventScore
                this.extScore = extScore
                this.medals = medals
                this.totalTimes = totalTimes
                this.totalMedals = totalMedals
                this.annualTimes = annualTimes
                this.annualMedals = annualMedals
                this.monthlyTimes = monthlyTimes
                this.monthlyMedals = monthlyMedals
                this.extInfo = extInfo
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
        map.add("appid", optionToJsonValue(this.appid))
        map.add("from_umodel", this.fromUmodel.toJsonValue())
        map.add("total_score", this.totalScore.toJsonValue())
        map.add("team_score", this.teamScore.toJsonValue())
        map.add("volunteer_score", this.volunteerScore.toJsonValue())
        map.add("event_score", this.eventScore.toJsonValue())
        map.add("ext_score", optionToJsonValue(this.extScore))
        map.add("medals", optionToJsonValue(this.medals))
        map.add("total_times", optionToJsonValue(this.totalTimes))
        map.add("total_medals", optionToJsonValue(this.totalMedals))
        map.add("annual_times", optionToJsonValue(this.annualTimes))
        map.add("annual_medals", optionToJsonValue(this.annualMedals))
        map.add("monthly_times", optionToJsonValue(this.monthlyTimes))
        map.add("monthly_medals", optionToJsonValue(this.monthlyMedals))
        map.add("ext_info", optionToJsonValue(this.extInfo))
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
