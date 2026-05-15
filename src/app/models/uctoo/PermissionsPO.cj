/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * PermissionsPO - permissions表持久化对象
 * 
 * 对应数据库表: permissions
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["permissions"]
public class PermissionsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['permission_name']
    public var permissionName: String = ""

        @ORMField['level']
    public var level: Option<String> = None<String>

        @ORMField['icon']
    public var icon: Option<String> = None<String>

        @ORMField['module']
    public var module: Option<String> = None<String>

        @ORMField['component']
    public var component: Option<String> = None<String>

        @ORMField['redirect']
    public var redirect: Option<String> = None<String>

        @ORMField['type']
    public var typeVal: Int32 = 0

        @ORMField['hidden']
    public var hidden: Int32 = 0

        @ORMField['weight']
    public var weight: Int32 = 0

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['keepalive']
    public var keepalive: Int32 = 0

        @ORMField['path']
    public var path: Option<String> = None<String>

        @ORMField['title']
    public var title: Option<String> = None<String>

        @ORMField['parent_id']
    public var parentId: Option<String> = None<String>

        @ORMField['meta']
    public var meta: Option<String> = None<String>

        @ORMField['method']
    public var method: Option<String> = None<String>

        @ORMField['menu_type']
    public var menuType: Option<String> = None<String>

        @ORMField['locale']
    public var locale: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                permissionName: String,
                level: Option<String>,
                icon: Option<String>,
                module: Option<String>,
                component: Option<String>,
                redirect: Option<String>,
                typeVal: Int32,
                hidden: Int32,
                weight: Int32,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                keepalive: Int32,
                path: Option<String>,
                title: Option<String>,
                parentId: Option<String>,
                meta: Option<String>,
                method: Option<String>,
                menuType: Option<String>,
                locale: Option<String>
    ) {
                this.id = id
                this.permissionName = permissionName
                this.level = level
                this.icon = icon
                this.module = module
                this.component = component
                this.redirect = redirect
                this.typeVal = typeVal
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
                this.menuType = menuType
                this.locale = locale
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("permission_name", this.permissionName.toJsonValue())
        map.add("level", optionToJsonValue(this.level))
        map.add("icon", optionToJsonValue(this.icon))
        map.add("module", optionToJsonValue(this.module))
        map.add("component", optionToJsonValue(this.component))
        map.add("redirect", optionToJsonValue(this.redirect))
        map.add("type", this.typeVal.toJsonValue())
        map.add("hidden", this.hidden.toJsonValue())
        map.add("weight", this.weight.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("keepalive", this.keepalive.toJsonValue())
        map.add("path", optionToJsonValue(this.path))
        map.add("title", optionToJsonValue(this.title))
        map.add("parent_id", optionToJsonValue(this.parentId))
        map.add("meta", optionToJsonValue(this.meta))
        map.add("method", optionToJsonValue(this.method))
        map.add("menu_type", optionToJsonValue(this.menuType))
        map.add("locale", optionToJsonValue(this.locale))
        return JsonObject(map)
    }

    /// 辅助方法：将 Option<T> 转换为 JsonValue
    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }

    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return this.toJsonValue().toString()
    }

//#endregion AutoCreateCode
}
