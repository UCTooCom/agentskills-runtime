/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * UctooUserPO - uctoo_user表持久化对象
 * 
 * 对应数据库表: uctoo_user
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["uctoo_user"]
public class UctooUserPO {
        @ORMField[true 'id']
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
    public var avatar: ?String = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['last_login']
    public var lastLogin: DateTime = DateTime.now()

        @ORMField['auth_provider']
    public var authProvider: ?Int32 = None<Int32>

        @ORMField['creator']
    public var creator: ?String = None<String>

        @ORMField['deleted_at']
    public var deletedAt: ?DateTime = None<DateTime>

        @ORMField['last_login_ip']
    public var lastLoginIp: ?String = None<String>

        @ORMField['last_login_time']
    public var lastLoginTime: DateTime = DateTime.now()

        @ORMField['remember_token']
    public var rememberToken: ?String = None<String>

        @ORMField['status']
    public var status: ?Int32 = None<Int32>

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['access_token']
    public var accessToken: ?String = None<String>

        @ORMField['refresh_token']
    public var refreshToken: ?String = None<String>

    public init() {}
    
    public init(
                id: String,
        name: String,
        username: String,
        email: String,
        password: String,
        avatar: ?String,
        createdAt: DateTime,
        lastLogin: DateTime,
        authProvider: ?Int32,
        creator: ?String,
        deletedAt: ?DateTime,
        lastLoginIp: ?String,
        lastLoginTime: DateTime,
        rememberToken: ?String,
        status: ?Int32,
        updatedAt: DateTime,
        accessToken: ?String,
        refreshToken: ?String
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
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"name\":\"${name}\",")
        sb.append("\"username\":\"${username}\",")
        sb.append("\"email\":\"${email}\",")
        sb.append("\"password\":\"${password}\",")
        if (let Some(v) <- avatar) {
            sb.append("\"avatar\":\"${v}\",")
        } else {
            sb.append("\"avatar\":\"\",")
        }
        sb.append("\"created_at\":\"${createdAt}\",")
        sb.append("\"last_login\":\"${lastLogin}\",")
        if (let Some(v) <- authProvider) {
            sb.append("\"auth_provider\":${v},")
        } else {
            sb.append("\"auth_provider\":null,")
        }
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\",")
        } else {
            sb.append("\"deleted_at\":\"\",")
        }
        if (let Some(v) <- lastLoginIp) {
            sb.append("\"last_login_ip\":\"${v}\",")
        } else {
            sb.append("\"last_login_ip\":\"\",")
        }
        sb.append("\"last_login_time\":\"${lastLoginTime}\",")
        if (let Some(v) <- rememberToken) {
            sb.append("\"remember_token\":\"${v}\",")
        } else {
            sb.append("\"remember_token\":\"\",")
        }
        if (let Some(v) <- status) {
            sb.append("\"status\":${v},")
        } else {
            sb.append("\"status\":null,")
        }
        sb.append("\"updated_at\":\"${updatedAt}\",")
        if (let Some(v) <- accessToken) {
            sb.append("\"access_token\":\"${v}\"")
        } else {
            sb.append("\"access_token\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
