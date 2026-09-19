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
 * LongRunningTaskArtifactPO - long_running_task_artifact表持久化对象
 * 
 * 对应数据库表: long_running_task_artifact
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["long_running_task_artifact"]
public class LongRunningTaskArtifactPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

        @ORMField['artifact_path']
    public var artifactPath: String = ""

        @ORMField['artifact_type']
    public var artifactType: String = ""

        @ORMField['verification_status']
    public var verificationStatus: String = ""

        @ORMField['verification_result']
    public var verificationResult: Option<String> = None<String>

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
                taskId: Option<String>,
                artifactPath: String,
                artifactType: String,
                verificationStatus: String,
                verificationResult: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.taskId = taskId
                this.artifactPath = artifactPath
                this.artifactType = artifactType
                this.verificationStatus = verificationStatus
                this.verificationResult = verificationResult
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("task_id", optionToJsonValue(this.taskId))
        map.add("artifact_path", this.artifactPath.toJsonValue())
        map.add("artifact_type", this.artifactType.toJsonValue())
        map.add("verification_status", this.verificationStatus.toJsonValue())
        map.add("verification_result", optionToJsonValue(this.verificationResult))
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
