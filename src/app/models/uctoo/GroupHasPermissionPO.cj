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
 * GroupHasPermissionPO - group_has_permission表持久化对象
 * 
 * 对应数据库表: group_has_permission
 * 遵循UCTOO V4 ORM规范
 * 
 * 注意: 此表使用复合主键 (group_id, permission_name)
 */
@DataAssist[fields]
@QueryMappersGenerator["group_has_permission"]
public class GroupHasPermissionPO {
    @ORMField[true 'group_id']
    private var groupId: String = ""

    @ORMField[true 'permission_name']
    private var permissionName: String = ""

    @ORMField['status']
    private var status: ?Int32 = None<Int32>

    @ORMField['creator']
    private var creator: ?String = None<String>

    @ORMField['created_at']
    private var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>

    @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>

    // ========== 属性访问器 ==========

    public mut prop groupIdProp: String {
        get() { groupId }
        set(value) { groupId = value }
    }

    public mut prop permissionNameProp: String {
        get() { permissionName }
        set(value) { permissionName = value }
    }

    public mut prop statusProp: ?Int32 {
        get() { status }
        set(value) { status = value }
    }

    public mut prop creatorProp: ?String {
        get() { creator }
        set(value) { creator = value }
    }

    public mut prop createdAtProp: DateTime {
        get() { createdAt }
        set(value) { createdAt = value }
    }

    public mut prop updatedAtProp: ?DateTime {
        get() { updatedAt }
        set(value) { updatedAt = value }
    }

    public mut prop deletedAtProp: ?DateTime {
        get() { deletedAt }
        set(value) { deletedAt = value }
    }

    // ========== 构造函数 ==========

    public init() {}

    public init(groupId: String, permissionName: String) {
        this.groupId = groupId
        this.permissionName = permissionName
    }

    // ========== 辅助方法 ==========

    /// 获取复合主键
    public func getCompositeKey(): String {
        "${groupId}:${permissionName}"
    }

    /// 转换为JSON字符串
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
        sb.append("\"group_id\":\"${groupId}\",")
        sb.append("\"permission_name\":\"${permissionName}\",")
        if (let Some(s) <- status) {
            sb.append("\"status\":${s},")
        }
        if (let Some(c) <- creator) {
            sb.append("\"creator\":\"${c}\",")
        }
        sb.append("\"created_at\":\"${createdAt}\"")
        if (let Some(u) <- updatedAt) {
            sb.append(",\"updated_at\":\"${u}\"")
        }
        if (let Some(d) <- deletedAt) {
            sb.append(",\"deleted_at\":\"${d}\"")
        }
        sb.append("}")
        sb.toString()
    }
}
