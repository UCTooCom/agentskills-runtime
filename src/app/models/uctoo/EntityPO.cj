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
 * EntityPO - entity表持久化对象
 * 
 * 对应数据库表: entity
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["entity"]
public class EntityPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['link']
    public var link: String = ""

        @ORMField['privacy_level']
    public var privacyLevel: Int32 = 0

        @ORMField['stars']
    public var stars: Float64 = 0.0

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['group_id']
    public var groupId: Option<String> = None<String>

        @ORMField['picture']
    public var picture: Option<String> = None<String>

        @ORMField['images']
    public var images: Option<String> = None<String>

        @ORMField['content']
    public var content: Option<String> = None<String>

        @ORMField['json']
    public var json: Option<String> = None<String>

        @ORMField['city']
    public var city: Option<String> = None<String>

        @ORMField['price']
    public var price: Option<Float64> = None<Float64>

        @ORMField['birthday']
    public var birthday: Option<DateTime> = None<DateTime>

        @ORMField['owner']
    public var owner: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['end_time']
    public var endTime: Option<DateTime> = None<DateTime>

        @ORMField['start_time']
    public var startTime: Option<DateTime> = None<DateTime>

        @ORMField['status']
    public var status: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                link: String,
                privacyLevel: Int32,
                stars: Float64,
                description: Option<String>,
                groupId: Option<String>,
                picture: Option<String>,
                images: Option<String>,
                content: Option<String>,
                json: Option<String>,
                city: Option<String>,
                price: Option<Float64>,
                birthday: Option<DateTime>,
                owner: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                endTime: Option<DateTime>,
                startTime: Option<DateTime>,
                status: Option<String>
    ) {
                this.id = id
                this.link = link
                this.privacyLevel = privacyLevel
                this.stars = stars
                this.description = description
                this.groupId = groupId
                this.picture = picture
                this.images = images
                this.content = content
                this.json = json
                this.city = city
                this.price = price
                this.birthday = birthday
                this.owner = owner
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.endTime = endTime
                this.startTime = startTime
                this.status = status
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("link", this.link.toJsonValue())
        map.add("privacy_level", this.privacyLevel.toJsonValue())
        map.add("stars", this.stars.toJsonValue())
        map.add("description", optionToJsonValue(this.description))
        map.add("group_id", optionToJsonValue(this.groupId))
        map.add("picture", optionToJsonValue(this.picture))
        map.add("images", optionToJsonValue(this.images))
        map.add("content", optionToJsonValue(this.content))
        map.add("json", optionToJsonValue(this.json))
        map.add("city", optionToJsonValue(this.city))
        map.add("price", optionToJsonValue(this.price))
        map.add("birthday", optionToJsonValue(this.birthday))
        map.add("owner", optionToJsonValue(this.owner))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("end_time", optionToJsonValue(this.endTime))
        map.add("start_time", optionToJsonValue(this.startTime))
        map.add("status", optionToJsonValue(this.status))
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
