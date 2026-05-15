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
 * UctooUserPO - uctoo_user表持久化对象
 * 
 * 对应数据库表: uctoo_user
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["uctoo_user"]
public class UctooUserPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['username']
    public var username: String = ""

        @ORMField['email']
    public var email: String = ""

        @ORMField['password']
    public var password: String = ""

        @ORMField['avatar']
    public var avatar: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['last_login']
    public var lastLogin: DateTime = DateTime.now()

        @ORMField['auth_provider']
    public var authProvider: Int32 = 0

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['last_login_ip']
    public var lastLoginIp: Option<String> = None<String>

        @ORMField['last_login_time']
    public var lastLoginTime: DateTime = DateTime.now()

        @ORMField['remember_token']
    public var rememberToken: Option<String> = None<String>

        @ORMField['status']
    public var status: Int32 = 0

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['access_token']
    public var accessToken: Option<String> = None<String>

        @ORMField['refresh_token']
    public var refreshToken: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                name: String,
                username: String,
                email: String,
                password: String,
                avatar: Option<String>,
                createdAt: DateTime,
                lastLogin: DateTime,
                authProvider: Int32,
                creator: Option<String>,
                deletedAt: Option<DateTime>,
                lastLoginIp: Option<String>,
                lastLoginTime: DateTime,
                rememberToken: Option<String>,
                status: Int32,
                updatedAt: DateTime,
                accessToken: Option<String>,
                refreshToken: Option<String>
    ) {
                this.id = id
                this.name = name
                this.username = username
                this.email = email
                this.password = password
                this.avatar = avatar
                this.createdAt = createdAt
                this.lastLogin = lastLogin
                this.authProvider = authProvider
                this.creator = creator
                this.deletedAt = deletedAt
                this.lastLoginIp = lastLoginIp
                this.lastLoginTime = lastLoginTime
                this.rememberToken = rememberToken
                this.status = status
                this.updatedAt = updatedAt
                this.accessToken = accessToken
                this.refreshToken = refreshToken
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("username", this.username.toJsonValue())
        map.add("email", this.email.toJsonValue())
        map.add("password", this.password.toJsonValue())
        map.add("avatar", optionToJsonValue(this.avatar))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("last_login", this.lastLogin.toJsonValue())
        map.add("auth_provider", this.authProvider.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("last_login_ip", optionToJsonValue(this.lastLoginIp))
        map.add("last_login_time", this.lastLoginTime.toJsonValue())
        map.add("remember_token", optionToJsonValue(this.rememberToken))
        map.add("status", this.status.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("access_token", optionToJsonValue(this.accessToken))
        map.add("refresh_token", optionToJsonValue(this.refreshToken))
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
