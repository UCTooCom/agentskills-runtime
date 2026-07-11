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
 * AipDiscoveryCachePO - aip_discovery_cache表持久化对象
 * 
 * 对应数据库表: aip_discovery_cache
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_discovery_cache"]
public class AipDiscoveryCachePO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['query_hash']
    public var queryHash: String = ""

        @ORMField['query_condition']
    public var queryCondition: String = ""

        @ORMField['result_set']
    public var resultSet: String = ""

        @ORMField['result_count']
    public var resultCount: Int32 = 0

        @ORMField['cached_at']
    public var cachedAt: DateTime = DateTime.now()

        @ORMField['expires_at']
    public var expiresAt: DateTime = DateTime.now()

        @ORMField['creator']
    public var creator: String = ""

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                queryHash: String,
                queryCondition: String,
                resultSet: String,
                resultCount: Int32,
                cachedAt: DateTime,
                expiresAt: DateTime,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.queryHash = queryHash
                this.queryCondition = queryCondition
                this.resultSet = resultSet
                this.resultCount = resultCount
                this.cachedAt = cachedAt
                this.expiresAt = expiresAt
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("query_hash", this.queryHash.toJsonValue())
        map.add("query_condition", this.queryCondition.toJsonValue())
        map.add("result_set", this.resultSet.toJsonValue())
        map.add("result_count", this.resultCount.toJsonValue())
        map.add("cached_at", this.cachedAt.toJsonValue())
        map.add("expires_at", this.expiresAt.toJsonValue())
        map.add("creator", this.creator.toJsonValue())
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
