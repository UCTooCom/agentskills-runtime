/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * OperateLogPO - operate_log表持久化对象
 * 
 * 对应数据库表: operate_log
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["operate_log"]
public class OperateLogPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['module']
    public var module: String = ""

        @ORMField['operate']
    public var operate: String = ""

        @ORMField['route']
    public var route: String = ""

        @ORMField['params']
    public var params: String = ""

        @ORMField['ip']
    public var ip: String = ""

        @ORMField['method']
    public var method: String = ""

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                module: String,
                operate: String,
                route: String,
                params: String,
                ip: String,
                method: String,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.module = module
                this.operate = operate
                this.route = route
                this.params = params
                this.ip = ip
                this.method = method
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("module", this.module.toJsonValue())
        map.add("operate", this.operate.toJsonValue())
        map.add("route", this.route.toJsonValue())
        map.add("params", this.params.toJsonValue())
        map.add("ip", this.ip.toJsonValue())
        map.add("method", this.method.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
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
