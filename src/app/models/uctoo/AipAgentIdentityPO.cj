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
 * AipAgentIdentityPO - aip_agent_identity表持久化对象
 * 
 * 对应数据库表: aip_agent_identity
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_agent_identity"]
public class AipAgentIdentityPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['aic']
    public var aic: String = ""

        @ORMField['aic_version']
    public var aicVersion: String = ""

        @ORMField['registration_service_provider']
    public var registrationServiceProvider: String = ""

        @ORMField['registration_requester']
    public var registrationRequester: String = ""

        @ORMField['ontology_serial']
    public var ontologySerial: String = ""

        @ORMField['instance_serial']
    public var instanceSerial: String = ""

        @ORMField['credential_id']
    public var credentialId: Option<String> = None<String>

        @ORMField['identity_status']
    public var identityStatus: String = ""

        @ORMField['registered_at']
    public var registeredAt: DateTime = DateTime.now()

        @ORMField['last_verified_at']
    public var lastVerifiedAt: Option<DateTime> = None<DateTime>

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
                agentId: String,
                aic: String,
                aicVersion: String,
                registrationServiceProvider: String,
                registrationRequester: String,
                ontologySerial: String,
                instanceSerial: String,
                credentialId: Option<String>,
                identityStatus: String,
                registeredAt: DateTime,
                lastVerifiedAt: Option<DateTime>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.aic = aic
                this.aicVersion = aicVersion
                this.registrationServiceProvider = registrationServiceProvider
                this.registrationRequester = registrationRequester
                this.ontologySerial = ontologySerial
                this.instanceSerial = instanceSerial
                this.credentialId = credentialId
                this.identityStatus = identityStatus
                this.registeredAt = registeredAt
                this.lastVerifiedAt = lastVerifiedAt
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("aic", this.aic.toJsonValue())
        map.add("aic_version", this.aicVersion.toJsonValue())
        map.add("registration_service_provider", this.registrationServiceProvider.toJsonValue())
        map.add("registration_requester", this.registrationRequester.toJsonValue())
        map.add("ontology_serial", this.ontologySerial.toJsonValue())
        map.add("instance_serial", this.instanceSerial.toJsonValue())
        map.add("credential_id", optionToJsonValue(this.credentialId))
        map.add("identity_status", this.identityStatus.toJsonValue())
        map.add("registered_at", this.registeredAt.toJsonValue())
        map.add("last_verified_at", optionToJsonValue(this.lastVerifiedAt))
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
