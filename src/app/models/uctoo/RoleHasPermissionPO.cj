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
 * RoleHasPermissionPO - role_has_permission表持久化对象
 * 
 * 对应数据库表: role_has_permission
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["role_has_permission"]
public class RoleHasPermissionPO {
        @ORMField[true 'role_id']
    private var roleId: String = ""

        @ORMField[true 'permission_name']
    private var permissionName: String = ""

        @ORMField['status']
    private var status: ?Int32 = None<Int32>

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
                roleId: String,
        permissionName: String,
        status: ?Int32,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime
    ) {
                this.roleId = roleId
        this.permissionName = permissionName
        this.status = status
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"role_id\":\"${roleId}\",")
        sb.append("\"permission_name\":\"${permissionName}\",")
        sb.append("\"status\":${status},")
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
