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
 * PermissionsPO - permissions表持久化对象
 * 
 * 对应数据库表: permissions
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["permissions"]
public class PermissionsPO {
        @ORMField[true 'id']
    private var id: String = ""

        @ORMField['permission_name']
    private var permissionName: String = ""

        @ORMField['level']
    private var level: ?String = None<String>

        @ORMField['icon']
    private var icon: ?String = None<String>

        @ORMField['module']
    private var module: ?String = None<String>

        @ORMField['component']
    private var component: ?String = None<String>

        @ORMField['redirect']
    private var redirect: ?String = None<String>

        // 注意: 数据库列名 'type' 是关键字，已重命名为 'permissionType'
    @ORMField['type']
    private var permissionType: ?Int32 = None<Int32>

        @ORMField['hidden']
    private var hidden: ?Int32 = None<Int32>

        @ORMField['weight']
    private var weight: ?Int32 = None<Int32>

        @ORMField['creator']
    private var creator: ?String = None<String>

        @ORMField['created_at']
    private var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>

        @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>

        @ORMField['keepalive']
    private var keepalive: ?Int32 = None<Int32>

        @ORMField['path']
    private var path: String = ""

        @ORMField['title']
    private var title: ?String = None<String>

        @ORMField['parent_id']
    private var parentId: ?String = None<String>

        @ORMField['meta']
    private var meta: ?String = None<String>

        @ORMField['method']
    private var method: ?String = None<String>
    
    public init() {}
    
    public init(
                id: String,
        permissionName: String,
        level: ?String,
        icon: ?String,
        module: ?String,
        component: ?String,
        redirect: ?String,
        permissionType: ?Int32,
        hidden: ?Int32,
        weight: ?Int32,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: ?DateTime,
        deletedAt: ?DateTime,
        keepalive: ?Int32,
        path: String,
        title: ?String,
        parentId: ?String,
        meta: ?String,
        method: ?String
    ) {
                this.id = id
        this.permissionName = permissionName
        this.level = level
        this.icon = icon
        this.module = module
        this.component = component
        this.redirect = redirect
        this.permissionType = permissionType
        this.hidden = hidden
        this.weight = weight
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
        this.keepalive = keepalive
        this.path = path
        this.title = title
        this.parentId = parentId
        this.meta = meta
        this.method = method
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"permission_name\":\"${permissionName}\",")
        if (let Some(v) <- level) {
            sb.append("\"level\":\"${v}\",")
        } else {
            sb.append("\"level\":\"\",")
        }
        if (let Some(v) <- icon) {
            sb.append("\"icon\":\"${v}\",")
        } else {
            sb.append("\"icon\":\"\",")
        }
        if (let Some(v) <- module) {
            sb.append("\"module\":\"${v}\",")
        } else {
            sb.append("\"module\":\"\",")
        }
        if (let Some(v) <- component) {
            sb.append("\"component\":\"${v}\",")
        } else {
            sb.append("\"component\":\"\",")
        }
        if (let Some(v) <- redirect) {
            sb.append("\"redirect\":\"${v}\",")
        } else {
            sb.append("\"redirect\":\"\",")
        }
        if (let Some(v) <- permissionType) {
            sb.append("\"type\":${v},")
        } else {
            sb.append("\"type\":null,")
        }
        if (let Some(v) <- hidden) {
            sb.append("\"hidden\":${v},")
        } else {
            sb.append("\"hidden\":null,")
        }
        if (let Some(v) <- weight) {
            sb.append("\"weight\":${v},")
        } else {
            sb.append("\"weight\":null,")
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
            sb.append("\"deleted_at\":\"${v}\",")
        } else {
            sb.append("\"deleted_at\":\"\",")
        }
        if (let Some(v) <- keepalive) {
            sb.append("\"keepalive\":${v},")
        } else {
            sb.append("\"keepalive\":null,")
        }
        sb.append("\"path\":\"${path}\",")
        if (let Some(v) <- title) {
            sb.append("\"title\":\"${v}\",")
        } else {
            sb.append("\"title\":\"\",")
        }
        if (let Some(v) <- parentId) {
            sb.append("\"parent_id\":\"${v}\",")
        } else {
            sb.append("\"parent_id\":\"\",")
        }
        if (let Some(v) <- meta) {
            sb.append("\"meta\":\"${v}\",")
        } else {
            sb.append("\"meta\":\"\",")
        }
        if (let Some(v) <- method) {
            sb.append("\"method\":\"${v}\"")
        } else {
            sb.append("\"method\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
