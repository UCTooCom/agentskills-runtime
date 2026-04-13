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
 * LangPO - lang表持久化对象
 * 
 * 对应数据库表: lang
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["lang"]
public class LangPO {
        @ORMField[true 'id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['code']
    public var code: String = ""

        @ORMField['status']
    public var status: ?Int32 = None<Int32>

        @ORMField['creator']
    public var creator: ?String = None<String>

        @ORMField['created_at']
    public var createdAt: ?DateTime = None<DateTime>

        @ORMField['updated_at']
    public var updatedAt: ?DateTime = None<DateTime>

        @ORMField['deleted_at']
    public var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        name: String,
        code: String,
        status: ?Int32,
        creator: ?String,
        createdAt: ?DateTime,
        updatedAt: ?DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.name = name
        this.code = code
        this.status = status
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"name\":\"${name}\",")
        sb.append("\"code\":\"${code}\",")
        sb.append("\"status\":${status},")
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        if (let Some(v) <- createdAt) {
            sb.append("\"created_at\":\"${v}\",")
        } else {
            sb.append("\"created_at\":\"\",")
        }
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
