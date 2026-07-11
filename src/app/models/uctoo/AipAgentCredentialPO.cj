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
 * AipAgentCredentialPO - aip_agent_credential表持久化对象
 * 
 * 对应数据库表: aip_agent_credential
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["aip_agent_credential"]
public class AipAgentCredentialPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_identity_id']
    public var agentIdentityId: String = ""

        @ORMField['credential_type']
    public var credentialType: String = ""

        @ORMField['issuer']
    public var issuer: String = ""

        @ORMField['serial_number']
    public var serialNumber: String = ""

        @ORMField['not_before']
    public var notBefore: DateTime = DateTime.now()

        @ORMField['not_after']
    public var notAfter: DateTime = DateTime.now()

        @ORMField['credential_status']
    public var credentialStatus: String = ""

        @ORMField['certificate_pem']
    public var certificatePem: Option<String> = None<String>

        @ORMField['public_key']
    public var publicKey: Option<String> = None<String>

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
                agentIdentityId: String,
                credentialType: String,
                issuer: String,
                serialNumber: String,
                notBefore: DateTime,
                notAfter: DateTime,
                credentialStatus: String,
                certificatePem: Option<String>,
                publicKey: Option<String>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentIdentityId = agentIdentityId
                this.credentialType = credentialType
                this.issuer = issuer
                this.serialNumber = serialNumber
                this.notBefore = notBefore
                this.notAfter = notAfter
                this.credentialStatus = credentialStatus
                this.certificatePem = certificatePem
                this.publicKey = publicKey
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("agent_identity_id", this.agentIdentityId.toJsonValue())
        map.add("credential_type", this.credentialType.toJsonValue())
        map.add("issuer", this.issuer.toJsonValue())
        map.add("serial_number", this.serialNumber.toJsonValue())
        map.add("not_before", this.notBefore.toJsonValue())
        map.add("not_after", this.notAfter.toJsonValue())
        map.add("credential_status", this.credentialStatus.toJsonValue())
        map.add("certificate_pem", optionToJsonValue(this.certificatePem))
        map.add("public_key", optionToJsonValue(this.publicKey))
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
