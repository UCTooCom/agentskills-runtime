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
 * AppAccessTokenPO - app_access_token表持久化对象
 * 
 * 对应数据库表: app_access_token
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["app_access_token"]
public class AppAccessTokenPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['access_token']
    public var accessToken: ?String = None<String>

        @ORMField['token_overtime']
    public var tokenOvertime: ?DateTime = None<DateTime>

        @ORMField['creator']
    public var creator: ?String = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        accessToken: ?String,
        tokenOvertime: ?DateTime,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.accessToken = accessToken
        this.tokenOvertime = tokenOvertime
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        if (let Some(v) <- accessToken) {
            sb.append("\"access_token\":\"${v}\",")
        } else {
            sb.append("\"access_token\":\"\",")
        }
        if (let Some(v) <- tokenOvertime) {
            sb.append("\"token_overtime\":\"${v}\",")
        } else {
            sb.append("\"token_overtime\":\"\",")
        }
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        sb.append("\"created_at\":\"${createdAt}\",")
        sb.append("\"updated_at\":\"${updatedAt}\",")
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\"")
        } else {
            sb.append("\"deleted_at\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
