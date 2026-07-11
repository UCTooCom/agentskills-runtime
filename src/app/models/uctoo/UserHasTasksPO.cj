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
 * UserHasTasksPO - user_has_tasks表持久化对象
 * 
 * 对应数据库表: user_has_tasks
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["user_has_tasks"]
public class UserHasTasksPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['user_id']
    public var userId: String = ""

        @ORMField['task_id']
    public var taskId: String = ""

        @ORMField['relation_type']
    public var relationType: String = ""

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['join_status']
    public var joinStatus: String = ""

        @ORMField['submission_content']
    public var submissionContent: Option<String> = None<String>

        @ORMField['submission_attachments']
    public var submissionAttachments: Option<String> = None<String>

        @ORMField['submitted_at']
    public var submittedAt: Option<DateTime> = None<DateTime>

        @ORMField['review_status']
    public var reviewStatus: String = ""

        @ORMField['review_comment']
    public var reviewComment: Option<String> = None<String>

        @ORMField['reviewed_at']
    public var reviewedAt: Option<DateTime> = None<DateTime>

        @ORMField['reviewer_id']
    public var reviewerId: Option<String> = None<String>

        @ORMField['allocation_ratio']
    public var allocationRatio: Float64 = 0.0

        @ORMField['points_earned']
    public var pointsEarned: Int64 = 0

        @ORMField['settled_at']
    public var settledAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                userId: String,
                taskId: String,
                relationType: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                creator: Option<String>,
                joinStatus: String,
                submissionContent: Option<String>,
                submissionAttachments: Option<String>,
                submittedAt: Option<DateTime>,
                reviewStatus: String,
                reviewComment: Option<String>,
                reviewedAt: Option<DateTime>,
                reviewerId: Option<String>,
                allocationRatio: Float64,
                pointsEarned: Int64,
                settledAt: Option<DateTime>
    ) {
                this.id = id
                this.userId = userId
                this.taskId = taskId
                this.relationType = relationType
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.creator = creator
                this.joinStatus = joinStatus
                this.submissionContent = submissionContent
                this.submissionAttachments = submissionAttachments
                this.submittedAt = submittedAt
                this.reviewStatus = reviewStatus
                this.reviewComment = reviewComment
                this.reviewedAt = reviewedAt
                this.reviewerId = reviewerId
                this.allocationRatio = allocationRatio
                this.pointsEarned = pointsEarned
                this.settledAt = settledAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("user_id", this.userId.toJsonValue())
        map.add("task_id", this.taskId.toJsonValue())
        map.add("relation_type", this.relationType.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("join_status", this.joinStatus.toJsonValue())
        map.add("submission_content", optionToJsonValue(this.submissionContent))
        map.add("submission_attachments", optionToJsonValue(this.submissionAttachments))
        map.add("submitted_at", optionToJsonValue(this.submittedAt))
        map.add("review_status", this.reviewStatus.toJsonValue())
        map.add("review_comment", optionToJsonValue(this.reviewComment))
        map.add("reviewed_at", optionToJsonValue(this.reviewedAt))
        map.add("reviewer_id", optionToJsonValue(this.reviewerId))
        map.add("allocation_ratio", this.allocationRatio.toJsonValue())
        map.add("points_earned", this.pointsEarned.toJsonValue())
        map.add("settled_at", optionToJsonValue(this.settledAt))
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
