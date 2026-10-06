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
 * ModelRouteRulePO - llm_route_rule表持久化对象
 *
 * 对应数据库表: llm_route_rule
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["llm_route_rule"]
public class ModelRouteRulePO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['scope']
    public var scope: String = ""

        @ORMField['require_capabilities']
    public var requireCapabilities: String = ""

        @ORMField['channel_chain']
    public var channelChain: String = ""

        @ORMField['fallback_chain']
    public var fallbackChain: String = ""

        @ORMField['strategy']
    public var strategy: String = ""

        @ORMField['shadow_percent']
    public var shadowPercent: Int32 = 0

        @ORMField['enabled']
    public var enabled: Bool = true

        @ORMField['priority']
    public var priority: Int32 = 0

        @ORMField['revision']
    public var revision: Int64 = 0

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
                scope: String,
                requireCapabilities: String,
                channelChain: String,
                fallbackChain: String,
                strategy: String,
                shadowPercent: Int32,
                enabled: Bool,
                priority: Int32,
                revision: Int64,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.scope = scope
                this.requireCapabilities = requireCapabilities
                this.channelChain = channelChain
                this.fallbackChain = fallbackChain
                this.strategy = strategy
                this.shadowPercent = shadowPercent
                this.enabled = enabled
                this.priority = priority
                this.revision = revision
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("scope", this.scope.toJsonValue())
        map.add("require_capabilities", this.requireCapabilities.toJsonValue())
        map.add("channel_chain", this.channelChain.toJsonValue())
        map.add("fallback_chain", this.fallbackChain.toJsonValue())
        map.add("strategy", this.strategy.toJsonValue())
        map.add("shadow_percent", this.shadowPercent.toJsonValue())
        map.add("enabled", this.enabled.toJsonValue())
        map.add("priority", this.priority.toJsonValue())
        map.add("revision", this.revision.toJsonValue())
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
