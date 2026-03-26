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
 * UctooSessionPO - uctoo_session表持久化对象
 * 
 * 对应数据库表: uctoo_session
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["uctoo_session"]
public class UctooSessionPO {
        @ORMField[true 'id']
    public var id: String = ""

        @ORMField['user_id']
    public var userId: String = ""

        @ORMField['valid']
    public var valid: Bool = false

        @ORMField['user_agent']
    public var userAgent: ?String = None<String>

        @ORMField['ip']
    public var ip: String = ""

        @ORMField['auth_provider']
    public var authProvider: ?Int32 = None<Int32>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: ?DateTime = None<DateTime>

        @ORMField['deleted_at']
    public var deletedAt: ?DateTime = None<DateTime>

        @ORMField['creator']
    public var creator: ?String = None<String>
    
    public init() {}
    
    public init(
                id: String,
        userId: String,
        valid: Bool,
        userAgent: ?String,
        ip: String,
        authProvider: ?Int32,
        createdAt: DateTime,
        updatedAt: ?DateTime,
        deletedAt: ?DateTime,
        creator: ?String
    ) {
                this.id = id
        this.userId = userId
        this.valid = valid
        this.userAgent = userAgent
        this.ip = ip
        this.authProvider = authProvider
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
        this.creator = creator
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"user_id\":\"${userId}\",")
        sb.append("\"valid\":\"${valid}\",")
        if (let Some(v) <- userAgent) {
            sb.append("\"user_agent\":\"${v}\",")
        } else {
            sb.append("\"user_agent\":\"\",")
        }
        sb.append("\"ip\":\"${ip}\",")
        if (let Some(v) <- authProvider) {
            sb.append("\"auth_provider\":${v},")
        } else {
            sb.append("\"auth_provider\":null,")
        }
        sb.append("\"created_at\":\"${createdAt}\",")
        if (let Some(v) <- updatedAt) {
            sb.append("\"updated_at\":\"${v}\",")
        } else {
            sb.append("\"updated_at\":\"\",")
        }
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\",")
        } else {
            sb.append("\"deleted_at\":\"\",")
        }
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\"")
        } else {
            sb.append("\"creator\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
