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
 * DbConnectionPO - db_connection表持久化对象
 * 
 * 对应数据库表: db_connection
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["db_connection"]
public class DbConnectionPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['user']
    public var user: String = ""

        @ORMField['password']
    public var password: String = ""

        @ORMField['host']
    public var host: String = ""

        @ORMField['port']
    public var port: String = ""

        @ORMField['database_name']
    public var databaseName: String = ""

        @ORMField['ssl']
    public var ssl: Int32 = 0

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['provider']
    public var provider: String = ""

        @ORMField['type']
    public var typeVal: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                user: String,
                password: String,
                host: String,
                port: String,
                databaseName: String,
                ssl: Int32,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                provider: String,
                typeVal: Option<String>
    ) {
                this.id = id
                this.user = user
                this.password = password
                this.host = host
                this.port = port
                this.databaseName = databaseName
                this.ssl = ssl
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.provider = provider
                this.typeVal = typeVal
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("user", this.user.toJsonValue())
        map.add("password", this.password.toJsonValue())
        map.add("host", this.host.toJsonValue())
        map.add("port", this.port.toJsonValue())
        map.add("database_name", this.databaseName.toJsonValue())
        map.add("ssl", this.ssl.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("provider", this.provider.toJsonValue())
        map.add("type", optionToJsonValue(this.typeVal))
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
