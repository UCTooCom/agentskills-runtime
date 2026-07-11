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
 * TaskSettlementsPO - task_settlements表持久化对象
 * 
 * 对应数据库表: task_settlements
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["task_settlements"]
public class TaskSettlementsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['task_id']
    public var taskId: String = ""

        @ORMField['settler_id']
    public var settlerId: String = ""

        @ORMField['company_id']
    public var companyId: Option<String> = None<String>

        @ORMField['settlement_type']
    public var settlementType: String = ""

        @ORMField['total_points']
    public var totalPoints: Int64 = 0

        @ORMField['settlement_status']
    public var settlementStatus: String = ""

        @ORMField['allocations']
    public var allocations: Option<String> = None<String>

        @ORMField['settled_at']
    public var settledAt: Option<DateTime> = None<DateTime>

        @ORMField['remark']
    public var remark: Option<String> = None<String>

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
                taskId: String,
                settlerId: String,
                companyId: Option<String>,
                settlementType: String,
                totalPoints: Int64,
                settlementStatus: String,
                allocations: Option<String>,
                settledAt: Option<DateTime>,
                remark: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.taskId = taskId
                this.settlerId = settlerId
                this.companyId = companyId
                this.settlementType = settlementType
                this.totalPoints = totalPoints
                this.settlementStatus = settlementStatus
                this.allocations = allocations
                this.settledAt = settledAt
                this.remark = remark
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("task_id", this.taskId.toJsonValue())
        map.add("settler_id", this.settlerId.toJsonValue())
        map.add("company_id", optionToJsonValue(this.companyId))
        map.add("settlement_type", this.settlementType.toJsonValue())
        map.add("total_points", this.totalPoints.toJsonValue())
        map.add("settlement_status", this.settlementStatus.toJsonValue())
        map.add("allocations", optionToJsonValue(this.allocations))
        map.add("settled_at", optionToJsonValue(this.settledAt))
        map.add("remark", optionToJsonValue(this.remark))
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
