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
 * TasksPO - tasks表持久化对象
 * 
 * 对应数据库表: tasks
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["tasks"]
public class TasksPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['title']
    public var title: String = ""

        @ORMField['description']
    public var description: String = ""

        @ORMField['task_type']
    public var taskType: String = ""

        @ORMField['task_status']
    public var taskStatus: String = ""

        @ORMField['priority']
    public var priority: String = ""

        @ORMField['company_id']
    public var companyId: Option<String> = None<String>

        @ORMField['creator_id']
    public var creatorId: String = ""

        @ORMField['assignee_id']
    public var assigneeId: Option<String> = None<String>

        @ORMField['participant_count']
    public var participantCount: Int32 = 0

        @ORMField['follower_count']
    public var followerCount: Int32 = 0

        @ORMField['view_count']
    public var viewCount: Int32 = 0

        @ORMField['comment_count']
    public var commentCount: Int32 = 0

        @ORMField['reward_type']
    public var rewardType: Option<String> = None<String>

        @ORMField['reward_amount']
    public var rewardAmount: Option<String> = None<String>

        @ORMField['deadline']
    public var deadline: Option<DateTime> = None<DateTime>

        @ORMField['started_at']
    public var startedAt: Option<DateTime> = None<DateTime>

        @ORMField['completed_at']
    public var completedAt: Option<DateTime> = None<DateTime>

        @ORMField['tags']
    public var tags: Option<String> = None<String>

        @ORMField['skills_required']
    public var skillsRequired: Option<String> = None<String>

        @ORMField['attachments']
    public var attachments: Option<String> = None<String>

        @ORMField['extra_data']
    public var extraData: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['reward_points']
    public var rewardPoints: Int64 = 0

        @ORMField['max_participants']
    public var maxParticipants: Int32 = 0

        @ORMField['accept_deadline']
    public var acceptDeadline: Option<DateTime> = None<DateTime>

        @ORMField['settlement_status']
    public var settlementStatus: String = ""

        @ORMField['points_frozen']
    public var pointsFrozen: Int64 = 0

        @ORMField['points_settled']
    public var pointsSettled: Int64 = 0

        @ORMField['points_refunded']
    public var pointsRefunded: Int64 = 0

        @ORMField['review_status']
    public var reviewStatus: String = ""

    public init() {}

    public init(
                id: String,
                title: String,
                description: String,
                taskType: String,
                taskStatus: String,
                priority: String,
                companyId: Option<String>,
                creatorId: String,
                assigneeId: Option<String>,
                participantCount: Int32,
                followerCount: Int32,
                viewCount: Int32,
                commentCount: Int32,
                rewardType: Option<String>,
                rewardAmount: Option<String>,
                deadline: Option<DateTime>,
                startedAt: Option<DateTime>,
                completedAt: Option<DateTime>,
                tags: Option<String>,
                skillsRequired: Option<String>,
                attachments: Option<String>,
                extraData: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                rewardPoints: Int64,
                maxParticipants: Int32,
                acceptDeadline: Option<DateTime>,
                settlementStatus: String,
                pointsFrozen: Int64,
                pointsSettled: Int64,
                pointsRefunded: Int64,
                reviewStatus: String
    ) {
                this.id = id
                this.title = title
                this.description = description
                this.taskType = taskType
                this.taskStatus = taskStatus
                this.priority = priority
                this.companyId = companyId
                this.creatorId = creatorId
                this.assigneeId = assigneeId
                this.participantCount = participantCount
                this.followerCount = followerCount
                this.viewCount = viewCount
                this.commentCount = commentCount
                this.rewardType = rewardType
                this.rewardAmount = rewardAmount
                this.deadline = deadline
                this.startedAt = startedAt
                this.completedAt = completedAt
                this.tags = tags
                this.skillsRequired = skillsRequired
                this.attachments = attachments
                this.extraData = extraData
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.rewardPoints = rewardPoints
                this.maxParticipants = maxParticipants
                this.acceptDeadline = acceptDeadline
                this.settlementStatus = settlementStatus
                this.pointsFrozen = pointsFrozen
                this.pointsSettled = pointsSettled
                this.pointsRefunded = pointsRefunded
                this.reviewStatus = reviewStatus
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("title", this.title.toJsonValue())
        map.add("description", this.description.toJsonValue())
        map.add("task_type", this.taskType.toJsonValue())
        map.add("task_status", this.taskStatus.toJsonValue())
        map.add("priority", this.priority.toJsonValue())
        map.add("company_id", optionToJsonValue(this.companyId))
        map.add("creator_id", this.creatorId.toJsonValue())
        map.add("assignee_id", optionToJsonValue(this.assigneeId))
        map.add("participant_count", this.participantCount.toJsonValue())
        map.add("follower_count", this.followerCount.toJsonValue())
        map.add("view_count", this.viewCount.toJsonValue())
        map.add("comment_count", this.commentCount.toJsonValue())
        map.add("reward_type", optionToJsonValue(this.rewardType))
        map.add("reward_amount", optionToJsonValue(this.rewardAmount))
        map.add("deadline", optionToJsonValue(this.deadline))
        map.add("started_at", optionToJsonValue(this.startedAt))
        map.add("completed_at", optionToJsonValue(this.completedAt))
        map.add("tags", optionToJsonValue(this.tags))
        map.add("skills_required", optionToJsonValue(this.skillsRequired))
        map.add("attachments", optionToJsonValue(this.attachments))
        map.add("extra_data", optionToJsonValue(this.extraData))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("reward_points", this.rewardPoints.toJsonValue())
        map.add("max_participants", this.maxParticipants.toJsonValue())
        map.add("accept_deadline", optionToJsonValue(this.acceptDeadline))
        map.add("settlement_status", this.settlementStatus.toJsonValue())
        map.add("points_frozen", this.pointsFrozen.toJsonValue())
        map.add("points_settled", this.pointsSettled.toJsonValue())
        map.add("points_refunded", this.pointsRefunded.toJsonValue())
        map.add("review_status", this.reviewStatus.toJsonValue())
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
