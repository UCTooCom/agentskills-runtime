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
 * UctooSessionPO - uctoo_session表持久化对象
 * 
 * 对应数据库表: uctoo_session
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["uctoo_session"]
public class UctooSessionPO {
        @ORMField['user_id']
    public var userId: String = ""

        @ORMField['valid']
    public var valid: Bool = false

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['user_agent']
    public var userAgent: Option<String> = None<String>

        @ORMField['ip']
    public var ip: String = ""

        @ORMField['auth_provider']
    public var authProvider: Int32 = 0

        @ORMField['id']
    public var id: String = ""

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

    public init() {}

    public init(
                userId: String,
                valid: Bool,
                createdAt: DateTime,
                updatedAt: DateTime,
                userAgent: Option<String>,
                ip: String,
                authProvider: Int32,
                id: String,
                deletedAt: Option<DateTime>,
                creator: Option<String>
    ) {
                this.userId = userId
                this.valid = valid
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.userAgent = userAgent
                this.ip = ip
                this.authProvider = authProvider
                this.id = id
                this.deletedAt = deletedAt
                this.creator = creator
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("user_id", this.userId.toJsonValue())
        map.add("valid", this.valid.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("user_agent", optionToJsonValue(this.userAgent))
        map.add("ip", this.ip.toJsonValue())
        map.add("auth_provider", this.authProvider.toJsonValue())
        map.add("id", this.id.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("creator", optionToJsonValue(this.creator))
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
