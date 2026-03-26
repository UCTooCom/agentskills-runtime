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
 * UserHasAccountPO - user_has_account表持久化对象
 * 
 * 对应数据库表: user_has_account
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["user_has_account"]
public class UserHasAccountPO {
        @ORMField[true 'id']
    private var id: String = ""

        @ORMField['user_id']
    private var userId: String = ""

        @ORMField['account_id']
    private var accountId: String = ""

        @ORMField['account_type']
    private var accountType: String = ""

        @ORMField['creator']
    private var creator: ?String = None<String>

        @ORMField['created_at']
    private var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>

        @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        userId: String,
        accountId: String,
        accountType: String,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: ?DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.userId = userId
        this.accountId = accountId
        this.accountType = accountType
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"user_id\":\"${userId}\",")
        sb.append("\"account_id\":\"${accountId}\",")
        sb.append("\"account_type\":\"${accountType}\",")
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        sb.append("\"created_at\":\"${createdAt}\",")
        if (let Some(v) <- updatedAt) {
            sb.append("\"updated_at\":\"${v}\",")
        } else {
            sb.append("\"updated_at\":\"\",")
        }
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\"")
        } else {
            sb.append("\"deleted_at\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
