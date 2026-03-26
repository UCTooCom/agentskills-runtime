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
 * DataAccessAuthorizationPO - data_access_authorization表持久化对象
 * 
 * 对应数据库表: data_access_authorization
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["data_access_authorization"]
public class DataAccessAuthorizationPO {
        @ORMField[true 'id']
    private var id: String = ""

        @ORMField['entity_id']
    private var entityId: String = ""

        @ORMField['entity_type']
    private var entityType: String = ""

        @ORMField['user_id']
    private var userId: String = ""

        @ORMField['permission']
    private var permission: ?Int32 = None<Int32>

        @ORMField['creator']
    private var creator: ?String = None<String>

        @ORMField['created_at']
    private var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    private var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        entityId: String,
        entityType: String,
        userId: String,
        permission: ?Int32,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.entityId = entityId
        this.entityType = entityType
        this.userId = userId
        this.permission = permission
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"entity_id\":\"${entityId}\",")
        sb.append("\"entity_type\":\"${entityType}\",")
        sb.append("\"user_id\":\"${userId}\",")
        sb.append("\"permission\":${permission},")
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
