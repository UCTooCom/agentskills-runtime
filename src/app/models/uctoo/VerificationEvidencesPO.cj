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
 * VerificationEvidencesPO - verification_evidences表持久化对象
 * 
 * 对应数据库表: verification_evidences
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["verification_evidences"]
public class VerificationEvidencesPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['agent_id']
    public var agentId: String = ""

        @ORMField['session_id']
    public var sessionId: String = ""

        @ORMField['verification_type']
    public var verificationType: String = ""

        @ORMField['scope']
    public var scope: String = ""

        @ORMField['command']
    public var command: Option<String> = None<String>

        @ORMField['status']
    public var status: String = ""

        @ORMField['exit_code']
    public var exitCode: Option<Int32> = None<Int32>

        @ORMField['output_summary']
    public var outputSummary: Option<String> = None<String>

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
                sessionId: String,
                verificationType: String,
                scope: String,
                command: Option<String>,
                status: String,
                exitCode: Option<Int32>,
                outputSummary: Option<String>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.agentId = agentId
                this.sessionId = sessionId
                this.verificationType = verificationType
                this.scope = scope
                this.command = command
                this.status = status
                this.exitCode = exitCode
                this.outputSummary = outputSummary
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
        map.add("session_id", this.sessionId.toJsonValue())
        map.add("verification_type", this.verificationType.toJsonValue())
        map.add("scope", this.scope.toJsonValue())
        map.add("command", optionToJsonValue(this.command))
        map.add("status", this.status.toJsonValue())
        map.add("exit_code", optionToJsonValue(this.exitCode))
        map.add("output_summary", optionToJsonValue(this.outputSummary))
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
