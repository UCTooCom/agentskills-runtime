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
 * OrchestrationStepsPO - orchestration_steps表持久化对象
 * 
 * 对应数据库表: orchestration_steps
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["orchestration_steps"]
public class OrchestrationStepsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['plan_id']
    public var planId: String = ""

        @ORMField['step_name']
    public var stepName: String = ""

        @ORMField['step_type']
    public var stepType: String = ""

        @ORMField['target_ref']
    public var targetRef: String = ""

        @ORMField['input_mapping']
    public var inputMapping: Option<String> = None<String>

        @ORMField['condition']
    public var condition: Option<String> = None<String>

        @ORMField['depends_on']
    public var dependsOn: Option<String> = None<String>

        @ORMField['status']
    public var status: String = ""

        @ORMField['result']
    public var result: Option<String> = None<String>

        @ORMField['side_effects']
    public var sideEffects: Option<String> = None<String>

        @ORMField['started_at']
    public var startedAt: Option<DateTime> = None<DateTime>

        @ORMField['completed_at']
    public var completedAt: Option<DateTime> = None<DateTime>

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
                planId: String,
                stepName: String,
                stepType: String,
                targetRef: String,
                inputMapping: Option<String>,
                condition: Option<String>,
                dependsOn: Option<String>,
                status: String,
                result: Option<String>,
                sideEffects: Option<String>,
                startedAt: Option<DateTime>,
                completedAt: Option<DateTime>,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.planId = planId
                this.stepName = stepName
                this.stepType = stepType
                this.targetRef = targetRef
                this.inputMapping = inputMapping
                this.condition = condition
                this.dependsOn = dependsOn
                this.status = status
                this.result = result
                this.sideEffects = sideEffects
                this.startedAt = startedAt
                this.completedAt = completedAt
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("plan_id", this.planId.toJsonValue())
        map.add("step_name", this.stepName.toJsonValue())
        map.add("step_type", this.stepType.toJsonValue())
        map.add("target_ref", this.targetRef.toJsonValue())
        map.add("input_mapping", optionToJsonValue(this.inputMapping))
        map.add("condition", optionToJsonValue(this.condition))
        map.add("depends_on", optionToJsonValue(this.dependsOn))
        map.add("status", this.status.toJsonValue())
        map.add("result", optionToJsonValue(this.result))
        map.add("side_effects", optionToJsonValue(this.sideEffects))
        map.add("started_at", optionToJsonValue(this.startedAt))
        map.add("completed_at", optionToJsonValue(this.completedAt))
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
