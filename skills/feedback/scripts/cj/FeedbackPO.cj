/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.feedback

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.HashMap
import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonNull}

/**
 * FeedbackPO - feedback表持久化对象
 *
 * 对应数据库表: feedback（库 uctoo）
 * 由 plugingen 生成（插件轨，design.md §2.6 包名规范）
 */
@DataAssist[fields]
@QueryMappersGenerator["feedback"]
public class FeedbackPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['user_id']
    public var userId: String = ""

    @ORMField['type']
    public var feedbackType: Option<String> = None<String>

    @ORMField['content']
    public var content: Option<String> = None<String>

    @ORMField['images']
    public var images: Option<String> = None<String>

    @ORMField['phone']
    public var phone: Option<String> = None<String>

    @ORMField['remark']
    public var remark: Option<String> = None<String>

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


    public init() {}

    public init(
        id: String,
        userId: String,
        feedbackType: Option<String>,
        content: Option<String>,
        images: Option<String>,
        phone: Option<String>,
        remark: Option<String>,
        status: Int32,
        creator: Option<String>,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: Option<DateTime>
    ) {
        this.id = id
        this.userId = userId
        this.feedbackType = feedbackType
        this.content = content
        this.images = images
        this.phone = phone
        this.remark = remark
        this.status = status
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
        map.add("type", optionToJsonValue(this.feedbackType))
        map.add("content", optionToJsonValue(this.content))
        map.add("images", optionToJsonValue(this.images))
        map.add("phone", optionToJsonValue(this.phone))
        map.add("remark", optionToJsonValue(this.remark))
        map.add("status", this.status.toJsonValue())
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
