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
 * AipServiceConfigPO - aip_service_config表持久化对象
 * 
 * 对应数据库表: aip_service_config
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_service_config"]
public class AipServiceConfigPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['service_type']
    public var serviceType: String = ""

        @ORMField['service_name']
    public var serviceName: String = ""

        @ORMField['service_endpoint']
    public var serviceEndpoint: String = ""

        @ORMField['protocol_version']
    public var protocolVersion: String = ""

        @ORMField['config']
    public var config: Option<String> = None<String>

        @ORMField['enabled']
    public var enabled: Bool = false

        @ORMField['health_status']
    public var healthStatus: String = ""

        @ORMField['last_health_check_at']
    public var lastHealthCheckAt: Option<DateTime> = None<DateTime>

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
                serviceType: String,
                serviceName: String,
                serviceEndpoint: String,
                protocolVersion: String,
                config: Option<String>,
                enabled: Bool,
                healthStatus: String,
                lastHealthCheckAt: Option<DateTime>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.serviceType = serviceType
                this.serviceName = serviceName
                this.serviceEndpoint = serviceEndpoint
                this.protocolVersion = protocolVersion
                this.config = config
                this.enabled = enabled
                this.healthStatus = healthStatus
                this.lastHealthCheckAt = lastHealthCheckAt
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("service_type", this.serviceType.toJsonValue())
        map.add("service_name", this.serviceName.toJsonValue())
        map.add("service_endpoint", this.serviceEndpoint.toJsonValue())
        map.add("protocol_version", this.protocolVersion.toJsonValue())
        map.add("config", optionToJsonValue(this.config))
        map.add("enabled", this.enabled.toJsonValue())
        map.add("health_status", this.healthStatus.toJsonValue())
        map.add("last_health_check_at", optionToJsonValue(this.lastHealthCheckAt))
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
