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
 * SyncLogPO - sync_log表持久化对象
 * 
 * 对应数据库表: sync_log
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["sync_log"]
public class SyncLogPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['entity_type']
    public var entityType: String = ""

        @ORMField['source_path']
    public var sourcePath: String = ""

        @ORMField['operation']
    public var operation: String = ""

        @ORMField['direction']
    public var direction: String = ""

        @ORMField['status']
    public var status: String = ""

        @ORMField['message']
    public var message: Option<String> = None<String>

        @ORMField['error_detail']
    public var errorDetail: Option<String> = None<String>

        @ORMField['sync_source']
    public var syncSource: String = ""

        @ORMField['duration_ms']
    public var durationMs: Option<Int32> = None<Int32>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: Option<DateTime> = None<DateTime>

        @ORMField['updated_at']
    public var updatedAt: Option<DateTime> = None<DateTime>

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                entityType: String,
                sourcePath: String,
                operation: String,
                direction: String,
                status: String,
                message: Option<String>,
                errorDetail: Option<String>,
                syncSource: String,
                durationMs: Option<Int32>,
                creator: Option<String>,
                createdAt: Option<DateTime>,
                updatedAt: Option<DateTime>,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.entityType = entityType
                this.sourcePath = sourcePath
                this.operation = operation
                this.direction = direction
                this.status = status
                this.message = message
                this.errorDetail = errorDetail
                this.syncSource = syncSource
                this.durationMs = durationMs
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("entity_type", this.entityType.toJsonValue())
        map.add("source_path", this.sourcePath.toJsonValue())
        map.add("operation", this.operation.toJsonValue())
        map.add("direction", this.direction.toJsonValue())
        map.add("status", this.status.toJsonValue())
        map.add("message", optionToJsonValue(this.message))
        map.add("error_detail", optionToJsonValue(this.errorDetail))
        map.add("sync_source", this.syncSource.toJsonValue())
        map.add("duration_ms", optionToJsonValue(this.durationMs))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", optionToJsonValue(this.createdAt))
        map.add("updated_at", optionToJsonValue(this.updatedAt))
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
