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
 * UserGroupPO - user_group表持久化对象
 * 
 * 对应数据库表: user_group
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["user_group"]
public class UserGroupPO {
        @ORMField[true 'id']
    private var id: String = ""

        @ORMField['group_name']
    private var groupName: String = ""

        @ORMField['parent_id']
    private var parentId: ?String = None<String>

        @ORMField['code']
    private var code: String = ""

        @ORMField['intro']
    private var intro: ?String = None<String>

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
        groupName: String,
        parentId: ?String,
        code: String,
        intro: ?String,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: ?DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.groupName = groupName
        this.parentId = parentId
        this.code = code
        this.intro = intro
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"group_name\":\"${groupName}\",")
        if (let Some(v) <- parentId) {
            sb.append("\"parent_id\":\"${v}\",")
        } else {
            sb.append("\"parent_id\":\"\",")
        }
        sb.append("\"code\":\"${code}\",")
        if (let Some(v) <- intro) {
            sb.append("\"intro\":\"${v}\",")
        } else {
            sb.append("\"intro\":\"\",")
        }
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
