/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * UctooRolePO - uctoo_role表持久化对象
 * 
 * 对应数据库表: uctoo_role
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["uctoo_role"]
public class UctooRolePO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['created_at']
    public var createdAt: Option<DateTime> = None<DateTime>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['updated_at']
    public var updatedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                name: String,
                createdAt: Option<DateTime>,
                creator: Option<String>,
                deletedAt: Option<DateTime>,
                updatedAt: Option<DateTime>
    ) {
                this.id = id
                this.name = name
                this.createdAt = createdAt
                this.creator = creator
                this.deletedAt = deletedAt
                this.updatedAt = updatedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("created_at", optionToJsonValue(this.createdAt))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("updated_at", optionToJsonValue(this.updatedAt))
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
