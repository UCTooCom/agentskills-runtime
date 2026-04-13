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
 * UctooRolePO - uctoo_role表持久化对象
 * 
 * 对应数据库表: uctoo_role
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["uctoo_role"]
public class UctooRolePO {
        @ORMField[true 'id']
    private var id: String = ""

        @ORMField['name']
    private var name: String = ""

        @ORMField['created_at']
    private var createdAt: ?DateTime = None<DateTime>

        @ORMField['creator']
    private var creator: ?String = None<String>

        @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>

        @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        name: String,
        createdAt: ?DateTime,
        creator: ?String,
        deletedAt: ?DateTime,
        updatedAt: ?DateTime
    ) {
                this.id = id
        this.name = name
        this.createdAt = createdAt
        this.creator = creator
        this.deletedAt = deletedAt
        this.updatedAt = updatedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"name\":\"${name}\",")
        if (let Some(v) <- createdAt) {
            sb.append("\"created_at\":\"${v}\",")
        } else {
            sb.append("\"created_at\":\"\",")
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
        if (let Some(v) <- updatedAt) {
            sb.append("\"updated_at\":\"${v}\"")
        } else {
            sb.append("\"updated_at\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
